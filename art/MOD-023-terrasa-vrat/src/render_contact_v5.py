import bpy,math,pathlib
from mathutils import Vector
p=pathlib.Path(r'C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-023-terrasa-vrat')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(p/'terrasa-draft-v5.glb'))
for o in bpy.context.scene.objects:
 if o.type=='MESH' and o.name in ('LOD1_Mineral','LOD2_Mineral'):o.hide_render=True
bpy.ops.object.camera_add(location=(50,-30,6));c=bpy.context.object;c.rotation_euler=(Vector((50,-9,3))-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=12;bpy.context.scene.camera=c
bpy.ops.object.light_add(type='AREA',location=(0,-70,90));l=bpy.context.object;l.data.energy=150000;l.data.shape='DISK';l.data.size=100;l.rotation_euler=(Vector((0,0,25))-l.location).to_track_quat('-Z','Y').to_euler()
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8;s.render.resolution_x=1000;s.render.resolution_y=600;s.render.resolution_percentage=100;s.render.filepath=str(p/'contact-v5.png');bpy.ops.render.render(write_still=True)

