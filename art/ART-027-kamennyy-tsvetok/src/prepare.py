from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
O=Path('art/ART-027-kamennyy-tsvetok'); G=Path('C:/Users/FEDYA/.codex/generated_images/01a150d4-51bb-7de2-a546-c950a2e37207')
Image.open(G/'exec-ed3d7d69-61b1-44d1-82d7-f76750c14f65.png').convert('RGB').resize((1600,900),Image.Resampling.LANCZOS).save(O/'01-podhod.jpg',quality=92)
Image.open(G/'exec-96906cf1-dd7e-466b-8182-cb3590e8884f.png').convert('RGB').resize((2048,1152),Image.Resampling.LANCZOS).quantize(colors=256).save(O/'02-list.png',optimize=True)
im=Image.new('RGB',(2048,1152),'#0B1C24');d=ImageDraw.Draw(im)
def font(n):return ImageFont.truetype('C:/Windows/Fonts/DejaVuSansCondensed.ttf',n)
def txt(x,y,t,n=25,c='#D5E4E8'):d.text((x,y),t,font=font(n),fill=c)
txt(50,25,'ART-027 · Габариты и размещение',42)
txt(50,90,'Слева: единый масштаб 18 пикселей / метр',27)
# Technical dimension envelopes, not artistic silhouettes. Height and width exact.
s=18; ground=700; cx=335
# coral bounding envelope 26 x28m, trunk3.5m, plinth8m x1.5m
box=(cx-13*s,ground-28*s,cx+13*s,ground)
d.rectangle(box,outline='#D06A94',width=3)
d.rectangle((cx-1.75*s,ground-7*s,cx+1.75*s,ground),fill='#63465C')
d.rectangle((cx-4*s,ground-1.5*s,cx+4*s,ground),fill='#344F63')
txt(cx-100,ground-28*s-40,'28 м × 26 м',27)
txt(cx-195,ground-19*s,'Габарит цветка',28,'#D06A94')
# ship side envelope 32 x5m
x=625; y=ground-5*s
d.rounded_rectangle((x,y,x+32*s,ground),radius=35,fill='#8C806B')
d.polygon([(x+20,y+12),(x+65,y+12),(x+65,y+43),(x+6,y+43)],fill='#F6DEAC')
txt(x+70,y-45,'Ковчег-7 · 32 × 5 м',27)
d.line((70,ground+15,1210,ground+15),fill='#D5E4E8',width=2)
for m in range(0,61,10):
 xx=80+m*s;d.line((xx,ground+20,xx,ground+35),fill='white',width=2);txt(xx-8,ground+40,str(m),22)
txt(1120,ground+40,'м',22)
# top plan independent scale 12px/m
px,py,sp=1600,440,12
r=13*sp;d.ellipse((px-r,py-r,px+r,py+r),outline='#D06A94',width=4)
d.ellipse((px-1.75*sp,py-1.75*sp,px+1.75*sp,py+1.75*sp),fill='#63465C')
d.line((px,py,px+23*sp,py),fill='#D5E4E8',width=2)
d.rectangle((px+21*sp,py-2*sp,px+25*sp,py+2*sp),outline='#86BCCB',width=3)
d.ellipse((px-2*sp,py+21*sp,px+2*sp,py+25*sp),outline='#F6AE55',width=3)
d.line((px,py,px,py+23*sp),fill='#D5E4E8',width=2)
txt(1330,100,'План · 12 пикселей / метр',27)
txt(1410,210,'Крона Ø 26 м',25)
txt(1700,385,'23 м',25);txt(1760,490,'Логово',24)
txt(1630,600,'23 м',25);txt(1480,765,'Огнецвет · до 4 м',24,'#F6AE55')
txt(1320,840,'От края кроны до края соседа ≥ 8 м',22)
txt(50,860,'Координата основания: X 40, глубина 42 м, Z −50.',27)
txt(50,905,'Верх: глубина 14 м. Цоколь включён в общую высоту 28 м.',27)
txt(50,950,'План соседей — предложение: логово на востоке, огнецвет на юге.',25)
txt(50,1000,'Схема задаёт размеры; художественные ракурсы не являются ортографическими чертежами.',25)
im.save(O/'03-gabarity.png',optimize=True)
for p in O.glob('*'):
 if p.suffix in ('.png','.jpg'):
  with Image.open(p) as v: print(p.name,v.size,p.stat().st_size); assert p.stat().st_size<2000000
