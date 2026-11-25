"""Render the middle pose of the strongest ANIM-003 planted-foot candidate."""

from pathlib import Path
import json
import math
import sys

sys.path.insert(0, str(Path(__file__).parent))
import bpy
from gltf_support import Vector, append, write
from planted_refine_20261125 import m, make_poses, read
from wrist_limits_20261125 import limit_wrist


def rank(row):
    samples = row["samples"]
    return (
        not row["passes"],
        sum(sample["neighbour_centres"] for sample in samples),
        sum(sample["clearance_m"] < .1 for sample in samples),
        max(sample["right_pixels"] for sample in samples),
    )


def render(sex, result, scratch):
    document, binary = read(m.REPO / "models" / f"ekipazh-{sex}.glb")
    rig, base = m.sample(document, binary, "PostIdle")
    pose = make_poses(rig, base, result["values"])[.5]
    if "maximum_deviation_deg" in result:
        limit_wrist(rig, pose, math.radians(result["maximum_deviation_deg"]))
    action = {"name": "PlantedDiagnostic", "samplers": [], "channels": []}
    timestamps = append(document, binary, [[0], [1 / 30]], "SCALAR")
    for joint in rig.j:
        local = pose[rig.parent[joint]].inverted() @ pose[joint]
        q = local.to_quaternion()
        for path, value, shape in (
            ("rotation", [q.x, q.y, q.z, q.w], "VEC4"),
            ("translation", list(local.translation), "VEC3"),
        ):
            output = append(document, binary, [value, value], shape)
            action["channels"].append(
                {"sampler": len(action["samplers"]), "target": {"node": joint, "path": path}}
            )
            action["samplers"].append({"input": timestamps, "output": output, "interpolation": "LINEAR"})
    document["animations"].append(action)
    glb = scratch / f"{sex}-planted-diagnostic.glb"
    write(glb, document, binary)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    scene.render.resolution_x, scene.render.resolution_y = 900, 700
    scene.render.image_settings.file_format = "JPEG"
    scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (.15, .19, .23, 1)
    background.inputs[1].default_value = .75
    bpy.ops.import_scene.gltf(filepath=str(glb))
    armature = next(o for o in scene.objects if o.type == "ARMATURE")
    clip = next(a for a in bpy.data.actions if "PlantedDiagnostic" in a.name)
    armature.animation_data.action = clip
    armature.animation_data.action_slot = clip.slots[0]
    scene.frame_set(1)

    bpy.ops.object.camera_add(location=(2.5, 1.9, 1.28))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, .38, .9)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.3
    scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(1, 2, 3))
    light = bpy.context.object
    light.data.energy, light.data.size = 350, 3
    light.rotation_euler = (Vector((0, 0, 1)) - light.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(scratch / f"{sex}-planted-side.jpg")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    report = json.loads((m.ROOT / "planted-refine-20261125.json").read_text())
    scratch = m.ROOT / "local"
    scratch.mkdir(exist_ok=True)
    limited = json.loads((m.ROOT / "wrist-limits-20261125.json").read_text())
    for sex, data in report.items():
        good = [row for row in limited[sex] if row["passes"]]
        if good:
            result = min(good, key=lambda row: (row["maximum_deviation_deg"], rank(row)))
            render(sex, result, scratch)
            continue
        render(sex, min(data["results"], key=rank), scratch)
