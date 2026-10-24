import bpy,json
from pathlib import Path
O=Path(__file__).resolve().parent.parent
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'revision-11/source.blend'))
old={o.name:[v.co.copy() for v in o.data.vertices] for o in bpy.data.objects if o.type=='MESH'}
bpy.ops.wm.open_mainfile(filepath=str(O/'source.blend'));report=[]
for o in [x for x in bpy.data.objects if x.type=='MESH']:
 o.data.calc_loop_triangles();turned=[];deg=[];olddeg=[]
 for t in o.data.loop_triangles:
  a,b,c=[old[o.name][i] for i in t.vertices];na=(b-a).cross(c-a)
  a,b,c=[o.data.vertices[i].co for i in t.vertices];nb=(b-a).cross(c-a)
  if na.length<1e-10:olddeg.append(t.index)
  if na.dot(nb)<=0:turned.append(t.index)
  if nb.length<1e-10:deg.append(t.index)

 assert set(deg).issubset(olddeg), (o.name,deg,olddeg)
 report.append({'name':o.name,'max_displacement':max((v.co-old[o.name][v.index]).length for v in o.data.vertices),'turned_over_90_degrees':turned,'degenerate_faces':deg,'old_degenerate_faces':olddeg})
(O/'geometry-change-check.json').write_text(json.dumps(report,indent=2));print(report)
