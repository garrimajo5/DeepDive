import bpy,math,sys,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'renders';out.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene;sc.render.fps=30
sc.render.engine='CYCLES';sc.cycles.samples=16;sc.cycles.use_denoising=True
sc.render.resolution_x=440;sc.render.resolution_y=520;sc.render.resolution_percentage=100
sc.world=bpy.data.worlds.new('World');sc.world.use_nodes=True
sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.11,.15,1)
sc.world.node_tree.nodes['Background'].inputs[1].default_value=.5
sc.view_settings.view_transform='AgX'
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.006));floor=bpy.context.object
ma=bpy.data.materials.new('floor');ma.diffuse_color=(.055,.075,.09,1);floor.data.materials.append(ma)
def area(loc,power,size):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
area((-3,-4,5),450,4);area((3,1,3),550,3)
bpy.ops.object.camera_add();cam=bpy.context.object;sc.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.15
def camera(view):
 cam.location=(3,5,2.5) if view=='three' else (4,0,1.4) if view=='side' else (0,-5,1.2) if view=='back' else (0,5,1.2)
 cam.rotation_euler=(Vector((0,0,.9))-cam.location).to_track_quat('-Z','Y').to_euler()
base=set(bpy.data.objects)
for sex in ['muzhchina','zhenshchina']:
 bpy.ops.import_scene.gltf(filepath=str(ROOT/('ekipazh-'+sex+'.glb')))
 added=set(bpy.data.objects)-base;arm=next(o for o in added if o.type=='ARMATURE')
 for o in added:
  if o.type=='MESH' and not o.vertex_groups:o.hide_render=True
 ad=arm.animation_data
 actions={t.name:t.strips[0].action for t in ad.nla_tracks}
 ad.use_nla=False
 ad.action=None
 for bone in arm.pose.bones:bone.matrix_basis.identity()
 for view in ['front','side','back']:
  camera(view);bpy.context.view_layer.update();sc.render.filepath=str(out/(sex+'-rest-'+view+'.png'));bpy.ops.render.render(write_still=True)
 for clip,count in [('Idle',120),('Walk',24),('SitIdle',120),('PostIdle',120)]:
  ad.action=actions[clip]
  for f in [0,count//4,count//2,count*3//4]:
   for view in ['three','side']:
    camera(view);sc.frame_set(f+1);sc.render.filepath=str(out/(sex+'-'+clip+'-'+str(f)+'-'+view+'.png'));bpy.ops.render.render(write_still=True)
  if clip in ['Walk','Idle']:
   for f in range(0,count,1 if clip=='Walk' else 6):
    camera('three');sc.frame_set(f+1);sc.render.filepath=str(out/(sex+'-'+clip+'-'+str(f)+'-three.png'));bpy.ops.render.render(write_still=True)
 for o in added:bpy.data.objects.remove(o,do_unlink=True)
print('RENDER_OK')
