"""Explore toe articulation and leg trajectories without exporting assets."""
import sys, json, types
from pathlib import Path
HERE=Path(__file__).resolve().parent
src=(HERE/'animate.py').read_text()
variants={'toe_rotation':src.replace('[::2]','').replace('range(10)','range(30)').replace('v=np.zeros(6)','v=np.zeros(9)').replace('len(error),6','len(error),9').replace('range(6)','range(9)').replace('np.eye(6)','np.eye(9)').replace('g[ti]=g[fi]@self.local[ti]', "g[ti]=g[fi]@self.local[ti];g[ti]=mat(rot('X',v[6])@rot('Y',v[7])@rot('Z',v[8])@g[ti].to_3x3(),g[ti].translation)")}
variants={f'toe_drop_{drop}_z_{z}':code.replace('getattr(self,"drop",.09)',str(drop)).replace("getattr(self,'zoff',0)",str(z)) for code in variants.values() for drop in [.09,.12,.15,.18] for z in [0,.05,.1,.15]}
results=[]
for label,code in variants.items():
 mod=types.ModuleType(label);mod.__file__=str(HERE/'animate.py');exec(compile(code,mod.__file__,'exec'),mod.__dict__)
 d,b=mod.read(mod.REPO/'models/ekipazh-muzhchina.glb');r=mod.Rig(d,b)
 # Independent evaluation includes every sole vertex, even in baseline.
 p=mod.accessor(d,b,d['meshes'][0]['primitives'][0]['attributes']['POSITION'])
 att=d['meshes'][0]['primitives'][0]['attributes'];w=mod.accessor(d,b,att['WEIGHTS_0']);j=mod.accessor(d,b,att['JOINTS_0']).astype(int)
 ib=mod.accessor(d,b,d['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
 np=mod.np;ph=np.column_stack([p,np.ones(len(p))])
 poses=[]
 for f in range(24):
  g=r.pose('Walk',f/30);mm=np.array([np.array(g[k]) for k in r.j])@ib
  poses.append(sum(w[:,k,None]*np.einsum('nij,nj->ni',mm[j[:,k]],ph) for k in range(4))[:,:3])
 item={'variant':label,'floor_m':float(min(x[:,1].min() for x in poses))}
 for side,start in [('Left',0),('Right',12)]:
  mask=(p[:,1]<.065)&((p[:,0]<0) if side=='Left' else (p[:,0]>0))
  item[side+'_slip_m']=float(max(np.linalg.norm((poses[(start+f)%24]-poses[start]-np.array([0,0,1.625*f/30]))[mask],axis=1).max() for f in range(13)))
 results.append(item);print(json.dumps(item),flush=True)
(HERE.parent/'contact-trajectory-20261108.json').write_text(json.dumps(results,indent=2))




