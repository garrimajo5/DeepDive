from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,random,json
R=Path(__file__).resolve().parents[1];atlas=Image.open(R/'vzves-atlas.png').convert('RGBA')
F='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
def font(n):return ImageFont.truetype(F,n)
def window_mask(name):
 im=Image.new('L',(1600,720));d=ImageDraw.Draw(im)
 for p in json.loads((R/f'source/{name}.json').read_text()):d.polygon([tuple(a) for a in p],fill=255)
 # Conservatively protect the near helm and touch controls, which lie in front of glass.
 d.rectangle((535,465,1065,720),fill=0);d.ellipse((38,395,328,685),fill=0);d.ellipse((1350,440,1550,640),fill=0)
 return np.array(im)/255

stats={}
for mode,base,n,seed in [('melko','melko',38,80),('glubzhe','glubzhe',28,200),('shahta','melko',38,80)]:
 im=Image.open(R/f'source/{base}.png').convert('RGBA');mask=window_mask(base);beam=np.zeros((720,1600))
 if mode=='shahta':
  yy,xx=np.mgrid[:720,:1600]
  for cx,w in [(360,100),(855,145),(1250,80)]:
   half=w*(.32+.68*np.clip((yy+150)/850,0,1));q=np.abs((xx-cx-(yy-250)*.025)/half)
   beam+=np.maximum(0,1-q*q)**2.5*np.clip(1-(yy+150)/950,0,1)*.14
  b=np.array(im).astype(float);b[:,:,:3]=b[:,:,:3]*(1-beam[:,:,None]*mask[:,:,None])+np.array([154,217,232])*beam[:,:,None]*mask[:,:,None];im=Image.fromarray(np.uint8(b))
 layer=Image.new('RGBA',im.size);rng=random.Random(seed);placements=[]
 weights=[9]*6+[4]*3+[10]*3+[4/3]*3
 for j in range(n):
  i=rng.choices(range(15),weights=weights)[0]
  if j==0:i=12 # one bubble is deliberately present for the art comparison.
  size=rng.choice([6,7,8,9,10,12]);angle=rng.uniform(-70,70) if i<12 else rng.uniform(-12,12)
  for attempt in range(1000):
   x=rng.randrange(205,1390);y=rng.randrange(235,460)
   if mask[y,x]>.9:break
  p=atlas.crop(((i%4)*128,(i//4)*128,(i%4+1)*128,(i//4+1)*128)).resize((size,size),Image.Resampling.LANCZOS).rotate(angle,resample=Image.Resampling.BICUBIC,expand=True)
  a=np.array(p).copy();lit=.54 if mode=='glubzhe' else .70
  if mode=='shahta':lit=min(1,.70+beam[y,x]*5)
  a[:,:,:3]=np.uint8(np.array([213,228,232])*lit);a[:,:,3]=np.uint8(a[:,:,3]*rng.uniform(.55,.90));p=Image.fromarray(a)
  layer.alpha_composite(p,(x-p.width//2,y-p.height//2));placements.append({'frame':i,'screen_xy':[x,y],'card_px':size})
 la=np.array(layer).copy();la[:,:,3]=np.uint8(la[:,:,3]*mask);layer=Image.fromarray(la)
 final=Image.alpha_composite(im,layer).convert('RGB');final.save(R/f'proba-{mode}.jpg',quality=96)
 stats[mode]={'placements':placements,'window_alpha_coverage_gt_8':float(np.count_nonzero(la[:,:,3]>8)/max(1,np.count_nonzero(mask))),'base':base,'method':'2D atlas composite over real game capture; shaft artist mockup, not engine effect'}
(R/'preview-validation.json').write_text(json.dumps(stats,ensure_ascii=False,indent=2),encoding='utf8')

sheet=Image.new('RGB',(2048,1152),'#0B1C24');d=ImageDraw.Draw(sheet)
def text(x,y,s,n=25,c='#D5E4E8'):d.text((x,y),s,font=font(n),fill=c)
text(30,14,'ART-058 · ВЗВЕСЬ ЗА БОРТОМ',39)
text(30,67,'Атлас 4 × 4 · 512² RGBA',29,'#9AD9E8')
bg=Image.new('RGBA',(512,512),'#102830');bg.alpha_composite(atlas);sheet.paste(bg.convert('RGB'),(30,110))
for i in range(16):text(36+(i%4)*128,116+(i//4)*128,f'{i+1:02}',18,'#9AD9E8')
for k,line in enumerate(['01–06  Морской снег','07–09  Органические нити','10–12  Пылинки','13–15  Пузырьки','16         Пустой кадр','','Хлопья: 2,5–7 см','Нити: 5–12 см','Пыль: 0,8–1,8 см','Пузыри: 1,5–5 см','Прозрачный край ≥ 4 px','Один атлас · без эмиссии']):text(570,125+k*35,line,23,'#9AD9E8' if k in [6,7,8] else '#D5E4E8')
for mode,title,x,y in [('melko','8 м · спокойная взвесь',1050,80),('glubzhe','20 м · меньше света на частицах',30,635),('shahta','8 м · взвесь в шахте ART-052',1050,635)]:
 text(x,y,title,28,'#9AD9E8');sheet.paste(Image.open(R/f'proba-{mode}.jpg').resize((970,437),Image.Resampling.LANCZOS),(x,y+43))
text(30,1118,'Пробы поверх настоящих кадров мостика. Взвесь и шахта — художественная примерка, не встроенный эффект.',23,'#9AD9E8')
sheet.save(R/'vzves-list.png',optimize=True)

# Native 6 / 9 / 12 pixel samples, with 6x nearest enlargement to inspect silhouettes.
test=Image.new('RGB',(1536,768),'#0B1C24');d=ImageDraw.Draw(test)
d.text((25,12),'ПРОВЕРКА НА ЭКРАНЕ · 6 / 9 / 12 пикселей',font=font(34),fill='#D5E4E8')
for i in range(16):
 xx=25+(i%8)*190;yy=80+(i//8)*330;d.text((xx,yy),f'{i+1:02}',font=font(22),fill='#9AD9E8')
 for k,size in enumerate([6,9,12]):
  p=atlas.crop(((i%4)*128,(i//4)*128,(i%4+1)*128,(i//4+1)*128)).resize((size,size),Image.Resampling.LANCZOS)
  bg=Image.new('RGBA',test.size);bg.alpha_composite(p,(xx+10+k*50,yy+45));test=Image.alpha_composite(test.convert('RGBA'),bg).convert('RGB');d=ImageDraw.Draw(test)
  z=p.resize((size*6,size*6),Image.Resampling.NEAREST);bg=Image.new('RGBA',test.size);bg.alpha_composite(z,(xx+k*52,yy+85));test=Image.alpha_composite(test.convert('RGBA'),bg).convert('RGB');d=ImageDraw.Draw(test)
  d.text((xx+k*52,yy+170),str(size),font=font(18),fill='#9AD9E8')
d.text((25,730),'Сверху — настоящий размер; ниже — увеличение ×6 без сглаживания. Кадр 16 прозрачен.',font=font(23),fill='#9AD9E8')
test.save(R/'vzves-test-telefon.png',optimize=True)
print({k:v['window_alpha_coverage_gt_8'] for k,v in stats.items()})
