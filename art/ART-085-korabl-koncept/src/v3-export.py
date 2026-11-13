from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import shutil
O=Path('art/ART-085-korabl-koncept');R=Path('C:/Users/FEDYA/.codex/generated_images/01a150d4-51bb-7de2-a546-c950a2e37207');font='C:/Windows/Fonts/arial.ttf'
def text(d,xy,t,s=24,c='#dce5e6'):d.text(xy,t,font=ImageFont.truetype(font,s),fill=c)
for raw,name,title,cap in [('exec-a25061c2-cc88-4259-8ad4-192dbd3b1e31.png','01-v3-batiskaf.jpg','01 / ART-085 v3 · ЭКСПЕДИЦИОННЫЙ БАТИСКАФ','В: 4 вертикальных канала · Б: 2 поперечных тоннеля · Схема размещения — лист 06'),('exec-a54b1919-aa22-47a6-907d-26221bd9c74b.png','05-v3-nosovaya.jpg','05 / ART-085 v3 · ОБЩАЯ НОСОВАЯ ЗОНА','Боковые посты развёрнуты внутрь и к носу · Два обхода сонара · Размеры — лист 03')]:
 im=Image.new('RGB',(1600,900),'#0b1c24');im.paste(Image.open(R/raw).convert('RGB').resize((1472,828),Image.Resampling.LANCZOS),(64,36));d=ImageDraw.Draw(im);text(d,(64,5),title,24);text(d,(64,870),cap,20);im.save(O/name,quality=91,optimize=True)
im=Image.new('RGB',(2048,1152),'#0b1c24');d=ImageDraw.Draw(im)
text(d,(60,30),'06 / ДВИЖИТЕЛИ · РАЗМЕЩЕНИЕ КАНАЛОВ',44);text(d,(60,95),'ART-085 v3 · Компоновочное предложение, без расчёта тяги и физики',24,'#8fa6ad')
# Two sections at distinct longitudinal stations, same metric scale
for cx,z,kind in [(530,-6,'В'),(1510,-4,'Б')]:
 s=65;cy=510;P=lambda x,y:(cx+x*s,cy-y*s)
 d.rounded_rectangle((*P(-5,4),*P(5,-5)),radius=100,outline='#dce5e6',width=4)
 d.ellipse((*P(-3.3,3.4),*P(3.3,-.9)),outline='#67ddeb',width=4)
 d.line((P(-3.2,0),P(3.2,0)),fill='#67ddeb',width=3)
 text(d,(cx-340,165),f'Сечение z={z} м / каналы {kind}',30)
 if kind=='В':
  for x in (-4.1,4.1):
   d.rectangle((*P(x-.45,3.4),*P(x+.45,-3.8)),outline='#e8b772',width=4)
   d.line((P(x,3),P(x,-3.3)),fill='#e8b772',width=3)
   for y in (-3.3,3):d.line((P(x-.18,y+.25),P(x,y),P(x+.18,y+.25)),fill='#e8b772',width=3)
 else:
  d.rectangle((*P(-4.9,-1.75),*P(4.9,-2.65)),outline='#e8b772',width=4)
  d.line((P(-4.5,-2.2),P(4.5,-2.2)),fill='#e8b772',width=3)
 text(d,(cx-315,870),'Прочный объём: x ±3,3; y −0,9…3,4',23,'#67ddeb')
lines=['В: 4 канала Ø0,9 м; x=±4,1; z=−6 / +7,5. Вне прочного объёма, верхний и нижний выходы.', 'Б: 2 тоннеля Ø0,9 м; z=−4 / +9,5; y=−2,2. Поперёк корпуса, ниже прочного объёма.', 'Сечения сняты в разных местах: В и Б не пересекаются. Два кормовых маршевых движителя сохранены.', 'На листе 01 дальняя пара В частично скрыта. Точные станции и размеры задают схемы 03/06, не перспектива.']
for i,t in enumerate(lines):text(d,(60,945+43*i),t,23,'#e8b772' if i<2 else '#dce5e6')
im.save(O/'06-v3-dvizhiteli.png')
