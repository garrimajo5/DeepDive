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
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=24;sc.render.resolution_x=680;sc.render.resolution_y=500;sc.render.resolution_percentage=100;sc.world=bpy.data.worlds.new('World');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.055,.065,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for o in bpy.data.objects:
 if o.type=='MESH':o.hide_render=True
for pos,power,size in [((3,4,5),500,4),((-3,2,3),350,3),((0,-3,4),500,3)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(Vector((0,0,1))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;sc.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.7
report=[]
for o in [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('gear-')]:
 arm=o.find_armature();body=next(x for x in bpy.data.objects if x.name.startswith('body-') and x.find_armature()==arm);pose(arm,'rest');bpy.ops.object.select_all(action='DESELECT');o.select_set(True);arm.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.export_scene.gltf(filepath=str(OUT/(o.name+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_yup=True,export_all_influences=False)
 o.data.calc_loop_triangles();report.append({'name':o.name,'triangles':len(o.data.loop_triangles),'vertices':len(o.data.vertices),'bones':len(arm.data.bones),'bounds_blender':[[min(v.co[i] for v in o.data.vertices),max(v.co[i] for v in o.data.vertices)] for i in range(3)]})
 o.hide_render=False;body.hide_render=False
 for key,pos in [('front',(0,6,1.05)),('side',(6,0,1.05)),('seat',(3,5,2.0))]:
  pose(arm,'seat' if key=='seat' else 'rest');cam.location=pos;cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();sc.render.filepath=str(R/f'{o.name}-{key}.png');bpy.ops.render.render(write_still=True)
 pose(arm,'rest');o.hide_render=True;body.hide_render=True
(O/'export-report.json').write_text(json.dumps(report,indent=2));print('EXPORTED',json.dumps(report))
