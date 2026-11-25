"""Compare distributed spine poses on the fixed ANIM-003 acceptance camera."""

from itertools import product
import heapq
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from mathutils.bvhtree import BVHTree
from gltf_support import accessor, mat, np, read, rot, Vector
import neighbour_search_20261112 as reference

m = reference.m
SHARES = (0, .5, 1)


def follows(rig, child, parent):
    while child in rig.parent:
        child = rig.parent[child]
        if child == parent:
            return True
    return False


def rotate_branch(rig, pose, name, rotation):
    joint = rig.names[name]
    pivot = pose[joint].translation
    for child in rig.j:
        if child == joint or follows(rig, child, joint):
            source = pose[child]
            pose[child] = mat(
                rotation @ source.to_3x3(), pivot + rotation @ (source.translation - pivot)
            )


def upper_body(rig, base, bend, yaw, neck):
    pose = base.copy()
    rotate_branch(rig, pose, "Spine01", rot("X", -.65 * bend))
    chest = rig.d["nodes"][rig.parent[rig.names["RightShoulder"]]]["name"]
    rotate_branch(rig, pose, chest, rot("Y", yaw) @ rot("X", -.35 * bend))
    rotate_branch(rig, pose, "neck", rot("X", neck) @ rot("Y", -.5 * yaw))
    return pose


def measure(d, b, rig, pose, triangles, share):
    right = m.mask_for(d, b, rig, pose, "Right")
    left = m.mask_for(d, b, rig, pose, "Left")
    points, _, _ = m.skin(d, b, rig, pose)
    distance = BVHTree.FromPolygons(points, triangles, all_triangles=True).find_nearest(m.EYE)[3]
    y = .72 + .56 * share
    z = -2.05 - (-.35 + .103 * (y - .75)) + .03
    neighbours = m.project(np.array(list(product((-.34, -.17, .17, .34), (y,), (z,)))))
    hits = sum(
        bool((right | left)[int(py), int(px)])
        for px, py, depth in neighbours
        if depth > .03 and 0 <= px < 2400 and 0 <= py < 1080
    )
    return {
        "share": share,
        "right_pixels": int(right.sum()),
        "left_pixels": int(left.sum()),
        "table_pixels": int((right | left)[190:669, 1660:2361].sum()),
        "neighbour_centres": hits,
        "clearance_m": distance,
    }


def scan(sex):
    d, b = read(m.REPO / "models" / ("ekipazh-" + sex + ".glb"))
    rig, base = m.sample(d, b, "PostIdle")
    triangles = accessor(d, b, d["meshes"][0]["primitives"][0]["indices"]).astype(int).reshape(-1, 3)
    wrist = rig.names["RightHand"]
    all_poses = []
    for bend, yaw, distance, pole in product(
        (.35, .5, .65, .8, .95, 1.1, 1.25, 1.4), (-.65, -.35, 0, .35, .65),
        (.15, .2, .22, .24, .25, .3, .35, .4, .45), ((0, -1, 0), (.5, -1, .2), (-.5, -1, .2)),
    ):
        torso = upper_body(rig, base, bend, yaw, .4 * bend)
        try:
            poses = [m.solve(rig, torso, share, pole=Vector(pole), distance=distance) for share in SHARES]
        except ValueError:
            continue
        for pose in poses:
            pose[wrist] = mat(rig.rest[wrist].to_3x3(), pose[wrist].translation)
        # The elbow farther from the camera tends to occupy fewer screen pixels.
        elbow = rig.names["RightForeArm"]
        shoulder = rig.names["RightArm"]
        depth = min((pose[elbow].translation - m.EYE).length for pose in poses)
        depth += min((pose[shoulder].translation - m.EYE).length for pose in poses)
        parameters = dict(bend=bend, yaw=yaw, wrist_distance_m=distance, pole=pole)
        all_poses.append((depth, parameters, poses))
    print(sex, "reachable", len(all_poses), flush=True)
    # A neck-only change keeps arm reach intact. Screen for camera clearance at
    # mid-travel before rasterizing the three slider samples.
    cleared = []
    max_clearance = 0.0
    for depth, parameters, poses in all_poses:
        for neck in (-.5, -.25, 0, .25, .5, .75):
            bend, yaw = (parameters[key] for key in ("bend", "yaw"))
            rotation = rot("X", neck) @ rot("X", -.4 * bend)
            adjusted = [pose.copy() for pose in poses]
            for pose in adjusted:
                rotate_branch(rig, pose, "neck", rotation)
            points, _, _ = m.skin(d, b, rig, adjusted[1])
            clearance = BVHTree.FromPolygons(points, triangles, all_triangles=True).find_nearest(m.EYE)[3]
            max_clearance = max(max_clearance, clearance)
            if clearance >= .1:
                cleared.append((depth, dict(parameters, neck=neck), adjusted))
    print(sex, "clear at midpoint", len(cleared), "max", max_clearance, flush=True)
    rows = []
    for _, parameters, poses in heapq.nlargest(24, cleared or all_poses, key=lambda entry: entry[0]):
        samples = [measure(d, b, rig, pose, triangles, share) for share, pose in zip(SHARES, poses)]
        result = {"parameters": parameters, "samples": samples}
        rows.append(result)
        if all(
            sample["right_pixels"] <= 648000 and sample["left_pixels"] == 0
            and sample["table_pixels"] == 0 and sample["neighbour_centres"] == 0
            and sample["clearance_m"] >= .1 for sample in samples
        ):
            print(sex, "candidate", json.dumps(result), flush=True)
    return {"reachable_count": len(all_poses), "clear_at_midpoint": len(cleared), "max_midpoint_clearance_m": max_clearance, "tested": rows}


if __name__ == "__main__":
    results = {sex: scan(sex) for sex in ("muzhchina", "zhenshchina")}
    (m.ROOT / "spine-sweep-20261125.json").write_text(json.dumps(results, indent=2) + "\n")
