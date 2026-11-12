from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
O=Path(__file__).resolve().parent.parent
im=Image.new('RGB',(2048,1152),'#17242c');d=ImageDraw.Draw(im);f=lambda n:ImageFont.truetype('C:/Windows/Fonts/arial.ttf',n)
d.text((32,24),'MOD-018 · лямки женского фартука · ЧЕРНОВИК',font=f(40),fill='#e4e7df')
for i,key in enumerate(['before','after']):
 src=Image.open(O/'renders'/('detail-'+key+'.png')).convert('RGB');src=src.resize((1024,576));im.paste(src,(1024*i,220));d.text((32+1024*i,150),('До: ревизия 07' if i==0 else 'После: ревизия 08'),font=f(32),fill='#e4e7df')
d.text((32,900),'Одинаковые камера, свет и игровая поза «стоя». Дефекты не ретушированы.',font=f(28),fill='#aec4ca')
d.text((32,955),'Нулевые пересечения и зазор 1–2 см ещё не достигнуты для всего комплекта.',font=f(26),fill='#aec4ca')
im.save(O/'07-lyamki-do-posle.jpg',quality=94)
