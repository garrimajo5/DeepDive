import types,json,numpy as np
from pathlib import Path
H=Path(__file__).resolve().parent
m=types.ModuleType('original');m.__file__=str(H/'animate.py');exec(compile((H/'animate.py').read_text().replace('[::2]',''),m.__file__,'exec'),m.__dict__)
ROOT=H.parent/'v2';ROOT.mkdir(exist_ok=True);REPO=m.REPO;Rig=m.Rig;CLIPS=m.CLIPS
original_read=m.read
changes=json.loads((H.parent/'heel-experiment-20261111.json').read_text())
def read(path):
 d,b=original_read(path)
 if Path(path).parent==REPO/'models':
  sex='muzhchina' if 'muzhchina' in Path(path).name else 'zhenshchina'
  att=d['meshes'][0]['primitives'][0]['attributes']
  for key,field in [('WEIGHTS_0','new_weights'),('JOINTS_0','new_joints')]:
   a=d['accessors'][att[key]];v=d['bufferViews'][a['bufferView']];ct={5126:'<f4',5123:'<u2',5121:'u1'}[a['componentType']];arr=m.accessor(d,b,att[key]);offset=v.get('byteOffset',0)+a.get('byteOffset',0)
   for change in next(x for x in changes if x['sex']==sex)['changed_vertices']:arr[change['vertex']]=change[field]
   raw=arr.astype(ct).tobytes();b[offset:offset+len(raw)]=raw
 return d,b
m.read=read;m.ROOT=ROOT
if __name__=='__main__':m.build()
