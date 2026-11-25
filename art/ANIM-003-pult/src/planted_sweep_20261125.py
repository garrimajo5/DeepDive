"""Search ANIM-003 slider poses with planted feet and bounded pelvis movement."""

from pathlib import Path
import json
import math
import sys

sys.path.insert(0, str(Path(__file__).parent))
from gltf_support import Matrix, Vector, accessor, mat, np, read, rot, turn
from spine_sweep_20261125 import BVHTree, m, measure, reference, upper_body

SHARES = (0, .25, .5, .75, 1)
PIXEL_LIMIT = 648000
CLEARANCE_LIMIT = .1


def planted_pose(rig, base, shift, bend, yaw, neck):
    pose = {joint: Matrix.Translation(shift) @ value for joint, value in base.items()}
    for side in ("Left", "Right"):
        thigh, shin, foot, toe = [rig.names[side + name] for name in ("UpLeg", "Leg", "Foot", "ToeBase")]
        origin = pose[thigh].translation
        old_hip, old_knee, ankle = [base[j].translation for j in (thigh, shin, foot)]
        old_axis = (ankle - old_hip).normalized()
        old_pole = (old_knee - old_hip).project(old_axis) - (old_knee - old_hip)
        old_pole.negate()
        upper_length = (old_knee - old_hip).length
        lower_length = (ankle - old_knee).length
        reach = (ankle - origin).length
        if not abs(upper_length - lower_length) < reach < upper_length + lower_length:
            return None
        axis = (ankle - origin).normalized()
        pole = (old_pole - old_pole.project(axis)).normalized()
        along = (upper_length**2 - lower_length**2 + reach**2) / (2 * reach)
        knee = origin + axis * along + pole * math.sqrt(upper_length**2 - along**2)
        pose[thigh] = mat(
            turn(old_knee - old_hip, old_pole, knee - origin, pole) @ base[thigh].to_3x3(), origin
        )
        pose[shin] = mat(
            turn(ankle - old_knee, old_pole, ankle - knee, pole) @ base[shin].to_3x3(), knee
        )
        pose[foot], pose[toe] = base[foot], base[toe]
    return upper_body(rig, pose, bend, yaw, neck)


def panel_points(share):
    y = .72 + .56 * share
    z = -2.05 - (-.35 + .103 * (y - .75)) + .03
    return m.project(np.array([[x, y, z] for x in (-.34, -.17, .17, .34)]))[:, :2]


def passes(samples):
    return all(
        row["right_pixels"] <= PIXEL_LIMIT and row["left_pixels"] == 0
        and row["table_pixels"] == 0 and row["neighbour_centres"] == 0
        and row["clearance_m"] >= CLEARANCE_LIMIT for row in samples
    )


def search(sex, trials):
    doc, binary = read(m.REPO / "models" / f"ekipazh-{sex}.glb")
    rig, base = m.sample(doc, binary, "PostIdle")
    primitive = doc["meshes"][0]["primitives"][0]
    triangles = accessor(doc, binary, primitive["indices"]).astype(int).reshape(-1, 3)
    _, weights, joints = m.skin(doc, binary, rig, base)
    arm_joints = [
        rig.j.index(rig.names["Right" + name]) for name in ("Shoulder", "Arm", "ForeArm", "Hand")
    ]
    arm_weights = np.sum(weights * np.isin(joints, arm_joints), axis=1)
    arm_triangles = triangles[arm_weights[triangles].mean(axis=1) > .5]
    neighbours = {share: panel_points(share) for share in SHARES}
    rng = np.random.default_rng(727)
    wrist = rig.names["RightHand"]
    reachable = clear = no_centres = 0
    best_clearance = 0.0
    shortlist = []
    for trial in range(trials):
        shift = Vector((rng.uniform(-.10, .10), rng.uniform(-.13, -.015), rng.uniform(-.12, .065)))
        bend, yaw, neck = rng.uniform((.15, -.65, -.55), (1.15, .85, .85))
        wrist_yaw, wrist_roll = rng.uniform((-1.4, -1.1), (1.4, 1.3))
        distance = rng.uniform(.16, .4)
        pole = Vector((rng.uniform(-1, 1), -1, rng.uniform(-.6, .7)))
        torso = planted_pose(rig, base, shift, bend, yaw, neck)
        if torso is None:
            continue
        poses = {}
        try:
            for share in SHARES:
                pose = m.solve(rig, torso, share, pole=pole, distance=distance)
                orientation = rot("Z", wrist_roll) @ rot("Y", wrist_yaw) @ rig.rest[wrist].to_3x3()
                pose[wrist] = mat(orientation, pose[wrist].translation)
                poses[share] = pose
        except ValueError:
            continue
        reachable += 1

        points, _, _ = m.skin(doc, binary, rig, poses[.5])
        clearance = BVHTree.FromPolygons(points, triangles, all_triangles=True).find_nearest(m.EYE)[3]
        best_clearance = max(clearance, best_clearance)
        if clearance < CLEARANCE_LIMIT:
            continue
        clear += 1

        occluded = sum(reference.hits(points, arm_triangles, neighbours[.5]))
        for share in (0, 1):
            points, _, _ = m.skin(doc, binary, rig, poses[share])
            occluded += sum(reference.hits(points, arm_triangles, neighbours[share]))
        no_centres += occluded == 0
        parameters = {
            "shift_xyz_m": list(shift), "bend_rad": bend, "chest_yaw_rad": yaw,
            "neck_rad": neck, "wrist_yaw_rad": wrist_yaw, "wrist_roll_rad": wrist_roll,
            "distance_m": distance, "pole": list(pole),
        }
        rank = (occluded, bend + 2 * shift.length, trial)
        shortlist.append((rank, parameters, poses))

    print(sex, "reachable", reachable, "clear", clear, "clear and centres", no_centres, flush=True)
    tested = []
    for rank, parameters, poses in sorted(shortlist, key=lambda entry: entry[0])[:12]:
        samples = [measure(doc, binary, rig, pose, triangles, share) for share, pose in poses.items()]
        row = {"parameters": parameters, "samples": samples, "passes_diagnostic": passes(samples)}
        tested.append(row)
        if row["passes_diagnostic"]:
            print(sex, "candidate", json.dumps(parameters), flush=True)
    return {
        "trials": trials, "reachable": reachable, "clear_at_midpoint": clear,
        "clear_at_midpoint_and_unoccluded_centres_at_0_50_100": no_centres,
        "max_midpoint_clearance_m": best_clearance, "measured": tested,
    }


if __name__ == "__main__":
    trials = int(sys.argv[-1]) if "--" in sys.argv else 3600
    report = {sex: search(sex, trials) for sex in ("muzhchina", "zhenshchina")}
    (m.ROOT / "planted-sweep-20261125.json").write_text(json.dumps(report, indent=2) + "\n")
