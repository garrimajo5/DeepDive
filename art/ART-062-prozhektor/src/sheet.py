from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import sys,json
P=Path(sys.argv[1]); F='C:/Windows/Fonts/DejaVuSansCondensed.ttf';B='C:/Windows/Fonts/DejaVuSansCondensed-Bold.ttf'
def font(s,b=False):return ImageFont.truetype(B if b else F,s)
def frame(tag,state):
 im=Image.open(P/'source'/f'{tag}-{state}.png').convert('RGB')
 x=(im.width-1600)//2;y=(im.height-720)//2;return im.crop((x,y,x+1600,y+720))
for tag in ['45','90','il']:
 for state in ['base','new','off']:
  im=frame(tag,state);im.save(P/'source'/f'{tag}-{state}.jpg',quality=93)
 frame(tag,'new').save(P/f'prozhektor-{tag}.jpg',quality=95)
sheet=Image.new('RGB',(3200,2020),'#0B1C24');d=ImageDraw.Draw(sheet)
d.text((40,18),'ПРОЖЕКТОР · РИСУНОК ОТРАЖАТЕЛЯ И ВЗВЕСЬ',fill='#E6FBFF',font=font(42,True))
mask=Image.open(P/'prozhektor-maska.png').convert('RGB').resize((360,360));sheet.paste(mask,(40,85))
beam=Image.open(P/'prozhektor-luch.png').convert('RGB').resize((180,360));sheet.paste(beam,(450,85))
d.text((690,90),'Пятно: ядро, кольца, тень держателя',fill='#E6FBFF',font=font(34))
d.text((690,145),'Луч: неравномерная взвесь, мягкое затухание',fill='#B1D1D8',font=font(32))
d.text((690,205),'Две маски L8 · 512² и 256 × 512 · без цвета и надписей',fill='#B1D1D8',font=font(30))
d.text((690,265),'Ниже — настоящие пробы Godot на склоне, курс 270°',fill='#67DDEB',font=font(30))
d.text((690,320),'Палитра глубины ART-059 · один существующий прожектор',fill='#B1D1D8',font=font(30))
for tag,pos,title in [('45',(0,500),'45 м · склон'),('90',(1600,500),'90 м · склон'),('il',(0,1280),'45 м · вход в облако ила')]:
 x,y=pos;sheet.paste(frame(tag,'new'),pos);d.rectangle((x,y,x+1600,y+48),fill='#0B1C24');d.text((x+24,y+4),title,fill='#E6FBFF',font=font(32,True))
# Diagnostic pair of the same window, baseline and proposed pattern; no changed exposure.
for state,x,title in [('base',1620,'Без маски'),('new',2400,'Маска отражателя')]:
 crop=frame('90',state).crop((595,220,1005,510)).resize((560,396))
 sheet.paste(crop,(x,1380));d.text((x,1305),title,fill='#E6FBFF',font=font(30,True))
d.text((1640,1820),'Кольца не заменяют рельеф дна; края пятна гаснут.',fill='#B1D1D8',font=font(30))
d.text((1640,1875),'В иле длина луча → 45 %; ближний свет не усиливается.',fill='#B1D1D8',font=font(30))
d.text((1640,1930),'Проектор требует shadow_enabled — см. notes.md.',fill='#FFB259',font=font(30))
sheet.save(P/'prozhektor-list.png',optimize=True)
v=json.loads((P/'validation.json').read_text())
for tag in ['45','90','il']:
 v[tag]={'capture_log':(P/f'{tag}.log').read_text(encoding='utf8').splitlines()[-2:]}
for f in P.rglob('*'):
 if f.is_file() and f.suffix.lower() in ['.png','.jpg'] and '-base.png' not in f.name and '-new.png' not in f.name and '-off.png' not in f.name and not f.name.startswith('test'):
  assert f.stat().st_size<=2*1024*1024,(f,f.stat().st_size)
(P/'validation.json').write_text(json.dumps(v,indent=2,ensure_ascii=False),encoding='utf8')
print('sheet', (P/'prozhektor-list.png').stat().st_size)
