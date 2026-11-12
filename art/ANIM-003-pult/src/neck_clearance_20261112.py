"""Fixed-camera clearance and neighbouring slider validation; diagnostic only."""
import sys,inspect,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import build as m
from gltf_support import *
from mathutils.bvhtree import BVHTree
m.EYE=Vector((0,1.4541,-.6476))
exec(inspect.getsource(m.solve).replace('-1.9-','-2.05-'),m.__dict__)
exec(inspect.getsource(m.mask_for).replace('v=p[tri];','v=p[tri];\n  if np.cross(v[1,:2]-v[0,:2],v[2,:2]-v[0,:2])>=0:continue'),m.__dict__)
def pose(d,r,base,share,neckangle):
 hip=base[r.names['Hips']].translation;delta=Matrix.Translation(hip)@rot('X',-1.2+math.radians(10)).to_4x4()@Matrix.Translation(-hip);bg={i:g.copy() for i,g in base.items()}
 for i in r.j:
  if not any(t in d['nodes'][i]['name'] for t in ['Leg','Foot','Toe']):bg[i]=delta@bg[i]
 pivot=bg[r.names['neck']].translation;nd=Matrix.Translation(pivot)@rot('X',neckangle).to_4x4()@Matrix.Translation(-pivot)
 for n in ['neck','Head','head_end','headfront']:bg[r.names[n]]=nd@bg[r.names[n]]
 g=m.solve(r,bg,share,pole=Vector((0,-1,0)),distance=.2);hi=r.names['RightHand'];g[hi]=mat(r.rest[hi].to_3x3(),g[hi].translation)
 return g
if __name__=='__main__':
 rows=[]
 for sex in ['muzhchina','zhenshchina']:
  d,b=read(m.REPO/'models'/('ekipazh-'+sex+'.glb'));r,base=m.sample(d,b,'PostIdle');tri=accessor(d,b,d['meshes'][0]['primitives'][0]['indices']).astype(int).reshape(-1,3)
  for angle in [-.6,-.4,-.2,0,.2,.4,.6]:
   g=pose(d,r,base,.5,angle);p,_,_=m.skin(d,b,r,g);near=BVHTree.FromPolygons(p,tri,all_triangles=True).find_nearest(m.EYE)
   row={'sex':sex,'neck_rad':angle,'surface_clearance':near[3]};rows.append(row);print(row,flush=True)
  for s in [0,.25,.5,.75,1]:
   g=pose(d,r,base,s,.4);mask=m.mask_for(d,b,r,g,'Right');left=m.mask_for(d,b,r,g,'Left');y=.72+.56*s;z=-2.05-(-.35+.103*(y-.75))+.03;adj=m.project(np.array([[.17,y,z],[-.17,y,z]]));print(sex,s,'area',int(mask.sum()),'left',int(left.sum()),'neighbours',[(list(v[:2]),bool(mask[int(v[1]),int(v[0])])) for v in adj],flush=True)
 (m.ROOT/'neck-clearance-20261112.json').write_text(json.dumps(rows,indent=2))
