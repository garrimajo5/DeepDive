from PIL import Image, ImageDraw, ImageOps
from pathlib import Path
import ui_base as u
O=Path(__file__).resolve().parents[1]
def mic(im,x,y,c='sub',slash=False):
 d=ImageDraw.Draw(im); col=u.C[c]
 d.rounded_rectangle((x+12,y,x+36,y+40),12,outline=col,width=4);d.arc((x,y+10,x+48,y+57),0,180,fill=col,width=4);d.line((x+24,y+56,x+24,y+69),fill=col,width=4);d.line((x+11,y+69,x+37,y+69),fill=col,width=4)
 if slash:d.line((x-3,y+65,x+52,y-4),fill=col,width=4)
def talker(im,x,y,name='Игорь',role='И',active=True,w=360):
 u.rect(im,(x,y,x+w,y+72),line='cyan' if active else 'line');d=ImageDraw.Draw(im)
 d.ellipse((x+12,y+10,x+64,y+62),outline=u.C['text'],width=2);u.text(im,(x+38,y+36),role,33,'text','mm');u.text(im,(x+78,y+19),name,32)
 if active:
  for j,h in enumerate([18,34,24]):d.line((x+w-48+j*10,y+36-h/2,x+w-48+j*10,y+36+h/2),fill=u.C['cyan'],width=4)
def scene(state='pressed',w=2400):
 im=u.background(w);u.controls(im,w);d=ImageDraw.Draw(im)
 d.ellipse((w-300,491,w-138,653),outline=u.C['line'],width=3);u.text(im,(w-219,572),'Свет',28,'sub','mm')
 if state not in ('wall','settings'):
  actor=Image.open(O/'src/engineer.png').convert('RGBA');actor.thumbnail((380,570));im.paste(actor,(470,320),actor);talker(im,460,225)
 x=w-370;y=340
 mode=state if state in ('idle','pressed','denied','muted','two') else 'pressed'
 u.rect(im,(x,y,x+300,y+128),'cyan' if mode in ('pressed','two') else 'panel','cyan')
 mic(im,x+24,y+28,'bg' if mode in ('pressed','two') else 'sub',mode=='denied')
 u.text(im,(x+90,y+42),'Говорить',34,'bg' if mode in ('pressed','two') else 'text')
 label={'pressed':'Вас слышно','two':'Вас слышно','denied':'Нет доступа','muted':'Звук выкл.','idle':'Удерживайте'}.get(mode,'Вас слышно')
 u.rect(im,(x,y-64,x+300,y-16))
 u.text(im,(x+12,y-53),label,30,'cyan' if mode in ('pressed','two') else 'sub')
 if mode=='pressed' or state in ('two','wall','both'):
  u.text(im,(w-780,234),'Рация · игроки',28,'sub');talker(im,w-780,280)
 if state=='two':talker(im,w-780,376,'Марина','Б')
 if state=='wall':u.text(im,(w-780,368),'Вне поля зрения',27,'sub')
 if state=='muted':u.text(im,(w-780,282),'Товарищей не слышно',30,'sub');u.text(im,(w-780,328),'Микрофон готов',28,'sub')
 if state=='denied':u.text(im,(w-800,278),'Разрешите микрофон',30);u.button(im,w-800,340,360,112,'В настройки')
 if state=='both':u.card(im,'missing',w)
 return im

def settings():
 im=u.background();im=Image.blend(im,Image.new('RGB',im.size,u.C['bg']),.7)
 u.text(im,(420,80),'Настройки · Голос',58);u.button(im,1680,60,300,112,'Назад')
 u.text(im,(420,235),'Громкость товарищей',38);u.text(im,(1940,235),'70 %',38,anchor='rt')
 d=ImageDraw.Draw(im);d.line((440,330,1920,330),fill=u.C['line'],width=10);d.line((440,330,1476,330),fill=u.C['cyan'],width=10);d.ellipse((1456,310,1496,350),fill=u.C['cyan'])
 u.text(im,(420,440),'Микрофон',38);u.button(im,1440,400,500,112,'Разрешён')
 u.text(im,(420,600),'Режим',38);u.button(im,820,562,650,112,'Нажать и держать',True);u.button(im,1500,562,440,112,'По голосу')
 u.text(im,(420,744),'По голосу: передача при вашей речи',32,'sub')
 u.button(im,420,840,700,112,'Звук товарищей: вкл.');u.button(im,1160,840,780,112,'Микрофон: вкл.')
 return im

def main():
 scene().save(O/'raciya-mostik.jpg',quality=93,optimize=True)
 states=[('01  Покой — держать для передачи',scene('idle')),('02  Нажата — вас слышно',scene()),('03  Нет разрешения Android',scene('denied')),('04  Звук товарищей выключен',scene('muted')),('05  Говорят двое и вы',scene('two')),('06  Товарищ за стеной',scene('wall')),('07  Рация и внутренняя связь',scene('both')),('08  Настройки → Голос',settings()),('09  16:9 — отдельные зоны',scene('both',1920))]
 sheet=Image.new('RGB',(2400,3290),u.C['bg']);u.text(sheet,(60,40),'ART-041 / Рация экипажа',54)
 for i,(name,im) in enumerate(states):
  x=60+(i%2)*1180;y=150+(i//2)*620;u.text(sheet,(x,y),name,31,'sub');t=ImageOps.contain(im,(1100,495));sheet.paste(t,(x,y+55))
 u.text(sheet,(1240,2700),'Живой голос — компактные имена.',34)
 u.text(sheet,(1240,2760),'Связь ART-040 — команда и код.',34)
 u.text(sheet,(1240,2850),'Кнопка рации выше «Света».',34,'sub')
 u.text(sheet,(1240,2910),'Нижние углы не заняты.',34,'sub')
 sheet.quantize(colors=240).save(O/'raciya-sostoyaniya.png',optimize=True)
 for p in O.rglob('*'):
  if p.is_file() and p.suffix in ('.png','.jpg'):print(p.name,p.stat().st_size);assert p.stat().st_size<2_000_000
if __name__=='__main__':main()
