from PIL import Image,ImageDraw,ImageOps
from pathlib import Path
import math
import ui_base as u
O=Path(__file__).resolve().parents[1]
NAMES=['Штурвал','Энергия','Сканер','Сонар','Разряд','Шлюз','Вентиль','Сброс','Сварка']
def glyph(i,color='#D5E4E8'):
 im=Image.new('RGBA',(128,128));d=ImageDraw.Draw(im);c=color;lw=8
 if i in (0,6):
  d.ellipse((28,28,100,100),outline=c,width=lw)
  for a in ([0,60,120,180,240,300] if i==0 else [45,135,225,315]):
   rad=math.radians(a);d.line((64,64,64+48*math.cos(rad),64+48*math.sin(rad)),fill=c,width=lw)
  d.ellipse((54,54,74,74),fill=c)
 elif i==1:
  for x,y in [(32,45),(64,80),(96,58)]:d.line((x,22,x,106),fill=c,width=6);d.rectangle((x-10,y-8,x+10,y+8),fill=c)
 elif i==2:
  d.polygon([(64,22),(100,43),(100,85),(64,106),(28,85),(28,43)],outline=c,width=lw);d.ellipse((49,49,79,79),outline=c,width=6)
 elif i==3:
  for r in (42,25):d.ellipse((64-r,64-r,64+r,64+r),outline=c,width=6)
  d.line((64,64,91,30),fill=c,width=lw);d.ellipse((58,58,70,70),fill=c)
 elif i==4:d.polygon([(70,16),(28,72),(58,72),(48,112),(103,51),(70,51)],fill=c)
 elif i==5:
  d.rectangle((24,22,79,106),outline=c,width=lw);d.line((52,64,108,64),fill=c,width=lw);d.line((90,44,110,64,90,84),fill=c,width=lw)
 elif i==7:
  d.rounded_rectangle((24,24,104,104),8,outline=c,width=lw);d.arc((42,42,86,86),-45,225,fill=c,width=7);d.line((64,34,64,60),fill=c,width=7)
 else:
  d.line((30,100,65,65,82,65,95,50),fill=c,width=12)
  for ex,ey in [(80,23),(110,27),(116,56)]:d.line((98,40,ex,ey),fill=c,width=5)
 return im
ATLAS=Image.new('RGBA',(512,384))
for i in range(9):ATLAS.alpha_composite(glyph(i),((i%4)*128,(i//4)*128))
def icon(im,i,x,y,size=48,color='#D5E4E8'):
 g=glyph(i,color).resize((size,size),Image.Resampling.LANCZOS);im.paste(g,(round(x-size/2),round(y-size/2)),g)
def screen(state='coop',w=2400):
 im=u.background(w);im=Image.blend(im,Image.new('RGB',im.size,u.C['bg']),.94);d=ImageDraw.Draw(im)
 s=min(50,(w-720)/30);left=(w-30*s)/2;cy=520
 def pos(x,z):return (left+(z+6)*s,cy-x*s)
 u.text(im,(360,58),'Схема корабля',58);u.button(im,w-660,48,300,112,'Назад')
 u.text(im,(360,180),'← Нос · вид сверху',29,'sub');u.text(im,(w-360,180),'Корма →',29,'sub','rt')
 rooms=[(-6,2,5,'Мостик'),(2,8,1.1,'Коридор'),(8,14,4,'Лаборатория'),(14,19.5,3,'Машинное'),(19.5,24,2.5,'Трюм')]
 for j,(z0,z1,hw,name) in enumerate(rooms):
  a,b=pos(hw,z0),pos(-hw,z1);d.rectangle((*a,*b),fill=u.C['panel'],outline=u.C['amber'] if state=='alarm' and j==4 else u.C['line'],width=5 if state=='alarm' and j==4 else 3)
  u.text(im,((a[0]+b[0])/2,221),name,30,'amber' if state=='alarm' and j==4 else 'text','mt')
 for z in (2,8,14,19.5):
  px,py=pos(0,z);h=.7*s
  d.line((px,py-h,px,py+h),fill=u.C['bg'],width=10)
  if state=='closed' and z==14:
   d.line((px,py-h,px,py+h),fill=u.C['text'],width=9);d.line((px-10,py-h,px+10,py-h),fill=u.C['text'],width=5);d.line((px-10,py+h,px+10,py+h),fill=u.C['text'],width=5)
   u.text(im,(px,775),'Люк закрыт',30,'text','mt');d.line((px,py+h+15,px,765),fill=u.C['sub'],width=2)
  else:
   d.line((px-12,py-h,px+12,py-h),fill=u.C['cyan'],width=4);d.line((px-12,py+h,px+12,py+h),fill=u.C['cyan'],width=4)
 posts=[(0,-4.2),(-3.9,-2),(3.85,-2),(0,-1.2),(-3.9,-.5),(1.5,22),(-2.2,17.2),(2.2,17.2)]
 for i,p in enumerate(posts):icon(im,i,*pos(*p))
 # Passable player sample positions, independent of post coordinates.
 for role,p in ([('С',(0,5))] if state=='solo' else [('П',(-1.8,-3)),('С',(0,5)),('Б',(1.5,11)),('И',(0,15.5))]):
  x,y=pos(*p);r=25;d.ellipse((x-r,y-r,x+r,y+r),fill=u.C['cyan'] if role=='С' else u.C['bg'],outline=u.C['text'],width=3);u.text(im,(x,y),role,32,'bg' if role=='С' else 'text','mm')
 x,y=pos(0,5);d.line((x,y+30,x,608),fill=u.C['cyan'],width=3);u.text(im,(x,620),'Вы здесь',34,'cyan','mt')
 if state=='alarm':
  x,y=pos(-1.5,20.5);d.rectangle((x-32,y-32,x+32,y+32),outline=u.C['amber'],width=4);icon(im,8,x,y,color=u.C['amber'])
  u.text(im,(w-420,710),'Пробоина',34,'amber','rt');u.text(im,(w-420,755),'Трюм · сварка',28,'amber','rt');d.line((x,y+36,x,700,w-420,700),fill=u.C['amber'],width=2)
 for i in range(8):
  col=i%4;row=i//4;x=360+col*((w-720)/4);y=870+row*92;icon(im,i,x+24,y);u.text(im,(x+64,y),NAMES[i],29,'text','lm')
 # Scale reference exactly 5 m long.
 x=left;y=811;d.line((x,y,x+5*s,y),fill=u.C['sub'],width=3)
 for xx in (x,x+5*s):d.line((xx,y-6,xx,y+6),fill=u.C['sub'],width=3)
 u.text(im,(x+2.5*s,y-12),'5 м',24,'sub','mb')
 return im

def pause():
 im=u.background();im=Image.blend(im,Image.new('RGB',im.size,u.C['bg']),.8);u.text(im,(1200,100),'Меню забега',58,anchor='mt')
 for i,t in enumerate(['Продолжить','Схема корабля','Настройки','Покинуть экипаж']):u.button(im,820,260+i*152,760,112,t,i==1)
 return im

def hint():
 im=u.background();u.rect(im,(520,32,1880,270),line='cyan');u.text(im,(560,60),'Первый забег · найдите пост',30,'sub');u.text(im,(560,118),'Подойдите к пульту энергии',40);u.button(im,1480,150,360,112,'Схема')
 return im

def main():
 screen().save(O/'shema-korablya.png',optimize=True);ATLAS.save(O/'shema-znachki.png',optimize=True)
 states=[('01  Соло — только ваша отметка',screen('solo')),('02  Кооп — четверо',screen()),('03  Пробоина в трюме — пример события',screen('alarm')),('04  Закрытый люк',screen('closed')),('05  Вход из меню забега',pause()),('06  Вход из подсказки',hint()),('07  16:9 — точный план, значки 48 px',screen('coop',1920))]
 sheet=Image.new('RGB',(2400,2650),u.C['bg']);u.text(sheet,(60,40),'ART-042 / Схема корабля',54)
 for i,(name,im) in enumerate(states):
  x=60+(i%2)*1180;y=145+(i//2)*620;u.text(sheet,(x,y),name,30,'sub');t=ImageOps.contain(im,(1100,495));sheet.paste(t,(x,y+55))
 u.text(sheet,(1240,2070),'Атлас: 4 × 3 ячейки по 128 px',32)
 for i in range(9):icon(sheet,i,1280+(i%3)*290,2190+(i//3)*110);u.text(sheet,(1320+(i%3)*290,2190+(i//3)*110),NAMES[i],24,anchor='lm')
 sheet.quantize(colors=240).save(O/'shema-sostoyaniya.png',optimize=True)
 for p in O.glob('*.png'):print(p.name,p.stat().st_size);assert p.stat().st_size<2_000_000
if __name__=='__main__':main()
