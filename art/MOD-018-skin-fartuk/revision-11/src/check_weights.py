exec(compile((__import__('pathlib').Path(__file__).parent/'scene.py').read_text(encoding='utf-8'),__file__,'exec'))
report=[]
for o in [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('gear-')]:
 groups={};max_sum_error=0;max_influences=0;lower_max=0
 for v in o.data.vertices:
  weights=[g for g in v.groups if g.weight>1e-6];max_influences=max(max_influences,len(weights));max_sum_error=max(max_sum_error,abs(sum(g.weight for g in weights)-1))
  for g in weights:
   name=o.vertex_groups[g.group].name;groups[name]=max(groups.get(name,0),g.weight)
   if name.endswith('UpLeg') and v.co.z<.9:lower_max=max(lower_max,g.weight)
 report.append({'name':o.name,'max_influences':max_influences,'max_weight_sum_error':max_sum_error,'bone_max_weights':groups,'lower_thigh_max':lower_max})
 assert max_influences<=4 and max_sum_error<.00001
(R/'validation-weights.json').write_text(json.dumps(report,indent=2));print(report)
