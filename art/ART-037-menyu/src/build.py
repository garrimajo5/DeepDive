from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import sys
O=Path(__file__).resolve().parents[1];ROOT=O.parents[1];D=ROOT/'docs/concept-art';FONT=sys.argv[1];F=lambda n:ImageFont.truetype(FONT,n)
C={'bg':'#0B1C24','panel':'#102B37','cyan':'#67DDEB','second':'#9AD9E8','text':'#D5E4E8','line':'#32616D','off':'#6E909A'}
def bg(pause=False):
 im=ImageOps.fit(Image.open(D/('mostik-vid-ot-vhoda.jpg' if pause else 'zastavka-fon.jpg')).convert('RGBA'),(2400,1080),method=Image.Resampling.LANCZOS)
 return Image.alpha_composite(im,Image.new('RGBA',im.size,(11,28,36,190 if pause else 35))).convert('RGB')
def text(im,xy,s,n=40,col='text',anchor='lt'):ImageDraw.Draw(im).text(xy,s,font=F(n),fill=C.get(col,col),anchor=anchor)
def button(im,rect,label,kind='normal'):
 x,y,w,h=rect;d=ImageDraw.Draw(im);fill=C['cyan'] if kind=='primary' else ('#32616D' if kind=='pressed' else C['panel']);outline=C['off'] if kind=='disabled' else C['cyan'] if kind in ['primary','pressed'] else C['line'];d.rounded_rectangle((x,y,x+w,y+h),radius=12,fill=fill,outline=outline,width=4 if kind=='pressed' else 2);text(im,(x+w/2,y+h/2),label,38,'bg' if kind=='primary' else 'off' if kind=='disabled' else 'text','mm')
def menu(states=False):
 im=bg();text(im,(360,230),'Погружение',104)
 for i,t in enumerate(['Погрузиться','Экипаж','Настройки']):button(im,(360,420+i*144,680,112),t,(['pressed','disabled','normal'] if states else ['primary','normal','normal'])[i])
 text(im,(1200,1000),'Версия 0.1',26,'second','mt');return im
def pause(role='solo'):
 im=bg(True);text(im,(1200,120),'Меню забега' if role!='solo' else 'Пауза',64,anchor='mt')
 if role!='solo':text(im,(1200,217),'Вы — гость · забег продолжается' if role=='guest' else 'Вы — хост · забег продолжается',32,'second','mt')
 labels=['Продолжить','Настройки','Покинуть экипаж'] if role=='guest' else ['Продолжить','Новый забег','Настройки','Выйти в меню']
 for i,t in enumerate(labels):button(im,(820,310+i*142,760,112),t,'primary' if i==0 else 'normal')
 return im
def settings():
 im=bg(True);text(im,(560,100),'Настройки',64);button(im,(1540,80,300,104),'Назад')
 for y,label,value,k in [(270,'Громкость','70 %',.7),(470,'Чувствительность свайпа','1,0×',.5)]:
  text(im,(560,y),label,40);text(im,(1840,y),value,38,'second','rt');d=ImageDraw.Draw(im);yy=y+90;d.rounded_rectangle((580,yy,1820,yy+10),radius=5,fill=C['line']);d.rounded_rectangle((580,yy,580+1240*k,yy+10),radius=5,fill=C['cyan']);x=580+1240*k;d.ellipse((x-23,yy-18,x+23,yy+28),fill=C['text'])
 text(im,(560,690),'Камера с борта в начале забега',38);button(im,(1580,655,260,112),'Вкл','primary');button(im,(560,842,1280,112),'Сбросить сохранение');return im
def confirm(base,title,lines):
 im=Image.alpha_composite(base.convert('RGBA'),Image.new('RGBA',(2400,1080),(11,28,36,190))).convert('RGB');d=ImageDraw.Draw(im);d.rounded_rectangle((590,300,1810,790),radius=16,fill=C['panel'],outline=C['line'],width=3);text(im,(1200,355),title,48,anchor='mt')
 for i,line in enumerate(lines):text(im,(1200,455+i*57),line,34,anchor='mt')
 button(im,(780,640,380,112),'Да');button(im,(1240,640,380,112),'Нет','primary');return im
images={'menyu.png':menu(),'menyu-pauza.png':pause(),'menyu-nastrojki.png':settings()}
for name,im in images.items():im.save(O/name,optimize=True)
examples=[('Нажатая / неактивная',menu(True)),('Новый забег',confirm(pause(),'Начать новый забег?',['Текущий забег будет потерян.'])),('Выход в меню',confirm(pause(),'Выйти в меню?',['Забег будет потерян. Выйти?'])),('Сброс сохранения',confirm(settings(),'Сбросить сохранение?',['Сохранение будет удалено.','Отменить это действие нельзя.'])),('Меню гостя',pause('guest')),('Гость: выход',confirm(pause('guest'),'Покинуть экипаж?',['Вы выйдете из текущего забега.'])),('Меню хоста',pause('host')),('Хост: завершение',confirm(pause('host'),'Выйти в меню?',['Забег закончится у всех игроков.','Завершить забег экипажа?']))]
sheet=Image.new('RGB',(2400,2480),C['bg']);text(sheet,(50,25),'АРТ-037 · Состояния меню',44)
for i,(title,im) in enumerate(examples):
 x=50+(i%2)*1180;y=130+(i//2)*580;text(sheet,(x,y-42),title,28,'second');sheet.paste(im.resize((1120,504),Image.Resampling.LANCZOS),(x,y))
sheet.quantize(colors=256,method=Image.Quantize.MEDIANCUT).save(O/'menyu-sostoyaniya.png',optimize=True)
if len(sys.argv)>2:
 R=Path(sys.argv[2]);
 for name,im in images.items():im.crop((240,0,2160,1080)).resize((960,540),Image.Resampling.LANCZOS).save(R/name)
print([(p.name,p.stat().st_size) for p in O.glob('*.png')])
