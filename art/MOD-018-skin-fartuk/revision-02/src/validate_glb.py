from pathlib import Path
import json,struct,io
from PIL import Image
O=Path(__file__).resolve().parent.parent;report=[]
for p in sorted(O.glob('*.glb')):
 b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);blob=b[28+n:]
 assert len(j['meshes'])==len(j['materials'])==len(j['skins'])==1
 assert len(j['meshes'][0]['primitives'])==1 and not j.get('animations')
 prim=j['meshes'][0]['primitives'][0];tris=j['accessors'][prim['indices']]['count']//3
 assert tris<=600 and len(b)<5*1024**2
 assert 'JOINTS_0' in prim['attributes'] and 'WEIGHTS_0' in prim['attributes']
 for node in j['nodes']:assert all(abs(x-1)<1e-5 for x in node.get('scale',[1,1,1]))
 for image in j['images']:
  view=j['bufferViews'][image['bufferView']];im=Image.open(io.BytesIO(blob[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]));assert im.size==(1024,1024)
 report.append({'file':p.name,'bytes':len(b),'triangles':tris,'skins':1,'materials':1,'animations':0,'embedded_images':len(j['images'])})
for p in O.glob('*.png'):
 im=Image.open(p);assert im.size==(2048,1152)
 if p.stat().st_size>2*1024**2:
  im=im.convert('RGB');im=im.point(lambda v:(v//2)*2);im.save(p,optimize=True)
 assert p.stat().st_size<2*1024**2
(O/'validation-glb.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
