"""ART-050: reproducible 2D Control design on unmodified game captures."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

ROOT=Path(__file__).resolve().parents[1]
FONT=Path('C:/Windows/Fonts')
BG='#0B1C24'; PANEL='#102B37'; CYAN='#67DDEB'; TEXT='#D5E4E8'
SUB='#9AD9E8'; BORDER='#32616D'; MUTED='#6E909A'; AMBER='#FFB259'
NAMES=['Двигатели','Сонар','Жизнеобеспечение','Разряд по корпусу','Прожектор']
HINTS=['тяга','дальность импульса','ремонт корпуса','радиус разряда','дальность луча']
def font(n,b=False): return ImageFont.truetype(str(FONT/('DejaVuSansCondensed-Bold.ttf' if b else 'DejaVuSansCondensed.ttf')),n)
def text(d,xy,s,n=28,c=TEXT,b=False): d.text(xy,s,font=font(n,b),fill=c,stroke_width=0)
def card(mode='normal'):
    im=Image.new('RGB',(700,478),PANEL); d=ImageDraw.Draw(im)
    hot=mode=='hot'; scram=mode=='scram'; accent=AMBER if hot else CYAN
    shares=[30,20,25,15,10]; selected=0
    if mode=='limit': shares=[60,10,10,10,10]; selected=0
    if mode=='off': shares=[30,0,25,15,10]; selected=1
    d.rounded_rectangle((1,1,698,476),radius=12,outline=accent if hot else BORDER,width=2)
    d.ellipse((19,13,51,45),outline=TEXT,width=2); text(d,(29,17),'И',21,TEXT,True)
    text(d,(65,12),'ПУЛЬТ ЭНЕРГИИ',30,TEXT,True)
    text(d,(486,16),'ПЕРЕГРЕВ 90°' if hot else 'ИНЖЕНЕР',24,accent if hot else SUB,True)
    d.line((20,57,680,57),fill=BORDER,width=2)
    for i,(name,hint,v) in enumerate(zip(NAMES,HINTS,shares)):
        y=62+64*i; sel=i==selected
        if sel:
            d.rounded_rectangle((12,y,687,y+60),radius=8,fill='#193E4D',outline=accent,width=2)
            d.rounded_rectangle((14,y+5,20,y+55),radius=2,fill=accent)
        fg=MUTED if scram else TEXT
        text(d,(31,y+2),name,30,fg,sel)
        text(d,(32,y+32),hint,23,MUTED if scram else SUB)
        if v==0: text(d,(444,y+6),'ВЫКЛ.',22,MUTED,True)
        if v==60: text(d,(442,y+6),'ПРЕДЕЛ',22,SUB,True)
        text(d,(602,y+1),str(v),34,accent if sel and not scram else fg,True)
        d.rounded_rectangle((442,y+43,660,y+51),radius=4,fill=BG)
        if v: d.rounded_rectangle((442,y+43,442+218*v/60,y+51),radius=4,fill=MUTED if scram else accent if sel else BORDER)
        for tick in (20,40): d.line((442+218*tick/60,y+42,442+218*tick/60,y+52),fill=PANEL,width=2)
    d.line((20,387,680,387),fill=BORDER,width=1)
    if hot:
        text(d,(24,395),'Нагрузка 100 / безопасно 60',25,AMBER,True)
        text(d,(24,430),'Сбросьте долю или откройте вентиль',28,AMBER,True)
    elif scram:
        text(d,(24,395),'АВАРИЙНЫЙ СБРОС · ещё 8 с',28,TEXT,True)
        text(d,(24,434),'Подача 0 · настройки сохранены',25,SUB)
    else:
        text(d,(24,394),f'Резерв {100-sum(shares)} / 100',27,TEXT,True)
        text(d,(330,398),'Шаг 5 · предел доли 60',23,SUB)
        text(d,(24,433),'Вверх-вниз — система · влево-вправо — доля',24,SUB)
    return im
def save(im,name):
    # Lossless PNG; scene palette reduction only if needed for the delivery cap.
    p=ROOT/name; im.save(p,optimize=True)
    if p.stat().st_size>2_000_000: im.quantize(colors=256,method=Image.Quantize.MEDIANCUT).save(p,optimize=True)
    assert p.stat().st_size<=2_000_000,(name,p.stat().st_size)

def compose(source,mode='normal'):
    im=Image.open(ROOT/'source'/source).convert('RGB')
    assert im.height==1080
    im.paste(card(mode),(im.width-740,190))
    return im

main=compose('scene.jpg'); save(main,'pult-energii.png')
narrow=compose('scene-169.jpg'); save(narrow,'pult-energii-169.png')
sheet=Image.new('RGB',(2400,1440),BG); d=ImageDraw.Draw(sheet)
text(d,(50,22),'ПУЛЬТ ЭНЕРГИИ',42,TEXT,True)
text(d,(52,76),'ART-050 · пять систем · одинаковые строки во всех режимах',26,SUB)
states=[('normal','01  Обычный режим'),('limit','02  Доля в упоре — 60'),('hot','03  Перегрев'),('scram','04  Аварийный сброс'),('off','05  Система обесточена')]
for i,(mode,title) in enumerate(states):
    x=50+(i%3)*790; y=145+(i//3)*620
    text(d,(x,y),title,32,TEXT,True); sheet.paste(card(mode),(x,y+54))
    foot={'normal':'Выбор: рамка + полоса + жирное имя.','limit':'Максимум одной системы, не всего пульта.','hot':'Янтарь только при перегреве.','scram':'Доли остаются; выход систем равен нулю.','off':'Ноль и слово «ВЫКЛ.», пустая шкала.'}[mode]
    text(d,(x,y+548),foot,24,SUB)
x,y=1630,765
text(d,(x,y),'06  Компоновка 16:9',32,TEXT,True)
sheet.paste(narrow.resize((700,394),Image.Resampling.LANCZOS),(x,y+54))
text(d,(x,y+473),'Шрифт и панель сохраняют размер по высоте.',24,SUB)
text(d,(x,y+510),'Ползунки слева, кнопка действия снизу.',24,SUB)
text(d,(50,1375),'Концепт интерфейса · сцена из игры · ракурс для открытого пульта предложен отдельно',27,MUTED)
save(sheet,'pult-energii-sostoyaniya.png')
print(json.dumps({p.name:{'size':Image.open(p).size,'bytes':p.stat().st_size} for p in ROOT.glob('*.png')},ensure_ascii=False,indent=2))
