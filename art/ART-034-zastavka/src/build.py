from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import sys,json
OUT=Path(__file__).resolve().parents[1]
FONT=sys.argv[1]
F=lambda size:ImageFont.truetype(FONT,size)
BG=OUT/'zastavka-fon.jpg'
if len(sys.argv)>2:
 im=Image.open(sys.argv[2]).convert('RGB');im=ImageOps.fit(im,(2400,1080),method=Image.Resampling.LANCZOS);im.save(BG,quality=91,optimize=True)
base=Image.open(BG).convert('RGB')
CYAN='#67DDEB';TEXT='#D5E4E8';SECOND='#9AD9E8'
hints=['Свайп — оглядеться','Крестовина — идти','Кнопка — действие у поста','Голосуйте у голостола: глубже или наверх']
def screen(progress,hint):
 im=base.copy();d=ImageDraw.Draw(im)
 d.text((360,416),'Погружение',font=F(104),fill=TEXT,anchor='lt',stroke_width=0)
 label='Готово к погружению' if progress==100 else 'Подготовка погружения'
 d.text((364,574),label,font=F(34),fill=SECOND,anchor='lt')
 d.text((1020,574),f'{progress} %',font=F(34),fill=TEXT,anchor='rt')
 d.rounded_rectangle((360,636,1020,648),radius=6,fill='#244955')
 if progress:d.rounded_rectangle((360,636,360+660*progress/100,648),radius=6,fill=CYAN)
 d.text((1200,944),hint,font=F(40),fill=TEXT,anchor='mt')
 return im
main=screen(50,hints[0]);main.save(OUT/'zastavka.jpg',quality=93,optimize=True)
sheet=Image.new('RGB',(2400,1440),'#0B1C24');d=ImageDraw.Draw(sheet);d.text((60,30),'Заставка • состояния прогрева и подсказки',font=F(46),fill=TEXT)
examples=[(0,0,'0 % · подготовка'),(50,1,'50 % · прогрев'),(100,2,'100 % · завершение'),(50,3,'Кадрирование · 16:9 и 19,5:9')]
for i,(value,hint,title) in enumerate(examples):
 x=60+(i%2)*1180;y=150+(i//2)*610
 d.text((x,y-48),title,font=F(30),fill=SECOND)
 im=screen(value,hints[hint])
 if i==3:
  q=ImageDraw.Draw(im);q.rectangle((240,0,2160,1079),outline=CYAN,width=5);q.rectangle((30,0,2370,1079),outline=TEXT,width=3)
 im=im.resize((1100,495),Image.Resampling.LANCZOS);sheet.paste(im,(x,y))
d.text((60,1350),'Заголовок 104 px · статус 34 px · подсказка 40 px · полоса 660 × 12 px',font=F(28),fill=SECOND)
d.text((60,1390),'Нижние углы свободны. Смена подсказки — раз в 8 с; никаких дополнительных анимаций.',font=F(25),fill=TEXT)
sheet.quantize(colors=256,method=Image.Quantize.MEDIANCUT).save(OUT/'zastavka-sostoyaniya.png',optimize=True)
# Inspection at representative phone raster dimensions, kept outside delivery.
if len(sys.argv)>3:
 qa=Path(sys.argv[3]);qa.mkdir(exist_ok=True)
 main.crop((240,0,2160,1080)).resize((960,540),Image.Resampling.LANCZOS).save(qa/'phone-16-9.png')
 main.crop((30,0,2370,1080)).resize((1170,540),Image.Resampling.LANCZOS).save(qa/'phone-19-5-9.png')
 print(json.dumps({p.name:{'size':Image.open(p).size,'bytes':p.stat().st_size} for p in OUT.iterdir() if p.suffix in ['.jpg','.png']},ensure_ascii=False))
