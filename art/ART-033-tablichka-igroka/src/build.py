from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
O=Path('art/ART-033-tablichka-igroka');B=O/'src/fon.jpg'
if not B.exists():Image.open('C:/Users/FEDYA/.codex/generated_images/01a150d4-51bb-7de2-a546-c950a2e37207/exec-61a82421-2296-4224-a0a2-b6b706aadd8e.png').convert('RGB').save(B,quality=95)
BG='#0B1C24';PANEL='#102B37';INK='#D5E4E8';CYAN='#67DDEB';SUB='#9AD9E8';DIM='#78949D'
def font(n,b=False):return ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed'+('-Bold' if b else '')+'.ttf',n)
def text(d,xy,t,n=30,c=INK,b=False):d.text(xy,t,font=font(n,b),fill=c)
def center(d,box,t,n,c,b=True):
 f=font(n,b);a=d.textbbox((0,0),t,font=f);d.text(((box[0]+box[2]-a[2])/2,(box[1]+box[3]-(a[3]-a[1]))/2-a[1]),t,font=f,fill=c)
def plate(im,x,y,h,name='Игрок 2',role='И',color=INK,state='normal',w=None):
 d=ImageDraw.Draw(im);w=w or h*5;r=(x,y,x+w,y+h);line=CYAN if state=='active' else DIM if state=='lost' else SUB
 d.rounded_rectangle(r,radius=max(3,h//9),fill=BG,outline=line,width=max(1,h//32))
 pad=h*.14;diam=h*.70; circ=(x+pad,y+pad,x+pad+diam,y+pad+diam)
 d.ellipse(circ,outline=DIM if state=='lost' else color,width=max(1,h//32));center(d,circ,role,int(h*.49),DIM if state=='lost' else color)
 fs=int(h*(.33 if state=='lost' else .43));ty=y+h*(.10 if state=='lost' else .24)
 text(d,(x+h,ty),name,fs,DIM if state=='lost' else INK,True)
 if state=='lost':text(d,(x+h,y+h*.55),'Нет связи',int(h*.24),SUB)
 if state=='active':
  for k,f in enumerate([.25,.55,.4]):
   xx=x+w-h*.7+k*h*.14;d.line((xx,y+h*(.5-f/2),xx,y+h*(.5+f/2)),fill=CYAN,width=max(2,h//18))
 return r
main=Image.open(B).resize((2400,1080),Image.Resampling.LANCZOS).quantize(colors=256).convert('RGB')
plate(main,280,38,96,role='И',w=470)
plate(main,1630,292,72,name='Марина',role='Б',color='#73BD5C',w=360)
d=ImageDraw.Draw(main)
# Captions are editorial, outside the in-game nameplates.
d.rounded_rectangle((800,20,1550,98),radius=10,fill=BG);text(d,(825,36),'ART-033 · Таблички других игроков',32,SUB,True)
d.rounded_rectangle((55,980,830,1050),radius=10,fill=BG);text(d,(80,997),'Игрок 2 · 2 м от камеры',30)
d.rounded_rectangle((1550,980,2315,1050),radius=10,fill=BG);text(d,(1575,997),'Марина · 6 м от камеры',30)
main.save(O/'tablichka-igroka.png',optimize=True)
S=Image.new('RGB',(2400,1350),BG);d=ImageDraw.Draw(S)
text(d,(60,25),'ART-033 · СОСТОЯНИЯ ТАБЛИЧЕК',46,INK,True)
for x,label,st in [(60,'Обычная', 'normal'),(840,'Говорит / нажимает', 'active'),(1620,'Связь потеряна','lost')]:
 text(d,(x,115),label,33,SUB,True);plate(S,x,175,96,name='Марина',role='Б',color='#73BD5C',state=st,w=600)
text(d,(60,300),'Роль + имя. Без шкал здоровья и значков мест.',28)
text(d,(840,300),'Только мягкий контур и три штриха.',28)
text(d,(1620,300),'Текст состояния, без красного.',28)
d.line((60,360,2340,360),fill='#32616D',width=2)
text(d,(60,395),'Пост занят другим игроком',34,SUB,True)
def occupied(x,y,title,name,role,color):
 d.rounded_rectangle((x,y,x+1040,y+220),radius=14,fill=PANEL,outline='#32616D',width=2)
 text(d,(x+25,y+20),title,28,SUB)
 d.rectangle((x+30,y+103,x+65,y+137),outline=INK,width=3);d.arc((x+35,y+84,x+60,y+120),180,360,fill=INK,width=3)
 text(d,(x+95,y+97),'Занято',40,INK,True)
 plate(S,x+330,y+77,96,name=name,role=role,color=color,w=660)
occupied(60,455,'Штурвал','Марина','П','#E39E38')
occupied(1260,455,'Пульт энергии','Игрок 2','И',INK)
text(d,(60,705),'Метка над рабочей поверхностью; свой пост не помечается «занято».',29)
d.line((60,765,2340,765),fill='#32616D',width=2)
text(d,(60,800),'Натуральный размер: 24 / 48 / 96 px',34,SUB,True)
for x,h in [(70,24),(700,48),(1360,96)]:
 text(d,(x,865),str(h)+' px',30,INK,True);plate(S,x,925,h,name='Александрина',role='С',color='#45C2CC',w=h*7)
text(d,(70,1050),'24 px: только дальняя подсказка',27)
text(d,(700,1050),'48 px: минимум для имени',27)
text(d,(1360,1050),'96 px: близко / акцент',27)
text(d,(60,1140),'Для 6 м: 72 px при экране 1080 px по высоте. Имя до 12 букв.',31,INK,True)
text(d,(60,1190),'П / С / И / Б + имя различимы без цвета. Инженер нейтральный.',29,SUB)
text(d,(60,1240),'Масштаб листа в просмотрщике меняется; образцы заданы в пикселях исходного PNG.',25,DIM)
S.save(O/'tablichka-sostoyaniya.png',optimize=True)
main.resize((1200,540),Image.Resampling.LANCZOS).save('../nameplate-work/phone.png')
for p in O.glob('*.png'):
 print(p.name,Image.open(p).size,p.stat().st_size);assert p.stat().st_size<3000000

