from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
O=Path(__file__).resolve().parent.parent;R=O/'renders';f=lambda n:ImageFont.truetype('C:/Windows/Fonts/arial.ttf',n)
for sex,title,num in [('m','Мужчина',5),('zh','Женщина',6)]:
 im=Image.new('RGB',(2048,1152),'#17242c');d=ImageDraw.Draw(im)
 d.text((28,16),'MOD-018 · правки 09 · игровые позы · '+title+' · ЧЕРНОВИК',font=f(32),fill='#e4e7df')
 for row,kind in enumerate(['fartuk','tunika']):
  for col,key in enumerate(['standing','seat1','post20']):
   x=28+col*672;y=68+row*520
   im.paste(Image.open(R/f'gear-{kind}-{sex}-{key}.png').convert('RGB'),(x,y))
   d.text((x+15,y+462),('Фартук' if kind=='fartuk' else 'Туника')+' · '+{'standing':'стоя','seat1':'в кресле','post20':'у поста, наклон 20°'}[key],font=f(23),fill='#e4e7df')
 d.text((28,1122),'CrewRig.pose · main be7df03 · пересечения не устранены · для диагностики, не для интеграции',font=f(21),fill='#aec4ca')
 im.save(O/f'{num:02}-igrovye-pozy-{sex}.png',optimize=True)
