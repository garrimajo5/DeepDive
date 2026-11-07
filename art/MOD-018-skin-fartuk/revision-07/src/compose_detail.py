from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
O=Path(__file__).resolve().parent.parent;R=O/'renders';f=lambda n:ImageFont.truetype('C:/Windows/Fonts/arial.ttf',n)
im=Image.new('RGB',(2048,1152),'#17242c');d=ImageDraw.Draw(im);d.text((32,24),'MOD-018 · сгиб женского фартука · правки 07',font=f(36),fill='#e4e7df')
for i,(name,label) in enumerate([('detail-before','До: ревизия 06'),('detail-after','После: ревизия 07')]):
 x=24+i*1012;im.paste(Image.open(R/(name+'.png')).convert('RGB').resize((988,556)),(x,148));d.text((x,98),label,font=f(28),fill='#b7d2d5')
lines=['Перестроено направление треугольников у бедра; цельный подол сохранён.','Контакты этого участка в проверенных игровых позах: 63 → 0.','У женского фартука в целом: 95 → 16 пар пересечений; остаток — на лямках.','Без ретуши геометрии. Работа ещё не готова к приёмке.']
for j,line in enumerate(lines):d.text((32,770+j*70),line,font=f(29),fill='#b7d2d5')
im.save(O/'07-sgib-bedra.jpg',quality=91)
