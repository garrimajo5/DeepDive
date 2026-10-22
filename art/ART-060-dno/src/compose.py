from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1]
F='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
def f(n):return ImageFont.truetype(F,n)
sheet=Image.new('RGB',(3200,1600),'#0B1C24');d=ImageDraw.Draw(sheet)
def txt(x,y,s,n=30,c='#D5E4E8'):d.text((x,y),s,font=f(n),fill=c)
txt(24,12,'ART-060 · ГРУНТЫ ОТМЕЛИ · 2 × 2 м на плитку',43)
for i,(name,title) in enumerate([('pesok','Песок с рябью'),('il','Мягкий ил'),('galka','Галька с ракушечником')]):
 x=i*1066+24;txt(x,82,title,34,'#9AD9E8');tile=Image.open(R/f'dno-{name}-tsvet.png').convert('RGB').resize((128,128),Image.Resampling.LANCZOS)
 for a in range(4):
  for b in range(4):sheet.paste(tile,(x+a*128,140+b*128))
 for j,suffix in enumerate(['normali','orm']):
  txt(x+555,110+j*285,'Нормали' if j==0 else 'ORM · металл 0',25,'#9AD9E8');sheet.paste(Image.open(R/f'dno-{name}-{suffix}.png').convert('RGB').resize((256,256)),(x+555,145+j*285))
 txt(x,680,'Цвет × 4 × 4 · средний серый 50%',26)
txt(24,746,'Мостик · прежняя палитра и каустики',34,'#9AD9E8');txt(1624,746,'В прожекторе · крупный план грунта',34,'#9AD9E8')
for i,name in enumerate(['mostik','blizko']):
 im=Image.open(R/f'source/{name}.png').convert('RGB');assert im.size==(1600,720);sheet.paste(im,(i*1600,800));im.save(R/f'dno-{name}.jpg',quality=95)
txt(24,1545,'Примерка карт на существующем дне · Forward Mobile · без новых мешей и проходов',29,'#9AD9E8')
sheet.save(R/'dno-list.png',optimize=True)
if (R/'dno-list.png').stat().st_size>2_000_000:sheet.quantize(colors=256).save(R/'dno-list.png',optimize=True)
im=Image.new('RGB',(2048,1152),'#0B1C24');d=ImageDraw.Draw(im)
d.text((30,15),'ART-060 · ДО И ПОСЛЕ',font=f(38),fill='#D5E4E8')
for i,(name,title) in enumerate([('mostik-base','Мостик · без карт'),('mostik','Мостик · с картами'),('blizko-base','У дна · без карт'),('blizko','У дна · с картами')]):
 x=30+(i%2)*1024;y=85+(i//2)*510;d.text((x,y),title,font=f(29),fill='#9AD9E8');im.paste(Image.open(R/f'source/{name}.png').resize((970,437)),(x,y+43))
d.text((30,1115),'В каждой паре камера, свет и экспозиция одинаковы. Крупный план: экспозиция 0,18 для чтения грунта.',font=f(23),fill='#9AD9E8');im.save(R/'dno-sravnenie.jpg',quality=94)
print('composed', (R/'dno-list.png').stat().st_size)
