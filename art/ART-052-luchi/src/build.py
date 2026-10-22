"""ART-052: numerical grayscale material maps and illustrative light comparisons."""
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
R=Path(__file__).resolve().parents[1];R.mkdir(parents=True,exist_ok=True)
def smooth(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
u=np.linspace(-1,1,512)[None,:];v=np.linspace(0,1,1024)[:,None]
profile=np.maximum(0,1-u*u)**2.5
mask=profile*smooth(0,.035,v)*(1-smooth(.12,1,v))**1.6
mask/=mask.max(); mask8=np.rint(mask*255).astype('uint8')
Image.fromarray(mask8,'L').save(R/'luchi-maska.png',optimize=True)
y,x=np.meshgrid(np.linspace(0,1,256),np.linspace(0,1,256),indexing='ij')
rng=np.random.default_rng(52);n=np.zeros_like(x)
for i in range(26):
 kx=int(rng.integers(1,15));ky=int(rng.integers(1,4));phase=rng.uniform(0,2*np.pi)
 n+=np.sin(2*np.pi*(kx*x+ky*y)+phase)/(1+.3*kx)
n/=np.max(np.abs(n));noise=np.rint(128+64*n).astype('uint8')
# Periodic inclusive grid: both edge samples are equal, including after quantization.
noise[:,-1]=noise[:,0];noise[-1,:]=noise[0,:]
Image.fromarray(noise,'L').save(R/'luchi-shum.png',optimize=True)
def font(n,b=False):return ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed'+('-Bold' if b else '')+'.ttf',n)
def txt(d,x,y,s,n=27,c='#D5E4E8',b=False):d.text((x,y),s,font=font(n,b),fill=c)
def panel(depth=5,edge=False,lamp=False):
 w,h=944,406;yy,xx=np.mgrid[0:h,0:w];t=yy/(h-1)
 base=np.zeros((h,w,3),float)
 shallow=np.array([.025,.12,.155]);deep=np.array([.008,.034,.05])
 for c in range(3):base[:,:,c]=shallow[c]*(1-t)+deep[c]*t
 base*=np.exp(-depth/100)
 rgb=np.array([.323,.694,.807]) # approximate linear #9AD9E8
 peak=.14*np.exp(-depth/9)
 for i,(cx,top,spread,length,g) in enumerate([(120,16,90,340,1),(345,8,62,300,.7),(574,15,135,370,.85),(810,4,56,275,.5)]):
  vv=np.clip((yy-top)/length,0,1);width=15+spread*vv
  uu=(xx-cx-18*vv)/width
  a=np.maximum(0,1-uu*uu)**2.5*smooth(0,.035,vv)*(1-smooth(.12,1,vv))**1.6
  a[(yy<top)|(yy>top+length)]=0
  nv=noise[((vv*255*1.7).astype(int))%256,((uu*.5+.5)*255).astype(int)%256]/255
  a*=.7+.6*nv
  base+=a[:,:,None]*rgb*peak*g*(.35 if edge else 1)
 if lamp:
  along=np.clip(xx/w,0,1);width=8+along*65
  cone=np.maximum(0,1-((yy-295)/width)**2)**2*(1-along)**1.8
  base+=cone[:,:,None]*np.array([.7,.85,.92])*.06
 # Illustrative opaque terrain occludes the additive layers.
 floor=342+14*np.sin(xx[0]/100)
 if edge:floor=280+120*smooth(400,750,xx[0])
 terrain=yy>=floor[None,:];base[terrain]=np.array([.008,.028,.038])
 arr=np.clip(base,0,1)**(1/2.2)
 im=Image.fromarray(np.uint8(arr*255));d=ImageDraw.Draw(im)
 d.line((0,9,w,9),fill='#86BCCB',width=3)
 for cx in [120,345,574,810]:d.line((cx-16,6,cx+8,12,cx+20,7),fill='#9AD9E8',width=2)
 # Snow is only a readability reference, not a new delivered particle texture.
 rand=np.random.default_rng(7)
 for px,py in zip(rand.integers(10,w-10,60),rand.integers(35,330,60)):
  d.point((int(px),int(py)),fill='#688A9B')
 return im
sheet=Image.new('RGB',(2048,1152),'#0B1C24');d=ImageDraw.Draw(sheet)
txt(d,40,18,'ЛУЧИ ПОДО ЛЬДОМ · профиль и затухание',40,b=True)
txt(d,42,76,'ART-052 · расчётные иллюстрации эффекта, не снимки внедрённого шейдера',25,'#9AD9E8')
cases=[(5,False,False,'Мелководье · наблюдатель 5 м'),(30,False,False,'Наблюдатель 30 м · едва заметно'),(15,True,False,'Край отмели · без световой стены'),(5,False,True,'Прожектор рядом · без белой засветки')]
for i,(depth,edge,lamp,title) in enumerate(cases):
 px=40+(i%2)*1024;py=132+(i//2)*493
 txt(d,px,py,title,29,b=True);sheet.paste(panel(depth,edge,lamp),(px,py+48))
txt(d,42,1110,'4 шахты · мягкий профиль · нити без резкой полосы · непрозрачное дно перекрывает свет',25,'#9AD9E8')
sheet.save(R/'luchi-list.png',optimize=True)
assert np.array_equal(noise[:,0],noise[:,-1]) and np.array_equal(noise[0],noise[-1])
assert np.all(mask8[:,0]==0) and np.all(mask8[:,-1]==0) and np.all(mask8[0]==0) and np.all(mask8[-1]==0)
out={'mask':{'mode':'L8','size':[512,1024],'edge_max':0,'range':[int(mask8.min()),int(mask8.max())]},'noise':{'mode':'L8','size':[256,256],'range':[int(noise.min()),int(noise.max())],'mean':float(noise.mean()),'edge_difference':0,'seed':52},'depth_peak_linear':{str(z):float(.14*np.exp(-z/9)) for z in [0,5,15,30,50]}}
for p in R.glob('*.png'):
 assert p.stat().st_size<=2_000_000
out['files']={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in R.glob('*.png')}
(R/'validation.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print(json.dumps(out,indent=2))
