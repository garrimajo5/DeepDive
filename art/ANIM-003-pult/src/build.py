import sys,json,copy,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from gltf_support import *
ROOT=Path(__file__).resolve().parents[1]; REPO=ROOT.parents[1]
CLIPS={'PowerReach':12,'PowerSlide':30,'PowerRelease':12}
def sample(d,b,name,t=0):
 r=Rig(d);loc=[x.copy() for x in r.local]
 a=next(a for a in d['animations'] if a['name']==name)
 for c in a['channels']:
  s=a['samplers'][c['sampler']];ts=accessor(d,b,s['input']).ravel();v=accessor(d,b,s['output']);ix=min(int(np.searchsorted(ts,t,side='right'))-1,len(ts)-2);ix=max(0,ix);f=float(np.clip((t-ts[ix])/(ts[ix+1]-ts[ix]),0,1));i=c['target']['node'];path=c['target']['path'];p,q,sc=loc[i].decompose()
  if path=='rotation':q=Quaternion((v[ix,3],*v[ix,:3])).slerp(Quaternion((v[ix+1,3],*v[ix+1,:3])),f)
  elif path=='translation':p=Vector(v[ix]).lerp(Vector(v[ix+1]),f)
  loc[i]=Matrix.LocRotScale(p,q,sc)
 g={}
 def glob(i):
  if i not in g:g[i]=glob(r.parent[i])@loc[i] if i in r.parent else loc[i]
  return g[i]
 for i in range(len(loc)):glob(i)
 return r,g
if __name__=='__main__':
 for sex in ['muzhchina','zhenshchina']:
  d,b=read(REPO/'models'/('ekipazh-'+sex+'.glb'));r,g=sample(d,b,'PostIdle')
  print(sex,{n:list(g[r.names[n]].translation) for n in ['Head','RightArm','RightForeArm','RightHand','LeftHand']})
EYE=Vector((0,1.65,0))
def solve(r,base,share,pole=Vector((.5,-1,.2)),distance=.55):
 g={i:m.copy() for i,m in base.items()}
 # Bring clavicle forward, with unchanged joint translations and bone lengths.
 si=r.names['RightShoulder'];ai=r.names['RightArm'];fi=r.names['RightForeArm'];hi=r.names['RightHand']
 g[si]=mat(rot('Y',math.radians(25))@g[si].to_3x3(),g[si].translation)
 g[ai]=g[si]@r.local[ai]
 y=.72+.56*share;knob=Vector((0,y,-1.9-(-.35+.103*(y-.75))+.03))
 target=EYE+(knob-EYE).normalized()*distance
 a=g[ai].translation;rr=[r.pos(n) for n in ['RightArm','RightForeArm','RightHand']];l1=(rr[1]-rr[0]).length;l2=(rr[2]-rr[1]).length;v=target-a;dist=v.length
 if dist>l1+l2:raise ValueError(('unreachable',share,dist,l1+l2))
 v.normalize();along=(l1*l1-l2*l2+dist*dist)/(2*dist);perp=(pole-v*pole.dot(v)).normalized();mid=a+v*along+perp*math.sqrt(max(0,l1*l1-along*along));ref=rr[1]-(rr[0]+rr[2])*.5+Vector((0,0,.02))
 for i,orig,dest,pos in [(ai,rr[1]-rr[0],mid-a,a),(fi,rr[2]-rr[1],target-mid,mid)]:g[i]=mat(turn(orig,ref,dest,perp)@r.rest[i].to_3x3(),pos)
 g[hi]=mat(g[fi].to_3x3()@r.local[hi].to_3x3(),target)
 return g

def skin(d,b,r,g):
 att=d['meshes'][0]['primitives'][0]['attributes'];p=accessor(d,b,att['POSITION']);w=accessor(d,b,att['WEIGHTS_0']);j=accessor(d,b,att['JOINTS_0']).astype(int);ib=accessor(d,b,d['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1);mm=np.array([np.array(g[k]) for k in r.j])@ib;pp=np.column_stack((p,np.ones(len(p))))
 return sum(w[:,k,None]*np.einsum('nij,nj->ni',mm[j[:,k]],pp) for k in range(4))[:,:3],w,j

def project(points):
 yaw=math.radians(-20);pitch=math.radians(-32);q=points-np.array(EYE);right=np.array([math.cos(yaw),0,-math.sin(yaw)]);up=np.array([math.sin(yaw)*math.sin(pitch),math.cos(pitch),math.cos(yaw)*math.sin(pitch)]);forward=np.array([-math.sin(yaw)*math.cos(pitch),math.sin(pitch),-math.cos(yaw)*math.cos(pitch)]);z=q@forward;f=540/math.tan(math.radians(36))
 return np.column_stack((1200+f*(q@right)/z,540-f*(q@up)/z,z))
def mask_for(d,b,r,g,side):
 p,w,j=skin(d,b,r,g);p=project(p);ids=[r.j.index(r.names[side+n]) for n in ['Shoulder','Arm','ForeArm','Hand']];weights=np.sum(w*np.isin(j,ids),axis=1);tris=accessor(d,b,d['meshes'][0]['primitives'][0]['indices']).astype(int).reshape(-1,3);tris=tris[weights[tris].mean(axis=1)>.5];mask=np.zeros((1080,2400),dtype=bool)
 for tri in tris:
  v=p[tri];
  if np.any(v[:,2]<.03):continue
  x0=max(0,int(np.floor(v[:,0].min())));x1=min(2399,int(np.ceil(v[:,0].max())));y0=max(0,int(np.floor(v[:,1].min())));y1=min(1079,int(np.ceil(v[:,1].max())))
  if x0>x1 or y0>y1:continue
  x,y=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5);edges=[]
  for k in range(3):a=v[k];bb=v[(k+1)%3];edges.append((bb[0]-a[0])*(y-a[1])-(bb[1]-a[1])*(x-a[0]))
  inside=(np.minimum.reduce(edges)>=0)|(np.maximum.reduce(edges)<=0);mask[y0:y1+1,x0:x1+1]|=inside
 return mask
if __name__=='__main__':
 results=[]
 for sex in ['muzhchina','zhenshchina']:
  d,b=read(REPO/'models'/('ekipazh-'+sex+'.glb'));r,base=sample(d,b,'PostIdle');row={'sex':sex,'samples':[]}
  for share in [0,.25,.5,.75,1]:
   try:g=solve(r,base,share)
   except ValueError as e: print(sex,e);continue
   l=mask_for(d,b,r,g,'Left');m=mask_for(d,b,r,g,'Right');result={'share':share,'right_pixels':int(m.sum()),'left_pixels':int(l.sum()),'table_pixels':int(m[190:669,1660:2361].sum()),'above285_pixels':int(m[:285].sum())};row['samples'].append(result);print(sex,result)
  results.append(row)
 (ROOT/'diagnostic.json').write_text(json.dumps(results,indent=2))
