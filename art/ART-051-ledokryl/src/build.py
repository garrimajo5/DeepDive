"""ART-051: original dimensioned construction drawings and labeled imagegen plates."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import math,json
R=Path(__file__).resolve().parents[1]
BG='#0B1C24'; FG='#D5E4E8'; SUB='#9AD9E8'; LINE='#32616D'; CYAN='#9FFCFF'
def f(n,b=False): return ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed'+('-Bold' if b else '')+'.ttf',n)
def txt(d,x,y,s,n=24,c=FG,b=False): d.text((x,y),s,font=f(n,b),fill=c)
def ln(d,p,c=LINE,w=2): d.line(p,fill=c,width=w)
def save(im,name):
 p=R/name
 if p.suffix=='.jpg': im.convert('RGB').save(p,quality=93,optimize=True)
 else:
  im.save(p,optimize=True)
  if p.stat().st_size>2_000_000: im.quantize(colors=256).save(p,optimize=True)
 assert p.stat().st_size<=2_000_000,(name,p.stat().st_size)

# Half-plan contour, metres. Mirrored exactly; tail begins at9m, ends18m.
HALF=[(0,0),(.65,.35),(1.1,1.25),(1.9,2.45),(3.8,3.8),(5.6,4.8),(6.7,5.8),(7,6.35),(6.85,6.75),(6.1,6.5),(5.3,6.85),(4.5,6.65),(3.6,7.35),(2.4,7.9),(1.1,8.5),(.16,9)]
DOTS=[(3.3,3.55),(4.05,4.02),(4.8,4.42),(5.55,4.9),(6.2,5.45),(6.65,5.95),(6.83,6.43)]
def plan(d,cx,top,s,vent=False,sil=False):
 conv=lambda p:(cx+p[0]*s,top+p[1]*s)
 pts=HALF+[(-x,y) for x,y in reversed(HALF)]
 color='#000000' if sil else '#A8CFE0' if vent else '#294651'
 d.polygon([conv(p) for p in pts],fill=color)
 if not sil:
  d.line([conv(p) for p in pts+[pts[0]]],fill='#607F89',width=2)
  for side in [-1,1]:
   for a in [2.5,3.8,5.2,6.5]:
    d.line([conv((side*.45,3.5)),conv((side*a,6.4))],fill='#7DA8B9' if vent else '#395867',width=2)
  d.ellipse((cx-.55*s,top+1.0*s,cx+.55*s,top+7.8*s),fill='#B5D5E0' if vent else '#365360')
  if vent:
   d.arc((cx-.65*s,top+1.1*s,cx+.65*s,top+2.0*s),0,180,fill='#193E4D',width=4)
   d.ellipse((cx-.5*s,top+2.6*s,cx+.5*s,top+4.0*s),fill='#91B7C7',outline='#607F89',width=2)
   for a in [-.3,-.15,0,.15,.3]: ln(d,[conv((a,2.7)),conv((a,3.9))],'#688A9B',1)
  else:
   for x,y in [(-.8,2.5),(.9,4.1),(-.55,6.1)]:
    d.ellipse((cx+(x-.09)*s,top+y*s,cx+(x+.09)*s,top+(y+.35)*s),fill='#82939A')
  for side in [-1,1]:
   for x,y in DOTS:
    px,py=conv((side*x,y)); d.ellipse((px-2,py-2,px+2,py+2),fill=CYAN)
  for side in [-1,1]:
   ex,ey=conv((side*.8,1.1)); d.ellipse((ex-3,ey-4,ex+3,ey+4),fill=BG)
 tail=[conv((.13,9)),conv((.09,12)),conv((.04,15)),conv((0,18)),conv((-.04,15)),conv((-.09,12)),conv((-.13,9))]
 d.polygon(tail,fill='#000000' if sil else '#607F89')
def dim(d,x0,y0,x1,y1,label):
 ln(d,[(x0,y0),(x1,y1)],SUB,2)
 if y0==y1:
  for x in [x0,x1]: ln(d,[(x,y0-7),(x,y0+7)],SUB,2)
  txt(d,(x0+x1)/2-50,y0+6,label,23,SUB)
 else:
  for y in [y0,y1]: ln(d,[(x0-6,y),(x0+6,y)],SUB,2)
  txt(d,x0+10,(y0+y1)/2-14,label,23,SUB)
def front(d,cx,y,s,phase=None):
 points=[]
 for i in range(81):
  x=-7+14*i/80; ax=abs(x)
  move=0 if phase is None else math.sin(phase-.32*ax)*(ax/7)**1.4*1.8
  hump=.5*max(0,1-ax/2.2)
  points.append((cx+x*s,y-(hump+move)*s))
 lower=[(x,y0+max(2,9*(1-abs(x-cx)/(7*s)))) for x,y0 in reversed(points)]
 d.polygon(points+lower,fill='#607F89'); ln(d,points,'#A8CFE0',2)
 d.ellipse((cx-.6*s,y-2,cx+.6*s,y+.32*s),fill='#A8CFE0')
def ship(d,x,y,s):
 p=[(0,2),(2,1),(26,1),(29,1.7),(32,1.7),(32,4),(29,4),(27,5),(3,5),(0,4)]
 d.polygon([(x+a*s,y+b*s) for a,b in p],fill='#050D11')
 d.rectangle((x+8*s,y+.3*s,x+11*s,y+s),fill='#050D11')
 d.rectangle((x+29*s,y,x+30*s,y+2*s),fill='#050D11')
im=Image.new('RGB',(2048,1152),BG); d=ImageDraw.Draw(im)
txt(d,35,20,'ЛЕДОКРЫЛ · размерный лист',40,FG,True)
txt(d,36,71,'ART-051 · геометрия для модели · силуэт и числа здесь приоритетнее иллюстраций',24,SUB)
ln(d,[(32,111),(2016,111)])
for cx,vent,title in [(305,False,'Сверху'),(865,True,'Снизу')]:
 txt(d,cx-70,125,title,28,FG,True)
 plan(d,cx,190,35,vent)
 dim(d,cx-245,166,cx+245,166,'14 м')
dim(d,33,190,33,505,'9 м')
dim(d,33,505,33,820,'9 м')
txt(d,153,832,'3 присоски по 0,35 м',22,SUB)
txt(d,720,832,'14 слабых точек · по 7',22,SUB)
ln(d,[(1140,125),(1140,870)])
txt(d,1190,130,'Сбоку · тело плоское',27,FG,True)
x,y,s=1205,245,42
p=[(0,0),(.8,-.25),(2.8,-.5),(6,-.25),(9,0),(18,.05),(9,.15),(6,.15),(3,.42),(1,.2)]
d.polygon([(x+a*s,y+b*s) for a,b in p],fill='#607F89')
d.ellipse((x+1.3*s,y,x+2.8*s,y+.38*s),fill='#A8CFE0')
dim(d,x,y+58,x+9*s,y+58,'Тело 9 м'); dim(d,x+9*s,y+58,x+18*s,y+58,'Хвост 9 м')
txt(d,1190,352,'Спереди · тонкий край, без «лица»',27,FG,True)
front(d,1585,448,50)
dim(d,1235,495,1935,495,'14 м')
txt(d,1190,560,'Три фазы медленного взмаха',27,FG,True)
for cx,phase,label in [(1280,3.81,'Вверх'),(1555,2.24,'Переход'),(1830,.67,'Вниз')]:
 front(d,cx,706,17,phase); txt(d,cx-47,760,label,23,SUB)
txt(d,1190,810,'Гнётся крыло, центральный корпус устойчив.',23,SUB)
ln(d,[(32,883),(2016,883)])
txt(d,36,899,'Единый масштаб · 20 пикселей на метр',26,FG,True)
ship(d,45,967,20); dim(d,45,1090,685,1090,'32 м')
txt(d,280,940,'Ковчег-7',22,SUB)
# Side silhouette 18m overall, exact same20px/m as ship.
p=[(0,0),(1,-.3),(3,-.5),(6,-.25),(9,0),(18,.05),(9,.15),(3,.42),(1,.2)]
d.polygon([(790+a*20,1016+b*20) for a,b in p],fill='#000000')
dim(d,790,1090,1150,1090,'18 м')
txt(d,800,967,'Ледокрыл · тело и хвост',22,SUB)
d.ellipse((1241,1004,1251,1014),fill='#000000'); d.rectangle((1241,1014,1251,1032),fill='#000000'); ln(d,[(1245,1030),(1239,1040)],'#000000',4); ln(d,[(1247,1030),(1254,1040)],'#000000',4)
txt(d,1280,1006,'Человек 1,8 м',22,SUB)
txt(d,1460,960,'Спина: #294651',23,SUB); txt(d,1460,996,'Брюхо: #A8CFE0',23,SUB)
txt(d,1460,1032,'Огни: #9FFCFF',23,SUB); txt(d,1460,1068,'Эмиссия только в 14 точках',23,SUB)
save(im,'02-razmernyy-list.png')

# Imagegen render views are material/anatomy illustrations, explicitly not metrology.
im=Image.new('RGB',(2048,1152),BG); d=ImageDraw.Draw(im)
txt(d,35,17,'ЛЕДОКРЫЛ · форма и анатомия',38,FG,True)
src=Image.open(R/'source/formy.jpg').convert('RGB')
im.paste(src.resize((1672,941),Image.Resampling.LANCZOS),(20,110))
d=ImageDraw.Draw(im)
txt(d,150,83,'Спина · 3 присоски',23,SUB);txt(d,625,83,'Брюхо · рот и резонатор',23,SUB)
txt(d,1140,252,'Сбоку',24,SUB); txt(d,1210,566,'Спереди',24,SUB)
txt(d,1695,135,'Рот и резонатор',25,FG,True)
im.paste(src.crop((655,100,810,315)).resize((300,416),Image.Resampling.LANCZOS),(1700,185))
d=ImageDraw.Draw(im)
txt(d,1695,630,'Щель со скребком.',22,SUB)
txt(d,1695,662,'Мягкие складки мешка.',22,SUB)
txt(d,1695,694,'Оба не светятся.',22,SUB)
txt(d,1695,760,'Кормление',25,FG,True)
txt(d,1695,800,'У льда — поворот',22,SUB);txt(d,1695,830,'брюхом к потолку.',22,SUB)
txt(d,1695,900,'Для модели',25,FG,True)
txt(d,1695,940,'Размеры и контур —',22,SUB);txt(d,1695,970,'по размерному листу.',22,SUB)
txt(d,35,1080,'Иллюстрации материала и анатомии · не обмерный чертёж · пропорции модели: лист 02',25,SUB)
save(im,'03-forma-i-anatomiya.png')
print('Built dimensioned and anatomical sheets.')
