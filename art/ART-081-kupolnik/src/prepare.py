from PIL import Image, ImageDraw, ImageFont, ImageOps
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
SRC=Path(sys.argv[1])
BG='#0b192b'; FG='#c3d7e1'; CY='#67ddeb'
font=lambda n: ImageFont.truetype('C:/Windows/Fonts/arial.ttf',n)
im=Image.open(SRC).convert('RGB').resize((1672,941))
out=Image.new('RGB',(2048,1152),BG); d=ImageDraw.Draw(out)
def text(x,y,s,n=28,fill=FG): d.text((x,y),s,font=font(n),fill=fill)
def paste(box,xy,size): out.paste(im.crop(box).resize(size,Image.Resampling.LANCZOS),xy)
text(40,24,'КУПОЛЬНИК / ART-081',48)
text(42,92,'СБОКУ · длина 3 м',30);text(805,92,'СПЕРЕДИ · ширина 1,8 м',30);text(1420,92,'СВЕРХУ',30)
paste((40,154,655,520),(28,145),(740,410))
paste((674,149,1103,527),(790,145),(552,452))
paste((1120,139,1616,515),(1390,145),(620,450))
text(50,570,'Купол 2,2 м · высота в покое 1,2 м',26)
text(50,615,'Три захвата · два клапана-сифона · овальные фотофоры',26)
# Detail crops, labels typeset rather than generated.
for box,x,label in [((35,537,326,691),40,'Минеральный купол'),((349,537,638,691),430,'Мягкий захват'),((1004,537,1347,691),820,'Клапаны-сифоны')]:
    paste(box,(x,672),(350,186));text(x,870,label,24)
text(1260,690,'ГАБАРИТ В ПОКОЕ',28,CY)
text(1260,741,'3 × 1,8 × 1,2 м',38)
text(1260,799,'Длина × ширина × высота',25)
# Exact shared scale, 40px/m; simplified ship profile traced from ART-001.
d.line((40,935,2008,935),fill='#395265',width=2)
text(40,952,'СРАВНЕНИЕ ДЛИН · 40 пикселей = 1 м',23)
pts=[(0,48),(35,25),(150,8),(220,7),(220,0),(275,0),(275,8),(1100,10),(1160,-15),(1210,-15),(1210,30),(1280,34),(1280,85),(1210,88),(1200,110),(1140,110),(1100,92),(190,92),(60,80),(0,65)]
d.polygon([(80+x,1000+y) for x,y in pts],fill='#8c806b')
text(550,1114,'Ковчег-7 · 32 м',23)
# Creature silhouette from same view with threshold mask, exact 120px / 3m width.
crop=im.crop((429,760,681,895)).convert('RGB')
mask=crop.convert('L').point(lambda p:255 if p>42 else 0)
mask=mask.resize((120,64),Image.Resampling.LANCZOS)
out.paste('#827da0',(1610,1040),mask)
text(1510,1114,'Купольник · 3 м',23)
ImageOps.posterize(out,6).save(ROOT/'01-rakursy.png',optimize=True)
print('01-rakursy.png', (ROOT/'01-rakursy.png').stat().st_size)
if len(sys.argv)>2:
    detail=Image.open(sys.argv[2]).convert('RGB').resize((2048,1152),Image.Resampling.LANCZOS)
    ImageOps.posterize(detail,5).save(ROOT/'02-stvorka.png',optimize=True)
    print('02-stvorka.png',(ROOT/'02-stvorka.png').stat().st_size)
