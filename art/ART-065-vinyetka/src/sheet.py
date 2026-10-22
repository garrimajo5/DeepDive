from pathlib import Path
import numpy as np,json,re
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parents[1]
FONT='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
def f(n):return ImageFont.truetype(FONT,n)
labels={'8-on':'8 м · прожектор включён','8-off':'8 м · прожектор выключен','20-on':'20 м · прожектор включён','20-off':'20 м · прожектор выключен','45-on':'45 м · прожектор включён','45-off':'45 м · прожектор выключен','90-on':'90 м · прожектор включён','90-off':'90 м · прожектор выключен','flyby':'Облёт · 8 м · третья секунда','silt':'Ил · 45 м · прожектор включён'}
for name,label in labels.items():
 a=Image.open(P/'source'/f'{name}.png').convert('RGB');b=Image.open(P/'source'/f'{name}-after.png').convert('RGB')
 out=Image.new('RGB',(3200,778),'#0b1c24');d=ImageDraw.Draw(out)
 d.text((22,12),label+'   |   Как сейчас',font=f(28),fill='#c6d6de');d.text((1622,12),'После · мягкая коррекция и виньетка',font=f(28),fill='#9ad9e8')
 out.paste(a,(0,58));out.paste(b,(1600,58));out.save(P/f'para-{name}.jpg',quality=92,subsampling=0,optimize=True)
def sheet(names,path,title):
 w=1536;rh=392
 im=Image.new('RGB',(w,110+rh*len(names)),'#0b1c24');d=ImageDraw.Draw(im)
 d.text((22,14),title,font=f(32),fill='#9ad9e8')
 d.text((22,60),'Как сейчас',font=f(22),fill='#c6d6de');d.text((790,60),'После',font=f(22),fill='#c6d6de')
 for i,name in enumerate(names):
  y=110+i*rh;d.text((22,y),labels[name],font=f(23),fill='#9ad9e8')
  for j,suffix in enumerate(['','-after']):
   a=Image.open(P/'source'/f'{name}{suffix}.png').convert('RGB');a.thumbnail((752,339),Image.Resampling.LANCZOS);im.paste(a,(8+j*768,y+35))
 if path.endswith('.png'):im.save(P/path,optimize=True)
 else:im.save(P/path,quality=92,subsampling=0,optimize=True)
sheet(['8-on','20-on','45-on','flyby'],'vinyetka-list.png','Характер воды · ART-065')
sheet(['8-off','20-off','45-off','90-on','90-off','silt'],'vinyetka-kontrol.jpg','Контроль · без прожектора, 90 м и ил')
print('sheets ready')
