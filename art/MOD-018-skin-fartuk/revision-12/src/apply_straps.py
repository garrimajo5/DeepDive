import bpy,json
from pathlib import Path
O=Path(__file__).resolve().parent.parent
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'revision-11/source.blend'))

for name,sex,shift in [('route12','m',114),('right12','m',114),('femaleleft12','zh',99),('femaleright12','zh',99)]:
 for rec in json.loads(O/(name+'.json').read_text()):
  for kind,delta in [('fartuk',0),('tunika',shift)]:
   o=bpy.data.objects['gear-'+kind+'-'+sex]
   for k,p in rec['positions'].items():
    if kind=='tunika' and sex=='zh' and int(k) in [278,279]:continue
    i=int(k)+delta;o.data.vertices[i].co=p
    for vg in o.vertex_groups:vg.remove([i])
    for n,w in rec['weights'][k].items():
     vg=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);vg.add([i],w,'REPLACE')
bpy.ops.wm.save_as_mainfile(filepath=str(O/'source.blend'))
