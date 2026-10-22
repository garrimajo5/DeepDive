from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1];N=1024;y,x=np.mgrid[:N,:N];u=x/(N-1);v=y/(N-1)
def sm(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def per(a):
 a=a.copy();a[-1]=a[0];a[:,-1]=a[:,0];return a
rng=np.random.default_rng(56);seeds=rng.uniform(0,16,(13,2));dist=[];dxs=[];dys=[]
wu=u*16+.24*np.sin(2*np.pi*(3*u+2*v))+.08*np.sin(2*np.pi*(11*u-v))
wv=v*16+.28*np.sin(2*np.pi*(u-3*v))+.07*np.sin(2*np.pi*(8*u+5*v))
for px,py in seeds:
 dx=(wu-px+8)%16-8;dy=(wv-py+8)%16-8;dist.append(dx*dx+dy*dy);dxs.append(dx);dys.append(dy)
dist=np.array(dist);idx=np.argmin(dist,axis=0)[None,:,:]
d0=np.take_along_axis(dist,idx,axis=0)[0];dx0=np.take_along_axis(np.array(dxs),idx,axis=0)[0];dy0=np.take_along_axis(np.array(dys),idx,axis=0)[0]
gap=np.full((N,N),100.0)
for dd,dxj,dyj in zip(dist,dxs,dys):
 den=2*np.sqrt((dxj-dx0)**2+(dyj-dy0)**2)
 cand=np.divide(dd-d0,den,out=np.full((N,N),100.0),where=den>.001)
 gap=np.minimum(gap,cand)

macro=np.zeros((N,N));fine=np.zeros((N,N))
for i in range(16):
 kx=int(rng.integers(1,5));ky=int(rng.integers(1,5));phase=rng.uniform(0,6.28)
 macro+=np.sin(2*np.pi*(kx*u+ky*v)+phase)/(kx+ky)
for i in range(18):
 kx=int(rng.integers(6,20));ky=int(rng.integers(6,20));phase=rng.uniform(0,6.28)
 fine+=np.sin(2*np.pi*(kx*u+ky*v)+phase)/(kx+ky)
macro/=max(abs(macro.min()),abs(macro.max()));fine/=max(abs(fine.min()),abs(fine.max()))
# Sparse strong transmission inside a broad, much weaker branching fissure network.
thin=(1-sm(.025,.16,gap))*(.70+.30*sm(-.5,.6,macro))
halo=1-sm(.12,.6,gap)
ridge=np.exp(-((gap-.35)/.2)**2)*(.5+.5*sm(-.5,.5,macro))
trans=np.clip(.035+.91*thin-.025*ridge,0,1)
height=.16*macro+.025*fine+.10*ridge-.085*thin
base=np.array([115,161,180]);c=np.ones((N,N,3))*base
strata=np.sin(2*np.pi*(2*u+v+.13*np.sin(2*np.pi*(3*u-2*v))))
frost=sm(.05,.75,.6*macro+.4*fine)
c+=macro[:,:,None]*np.array([11,13,14])+fine[:,:,None]*np.array([5,6,6])+strata[:,:,None]*np.array([3,4,4])
c=c*(1-.20*frost[:,:,None])+np.array([175,204,214])*frost[:,:,None]*.20
c=c*(1-.10*ridge[:,:,None]);c=c*(1-.18*halo[:,:,None])+np.array([134,188,203])*halo[:,:,None]*.18
c=c*(1-.58*thin[:,:,None])+np.array([154,217,232])*thin[:,:,None]*.58
# Trapped bubble lenses, calm low contrast, never white pinpoints.
for px,py,rad in zip(rng.uniform(0,16,26),rng.uniform(0,16,26),rng.uniform(.035,.15,26)):
 rr=np.sqrt(((u*16-px+8)%16-8)**2+((v*16-py+8)%16-8)**2)/rad
 bubble=np.exp(-((rr-.8)/.22)**2)*.07
 c=c*(1-bubble[:,:,None])+np.array([164,201,213])*bubble[:,:,None]
col=per(np.uint8(np.clip(np.rint(c),0,255)))
freq=np.fft.fftfreq(N);height=np.fft.ifft2(np.fft.fft2(height)*np.exp(-2*np.pi**2*1.2**2*(freq[:,None]**2+freq[None,:]**2))).real
h=height[:-1,:-1];step=16/(N-1);dx=(np.roll(h,-1,1)-np.roll(h,1,1))/(2*step);dy=(np.roll(h,-1,0)-np.roll(h,1,0))/(2*step)
n=np.stack([-dx,dy,np.ones_like(dx)],-1);n/=np.linalg.norm(n,axis=-1,keepdims=True);n=np.pad(n,((0,1),(0,1),(0,0)),mode='wrap');norm=per(np.uint8(np.rint((n*.5+.5)*255)))
mask=per(np.uint8(np.rint(trans*255)))
for name,a in [('led-tsvet.png',col),('led-normali.png',norm),('led-treshchiny.png',mask)]:
 Image.fromarray(a).save(R/name,optimize=True);assert np.array_equal(a[0],a[-1]) and np.array_equal(a[:,0],a[:,-1]);assert (R/name).stat().st_size<2_000_000
report={'tile_m':16,'seed':56,'normal_format':'OpenGL +Y','source_main':'ee525c6b4cedc62cff369a0ed040bf5e67627d74','height_range_m':[float(height.min()),float(height.max())],'transmission_range':[int(mask.min()),int(mask.max())],'bright_area_fraction':float((mask>180).mean()),'edges_equal':True,'files':{p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in R.glob('*.png')}}
(R/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
sheet=Image.new('RGB',(2048,1152),'#0B1C24');d=ImageDraw.Draw(sheet);F='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
def txt(x,y,s,n=25,c='#D5E4E8'):d.text((x,y),s,font=ImageFont.truetype(F,n),fill=c)
txt(35,20,'ЛЁД СНИЗУ · карты одной поверхности',40);txt(37,78,'ART-056 · плитка 16 × 16 м · цвет / нормали / светопропускание',26,'#9AD9E8')
for i,(name,title) in enumerate([('led-tsvet.png','Цвет · повтор 3 × 3'),('led-normali.png','Нормали · OpenGL'),('led-treshchiny.png','Трещины · один канал')]):
 xx=35+i*676;txt(xx,130,title,28)
 tile=Image.open(R/name).convert('RGB').resize((208,208),Image.Resampling.LANCZOS)
 for a in range(3):
  for b in range(3):sheet.paste(tile,(xx+208*a,180+208*b))
txt(36,842,'Свет не равномерный: трещины светлее, толстые наплывы темнее, нет солнечного пятна.',27,'#9AD9E8')
txt(36,902,'Карту трещин и точки шахт брать из одних мировых координат; не светить из центра каждой плитки.',27)
txt(36,963,'На 30 м: приглушить эмиссию и контраст, нормали ослабить; приёмка — на настоящем Forward Mobile.',26,'#9AD9E8')
txt(36,1040,'Шахты ART-052 · 3–5 на видимую область · минимум 12 м между основаниями',26)
txt(36,1090,'Готовых мешей и игрового шейдера в сдаче нет.',24,'#6E909A')
sheet.save(R/'led-list.png',optimize=True)
print(json.dumps(report,indent=2))
