from pathlib import Path
import numpy as np,random,json
from PIL import Image,ImageDraw,ImageFilter
R=Path(__file__).resolve().parents[1];W,H=1024,512
y,x=np.mgrid[:H,:W];u=x/(W-1);v=y/(H-1);edge=np.minimum.reduce([u,1-u,v,1-v]);rng=random.Random(413)
frost=np.exp(-edge/.038)*(.66+.14*np.sin(u*17+v*5)+.10*np.cos(v*21-u*7))
g=Image.new('L',(W,H));d=ImageDraw.Draw(g)
for i in range(130):
 xx=rng.randrange(8,W-8);yy=rng.randrange(8,H-8)
 if min(xx/W,1-xx/W,yy/H,1-yy/H)>.16:continue
 rr=rng.uniform(1.4,4.2);d.ellipse((xx-rr,yy-rr*1.15,xx+rr,yy+rr*1.15),outline=rng.randint(25,105),width=1)
 if i%4==0:d.line([(xx,yy+rr),(xx+rng.uniform(-1,1),yy+rr+rng.uniform(5,19))],fill=18,width=1)
g=np.array(g.filter(ImageFilter.GaussianBlur(.5)))/255
b=Image.new('L',(W,H));d=ImageDraw.Draw(b)
for i in range(32):
 xx=rng.randrange(W);yy=rng.randrange(H)
 if min(xx/W,1-xx/W,yy/H,1-yy/H)>.15:continue
 d.line([(xx,yy),(xx+rng.uniform(-30,30),yy+rng.uniform(-8,8))],fill=rng.randint(22,75),width=1)
b=np.array(b.filter(ImageFilter.GaussianBlur(.35)))/255
src=R/'source/kondensat.jpg'
if src.exists():
 pigment=np.array(Image.open(src).convert('L').resize((W,H)).filter(ImageFilter.GaussianBlur(1)))/255
 g=np.maximum(g,pigment*.2*np.exp(-edge/.065))
a=np.clip(.85*frost+.55*g+.45*b,0,.9)
mask=np.uint8(np.clip(np.stack([frost,g,b,a],-1)*255,0,255));Image.fromarray(mask).save(R/'steklo-maska.png',optimize=True)
# 0.8 mm long wave; slopes use physical width 2.5 m and height 1.9 m.
height=.0008*(np.sin(2*np.pi*(u*2+.23))*np.sin(2*np.pi*(v*1.5+.17)))-.00012*b
dy,dx=np.gradient(height,1.9/(H-1),2.5/(W-1));n=np.stack([-dx,dy,np.ones_like(dx)],-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
normal=np.uint8(np.rint((n*.5+.5)*255));Image.fromarray(normal).save(R/'steklo-normali.png',optimize=True)
assert a[(u>.22)&(u<.78)&(v>.22)&(v<.78)].max()<.01
report={'size':[W,H],'channels':'R frost G dried drops B scratches A combined strength','center_strength_max':float(a[(u>.22)&(u<.78)&(v>.22)&(v<.78)].max()),'normal':'OpenGL +Y','normal_wave_height_mm':.8,'bytes':{p.name:p.stat().st_size for p in R.glob('*.png')}}
assert all(v<1_000_000 for v in report['bytes'].values());(R/'validation.json').write_text(json.dumps(report,indent=2))
sheet=Image.new('RGB',(1024,768),'#0B1C24')
for i in range(4):sheet.paste(Image.fromarray(mask[:,:,i]).resize((512,256)),((i%2)*512,(i//2)*256))
sheet.paste(Image.fromarray(normal).resize((1024,256)),(0,512));sheet.save(R/'source/channels.png')
print(report)
