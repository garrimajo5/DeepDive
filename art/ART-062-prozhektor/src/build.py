from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageFilter
import numpy as np,json,sys
P=Path(sys.argv[1]); (P/'src').mkdir(parents=True,exist_ok=True);(P/'source').mkdir(exist_ok=True)
source=Path(sys.argv[2]) if len(sys.argv)>2 else P/'source/reflector.png'
im=Image.open(source).convert('L').resize((512,512),Image.Resampling.LANCZOS)
im.save(P/'source/reflector.png',optimize=True)
y,x=np.mgrid[:512,:512];r=np.hypot((x-255.5)/255.5,(y-255.5)/255.5)
v=np.asarray(im,dtype=float)/255
# Exact black frame; original generated optical structure retained inside.
edge=np.clip((.94-r)/.12,0,1);edge=edge*edge*(3-2*edge)
v=np.clip(v*edge,0,1)
Image.fromarray(np.uint8(np.rint(v*255)),'L').save(P/'prozhektor-maska.png',optimize=True)
# Periodic scalar turbulence, U around cone, V along the cone. No baked light colour.
y,x=np.mgrid[:512,:256];u=x/255;w=y/511
rng=np.random.default_rng(620436)
f=np.zeros_like(u)
for k in range(32):
 nu=int(rng.integers(1,14)); nv=int(rng.integers(1,6)); phase=rng.uniform(0,6.28318)
 f+=np.sin(2*np.pi*(nu*u+nv*w)+phase+.7*np.sin(2*np.pi*(u+w)))/(nu**.65*nv**.65)
f=.5+.125*f/(f.std()+1e-6)
f=np.clip(f,.10,.92)
f[:,-1]=f[:,0];f[-1]=f[0]
Image.fromarray(np.uint8(np.rint(f*255)),'L').save(P/'prozhektor-luch.png',optimize=True)
meta={}
for name,size in [('prozhektor-maska.png',(512,512)),('prozhektor-luch.png',(256,512))]:
 a=Image.open(P/name); z=np.array(a); assert a.mode=='L' and a.size==size and (P/name).stat().st_size<=256*1024
 meta[name]={'mode':a.mode,'size':a.size,'bytes':(P/name).stat().st_size,'min':int(z.min()),'max':int(z.max()),'mean':float(z.mean())}
assert np.max(np.array(Image.open(P/'prozhektor-maska.png'))[[0,-1],:])==0
(P/'validation.json').write_text(json.dumps(meta,indent=2),encoding='utf8')
print(json.dumps(meta))
