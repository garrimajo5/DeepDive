from pathlib import Path
import numpy as np
from PIL import Image
p=Path(__file__).resolve().parents[1]
q=np.linspace(0,1,512);u,v=np.meshgrid(q,q);dx=np.zeros_like(u);dy=np.zeros_like(u)
for kx,ky,amp,phase in [(1,2,.006,.2),(3,-2,.003,1.1),(5,3,.0018,.7),(-4,7,.0012,2.2),(8,1,.0008,.4),(2,10,.0007,1.8),(11,-6,.0004,.8)]:
 w=2*np.pi*(kx*u+ky*v)+phase;dx+=amp*2*np.pi*kx*np.cos(w);dy+=amp*2*np.pi*ky*np.cos(w)
n=np.stack([-dx,-dy,np.ones_like(u)],axis=-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
a=np.rint((n*.5+.5)*255).astype('uint8');a[-1]=a[0];a[:,-1]=a[:,0]
Image.fromarray(a,'RGB').save(p/'shlyuz-voda-normal.png',optimize=True)
atlas=Image.new('RGBA',(512,512));q=np.linspace(-.5,.5,104);x,y=np.meshgrid(q,q);r=np.sqrt(x*x+y*y);ang=np.arctan2(y,x)
for i in range(16):
 if i<8:
  t=i/7;rad=.035+.40*t
  h=np.exp(-((r-rad)/.014)**2)*(1-t*.7)+.35*np.exp(-((r-rad*.65)/.012)**2)*(1-t)
 elif i<12:
  t=(i-8)/3;rad=.09+.21*t;rr=rad*(1+.12*np.sin(7*ang)+.05*np.cos(11*ang))
  h=np.exp(-((r-rr)/(.018+.012*t))**2)*(1-.8*t)
 else:
  t=(i-12)/3;h=np.zeros_like(r)
  for j in range(7):
   ar=j*2.39996;cx=np.sin(ar)*(.08+.11*t);cy=np.cos(ar)*(.08+.11*t);rr=np.sqrt((x-cx)**2+(y-cy)**2)
   rad=.012+.020*t;h+=np.exp(-((rr-rad)/.006)**2)*(1-.85*t)
 mask=np.clip(h,0,1)*(1-np.clip((r-.46)/.03,0,1))
 out=np.zeros((104,104,4),dtype='uint8');out[:,:,0]=np.rint(np.clip(h,0,1)*255);out[:,:,3]=np.rint(mask*255)
 atlas.paste(Image.fromarray(out,'RGBA'),((i%4)*128+12,(i//4)*128+12))
atlas.save(p/'shlyuz-voda-kolca.png',optimize=True)
print('maps bytes',sum((p/n).stat().st_size for n in ['shlyuz-voda-normal.png','shlyuz-voda-kolca.png']))
