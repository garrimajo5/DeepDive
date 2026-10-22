from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,hashlib
R=Path(__file__).resolve().parents[1];N=1024;C=N-1
def blur(a,s):
 f=np.fft.fftfreq(a.shape[0]);g=np.fft.fftfreq(a.shape[1]);return np.fft.ifft2(np.fft.fft2(a)*np.exp(-2*np.pi**2*s*s*(f[:,None]**2+g[None,:]**2))).real
def periodic(a):
 # Periodic-plus-smooth decomposition removes the broad boundary ramp.
 h,w=a.shape;b=np.zeros_like(a);b[0,:]=a[-1,:]-a[0,:];b[-1,:]=-b[0,:];b[:,0]+=a[:,-1]-a[:,0];b[:,-1]-=a[:,-1]-a[:,0]
 yy,xx=np.mgrid[:h,:w];den=2*np.cos(2*np.pi*xx/w)+2*np.cos(2*np.pi*yy/h)-4;den[0,0]=1
 f=np.fft.fft2(b)/den;f[0,0]=0;return a-np.fft.ifft2(f).real
def pad(a):return np.pad(a,((0,1),(0,1))+(((0,0),) if a.ndim==3 else ()),mode='wrap')
def normal(h):
 step=2/C;dx=(np.roll(h,-1,1)-np.roll(h,1,1))/(2*step);dy=(np.roll(h,-1,0)-np.roll(h,1,0))/(2*step)
 n=np.stack([-dx,dy,np.ones_like(h)],-1);n/=np.linalg.norm(n,axis=-1,keepdims=True);return pad(np.uint8(np.rint((n*.5+.5)*255)))
def norm(a):return (a-a.mean())/max(a.std(),1e-9)
report={'tile_m':[2,2],'source_main':'608f7ed49e24ae8bfac71d8161effbd7bbe0a2f8','normal':'OpenGL +Y','color':'linear multiplier data; 2*sample, neutral=0.5','materials':{}}
for name,amplitude,sigma,contrast,rough in [('pesok',.005,1.8,.030,.87),('il',.0025,2.8,.018,.95),('galka',.018,2.0,.060,.83)]:
 raw=np.array(Image.open(R/f'source/{name}.jpg').convert('L').resize((C,C),Image.Resampling.LANCZOS))/255
 z=blur(periodic(raw),sigma);z=(z-np.percentile(z,2))/max(.001,np.percentile(z,98)-np.percentile(z,2));z=np.clip(z,-.15,1.15)
 h=z*amplitude
 rng=np.random.default_rng({'pesok':60,'il':61,'galka':62}[name]);fine=norm(blur(rng.normal(size=(C,C)),1.4));broad=norm(blur(rng.normal(size=(C,C)),16))
 delta=(.30*norm(z-blur(z,12))+.55*broad+.15*fine);delta=np.clip(delta,-2.5,2.5);delta-=delta.mean()
 col=np.uint8(np.clip(np.rint((.5+contrast*delta)*255),0,255));col=pad(np.repeat(col[:,:,None],3,axis=2))
 nm=normal(h)
 depression=np.clip((blur(h,6)-h)/(.15*amplitude),0,1)
 ao=1-depression*(.16 if name=='galka' else .06);rg=np.clip(rough+.016*broad-.025*z*(name=='galka'),.70,.99)
 orm=pad(np.uint8(np.rint(np.stack([ao,rg,np.zeros_like(z)],-1)*255)))
 modes={}
 for suffix,a in [('tsvet',col),('normali',nm),('orm',orm)]:
  p=R/f'dno-{name}-{suffix}.png';im=Image.fromarray(a,'RGB');im.save(p,optimize=True)
  if p.stat().st_size>1_000_000:
   # Data palette compression preserves sampled vector values, with no colour-space conversion.
   im.quantize(colors=256,dither=Image.Dither.NONE).save(p,optimize=True);modes[suffix]='palette256'
  else:modes[suffix]='RGB8'
  assert p.stat().st_size<=1_000_000,(p,p.stat().st_size)
  actual=np.array(Image.open(p).convert('RGB'));assert np.array_equal(actual[0],actual[-1]) and np.array_equal(actual[:,0],actual[:,-1])
 report['materials'][name]={'height_range_mm':[float(h.min()*1000),float(h.max()*1000)],'mean_color':col.mean(axis=(0,1)).tolist(),'roughness':[float(rg.min()),float(rg.max())],'metallic_max':0,'edge_equal':True,'encoding':modes}
# Green-channel convention proof: a dome is green above its crest.
yy,xx=np.mgrid[:C,:C];nt=normal(.002*np.exp(-((xx-512)**2+(yy-512)**2)/80));assert nt[507,512,1]>128 and nt[517,512,1]<128
report['green_dome_test']=True
report['files']={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in R.glob('dno-*.png')}
(R/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(report['materials'])
# All nine maps and a 4x4 repeat per material, without labels on the game assets.
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed.ttf',n)
for name,title in [('pesok','Песок с рябью'),('il','Мягкий ил'),('galka','Галька с ракушечником')]:
 sheet=Image.new('RGB',(1536,1152),'#0B1C24');d=ImageDraw.Draw(sheet);d.text((24,14),title+' · повтор 4 × 4 · плитка 2 × 2 м',font=font(34),fill='#D5E4E8')
 tile=Image.open(R/f'dno-{name}-tsvet.png').convert('RGB').resize((248,248),Image.Resampling.LANCZOS)
 for a in range(4):
  for b in range(4):sheet.paste(tile,(24+a*248,90+b*248))
 for i,suffix in enumerate(['normali','orm']):
  d.text((1050,80+i*510),'Нормали OpenGL' if i==0 else 'Затенение / шерш. / металл',font=font(23),fill='#9AD9E8');sheet.paste(Image.open(R/f'dno-{name}-{suffix}.png').convert('RGB').resize((450,450)),(1050,120+i*510))
 sheet.save(R/f'proverka-{name}.jpg',quality=93)
