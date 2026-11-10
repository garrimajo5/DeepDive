import json,math
from pathlib import Path
P=Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik');r=json.loads((P/'retopology-v5.json').read_text());shift=json.loads((P/'pivot-shift.json').read_text())
def gltf(p):return [round(p[0]+shift[0],6),round(p[2]+shift[2],6),round(-p[1]-shift[1],6)]
roots=[[-.47,.28,.60],[0,.42,.60],[.47,.28,.60]];out={'coordinates':'glTF metres, Y up, front -Z','roots_are':'anatomical attachment centers inside mantle; no bones'}
for i,(root,part) in enumerate(zip(roots,r['parts'][:3])):
 points=[root]+part['ring_centers_blender'];length=sum(math.dist(a,b) for a,b in zip(points,points[1:]));out['grasper_'+str(i)]={'root':gltf(root),'pad_base':gltf(points[-1]),'centerline_length_m':round(length,4),'pad_length_projection_m':.45,'transverse_internal_rings':6}
for part in r['parts'][3:]:out[part['part']]={'mouth_center':gltf(part['mouth_blender']),'diameter_m':.25,'folds':3}
(P/'landmarks.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))
