"""Check whether more reach at the top preserves the grip geometry."""
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from neutral_wrist_20261127 import BVHTree, SHARES, accessor, m, make_poses, measure, passes, read

source = json.loads((m.ROOT / "neutral-wrist-20261127.json").read_text())
results = {}
for sex, report in source.items():
    doc, binary = read(m.REPO / "models" / f"ekipazh-{sex}.glb")
    rig, base = m.sample(doc, binary, "PostIdle")
    triangles = accessor(doc, binary, doc["meshes"][0]["primitives"][0]["indices"]).astype(int).reshape(-1, 3)
    rows = []
    candidates = [row for row in report["tested"] if "samples" in row and all(
        item["neighbour_centres"] == 0 and item["table_pixels"] == 0
        and item["left_pixels"] == 0 and item["right_pixels"] <= 648000
        for item in row["samples"])]
    for row in candidates:
        for extension in (.01, .02, .03, .04, .05):
            poses = {}
            for share in SHARES:
                values = row["values"][:]
                values[6] += max(0, (share - .5) * 2) ** 2 * extension
                item = make_poses(rig, base, values, (share,))
                if item is None:
                    break
                poses.update(item)
            if len(poses) != len(SHARES):
                continue
            points, _, _ = m.skin(doc, binary, rig, poses[1])
            top_clearance = BVHTree.FromPolygons(points, triangles, all_triangles=True).find_nearest(m.EYE)[3]
            if top_clearance < .1:
                rows.append({"values": row["values"], "extension_m": extension, "top_clearance_m": top_clearance, "passes": False})
                continue
            samples = [measure(doc, binary, rig, pose, triangles, share) for share, pose in poses.items()]
            rows.append({"values": row["values"], "extension_m": extension, "samples": samples, "passes": passes(samples)})
    results[sex] = rows
    print(sex, len(rows), "passing", sum(row["passes"] for row in rows), flush=True)
(m.ROOT / "upper-reach-20261127.json").write_text(json.dumps(results, indent=2) + "\n")
