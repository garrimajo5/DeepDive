import sys,math,json,copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from build import *
import bpy
TMP=ROOT/'local';TMP.mkdir(exist_ok=True)
for sex in ['muzhchina','zhenshchina']:
 d,b=read(REPO/'models'/('ekipazh-'+sex+'.glb'));r,base=sample(d,b,'PostIdle');g=solve(r,base,.5);a={'name':'Diagnostic','samplers':[],'channels':[]};time=append(d,b,[[0],[1]],'SCALAR')
 for i in r.j:
  loc=g[r.parent[i]].inverted()@g[i];q=loc.to_quaternion()
  for path,vals,kind in [('rotation',[[q.x,q.y,q.z,q.w]]*2,'VEC4'),('translation',[list(loc.translation)]*2,'VEC3')]:
   out=append(d,b,vals,kind);a['channels'].append({'sampler':len(a['samplers']),'target':{'node':i,'path':path}});a['samplers'].append({'input':time,'output':out,'interpolation':'LINEAR'})
 d['animations'].append(a);write(TMP/(sex+'.glb'),d,b)
 for clip in ['PostIdle','Diagnostic']:
  bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=4;s.render.resolution_x=2400;s.render.resolution_y=1080;s.render.resolution_percentage=100;s.render.image_settings.file_format='JPEG';s.render.image_settings.quality=90
  s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.2,.24,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.7
  bpy.ops.import_scene.gltf(filepath=str(TMP/(sex+'.glb')));arm=next(o for o in s.objects if o.type=='ARMATURE');act=next(a for a in bpy.data.actions if a.name==clip or a.name.endswith('|'+clip));arm.animation_data.action=act
  if hasattr(act,'slots') and len(act.slots):arm.animation_data.action_slot=act.slots[0]
  s.frame_set(1);bpy.context.view_layer.update()
  # Preview only: reproduce CrewView.cut_mesh(HIDE_HEAD); never export this mesh.
  import bmesh
  for ob in list(s.objects):
   if ob.type!='MESH':continue
   hide={vg.index for vg in ob.vertex_groups if vg.name in ['neck','Head','head_end','headfront']}
   gone={v.index for v in ob.data.vertices if sum(q.weight for q in v.groups if q.group in hide)>.5}
   bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table();bmesh.ops.delete(bm,geom=[f for f in bm.faces if any(v.index in gone for v in f.verts)],context='FACES');bm.to_mesh(ob.data);bm.free()
  bpy.ops.object.camera_add(location=(0,0,1.65));cam=bpy.context.object;s.camera=cam;cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=32;cam.data.lens=32/(2*math.tan(math.radians(36)));cam.data.clip_start=.03
  yaw=math.radians(-20);pitch=math.radians(-32);f=Vector((-math.sin(yaw)*math.cos(pitch),-math.cos(yaw)*math.cos(pitch),math.sin(pitch)));f=Vector((f.x,-f.y,f.z));cam.rotation_euler=f.to_track_quat('-Z','Y').to_euler()
  bpy.ops.object.light_add(type='AREA',location=(0,2,3));light=bpy.context.object;light.data.energy=300;light.data.shape='DISK';light.data.size=4;light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
  s.render.filepath=str(ROOT/(sex+'-'+clip+'-cut.jpg'));bpy.ops.render.render(write_still=True)


