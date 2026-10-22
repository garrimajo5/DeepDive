from pathlib import Path
from PIL import Image
import numpy as np,json,sys
P=Path(sys.argv[1]);(P/'source').mkdir(parents=True,exist_ok=True);(P/'src').mkdir(exist_ok=True)
src=Path(sys.argv[2]) if len(sys.argv)>2 else P/'source/atlas-source.png'
im=Image.open(src).convert('RGBA').resize((512,512),Image.Resampling.LANCZOS)
im.save(P/'source/atlas-source.png',optimize=True)
a=np.asarray(im).astype(float)/255
luma=a[:,:,0]*.2126+a[:,:,1]*.7152+a[:,:,2]*.0722
alpha=a[:,:,3]*luma**1.65
# Technical packing: all highlight/shading information goes into opacity.
for j in range(4):
 for i in range(4):
  x=i*128;y=j*128
  alpha[y:y+4,x:x+128]=0;alpha[y+124:y+128,x:x+128]=0
  alpha[y:y+128,x:x+4]=0;alpha[y:y+128,x+124:x+128]=0
out=np.zeros((512,512,4),dtype=np.uint8);out[:,:,:3]=[213,228,232];out[:,:,3]=np.uint8(np.rint(alpha*255))
Image.fromarray(out,'RGBA').save(P/'sled-atlas.png',optimize=True)
assert (P/'sled-atlas.png').stat().st_size<=128*1024
meta={'size':[512,512],'mode':'RGBA','bytes':(P/'sled-atlas.png').stat().st_size,'rgb':[213,228,232],'padding_px':4,'grid':[4,4], 'cells':[]}
for k in range(16):
 z=out[k//4*128:(k//4+1)*128,k%4*128:(k%4+1)*128,3]
 assert z.max()>0 and not z[:4].any() and not z[-4:].any() and not z[:,:4].any() and not z[:,-4:].any()
 meta['cells'].append({'id':k,'coverage':float(np.mean(z>16)),'alpha_max':int(z.max())})
(P/'validation.json').write_text(json.dumps(meta,indent=2),encoding='utf8')
print('atlas',meta['bytes'])
