from pathlib import Path
import numpy as np
from PIL import Image
p=Path(__file__).resolve().parents[1]
y,x=np.mgrid[0:512,0:512]/512
pts=np.random.default_rng(479).random((24,2));ds=[]
for a,b in pts:
 dx=(x-a+.5)%1-.5;dy=(y-b+.5)%1-.5;ds.append(dx*dx+dy*dy)
d=np.sort(np.stack(ds),axis=0);edge=np.sqrt(d[1])-np.sqrt(d[0])
a=np.rint(np.exp(-(edge/.009)**2)*255).astype('uint8')
Image.fromarray(a,'L').save(p/'bliki-maska.png',optimize=True)
