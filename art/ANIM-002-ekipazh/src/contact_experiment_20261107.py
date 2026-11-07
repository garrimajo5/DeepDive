"""Compare full-sole minimax fitting, without modifying released assets."""
import sys, json, types
from pathlib import Path
HERE=Path(__file__).resolve().parent
src=(HERE/'animate.py').read_text()
variants={
 'baseline':src,
 'full_sole':src.replace('[::2]',''),
 'minimax':src.replace('[::2]','').replace('range(10)', 'range(30)').replace('step=np.linalg.solve(jac.T@jac+np.eye(6)*.0001,-jac.T@error)', '''weights=np.repeat(np.maximum(np.linalg.norm(error.reshape(-1,3),axis=1),.002)**2,3)
     weights/=weights.mean()
     step=np.linalg.solve(jac.T@(weights[:,None]*jac)+np.eye(6)*.0001,-jac.T@(weights*error))''')
}
variants['minimax_linesearch']=variants['minimax'].replace('range(30)','range(60)').replace('vv[c]+=.0001','vv[c]+=.001').replace('(evaluate(vv)-error)/.0001','(evaluate(vv)-error)/.001').replace('v+=step', '''base_cost=np.sum(weights*error**2)
     for alpha in [1,.5,.25,.125,.0625,.03125]:
      candidate=evaluate(v+alpha*step)
      if np.sum(weights*candidate**2)<base_cost:
       v+=alpha*step
       break
     else:break''')
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
(HERE.parent/'contact-experiment-20261107.json').write_text(json.dumps(results,indent=2))

