from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
im=Image.new('RGB',(2048,1152),'#0b1c24');d=ImageDraw.Draw(im)
font='C:/Windows/Fonts/arial.ttf'
def text(x,y,s,size=26,fill='#c3dce2'): d.text((x,y),s,font=ImageFont.truetype(font,size),fill=fill)
def line(points,fill='#67ddeb',width=3): d.line(points,fill=fill,width=width)
def dim(a,b,label,xy):
 line([a,b],'#97aeb6',2)
 for x,y in [a,b]:
  if a[1]==b[1]: line([(x,y-8),(x,y+8)],'#97aeb6',2)
  else: line([(x-8,y),(x+8,y)],'#97aeb6',2)
 text(*xy,label,24)
text(70,35,'ТЕРРАСА ВРАТ · ГАБАРИТЫ И ПРОХОД',44)
text(70,98,'Схема в метрах · размеры для будущей модели · художественные ракурсы не являются чертежом',25)
line([(1024,180),(1024,1000)],'#304b59',2)
text(70,170,'Вид вдоль прохода',32)
# Exact metric envelopes, 6 px/m
x0,y0,s=160,650,6
D=lambda x,y:(x0+x*s,y0-y*s)
d.rectangle([D(0,58),D(120,0)],fill='#253d49',outline='#64818d',width=3)
d.rectangle([D(30,36),D(90,0)],fill='#0d3039',outline='#67ddeb',width=4)
text(365,550,'СВОБОДНО',27,'#67ddeb')
text(375,512,'60 × 36 м',26,'#67ddeb')
# End-on ship bounding box at local y30
center=D(60,30)
d.rounded_rectangle((center[0]-33,center[1]-15,center[0]+33,center[1]+15),radius=12,fill='#b39a6a')
text(480,405,'11 × 5 м',23,'#d4b982')
dim(D(0,-5),D(120,-5),'120 м',(475,700))
dim(D(-7,0),D(-7,58),'58 м',(40,450))
text(160,235,'Габарит конструкции, включая верхушку',24)
text(90,765,'Корабль: 32 × 11 × 5 м',28,'#d4b982')
d.rounded_rectangle((160,825,352,855),radius=15,fill='#b39a6a')
dim((160,885),(352,885),'32 м',(225,903))
text(395,825,'Длина показана в том же масштабе',23)
text(90,970,'Пол террасы: глубина 65 м; верх арки: 7 м.',24)
text(90,1010,'Центр корабля: глубина 35 м, как в месте 07.',24)
# Plan, 4 px/m, north -Z top
text(1100,170,'План · север −Z сверху',32)
cx,cz,s=1530,350,4
P=lambda x,z:(cx+x*s,cz+z*s)
d.rectangle([P(-60,-11.5),P(60,11.5)],fill='#253d49',outline='#64818d',width=3)
d.rectangle([P(-30,-11.5),P(30,11.5)],fill='#0d3039',outline='#67ddeb',width=3)
dim(P(-60,-22),P(60,-22),'120 м',(1480,222))
dim(P(70,-11.5),P(70,11.5),'23 м',(1835,330))
# Clear turning pocket diameter100, center local z70
cc=P(0,70); r=50*s
d.ellipse((cc[0]-r,cc[1]-r,cc[0]+r,cc[1]+r),outline='#67ddeb',width=4)
text(1380,867,'Разворот: Ø 100 м',29,'#67ddeb')
# Ship32x11 at center, all rotations swept diameter33.84
rr=((32*32+11*11)**.5)/2*s
d.ellipse((cc[0]-rr,cc[1]-rr,cc[0]+rr,cc[1]+rr),outline='#9c916d',width=2)
d.rounded_rectangle((cc[0]-22,cc[1]-64,cc[0]+22,cc[1]+64),radius=18,fill='#b39a6a')
text(1640,590,'Корабль',24,'#d4b982')
text(1640,626,'32 × 11 м',23,'#d4b982')
line([P(0,20),P(0,11.5)],'#67ddeb',4)
text(1150,935,'Диаметр поворота габарита: 33,84 м.',24)
text(1150,975,'Запас до края кармана: 33,08 м.',24)
text(1150,1015,'Декор и кабели — за пределами прохода.',24)
text(70,1090,'Это геометрический запас. Коллизии, инерцию и камеру проверить при сборке уровня.',24,'#96aeb8')
im.save(Path(__file__).resolve().parents[1]/'05-prohod.png',optimize=True)

