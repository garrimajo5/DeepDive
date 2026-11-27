"""Find panel poses with bounded wrist articulation from the start."""
from pathlib import Path
import json
import math
import sys

sys.path.insert(0, str(Path(__file__).parent))

from gltf_support import Quaternion
from planted_refine_20261125 import (
    BVHTree, SHARES, Vector, accessor, m, mat, measure, np, pack,
    panel_points, passes, planted_pose, read, reference, unpack,
)


def make_poses(rig, base, values, shares=SHARES):
    shift, bend, yaw, neck, distance, pronation, flexion, pole = unpack(values)
    torso = planted_pose(rig, base, shift, bend, yaw, neck)
    if torso is None:
        return None
    arm, forearm, wrist = (rig.names[name] for name in ("RightArm", "RightForeArm", "RightHand"))
    poses = {}
    for share in shares:
        try:
            pose = m.solve(rig, torso, share, pole=pole, distance=distance)
        except ValueError:
            return None
        across = (pose[forearm].translation - pose[arm].translation).cross(
            pose[wrist].translation - pose[forearm].translation
        ).normalized()
        axis = (pose[wrist].translation - pose[forearm].translation).normalized()
        roll = Quaternion(axis, pronation)
        tilted_forearm = roll @ pose[forearm].to_quaternion()
        pose[forearm] = mat(tilted_forearm.to_matrix(), pose[forearm].translation)
        neutral_hand = tilted_forearm @ rig.local[wrist].to_quaternion()
        hand = Quaternion(roll @ across, flexion) @ neutral_hand
        pose[wrist] = mat(hand.to_matrix(), pose[wrist].translation)
        poses[share] = pose
    return poses


def search(sex, source_rows, previous_rows):
    doc, binary = read(m.REPO / "models" / f"ekipazh-{sex}.glb")
    rig, base = m.sample(doc, binary, "PostIdle")
    primitive = doc["meshes"][0]["primitives"][0]
    triangles = accessor(doc, binary, primitive["indices"]).astype(int).reshape(-1, 3)
    _, weights, joints = m.skin(doc, binary, rig, base)
    arm_joints = [rig.j.index(rig.names["Right" + name]) for name in ("Shoulder", "Arm", "ForeArm", "Hand")]
    arm_weights = np.sum(weights * np.isin(joints, arm_joints), axis=1)
    selected_triangles = triangles[arm_weights[triangles].mean(axis=1) > .5]
    selected, indices = np.unique(selected_triangles, return_inverse=True)
    arm_triangles = indices.reshape(-1, 3)
    att = primitive["attributes"]
    bind = accessor(doc, binary, doc["skins"][0]["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    coords = accessor(doc, binary, att["POSITION"])[selected]
    homog = np.column_stack((coords, np.ones(len(coords))))
    arm_weights, arm_influences = weights[selected], joints[selected]
    neighbours = {share: panel_points(share) for share in SHARES}
    lo = np.array([-.14, -.17, -.16, .15, -.7, -.7, .17, -1.25, -.52, -1.5, -1.3])
    hi = np.array([.14, -.015, .065, 1.2, 1.2, .9, .45, 1.25, .52, 1.5, 1.3])
    spread = np.array([.025, .027, .029, .12, .15, .19, .032, .38, .22, .27, .25])
    rng = np.random.default_rng(72727)
    seeds = [pack(row["parameters"]) for row in source_rows] + [row["values"] for row in previous_rows]
    pool = []
    reached = 0
    clear = 0
    for iteration in range(1850):
        if iteration < len(seeds):
            values = np.clip(seeds[iteration], lo, hi)
        else:
            parent = pool[rng.integers(len(pool))][2]
            values = np.clip(parent + rng.normal(size=len(parent)) * spread * rng.choice((.3, .7, 1.5)), lo, hi)
        poses = make_poses(rig, base, values, (0, .5, 1))
        if poses is None:
            continue
        reached += 1
        hits = 0
        for share, pose in poses.items():
            transforms = np.array([np.array(pose[joint]) for joint in rig.j]) @ bind
            points = sum(
                arm_weights[:, i, None] * np.einsum("nij,nj->ni", transforms[arm_influences[:, i]], homog)
                for i in range(4)
            )[:, :3]
            hits += sum(reference.hits(points, arm_triangles, neighbours[share]))
        clear += hits == 0
        style = .06 * (abs(values[3]) + abs(values[4]) + 3 * np.linalg.norm(values[:3]))
        # Favor low overlaps, keeping enough diversity to validate whole-body clearance later.
        entry = (hits + style, iteration, values)
        pool = sorted([*pool, entry], key=lambda row: row[:2])[:35]
    print(sex, "reachable", reached, "visible centres at 3 shares", clear, flush=True)
    tested = []
    for _, _, values in pool[:20]:
        poses = make_poses(rig, base, values)
        if poses is None:
            continue
        midpoint, _, _ = m.skin(doc, binary, rig, poses[.5])
        clearance = BVHTree.FromPolygons(midpoint, triangles, all_triangles=True).find_nearest(m.EYE)[3]
        if clearance < .10:
            tested.append({"values": values.tolist(), "midpoint_clearance_m": clearance, "passes": False})
            continue
        samples = [measure(doc, binary, rig, pose, triangles, share) for share, pose in poses.items()]
        tested.append({"values": values.tolist(), "samples": samples, "passes": passes(samples)})
    print(sex, "passes five phases", sum(row["passes"] for row in tested), flush=True)
    return {"reachable": reached, "visible_centres_at_three_shares": clear, "tested": tested}


if __name__ == "__main__":
    initial = json.loads((m.ROOT / "planted-sweep-20261125.json").read_text())
    previous = json.loads((m.ROOT / "planted-refine-20261125.json").read_text())
    result = {
        sex: search(sex, initial[sex]["measured"], previous[sex]["results"])
        for sex in ("muzhchina", "zhenshchina")
    }
    (m.ROOT / "neutral-wrist-20261127.json").write_text(json.dumps(result, indent=2) + "\n")
