"""Side preview of the exported v2 GLB (not the authoring scene)."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
root=Path.cwd();out=root/'art/ANIM-001-serpohvost';tmp=root.parent/'serp-strike-v2';tmp.mkdir(exist_ok=True)
bpy.ops.import_scene.gltf(filepath=str(out/'serpohvost-animated-v2.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for t in rig.animation_data.nla_tracks:t.mute=True
act=next(a for a in bpy.data.actions if a.name.startswith('TailStrike'))
rig.animation_data.action=act
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=12;s.cycles.use_denoising=True;s.render.fps=30
s.render.resolution_x=640;s.render.resolution_y=360;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new('Water');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.09,.11,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.55;s.view_settings.view_transform='AgX'
for name,loc,power,size,color in [('Key',(2,2,6),1800,7,(.69,.86,1)),('Rim',(-3,-3,4),1500,5,(.3,.75,1)),('Fill',(5,-2,1),600,5,(.8,.9,1))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,-1,0))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Side');cam=bpy.data.objects.new('Side',d);s.collection.objects.link(cam);s.camera=cam;d.type='ORTHO';d.ortho_scale=7.6;cam.location=(9,-1,1.6);cam.rotation_euler=(Vector((0,-1.1,-.15))-cam.location).to_track_quat('-Z','Y').to_euler()
for i in range(10):
 s.frame_set(i*2);s.render.filepath=str(tmp/f'{i:02}.png');bpy.ops.render.render(write_still=True)
