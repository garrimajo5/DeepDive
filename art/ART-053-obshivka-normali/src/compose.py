from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1];P=R/'renders'
im=Image.new('RGB',(2048,1152),'#0B1C24');d=ImageDraw.Draw(im)
def font(n,b=False):return ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed'+('-Bold' if b else '')+'.ttf',n)
def txt(x,y,s,n=27,c='#D5E4E8',b=False):d.text((x,y),s,font=font(n,b),fill=c)
txt(34,18,'ОБШИВКА · рельеф под боковым светом',40,b=True)
txt(36,74,'ART-053 · один фрагмент 2 × 2 м · одинаковые камера, свет, цвет и шероховатость',25,'#9AD9E8')
for i,(name,title) in enumerate([('flat','Без нормалей'),('normal','С нормалями'),('damage15','Повреждения · корпус 15 %')]):
 x=32+676*i;txt(x,117,title,29,b=True)
 a=Image.open(P/(name+'.png')).convert('RGB');im.paste(a.resize((632,632),Image.Resampling.LANCZOS),(x,166))
txt(35,817,'Проверка без нарисованных теней · тот же серый материал, только нормали',27,'#9AD9E8',True)
clay=Image.open(P/'clay.png').convert('RGB')
for x,box,title in [(35,(55,195,325,465),'Заклёпки выпуклые, швы утоплены'),(713,(530,520,800,790),'Вмятина — углубление'),(1390,(0,535,270,805),'Кольцо — выпуклый валик')]:
 crop=clay.crop(box).resize((250,250),Image.Resampling.LANCZOS);im.paste(crop,(x,866));txt(x+265,880,title.split(' — ')[0] if ' — ' in title else 'Шов и крепёж',23,'#D5E4E8',True)
 if x==35:
  txt(x+265,924,'Головка ловит свет.',22,'#9AD9E8');txt(x+265,958,'Шов остаётся ниже.',22,'#9AD9E8')
 elif x==713:
  txt(x+265,924,'Отрицательная высота.',22,'#9AD9E8');txt(x+265,958,'Центр ниже краёв.',22,'#9AD9E8')
 else:
  txt(x+265,924,'Середина без рельефа.',22,'#9AD9E8');txt(x+265,958,'Края приподняты.',22,'#9AD9E8')
txt(35,1124,'Blender · примерка карт, не игровой кадр Forward Mobile',20,'#6E909A')
im.save(R/'normali-list.png',optimize=True)
if (R/'normali-list.png').stat().st_size>2_000_000:im.quantize(colors=256).save(R/'normali-list.png',optimize=True)
