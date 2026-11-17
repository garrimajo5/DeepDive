from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
O=Path(__file__).resolve().parent.parent;R=O/'renders';font='C:/Windows/Fonts/arial.ttf';f=lambda n:ImageFont.truetype(font,n)
for sex,title,filename in [('m','Мужская модель','03-muzhchina-pravki.png'),('zh','Женская модель','04-zhenshchina-pravki.png')]:
 im=Image.new('RGB',(2048,1152),'#17242c');d=ImageDraw.Draw(im);d.text((32,14),'MOD-018 · правки 06 · ЧЕРНОВИК · '+title+' · фартук и туника',font=f(32),fill='#e4e7df')
 for row,kind in enumerate(['fartuk','tunika']):
  for col,key in enumerate(['front','side','seat']):
   x=col*680+4;y=66+row*535;im.paste(Image.open(R/f'gear-{kind}-{sex}-{key}.png').convert('RGB'),(x,y));d.text((x+20,y+465),('Фартук' if row==0 else 'Туника')+' · '+{'front':'спереди','side':'сбоку','seat':'сидя, 90° / 90°'}[key],font=f(24),fill='#e4e7df')
 d.text((32,1120),'Рост базы 1,80 м · скелет MOD-012 · нижний край: вес бедра до 1,0 по согласованию',font=f(21),fill='#aec4ca')
 im.save(O/filename,optimize=True)
