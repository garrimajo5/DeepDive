exec(compile((__import__('pathlib').Path(__file__).parent/'scene.py').read_text(encoding='utf-8'),__file__,'exec'))
from mathutils.kdtree import KDTree
P=json.loads((O/'cloth-points.json').read_text());report=[]
for sex in ['m','zh']:
 for kind in ['fartuk','tunika']:
  gear=bpy.data.objects['gear-'+kind+'-'+sex];arm=gear.find_armature()
  for key,per_gear in P[sex].items():
   points=per_gear[kind];pose(arm,'rest')
   for b in arm.pose.bones:b.matrix=C@Matrix(D[sex][key][b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
   vs,fs=ev(gear);kd=KDTree(len(vs))
   for i,v in enumerate(vs):kd.insert(v,i)
   kd.balance();ds=[kd.find(C@Vector(p))[2] for p in points];report.append({'gear':gear.name,'pose':key,'max_error_m':max(ds),'mean_error_m':sum(ds)/len(ds),'samples':len(ds)})
assert max(r['max_error_m'] for r in report)<.0005
(R/'cloth-coordinate-check.json').write_text(json.dumps(report,indent=2));print(report)
