import sys,inspect
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import neighbour_search_20261112 as n
from gltf_support import *
m=n.m
for sex,lean,dist,yaw,tilt in [('muzhchina',1.35,.25,-30,90),('zhenshchina',1.2,.25,-90,0)]:
 d,b=read(m.REPO/'models'/('ekipazh-'+sex+'.glb'));r,base=m.sample(d,b,'PostIdle');g=n.n.pose2(d,r,base,.5,-.4,lean,dist);hi=r.names['RightHand'];g[hi]=mat(rot('Z',math.radians(tilt))@rot('Y',math.radians(yaw))@r.rest[hi].to_3x3(),g[hi].translation)
 a={'name':'Diagnostic','samplers':[],'channels':[]};time=append(d,b,[[0],[1]],'SCALAR')
 for i in r.j:
  loc=g[r.parent[i]].inverted()@g[i];q=loc.to_quaternion()
  for path,vals,kind in [('rotation',[[q.x,q.y,q.z,q.w]]*2,'VEC4'),('translation',[list(loc.translation)]*2,'VEC3')]:
   out=append(d,b,vals,kind);a['channels'].append({'sampler':len(a['samplers']),'target':{'node':i,'path':path}});a['samplers'].append({'input':time,'output':out,'interpolation':'LINEAR'})
 d['animations'].append(a);tmp=m.ROOT/'local';tmp.mkdir(exist_ok=True);write(tmp/(sex+'-neck.glb'),d,b)
 bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8;s.render.resolution_x=1200;s.render.resolution_y=800;s.render.resolution_percentage=100;s.render.image_settings.file_format='JPEG'
 s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.2,.24,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.7
 bpy.ops.import_scene.gltf(filepath=str(tmp/(sex+'-neck.glb')));arm=next(o for o in s.objects if o.type=='ARMATURE');act=next(a for a in bpy.data.actions if 'Diagnostic' in a.name);arm.animation_data.action=act;arm.animation_data.action_slot=act.slots[0];s.frame_set(1)
 bpy.ops.object.camera_add(location=(2.5,2.3,1.8));cam=bpy.context.object;s.camera=cam;cam.rotation_euler=(Vector((0,.4,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.2
 bpy.ops.object.light_add(type='AREA',location=(0,2,3));light=bpy.context.object;light.data.energy=300;light.data.size=4;light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
 s.render.filepath=str(m.ROOT/(sex+'-neck-side-20261112.jpg'));bpy.ops.render.render(write_still=True)
