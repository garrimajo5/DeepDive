"""Refine the planted-foot poses on the five slider phases."""

from pathlib import Path
import json
import sys

sys.path.insert(0, str(Path(__file__).parent))
from planted_sweep_20261125 import (
    BVHTree, SHARES, Vector, accessor, m, mat, measure, np, panel_points,
    passes, planted_pose, read, reference, rot,
)


def unpack(values):
    shift = Vector(values[:3])
    bend, yaw, neck, distance, hand_yaw, hand_roll, pole_x, pole_z = values[3:]
    return shift, bend, yaw, neck, distance, hand_yaw, hand_roll, Vector((pole_x, -1, pole_z))


def pack(parameters):
    p = parameters
    return [
        *p["shift_xyz_m"], p["bend_rad"], p["chest_yaw_rad"], p["neck_rad"],
        p["distance_m"], p["wrist_yaw_rad"], p["wrist_roll_rad"], p["pole"][0], p["pole"][2],
    ]


def make_poses(rig, base, parameters):
    shift, bend, yaw, neck, distance, hand_yaw, hand_roll, pole = unpack(parameters)
    torso = planted_pose(rig, base, shift, bend, yaw, neck)
    if torso is None:
        return None
    wrist = rig.names["RightHand"]
    orientation = rot("Z", hand_roll) @ rot("Y", hand_yaw) @ rig.rest[wrist].to_3x3()
    poses = {}
    for share in SHARES:
        try:
            pose = m.solve(rig, torso, share, pole=pole, distance=distance)
        except ValueError:
            return None
        pose[wrist] = mat(orientation, pose[wrist].translation)
        poses[share] = pose
    return poses


def refine(sex, starting_rows):
    doc, binary = read(m.REPO / "models" / f"ekipazh-{sex}.glb")
    rig, base = m.sample(doc, binary, "PostIdle")
    primitive = doc["meshes"][0]["primitives"][0]
    triangles = accessor(doc, binary, primitive["indices"]).astype(int).reshape(-1, 3)
    _, weights, joints = m.skin(doc, binary, rig, base)
    arm_joints = [rig.j.index(rig.names["Right" + name]) for name in ("Shoulder", "Arm", "ForeArm", "Hand")]
    arm_weights = np.sum(weights * np.isin(joints, arm_joints), axis=1)
    arm_triangles = triangles[arm_weights[triangles].mean(axis=1) > .5]
    neighbours = {share: panel_points(share) for share in SHARES}
    att = primitive["attributes"]
    bind = accessor(doc, binary, doc["skins"][0]["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    coords = accessor(doc, binary, att["POSITION"])
    homog = np.column_stack((coords, np.ones(len(coords))))
    spread = np.array([.022, .026, .025, .10, .14, .20, .035, .38, .37, .24, .24])
    lo = [-.12, -.17, -.15, .15, -.7, -.7, .17, -1.8, -1.6, -1.5, -1.3]
    hi = [ .12, -.015, .065, 1.2, 1.2, .9, .45, 1.8, 1.6, 1.5, 1.3]
    rng = np.random.default_rng(25)
    pool = []
    shortlisted = []
    evaluations = 0
    for iteration in range(3500):
        if iteration < len(starting_rows):
            values = np.array(pack(starting_rows[iteration]["parameters"]))
        else:
            parent = pool[rng.integers(0, len(pool))][2]
            factor = rng.choice((.25, .55, 1, 1.65))
            values = np.clip(parent + rng.normal(size=len(parent)) * spread * factor, lo, hi)
        poses = make_poses(rig, base, values)
        if poses is None:
            continue
        hits, min_clearance = 0, 1.0
        for share, pose in poses.items():
            transforms = np.array([np.array(pose[joint]) for joint in rig.j]) @ bind
            points = sum(
                weights[:, i, None] * np.einsum("nij,nj->ni", transforms[joints[:, i]], homog)
                for i in range(4)
            )[:, :3]
            hits += sum(reference.hits(points, arm_triangles, neighbours[share]))
            min_clearance = min(
                min_clearance, BVHTree.FromPolygons(points, triangles, all_triangles=True).find_nearest(m.EYE)[3]
            )
        evaluations += 1
        penalty = hits + 500 * max(.105 - min_clearance, 0)
        style = abs(values[3]) + abs(values[4]) + 4 * np.linalg.norm(values[:3])
        entry = (penalty + .1 * style, iteration, values)
        pool = sorted([*pool, entry], key=lambda row: row[:2])[:24]
        if hits == 0 and min_clearance >= .1:
            shortlisted.append((style, iteration, values))
    print(sex, "feasible arm/keypoint/clearance", len(shortlisted), "evaluated", evaluations, flush=True)
    finalists = sorted(shortlisted or pool, key=lambda row: row[:2])[:10]
    results = []
    for _, _, values in finalists:
        poses = make_poses(rig, base, values)
        samples = [measure(doc, binary, rig, pose, triangles, share) for share, pose in poses.items()]
        results.append({"values": values.tolist(), "samples": samples, "passes": passes(samples)})
    print(sex, "full diagnostic passed", sum(row["passes"] for row in results), flush=True)
    return {"evaluated": evaluations, "shortlisted": len(shortlisted), "results": results}


if __name__ == "__main__":
    source = json.loads((m.ROOT / "planted-sweep-20261125.json").read_text())
    results = {sex: refine(sex, rows["measured"]) for sex, rows in source.items()}
    (m.ROOT / "planted-refine-20261125.json").write_text(json.dumps(results, indent=2) + "\n")
