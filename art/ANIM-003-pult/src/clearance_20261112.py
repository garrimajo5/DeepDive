import sys,inspect,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import build as m
from gltf_support import *
m.EYE=Vector((0,1.4541,-.6476))
exec(inspect.getsource(m.solve).replace('-1.9-','-2.05-'),m.__dict__)
for sex in ['muzhchina','zhenshchina']:
 d,b=read(m.REPO/'models'/('ekipazh-'+sex+'.glb'));r,base=m.sample(d,b,'PostIdle')
 hip=base[r.names['Hips']].translation;delta=Matrix.Translation(hip)@rot('X',-1.2+math.radians(10)).to_4x4()@Matrix.Translation(-hip);bg={i:g.copy() for i,g in base.items()}
 for i in r.j:
  if not any(t in d['nodes'][i]['name'] for t in ['Leg','Foot','Toe']):bg[i]=delta@bg[i]
 g=m.solve(r,bg,.5,pole=Vector((0,-1,0)),distance=.2);hi=r.names['RightHand'];g[hi]=mat(r.rest[hi].to_3x3(),g[hi].translation)
 p,w,j=m.skin(d,b,r,g);ds=np.linalg.norm(p-np.array(m.EYE),axis=1);ix=np.argsort(ds)[:5]
 print(sex,[(int(v),float(ds[v]),list(p[v]),[(d['nodes'][r.j[k]]['name'],float(ww)) for k,ww in zip(j[v],w[v])]) for v in ix],flush=True)
 print('bones',[(n,list(g[i].translation)) for n,i in r.names.items()])
