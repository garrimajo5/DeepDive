import sys,json,types,numpy as np
from pathlib import Path
H=Path(__file__).resolve().parent
code=(H/'animate.py').read_text().replace('[::2]','')
m=types.ModuleType('anim');m.__file__=str(H/'animate.py');exec(compile(code,m.__file__,'exec'),m.__dict__)
results=[]
for sex in ['muzhchina','zhenshchina']:
 d,b=m.read(m.REPO/'models'/('ekipazh-'+sex+'.glb'));att=d['meshes'][0]['primitives'][0]['attributes'];p=m.accessor(d,b,att['POSITION']);w=m.accessor(d,b,att['WEIGHTS_0']);j=m.accessor(d,b,att['JOINTS_0']).astype(int);r=m.Rig(d,b);changes=[]
 for i in np.flatnonzero(p[:,1]<.065):
  side='Left' if p[i,0]<0 else 'Right';leg=r.j.index(r.names[side+'Leg']);foot=r.j.index(r.names[side+'Foot']);slots=np.flatnonzero(j[i]==leg)
  if not len(slots):continue
  oldw=w[i].copy();oldj=j[i].copy()
  for slot in slots:
   if w[i,slot]<=0:continue
   fs=np.flatnonzero(j[i]==foot)
   if len(fs):w[i,fs[0]]+=w[i,slot];w[i,slot]=0
   else:j[i,slot]=foot
  if not np.array_equal(w[i],oldw) or not np.array_equal(j[i],oldj):changes.append({'vertex':int(i),'old_joints':oldj.tolist(),'old_weights':oldw.tolist(),'new_joints':j[i].tolist(),'new_weights':w[i].tolist()})
 for key,arr in [('WEIGHTS_0',w),('JOINTS_0',j)]:
  a=d['accessors'][att[key]];v=d['bufferViews'][a['bufferView']];dtype={5126:'<f4',5123:'<u2',5121:'u1'}[a['componentType']];off=v.get('byteOffset',0)+a.get('byteOffset',0);raw=arr.astype(dtype).tobytes();b[off:off+len(raw)]=raw
 r=m.Rig(d,b);ib=m.accessor(d,b,d['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1);ph=np.column_stack([p,np.ones(len(p))]);report={'sex':sex,'changed_vertices':changes,'clips':{}}
 for clip,count in m.CLIPS.items():
  poses=[]
  for f in range(count):
   g=r.pose(clip,f/30);mm=np.array([np.array(g[k]) for k in r.j])@ib;poses.append(sum(w[:,k,None]*np.einsum('nij,nj->ni',mm[j[:,k]],ph) for k in range(4))[:,:3])
  item={'floor_m':float(min(x[:,1].min() for x in poses))}
  if clip=='Walk':
   for side,start in [('Left',0),('Right',12)]:
    mask=(p[:,1]<.065)&((p[:,0]<0) if side=='Left' else (p[:,0]>0));item[side+'_slip_m']=float(max(np.linalg.norm((poses[(start+f)%24]-poses[start]-np.array([0,0,1.625*f/30]))[mask],axis=1).max() for f in range(13)))
  report['clips'][clip]=item
 results.append(report);print(sex,len(changes),report['clips'],flush=True)
(H.parent/'heel-experiment-20261111.json').write_text(json.dumps(results,indent=2))
