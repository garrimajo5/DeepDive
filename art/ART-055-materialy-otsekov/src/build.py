from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1];N=1024
y,x=np.mgrid[:N,:N];u=x/(N-1);v=y/(N-1)
def sm(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def per(a):
 a=a.copy();a[-1]=a[0];a[:,-1]=a[:,0];return a
def blur(a,s):
 f=np.fft.fftfreq(a.shape[0]);g=np.fft.fftfreq(a.shape[1]);return np.fft.ifft2(np.fft.fft2(a)*np.exp(-2*np.pi**2*s*s*(f[:,None]**2+g[None,:]**2))).real
def normal(h):
 h=h[:-1,:-1];px=1/(N-1);dx=(np.roll(h,-1,1)-np.roll(h,1,1))/(2*px);dy=(np.roll(h,-1,0)-np.roll(h,1,0))/(2*px)
 n=np.stack([-dx,dy,np.ones_like(dx)],-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
 n=np.pad(n,((0,1),(0,1),(0,0)),mode='wrap');return per(np.uint8(np.clip(np.rint((n*.5+.5)*255),0,255)))
def mix(a,b,w):return a*(1-w[:,:,None])+np.array(b)*w[:,:,None]
def rect(cx,cy,w,h,r=.003):
 dx=np.abs((u-cx+.5)%1-.5)-(w/2-r);dy=np.abs((v-cy+.5)%1-.5)-(h/2-r)
 sdf=np.sqrt(np.maximum(dx,0)**2+np.maximum(dy,0)**2)+np.minimum(np.maximum(dx,dy),0)-r
 return 1-sm(-.0008,.0008,sdf)
pig=np.array(Image.open(R/'source/metall-osnova.jpg').convert('L')).astype(float);pig=blur(pig,4);pig=(pig-pig.mean())/max(1,pig.std());pig=np.clip(pig,-2,2)*.006
brushed=.008*np.sin(2*np.pi*(u*71+v*3))+.004*np.sin(2*np.pi*(u*31-v*7))
def color(base):return np.ones((N,N,3))*np.array(base)[None,None,:]*(1+pig[:,:,None])
report={'tile_m':1,'normal_format':'OpenGL +Y','source_main':'c59137cf51cd185a4ee2fcca760c47261f6c386a','materials':{}}
def deliver(name,col,h,ao,rough,metal):
 col=per(np.uint8(np.clip(np.rint(col),0,255)));norm=normal(per(h));orm=per(np.uint8(np.clip(np.rint(np.stack([ao,rough,metal],-1)*255),0,255)))
 for suffix,a in [('tsvet',col),('normali',norm),('orm',orm)]:
  assert np.array_equal(a[0],a[-1]) and np.array_equal(a[:,0],a[:,-1]);Image.fromarray(a,'RGB').save(R/f'{name}-{suffix}.png',optimize=True)
 report['materials'][name]={'height_mm':[float(h.min()*1000),float(h.max()*1000)],'ao':[float(ao.min()),float(ao.max())],'roughness':[float(rough.min()),float(rough.max())],'metallic':[float(metal.min()),float(metal.max())],'edge_equal':True}


# Physical height in metres. Oil changes reflectance, not panel silhouette.
oil=(.5+.5*np.sin(2*np.pi*(u+v)))**8*(.5+.5*np.sin(2*np.pi*(3*u-v)))**4
dust=(.5+.5*np.sin(2*np.pi*(2*u+v)))**5
def finish(name,base,h,feature,wear,oilmask=None):
 col=color(base);col=mix(col,[50,54,48],feature*.30);col=mix(col,[133,130,109],wear*.28)
 rough=.78-.17*wear+brushed*.35;metal=.19+.39*wear
 if oilmask is not None:
  col=mix(col,[36,40,36],oilmask*.36);rough-=.30*oilmask;metal*=1-.6*oilmask
 ao=1-.17*feature
 deliver(name,col,h,ao,np.clip(rough,.36,.9),np.clip(metal,.04,.72))

# Alternating diagonals: 55 mm diamonds, 1.2 mm raised chequers; no tile frame.
qx=(u*12)%1-.5;qy=(v*12)%1-.5
row=np.floor(v*12).astype(int);colidx=np.floor(u*12).astype(int)
sign=np.where((row+colidx)%2==0,1,-1)
along=(qx+sign*qy)/1.414;across=(qx-sign*qy)/1.414
cheq=(1-sm(.24,.29,np.abs(along)))*(1-sm(.035,.075,np.abs(across)))
finish('mash-pol',[65,72,67],.0012*cheq,np.zeros_like(u),cheq,oil)

# Two calm panels, small fasteners, continuous shallow bent pipe loop.
du=np.minimum(u,1-u);dv=np.minimum(v%.5,.5-v%.5)
seam=np.maximum(1-sm(.002,.005,du),1-sm(.002,.005,dv))
heads=np.zeros_like(u)
for a in [.055,.945]:
 for b in [.055,.445,.555,.945]:
  rr=((u-a)**2+(v-b)**2)/.008**2;heads=np.maximum(heads,np.maximum(0,1-rr))
outer=rect(.5,.50,.55,.72,.11);inner=rect(.5,.50,.505,.675,.0875)
pipe=np.clip(outer-inner,0,1);pipe=blur(pipe,1.1)
clamps=np.maximum(rect(.235,.34,.065,.035),rect(.765,.66,.065,.035))
finish('mash-stena',[129,120,99],-.001*seam+.0028*pipe+.0012*heads+.001*clamps,seam,pipe*.6+heads*.3,dust*.20)

# Cargo deck: longitudinal drag scuffs, 50 mm flush anchor recesses, no hole mesh.
seam=1-sm(.0015,.004,np.minimum(u%.5,.5-u%.5))
scuff=np.zeros_like(u)
for a in [.19,.24,.73,.77]:
 scuff=np.maximum(scuff,np.exp(-(((u-a+.5)%1-.5)/.005)**2)*(.5+.5*np.sin(2*np.pi*(2*v+a)))**4)
rr=np.sqrt(((u-.5+.5)%1-.5)**2+((v-.5+.5)%1-.5)**2)
recess=1-sm(.023,.026,rr);ring=np.exp(-((rr-.027)/.0025)**2)
slot=rect(.5,.5,.035,.008,.003)
finish('tryum-pol',[70,77,70],-.0006*seam-.0018*recess+.0006*ring-.0005*slot,np.maximum(seam,recess),np.clip(scuff+ring,0,1),dust*.12)

# Cargo frame rib is only a shallow stamped relief; anchor rings stay decorative.
rib=rect(.15,.5,.075,1.2,.008);foot=rect(.15,.5,.14,.09,.007)
rr=np.sqrt(((u-.73+.5)%1-.5)**2+((v-.50+.5)%1-.5)**2)
ring=np.exp(-((rr-.027)/.005)**2);pad=rect(.73,.5,.11,.11,.01)
seam=1-sm(.002,.004,np.minimum(v%.5,.5-v%.5))
finish('tryum-stena',[137,125,103],.0022*rib+.0008*foot+.0007*pad+.0015*ring-.0008*seam,seam,np.clip(.35*rib+ring,0,1),dust*.12)

# Shared overhead service tray with sparse 12 mm vent slots and paired cable runs.
tray=rect(.35,.5,.25,1.2,.009);hatch=rect(.73,.5,.30,.55,.015)
slots=np.zeros_like(u)
for a in [.32,.38,.44,.50,.56,.62,.68]:slots=np.maximum(slots,rect(.73,a,.23,.012,.004))
cables=np.maximum(rect(.13,.5,.012,1.2,.005),rect(.17,.5,.012,1.2,.005))
finish('otsek-potolok',[112,105,88],.002*tray+.0006*cables-.0013*slots+.0004*hatch,slots,.20*tray,dust*.10)

nt=normal(.001*np.exp(-((x-512)**2+(y-512)**2)/80));assert nt[507,512,1]>128 and nt[517,512,1]<128
report['green_dome_test']=True
report['files']={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in R.glob('*.png')}
for p in R.glob('*.png'):assert p.stat().st_size<2_000_000
(R/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
# Inspect every technical map plus 3x3 colour repeat on one sheet per material.
for name in report['materials']:
 sheet=Image.new('RGB',(1536,1024),'#0B1C24');d=ImageDraw.Draw(sheet)
 d.text((20,12),name+' | 1 x 1 m | repeat 3 x 3',font=ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed.ttf',27),fill='#D5E4E8')
 tile=Image.open(R/f'{name}-tsvet.png').resize((300,300),Image.Resampling.LANCZOS)
 for a in range(3):
  for b in range(3):sheet.paste(tile,(20+a*300,70+b*300))
 for i,suffix in enumerate(['normali','orm']):sheet.paste(Image.open(R/f'{name}-{suffix}.png').resize((480,480)),(1000,42+i*490))
 sheet.save(R/f'proverka-{name}.jpg',quality=88)
print('15 maps generated; periodic borders and OpenGL green orientation passed')
