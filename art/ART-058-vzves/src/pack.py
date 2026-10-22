from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageFilter
import numpy as np,json,hashlib
R=Path(__file__).resolve().parents[1]
src=Image.open(R/'source/sprites.png').convert('RGBA')
out=Image.new('RGBA',(512,512),(213,228,232,0));report=[]
names=['Хлопья 1','Хлопья 2','Хлопья 3','Хлопья 4','Хлопья 5','Хлопья 6','Нить 1','Нить 2','Нить 3','Пыль 1','Пыль 2','Пыль 3','Пузырёк 1','Пузырёк 2','Пузырёк 3','Пустой']
for i in range(15):
 xx,yy=i%4,i//4;cell=src.crop((round(xx*src.width/4),round(yy*src.height/4),round((xx+1)*src.width/4),round((yy+1)*src.height/4)))
 a=cell.getchannel('A');bb=a.point(lambda t:255 if t>16 else 0).getbbox();assert bb
 cell=cell.crop(bb);a=cell.getchannel('A')
 # Atlas packing: alpha is the shape, RGB a constant cold neutral. No baked emissive fringe.
 size=100 if i<6 else (108 if i<9 else (70 if i<12 else 100))
 a.thumbnail((size,size),Image.Resampling.LANCZOS)
 alpha=np.array(a).astype(float);alpha[alpha<2]=0
 factor=.62 if i<6 else (.48 if i<9 else (.40 if i<12 else .80))
 a=Image.fromarray(np.uint8(alpha*factor));patch=Image.new('RGBA',a.size,(213,228,232,0));patch.putalpha(a)
 x=xx*128+(128-patch.width)//2;y=yy*128+(128-patch.height)//2;out.paste(patch,(x,y))
 report.append({'index':i,'name':names[i],'bounds':[x,y,x+patch.width,y+patch.height]})
out.save(R/'vzves-atlas.png',optimize=True)
arr=np.array(out);assert arr.shape==(512,512,4)
for i in range(16):
 a=arr[(i//4)*128:(i//4+1)*128,(i%4)*128:(i%4+1)*128,3]
 assert not a[:4].any() and not a[-4:].any() and not a[:,:4].any() and not a[:,-4:].any()
 if i==15:assert not a.any()
assert (R/'vzves-atlas.png').stat().st_size<512_000
(R/'validation.json').write_text(json.dumps({'size':[512,512],'mode':'RGBA8 straight alpha','padding_px_min':4,'empty_cell':15,'rgb':[213,228,232],'bytes':(R/'vzves-atlas.png').stat().st_size,'sha256':hashlib.sha256((R/'vzves-atlas.png').read_bytes()).hexdigest(),'frames':report},ensure_ascii=False,indent=2),encoding='utf8')
print('Atlas packed:',(R/'vzves-atlas.png').stat().st_size,'bytes')
