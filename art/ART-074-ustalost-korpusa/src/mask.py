"""Rebuild the linear RGB packed data map; no external art input."""
from pathlib import Path
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1]
x,y=np.meshgrid(np.arange(512)/511,np.arange(512)/511)
r=np.zeros_like(x);g=np.zeros_like(x)
for i,(cx,cy,rad) in enumerate([(.13,.2,.13),(.43,.67,.19),(.79,.38,.17),(.92,.9,.10)]):
 dx=np.minimum(abs(x-cx),1-abs(x-cx));dy=np.minimum(abs(y-cy),1-abs(y-cy))
 shape=np.exp(-((dx/rad)**2+(dy/(rad*.47))**2)*2)*(.8+.2*np.sin(x*87+y*51));g=np.maximum(g,shape)
for i,cx in enumerate([.13,.43,.79]):
 dx=np.minimum(abs(x-cx-.01*np.sin(y*9+i)),1-abs(x-cx-.01*np.sin(y*9+i)))
 r=np.maximum(r,np.exp(-(dx/.028)**2)*np.maximum(0,1-y/(.5+i*.17))**.6)
r*=np.sin(np.pi*y)**.27
b=.37+.4*(.5+.5*np.sin(x*2*np.pi)*np.cos(y*2*np.pi))
a=np.uint8(np.clip(np.stack([r,g,b],-1)*255,0,255))
a[:,:,0]=np.uint8(np.minimum(255,a[:,:,0].astype(float)*1.8))
a[-1]=a[0];a[:,-1]=a[:,0]
Image.fromarray(a).save(P/'ustalost-maska.png',optimize=True)
