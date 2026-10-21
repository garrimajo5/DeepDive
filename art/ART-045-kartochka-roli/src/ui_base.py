from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import os
ROOT=Path(__file__).resolve().parents[3]; OUT=Path(__file__).resolve().parents[1]
FONT=os.environ.get('ART_FONT',r'C:/Users/FEDYA/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/share/fonts/DejaVuSans.ttf')
C={'bg':'#0B1C24','panel':'#102B37','cyan':'#67DDEB','sub':'#9AD9E8','text':'#D5E4E8','line':'#32616D','off':'#6E909A','amber':'#FFB259'}
def text(im,xy,s,size=36,color='text',anchor='lt'):
    ImageDraw.Draw(im).text(xy,s,font=ImageFont.truetype(FONT,size),fill=C.get(color,color),anchor=anchor)
def rect(im,b,fill='bg',line='line',width=2):
    ImageDraw.Draw(im).rounded_rectangle(b,radius=12,fill=C[fill],outline=C[line],width=width)
def button(im,x,y,w,h,s,active=False,disabled=False):
    rect(im,(x,y,x+w,y+h),'cyan' if active else 'panel','cyan' if active else 'line')
    text(im,(x+w/2,y+h/2),s,34,'bg' if active else ('off' if disabled else 'text'),'mm')
def background(w=2400):
    im=ImageOps.fit(Image.open(ROOT/'docs/concept-art/mostik-vid-ot-vhoda.jpg').convert('RGB'),(2400,1080),centering=(.5,.45))
    im=Image.blend(im,Image.new('RGB',im.size,C['bg']),.24)
    return im.crop(((2400-w)//2,0,(2400+w)//2,1080))
def waveform(im,x,y,repeated=False):
    d=ImageDraw.Draw(im); heights=([12,30,18,8]*3 if repeated else [10,20,32,16,8,26,36,12,18,30,10,6])
    for i,h in enumerate(heights):d.line((x+i*10,y-h/2,x+i*10,y+h/2),fill=C['sub'],width=4)
def controls(im,w):
    d=ImageDraw.Draw(im)
    for x,y,r in [(270,810,205),(w-219,810,119),(w-489,710,81),(w-489,910,81)]:d.ellipse((x-r,y-r,x+r,y+r),outline=C['line'],width=3)
    for s,x,y in [('↑',270,686),('↓',270,934),('←',146,810),('→',394,810)]:text(im,(x,y),s,45,'sub','mm')
    text(im,(w-219,810),'Действие',31,'sub','mm')
    text(im,(w-489,710),'Вверх',26,'sub','mm');text(im,(w-489,910),'Вниз',26,'sub','mm')
def card(im,state='normal',w=2400):
    left=520;right=w-620; top=680 if w<2200 else 720; dy=top-720
    rect(im,(left,top,right,1030),line='cyan')
    d=ImageDraw.Draw(im);d.ellipse((560,752+dy,650,842+dy),outline=C['text'],width=3)
    text(im,(605,797+dy),'И',48,'text','mm')
    text(im,(680,744+dy),'Связь' if state=='exposed' else 'Инженер',36)
    if w>=2200 and state!='exposed':text(im,(900,750+dy),'· экипаж',28,'sub')
    waveform(im,right-165,766+dy,state=='repeat')
    message='Сбросьте ход, перегрев'
    code='Код: Иней'; action='Спросить код'; disabled=False
    if state=='missing':code='Код: …'
    if state=='waiting':code='Ждём ответ…';action='Проверяем';disabled=True
    if state=='verified':code='Код совпал';action='Проверено';disabled=True
    if state=='wrong':code='Код: Пепел';action='Код не совпал';disabled=True
    if state=='unverified':code='Нет ответа';action='Спросить код'
    if state=='exposed':
        message='Это был не наш';code='Код не совпал';action='Понятно'
    text(im,(680,810+dy),message,40)
    text(im,(680,834 if w<2200 else 917),code,32,'sub')
    button(im,right-420,886,380,112,action,active=state=='exposed',disabled=disabled)
    if state=='verified':
        d.line((680,977,692,988,714,964),fill=C['cyan'],width=4)
    if state=='exposed':
        # Neutral role remains a remembered claimed identity, never a red threat icon.
        d.line((560,1028,right-40,1028),fill=C['cyan'],width=3)

def scene(state='normal',w=2400,tutorial=False,alarm=False):
    im=background(w);controls(im,w);card(im,state,w)
    if tutorial:
        x=(w-1360)//2;rect(im,(x,32,x+1360,206),line='cyan')
        text(im,(x+40,52),'Первый забег · 1 / 6',28,'sub')
        text(im,(x+40,112),'Подойдите к штурвалу — кнопка справа',40)
    if alarm:
        # Screen representation of the existing Status alarm, not a new alarm widget.
        rect(im,(24,16,510,88),line='amber');text(im,(44,34),'Перегрев',34,'amber')
    return im

def briefing():
    im=background();rect(im,(570,200,1830,650),line='cyan')
    text(im,(620,245),'Брифинг · голостол',38,'sub')
    text(im,(620,322),'Кодовое слово забега',42)
    text(im,(620,400),'Иней',76,'cyan')
    text(im,(620,526),'Запомните. Спросите код, если сомневаетесь.',34)
    text(im,(620,583),'Один код у всего экипажа',30,'sub')
    ImageDraw.Draw(im).line((1200,650,1200,715),fill=C['cyan'],width=3)
    ImageDraw.Draw(im).ellipse((1192,707,1208,723),fill=C['cyan'])
    return im

def main():
    scene(alarm=True).save(OUT/'svyaz-mostik.jpg',quality=94,subsampling=0,optimize=True)
    sheet=Image.new('RGB',(2400,3330),C['bg'])
    text(sheet,(60,40),'ART-040  /  Внутренняя связь',54)
    text(sheet,(60,112),'Рекомендуется А. Подписи вариантов — только на листе художника.',30,'sub')
    variants=[('01  Обычное сообщение',scene()),('02  А · нет кодового слова',scene('missing')),('03  Б · повтор рисунка сигнала',scene('repeat')),('04  Код на брифинге у голостола',briefing()),('05  Одна кнопка → запрос кода',scene('waiting')),('06  Ответ своего',scene('verified')),('07  Ответ с чужим кодом',scene('wrong')),('08  После подтверждения подделки',scene('exposed')),('09  Обучение сверху, связь снизу',scene(tutorial=True)),('10  16:9 · нет ответа ≠ подделка',scene('unverified',1920))]
    for i,(title,im) in enumerate(variants):
        x=60+(i%2)*1180;y=190+(i//2)*620
        text(sheet,(x,y),title,31,'sub')
        thumb=ImageOps.contain(im,(1100,495),Image.Resampling.LANCZOS)
        sheet.paste(thumb,(x+(1100-thumb.width)//2,y+54))
    # Reduce only the presentation sheet when necessary to meet the file budget.
    sheet.save(OUT/'svyaz-sostoyaniya.png',optimize=True)
    if (OUT/'svyaz-sostoyaniya.png').stat().st_size>=2_000_000:
        sheet.quantize(colors=240,method=Image.Quantize.MEDIANCUT).save(OUT/'svyaz-sostoyaniya.png',optimize=True)
    for f in OUT.glob('*'):
        if f.suffix in ('.png','.jpg'):
            assert f.stat().st_size<2_000_000,(f,f.stat().st_size)
            print(f.name,Image.open(f).size,f.stat().st_size)
if __name__=='__main__':main()
