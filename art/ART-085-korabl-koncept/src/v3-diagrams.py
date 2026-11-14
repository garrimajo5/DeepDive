from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math
OUT=Path('art/ART-085-korabl-koncept')
BG='#0b1c24'; FG='#dce5e6'; MUT='#8fa6ad'; CY='#67ddeb'; AM='#e8b772'; GREY='#354953'
font='C:/Windows/Fonts/arial.ttf'
def new(title,sub):
 im=Image.new('RGB',(2048,1152),BG); d=ImageDraw.Draw(im)
 txt(d,(58,30),title,44);txt(d,(60,92),sub,23,MUT);d.line((60,133,1985,133),fill=GREY,width=2);return im,d
def txt(d,xy,t,s=24,c=FG):d.text(xy,t,font=ImageFont.truetype(font,s),fill=c)
def poly(d,pts,c=FG,w=3):d.line(pts,fill=c,width=w,joint='curve')
def dim(d,a,b,label):
 d.line((a,b),fill=CY,width=2)
 for x,y in (a,b):d.line((x-5,y-8,x+5,y+8),fill=CY,width=2)
 txt(d,((a[0]+b[0])/2-60,a[1]-32),label,22,CY)
def human(d,x,y,s=1,c=FG):
 # baseline at y, exact total 1.8 m
 d.ellipse((x-.12*s,y-1.8*s,x+.12*s,y-1.56*s),outline=c,width=2)
 d.line((x,y-1.56*s,x,y-.65*s),fill=c,width=3)
 d.line((x-.35*s,y-1.1*s,x,y-1.4*s,x+.35*s,y-1.1*s),fill=c,width=3)
 d.line((x-.2*s,y,x,y-.65*s,x+.2*s,y),fill=c,width=3)
# side section: z horizontal, y vertical, 54 px/metre
im,d=new('02 / БАТИСКАФ · ПОСАДКА И ОТСЕКИ','ART-085 / v3 · Одна конструкция · Все размеры — предложение на оценку')
s=54; ox=1030; oy=440
P=lambda z,y:(ox+z*s,oy-y*s)
outer=[(-14,-2),(-13,-.2),(-13,2.5),(-10,3.4),(-6,4),(6,4),(11,2.6),(14,.2),(14,-2.6),(10,-4.3),(-9,-5),(-12,-3.8),(-14,-2)]
poly(d,[P(*p) for p in outer],FG,4)
pressure=[(-13,.3),(-13,2.2),(-9,3),(-5,3.4),(7,3.4),(9.7,2.7),(11,1.0),(10,-.9),(-8,-.9),(-12.5,-.4),(-13,.3)]
poly(d,[P(*p) for p in pressure],CY,3)
d.line((P(-12.5,0),P(10,0)),fill=FG,width=4)
for z in (-3,2,7):
 d.line((P(z,0),P(z,2.8)),fill=FG,width=3)
 d.line((P(z,0),P(z,2.1)),fill=AM,width=7)
# simplified furniture, not structural engineering
human(d,*P(-6.7,0),s)
poly(d,[P(-11.4,.3),P(-11.4,1.1),P(-11.8,1.33)],FG,3)
poly(d,[P(-11.4,.6),P(-11.8,.6),P(-12,0)],FG,3)
for z1,z2,h in [(-12.65,-12.35,.85),(-2.5,.7,.95),(3.5,5.5,.6),(7.6,9.8,2.1)]:
 d.rectangle((*P(z1,h),*P(z2,0)),outline=AM,width=3)
# habitat second bunk
poly(d,[P(3.5,1.6),P(5.5,1.6)],AM,3)
# port at bow eye height
poly(d,[P(-13,.78),P(-13,1.88)],CY,9)
d.ellipse((P(-11.8,1.33)[0]-5,P(-11.8,1.33)[1]-5,P(-11.8,1.33)[0]+5,P(-11.8,1.33)[1]+5),fill=CY)
poly(d,[P(-11.8,1.33),P(-13,.78)],CY,2)
txt(d,(75,205),'Глаз: z−11,80 / y1,33; порты z−13,00',20,CY)
# low work recess and folded arms
poly(d,[P(-12,-1.3),P(-6,-1.3),P(-6,-4.2)],AM,4)
poly(d,[P(-11,-3.2),P(-8.2,-2.3),P(-9,-4.0)],AM,5)
d.rectangle((*P(-7.9,-2.7),*P(-6.8,-3.8)),outline=AM,width=3)
for z in (-8,7):d.ellipse((*P(z,3.8),*P(z+1.4,3.5)),outline=MUT,width=3)
# stern duct side symbol
d.ellipse((*P(11.5,2),*P(13.5,0)),outline=AM,width=4)
d.ellipse((*P(11.5,-.5),*P(13.5,-2.5)),outline=AM,width=4)
for a in range(0,360,60):
 x,y=P(12.5,1);r=.7*s;d.line((x,y,x+r*math.cos(math.radians(a)),y+r*math.sin(math.radians(a))),fill=MUT,width=2)
for z,t in [(-10.8,'ОБЩАЯ НОСОВАЯ'),(-2.7,'ЛАБОРАТОРИЯ'),(2.3,'ЖИЛОЙ'),(7.2,'ТЕХНИЧЕСКИЙ')]:txt(d,P(z,2.6),t,19)
for z in (-14,-12,-3,2,7,11,14):txt(d,(P(z,0)[0]-15,735),str(z),20,CY)
dim(d,(P(-14,0)[0],795),(P(14,0)[0],795),'28 м')
for x,y,t in [(75,170,'Нос / −Z'),(1690,170,'Корма / +Z'),(78,860,'Габарит: 28 × 10 × 9 м; врата 48 × 22'),(78,900,'Палуба y=0; 1 деление координат — 1 м'),(78,940,'Человек 1,8 м; люки 1,2 × 2,1 м'),(78,980,'Потолок 2,8 м; у краёв ниже')]:txt(d,(x,y),t,25)
for i,t in enumerate(['Голубой — прочный объём; белый — внешний кожух. Обзор: лист 04.', 'Под носом: мокрая ниша, сложенные инструменты и контейнер проб.', 'Каналы В — вне прочного объёма; Б — под палубой: лист 06.', 'Две койки показаны сбоку; ещё две — на противоположном борту.', 'Прочность, плавучесть, масса и глубина применения не рассчитаны.']):txt(d,(850,860+i*39),t,23,FG if i<4 else AM)
txt(d,(60,1090),'Схема компоновки, не инженерный проект. Изоляция помещений и оборудование — предложения, не новые механики.',22,MUT)
im.save(OUT/'02-v3-razrez.png')
# plan, full envelope at 43px/m top; enlarged bridge below 75 px/m
im,d=new('03 / ЧЕТЫРЕ ПОСТА · ПЛАН И ПУТЬ СОЛО','ART-085 / v3 · Размеры в метрах · Нос слева на общем плане, сверху на увеличении')
s=43;ox=850;oy=400
P=lambda z,x:(ox+z*s,oy+x*s)
outer=[(-14,0),(-12,-3.5),(-7,-5),(7,-5),(12,-3.5),(14,-1.5),(14,1.5),(12,3.5),(7,5),(-7,5),(-12,3.5),(-14,0)]
poly(d,[P(*p) for p in outer],FG,4)
for z1,z2,label in [(-12.5,-3,'НОСОВАЯ ЗОНА'),(-3,2,'ЛАБОРАТОРИЯ'),(2,7,'БЫТ'),(7,10.5,'ТЕХНИКА')]:

 if z1 < -10:
  poly(d,[P(-12.5,-1.2),P(-10.5,-3.3),P(z2,-3.3),P(z2,3.3),P(-10.5,3.3),P(-12.5,1.2),P(-12.5,-1.2)],CY,2)
 else:d.rectangle((*P(z1,-3.3),*P(z2,3.3)),outline=CY,width=2)
 txt(d,P(max(z1,-10.5)+.15,-2.9),label,17)
for z in (-3,2,7):poly(d,[P(z,-.6),P(z,.6)],AM,7)
# Auxiliary channels, x/z coordinates
for z in (-6,7.5):
 for x in (-4.1,4.1):
  px,py=P(z,x);d.ellipse((px-18,py-18,px+18,py+18),outline=AM,width=3);txt(d,(px-7,py-12),'В',17,AM)
for z in (-4,9.5):
 poly(d,[P(z,-4.8),P(z,4.8)],MUT,2);txt(d,P(z+.1,4),'Б',17,AM)
# all four posts scaled
for z,x,r,c in [(-11.4,0,.35,AM),(-7.7,-2.1,.35,AM),(-7.7,2.1,.35,AM),(-4,0,.35,AM),(-5.2,0,.65,CY)]:
 px,py=P(z,x);d.ellipse((px-r*s,py-r*s,px+r*s,py+r*s),outline=c,width=3)
poly(d,[P(9,0),P(-3,0),P(-3.8,-1.4),P(-8.8,-1.4),P(-10.8,0)],AM,3)
for z in (3.5,):
 for x in (-2.5,2.5):d.rectangle((*P(z,x-.5),*P(z+2,x+.5)),outline=MUT,width=2)
dim(d,(248,660),(1452,660),'28 м')
txt(d,(1505,220),'ГАБАРИТ / ПРЕДЛОЖЕНИЕ',24,AM)
for i,t in enumerate(['Длина 28; ширина 10; высота 9.', 'Внутренняя ширина до 6,6.', 'Обитаемая палуба одна.', 'По оси: нос → лаборатория', '→ быт → техническая корма.', 'Быт: 2 × 2 койки по бортам;', 'проход посредине остаётся.', 'Общая зона: 4 поста;', 'камера не заменяет окно.']):txt(d,(1505,270+34*i),t,21)
# enlarged forward compartment, 33px/m both axes, bow upwards
s=33;cx=460;cy=750
B=lambda x,z:(cx+x*s,cy+(z+12.5)*s)
for x in range(-3,4):d.line((B(x,-10.5),B(x,-3)),fill='#20343d',width=1)
for z in range(-12,-2):d.line((B(-3.3,z),B(3.3,z)),fill='#20343d',width=1)
poly(d,[B(-1.2,-12.5),B(-3.3,-10.5),B(-3.3,-3),B(3.3,-3),B(3.3,-10.5),B(1.2,-12.5),B(-1.2,-12.5)],CY,2)
# operators forward vectors: inward +45 / -45 degrees relative bow
for x,z,ang,label in [(0,-11.4,0,'1'),(-2.1,-7.7,45,'2'),(2.1,-7.7,-45,'3'),(0,-4,0,'4')]:
 px,py=B(x,z);a=math.radians(ang);dx,dz=math.sin(a),-math.cos(a)
 d.ellipse((px-8,py-8,px+8,py+8),fill=AM)
 txt(d,(px-26,py-10),label,20)
 # console centered .65m ahead, oriented perpendicular to working direction
 ccx,ccz=x+dx*.65,z+dz*.65;vx,vz=math.cos(a),math.sin(a)
 corners=[B(ccx+sx*.45*vx+sy*.18*dx,ccz+sx*.45*vz+sy*.18*dz) for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1),(-1,-1)]]
 poly(d,corners,FG,2)
 poly(d,[(px,py),B(x+dx*1.1,z+dz*1.1)],CY,3)
 if label in ('2','3'):
  for side in (-60,60):
   sa=a+math.radians(side);poly(d,[(px,py),B(x+math.sin(sa)*2,z-math.cos(sa)*2)],MUT,1)
px,py=B(0,-5.2);d.ellipse((px-.65*s,py-.65*s,px+.65*s,py+.65*s),outline=CY,width=3)
poly(d,[B(0,-3),B(-1.4,-4),B(-1.4,-9.2),B(0,-10.8)],AM,3)
poly(d,[B(0,-3),B(1.4,-4),B(1.4,-9.2),B(0,-10.8)],AM,3)
txt(d,(75,718),'НОС / −Z ↑ · 33 px/м',22,CY)
for i,t in enumerate(['1  Кресло z−11,40; глаз z−11,80; контроль — лист 04.', '2  Инженер: 45° внутрь от носа, консоль справа-впереди.', '3  Биолог: 45° внутрь от носа, консоль слева-впереди.', '4  Сонар: стол Ø1,3; рабочее место у кормовой кромки.', 'Стрелки — рабочий взгляд; тонкие линии — ±60°.', 'Пилот и встречный пост в секторе; сонар — с поворотом.', 'Янтарный — два обхода стола. Люки 1,2 м.', 'В/Б — вертикаль/боковая коррекция; сечение — лист 06.']):txt(d,(800,730+i*44),t,24,AM if i==7 else FG)
im.save(OUT/'03-v3-plan.png')
