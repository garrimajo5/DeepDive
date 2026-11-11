import bpy,numpy as np,json
from pathlib import Path
P=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30;bpy.ops.import_scene.gltf(filepath=str(P/'kupolnik-anim.glb'))
o=next(x for x in bpy.context.scene.objects if x.type=='MESH');r=next(x for x in bpy.context.scene.objects if x.type=='ARMATURE');o.data.calc_loop_triangles();tri=np.array([t.vertices[:] for t in o.data.loop_triangles]);v=np.array([v.co[:] for v in o.data.vertices]);norm=np.cross(v[tri[:,1]]-v[tri[:,0]],v[tri[:,2]]-v[tri[:,0]]);areas=np.linalg.norm(norm,axis=1);weights=np.zeros((len(v),len(r.data.bones)))
for vert in o.data.vertices:
 for g in vert.groups:weights[vert.index,list(r.data.bones.keys()).index(o.vertex_groups[g.group].name)]=g.weight
w=weights[tri].mean(1);report={}
for act in bpy.data.actions:
 r.animation_data.action=act;worst=0
 for frame in range(round(act.frame_range[1])+1):
  bpy.context.scene.frame_set(frame);ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());p=np.array([v.co[:] for v in ev.data.vertices]);actual=np.cross(p[tri[:,1]]-p[tri[:,0]],p[tri[:,2]]-p[tri[:,0]]);expected=np.zeros_like(norm)
  for k,b in enumerate(r.pose.bones):
   m=np.array((b.matrix@b.bone.matrix_local.inverted()).to_3x3());expected+=w[:,k,None]*(norm@np.linalg.inv(m))
  dots=(actual*expected).sum(1);bad=(dots< -1e-12)&(areas>1e-6);
  if int(bad.sum())>worst:
   worst=int(bad.sum());points=v[tri[bad]].mean(1).round(3).tolist()
 print(act.name,worst,points if worst else [])
 report[act.name]=worst
print('ORIENTATION',report);(P/'orientation-audit.json').write_text(json.dumps(report,indent=2))
