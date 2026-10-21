from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import json
O=Path(__file__).resolve().parents[1]
FONT=Path('C:/Windows/Fonts/DejaVuSansCondensed-Bold.ttf')
W,H=2048,256
labels=['ПРОБОИНА','СТЕКЛОУСТ НА КОРПУСЕ','ПЕРЕГРЕВ','ИЛ — СОНАР СЛЕП','МАЛО ЗАРЯДА']
widths=[1.05,2.25,1.15,1.65,1.10]
edges=[round(x/7.2*W) for x in [0,1.05,3.30,4.45,6.10,7.20]]
bg=(11,28,36);off=(102,116,122);on=(255,178,89);seam=(81,77,67);metal=(140,128,107)
base=Image.new('RGB',(W,H),bg);d=ImageDraw.Draw(base)
# Hardware stays identical between states and never emits.
for x in edges:
 x=min(W-3,max(2,x));d.rectangle((x-1,0,x+1,255),fill=seam)
 for y in [22,233]:
  d.ellipse((x-2,y-7,x+2,y+7),fill=metal)
d.line((0,3,W-1,3),fill=seam,width=2);d.line((0,252,W-1,252),fill=seam,width=2)
font_size=1
for size in range(20,80):
 f=ImageFont.truetype(str(FONT),size)
 if all(f.getbbox(t)[2]-f.getbbox(t)[0] <= edges[i+1]-edges[i]-42 for i,t in enumerate(labels)):font_size=size
font=ImageFont.truetype(str(FONT),font_size)
letters=Image.new('L',(W,H));corners=Image.new('L',(W,H));cd=ImageDraw.Draw(corners);records=[]
for i,t in enumerate(labels):
 x0,x1=edges[i:i+2];bb=font.getbbox(t);tw,th=bb[2]-bb[0],bb[3]-bb[1]
 ink=Image.new('L',(tw,th));ImageDraw.Draw(ink).text((-bb[0],-bb[1]),t,font=font,fill=255)
 # Atlas Y is stretched 3.6x relative to the physical face. Ink height = 0.14 m.
 ink=ink.resize((tw,143),Image.Resampling.LANCZOS).point(lambda a:255 if a>=128 else 0)
 tx=(x0+x1-tw)//2;ty=(H-143)//2;letters.paste(ink,(tx,ty))
 # Corner lengths: 18px X ~= 6.3cm; 64px Y ~= 6.25cm. Stroke 4px X / 14px Y.
 l,r=x0+9,x1-10;top,bot=14,241
 for xx,sgn in [(l,1),(r,-1)]:
  for yy,sy in [(top,1),(bot,-1)]:
   cd.rectangle((min(xx,xx+sgn*18),min(yy,yy+sy*13),max(xx,xx+sgn*18),max(yy,yy+sy*13)),fill=128)
   cd.rectangle((min(xx,xx+sgn*3),min(yy,yy+sy*64),max(xx,xx+sgn*3),max(yy,yy+sy*64)),fill=128)
 records.append({'text':t,'x_start':x0,'x_end_exclusive':x1,'width_px':x1-x0,'width_m':widths[i],'uv_min':x0/W,'uv_max':x1/W,'ink_rect':[tx,ty,tx+tw,ty+143]})
a=np.array(letters);c=np.array(corners);assert not np.any((a>0)&(c>0))
mask=np.maximum(a,c).astype('uint8');base_a=np.array(base);out_off=base_a.copy();out_on=base_a.copy();out_off[c>0]=seam;out_off[a>0]=off;out_on[mask>0]=on
Image.fromarray(out_off).save(O/'tablo-color.png',optimize=True)
Image.fromarray(out_on).save(O/'tablo-color-on.png',optimize=True)
Image.fromarray(mask).save(O/'tablo-mask.png',optimize=True)
# Preview: native atlas proportions first, then physical 28.8:1 and 17px phone representation.
p=Image.new('RGB',(1600,720),bg);pd=ImageDraw.Draw(p);pf=lambda s:ImageFont.truetype(str(FONT),s)
pd.text((32,12),'MOD-019 · Табло тревог · атлас и проверка масштаба',font=pf(27),fill=(213,228,232))
for name,y,title in [('tablo-color.png',77,'Погашено · UV-атлас 2048 × 256'),('tablo-color-on.png',302,'Горит · те же пиксели букв и углов')]:
 pd.text((32,y-29),title,font=pf(20),fill=(154,217,232));p.paste(Image.open(O/name).resize((1536,192),Image.Resampling.LANCZOS),(32,y))
pd.text((32,513),'На плоскости 7,2 × 0,25 м · физические пропорции',font=pf(20),fill=(154,217,232));p.paste(Image.fromarray(out_on).resize((1536,53),Image.Resampling.LANCZOS),(32,544))
pd.text((32,620),'Телефон 1600 × 720 · табло 490 × 17 px · без bloom',font=pf(20),fill=(154,217,232));p.paste(Image.fromarray(out_on).resize((490,17),Image.Resampling.LANCZOS),(32,660));pd.text((580,656),'17 px — высота всего поля, буквы ≈ 9,5 px',font=pf(17),fill=(213,228,232))
p.save(O/'preview.png',optimize=True)
assert set(np.unique(mask))=={0,128,255}
assert np.array_equal(np.any(out_on!=out_off,axis=2),mask>0)
assert np.all(out_off[mask==255]==off) and np.all(out_on[mask>0]==on)
assert np.all(out_off[mask==0]==out_on[mask==0])
for name in ['tablo-color.png','tablo-color-on.png','tablo-mask.png']:assert (O/name).stat().st_size<1024**2
(O/'fields.json').write_text(json.dumps({'size':[W,H],'font':FONT.name,'font_size_before_y_stretch':font_size,'ink_height_px':143,'fields':records},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'edges':edges,'font_size':font_size,'mask_counts':{int(v):int((mask==v).sum()) for v in np.unique(mask)},'files':{f.name:f.stat().st_size for f in O.glob('*.png')}},indent=2))
