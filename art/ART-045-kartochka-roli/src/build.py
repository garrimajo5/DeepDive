from PIL import Image,ImageDraw,ImageOps
from pathlib import Path
import ui_base as u
O=Path(__file__).resolve().parents[1]
DATA=[('Штурвал','П',0,['Ведите корабль','Действие — сесть / встать','Крестовина — ход и руль']),('Энергия','И',1,['Распределяйте энергию','Действие — открыть пульт','↑↓ — система · ←→ — доля']),('Сканер','Б',2,['Изучайте существ','Действие — сканировать','Держите цель в поле зрения']),('Сонар','С',3,['Находите контакты','Действие — импульс','Свайп — повернуть карту']),('Разряд','И',4,['Снимайте угрозу с корпуса','Действие — разряд','Дождитесь готовности']),('Вентиль','И',6,['Снижайте перегрев','Держите действие — сброс пара','Отпустите — закрыть вентиль'])]
def screen(which=3,w=2400,state='open'):
 im=u.background(w);u.controls(im,w);d=ImageDraw.Draw(im)
 if state=='alarm':
  u.rect(im,(24,16,500,100),line='amber');u.text(im,(48,40),'Перегрев',38,'amber');return im
 if state=='foreign':
  x=(w-1360)/2;u.rect(im,(x,230,x+1360,375));u.text(im,(w/2,260),'Это пост инженера',40,anchor='mt');u.text(im,(w/2,323),'Вы тоже можете им пользоваться',30,'sub','mt');return im
 if state=='collapsed':u.button(im,70,240,112,112,'?');return im
 title,role,idx,lines=DATA[which]
 x=w-1360 if which in (1,4,5) else 70
 u.rect(im,(x,180,x+620,550),line='cyan')
 a=Image.open(u.ROOT/'docs/concept-art/shema-znachki.png').convert('RGBA');g=a.crop((idx%4*128,idx//4*128,idx%4*128+128,idx//4*128+128)).resize((72,72));im.paste(g,(int(x+24),204),g)
 u.text(im,(x+116,216),title,40)
 d.ellipse((x+534,205,x+590,261),outline=u.C['text'],width=3);u.text(im,(x+562,233),role,34,anchor='mm')
 for j,t in enumerate(lines):u.text(im,(x+28,282+j*42),t,30,'sub' if j==0 else 'text')
 u.button(im,x+28,414,564,112,'Понятно',True)
 return im

def main():
 screen().quantize(colors=256).save(O/'kartochka-roli.png',optimize=True)
 states=[(f'{i+1:02}  {d[0]}',screen(i)) for i,d in enumerate(DATA)]
 states += [('07  Чужая роль — без запрета',screen(state='foreign')),('08  Свёрнута — открыть через «?»',screen(state='collapsed')),('09  Тревога — карточка скрыта',screen(state='alarm')),('10  16:9',screen(w=1920))]
 sheet=Image.new('RGB',(2400,3290),u.C['bg']);u.text(sheet,(60,40),'ART-045 / Карточки постов',54)
 for i,(name,im) in enumerate(states):
  x=60+i%2*1180;y=150+i//2*620;u.text(sheet,(x,y),name,31,'sub');sheet.paste(ImageOps.contain(im,(1100,495)),(x,y+55))
 sheet.quantize(colors=240).save(O/'kartochka-roli-sostoyaniya.png',optimize=True)
 for p in O.glob('*.png'):print(p.name,p.stat().st_size);assert p.stat().st_size<2_000_000
if __name__=='__main__':main()
