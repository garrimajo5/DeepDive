import bpy,json,math
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30;bpy.ops.import_scene.gltf(filepath=str(P/'kupolnik-anim.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
print('ACTIONS',[(a.name,list(a.frame_range)) for a in bpy.data.actions]);print('MESH',len(mesh.data.vertices),len(rig.data.bones))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.render.resolution_x=640;scene.render.resolution_y=480;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.fps=30
scene.world=bpy.data.worlds.new('Studio');scene.world.color=(.07,.07,.07)
bpy.ops.object.camera_add(location=(4,5,3));cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=3.9
for loc,power,size in [((1,3,5),1100,5),((-3,0,2),650,4),((0,-3,4),1300,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
# Visible metre ruler in every view: a 1 m bar along X in front of animal.
def rod(a,b,r=.008):
 d=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=r,depth=d.length,location=(Vector(a)+Vector(b))/2);obj=bpy.context.object;obj.rotation_euler=d.to_track_quat('Z','Y').to_euler()
rod((-.5,1.8,-.08),(.5,1.8,-.08))
for i in range(11):x=-.5+i*.1;rod((x,1.76,-.08),(x,1.84,-.08),.004)
(P/'renders').mkdir(exist_ok=True)
def render(label,action,frame,loc):
 cam.data.ortho_scale=4.6 if label=='preview-top.png' else 3.9;rig.animation_data.action=next(a for a in bpy.data.actions if a.name==action or a.name.endswith('|'+action));scene.frame_set(frame);cam.location=loc;cam.rotation_euler=(Vector((0,.1,.5))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(P/'renders'/label);bpy.ops.render.render(write_still=True)
for name,loc in [('front',(0,6,2)),('side',(6,0,2)),('top',(0,0,7))]:render('preview-'+name+'.png','Idle',0,loc)
import sys
if '--preview-only' in sys.argv:raise SystemExit
for action,n in [('Idle',120),('Swim',90),('OpenPetal',150)]:
 for k in range(4):render(action+'-'+str(k)+'.png',action,round(n*k/4),(4,5,2.8))
scene.render.resolution_x=480;scene.render.resolution_y=360
for k in range(31):render('gif-'+str(k).zfill(2)+'.png','OpenPetal',k*5,(4,5,2.8))

rig.animation_data_clear()
for b in rig.pose.bones:b.matrix_basis.identity()
for side in 'LMR':
 b=rig.pose.bones['Grasp'+side+'Lower'];b.rotation_mode='XYZ';b.rotation_euler.x=math.radians(60)
bpy.context.view_layer.update();scene.render.resolution_x=640;scene.render.resolution_y=480;scene.render.filepath=str(P/'renders'/'stress60.png');bpy.ops.render.render(write_still=True)
