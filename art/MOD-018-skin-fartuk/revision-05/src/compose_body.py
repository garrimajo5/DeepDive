from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
O=Path(__file__).resolve().parent.parent;R=O/'renders';im=Image.new('RGB',(2048,1152),'#17242c');d=ImageDraw.Draw(im);f=lambda n:ImageFont.truetype('C:/Windows/Fonts/arial.ttf',n)
d.text((25,14),'MOD-018 · диагностика исходного тела · без фартука и туники',font=f(29),fill='#e4e7df')
for row,sex in enumerate(['m','zh']):
 for col,key in enumerate(['standing','walk5']):
  x=col*1024+112;y=65+row*510;im.paste(Image.open(R/f'body-{sex}-{key}.png').convert('RGB'),(x,y));d.text((x+20,y+415),('Мужчина' if sex=='m' else 'Женщина')+' · '+('стоя' if key=='standing' else 'фаза шага walk5'),font=f(26),fill='#e4e7df')
d.text((25,1100),'Голубой — предплечья/кисти; светлая охра — пересекающиеся грани торса.',font=f(24),fill='#aec4ca')
im.save(O/'07-kontakty-tela.png',optimize=True)
