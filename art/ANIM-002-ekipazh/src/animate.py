"""Blender 4.5: author bone poses and append animation channels to untouched source GLB.
Run blender -b -P this.py -- [build|render]
Original binary/accessors/nodes/skins/materials are preserved verbatim.
"""
import bpy,json,struct,math,sys,copy
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
ROOT=Path(__file__).resolve().parents[1]; REPO=ROOT.parents[1]
CLIPS={'Idle':120,'Walk':24,'SitIdle':120,'PostIdle':120}
def read(p):
 b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0]
 return json.loads(b[20:20+n]),bytearray(b[28+n:])
def trs(n):
 q=n.get('rotation',[0,0,0,1])
 return Matrix.LocRotScale(Vector(n.get('translation',[0,0,0])),Quaternion((q[3],*q[:3])),Vector(n.get('scale',[1,1,1])))
def frame(d,ref):
 y=d.normalized(); z=ref-y*ref.dot(y)
 if z.length<1e-6:z=Vector((0,0,1))-y*y.z
 z.normalize();return Matrix((y.cross(z),y,z)).transposed()
def turn(a,ra,b,rb): return frame(b,rb)@frame(a,ra).transposed()
def rot(axis,a):return Matrix.Rotation(a,3,axis)
def mat(r,o):
 m=r.to_4x4();m.translation=o;return m
import numpy as np
def accessor(d,b,k):
 a=d['accessors'][k];v=d['bufferViews'][a['bufferView']];ct={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']]
 nc={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 z=np.frombuffer(b,dtype=ct,count=a['count']*nc,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,nc).copy()
 return z/np.iinfo(ct).max if a.get('normalized') else z

class Rig:
 def __init__(self,d,b=None):
  self.d=d; self.j=d['skins'][0]['joints'];self.names={n['name']:i for i,n in enumerate(d['nodes'])}
  self.parent={c:i for i,n in enumerate(d['nodes']) for c in n.get('children',[])}
  self.local=[trs(n) for n in d['nodes']]; self.rest={}
  def glob(i):
   if i not in self.rest:self.rest[i]=glob(self.parent[i])@self.local[i] if i in self.parent else self.local[i]
   return self.rest[i]
  for i in range(len(self.local)):glob(i)
  self.R={d['nodes'][i]['name']:self.rest[i] for i in self.j}
  self.skin={}
  if b is not None:
   att=d['meshes'][0]['primitives'][0]['attributes'];p=accessor(d,b,att['POSITION']);ww=accessor(d,b,att['WEIGHTS_0']);jj=accessor(d,b,att['JOINTS_0']).astype(int);ib=accessor(d,b,d['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
   for side in ['Left','Right']:
    mask=(p[:,1]<.065)&((p[:,0]<0) if side=='Left' else (p[:,0]>0));ids=np.flatnonzero(mask)[::2]
    self.skin[side]=(np.column_stack([p[ids],np.ones(len(ids))]),ww[ids],jj[ids],ib)
 def pos(self,n):return self.R[n].translation.copy()
 def pose(self,clip,t):
  phase=t/(CLIPS[clip]/30); wave=math.sin(phase*2*math.pi)
  root=self.pos('Hips'); root.x+=.004*wave if clip!='Walk' else .008*wave
  lean=0
  if clip=='Walk':root.y-=getattr(self,"drop",.09)+.008*(1-math.cos(phase*4*math.pi))
  if clip=='SitIdle':root.y=.67;lean=math.radians(25)
  if clip=='PostIdle':lean=math.radians(-10)
  # Rotation about world X: positive tilts upright toward +Z (back).
  torso=rot('X',lean);g={}
  for i in self.j:
   n=self.d['nodes'][i]['name'];p=self.parent.get(i)
   if n=='Hips':g[i]=mat(torso@self.rest[i].to_3x3(),root);continue
   g[i]=g.get(p,self.rest[p])@self.local[i]
   if n=='Spine01':
    g[i]=mat(rot('X',math.radians(.65)*wave)@g[i].to_3x3(),g[i].translation)
   if n=='Head':
    g[i]=mat(rot('Y',math.radians(2)*wave)@g[i].to_3x3(),g[i].translation)
  def solve(names,target,pole):
   i,j,k=[self.names[n] for n in names]
   a=g[i].translation; r0,r1,r2=[self.pos(n) for n in names]
   l1=(r1-r0).length;l2=(r2-r1).length;v=target-a;dist=min(v.length,l1+l2-1e-5);v.normalize()
   midalong=(l1*l1-l2*l2+dist*dist)/(2*dist)
   perp=pole-v*pole.dot(v);perp.normalize()
   mid=a+v*midalong+perp*math.sqrt(max(0,l1*l1-midalong*midalong));end=a+v*dist
   ref=r1-(r0+r2)*.5;ref+=Vector((0,0,.02 if 'Arm' in names[0] else -.02))
   for idx,rr,dr in [(i,r1-r0,mid-a),(j,r2-r1,end-mid)]:
    g[idx]=mat(turn(rr,ref,dr,perp)@self.rest[idx].to_3x3(),a if idx==i else mid)
   g[k]=mat(self.rest[k].to_3x3(),end)
  for side,offset in [('Left',0),('Right',.5)]:
   foot=self.pos(side+'Foot');q=(phase+offset)%1
   if clip=='Walk':
    foot.z+=getattr(self,'zoff',0)
    if q<=.5:foot.z+=-.325+1.3*q
    else:
     u=(q-.5)*2
     foot.z+=(2*u**3-3*u**2+1)*.325+(-2*u**3+3*u**2)*(-.325)+(2*u**3-3*u**2+u)*.65
     foot.y+=.09*math.sin(math.pi*u)**2
   elif clip=='SitIdle':foot.z-=.38
   solve([side+'UpLeg',side+'Leg',side+'Foot'],foot,Vector((0,0,-1)))
   toe=self.names[side+'ToeBase'];g[toe]=g[self.names[side+'Foot']]@self.local[toe]
   # Fit original sole vertices using poses only, retaining original skin weights.
   if self.skin:
    data=self.skin[side];pp,ww,jj,ib=data
    desired=pp[:,:3]+np.array(foot-self.pos(side+'Foot'))
    origin=foot.copy()
    def evaluate(v):
     solve([side+'UpLeg',side+'Leg',side+'Foot'],origin+Vector(v[:3]),Vector((0,0,-1)))
     fi=self.names[side+'Foot'];ti=self.names[side+'ToeBase']
     g[fi]=mat(rot('X',v[3])@rot('Y',v[4])@rot('Z',v[5])@self.rest[fi].to_3x3(),g[fi].translation)
     g[ti]=g[fi]@self.local[ti]
     mm=np.array([np.array(g[k]) for k in self.j])@ib
     sk=sum(ww[:,k,None]*np.einsum('nij,nj->ni',mm[jj[:,k]],pp) for k in range(4))[:,:3]
     return (sk-desired).reshape(-1)
    v=np.zeros(6)
    for it in range(10):
     error=evaluate(v);jac=np.empty((len(error),6))
     for c in range(6):
      vv=v.copy();vv[c]+=.0001;jac[:,c]=(evaluate(vv)-error)/.0001
     step=np.linalg.solve(jac.T@jac+np.eye(6)*.0001,-jac.T@error)
     step[:3]=np.clip(step[:3],-.03,.03);step[3:]=np.clip(step[3:],-.15,.15)
     v+=step
     if np.linalg.norm(step)<1e-6:break
    evaluate(v)

   shoulder=g[self.names[side+'Arm']].translation
   sign=-1 if shoulder.x<0 else 1
   target=Vector((sign*.29,.91,-.035))
   if clip=='Walk': target.z+=.13*math.cos(2*math.pi*(phase+offset))
   if clip=='SitIdle':target=Vector((sign*.20,.69,-.30))
   if clip=='PostIdle':target=Vector((sign*.25,1.04,-.32))
   solve([side+'Arm',side+'ForeArm',side+'Hand'],target,Vector((sign*.22,0,1)))
   # Palm follows forearm with its original rest relative rotation.
   hand=self.names[side+'Hand'];fore=self.names[side+'ForeArm']
   g[hand]=mat(g[fore].to_3x3()@self.local[hand].to_3x3(),g[hand].translation)
  return g
def append(d,b,vals,kind):
 while len(b)%4:b.append(0)
 off=len(b);flat=[z for v in vals for z in v];b.extend(struct.pack('<'+'f'*len(flat),*flat))
 view=len(d['bufferViews']);d['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(flat)*4})
 a={'bufferView':view,'componentType':5126,'count':len(vals),'type':kind}
 if kind=='SCALAR':a.update(min=[min(flat)],max=[max(flat)])
 idx=len(d['accessors']);d['accessors'].append(a);return idx
def write(p,d,b):
 d['buffers'][0]['byteLength']=len(b)
 j=json.dumps(d,separators=(',',':')).encode();j+=b' '*((-len(j))%4);b+=b'\0'*((-len(b))%4)
 p.write_bytes(struct.pack('<III',0x46546c67,2,28+len(j)+len(b))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(b),0x004e4942)+b)
def build():
 reports=[]
 for sex in ['muzhchina','zhenshchina']:
  name='ekipazh-'+sex;d,b=read(REPO/'models'/(name+'.glb'));rig=Rig(d,b);d['animations']=[]
  report={'file':name+'.glb','clips':{},'rest_positions':{n:list(rig.pos(n)) for n in rig.R}}
  for clip,count in CLIPS.items():
   poses=[rig.pose(clip,f/30) for f in range(count)];poses.append(copy.deepcopy(poses[0]))
   times=append(d,b,[[f/30] for f in range(count+1)],'SCALAR')
   ani={'name':clip,'samplers':[],'channels':[],'extras':{'loop':True,'loop_mode':1}}
   for i in rig.j:
    locals=[(g[rig.parent[i]].inverted() if rig.parent[i] in g else rig.rest[rig.parent[i]].inverted())@g[i] for g in poses]
    rots=[];trans=[]
    for m in locals:
     q=m.to_quaternion()
     if rots and q.dot(Quaternion((rots[-1][3],*rots[-1][:3])))<0:q.negate()
     rots.append([q.x,q.y,q.z,q.w]);trans.append(list(m.translation))
    for path,vals,kind in [('rotation',rots,'VEC4'),('translation',trans,'VEC3')]:
     oi=append(d,b,vals,kind);si=len(ani['samplers']);ani['samplers'].append({'input':times,'output':oi,'interpolation':'LINEAR'})
     ani['channels'].append({'sampler':si,'target':{'node':i,'path':path}})
   d['animations'].append(ani)
   foot=rig.names['LeftFoot']
   slip=[]
   if clip=='Walk':
    base=poses[0][foot].translation
    for f in range(13):slip.append((poses[f][foot].translation-base-Vector((0,0,1.625*f/30))).length)
   report['clips'][clip]={'seconds':count/30,'samples':count+1,'left_stance_max_slip_m':max(slip) if slip else None,'hips_y_min':min(g[rig.names['Hips']].translation.y for g in poses),'hips_y_max':max(g[rig.names['Hips']].translation.y for g in poses)}
  write(ROOT/(name+'.glb'),d,b)
  report['bytes']=(ROOT/(name+'.glb')).stat().st_size;reports.append(report)
 (ROOT/'measurements.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
 print('BUILD_OK',json.dumps(reports))
if __name__=='__main__':build()
