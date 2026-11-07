exec(compile((__import__('pathlib').Path(__file__).parent/'scene.py').read_text(encoding='utf-8'),__file__,'exec'))
from mathutils.kdtree import KDTree
P=json.loads((O/'body-points.json').read_text());report=[]
for sex in ['m','zh']:
 body=bpy.data.objects['body-'+sex];arm=body.find_armature()
 for key,points in P[sex].items():
  pose(arm,'rest')
  for b in arm.pose.bones:b.matrix=C@Matrix(D[sex][key][b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
  vs,fs=ev(body);kd=KDTree(len(vs))
  for i,v in enumerate(vs):kd.insert(v,i)
  kd.balance();ds=[kd.find(C@Vector(p))[2] for p in points];report.append({'sex':sex,'pose':key,'max_error_m':max(ds),'mean_error_m':sum(ds)/len(ds),'samples':len(ds)})
(R/'coordinate-check.json').write_text(json.dumps(report,indent=2));print(report)
