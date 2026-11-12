"""Search wrist roll and reach distance; reject any adjacent-slider centre occlusion."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import neck_clearance_20261112 as n
from gltf_support import *
import itertools
m=n.m
exec(__import__('inspect').getsource(n.pose).replace('def pose(', 'def pose2(').replace('-1.2+', '-lean+').replace('distance=.2','distance=distance').replace('neckangle):','neckangle,lean,distance):'),n.__dict__)
def hits(p,tris,pts):
 v=m.project(p)[tris];a=v[:,0,:2];bb=v[:,1,:2];c=v[:,2,:2];signed=np.cross(bb-a,c-a);valid=(signed<0)&(v[:,:,2].min(axis=1)>.03);out=[]
 for pt in pts:
  e0=np.cross(bb-a,pt-a);e1=np.cross(c-bb,pt-bb);e2=np.cross(a-c,pt-c)
  out.append(bool(np.any(valid&(e0<=0)&(e1<=0)&(e2<=0))))
 return out
if __name__=='__main__':
 rows=[]
 for sex in ['muzhchina','zhenshchina']:
  d,b=read(m.REPO/'models'/('ekipazh-'+sex+'.glb'));r,base=m.sample(d,b,'PostIdle');_,w,j=m.skin(d,b,r,base);ids=[r.j.index(r.names['Right'+nn]) for nn in ['Shoulder','Arm','ForeArm','Hand']];weights=np.sum(w*np.isin(j,ids),axis=1);tri=accessor(d,b,d['meshes'][0]['primitives'][0]['indices']).astype(int).reshape(-1,3);tri=tri[weights[tri].mean(axis=1)>.5]
  best=(99,None)
  for lean,distance in itertools.product([.9,1.05,1.2,1.35,1.5],[.2,.25,.3,.35,.4,.45]):
   poses=[]
   try:
    for s in [0,.25,.5,.75,1]:poses.append(n.pose2(d,r,base,s,-.4,lean,distance))
   except ValueError:continue
   for yaw,tilt in itertools.product(range(-90,91,30),[-45,0,45,90]):
    count=0;clear=1;ss=[]
    for s,g0 in zip([0,.25,.5,.75,1],poses):
     g={i:v.copy() for i,v in g0.items()};hi=r.names['RightHand'];g[hi]=mat(rot('Z',math.radians(tilt))@rot('Y',math.radians(yaw))@r.rest[hi].to_3x3(),g[hi].translation)
     p,_,_=m.skin(d,b,r,g);y=.72+.56*s;z=-2.05-(-.35+.103*(y-.75))+.03;pts=m.project(np.array([[.17,y,z],[-.17,y,z]]))[:,:2];hit=hits(p,tri,pts);count+=sum(hit);ss.append(hit)
    row={'sex':sex,'lean':lean,'distance':distance,'wrist_yaw_deg':yaw,'wrist_tilt_deg':tilt,'occluded_centres':count,'samples':ss}
    if count<best[0]:best=(count,row);print('BEST',best,flush=True)
    rows.append(row)
 (m.ROOT/'neighbour-search-20261112.json').write_text(json.dumps(rows,indent=2))
