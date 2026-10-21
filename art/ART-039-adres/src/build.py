from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import os
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parents[1]
FONT=os.environ.get('ART_FONT',r'C:/Users/FEDYA/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/share/fonts/DejaVuSans.ttf')
C={'bg':'#0B1C24','panel':'#102B37','cyan':'#67DDEB','sub':'#9AD9E8','text':'#D5E4E8','line':'#32616D','off':'#6E909A'}
def txt(im,xy,s,size=36,fill='text',anchor='lt'):
    d=ImageDraw.Draw(im);d.text(xy,s,font=ImageFont.truetype(FONT,size),fill=C.get(fill,fill),anchor=anchor)
def panel(im,box,fill='panel',line='line',width=2):
    ImageDraw.Draw(im).rounded_rectangle(box,12,fill=C.get(fill,fill),outline=C.get(line,line),width=width)
def button(im,x,y,w,h,s,mode='normal',size=36):
    panel(im,(x,y,x+w,y+h),'cyan' if mode=='primary' else 'panel','cyan' if mode in ('primary','focus') else 'line',4 if mode=='focus' else 2)
    txt(im,(x+w/2,y+h/2),s,size,'bg' if mode=='primary' else ('off' if mode=='disabled' else 'text'),'mm')
def bg():
    im=ImageOps.fit(Image.open(ROOT/'docs/concept-art/zastavka-fon.jpg').convert('RGB'),(2400,1080))
    return Image.blend(im,Image.new('RGB',im.size,C['bg']),.86)
def guest(state='filled'):
    im=bg();txt(im,(400,86),'Войти по адресу',58)
    button(im,1720,64,280,112,'Назад')
    txt(im,(400,210),'Адрес товарища',30,'sub')
    value={'empty':'','invalid':'192.168.43.999'}.get(state,'192.168.43.17')
    panel(im,(400,270,1130,398),line='cyan')
    txt(im,(430,308),value or 'Адрес',52,'text' if value else 'off')
    if state == 'filled':
        x=430+ImageDraw.Draw(im).textlength(value,font=ImageFont.truetype(FONT,52)) if value else 430
        ImageDraw.Draw(im).line((x+8,302,x+8,365),fill=C['cyan'],width=3)
    msg={'empty':'Введите адрес хоста','invalid':'Проверьте адрес','connecting':'Подключаемся…','timeout':'Нет ответа','version':'Другая версия игры','full':'Экипаж полон'}.get(state,'В одной сети с хостом')
    txt(im,(400,430),msg,36,'cyan' if state not in ('filled','empty') else 'sub')
    txt(im,(400,523),'Последний удачный адрес',28,'sub')
    button(im,400,571,730,112,'192.168.43.17','disabled' if state=='connecting' else 'normal',38)
    button(im,400,737,730,128,'Отмена' if state=='connecting' else 'Войти','disabled' if state in ('empty','invalid') else 'primary',42)
    txt(im,(400,909),'Попросите адрес у хоста',28,'sub')
    for i,s in enumerate(['1','2','3','4','5','6','7','8','9','.','0','Стереть']):
        button(im,1260+(i%3)*248,270+(i//3)*152,224,128,s,'disabled' if state=='connecting' else 'normal',34 if s=='Стереть' else 52)
    return im

def lobby(host=True):
    im=bg();txt(im,(380,65),'Сбор экипажа',58)
    button(im,1720,52,300,112,'Назад')
    if host:
        panel(im,(380,190,2020,290))
        txt(im,(400,222),'Ваш адрес:',34,'sub');txt(im,(650,208),'192.168.43.17',64,'cyan')
        txt(im,(1430,230),'Скажите его товарищам',30,'sub')
        for i,(role,name,letter,status,color) in enumerate([('Пилот','Игрок 1 · вы · хост','П','Ждём','#E39E38'),('Сонарщик','Игорь','С','Готов','#45C2CC'),('Инженер','Игрок 3','И','Готов','#D5E4E8'),('Биолог','Свободно','Б','Выбрать роль','#73BD5C')]):
            y=320+i*130
            panel(im,(380,y,2020,y+112),line='cyan' if i==0 else 'line')
            ImageDraw.Draw(im).ellipse((410,y+20,482,y+92),outline=color,width=3)
            txt(im,(446,y+56),letter,39,color,'mm')
            txt(im,(510,y+14),role,34);txt(im,(510,y+63),name,30,'sub')
            if i==3:button(im,1540,y+8,468,96,status,size=34)
            else:txt(im,(1570,y+40),('✓ ' if i else '○ ')+status,34,'cyan' if i else 'text')
        txt(im,(520,850),'Готовы 2 из 3 · подтвердите готовность',30,'sub')
        button(im,520,920,580,112,'Готов','primary')
        button(im,1140,920,740,112,'Начать погружение','disabled',34)
    else:
        txt(im,(380,190),'Забеги в вашей сети',32,'sub')
        button(im,380,270,500,112,'Создать забег')
        button(im,910,270,500,112,'По адресу','primary')
        button(im,1440,270,580,112,'Обновить список')
        panel(im,(380,450,2020,650))
        txt(im,(420,485),'Забег «Игорь»',42);txt(im,(420,556),'2 из 4 мест · ждут экипаж',32,'sub')
        button(im,1540,493,440,112,'Подключиться',size=34)
        txt(im,(400,720),'Не нашли забег? Узнайте адрес у хоста.',34,'sub')
    return im

def save(im,name):
    # Palette compression keeps approved photographic underlay within the issue budget.
    im.save(OUT/name,optimize=True)

def main():
    save(guest(),'adres-vvod.png');save(lobby(),'adres-host.png')
    sheet=Image.new('RGB',(2400,2600),C['bg']);txt(sheet,(64,45),'ART-039  /  Вход по адресу',54)
    variants=[('01  Пустое поле',guest('empty')),('02  Неверный адрес',guest('invalid')),('03  Идёт подключение',guest('connecting')),('04  Нет ответа',guest('timeout')),('05  Другая версия игры',guest('version')),('06  Экипаж полон',guest('full')),('07  «По адресу» — рядом с поиском',lobby(False)),('08  Адрес хоста над ролями',lobby())]
    for i,(label,im) in enumerate(variants):
        x=64+(i%2)*1180;y=150+(i//2)*606
        txt(sheet,(x,y),label,32,'sub');sheet.paste(im.resize((1096,493),Image.Resampling.LANCZOS),(x,y+57))
    save(sheet,'adres-sostoyaniya.png')
    for f in OUT.glob('*.png'):
        assert f.stat().st_size<2_000_000,(f,f.stat().st_size)
        print(f.name,Image.open(f).size,f.stat().st_size)
if __name__=='__main__':main()
