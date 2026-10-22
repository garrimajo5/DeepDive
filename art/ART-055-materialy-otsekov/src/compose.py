from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1]
def font(n,b=False):return ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed'+('-Bold' if b else '')+'.ttf',n)
im=Image.new('RGB',(2048,2112),'#0B1C24');d=ImageDraw.Draw(im)
def txt(x,y,s,n=26,c='#D5E4E8'):d.text((x,y),s,font=font(n),fill=c)
txt(32,15,'ART-055 · МАТЕРИАЛЫ МАШИННОГО И ТРЮМА',40)
txt(33,67,'Одна плитка — 1 × 1 м. Геометрия ShipLayout, принятые модели. Примерка в Blender.',25,'#9AD9E8')
for row,(mode,title) in enumerate([('engine-warm','Машинное · тёплый плафон'),('engine-hot','Машинное · янтарь перегрева'),('cargo-warm','Трюм · тёплый плафон')]):
 for col in range(2):
  xx=32+col*1024;yy=113+row*650
  txt(xx,yy,title,29);txt(xx,yy+35,'С картами' if col else 'Без карт · исходная заливка',25,'#9AD9E8')
  im.paste(Image.open(R/'renders'/f'{mode}-{col}.png').convert('RGB').resize((950,570),Image.Resampling.LANCZOS),(xx,yy+75))
txt(32,2090,'Цвет + нормали OpenGL + ORM. Нет новой геометрии. Силуэты и источники света одинаковы в каждой паре.',20,'#9AD9E8')
im.quantize(colors=256).save(R/'materialy-list.png',optimize=True)

# Russian captions for the five inspection sheets.
for name,title in [('mash-pol','Машинное · рифлёный пол'),('mash-stena','Машинное · панели и трубные петли'),('tryum-pol','Трюм · палуба и крепления'),('tryum-stena','Трюм · набор и такелажные точки'),('otsek-potolok','Общий потолок · сервисные короба')]:
 p=R/f'proverka-{name}.jpg';img=Image.open(p).convert('RGB');dr=ImageDraw.Draw(img);dr.rectangle((0,0,1536,69),fill='#0B1C24')
 dr.text((20,8),title+' · повтор 3 × 3',font=font(27),fill='#D5E4E8')
 dr.text((20,39),'Плитка 1 × 1 м. Справа: нормали, ниже — затенение / шероховатость / металличность.',font=font(21),fill='#9AD9E8')
 img.save(p,quality=90)
