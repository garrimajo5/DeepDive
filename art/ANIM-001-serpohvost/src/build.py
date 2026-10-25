"""Build ANIM-001 from accepted MOD-011. Blender 4.5 LTS; run from repository root.
Outputs only art/ANIM-001-serpohvost; working renders go to --work PATH.
"""
import bpy, math, json, sys, hashlib, argparse
from pathlib import Path
from mathutils import Vector, Quaternion
p=argparse.ArgumentParser();p.add_argument('--work',required=True);p.add_argument('--render',action='store_true');p.add_argument('--top-only',action='store_true')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);root=Path.cwd();out=root/'art/ANIM-001-serpohvost';tmp=Path(a.work).resolve();tmp.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
meshes=[]
for part,offset in [('telo',(0,0,0)),('hvost',(0,-1.8,-.19)),('chelyust',(0,.95,-.12))]:
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(root/'models'/f'serpohvost-{part}.glb'))
 for o in set(bpy.data.objects)-before:
  if o.type!='MESH':continue
  mat=o.matrix_world.copy();o.parent=None;o.matrix_world.identity()
  for v in o.data.vertices:v.co=mat@v.co+Vector(offset)
  o.name=part;meshes.append(o)
# Keep original pixels; deduplicate identical imported texture payloads.
seen={}
for img in list(bpy.data.images):
 if img.packed_file:
  key=hashlib.sha256(img.packed_file.data).hexdigest()
  if key in seen:
   for mat in bpy.data.materials:
    if mat.use_nodes:
     for node in mat.node_tree.nodes:
      if node.type=='TEX_IMAGE' and node.image==img:node.image=seen[key]
  else:seen[key]=img
# Rig uses Blender Z-up; glTF exporter converts to Godot Y-up, nose -Z.
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='SerpohvostRig'
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
def bone(name,head,tail,parent=None):
 b=rig.data.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=rig.data.edit_bones[parent]
 return b
bone('Root',(0,0,0),(0,.4,0))
bone('Body',(0,0,0),(0,.8,0),'Root')
for i,y in enumerate([-1.8,-2.5,-3.25]):bone(f'Tail{i+1:02}',(0,y,-.19),(0,y-.65,-.19),'Body' if i==0 else f'Tail{i:02}')
bone('Jaw',(0,.95,-.12),(0,1.5,-.12),'Body')
for side,s in [('L',-1),('R',1)]:
 for tag,y in [('Front',.25),('Rear',-1.05)]:bone(f'Fin{tag}{side}',(s*.34,y,-.12),(s*.85,y,-.18),'Body')
bpy.ops.object.mode_set(mode='OBJECT')
def smooth(v):v=max(0,min(1,v));return v*v*(3-2*v)
def tail_weights(z):
 centers=[1.8,2.5,3.25]
 if z<=centers[0]:return {'Tail01':1}
 if z>=centers[-1]:return {'Tail03':1}
 k=0 if z<centers[1] else 1;t=smooth((z-centers[k])/(centers[k+1]-centers[k]));return {f'Tail{k+1:02}':1-t,f'Tail{k+2:02}':t}
for obj in meshes:
 groups={b.name:obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
 for v in obj.data.vertices:
  x,y,h=v.co;z=-y;w={'Body':1}
  if obj.name=='chelyust':w={'Jaw':1}
  elif obj.name=='hvost':w=tail_weights(z)
  else:
   if z>1.05:
    t=smooth((z-1.05)/.7);w={'Body':1-t,'Tail01':t}
   # Fin tips only; smooth transition leaves trunk and dorsal fin rigid.
   if abs(x)>.38 and h<.1 and -.8<z<1.5:
    f=smooth((abs(x)-.38)/.45)*smooth((.1-h)/.18)
    name='Fin'+('Front' if y>-.4 else 'Rear')+('R' if x>0 else 'L')
    w={k:q*(1-f) for k,q in w.items()};w[name]=f
  for k,q in w.items():
   if q>1e-7:groups[k].add([v.index],q,'REPLACE')
 obj.parent=rig;mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig
# All clips in place, no gameplay trajectory/root motion.
scene=bpy.context.scene;scene.render.fps=30
clips=[('Swim',2.4,True),('SwimFast',1.2,True),('Bite',1.2,False),('TailStrike',.6,False)]
actions={}
def envelope(u,points):
 for (x,a),(y,b) in zip(points,points[1:]):
  if x<=u<=y:return a+(b-a)*smooth((u-x)/(y-x))
 return points[-1][1]
def pose(name,u):
 angles={b.name:0 for b in rig.data.bones};phase=2*math.pi*u
 if name.startswith('Swim'):
  fast=name=='SwimFast';amp=1.55 if fast else 1
  angles['Body']=math.radians(1.8*amp)*math.sin(phase)
  for i in range(3):angles[f'Tail{i+1:02}']=math.radians((7+i*3)*amp)*math.sin(phase-i*.8)
  angles['Jaw']=math.radians(2+1.5*math.sin(phase))
  for side,s in [('L',-1),('R',1)]:
   for j,tag in enumerate(['Front','Rear']):angles[f'Fin{tag}{side}']=s*math.radians(4)*math.sin(phase+j*.8+s*.4)
 elif name=='Bite':
  gape=envelope(u,[(0,0),(.3,1),(.43,1),(.54,0),(.7,.08),(1,0)])
  angles['Jaw']=math.radians(35)*gape
  angles['Body']=math.radians(2)*math.sin(2*math.pi*u)*math.sin(math.pi*u)**2
  for i in range(3):angles[f'Tail{i+1:02}']=math.radians(8+i*2)*math.sin(phase-i*.5)*math.sin(math.pi*u)**2
 else:
  sweep=envelope(u,[(0,0),(.25,-.38),(.55,1),(.85,-.08),(1,0)])
  angles['Body']=math.radians(-3)*sweep
  for i,deg in enumerate([16,11,8]):angles[f'Tail{i+1:02}']=math.radians(deg)*sweep
 for pb in rig.pose.bones:
  axis=Vector((1,0,0)) if pb.name=='Jaw' else Vector((0,1,0)) if pb.name.startswith('Fin') else Vector((0,0,1))
  local=pb.bone.matrix_local.to_3x3().inverted()@axis
  pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion(local,-angles[pb.name] if pb.name=='Jaw' else angles[pb.name]);pb.location=(0,0,0);pb.scale=(1,1,1)
for name,duration,loop in clips:
 rig.animation_data_create();act=bpy.data.actions.new(name);rig.animation_data.action=act;actions[name]=act
 n=round(duration*30)
 for f in range(n+1):
  pose(name,f/n)
  for pb in rig.pose.bones:pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name)
 act.use_fake_user=True
 track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,0,act);track.mute=True
rig.animation_data.action=None;pose('Bite',0)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=rig
# NLA mode gives one clip per named track. Exporter temporarily evaluates muted tracks.
for tr in rig.animation_data.nla_tracks:tr.mute=False
bpy.ops.export_scene.gltf(filepath=str(out/'serpohvost-animated.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_frame_range=False,export_force_sampling=True,export_anim_slide_to_zero=True,export_yup=True)
for tr in rig.animation_data.nla_tracks:tr.mute=True
info={'source_commit':'46d4640b2c9037f171ef316d26784cbef9873713','issue':651,'bones':[b.name for b in rig.data.bones],'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'clips':[{'name':n,'seconds':d,'loop':l} for n,d,l in clips],'source_sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in (root/'models').glob('serpohvost-*.glb')},'glb_bytes':(out/'serpohvost-animated.glb').stat().st_size}
(out/'manifest.json').write_text(json.dumps(info,indent=2),encoding='utf-8');print('ASSET',json.dumps(info))
if not a.render:sys.exit(0)
scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.render.resolution_x=640;scene.render.resolution_y=360;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DeepWater');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.09,.11,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
scene.view_settings.view_transform='AgX'
def light(name,loc,power,size,color):
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,-1,0))-o.location).to_track_quat('-Z','Y').to_euler()
light('Softbox',(2,2,6),1800,7,(.69,.86,1));light('Rim',(-3,-3,4),1500,5,(.3,.75,1));light('Fill',(5,-2,1),600,5,(.8,.9,1))
d=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',d);scene.collection.objects.link(cam);scene.camera=cam;d.type='ORTHO';d.ortho_scale=7.6
views={'three':(8,4,5),'side':(9,-1,1.6),'top':(0,-1,12)}
def camera(view):
 cam.location=views[view];q=(Vector((0,-1.1,0))-cam.location).to_track_quat('-Z','Y')
 if view=='top':q=q@Quaternion((0,0,1),math.pi/2)
 cam.rotation_euler=q.to_euler()
def render(name,u,view,path):
 rig.animation_data.action=actions[name];scene.frame_set(round(u*dict((n,d) for n,d,l in clips)[name]*30));camera(view);scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
if a.top_only:
 render('Bite',0,'top',tmp/'rest-top.png')
 for k,u in enumerate([0,.25,.5,.75]):render('TailStrike',u,'top',tmp/f'TailStrike-pose{k}.png')
 sys.exit(0)
for view in views:render('Bite',0,view,tmp/f'rest-{view}.png')
for name,duration,loop in clips:
 folder=tmp/name;folder.mkdir(exist_ok=True)
 count=round(duration*15)
 for f in range(count):render(name,f/count,'three',folder/f'{f:03}.png')
 for k,u in enumerate([0,.25,.5,.75]):render(name,u,'top' if name=='TailStrike' else 'side',tmp/f'{name}-pose{k}.png')
print('RENDERS COMPLETE')
