import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from animate import *
d,b=read(REPO/'models/ekipazh-muzhchina.glb');r=Rig(d,b)
pp,ww,jj,ib=r.skin['Left']
def vertices(g):
 mm=np.array([np.array(g[k]) for k in r.j])@ib
 return sum(ww[:,k,None]*np.einsum('nij,nj->ni',mm[jj[:,k]],pp) for k in range(4))[:,:3]
results=[]
for drop in [.03,.06,.09,.12,.15,.18]:
 for zoff in [-.1,0,.1,.2]:
  r.drop=drop;r.zoff=zoff
  vs=[vertices(r.pose('Walk',f/30)) for f in [0,3,6,9,12]]
  slip=max(np.linalg.norm(a-vs[0]-np.array([0,0,.1625*k]),axis=1).max() for k,a in enumerate(vs))
  floor=min(a[:,1].min() for a in vs)
  item=dict(drop=drop,zoff=zoff,slip=float(slip),floor=float(floor));results.append(item);print(item,flush=True)
(ROOT/'parameter-search.json').write_text(json.dumps(results,indent=2))
