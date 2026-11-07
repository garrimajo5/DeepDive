import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
from mathutils.bvhtree import BVHTree
O=Path(__file__).resolve().parent.parent
R=O/'renders';R.mkdir(exist_ok=True)
OUT=O
REPO=O.parents[2]
bpy.ops.wm.open_mainfile(filepath=str(O/'source.blend'))
def pose(arm,key):
 for b in arm.pose.bones:b.matrix_basis=Matrix.Identity(4)
 def rot(n,a):
  b=arm.pose.bones[n];b.rotation_mode='QUATERNION';b.rotation_quaternion=Quaternion(b.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0)),math.radians(a))
 if key=='seat':
  for s in ['Left','Right']:rot(s+'UpLeg',90);rot(s+'Leg',-90)
 if key in ['walk','walk2']:
  a=25 if key=='walk' else -25;rot('LeftUpLeg',a);rot('RightUpLeg',-a)
 if key=='lean':rot('Spine01',-20)
 bpy.context.view_layer.update()
def ev(o):
 q=o.evaluated_get(bpy.context.evaluated_depsgraph_get());m=q.to_mesh();p=[v.co.copy() for v in m.vertices];m.calc_loop_triangles();f=[list(t.vertices) for t in m.loop_triangles];q.to_mesh_clear();return p,f

for sex,gender in [('m','muzhchina'),('zh','zhenshchina')]:
 arm=bpy.data.objects['gear-fartuk-'+sex].find_armature();pose(arm,'rest')
 old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(REPO/'models'/('ekipazh-'+gender+'.glb')))
 body=max((x for x in set(bpy.data.objects)-old if x.type=='MESH'),key=lambda x:len(x.data.vertices));imported=body.find_armature();world=body.matrix_world.copy();body.parent=arm;body.matrix_world=world
 for mod in body.modifiers:
  if mod.type=='ARMATURE':mod.object=arm
 body.name='body-'+sex
 if imported!=arm:bpy.data.objects.remove(imported,do_unlink=True)
report=[]
for o in [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('gear-')]:
 arm=o.find_armature();body=next(x for x in bpy.data.objects if x.name.startswith('body-') and x.find_armature()==arm)
 rec={'name':o.name,'poses':{}}
 for key in ['rest','seat','walk','walk2','lean']:
  pose(arm,key);bp,bf=ev(body);gp,gf=ev(o);bt=BVHTree.FromPolygons(bp,bf,all_triangles=True);gt=BVHTree.FromPolygons(gp,gf,all_triangles=True);gaps=[]
  for p in gp:
   q,n,i,d=bt.find_nearest(p);gaps.append(d if (p-q).dot(n)>=0 else -d)
  rec['poses'][key]={'min':min(gaps),'max':max(gaps),'inside':sum(g<-.002 for g in gaps),'far':sum(g>.04 for g in gaps),'intersections':len(gt.overlap(bt))}
 pose(arm,'rest');report.append(rec)
(O/'validation-poses.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))

