"""Pose search with fixed camera, backface-culled diagnostic masks."""
import sys,inspect,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import build as m
from gltf_support import *
m.EYE=Vector((0,1.4541,-.6476))
exec(inspect.getsource(m.solve).replace('-1.9-','-2.05-'),m.__dict__)
source=inspect.getsource(m.mask_for).replace("v=p[tri];","v=p[tri];\n  if np.cross(v[1,:2]-v[0,:2],v[2,:2]-v[0,:2])>=0:continue")
exec(source,m.__dict__)
rows=[]
for sex in ['muzhchina','zhenshchina']:
 d,b=read(m.REPO/'models'/('ekipazh-'+sex+'.glb'));r,base=m.sample(d,b,'PostIdle');best=None
 for lean,dist,poleidx,handmode in itertools.product([.9,1.05,1.2],[.2,.3,.4],range(3),range(2)):
  hip=base[r.names['Hips']].translation;delta=Matrix.Translation(hip)@rot('X',-lean+math.radians(10)).to_4x4()@Matrix.Translation(-hip);bg={i:g.copy() for i,g in base.items()}
  for i in r.j:
   if not any(t in d['nodes'][i]['name'] for t in ['Leg','Foot','Toe']):bg[i]=delta@bg[i]
  samples=[]
  for share in [0,.25,.5,.75,1]:
   try:g=m.solve(r,bg,share,pole=Vector([(0,-1,0),(.5,-1,.2),(-.5,-1,.2)][poleidx]),distance=dist)
   except ValueError:break
   if handmode:
    hi=r.names['RightHand'];g[hi]=mat(r.rest[hi].to_3x3(),g[hi].translation)
   mask=m.mask_for(d,b,r,g,'Right');p,_,_=m.skin(d,b,r,g);near=float(np.linalg.norm(p-np.array(m.EYE),axis=1).min())
   samples.append({'share':share,'area':int(mask.sum()),'table':int(mask[190:669,1660:2361].sum()),'min_vertex_distance':near})
  if len(samples)!=5:continue
  row={'sex':sex,'lean':lean,'distance':dist,'pole':poleidx,'handmode':handmode,'samples':samples};rows.append(row)
  score=max(s['area']+5*s['table'] for s in samples)
  if best is None or score<best[0]:best=(score,row)
 print('BEST',json.dumps(best),flush=True)
(m.ROOT/'pose-search-20261112.json').write_text(json.dumps(rows,indent=2))
