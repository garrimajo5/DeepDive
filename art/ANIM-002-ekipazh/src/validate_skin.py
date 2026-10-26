import json,struct
from pathlib import Path
import numpy as np
import sys;sys.path.insert(0,str(Path(__file__).resolve().parent))
from animate import read,Rig,CLIPS,ROOT,REPO
def arr(d,b,k):
 a=d['accessors'][k];v=d['bufferViews'][a['bufferView']]
 ct={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']]
 n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 z=np.frombuffer(b,dtype=ct,count=a['count']*n,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,n).copy()
 if a.get('normalized'):z=z/np.iinfo(ct).max
 return z
out=[]
for sex in ['muzhchina','zhenshchina']:
 name='ekipazh-'+sex+'.glb';d,b=read(REPO/'models'/name);e,c=read(ROOT/name)
 for key in ['nodes','skins','meshes','materials','textures','images']:assert d.get(key)==e.get(key),key
 assert b==c[:len(b)]
 r=Rig(d,b);pr=d['meshes'][0]['primitives'][0];attrs=pr['attributes']
 p=arr(d,b,attrs['POSITION']);p=np.column_stack([p,np.ones(len(p))])
 joints=arr(d,b,attrs['JOINTS_0']).astype(int);w=arr(d,b,attrs['WEIGHTS_0'])
 ib=arr(d,b,d['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
 rest=np.array([np.array(r.rest[i]) for i in r.j])
 def deform(g):
  matrices=np.array([np.array(g[i]) for i in r.j])@ib
  return sum(w[:,k,None]*np.einsum('nij,nj->ni',matrices[joints[:,k]],p) for k in range(4))[:,:3]
 def sample(clip,f):
  from mathutils import Quaternion,Matrix,Vector
  animation=next(x for x in e['animations'] if x['name']==clip)
  ns=__import__('copy').deepcopy(e['nodes'])
  for ch in animation['channels']:
   sam=animation['samplers'][ch['sampler']];values=arr(e,c,sam['output'])
   ns[ch['target']['node']][ch['target']['path']]=values[f].tolist()
  local=[]
  for n in ns:
   q=n.get('rotation',[0,0,0,1]);local.append(Matrix.LocRotScale(Vector(n.get('translation',[0,0,0])),Quaternion((q[3],*q[:3])),Vector(n.get('scale',[1,1,1]))))
  glob={}
  def calc(i):
   if i not in glob:glob[i]=calc(r.parent[i])@local[i] if i in r.parent else local[i]
   return glob[i]
  for i in range(len(ns)):calc(i)
  return glob
 result={'model':sex,'original_payload_equal':True,'triangles':int(len(arr(d,b,pr['indices']))/3),'clips':{}}
 for clip,n in CLIPS.items():
  ps=[deform(sample(clip,f)) for f in range(n+1)]
  cm={'mesh_min_y':float(min(a[:,1].min() for a in ps)),'loop_max_vertex_error_m':float(np.abs(ps[0]-ps[-1]).max())}
  for side,start in [('Left',0),('Right',12)]:
   ids=[r.j.index(r.names[side+s]) for s in ['Foot','ToeBase']]
   mask=(p[:,1]<.065)&((p[:,0]<0) if side=='Left' else (p[:,0]>0))
   if clip=='Walk':
    poses=[deform(sample(clip,(start+f)%24)) for f in range(13)]
    displacement=[np.linalg.norm((poses[f]-poses[0]-np.array([0,0,1.625*f/30]))[mask],axis=1).max() for f in range(13)]
    cm[side+'_sole_world_slip_m']=float(max(displacement))
   if clip in ['Idle','PostIdle','SitIdle']:
    cm[side+'_sole_motion_m']=float(max(np.linalg.norm((a-ps[0])[mask],axis=1).max() for a in ps))
  result['clips'][clip]=cm
 out.append(result)
(ROOT/'skin-validation.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print(json.dumps(out,indent=2))
