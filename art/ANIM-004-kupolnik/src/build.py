import bpy, math, json
from mathutils import Vector
from pathlib import Path
P=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(P/'source.blend'))
o=next(x for x in bpy.context.scene.objects if x.type=='MESH')
bpy.ops.object.select_all(action='DESELECT')
a=bpy.data.armatures.new('KupolnikSkeleton'); rig=bpy.data.objects.new('KupolnikRig',a);bpy.context.collection.objects.link(rig);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(n,h,t,p=None):
 b=a.edit_bones.new(n);b.head=h;b.tail=t
 if p:b.parent=a.edit_bones[p]
 return b
bone('Root',(0,0,0),(0,0,.2));bone('Body',(0,0,.6),(0,.3,.6),'Root')
for s,x in [('L',-.45),('R',.45)]:bone('Mantle'+s,(x,-.3,.58),(x,.3,.5),'Body')
ends={}; roots={}
for s,x,y,px,py,pz in [('L',-.469,.270,-.6045,.95994,.27827),('M',.001,.410,.00378,1.04012,.28146),('R',.471,.270,.6154,.96614,.28419)]:
 h=Vector((x,y,.599));e=Vector((px,py,pz));mid=h.lerp(e,.48);mid.z-=.05
 roots[s]=h;ends[s]=e
 bone('Grasp'+s+'Upper',h,mid,'Body');bone('Grasp'+s+'Lower',mid,e,'Grasp'+s+'Upper')
 for k,dx in [('A',-.08),('B',.08)]:bone('Grasp'+s+'Pad'+k,e,(px+dx,py+.38,pz-.03),'Grasp'+s+'Lower')
for s,x in [('L',-.169),('R',.171)]:
 bone('Siphon'+s+'Base',(x,-1.11,.749),(x,-1.32,.749),'Body');bone('Siphon'+s+'Valve',(x,-1.32,.749),(x,-1.49,.749),'Siphon'+s+'Base')
bpy.ops.object.mode_set(mode='OBJECT')
for b in a.bones:
 o.vertex_groups.new(name=b.name)
 if 'Pad' in b.name:b.use_inherit_rotation=False
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
for v in o.data.vertices:
 x,y,z=v.co;w={'Body':1.}
 if y>.27 and z<.60:
  s='M' if abs(x)<.28 else ('L' if x<0 else 'R');h=roots[s];e=ends[s]
  u=smooth((y-(.60 if s!='M' else .72))/.35);q=smooth((y-(h.y+e.y)/2+.20)/.40);p=smooth((y-e.y+.04)/.12)
  w={'Body':1-u,'Grasp'+s+'Upper':u*(1-q),'Grasp'+s+'Lower':u*q*(1-p),'Grasp'+s+('PadA' if x<e.x else 'PadB'):u*q*p}
 elif y< -1.10 and abs(x)<.34 and z>.55 and z<.95:
  s='L' if x<0 else 'R';b=smooth((-y-1.10)/.16);vweight=smooth((-y-1.29)/.12)
  w={'Body':1-b,'Siphon'+s+'Base':b*(1-vweight),'Siphon'+s+'Valve':b*vweight}
 elif z<.59 and y<.5 and y> -1.10:
  t=smooth((.59-z)/.14);w={'Body':1-t,'Mantle'+('L' if x<0 else 'R'):t}
 for n,weight in w.items():
  if weight>1e-7:o.vertex_groups[n].add([v.index],weight,'REPLACE')
o.parent=rig;mod=o.modifiers.new('Skin','ARMATURE');mod.object=rig
scene=bpy.context.scene;scene.render.fps=30
report={'bones':{b.name:b.parent.name if b.parent else None for b in a.bones},'clips':{}}
for name,duration in [('Idle',4),('Swim',3),('OpenPetal',5)]:
 rig.animation_data_clear()
 for b in rig.pose.bones:b.matrix_basis.identity();b.rotation_mode='QUATERNION'
 helpers=[]
 for s in 'LMR':
  target=bpy.data.objects.new('Target'+s,None);bpy.context.collection.objects.link(target);helpers.append(target)
  c=rig.pose.bones['Grasp'+s+'Lower'].constraints.new('IK');c.target=target;c.chain_count=2;c.use_stretch=False

  # Target rotation matches the original pad direction sufficiently for stable contact.
  target.rotation_mode='QUATERNION';target.rotation_quaternion=a.bones['Grasp'+s+'PadA'].matrix_local.to_quaternion()
 n=int(duration*30)
 for f in range(n+1):
  t=f/30;phase=2*math.pi*t/duration;scene.frame_set(f)
  body=rig.pose.bones['Body'];body.location=(0,0,0)
  for s in 'LR':
   mb=rig.pose.bones['Mantle'+s];mb.scale=(1,1,1-.025*(1-math.cos(phase)))
   vb=rig.pose.bones['Siphon'+s+'Valve'];vb.scale=(.88,1,.88)
  for s,target in zip('LMR',helpers):
   dest=ends[s].copy()
   if name=='Idle':dest.z+=.012*math.sin(phase)*(1 if s!='M' else -.6)
   elif name=='Swim':
    dest.y-=.12;dest.z+=.08+.02*math.sin(phase)
    body.location.z=.025*(1-math.cos(phase))
    val=math.sin(math.pi*max(0,min(1,(t-1.5)/.7))) if 1.5<=t<=2.2 else 0
    for side in 'LR':rig.pose.bones['Siphon'+side+'Valve'].scale=(.7+.3*val,1,.7+.3*val)
   else:
    reach=smooth(t/1.2);release=1-smooth((t-3.8)/1.2);hold=reach*release;lift=smooth((t-1.2)/2.6)*release
    body.location.z=.25*lift
    if s=='R':dest=ends[s].lerp(Vector((.615,.85,.42)),hold)
    if s=='M':dest.y+=.04*hold;dest.z+=.6*lift
    if s=='L':dest.x-=.15*hold;dest.y-=.1*hold
   target.location=dest;target.keyframe_insert('location',frame=f)
  for b in rig.pose.bones:
   b.keyframe_insert('location',frame=f);b.keyframe_insert('rotation_quaternion',frame=f);b.keyframe_insert('scale',frame=f)
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
 bpy.ops.nla.bake(frame_start=0,frame_end=n,step=1,only_selected=False,visual_keying=True,clear_constraints=True,use_current_action=True,bake_types={'POSE'})
 action=rig.animation_data.action;action.name=name;action.use_fake_user=True
 # Cyclic endpoints are exact, avoiding accumulated IK numerical differences.
 for fc in action.fcurves:
  for kp in fc.keyframe_points:kp.interpolation='LINEAR'
  if name in ('Idle','Swim') and len(fc.keyframe_points)>1:fc.keyframe_points[-1].co.y=fc.keyframe_points[0].co.y
 for helper in helpers:bpy.data.objects.remove(helper,do_unlink=True)
 report['clips'][name]={'seconds':duration,'frames':n+1}
rig.animation_data.action=bpy.data.actions['Idle'];scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(P/'rig.blend'))
bpy.ops.export_scene.gltf(filepath=str(P/'kupolnik-anim.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_extras=True)
(P/'build-report.json').write_text(json.dumps(report,indent=2))



# Restore original split normals byte-for-byte after Blender's exporter normalization.
import struct
original=(P.parents[1]/'models/kupolnik.glb').read_bytes();result=bytearray((P/'kupolnik-anim.glb').read_bytes())
def normals(data):
 size=struct.unpack_from('<I',data,12)[0];j=json.loads(data[20:20+size]);a=j['accessors'][j['meshes'][0]['primitives'][0]['attributes']['NORMAL']];v=j['bufferViews'][a['bufferView']];return 28+size+v.get('byteOffset',0)+a.get('byteOffset',0),a['count']*12
src,n=normals(original);dst,m=normals(result);assert n==m;result[dst:dst+m]=original[src:src+n];(P/'kupolnik-anim.glb').write_bytes(result)
