from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
O=Path('art/ART-028-sbor-ekipazha'); W,H=2400,1080
BG=Image.open(Path(__file__).with_name('fon-mostika.jpg')).convert('RGB').resize((W,H),Image.Resampling.LANCZOS)
C={'bg':'#0B1C24','ink':'#D5E4E8','cyan':'#67DDEB','sub':'#9AD9E8','dim':'#6E909A','panel':'#102B37','line':'#32616D'}
ROLE=[('П','Пилот','#E39E38'),('С','Сонарщик','#45C2CC'),('И','Инженер','#D5E4E8'),('Б','Биолог','#73BD5C')]
def font(n,b=False):return ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed'+('-Bold' if b else '')+'.ttf',n)
class UI:
 def __init__(self):self.im=BG.copy(); self.d=ImageDraw.Draw(self.im)
 def text(self,x,y,t,n=34,col=None,b=False):self.d.text((x,y),t,font=font(n,b),fill=col or C['ink'])
 def box(self,r,fill=None,line=None,w=2):self.d.rounded_rectangle(r,radius=12,fill=fill or C['panel'],outline=line or C['line'],width=w)
 def center(self,r,t,n,col,b=False):
  f=font(n,b); bb=self.d.textbbox((0,0),t,font=f); self.d.text(((r[0]+r[2]-bb[2])/2,(r[1]+r[3]-(bb[3]-bb[1]))/2-bb[1]),t,font=f,fill=col)
 def button(self,r,t,primary=False,disabled=False):
  self.box(r, C['cyan'] if primary and not disabled else C['panel'],C['dim'] if disabled else C['cyan'],3)
  self.center(r,t,34,C['bg'] if primary and not disabled else C['dim'] if disabled else C['ink'],True)
 def header(self,sub='Забег создан · вы — хост'):
  self.text(220,65,'СБОР ЭКИПАЖА',58,b=True);self.text(222,145,sub,32,C['sub'])
  self.button((1360,76,1760,180),'Создать забег',disabled=True)
  self.button((1790,76,2190,180),'Подключиться',disabled=True)
  self.d.line((220,220,2190,220),fill=C['line'],width=2)
 def check(self,x,y,col):self.d.line([(x,y+10),(x+14,y+24),(x+42,y-8)],fill=col,width=6)
 def row(self,i,name,status,own=False,free=False,locked=False):
  y=300+i*130; r=(380,y,2020,y+112)
  self.box(r,C['bg'] if free else C['panel'],C['cyan'] if own else C['line'],3 if own else 2)
  letter,role,col=ROLE[i];self.d.ellipse((408,y+20,480,y+92),outline=col,width=3,fill=C['bg']);self.center((408,y+20,480,y+92),letter,39,col,True)
  self.text(510,y+15,role,34,b=True);self.text(510,y+58,'Свободно' if free else name,30,C['dim'] if free else C['sub'])
  if free:
   self.d.line((1030,y+56,1250,y+56),fill=C['dim'],width=2);self.button((1540,y+8,2008,y+104),'Выбрать роль')
  elif locked:
   self.text(1600,y+35,'Занято',32);self.d.rectangle((1535,y+41,1565,y+69),outline=C['ink'],width=3);self.d.arc((1540,y+27,1560,y+52),180,360,fill=C['ink'],width=3)
  elif status=='Готов':self.check(1540,y+50,C['cyan']);self.text(1610,y+35,'Готов',34,C['cyan'],True)
  else:self.d.ellipse((1542,y+40,1576,y+74),outline=C['ink'],width=3);self.text(1610,y+35,'Ждём',34,b=True)
 def footer(self,ready=False,client=False):
  if client:
   self.button((520,900,1100,1012),'Отменить готовность');self.text(1170,932,'Ждём начала от хоста',32,C['sub'])
  else:
   self.button((520,900,1100,1012),'Отменить готовность' if ready else 'Готов',primary=not ready)
   self.button((1140,900,1880,1012),'Начать погружение',primary=ready,disabled=not ready)
 def save(self,p):self.im.save(p,optimize=True)
def lobby(allready=False,client=False):
 u=UI();u.header('Забег Лены · подключено' if client else 'Забег «Игрок 1» · вы — хост')
 u.text(380,245,'3 из 4 мест · все подключённые выбирают роль',29,C['sub'])
 u.row(0,'Лена · хост' if client else 'Игрок 1 · вы · хост','Готов' if allready or client else 'Ждём',own=not client)
 u.row(1,'Игорь','Готов')
 u.row(2,'Игрок 3 · вы' if client else 'Игрок 3','Готов',own=client)
 u.row(3,'','',free=True)
 u.box((500,824,1900,885),C['bg'],C['bg'])
 u.text(520,835,'Все 3 игрока готовы · свободное место не мешает старту' if allready else 'Готовы 2 из 3 · подтвердите готовность',31,C['cyan'] if allready else C['ink'])
 u.footer(allready,client);return u
main=lobby();main.save(O/'sbor-ekipazha.png')
# Six full-resolution logical screens, reduced only for the contact sheet.
search=UI();search.header('Одна сеть Wi-Fi · выберите забег')
search.button((1360,76,1760,180),'Создать забег');search.button((1790,76,2190,180),'Подключиться',primary=True)
search.text(380,275,'Найдено 2 забега',42,b=True)
for y,name,count in [(375,'Забег Лены','2 / 4 · свободны И / Б'),(565,'Забег Игрока 4','3 / 4 · свободна С')]:
 search.box((380,y,2020,y+150));search.text(420,y+22,name,40,b=True);search.text(420,y+83,count,32,C['sub']);search.button((1580,y+23,1980,y+127),'Подключиться')
search.button((900,900,1500,1012),'Обновить список')
empty=UI();empty.header('Одна сеть Wi-Fi · поиск завершён');empty.button((1360,76,1760,180),'Создать забег');empty.button((1790,76,2190,180),'Подключиться',primary=True)
empty.text(790,370,'Никого нет',64,b=True);empty.text(620,485,'Подключитесь к одной сети Wi-Fi.',40,C['sub']);empty.text(620,550,'Один из вас должен создать забег.',40,C['sub']);empty.button((510,800,1170,912),'Создать забег',primary=True);empty.button((1210,800,1870,912),'Обновить список')
occupied=UI();occupied.header('Забег Лены · выберите свободную роль');occupied.row(0,'Лена · хост','',locked=True);occupied.row(1,'Игорь','Готов');occupied.row(2,'','',free=True);occupied.row(3,'','',free=True);occupied.text(520,850,'Пилот уже занят Леной. Выберите И или Б.',36,C['ink']);occupied.button((800,930,1600,1034),'Назад к списку')
lost=UI();lost.header('Забег Лены · соединение прервано');lost.box((480,300,1920,790),C['bg'],C['sub'],3);lost.text(700,360,'Связь потеряна',62,b=True);lost.text(650,475,'Проверьте Wi-Fi и телефон хоста.',38,C['sub']);lost.text(650,545,'Готовность будет сброшена.',38,C['sub']);lost.button((540,640,1160,752),'Повторить',primary=True);lost.button((1200,640,1860,752),'К списку забегов')
states=[('01 · Поиск: забеги найдены',search),('02 · В сети никого нет',empty),('03 · Роль уже занята',occupied),('04 · Все готовы: экран хоста',lobby(True)),('05 · Связь потеряна',lost),('06 · Гость готов: старт только у хоста',lobby(True,True))]
sheet=Image.new('RGB',(2400,2160),C['bg']);dr=ImageDraw.Draw(sheet);dr.text((50,25),'ART-028 · СОСТОЯНИЯ СБОРА ЭКИПАЖА',font=font(42,True),fill=C['ink'])
for i,(name,u) in enumerate(states):
 x=40+(i%2)*1200;y=120+(i//2)*670
 dr.text((x,y),name,font=font(28,True),fill=C['sub']);sheet.paste(u.im.resize((1120,504),Image.Resampling.LANCZOS),(x,y+55));dr.text((x,y+577),'Макет уменьшен. Размеры касания заданы для 2400 × 1080.',font=font(21),fill=C['dim'])
sheet.save(O/'sbor-ekipazha-sostoyaniya.png',optimize=True)
# Review-only phone-sized preview, not delivery.
main.im.resize((1000,450),Image.Resampling.LANCZOS).save('../crew-lobby-work/phone-preview.png')
for p in O.glob('*.png'):
 with Image.open(p) as im:print(p.name,im.size,p.stat().st_size);assert p.stat().st_size<3000000

