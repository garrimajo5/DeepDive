"""Blender background authoring study; source GLB payload and old clips preserved."""
import sys,copy,json,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from gltf_support import *
from sample_source import sample
OUT=Path(__file__).resolve().parents[1];REPO=OUT.parents[1]
d,b=read(REPO/'models/serpohvost-anim.glb');r,base=sample(d,b,'Swim');_,fast=sample(d,b,'SwimFast');tip=Vector((0,-.19,4.2));local_tip=r.rest[r.names['Tail03']].inverted()@tip
base_tip=base[r.names['Tail03']]@local_tip
# Quintic Hermite: endpoint position, velocity, acceleration.
def quint(t,keys):
 for a,z in zip(keys,keys[1:]):
  if a[0]<=t<=z[0]+1e-8:
   h=z[0]-a[0];u=(t-a[0])/h;c=np.array([a[1],a[2]*h,a[3]*h*h/2]);rhs=np.array([z[1]-sum(c),z[2]*h-c[1]-2*c[2],z[3]*h*h-2*c[2]])
   tail=np.linalg.solve(np.array([[1,1,1],[3,4,5],[6,12,20]]),rhs);return float(np.polynomial.polynomial.polyval(u,np.r_[c,tail]))
 return keys[-1][1]
def rotate_chain(g,name,axis,angle):
 i=r.names[name];pivot=g[i].translation;delta=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,axis)@Matrix.Translation(-pivot)
 def rec(k):
  g[k]=delta@g[k]
  for child in d['nodes'][k].get('children',[]):rec(child)
 rec(i)
def fins(g,front,rear,axis='Z'):
 for side,sign in [('L',-1),('R',1)]:
  rotate_chain(g,'FinFront'+side,axis,math.radians(front)*sign)
  rotate_chain(g,'FinRear'+side,axis,math.radians(rear)*sign)
def pose(name,t,duration):
 g={i:v.copy() for i,v in base.items()};u=t/duration;w=math.sin(math.pi*u)**2
 if name=='TailStrike':
  y=quint(t,[(0,0,0,0),(.20,.30,0,-15),(.38,-.40,-7.2,10),(.55,-1,0,15),(.9,0,0,0)])
  rotate_chain(g,'Body','X',math.radians(.6)*w)
  fins(g,5*w,2*w)
  pivot=g[r.names['Tail01']].translation;v=g[r.names['Tail03']]@local_tip-pivot;rad=math.hypot(v.y,v.z);ang=math.asin(max(-.99,min(.99,(base_tip.y+y-pivot.y)/rad)))-math.atan2(v.y,v.z)
  rotate_chain(g,'Tail01','X',-ang)
 elif name=='Recoil':
  fins(g,18*w,7*w,'Y')
  rotate_chain(g,'Jaw','X',math.radians(2)*w)
  rotate_chain(g,'Body','X',math.radians(6)*w)
  for k in range(1,4):rotate_chain(g,f'Tail{k:02}','Y',math.radians(3)*math.sin(2*math.pi*u-k*.4)*w)
 elif name=='Hover':
  fins(g,7*math.sin(2*math.pi*u),3*math.sin(2*math.pi*u+.6))
  for k in range(1,4):rotate_chain(g,f'Tail{k:02}','Y',math.radians(1.8)*math.sin(2*math.pi*u-k*.8))
  rotate_chain(g,'Jaw','X',math.radians(-3))
 elif name=='Coil':
  s=u*u*u*(10+u*(-15+6*u))
  locals={}
  for i in r.j:
   pa=r.parent[i];a=base[pa].inverted()@base[i];z=fast[pa].inverted()@fast[i]
   p0,q0,sc=a.decompose();p1,q1,_=z.decompose();locals[i]=Matrix.LocRotScale(p0.lerp(p1,s),q0.slerp(q1,s),sc)
  def build(i):
   pa=r.parent.get(i)
   g[i]=(build(pa) if pa in locals else base[pa])@locals[i]
   return g[i]
  for i in r.j:build(i)
  rotate_chain(g,'Body','X',math.radians(-1)*w)
  fins(g,-15*w,-9*w,'Y')
  for k in range(1,4):rotate_chain(g,f'Tail{k:02}','Y',math.radians([7,-14,20][k-1])*w)
 else:
  for k in range(1,4):g[r.names[f'Tail{k:02}']]=r.rest[r.names[f'Tail{k:02}']].copy()
  rotate_chain(g,'FinFrontR' if name=='BendL' else 'FinFrontL','Z',math.radians(20)*(1 if name=='BendL' else -1))
  for k,deg in enumerate([12,18,22],1):rotate_chain(g,f'Tail{k:02}','Y',math.radians(deg)*(1 if name=='BendR' else -1))
 return g
clips={'TailStrike':.9,'Recoil':1.,'Hover':4.,'Coil':.5,'BendL':1/30,'BendR':1/30};report={}
for name,dur in clips.items():
 n=round(dur*60);gs=[pose(name,f/60,dur) for f in range(n+1)];times=append(d,b,[[f/60] for f in range(n+1)],'SCALAR');anim={'name':name,'samplers':[],'channels':[]}
 for i in r.j:
  qs=[]
  for g in gs:
   loc=g[r.parent[i]].inverted()@g[i];q=loc.to_quaternion()
   if qs and sum(a*bb for a,bb in zip(qs[-1],[q.x,q.y,q.z,q.w]))<0:q.negate()
   qs.append([q.x,q.y,q.z,q.w])
  out=append(d,b,qs,'VEC4');anim['channels'].append({'sampler':len(anim['samplers']),'target':{'node':i,'path':'rotation'}});anim['samplers'].append({'input':times,'output':out,'interpolation':'LINEAR'})
 d['animations']=[a for a in d['animations'] if a['name']!=name]+[anim]
 vals={}
 for hz in [30,60]:
  pts=np.array([list(pose(name,f/hz,dur)[r.names['Tail03']]@local_tip) for f in range(round(dur*hz)+1)]);acc=np.linalg.norm(np.diff(pts,n=2,axis=0)*hz*hz,axis=1);vel=np.linalg.norm((pts[2:]-pts[:-2])*hz/2,axis=1)
  vals[hz]={'amax':float(max(acc,default=0)),'vmax':float(max(vel,default=0)),'dy_min':float(min(pts[:,1]-base_tip.y)),'dy_max':float(max(pts[:,1]-base_tip.y))}
 report[name]=vals
write(OUT/'serpohvost-anim.glb',d,b);(OUT/'author-metrics.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
