from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,sys
P=Path(sys.argv[1]);sources=json.loads((P/'sources.json').read_text(encoding='utf8'))
F='C:/Windows/Fonts/DejaVuSansCondensed.ttf';B='C:/Windows/Fonts/DejaVuSansCondensed-Bold.ttf'
def font(s,b=False):return ImageFont.truetype(B if b else F,s)
canvas=Image.new('RGB',(2400,1700),'#0B1C24');d=ImageDraw.Draw(canvas)
d.text((36,20),'СВЕТ ВНУТРИ «КОВЧЕГА-7» · ПЛАН И ИСТОЧНИКИ',font=font(40,True),fill='#E6FBFF')
d.text((36,78),'Оси ShipLayout · метры · вид сверху · нос −Z вверх',font=font(25),fill='#A9C9D2')
scale=43;cx=450;top=150
rooms=[('Мостик',-5.9,2,5),('Коридор',2,8,1.1),('Лаборатория',8,14,4),('Машинное',14,19.5,3),('Трюм',19.5,24,2.5)]
def pos(x,z):return (int(cx+x*scale),int(top+(z+5.9)*scale))
# Schematic pools at working height, clipped by room outlines: not a shadow simulation.
layer=Image.new('RGB',(880,1420),'#0B1C24');pix=np.asarray(layer).copy();yy,xx=np.mgrid[:1420,:880];wx=(xx-cx)/scale;wz=(yy-top)/scale-5.9
for name,z0,z1,hw in rooms:
 mask=(np.abs(wx)<=hw)&(wz>=z0)&(wz<=z1)
 col=np.zeros((1420,880,3))+[11,28,36]
 for s in sources:
  if s['room'].lower()!=name.lower():continue
  x,y,z=s['pos'];dist=np.sqrt((wx-x)**2+(wz-z)**2+(y-1)**2)
  k=np.maximum(1-dist/s['range'],0)**s['attenuation']*s['energy']*.8
  rgb=np.array([int(s['color'][i:i+2],16) for i in [0,2,4]])
  col+=k[:,:,None]*rgb
 pix[mask]=np.uint8(np.clip(col[mask],0,255))
canvas.paste(Image.fromarray(pix),(0,0));d=ImageDraw.Draw(canvas)
# Header restored after schematic layer paste.
d.rectangle((0,0,2400,128),fill='#0B1C24');d.text((36,20),'СВЕТ ВНУТРИ «КОВЧЕГА-7» · ПЛАН И ИСТОЧНИКИ',font=font(40,True),fill='#E6FBFF');d.text((36,78),'Оси ShipLayout · метры · вид сверху · нос −Z вверх',font=font(25),fill='#A9C9D2')
for name,z0,z1,hw in rooms:
 x0,y0=pos(-hw,z0);x1,y1=pos(hw,z1);d.rectangle((x0,y0,x1,y1),outline='#8DA6AD',width=3)
 d.text((18,(y0+y1)//2),name,font=font(24,True),fill='#B8D9E8')
 for z in np.arange(np.ceil(z0),z1,1):
  q=pos(0,float(z));d.line((x0,q[1],x1,q[1]),fill='#213F48',width=1)
for z in [2,8,14,19.5]:
 x0,y=pos(-.7,z);x1,_=pos(.7,z);d.line((x0,y,x1,y),fill='#E6FBFF',width=6)
 d.text((690,y-12),f'люк z={z:g}',font=font(20),fill='#8DA6AD')
# Fixtures remain material emission, not extra point lights.
for x in [-4.85,4.85]:
 for z in [-5,-3.5,-2,-.5,1]:
  px,py=pos(x,z);d.rectangle((px-4,py-7,px+4,py+7),fill='#E3D2AC' if x<0 else '#92BBCB')
for s in sources:
 x,y=pos(s['pos'][0],s['pos'][2]);c='#'+s['color'];d.ellipse((x-8,y-8,x+8,y+8),fill=c,outline='#E6FBFF',width=2)
 dx=18 if s['id']!='R1' else 38;dy=-22 if s['id']!='E1' else -32
 d.line((x,y,x+dx,y+dy),fill=c,width=2);d.text((x+dx,y+dy-12),s['id'],font=font(24,True),fill='#E6FBFF')
d.text((210,1470),'Светло → полутень → тёмный угол',font=font(24),fill='#B1D1D8')
d.text((210,1515),'Пятна условные, не расчёт теней.',font=font(22),fill='#7FA4AF')
d.text((210,1555),'Тени плафонов выключены.',font=font(22),fill='#7FA4AF')
d.line((210,1620,425,1620),fill='#E6FBFF',width=4);d.text((270,1625),'5 м',font=font(22),fill='#B1D1D8')
d.text((920,140),'7 рабочих источников · без добавления новых',font=font(31,True),fill='#E6FBFF')
for index,s in enumerate(sources):
 y=205+index*133;d.ellipse((925,y+4,955,y+34),fill='#'+s['color']);d.text((980,y),s['id']+' · '+s['name'],font=font(28,True),fill='#E6FBFF')
 a=s['pos'];d.text((980,y+41),f"({a[0]:g}; {a[1]:g}; {a[2]:g}) м   #{s['color']}",font=font(25),fill='#B1D1D8')
 d.text((980,y+79),f"E {s['energy']:g}  ·  R {s['range']:g} м  ·  затухание {s['attenuation']:g}",font=font(25),fill='#B1D1D8')
d.text((920,1180),'АВАРИЯ · период 1,2 с',font=font(30,True),fill='#FFB259')
d.text((920,1230),'B1 / L1: холодный #A9DDE7 × 0,48',font=font(26),fill='#A9DDE7')
d.text((920,1272),'B2 / C1 / E1 / H1: янтарный #FFB259',font=font(26),fill='#FFB259')
d.text((920,1314),'В повреждённом отсеке: × 0,35…1; в остальных × 0,40…0,60.',font=font(25),fill='#B1D1D8')
d.text((920,1356),'R1 сохраняет состояние реактора, без аварийного мигания.',font=font(25),fill='#B1D1D8')
d.text((920,1420),'A1 — прежний огонь пробоины: 0 (не удваивать янтарь).',font=font(23),fill='#9AB7C0')
d.text((920,1460),'Сварка — прежний источник у активной пробоины, без изменений.',font=font(23),fill='#9AB7C0')
d.text((920,1500),'Внешние солнце / прожектор / разряд не относятся к этой схеме.',font=font(23),fill='#9AB7C0')
d.text((920,1570),'Энергия — единицы Godot, не люмены. Cull mask = 2.',font=font(24),fill='#E6FBFF')
d.text((920,1614),'Решётки плафонов и кольцо лаборатории светятся материалом.',font=font(24),fill='#B1D1D8')
canvas.save(P/'svet-plan.png',optimize=True)
print('plan', (P/'svet-plan.png').stat().st_size)
