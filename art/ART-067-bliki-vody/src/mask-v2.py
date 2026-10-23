from pathlib import Path
import numpy as np
from PIL import Image
p=Path(__file__).resolve().parents[1]
y,x=np.mgrid[0:512,0:512]/512;T=2*np.pi
wx=x+.035*np.sin(T*y*2)+.017*np.sin(T*(x+y)*3)
wy=y+.028*np.sin(T*x*2)+.013*np.sin(T*(x-y)*3)
rng=np.random.default_rng(479);pts=[]
for _ in range(10000):
 a=rng.random(2)
 if all(np.linalg.norm((a-b+.5)%1-.5)>.13 for b in pts):pts.append(a)
 if len(pts)==24:break
D=[];VX=[];VY=[]
for a,b in pts:
 dx=(wx-a+.5)%1-.5;dy=(wy-b+.5)%1-.5
 VX.append(dx);VY.append(dy);D.append(dx*dx+dy*dy)
D=np.stack(D);VX=np.stack(VX);VY=np.stack(VY)
order=np.argsort(D,axis=0);i=order[0:1];j=order[1:2]
g=lambda a,k:np.take_along_axis(a,k,axis=0)[0]
d1=g(D,i);d2=g(D,j)
sep=np.sqrt((g(VX,i)-g(VX,j))**2+(g(VY,i)-g(VY,j))**2)
bisector=(d2-d1)/(2*sep)
d3=g(D,order[2:3]);junction=np.exp(-((d3-d1)/.004)**2)
variation=.5+.5*np.sin(T*(wx*2+wy)+.9*np.sin(T*wy*3))
width=.0019+.0022*variation+.002*junction
brightness=(.22+.55*variation+.23*junction)
mask=np.exp(-(bisector/width)**2)*brightness
Image.fromarray(np.rint(mask.clip(0,1)*255).astype('uint8'),'L').save(p/'bliki-maska-v2.png',optimize=True)
