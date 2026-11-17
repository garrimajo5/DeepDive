from pathlib import Path
__file__=str(Path(__file__).with_name('scene.py'))
exec(compile(Path(__file__).read_text(),__file__,'exec'))
from collections import Counter
D=json.loads((O/'game-poses-dense.json').read_text());out={}
for sex in ['m','zh']:
 body=bpy.data.objects['body-'+sex];arm=body.find_armature();dominant={v.index:body.vertex_groups[max(v.groups,key=lambda g:g.weight).group].name for v in body.data.vertices};out[sex]={}
 for key,trans in {'rest':None,**D[sex]}.items():
  pose(arm,'rest')
  if trans:
   for b in arm.pose.bones:b.matrix=C@Matrix(trans[b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
  bp,bf=ev(body);regions=[Counter(dominant[i] for i in f).most_common(1)[0][0] for f in bf];bt=BVHTree.FromPolygons(bp,bf,all_triangles=True);hits=Counter();examples=[]
  for a,b in bt.overlap(bt):
   if a>=b or set(bf[a])&set(bf[b]):continue
   ra,rb=regions[a],regions[b]
   if not ((ra.endswith('ForeArm') and rb in ['Hips','Spine','Spine01','Spine02']) or (rb.endswith('ForeArm') and ra in ['Hips','Spine','Spine01','Spine02'])):continue
   if any((bp[i]-bp[j]).length<1e-6 for i in bf[a] for j in bf[b]):continue
   hits[' / '.join(sorted([ra,rb]))]+=1
   if len(examples)<12:examples.append([a,b])
  if hits:out[sex][key]={'pairs':dict(hits),'example_faces':examples}
 print(sex,out[sex],flush=True)
(O/'body-pose-diagnostic.json').write_text(json.dumps(out,indent=2))
