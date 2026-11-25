"""Separate forearm roll from wrist bending without moving reach points."""
from pathlib import Path
import json
import math
import sys

sys.path.insert(0, str(Path(__file__).parent))
from gltf_support import Quaternion
from planted_refine_20261125 import SHARES, accessor, m, make_poses, mat, measure, passes, read


def forearm_roll(rig, pose):
    wrist, forearm = (rig.names[name] for name in ("RightHand", "RightForeArm"))
    axis = (pose[wrist].translation - pose[forearm].translation).normalized()
    neutral = (pose[forearm] @ rig.local[wrist]).to_quaternion()
    target = pose[wrist].to_quaternion()
    difference = target @ neutral.inverted()
    component = difference.x * axis.x + difference.y * axis.y + difference.z * axis.z
    angle = 2 * math.atan2(component, difference.w)
    return (angle + math.pi) % (2 * math.pi) - math.pi


def apply_roll(rig, pose, amount):
    wrist, forearm = (rig.names[name] for name in ("RightHand", "RightForeArm"))
    axis = (pose[wrist].translation - pose[forearm].translation).normalized()
    correction = Quaternion(axis, amount * forearm_roll(rig, pose))
    rotation = correction @ pose[forearm].to_quaternion()
    pose[forearm] = mat(rotation.to_matrix(), pose[forearm].translation)


def check(sex, data):
    doc, binary = read(m.REPO / "models" / f"ekipazh-{sex}.glb")
    rig, base = m.sample(doc, binary, "PostIdle")
    triangles = accessor(doc, binary, doc["meshes"][0]["primitives"][0]["indices"]).astype(int).reshape(-1, 3)
    wrist, forearm = (rig.names[name] for name in ("RightHand", "RightForeArm"))
    results = []
    for candidate in data["results"]:
        if not candidate["passes"]:
            continue
        for amount in (.65, .85, 1):
            poses = make_poses(rig, base, candidate["values"])
            deviations = []
            rolls = []
            for pose in poses.values():
                rolls.append(math.degrees(forearm_roll(rig, pose)))
                apply_roll(rig, pose, amount)
                neutral = (pose[forearm] @ rig.local[wrist]).to_quaternion()
                delta = neutral.rotation_difference(pose[wrist].to_quaternion()).angle
                deviations.append(math.degrees(min(delta, 2 * math.pi - delta)))
            samples = [measure(doc, binary, rig, poses[share], triangles, share) for share in SHARES]
            results.append({
                "values": candidate["values"], "forearm_roll_fraction": amount, "roll_deg": rolls,
                "residual_wrist_deg": deviations, "samples": samples, "passes": passes(samples),
            })
    print(sex, "passed", sum(row["passes"] for row in results), flush=True)
    return results


if __name__ == "__main__":
    report = json.loads((m.ROOT / "planted-refine-20261125.json").read_text())
    result = {sex: check(sex, data) for sex, data in report.items()}
    (m.ROOT / "forearm-roll-20261125.json").write_text(json.dumps(result, indent=2) + "\n")
