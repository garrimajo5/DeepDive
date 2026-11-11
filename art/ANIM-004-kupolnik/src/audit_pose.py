import bpy,json,math,numpy as np
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30;bpy.ops.import_scene.gltf(filepath=str(P/'kupolnik-anim.glb'))
s=bpy.context.scene;r=next(o for o in s.objects if o.type=='ARMATURE');o=next(o for o in s.objects if o.type=='MESH');o.data.calc_loop_triangles();tri=np.array([t.vertices[:] for t in o.data.loop_triangles]);base=np.array([v.co[:] for v in o.data.vertices]);ref=np.linalg.norm(np.cross(base[tri[:,1]]-base[tri[:,0]],base[tri[:,2]]-base[tri[:,0]]),axis=1)
def verts():
 ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());return np.array([v.co[:] for v in ev.data.vertices])
report={};ends={}
for action in bpy.data.actions:
 r.animation_data.action=action;n=round(action.frame_range[1]);minimum=1e9;maximum=0;contact=[];middle=[];allposes=[]
 for f in range(n+1):
  s.frame_set(f);v=verts();allposes.append(v);area=np.linalg.norm(np.cross(v[tri[:,1]]-v[tri[:,0]],v[tri[:,2]]-v[tri[:,0]]),axis=1);ratio=area[ref>1e-8]/ref[ref>1e-8];minimum=min(minimum,float(ratio.min()));maximum=max(maximum,float(ratio.max()))
  if action.name=='OpenPetal' and 36<=f<=114:
   contact.append(list(r.pose.bones['GraspRLower'].tail));middle.append(list(r.pose.bones['GraspMLower'].tail))
 idx=int(np.argmax(area/np.maximum(ref,1e-12)));print('MAXTRI',action.name,base[tri[idx]].tolist())
 report[action.name]={'endpoint_max_m':float(np.max(np.linalg.norm(allposes[0]-allposes[-1],axis=1))),'area_ratio_min':minimum,'area_ratio_max':maximum}
 ends[action.name]=allposes[0]
 if contact:
  c=np.array(contact);m=np.array(middle);report[action.name]['right_contact_drift_m']=float(np.max(np.linalg.norm(c-c[0],axis=1)));report[action.name]['middle_lift_m']=float(m[-1,2]-m[0,2])
report['open_idle_start_max_m']=float(np.max(np.linalg.norm(ends['Idle']-ends['OpenPetal'],axis=1)))
r.animation_data_clear()
for b in r.pose.bones:b.matrix_basis.identity()
for side in 'LMR':r.pose.bones['Grasp'+side+'Lower'].rotation_mode='XYZ';r.pose.bones['Grasp'+side+'Lower'].rotation_euler.x=math.radians(60)
bpy.context.view_layer.update();v=verts();area=np.linalg.norm(np.cross(v[tri[:,1]]-v[tri[:,0]],v[tri[:,2]]-v[tri[:,0]]),axis=1);report['stress60_area_ratio_min']=float((area[ref>1e-8]/ref[ref>1e-8]).min())
(P/'deformation-audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
