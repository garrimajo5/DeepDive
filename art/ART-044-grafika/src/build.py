from PIL import Image,ImageDraw,ImageOps
from pathlib import Path
import ui_base as u
O=Path(__file__).resolve().parents[1]
LEVELS=['Экономно','Обычно','Красиво']
VALUES=[['Ближе','Меньше','Выключены','Снижено'],['Средняя','Умеренно','Простые','Среднее'],['Дальше','Больше','Подробные','Полное']]
def page(level=1,w=2400,on=True):
 im=u.background(w);im=Image.blend(im,Image.new('RGB',im.size,u.C['bg']),.88);dx=(2400-w)/2
 u.text(im,(400-dx,72),'Настройки · Графика',58);u.button(im,1690-dx,52,300,112,'Назад')
 for i,t in enumerate(LEVELS):u.button(im,400-dx+i*540,230,510,112,t,i==level)
 for j,(name,value) in enumerate(zip(['Дальность обзора','Морской снег и частицы','Тени','Разрешение сцены'],VALUES[level])):
  y=430+j*90;u.text(im,(430-dx,y),name,38);u.text(im,(1940-dx,y),value,38,'cyan','rt')
 u.text(im,(430-dx,835),'Показывать кадры/с',38);u.button(im,1510-dx,800,430,112,'Вкл.' if on else 'Выкл.',on)
 u.text(im,(430-dx,980),'Надписи и кнопки остаются чёткими',30,'sub')
 return im

def game():
 im=u.background();u.controls(im,2400);d=ImageDraw.Draw(im)
 # Existing debug control, included only to verify separation.
 d.ellipse((2227,65,2335,173),outline=u.C['sub'],width=2);u.text(im,(2281,119),'noclip',23,'sub','mm')
 u.rect(im,(2030,210,2330,264));u.text(im,(2180,237),'58 кадр/с',34,anchor='mm')
 u.rect(im,(24,16,650,155));u.text(im,(44,34),'Глубина 120 м · ход 4',30,'sub');u.text(im,(44,90),'Корпус 98 %',30,'sub')
 return im

def suggestion():
 im=Image.blend(u.background(),Image.new('RGB',(2400,1080),u.C['bg']),.78);u.rect(im,(500,270,1900,810),line='cyan')
 u.text(im,(1200,330),'Телефон не справляется',48,anchor='mt');u.text(im,(1200,425),'Включить «Экономно»?',42,'sub','mt')
 u.text(im,(1200,500),'Меньше деталей — плавнее игра',32,'sub','mt');u.button(im,640,650,520,112,'Да',True);u.button(im,1240,650,520,112,'Нет');return im

def main():
 page().save(O/'grafika.png',optimize=True)
 states=[('01  Экономно',page(0)),('02  Обычно',page(1)),('03  Красиво',page(2)),('04  Счётчик в игре',game()),('05  После прогрева и проверки игры',suggestion()),('06  16:9',page(1,1920))]
 sheet=Image.new('RGB',(2400,2040),u.C['bg']);u.text(sheet,(60,40),'ART-044 / Графика',54)
 for i,(name,im) in enumerate(states):
  x=60+i%2*1180;y=150+i//2*620;u.text(sheet,(x,y),name,31,'sub');sheet.paste(ImageOps.contain(im,(1100,495)),(x,y+55))
 sheet.quantize(colors=240).save(O/'grafika-sostoyaniya.png',optimize=True)
 for p in O.glob('*.png'):print(p.name,p.stat().st_size);assert p.stat().st_size<2_000_000
if __name__=='__main__':main()
