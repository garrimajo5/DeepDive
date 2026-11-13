import bpy,sys,math
from pathlib import Path
from mathutils import Vector
out=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8;s.render.resolution_x=1200;s.render.resolution_y=600;s.render.resolution_percentage=100;s.render.image_settings.file_format='JPEG';s.render.fps=60
bpy.ops.import_scene.gltf(filepath=str(out/'serpohvost-study-v2.glb'));arm=next(o for o in s.objects if o.type=='ARMATURE');act=next(a for a in bpy.data.actions if 'TailStrike' in a.name);arm.animation_data.action=act;arm.animation_data.action_slot=act.slots[0];s.frame_set(33)
s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.07,.12,.16,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.camera_add(location=(9,-1,2));cam=bpy.context.object;cam.rotation_euler=(Vector((0,-1,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=7.5;s.camera=cam
bpy.ops.object.light_add(type='AREA',location=(3,0,5));light=bpy.context.object;light.data.energy=1500;light.data.size=6;light.rotation_euler=(Vector((0,-1,0))-light.location).to_track_quat('-Z','Y').to_euler()
s.render.filepath=str(out/'study-v2-strike.jpg');bpy.ops.render.render(write_still=True)
print('IMPORT',len(arm.data.bones),[a.name for a in bpy.data.actions],[(o.name,len(o.data.polygons)) for o in s.objects if o.type=='MESH'])
