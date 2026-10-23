from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
import random,json
P=Path('art/ART-077-kondensat-okon'); N=256; S=4; W=N*S
rng=random.Random(531)
y,x=np.mgrid[0:W,0:W]/(W-1)
e=np.minimum.reduce([x,1-x,y,1-y])
protect=(x>.22)&(x<.78)&(y>.22)&(y<.78)
R=np.zeros((W,W),np.float32)
# Rounded caps with varying height, separated and restricted to a peripheral band.
for i in range(380):
 for attempt in range(100):
  u,v=rng.uniform(.012,.988),rng.uniform(.012,.988)
  if min(u,1-u,v,1-v)<.18: break
 rx=rng.uniform(.0028,.0065); ry=rx*rng.uniform(.7,1.6)
 q=((x-u)/rx)**2+((y-v)/ry)**2
 cap=np.maximum(0,1-q)**1.1*rng.uniform(.4,1)
 R=np.maximum(R,cap)
# Rare continuous downward trails, never traversing the centre sight rectangle.
g=Image.new('L',(W,W)); d=ImageDraw.Draw(g)
for i in range(13):
 u=rng.choice([rng.uniform(.025,.145),rng.uniform(.855,.975)])
 v=rng.uniform(.02,.65); length=rng.uniform(.10,.27)
 pts=[(int((u+.0015*np.sin(k*.7+i))*W),int((v+length*k/24)*W)) for k in range(25)]
 d.line(pts,fill=rng.randint(90,195),width=rng.randint(1,2)*S)
 d.ellipse((pts[-1][0]-1.3*S,pts[-1][1]-2*S,pts[-1][0]+1.3*S,pts[-1][1]+2*S),fill=220)
g=g.filter(ImageFilter.GaussianBlur(.65*S)); G=np.asarray(g)/255.
# Dendrites attached to all four frame corners: stems and paired needles, no random white grain.
f=Image.new('L',(W,W)); fd=ImageDraw.Draw(f)
for cx,cy in [(0,0),(1,0),(0,1),(1,1)]:
 sx=1 if cx==0 else -1; sy=1 if cy==0 else -1
 def pt(a,b):return ((cx+sx*a)*W,(cy+sy*b)*W)
 for j in range(14):
  angle=rng.uniform(.12,1.43); length=rng.uniform(.04,.21)
  origin=rng.uniform(.0,.045)
  start=pt(origin*.5,origin*.5); end=pt(origin*.5+np.cos(angle)*length,origin*.5+np.sin(angle)*length)
  fd.line([start,end],fill=rng.randint(110,200),width=int(1.2*S))
  for t in np.arange(.22,.94,.13):
   a=origin*.5+np.cos(angle)*length*t; b=origin*.5+np.sin(angle)*length*t
   ll=length*.18*(1-t*.65)
   for sign in [-1,1]:
    aa=angle+sign*.67
    fd.line([pt(a,b),pt(a+np.cos(aa)*ll,b+np.sin(aa)*ll)],fill=rng.randint(110,210),width=int(.75*S))
f=f.filter(ImageFilter.GaussianBlur(.38*S)); B=np.asarray(f)/255.
# A rises with distance from frame. Clean central 56 percent on both axes is hard-protected.
t=np.clip(e/.22,0,1); A=.10+.78*t*t*(3-2*t)
edgefade=np.clip((.22-e)/.025,0,1)
R*=edgefade;G*=edgefade;B*=edgefade
for c in [R,G,B]:c[protect]=0
A[protect]=1
arr=np.stack([R,G,B,A],-1)
im=Image.fromarray(np.uint8(np.clip(arr,0,1)*255),'RGBA').resize((N,N),Image.Resampling.LANCZOS)
a=np.array(im); yy,xx=np.mgrid[0:N,0:N]/(N-1); clean=(xx>=.22)&(xx<=.78)&(yy>=.22)&(yy<=.78);a[clean,:3]=0;a[clean,3]=255
Image.fromarray(a).save(P/'kondensat-maska.png',optimize=True)
print('mask bytes', (P/'kondensat-maska.png').stat().st_size, 'raw',a.nbytes,'clean max',a[clean,:3].max())
