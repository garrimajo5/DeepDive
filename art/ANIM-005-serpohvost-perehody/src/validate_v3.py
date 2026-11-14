import bpy,sys,json,math,numpy as np
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from gltf_support import read,accessor
from sample_source import sample
out=Path(__file__).resolve().parents[1];repo=out.parents[1]
d,b=read(out/'serpohvost-anim.glb');old,ob=read(repo/'models/serpohvost-anim.glb')
assert b[:len(ob)]==ob
for key in ['nodes','meshes','skins','materials','images','textures','samplers']:
 assert d.get(key)==old.get(key),key
for name in ['Swim','SwimFast','Bite']:
 assert next(a for a in d['animations'] if a['name']==name)==next(a for a in old['animations'] if a['name']==name)
r,neutral=sample(d,b,'Swim');_,fast=sample(d,b,'SwimFast');result={'payload_unchanged':True,'endpoints':{}}
for name,dur,target in [('TailStrike',.9,neutral),('Recoil',1,neutral),('Coil',.5,fast),('Hover',4,None)]:
 _,a=sample(d,b,name,0);_,z=sample(d,b,name,dur)
 target=target or a
 err=max(max(abs(float(z[i][x][y]-target[i][x][y])) for x in range(4) for y in range(4)) for i in r.j)
 result['endpoints'][name]=err
 assert err<1e-5,(name,err)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=60
bpy.ops.import_scene.gltf(filepath=str(out/'serpohvost-anim.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
assert len(arm.data.bones)==10 and len(meshes)==3 and len(bpy.data.actions)==9
result['blender']={'bones':10,'skins':3,'clips':[a.name for a in bpy.data.actions],'triangles':sum(len(o.data.polygons) for o in meshes)}
# Every exported frame: finite evaluated vertices, no zero-area triangles.
mins=[]
for act in bpy.data.actions:
 arm.animation_data.action=act;arm.animation_data.action_slot=act.slots[0]
 for f in range(int(act.frame_range[0]),int(act.frame_range[1])+1):
  bpy.context.scene.frame_set(f);dg=bpy.context.evaluated_depsgraph_get()
  for obj in meshes:
   ev=obj.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles()
   vs=np.array([v.co[:] for v in me.vertices]);assert np.isfinite(vs).all()
   ids=np.array([t.vertices[:] for t in me.loop_triangles]);v=vs[ids]
   ar=np.linalg.norm(np.cross(v[:,1]-v[:,0],v[:,2]-v[:,0]),axis=1)/2
   mins.append(float(ar.min()));ev.to_mesh_clear()
result['minimum_triangle_area']=min(mins)
(out/'validation-v3.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
