from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json
P=Path(__file__).resolve().parents[1]
font='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
def f(n):return ImageFont.truetype(font,n)
ink='#d4e1de';muted='#8ca9ae'
im=Image.new('RGB',(1600,720),'#102027');d=ImageDraw.Draw(im)
d.text((16,5),'ART-076 · мягкий ободок и тёмные щели корпуса',font=f(24),fill=ink)
d.text((1190,9),'0 новых вызовов · 1 выборка · AO формулой',font=f(17),fill=muted)
for row,(name,label) in enumerate([('flyby12','Облёт · 12 м · прожектор выключен'),('flyby45-clear','Тот же ракурс · 45 м · прожектор выключен'),('rear8','Всплытие · 8 м · сзади-сверху')]):
 y=36+row*226
 for col,suffix in enumerate(['','-control']):
  x=16+col*792
  pic=Image.open(P/'source'/f'{name}{suffix}.png').convert('RGB')
  crop=(0,150,1600,570) if name!='rear8' else (0,170,1600,590)
  im.paste(pic.crop(crop).resize((784,206),Image.Resampling.LANCZOS),(x,y+20))
  d.text((x+5,y),('С эффектом · ' if col==0 else 'Без эффекта · ')+label,font=f(17),fill=ink)
im.save(P/'obodok-list.png',optimize=True)
proof=Image.new('RGB',(1600,900),'#102027');dr=ImageDraw.Draw(proof)
dr.text((18,12),'ART-076 · кривые ободка и затенение примыканий',font=f(28),fill=ink)
lut=np.asarray(Image.open(P/'obodok-gradient.png'));v=lut[:,:,:3]/255
v=np.where(v<=.0031308,v*12.92,1.055*v**(1/2.4)-.055)
proof.paste(Image.fromarray(np.uint8(np.clip(v*255,0,255))).resize((512,160),Image.Resampling.NEAREST),(18,91))
dr.text((18,61),'RGB · linear показан в sRGB · строки по глубине',font=f(17),fill=ink)
for j,label in enumerate(['0','8','14','20','32,5','45','90','ил']):dr.text((535,91+j*20),label,font=f(12),fill=muted)
proof.paste(Image.fromarray(lut[:,:,3]).convert('RGB').resize((512,80),Image.Resampling.NEAREST),(18,292))
dr.text((18,263),'A · от фронтального взгляда к краю',font=f(18),fill=ink)
x0,y0,ww,hh=32,426,480,197;dr.rectangle((x0,y0,x0+ww,y0+hh),outline=muted)
for row,color in [(1,'#729A9C'),(3,'#71A5B5'),(5,'#BCDDE2')]:
 pts=[(x0+i/255*ww,y0+(1-a/255)*hh) for i,a in enumerate(lut[row,:,3])];dr.line(pts,fill=color,width=2)
dr.text((18,394),'Сила по углу · 8 / 20 / 45 м',font=f(20),fill=ink)
dr.text((32,636),'0           1 − dot(N, V)           1',font=f(18),fill=muted)
dr.text((18,681),'AO: швы + зоны у деталей HullPlan',font=f(19),fill=ink)
dr.text((18,711),'Текстура AO не нужна: UV трипланарные.',font=f(18),fill=muted)
proof.paste(Image.open(P/'source/contact12.png').convert('RGB').resize((1020,459),Image.Resampling.LANCZOS),(565,79))
dr.text((565,49),'AO · диагностический вид 0,55…1 · контраст для проверки',font=f(19),fill=ink)
for i,(name,label) in enumerate([('wear15','Корпус 15% · следы ART-049'),('zap45','Разряд ART-068 · 0,3 с'),('eco45','45 м · Экономно')]):
 x=565+i*342;pic=Image.open(P/'source'/f'{name}.png').convert('RGB')
 proof.paste(pic.crop((0,170,1600,670)).resize((330,148),Image.Resampling.LANCZOS),(x,589))
 dr.text((x,561),label,font=f(16),fill=ink)
dr.text((18,778),'Ободок цвета воды · геометрическая нормаль · без шума и неоновой полосы',font=f(24),fill=ink)
dr.text((18,822),'Ил и разрушение гасят ободок. Дуги, следы, прожектор и материалы мостика сохранены.',font=f(21),fill=muted)
dr.text((18,860),'Одна новая LUT 256 × 8 · 8 КиБ несжатых · без новых мешей и источников света',font=f(20),fill=muted)
proof.save(P/'obodok-proverka.png',optimize=True)
report={'new_texture_raw_bytes':256*8*4,'texture_limit_bytes':512*1024,'captures':{}}
assert lut.shape==(8,256,4) and not lut[7,:,3].any()
assert np.min(np.diff(lut[:,:,3].astype(int),axis=1))>=0
names=['flyby12','flyby45-clear','rear8','contact12','wear15','zap45','eco45','silt45','inside12','wreck45','contactlit12']
for name in names:
 data=json.loads((P/'source'/f'{name}-metrics.json').read_text())
 assert data['baseline']==data['after']==data['zero_gain']
 a=np.asarray(Image.open(P/'source'/f'{name}.png')).astype(float)
 b=np.asarray(Image.open(P/'source'/f'{name}-control.png')).astype(float)
 z=np.asarray(Image.open(P/'source'/f'{name}-zero.png')).astype(float)
 roi=(slice(230,510),slice(430,1130),slice(0,3))
 data['effect_vs_zero_roi_mae']=float(np.abs(a[roi]-z[roi]).mean())
 data['control_vs_zero_roi_mae']=float(np.abs(b[roi]-z[roi]).mean())
 report['captures'][name]=data
 for suffix in ['','-control']:
  Image.open(P/'source'/f'{name}{suffix}.png').convert('RGB').save(P/'source'/f'{name}{suffix}.jpg',quality=94,subsampling=0)
for path in list(P.glob('*.png'))+list((P/'source').glob('*.jpg')):assert path.stat().st_size<2*1024*1024,(path,path.stat().st_size)
assert report['new_texture_raw_bytes']<=report['texture_limit_bytes']
assert report['captures']['wreck45']['alive']==0
(P/'source/validation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report,indent=2))
