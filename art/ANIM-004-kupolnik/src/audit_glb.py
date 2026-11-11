import json,struct,hashlib
from pathlib import Path
P=Path(__file__).resolve().parents[1]
def read(p):
 d=p.read_bytes();n=struct.unpack_from('<I',d,12)[0];j=json.loads(d[20:20+n]);return j,d[28+n:]
def access(j,b,i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];size={5126:4,5125:4,5123:2,5121:1}[a['componentType']]*{'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size);return b''.join(b[start+k*stride:start+k*stride+size] for k in range(a['count']))
a,ab=read(P.parents[1]/'models/kupolnik.glb');c,cb=read(P/'kupolnik-anim.glb');ap=a['meshes'][0]['primitives'][0];cp=c['meshes'][0]['primitives'][0]
r={'bytes':(P/'kupolnik-anim.glb').stat().st_size,'skins':len(c.get('skins',[])),'bones':len(c['skins'][0]['joints']),'animations':{},'attributes':{},'materials_equal':a['materials']==c['materials'],'images_equal':[]}
for key in ap['attributes']:r['attributes'][key]=access(a,ab,ap['attributes'][key])==access(c,cb,cp['attributes'][key])
r['indices_equal']=access(a,ab,ap['indices'])==access(c,cb,cp['indices'])
for im in a['images']:
 v=a['bufferViews'][im['bufferView']];blob=ab[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']];r['images_equal'].append(any(blob==cb[(cv:=c['bufferViews'][ci['bufferView']]).get('byteOffset',0):cv.get('byteOffset',0)+cv['byteLength']] for ci in c['images']))
for an in c['animations']:
 times=[struct.unpack('<'+'f'*(len(raw)//4),raw) for s in an['samplers'] for raw in [access(c,cb,s['input'])]];r['animations'][an['name']]=max(max(t) for t in times)-min(min(t) for t in times)
(P/'glb-audit.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
