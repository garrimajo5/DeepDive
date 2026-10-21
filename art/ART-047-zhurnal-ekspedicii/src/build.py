from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
P=Path(__file__).resolve().parents[1];D=P.parents[1]/'docs/concept-art'
F='C:/Users/FEDYA/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/share/fonts/DejaVuSans.ttf'
def txt(im,xy,s,n=34,c='#D5E4E8',a=None):ImageDraw.Draw(im).text(xy,s,font=ImageFont.truetype(F,n),fill=c,anchor=a)
def box(im,b,fill='#102B37',stroke='#32616D',r=12):ImageDraw.Draw(im).rounded_rectangle(b,radius=r,fill=fill,outline=stroke,width=2)
def button(im,b,s):box(im,b);txt(im,((b[0]+b[2])/2,(b[1]+b[3])/2),s,36,a='mm')
def icon(im,name,b):
 a=Image.open(D/name).convert('RGBA');a.thumbnail((b[2],b[3]),Image.Resampling.LANCZOS);im.paste(a,(b[0]+(b[2]-a.width)//2,b[1]+(b[3]-a.height)//2),a)
def base(w=2400):
 im=ImageOps.fit(Image.open(D/'mostik-vid-ot-vhoda.jpg').convert('RGB').crop((0,0,1600,820)),(w,1080));im=Image.blend(im,Image.new('RGB',im.size,'#0B1C24'),.9);return im
fish=Image.open(D/'svetlyak-ognevka-vidy.png').crop((95,208,815,418)).convert('RGB')
def page(w=2400,empty=False,new=False):
 im=base(w);L=(w-1680)//2;R=L+780
 txt(im,(L,65),'Журнал экспедиции',56);button(im,(L+1380,52,L+1680,164),'Назад')
 if empty:
  txt(im,(w//2,510),'Начните погружение — и журнал оживёт.',42,a='mm');return im
 txt(im,(L,209),'Подлёдный сад',38);txt(im,(L+730,220),'−Z ↑',28,a='rt')
 box(im,(L,270,L+730,840))
 d=ImageDraw.Draw(im);cx=L+365;cy=560
 for i in range(-2,3):
  d.line((cx+i*125,290,cx+i*125,810),fill='#20434C',width=1);d.line((L+30,cy+i*125,L+700,cy+i*125),fill='#20434C',width=1)
 places=[(40,-50,'kamennyy-tsvetok',True),(-126,45,'chernyy-kurilshchik',False),(162,-36,'rakovina-drevnih',False),(-30,-148,'kosti-leviafana',True),(-170,-70,'svetovoy-kolodets',True),(215,90,'kray-otmeli',False)]
 for x,z,name,seen in places:
  u=int(cx+x*1.25);v=int(cy+z*1.25)
  box(im,(u-56,v-56,u+56,v+56),'#173C48' if seen else '#102B37','#67DDEB' if seen else '#32616D')
  icon(im,'ikonka-'+name+'.png',(u-40,v-42,80,80))
  if seen:txt(im,(u+30,v+24),'✓',28,'#D5E4E8')
 txt(im,(L+24,868),'✓ Посещено 3 из 6',32);txt(im,(L+24,921),'Дальше: Чёрный курильщик',32,'#9AD9E8');txt(im,(L+24,971),'Маршрут выбирайте у голостола',27,'#9AD9E8')
 for i,s in enumerate(['Видов изучено 7 из 100','Образцов в трюме 12 из 24','Забегов 5','Глубже всего 340 м']):
  y=215+67*i
  if i<2:icon(im,['itog-vidy.png','itog-obrazcy.png'][i],(R,y,48,48))
  txt(im,(R+64,y+4),s,36)
 txt(im,(R,501),'Виды · 1–6 из 100',30,'#9AD9E8')
 for i in range(6):
  x=R+(i%3)*300;y=550+(i//3)*180
  box(im,(x,y,x+280,y+160),stroke='#67DDEB' if i==0 else '#32616D')
  if i==0:
   f=ImageOps.contain(fish,(240,86));im.paste(f,(x+(280-f.width)//2,y+14));txt(im,(x+140,y+135),'Светляк',29,a='mm')
   if new:box(im,(x+134,y+3,x+273,y+42),'#67DDEB','#67DDEB',7);txt(im,(x+204,y+22),'новое',25,'#0B1C24','mm')
  else:txt(im,(x+140,y+61),'?',54,'#6E909A','mm');txt(im,(x+140,y+131),'Не изучен',27,'#9AD9E8','mm')
 box(im,(R,922,R+240,1034),'#10252E');txt(im,(R+120,978),'Ранее',36,'#6E909A','mm');txt(im,(R+450,978),'1 / 17',32,a='mm');button(im,(R+660,922,R+900,1034),'Далее')
 return im

def card():
 im=page();im=Image.blend(im,Image.new('RGB',im.size,'#0B1C24'),.65);box(im,(540,205,1860,920))
 txt(im,(590,252),'ЖУРНАЛ · ВИД 1 ИЗ 7',28,'#9AD9E8');txt(im,(590,313),'Светляк-полосник',48)
 im.paste(ImageOps.contain(fish,(500,230)),(590,426))
 txt(im,(1140,425),'Наблюдений 1 из 3',36)
 for i,s in enumerate(['· Завидев хищника,','стая ныряет в заросли','кораллов.']):txt(im,(1140,505+i*49),s,34)
 txt(im,(590,725),'Последнее наблюдение',28,'#9AD9E8');button(im,(1440,780,1800,892),'Закрыть');return im
page().save(P/'zhurnal.png',optimize=True)
items=[('Первый запуск',page(empty=True)),('Карточка · текст Lab.card_lines',card()),('Новое после забега',page(new=True)),('16:9 · те же кегли и размеры касания',page(1920))]
sheet=Image.new('RGB',(2400,2650),'#0B1C24')
for i,(title,im) in enumerate(items):
 y=20+i*650;txt(sheet,(60,y),title,36);im.thumbnail((2280,570),Image.Resampling.LANCZOS);sheet.paste(im,((2400-im.width)//2,y+60))
sheet.quantize(colors=240).save(P/'zhurnal-sostoyaniya.png',optimize=True)
for f in P.glob('*.png'):print(f.name,Image.open(f).size,f.stat().st_size);assert f.stat().st_size<2000000
