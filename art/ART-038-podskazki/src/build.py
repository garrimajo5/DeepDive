from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import sys,math
O=Path(__file__).resolve().parents[1];ROOT=O.parents[1];FONT=sys.argv[1];F=lambda n:ImageFont.truetype(FONT,n)
C='#67DDEB';T='#D5E4E8';S='#9AD9E8';B='#0B1C24'
# Simple native UI symbols: same outlined-circle vocabulary as existing touch controls.
atlas=Image.new('RGBA',(1024,1024));d=ImageDraw.Draw(atlas)
def ring(cx,cy,r,fill=None):d.ellipse((cx-r,cy-r,cx+r,cy+r),outline=C,width=18,fill=fill)
ring(256,208,100);d.line([(210,350),(256,396),(302,350)],fill=C,width=20)
d.line([(838,130),(714,254),(838,378)],fill=C,width=28);d.line([(714,254),(910,254)],fill=C,width=24)
ring(256,720,100);d.ellipse((220,684,292,756),fill=C);d.line([(214,856),(256,898),(298,856)],fill=C,width=20)
atlas=atlas.resize((512,512),Image.Resampling.LANCZOS);atlas.save(O/'podskazki-ukazatel.png',optimize=True)
cells=[atlas.crop((0,0,256,256)),atlas.crop((256,0,512,256)),atlas.crop((0,256,256,512))]
bg=ImageOps.fit(Image.open(ROOT/'docs/concept-art/mostik-vid-ot-vhoda.jpg').convert('RGBA'),(2400,1080),method=Image.Resampling.LANCZOS);bg=Image.alpha_composite(bg,Image.new('RGBA',(2400,1080),(11,28,36,50)))
lines=[['Подойдите к штурвалу — кнопка справа'],['За штурвалом: крестовина вверх — ход'],['За штурвалом нажмите «Свет»'],['Пульт энергии: крестовиной меняйте доли'],['У голостола нажмите «Сонар» — импульс'],['У голостола нажмите «Маршрут»']]
labels=['Штурвал','Встать','Встать','Энергия','Сонар','Маршрут'];targets=[(1200,500),(1200,500),(1200,500),(380,225),(1200,600),(1200,600)]
def txt(im,xy,s,n=40,color=T,anchor='lt'):ImageDraw.Draw(im).text(xy,s,font=F(n),fill=color,anchor=anchor)
def controls(im,step):
 d=ImageDraw.Draw(im);px,py,pr=270,810,205;ax,ay,ar=2181,810,119
 d.ellipse((px-pr,py-pr,px+pr,py+pr),fill=(103,221,235,25),outline=(213,228,232,150),width=3)
 for i in range(8):
  a=i*math.pi/4;ux,uy=math.cos(a),math.sin(a);tip=(px+ux*160,py+uy*160);base=(px+ux*113,py+uy*113);q=(-uy*20,ux*20);d.polygon([tip,(base[0]+q[0],base[1]+q[1]),(base[0]-q[0],base[1]-q[1])],fill=C if (step==1 and i==6) or step==3 else (213,228,232,150))
 d.ellipse((ax-ar,ay-ar,ax+ar,ay+ar),fill=(16,43,55,210),outline=C if step in [0,4,5] else S,width=8 if step in [0,4,5] else 3);txt(im,(ax,ay),labels[step],34,T,'mm')
 if step in [1,2]:
  for xx,yy,label in [(1911,710,'Всплыть'),(1911,910,'Вниз'),(2181,572,'Свет')]:
   d.ellipse((xx-81,yy-81,xx+81,yy+81),fill=(16,43,55,225),outline=C if label=='Свет' and step==2 else S,width=8 if label=='Свет' and step==2 else 3);txt(im,(xx,yy),label,27,T,'mm')
def frame(step,success=False,behind=False):
 im=ImageOps.fit(bg.crop((1750,180,2400,790)),(2400,1080),method=Image.Resampling.LANCZOS) if behind else bg.copy();hud=Image.new('RGBA',im.size);controls(hud,step);d=ImageDraw.Draw(hud);d.rounded_rectangle((520,32,1880,206),radius=12,fill=(11,28,36,244),outline=C,width=2)
 txt(hud,(560,52),('Выполнено' if success else f'Первый забег · {step+1} / 6'),28,S)
 txt(hud,(560,112),('Штурвал освоен' if success else lines[step][0]),40)
 if success:d.line([(1745,82),(1770,107),(1825,55)],fill=C,width=9)
 else:
  if behind:cell=cells[1];pos=(60,340)
  else:cell=cells[2 if step in [1,2,3,5] else 0];x,y=targets[step];pos=(x-64,y-150)
  hud.alpha_composite(cell.resize((128,128),Image.Resampling.LANCZOS),pos)
 return Image.alpha_composite(im,hud).convert('RGB')
frames=[frame(i) for i in range(6)];frames[0].save(O/'podskazki-mostik.jpg',quality=92,optimize=True)
sheet=Image.new('RGB',(2400,2480),B);txt(sheet,(50,25),'АРТ-038 · Подсказки первого забега',44)
heads=['1 · Штурвал: сесть','2 · Ход: крестовина вверх','3 · Прожектор: «Свет»','4 · Энергия: доли','5 · Сонар: импульс','6 · Голостол: маршрут','Выполнено · галочка 0,5 с','Пост за спиной · край экрана']
for i,im in enumerate(frames+[frame(0,True),frame(0,behind=True)]):
 x=50+(i%2)*1180;y=130+(i//2)*580;txt(sheet,(x,y-42),heads[i],28,S);sheet.paste(im.resize((1120,504),Image.Resampling.LANCZOS),(x,y))
sheet.quantize(colors=256,method=Image.Quantize.MEDIANCUT).save(O/'podskazki-list.png',optimize=True)
# Aspect adaptation must relayout the HUD, not crop controls. QA 20:9 at phone-sized raster.
if len(sys.argv)>2:frames[0].resize((1200,540),Image.Resampling.LANCZOS).save(Path(sys.argv[2])/'phone.png')
print([(p.name,p.stat().st_size) for p in O.iterdir() if p.suffix in ['.png','.jpg']])


