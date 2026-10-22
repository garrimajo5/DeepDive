from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageEnhance
import numpy as np,json
O=Path(__file__).resolve().parent.parent;R=O/'renders';font=lambda n:ImageFont.truetype('C:/Windows/Fonts/arial.ttf',n)
bg='#172b34';ink='#e1e7df';dim='#a8bec4'
im=Image.new('RGB',(2048,1152),bg);d=ImageDraw.Draw(im)
d.text((28,18),'КОВЧЕГ-7 · ПОВРЕЖДЕНИЯ ОБШИВКИ',font=font(37),fill=ink)
for k,hull in enumerate([100,70,40,15]):
 x=24+(k%2)*1024;y=80+(k//2)*350
 im.paste(Image.open(R/f'hull-{hull}.png').convert('RGB'),(x,y))
 d.text((x+16,y+6),f'Корпус {hull} %',font=font(30),fill=ink)
 d.text((x+16,y+300),{100:'Без следов',70:'Царапины и первые кольца',40:'Сколы и вмятины',15:'Глубокие следы, сварная заплатка'}[hull],font=font(24),fill=ink)
a=np.roll(np.array(Image.open(O/'povrezhdeniya-tsvet.png')) ,(-317,-211),(0,1));features=json.loads((O/'validation.json').read_text())['features']
for k,(i,title) in enumerate([(0,'Скол краски'),(2,'Царапины о камень'),(4,'Вмятина'),(1,'Кольцо присоски'),(8,'Сварная заплатка')]):
 x=24+k*402;y=820;box=features[i]['source_bounds'];box=tuple(round(v*1024/1254) for v in box);sample=a.copy();T=np.roll(np.array(Image.open(O/'povrezhdeniya-uroven.png')),(-317,-211),(0,1));sample[:,:,3]=np.where(T==features[i]['threshold'],sample[:,:,3],0);cut=Image.fromarray(sample).crop(box);cut.thumbnail((365,205),Image.Resampling.LANCZOS);panel=Image.new('RGB',(380,210),'#8c806b');panel.paste(cut,((380-cut.width)//2,(210-cut.height)//2),cut);im.paste(panel,(x,y));d.text((x,y+218),title,font=font(25),fill=ink)
d.text((28,1106),'Плитка 2 × 2 м · один ракурс и свет · силуэт и окна сохраняются · геометрия корпуса из проекта',font=font(23),fill=dim)
im.save(O/'povrezhdeniya-list.png',optimize=True)
qa=Image.new('RGB',(2048,1152),bg);d=ImageDraw.Draw(qa);d.text((28,20),'ART-049 · ПОВТОР ПЛИТКИ И ПОРОГИ',font=font(37),fill=ink)
tile=Image.open(R/'plate-15.png').convert('RGB');grid=Image.new('RGB',(3072,3072))
for y in range(3):
 for x in range(3):grid.paste(tile,(x*1024,y*1024))
grid=ImageEnhance.Contrast(grid).enhance(1.8).resize((950,950),Image.Resampling.LANCZOS);qa.paste(grid,(28,95));qa.paste(Image.open(O/'povrezhdeniya-uroven.png').convert('RGB').resize((950,950),Image.Resampling.NEAREST),(1065,95))
d.text((28,1065),'Повтор 3 × 3 · корпус 15 % · контраст ×1,8',font=font(25),fill=ink);d.text((1065,1065),'Порог потери прочности: от чёрного к белому',font=font(25),fill=ink)
d.text((28,1112),'100 / 70 / 40 / 15 % корпуса: 0 / 7 / 12 / 17 следов на плитку. Прозрачность берётся из карты цвета.',font=font(23),fill=dim)
qa.save(O/'povrezhdeniya-proverka.png',optimize=True)
for p in [O/'povrezhdeniya-list.png',O/'povrezhdeniya-proverka.png']:
 if p.stat().st_size>2*1024**2:
  i=Image.open(p).quantize(colors=192,method=Image.Quantize.MEDIANCUT);i.save(p,optimize=True)
 assert p.stat().st_size<2*1024**2
