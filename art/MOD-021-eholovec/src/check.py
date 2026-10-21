import json,struct
from pathlib import Path
R=Path(__file__).parent.parent/'DeepDive/art/MOD-021-eholovec'
limits={'telo':3500,'uho':900,'mesh ok':400,'meshok':400,'chelyust':500}
total=0
for p in R.glob('*.glb'):
 b=p.read_bytes();assert b[:4]==b'glTF';n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);assert len(b)<5000000
 assert not j.get('skins') and not j.get('animations');assert len(j['meshes'])==1 and len(j['meshes'][0]['primitives'])==1
 assert len(j['materials'])==1
 t=j['accessors'][j['meshes'][0]['primitives'][0]['indices']]['count']//3
 key=p.stem.split('-')[-1];assert t<=limits[key],(key,t);total+=t*(2 if key=='uho' else 1)
 for node in j['nodes']:
  assert all(abs(v-1)<1e-5 for v in node.get('scale',[1,1,1]))
 print(p.name,len(b),t,'triangles')
assert total<6200;print('assembly triangles',total)
