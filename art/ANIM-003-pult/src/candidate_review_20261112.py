"""Evaluate rejected candidates and produce diagnostic masks, not acceptance renders."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import neighbour_search_20261112 as n
from gltf_support import *
from mathutils.bvhtree import BVHTree
m=n.m;rows=[]
for sex,lean,dist,yaw,tilt in [('muzhchina',1.35,.25,-30,90),('zhenshchina',1.2,.25,-90,0)]:
 d,b=read(m.REPO/'models'/('ekipazh-'+sex+'.glb'));r,base=m.sample(d,b,'PostIdle');tris=accessor(d,b,d['meshes'][0]['primitives'][0]['indices']).astype(int).reshape(-1,3);panels=[];samples=[]
 for s in [0,.25,.5,.75,1]:
  g=n.n.pose2(d,r,base,s,-.4,lean,dist);hi=r.names['RightHand'];g[hi]=mat(rot('Z',math.radians(tilt))@rot('Y',math.radians(yaw))@r.rest[hi].to_3x3(),g[hi].translation)
  p,_,_=m.skin(d,b,r,g);near=BVHTree.FromPolygons(p,tris,all_triangles=True).find_nearest(m.EYE)[3];mask=m.mask_for(d,b,r,g,'Right');left=m.mask_for(d,b,r,g,'Left');y=.72+.56*s;z=-2.05-(-.35+.103*(y-.75))+.03;pts=m.project(np.array([[.17,y,z],[-.17,y,z]]))[:,:2]
  samples.append({'share':s,'right_area':int(mask.sum()),'left_area':int(left.sum()),'table_pixels':int(mask[190:669,1660:2361].sum()),'surface_clearance_m':near,'adjacent_centres_covered':[bool(mask[int(pt[1]),int(pt[0])]) for pt in pts]})
  rgb=np.zeros((1080,2400,4),np.float32);rgb[:]=(.035,.05,.07,1);rgb[mask]=(.1,.65,.9,1);rgb[left]=(1,.4,.08,1);rgb[190:669,1660:1664,:3]=1;rgb[190:669,2357:2361,:3]=1;rgb[190:194,1660:2361,:3]=1;rgb[665:669,1660:2361,:3]=1
  for pt in pts:
   x,yy=map(int,pt);rgb[max(0,yy-9):yy+10,max(0,x-9):x+10,:3]=(1,.05,.05)
  panels.append(rgb[::4,::4])
 strip=np.concatenate(panels,axis=1);h,w=strip.shape[:2];im=bpy.data.images.new(sex,width=w,height=h,alpha=True);im.pixels.foreach_set(strip[::-1].ravel());im.filepath_raw=str(m.ROOT/(sex+'-neighbours-20261112.png'));im.file_format='PNG';im.save()
 rows.append({'sex':sex,'lean_rad':lean,'wrist_distance_m':dist,'neck_rad':-.4,'wrist_yaw_deg':yaw,'wrist_tilt_deg':tilt,'samples':samples,'verdict':'REJECTED: visually excessive torso bending; male also occludes adjacent slider centre at share 1. Not final animation.'})
(m.ROOT/'candidate-review-20261112.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows,indent=2))
