from pathlib import Path
import numpy as np
from PIL import Image
import ast,json,hashlib
R=Path(__file__).resolve().parents[1]; REPO=R.parents[1]; C=REPO/'docs/concept-art';TMP=R/'renders';TMP.mkdir(exist_ok=True)
N=1024;METRES_PER_PX=2/1024
def arr(p,mode):return np.array(Image.open(p).convert(mode)).astype(float)
base=arr(C/'obshivka-tsvet.png','RGB');mask=arr(C/'obshivka-maska.png','L');damage=arr(C/'povrezhdeniya-tsvet.png','RGBA');level=arr(C/'povrezhdeniya-uroven.png','L')
def blur(a,s):
 f=np.fft.fftfreq(a.shape[0]);g=np.fft.fftfreq(a.shape[1]);k=np.exp(-2*np.pi**2*s*s*(f[:,None]**2+g[None,:]**2))
 return np.fft.ifft2(np.fft.fft2(a)*k).real
def periodic(a):
 a=a.copy();a[-1]=a[0];a[:,-1]=a[:,0];return a
def normals(h,active=None):
 # PNG row increases downwards. OpenGL tangent Y points up: green is +dH/d(row).
 core=h[:-1,:-1];dx=(np.roll(core,-1,1)-np.roll(core,1,1))/(2*METRES_PER_PX);dy=(np.roll(core,-1,0)-np.roll(core,1,0))/(2*METRES_PER_PX)
 n=np.stack([-dx,dy,np.ones_like(dx)],-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
 n=np.pad(n,((0,1),(0,1),(0,0)),mode='wrap')
 if active is not None:n[~active]=[0,0,1]
 out=np.rint((n*.5+.5)*255).astype('uint8');return periodic(out)
seam=(mask>240).astype(float)
h=-.0014*blur(seam,1.3)
y,x=np.mgrid[:N,:N];bolts=np.zeros((N,N))
centres=[]
for cy in [0,255,511,767]:
 for cx in [109,255,399,626,770,914]:centres.append((cx,cy,12))
for cx in [0,512]:
 for cy in [95,350,604,860]:centres.append((cx,cy,12))
for cy in [342,413]:
 for cx in [817,883,949]:centres.append((cx,cy,8))
for cx,cy,rad in centres:
 dx=np.minimum(abs(x-cx),N-1-abs(x-cx));dy=np.minimum(abs(y-cy),N-1-abs(y-cy));rr=np.sqrt(dx*dx+dy*dy)/rad
 dome=np.maximum(0,1-rr*rr)**1.25
 dome*=seam # Mask guarantees no fastener relief displaced from the accepted dark footprint.
 bolts=np.maximum(bolts,dome)
h+=.004*bolts;h=periodic(h)
nb=normals(h)
rough=.82-.34*blur(seam,1)-.10*bolts
# Stains stay matte; a narrow polished strip beside a panel seam is smoother than paint.
edge=np.clip(blur(seam,4)-blur(seam,1),0,1);rough-=.28*edge
rough=np.clip(rough,.35,.86);rough=periodic(np.rint(rough*255).astype('uint8'))

tree=ast.parse((R/'source/prepare-art049.py').read_text('utf-8'))
features=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='features' for t in n.targets))
sy,sx=np.mgrid[:1254,:1254];score=np.full((1254,1254),1e6);ids=np.zeros((1254,1254),np.uint8)
for k,(_,threshold,(x0,y0,x1,y1)) in enumerate(features):
 s=((sx-(x0+x1)/2)/((x1-x0)/2+8))**2+((sy-(y0+y1)/2)/((y1-y0)/2+8))**2
 inside=(sx>=x0-12)&(sx<x1+12)&(sy>=y0-12)&(sy<y1+12);s=np.where(inside,s,s+100)
 use=s<score;ids[use]=k;score[use]=s[use]
ids=np.array(Image.fromarray(ids).resize((N,N),Image.Resampling.NEAREST));ids=np.roll(ids,(317,211),(0,1));ids=periodic(ids)
assert np.array_equal(np.array([f[1] for f in features])[ids],level),'Feature registration differs from accepted ART-049'
alpha=damage[:,:,3]/255;lum=damage[:,:,:3]@np.array([.2126,.7152,.0722])/255
hd=np.zeros((N,N));reports=[]
for k,(kind,t,bounds) in enumerate(features):
 a=alpha*(ids==k);soft=blur(a,1.2); cx=(bounds[0]+bounds[2])/2/1254*N+211;cy=(bounds[1]+bounds[3])/2/1254*N+317
 dx=(x-cx+N/2)%N-N/2;dy=(y-cy+N/2)%N-N/2
 rx=(bounds[2]-bounds[0])/2/1254*N;ry=(bounds[3]-bounds[1])/2/1254*N;r2=(dx/rx)**2+(dy/ry)**2
 if kind=='vmyatina':hh=-.006*np.exp(-2.4*r2)*soft+.00035*np.exp(-((np.sqrt(r2)-.8)/.13)**2)*soft
 elif kind=='koltso':hh=.0018*blur(a,3.2)
 elif kind=='skol':hh=-.00035*soft
 elif kind=='tsarapiny':
  # Fine dark lines become grooves only within the preclassified scratch groups.
  numerator=blur(lum*a,.7);denom=blur(a,.7);local=np.divide(numerator,denom,out=np.zeros_like(a),where=denom>.001)
  dark=np.clip(blur(local,2.5)-local,0,.3)
  hh=-.00045*soft-.005*dark*soft
 else:
  # Raised patch, weld bead ring derived from its alpha boundary, fine bead modulation from local colour.
  rim=np.clip(blur(a,2)-blur(a,6),0,1)*6
  hh=.0006*soft+.0018*rim*(.85+.15*lum)
 hh*=alpha>0;hd+=hh
 reports.append({'id':k,'kind':kind,'threshold':t,'height_min_mm':float(hh.min()*1000),'height_max_mm':float(hh.max()*1000)})
hd=periodic(hd);nd=normals(hd,alpha>0)
Image.fromarray(nb,'RGB').save(R/'obshivka-normali.png',optimize=True)
Image.fromarray(rough,'L').save(R/'obshivka-sheroh.png',optimize=True)
Image.fromarray(nd,'RGB').save(R/'povrezhdeniya-normali.png',optimize=True)

# Material preview inputs: same accepted colour and shader seam preservation; no biofilm in coupon comparison.
t=np.clip((mask/255-.75)/.2,0,1);sm=t*t*(3-2*t)
col=base*(1-.3*sm[:,:,None]);a=alpha*(level<=.85*255)*(1-.55*sm)
col15=col*(1-a[:,:,None])+damage[:,:,:3]*a[:,:,None]
Image.fromarray(np.uint8(np.clip(col,0,255))).save(TMP/'color-clean.png')
Image.fromarray(np.uint8(np.clip(col15,0,255))).save(TMP/'color-15.png')
def decode(p):
 n=p.astype(float)/255*2-1;n/=np.linalg.norm(n,axis=-1,keepdims=True);return n
def rnm(a,b):
 t=a+np.array([0,0,1]);u=b*np.array([-1,-1,1]);r=t*np.sum(t*u,axis=-1,keepdims=True)/np.maximum(t[:,:,2:3],1e-6)-u
 return r/np.linalg.norm(r,axis=-1,keepdims=True)
base_n=decode(nb);detail=decode(nd);detail=detail*a[:,:,None]+np.array([0,0,1])*(1-a[:,:,None]);detail/=np.linalg.norm(detail,axis=-1,keepdims=True)
blend=rnm(base_n,detail);n15=np.uint8(np.clip(np.rint((blend*.5+.5)*255),0,255));Image.fromarray(n15).save(TMP/'normal-15.png')

# Sign proof independent of accepted artwork: a positive dome must have OpenGL green>128 on its upper slope.
test=.003*np.exp(-((x-512)**2+(y-512)**2)/80);nt=normals(test)
assert nt[507,512,1]>128 and nt[517,512,1]<128
assert np.array_equal(nd[alpha==0],np.tile([128,128,255],((alpha==0).sum(),1)))
for im in [nb,nd,rough]:assert np.array_equal(im[0],im[-1]) and np.array_equal(im[:,0],im[:,-1])
report={'tile_m':2,'normal_format':'OpenGL +Y; RGB8 linear','height_base_range_mm':[float(h.min()*1000),float(h.max()*1000)],'damage_features':reports,'feature_threshold_registration_exact':True,'outside_alpha_normal':[128,128,255],'edges_exact':True,'green_dome_test':True,'source_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [C/'obshivka-tsvet.png',C/'obshivka-maska.png',C/'povrezhdeniya-tsvet.png',C/'povrezhdeniya-uroven.png']}}
for p in R.glob('*.png'):assert p.stat().st_size<2_000_000
(R/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='damage_features'},indent=2))
