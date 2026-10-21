from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import random,math,sys
P=Path(__file__).resolve().parents[1]
F='C:/Users/FEDYA/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/share/fonts/DejaVuSans.ttf'
def text(im,xy,s,size=30,c='#D5E4E8',a=None):ImageDraw.Draw(im).text(xy,s,font=ImageFont.truetype(F,size),fill=c,anchor=a)
def flake(d,x,y,r,c):
 pts=[(x+math.cos(i*math.tau/7)*r*(.65+(i%3)*.14),y+math.sin(i*math.tau/7)*r*(.55+(i%2)*.4)) for i in range(7)];d.polygon(pts,fill=c)
def window(k,n):
 im=Image.new('RGB',(720,350),'#244751');d=ImageDraw.Draw(im);rng=random.Random(7)
 if k<.5:
  d.polygon([(0,325),(100,255),(180,290),(260,210),(400,300),(530,210),(720,270),(720,350)],fill='#365C5E')
 veil=Image.new('RGB',im.size,'#55665D');im=Image.blend(im,veil,k*.65);d=ImageDraw.Draw(im)
 d.polygon([(342,350),(274,350-int(230*(1-.55*k))),(435,350-int(210*(1-.55*k)))],fill='#91ADA6')
 for i in range(n):flake(d,rng.randrange(20,700),rng.randrange(15,335),rng.randrange(4,17),rng.choice(['#45584F','#728479','#A0AEA0']))
 d.rectangle((4,4,716,346),outline='#8C806B',width=8);return im

def holo(jam=False):
 im=Image.new('RGB',(1080,510),'#102B37');d=ImageDraw.Draw(im);cx,cy=540,255
 for r in [80,160,235]:d.ellipse((cx-r*1.7,cy-r*.8,cx+r*1.7,cy+r*.8),outline='#32616D',width=3)
 d.polygon([(540,221),(518,267),(562,267)],fill='#D5E4E8')
 if jam:
  rng=random.Random(18)
  for i in range(50):
   x=rng.randrange(175,905);y=rng.randrange(90,420);d.line((x,y,x+rng.randrange(12,43),y),fill='#32616D',width=4)
  for r in [70,90,105]:
   for a,b in [(5,60),(90,143),(183,245),(280,330)]:d.arc((cx-r*1.7,cy-r*.8,cx+r*1.7,cy+r*.8),a,b,fill='#67DDEB',width=7)
 else:
  d.ellipse((cx-330,cy-155,cx+330,cy+155),outline='#67DDEB',width=7)
  for x,y in [(350,200),(780,320),(610,140)]:d.ellipse((x-7,y-7,x+7,y+7),fill='#67DDEB')
 return im
if len(sys.argv)>1:
 im=ImageOps.fit(Image.open(sys.argv[1]).convert('RGB'),(2400,1080));d=ImageDraw.Draw(im)
 d.rounded_rectangle((673,18,1728,73),radius=8,fill='#514D43',outline='#8C806B',width=3)
 x=681
 for i,ratio in enumerate([1.05,2.25,1.15,1.65,1.10]):
  w=int(1036*ratio/7.2);d.rounded_rectangle((x,24,x+w-5,65),radius=3,fill='#FFB259' if i==3 else '#0B1C24',outline='#514D43',width=2)
  if i==3:text(im,(x+w/2-2,44),'ИЛ — СОНАР СЛЕП',19,'#0B1C24','mm')
  x+=w
 im.save(P/'tma-mostik.jpg',quality=92,optimize=True)
main=Image.open(P/'tma-mostik.jpg')
sheet=Image.new('RGB',(2400,2500),'#0B1C24');text(sheet,(60,35),'Сонарная тьма · фазы и правила чтения',48)
for i,(title,k,n,desc) in enumerate([('Начало · 0–0,5 с',.25,22,'Хлопья подходят · риф ещё виден'),('Внутри · плотное облако',1,100,'Короткий луч · деталей вдали нет'),('Конец · последние 8 с',.2,13,'Хлопья редеют и уходят вниз')]):
 x=60+i*780;text(sheet,(x,115),title,32);sheet.paste(window(k,n),(x,165));text(sheet,(x,535),desc,28)
text(sheet,(60,610),'Обычный импульс',36);text(sheet,(1260,610),'Импульс вязнет · сонар включён',36)
sheet.paste(holo(),(60,670));sheet.paste(holo(True),(1260,670))
text(sheet,(60,1195),'Кольцо проходит наружу · свежие контакты',28);text(sheet,(1260,1195),'Разрыв на ⅓ радиуса · новых отметок нет',28)
text(sheet,(60,1285),'Хлопья у окна · схема маски, не новый меш',36)
d=ImageDraw.Draw(sheet)
for i,(r,label) in enumerate([(18,'10–20 см'),(38,'20–40 см'),(65,'40–70 см')]):
 x=170+i*285;flake(d,x,1450,r,['#45584F','#728479','#A0AEA0'][i]);text(sheet,(x,1550),label,29,a='mm')
for j,s in enumerate(['Не светятся · серо-зелёные с рваным краем','Обычный морской снег: мельче и реже','Внутри корпуса хлопьев нет','300 карточек на облако · до 3 облаков']):text(sheet,(1050,1360+j*58),s,31)
text(sheet,(60,1660),'16:9 · центральная обрезка · органы управления остаются свободны',36)
narrow=main.crop((240,0,2160,1080));narrow.thumbnail((1152,648),Image.Resampling.LANCZOS);sheet.paste(narrow,(60,1730))
for j,s in enumerate(['Табло: «ИЛ — СОНАР СЛЕП»','Пост пилота — выход из облака','Тревога не выключает сонар','Помехи импульса: ещё до 4 с','Луч при k=1: 45% длины','Облако: 45 с / оползень 80 с','Без красного и частиц в каюте']):text(sheet,(1280,1770+j*71),s,31)
sheet.quantize(colors=240).save(P/'tma-sostoyaniya.png',optimize=True)
for f in list(P.glob('*.png'))+list(P.glob('*.jpg')):print(f.name,Image.open(f).size,f.stat().st_size);assert f.stat().st_size<2000000
