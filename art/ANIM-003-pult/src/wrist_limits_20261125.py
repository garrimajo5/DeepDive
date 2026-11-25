"""Check whether the refined diagnostics still pass when wrist flexion is limited."""

from pathlib import Path
import json
import math
import sys

sys.path.insert(0, str(Path(__file__).parent))
from planted_refine_20261125 import SHARES, accessor, m, make_poses, mat, measure, passes, read


def limit_wrist(rig, pose, maximum):
    wrist = rig.names["RightHand"]
    forearm = rig.names["RightForeArm"]
    neutral = (pose[forearm] @ rig.local[wrist]).to_quaternion()
    current = pose[wrist].to_quaternion()
    deviation = neutral.rotation_difference(current).angle
    deviation = min(deviation, 2 * math.pi - deviation)
    if deviation > maximum:
        corrected = neutral.slerp(current, maximum / deviation)
        pose[wrist] = mat(corrected.to_matrix(), pose[wrist].translation)
    return math.degrees(deviation)


def check(sex, data):
    doc, binary = read(m.REPO / "models" / f"ekipazh-{sex}.glb")
    rig, base = m.sample(doc, binary, "PostIdle")
    primitive = doc["meshes"][0]["primitives"][0]
    triangles = accessor(doc, binary, primitive["indices"]).astype(int).reshape(-1, 3)
    rows = []
    for candidate in data["results"]:
        if not candidate["passes"]:
            continue
        for maximum in (30, 45, 60):
            poses = make_poses(rig, base, candidate["values"])
            deviations = [limit_wrist(rig, pose, math.radians(maximum)) for pose in poses.values()]
            result = [measure(doc, binary, rig, poses[share], triangles, share) for share in SHARES]
            rows.append({
                "values": candidate["values"], "maximum_deviation_deg": maximum,
                "unconstrained_deviation_deg": deviations, "samples": result, "passes": passes(result),
            })
    print(sex, len(rows), "passed", sum(row["passes"] for row in rows), flush=True)
    return rows


if __name__ == "__main__":
    report = json.loads((m.ROOT / "planted-refine-20261125.json").read_text())
    result = {sex: check(sex, data) for sex, data in report.items()}
    (m.ROOT / "wrist-limits-20261125.json").write_text(json.dumps(result, indent=2) + "\n")
