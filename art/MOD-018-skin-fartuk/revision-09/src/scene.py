import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
from mathutils.bvhtree import BVHTree
O=Path(__file__).resolve().parent.parent
R=O/'renders';R.mkdir(exist_ok=True)
OUT=O
REPO=O.parents[2]
import sys
SOURCE=Path(sys.argv[sys.argv.index('--')+1]).resolve() if '--' in sys.argv else O/'source.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
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
 if bpy.data.objects.get('body-'+sex):continue
 arm=bpy.data.objects['gear-fartuk-'+sex].find_armature();pose(arm,'rest')
 old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(REPO/'models'/('ekipazh-'+gender+'.glb')))
 body=max((x for x in set(bpy.data.objects)-old if x.type=='MESH'),key=lambda x:len(x.data.vertices));imported=body.find_armature();world=body.matrix_world.copy();body.parent=arm;body.matrix_world=world
 for mod in body.modifiers:
  if mod.type=='ARMATURE':mod.object=arm
 body.name='body-'+sex
 if imported!=arm:bpy.data.objects.remove(imported,do_unlink=True)
D=json.loads((O/'game-poses.json').read_text())
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));CI=C.inverted()
