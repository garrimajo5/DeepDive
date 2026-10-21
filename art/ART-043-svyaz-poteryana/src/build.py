from PIL import Image,ImageDraw,ImageOps
from pathlib import Path
import ui_base as u
O=Path(__file__).resolve().parents[1]
def modal(state='lost',w=2400):
 im=u.background(w);im=Image.blend(im,Image.new('RGB',im.size,u.C['bg']),.76);cx=w/2
 u.rect(im,(cx-700,180,cx+700,925),line='cyan')
 u.text(im,(cx,235),'Связь с хостом потеряна',56,anchor='mt')
 u.text(im,(cx,330),'Ваше управление остановлено',36,'sub','mt')
 u.text(im,(cx,387),'У хоста игра может продолжаться',32,'sub','mt')
 message={'lost':'Ждём хоста · осталось 7 с','joining':'Подключаемся… 3 из 10 с','timeout':'Нет ответа','version':'Другая версия игры','full':'Экипаж полон'}.get(state,'Ждём хоста · осталось 7 с')
 u.text(im,(cx,485),message,42,'cyan','mt')
 u.button(im,cx-600,615,1200,112,'Ждать',True)
 u.button(im,cx-600,765,580,112,'Играть одному');u.button(im,cx+20,765,580,112,'В меню')
 return im

def live(state='weak'):
 im=u.background();u.controls(im,2400)
 if state=='weak':
  u.rect(im,(70,430,470,526));u.text(im,(94,454),'≈  Слабая связь',34,'sub')
 elif state=='returned':
  u.rect(im,(650,260,1750,390),line='cyan');u.text(im,(1200,295),'Связь восстановлена',42,'cyan','mt');u.text(im,(1200,352),'Вы снова в экипаже',28,'sub','mt')
 else:
  a=Image.open(O/'src/engineer.png').convert('RGBA');a.thumbnail((380,570))
  if state=='hostlost':a.putalpha(a.getchannel('A').point(lambda v:round(v*.35)))
  im.paste(a,(470,330),a)
  u.rect(im,(460,200,860,310),line='line' if state=='hostlost' else 'cyan')
  u.text(im,(485,216),'И · Игорь',34,'off' if state=='hostlost' else 'text');u.text(im,(485,262),'Нет связи' if state=='hostlost' else 'В сети',28,'off' if state=='hostlost' else 'cyan')
  u.rect(im,(920,260,2010,435),line='cyan')
  u.text(im,(950,290),'Игорь отключился' if state=='hostlost' else 'Игорь вернулся',42)
  u.text(im,(950,360),'Роль свободна · пост освобождён' if state=='hostlost' else 'Проверяем роль и место в экипаже',32,'sub')
 return im

def confirm():
 im=Image.blend(modal(),Image.new('RGB',(2400,1080),u.C['bg']),.7);u.rect(im,(600,260,1800,800),line='cyan');u.text(im,(1200,310),'Продолжить одному?',48,anchor='mt');u.text(im,(1200,410),'Вы покинете сетевой забег.',36,'sub','mt');u.text(im,(1200,470),'Возврат — через сбор экипажа.',32,'sub','mt');u.button(im,720,610,450,112,'Да');u.button(im,1230,610,450,112,'Нет',True);return im

def main():
 modal().save(O/'svyaz-poteryana.png',optimize=True)
 states=[('01  Слабая связь — игра идёт',live()),('02  Гость ждёт хоста',modal()),('03  Переподключение',modal('joining')),('04  Связь восстановлена',live('returned')),('05  Хост: гость отключился',live('hostlost')),('06  Хост: гость вернулся',live('hostback')),('07  Нет ответа — выбор остаётся',modal('timeout')),('08  Подтверждение одиночной игры',confirm()),('09  16:9',modal(w=1920))]
 sheet=Image.new('RGB',(2400,3290),u.C['bg']);u.text(sheet,(60,40),'ART-043 / Связь потеряна',54)
 for i,(name,im) in enumerate(states):
  x=60+(i%2)*1180;y=150+(i//2)*620;u.text(sheet,(x,y),name,30,'sub');sheet.paste(ImageOps.contain(im,(1100,495)),(x,y+55))
 u.text(sheet,(1240,2730),'Нет автоматического перехода',34);u.text(sheet,(1240,2790),'в одиночный забег.',34)
 u.text(sheet,(1240,2890),'Истёк таймер → «Нет ответа».',32,'sub')
 sheet.quantize(colors=240).save(O/'svyaz-poteryana-sostoyaniya.png',optimize=True)
 for p in O.glob('*.png'):print(p.name,p.stat().st_size);assert p.stat().st_size<2_000_000
if __name__=='__main__':main()
