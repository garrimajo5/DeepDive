from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1]
im=Image.new('RGB',(2048,1152),'#0B1C24');d=ImageDraw.Draw(im)
def font(n,b=False):return ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed'+('-Bold' if b else '')+'.ttf',n)
def txt(x,y,s,n=26,c='#D5E4E8',b=False):d.text((x,y),s,font=font(n,b),fill=c)
txt(35,16,'МАТЕРИАЛЫ МОСТИКА · до и после',39,b=True)
txt(37,67,'ART-054 · геометрия BridgePlan и принятые модели · Blender-примерка, не игровой кадр',24,'#9AD9E8')
for i,(name,title,sub) in enumerate([('warm-0','Тёплый плафон · без карт','Исходная заливка'),('warm-1','Тёплый плафон · с картами','Цвет + нормали + ORM'),('blue-0','Голубой свет пульта · без карт','Исходная заливка'),('blue-1','Голубой свет пульта · с картами','Цвет + нормали + ORM')]):
 x=35+(i%2)*1024;y=111+(i//2)*516
 txt(x,y,title,29,b=True)
 src=Image.open(R/'renders'/(name+'.png')).convert('RGB');im.paste(src.resize((760,456),Image.Resampling.LANCZOS),(x,y+40))
 txt(x+780,y+60,'1 × 1 м',25,'#9AD9E8',True)
 txt(x+780,y+105,'Пол',23);txt(x+780,y+137,'0,6',24,'#9AD9E8')
 txt(x+780,y+193,'Стены',23);txt(x+780,y+225,'0,8',24,'#9AD9E8')
 txt(x+780,y+281,'Потолок',23);txt(x+780,y+313,'0,7',24,'#9AD9E8')
 txt(x+780,y+375,'Сила',22,'#6E909A');txt(x+780,y+404,'нормалей',22,'#6E909A')
im.save(R/'materialy-list.png',optimize=True)
if (R/'materialy-list.png').stat().st_size>2_000_000:im.quantize(colors=256).save(R/'materialy-list.png',optimize=True)
