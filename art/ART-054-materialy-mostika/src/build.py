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
report={'tile_m':1,'normal_format':'OpenGL +Y','source_main':'0b1ec3e5840401fdb3fe02a88525ade0d24525a5','materials':{}}
def deliver(name,col,h,ao,rough,metal):
 col=per(np.uint8(np.clip(np.rint(col),0,255)));norm=normal(per(h));orm=per(np.uint8(np.clip(np.rint(np.stack([ao,rough,metal],-1)*255),0,255)))
 for suffix,a in [('tsvet',col),('normali',norm),('orm',orm)]:
  assert np.array_equal(a[0],a[-1]) and np.array_equal(a[:,0],a[:,-1]);Image.fromarray(a,'RGB').save(R/f'{name}-{suffix}.png',optimize=True)
 report['materials'][name]={'height_mm':[float(h.min()*1000),float(h.max()*1000)],'ao':[float(ao.min()),float(ao.max())],'roughness':[float(rough.min()),float(rough.max())],'metallic':[float(metal.min()),float(metal.max())],'edge_equal':True}

# Floor: staggered recessed slots in a closed backing tray, not alpha-cut holes.
row=np.floor(v*16).astype(int);cx=((u*10+(row%2)*.5)%1-.5)*.1;cy=(v*16%1-.5)/16
dx=np.abs(cx)-(.032-.003);dy=np.abs(cy)-(.008-.003)
sdf=np.sqrt(np.maximum(dx,0)**2+np.maximum(dy,0)**2)+np.minimum(np.maximum(dx,dy),0)-.003
slot=1-sm(-.0018,.0007,sdf);edge=np.exp(-(sdf/.0014)**2)
h=-.0035*slot+.00028*edge
col=color([52,72,76]);col=mix(col,[28,39,40],slot*.83);col=mix(col,[105,112,103],edge*.22)
ao=1-.32*slot;rough=np.clip(.72-.2*edge+brushed,.42,.86);metal=.35+.30*edge+.08*(1-slot)
deliver('pol',col,h,ao,rough,metal)

# Walls: one-metre module with two calm panels, countersunk seams and small domed fasteners.
du=np.minimum(u,1-u);dv=np.minimum(v%.5,.5-v%.5)
seam=np.maximum(1-sm(.002,.005,du),1-sm(.002,.005,dv));h=-.0009*seam
heads=np.zeros((N,N));rim=np.zeros((N,N))
for cx0 in [.055,.945]:
 for cy0 in [.055,.445,.555,.945]:
  rr=(((u-cx0+.5)%1-.5)**2+((v-cy0+.5)%1-.5)**2)/.008**2
  heads=np.maximum(heads,np.maximum(0,1-rr)**1.25)
  rim=np.maximum(rim,np.exp(-((np.sqrt(rr)-1)/.15)**2))
h+=.0012*heads
col=color([140,128,107]);col=mix(col,[81,77,67],seam*.70);col=mix(col,[157,148,127],heads*.35);col=mix(col,[81,77,67],rim*.35)
# Two small faded non-text stencils: a pair of registration brackets and an empty diamond.
stencil=np.maximum(rect(.76,.22,.045,.004),rect(.76,.244,.045,.004))
stencil=np.maximum(stencil,np.maximum(rect(.739,.232,.003,.025),rect(.781,.232,.003,.025)))
diamond=np.abs(np.abs((u-.22+.5)%1-.5)+np.abs((v-.74+.5)%1-.5)-.022)
stencil=np.maximum(stencil,1-sm(.0007,.002,diamond));col=mix(col,[190,187,161],stencil*.30)
ao=1-.13*seam-.08*rim;rough=np.clip(.81-.19*seam-.18*heads+.04*stencil+brushed*.35,.43,.89);metal=np.clip(.08+.43*heads+.22*seam-.06*stencil,0,1)
deliver('stena',col,h,ao,rough,metal)

# Ceiling: shallow painted service trunk, offset cable strips and a recessed vent panel.
seam=np.maximum(1-sm(.002,.005,du),1-sm(.002,.005,np.minimum(v,1-v)))
trunk=rect(.35,.5,.23,1.15,.009);cover=rect(.35,.5,.20,1.2,.008)
cable=np.zeros((N,N))
for cx0 in [.15,.17,.19]:
 rr=np.abs((u-cx0+.5)%1-.5)/.006;cable+=np.maximum(0,1-rr*rr)**.7*.00065
vent=rect(.745,.5,.25,.60,.01);slots=np.zeros((N,N))
for cy0 in [.265,.315,.365,.415,.465,.515,.565,.615,.665,.715]:slots=np.maximum(slots,rect(.745,cy0,.205,.017,.004))
h=-.0008*seam+.0018*trunk+.0006*cover+cable-.0012*slots
col=color([110,104,89]);col=mix(col,[81,77,67],seam*.6);col=mix(col,[125,117,98],cover*.5);col=mix(col,[75,77,68],vent*.4);col=mix(col,[47,56,55],slots*.8)
ao=1-.12*seam-.22*slots-.05*(trunk-cover);rough=np.clip(.79-.12*trunk+.04*slots+brushed*.4,.55,.87);metal=np.clip(.12+.22*trunk+.16*(cable/.00195),.1,.55)
deliver('potolok',col,h,ao,rough,metal)

# Data proof for green-channel orientation.
nt=normal(.001*np.exp(-((x-512)**2+(y-512)**2)/80));assert nt[507,512,1]>128 and nt[517,512,1]<128
report['green_dome_test']=True
report['files']={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in R.glob('*.png')}
for p in R.glob('*.png'):assert p.stat().st_size<2_000_000
(R/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report['materials'],indent=2))

F='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
sheet=Image.new('RGB',(2048,1152),'#0B1C24');d=ImageDraw.Draw(sheet)
def txt(x,y,s,n=25,c='#D5E4E8'):d.text((x,y),s,font=ImageFont.truetype(F,n),fill=c)
txt(32,20,'МАТЕРИАЛЫ МОСТИКА · повтор 3 × 3',40);txt(34,78,'ART-054 · одна плитка 1 × 1 м · структурный рисунок, без рамки по краю файла',25,'#9AD9E8')
for i,(name,title) in enumerate([('pol','Пол · углублённая решётка'),('stena','Стены · спокойные панели'),('potolok','Потолок · короба и вентиляция')]):
 x0=32+i*676;txt(x0,125,title,27)
 tile=Image.open(R/f'{name}-tsvet.png').resize((208,208),Image.Resampling.LANCZOS)
 for a in range(3):
  for b in range(3):sheet.paste(tile,(x0+208*a,175+208*b))
 txt(x0,822,'Нормали OpenGL',23,'#9AD9E8');txt(x0+315,822,'ORM: R / G / B',23,'#9AD9E8')
 sheet.paste(Image.open(R/f'{name}-normali.png').resize((228,228),Image.Resampling.LANCZOS),(x0,861))
 sheet.paste(Image.open(R/f'{name}-orm.png').resize((228,228),Image.Resampling.LANCZOS),(x0+315,861))
txt(34,1115,'R — затенение · G — шероховатость · B — металличность · у материалов нет собственной эмиссии',23,'#9AD9E8')
sheet.save(R/'materialy-povtor.png',optimize=True)
