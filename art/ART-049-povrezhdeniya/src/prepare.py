from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageFilter
O=Path(__file__).resolve().parent.parent
im=Image.open(O/'source/wear-source.png').convert('RGBA');a=np.array(im);h,w=a.shape[:2]
# Explicit island identification, thresholds in 8-bit lost-hull units.
features=[
 ('skol',0,(61,60,594,264)),('koltso',48,(659,86,836,267)),('tsarapiny',72,(914,57,1189,312)),
 ('tsarapiny',24,(60,283,364,497)),('vmyatina',104,(375,297,632,479)),('skol',136,(679,317,984,500)),('koltso',168,(1011,297,1182,471)),
 ('koltso',16,(60,530,234,702)),('zaplatka',200,(309,535,483,684)),('skol',184,(537,507,922,705)),('vmyatina',72,(958,510,1191,688)),
 ('vmyatina',144,(104,719,415,928)),('koltso',120,(483,715,662,893)),('tsarapiny',56,(865,691,1151,821)),('skol',216,(711,800,1194,985)),
 ('tsarapiny',152,(63,949,442,1190)),('koltso',232,(470,1003,645,1176)),('zaplatka',255,(704,1003,884,1153)),('vmyatina',208,(918,988,1194,1211))]
y,x=np.mgrid[:h,:w];score=np.full((h,w),1e6);ids=np.zeros((h,w),np.uint8)
for k,(_,t,(x0,y0,x1,y1)) in enumerate(features):
 s=((x-(x0+x1)/2)/((x1-x0)/2+8))**2+((y-(y0+y1)/2)/((y1-y0)/2+8))**2
 # Keep every fragment associated with its parent mark; no random per-pixel thresholds.
 inside=(x>=x0-12)&(x<x1+12)&(y>=y0-12)&(y<y1+12);s=np.where(inside,s,s+100)
 use=s<score;ids[use]=k;score[use]=s[use]
# Neutral metal palette normalization removes saturated alpha-edge artifacts.
rgb=a[:,:,:3].astype(float);lum=rgb@np.array([.2126,.7152,.0722]);stops=np.array([0,50,100,145,200,255]);pal=np.array([[24,29,27],[56,55,48],[99,92,77],[140,128,107],[187,180,158],[220,216,200]])
for c in range(3):a[:,:,c]=np.interp(lum,stops,pal[:,c]).astype(np.uint8)
a[a[:,:,3]==0,:3]=0
color=Image.fromarray(a).resize((1024,1024),Image.Resampling.LANCZOS)
index=np.array(Image.fromarray(ids).resize((1024,1024),Image.Resampling.NEAREST))
threshold=np.array([f[1] for f in features],np.uint8)[index]
rgba=np.array(color);# Threshold padding covers transparent neighbors: alpha, not threshold, masks empty pixels.
# Periodic registration shift: marks cross tile boundaries, avoiding an empty perimeter grid.
rgba=np.roll(rgba,(317,211),(0,1));threshold=np.roll(threshold,(317,211),(0,1));index=np.roll(index,(317,211),(0,1))
# Exact matching edge samples for repeat sampling; the two maps receive the same operation.
for v in [rgba,threshold,index]:v[-1]=v[0];v[:,-1]=v[:,0]
Image.fromarray(rgba).save(O/'povrezhdeniya-tsvet.png',optimize=True)
Image.fromarray(threshold,'L').save(O/'povrezhdeniya-uroven.png',optimize=True)
R=O/'renders';R.mkdir(exist_ok=True)
base=np.array(Image.open(O.parents[1]/'docs/concept-art/obshivka-tsvet.png').convert('RGB')).astype(float)
mask=np.array(Image.open(O.parents[1]/'docs/concept-art/obshivka-maska.png').convert('L'))/255
seam=np.clip((mask-.75)/.2,0,1);seam=seam*seam*(3-2*seam)
# Match the base shader seam/stain darkening; damage preserves the same seam mask.
stain=np.clip((mask-.3)/.2,0,1);stain=stain*stain*(3-2*stain)*(1-seam)
base=base*(1-.3*seam[:,:,None])*(1-.05*stain[:,:,None])
report={'tile_m':2,'shift_px':[317,211],'features':[{'id':i,'kind':f[0],'threshold':f[1],'source_bounds':f[2]} for i,f in enumerate(features)],'states':{}}
for hull in [100,70,40,15,0]:
 loss=255*(1-hull/100);vis=(threshold<=loss)&(hull<100);alpha=rgba[:,:,3]/255*vis*(1-.55*seam)
 result=np.clip(base*(1-alpha[:,:,None])+rgba[:,:,:3]*alpha[:,:,None],0,255).astype('uint8')
 Image.fromarray(result).save(R/f'plate-{hull}.png',optimize=True)
 report['states'][str(hull)]={'visible_marks':sum(f[1]<=loss for f in features) if hull<100 else 0,'alpha_coverage':float((alpha>.1).mean())}
assert np.array_equal(rgba[0],rgba[-1]) and np.array_equal(rgba[:,0],rgba[:,-1])
assert np.array_equal(threshold[0],threshold[-1]) and np.array_equal(threshold[:,0],threshold[:,-1])
assert Image.open(O/'povrezhdeniya-uroven.png').mode=='L'
for f in O.glob('*.png'):assert f.stat().st_size<2*1024**2
report['edges_exact_match']=True;report['alpha_zero_fraction']=float((rgba[:,:,3]==0).mean());report['dimensions']=[1024,1024]
(O/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report['states']))
