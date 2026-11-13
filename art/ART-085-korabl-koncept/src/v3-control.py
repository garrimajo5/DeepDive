from pathlib import Path
import math,json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
O=Path('art/ART-085-korabl-koncept');W,H=1280,720
FOV=72.;pitch=math.radians(-8); eye=np.array([0.,1.33,-11.8]); ports=[(-1.15,.4),(0,.55),(1.15,.4)]; planes=[-12.75,-13.0]
f=H/(2*math.tan(math.radians(FOV/2)))
print('CAMERA eye=',eye.tolist(),'yaw=0 pitch=-8 FOV_y=72 viewport=1280x720; planes=',planes,'distances=',[eye[2]-z for z in planes])
xx,yy=np.meshgrid(np.arange(W)+.5,np.arange(H)+.5);u=(xx-W/2)/f;v=-(yy-H/2)/f
ry=math.sin(pitch)+v*math.cos(pitch);rz=-math.cos(pitch)+v*math.sin(pitch)
visible=np.zeros((H,W),bool); inner=np.zeros((H,W),bool)
for cx,r in ports:
 masks=[]
 for z in planes:
  t=(z-eye[2])/rz; xp=t*u;yp=eye[1]+t*ry
  masks.append((xp-cx)**2+(yp-1.33)**2<=r*r)
 visible |= masks[0]&masks[1];inner|=masks[0]
# Purpose-built analytic test world; not an in-game screenshot.
world=np.empty((H,W,3),np.uint8);world[:]=[16,56,70]
tfloor=np.divide(-8-eye[1],ry,out=np.zeros_like(ry),where=ry<0)
fx=tfloor*u;fz=eye[2]+tfloor*rz
floor=(ry<0)&(tfloor>0)&(tfloor<160)
world[floor]=[67,85,86]
grid=floor&((np.mod(np.abs(fx),5)<.06)|(np.mod(np.abs(fz+11.8),5)<.06));world[grid]=[100,129,129]
img=Image.fromarray(world);dw=ImageDraw.Draw(img)
def proj(pt):
 x,y,z=np.array(pt)-eye; depth=y*math.sin(pitch)-z*math.cos(pitch);up=y*math.cos(pitch)+z*math.sin(pitch)
 return W/2+f*x/depth,H/2-f*up/depth,depth
# Landmark geometric calibration monolith, not new game location.
land=[(-1,-8,-42),(1,-8,-42),(1,-2,-42),(-1,-2,-42)]
dw.polygon([proj(p)[:2] for p in land],fill='#d9ad69',outline='#fff2ca')
# Approaching creature proxy, 1.5 m ellipsoid; no new species design.
p=proj((-5,0,-30));rad=f*.75/p[2];dw.ellipse((p[0]-rad,p[1]-rad*.45,p[0]+rad,p[1]+rad*.45),fill='#73e3e4',outline='white')
# Overlay solid frame and barrel: rays must clear both apertures.
a=np.array(img);a[~visible]=[75,80,80];a[inner&~visible]=[36,45,49]
# margin of inner rim rendered geometrically at near plane
for cx,r in ports:
 t=(planes[0]-eye[2])/rz; q=(t*u-cx)**2+(eye[1]+t*ry-1.33)**2
 rim=(q>(r*r))&(q<(r+.085)**2);a[rim]=[130,124,107]
img=Image.fromarray(a);dw=ImageDraw.Draw(img)
# console actual projected top plane below main aperture
console=[(-.65,.85,-12.35),(.65,.85,-12.35),(.65,.85,-12.65),(-.65,.85,-12.65)]
dw.polygon([proj(p)[:2] for p in console],fill='#9b7949',outline='#e8b772')
# safe annotation labels only outside central direct view
font='C:/Windows/Fonts/arial.ttf'
def text(d,xy,s,size=23,color='#dce5e6'):d.text(xy,s,font=ImageFont.truetype(font,size),fill=color)
text(dw,(20,18),'КОНТРОЛЬНАЯ ПРОЕКЦИЯ · НЕ СКРИНШОТ ИГРЫ',19)
# Targets: analytic checks through all planes
def test(pt):
 q=np.array(pt)-eye
 for cx,r in ports:
  if all((q[0]*((z-eye[2])/q[2])-cx)**2+(eye[1]+q[1]*((z-eye[2])/q[2])-1.33)**2<=r*r for z in planes):
   px,py,dep=proj(pt);return bool(dep>0 and 0<=px<W and 0<=py<H)
 return False
checks={name:{'xyz':pt,'visible':test(pt)} for name,pt in [('bottom25m',[0,-8,-36.8]),('landmark_top',[0,-2,-42]),('creature_center',[-5,0,-30]),('near_bottom10m',[0,-8,-21.8]),('side_creature',[12,0,-30])]}
print(json.dumps(checks))
assert checks['bottom25m']['visible'] and checks['landmark_top']['visible'] and checks['creature_center']['visible']
assert not checks['near_bottom10m']['visible']
sheet=Image.new('RGB',(2048,1152),'#0b1c24');d=ImageDraw.Draw(sheet)
text(d,(58,28),'04 / ПИЛОТ · КОНТРОЛЬ ПРЯМОГО ОБЗОРА',44)
text(d,(60,89),'ART-085 v3 · Поле зрения игры, явные рамы и условная контрольная сцена',24,'#8fa6ad')
sheet.paste(img,(60,175));d.rectangle((59,174,1340,895),outline='#67ddeb',width=2)
lines=['Глаз: (0; 1,33; −11,80) м','Курс 0°; наклон −8°','FOV: 72° по вертикали','104,3° по горизонтали','Кадр слева: 1280 × 720','Порты: Ø1,1 / 0,8 / 0,8 м','Центры: x=0 / ±1,15; y=1,33','Внутр. кромка z=−12,75','Внешн. кромка z=−13,00','Проход луча через обе кромки.','Дно y=−8: 3 м под полозьями.','Сетка на дне: 5 м.','Охра: ориентир в 30,2 м.','Голубой: цель в 18,2 м.','Обе цели видны напрямую.']
for i,t in enumerate(lines):text(d,(1390,180+43*i),t,23,'#e8b772' if i>11 else '#dce5e6')
for i,t in enumerate(['Дно по оси видно примерно с 20,4 м от глаза; точка в 25 м видна, в 10 м скрыта нижней рамой.', 'Рамы дают слепые сектора. Боковые цели могут закрываться: требуется поворот головы / корабля.', 'Камеры — дополнение для близкой рабочей ниши, не замена прямого вида. Дальние формы проверяются без них.', 'Это новая посадка и рамы на оценку: глаз v2 был дальше от портов. Свет, вода и модель экипажа здесь не проверены.']):text(d,(60,932+45*i),t,24,'#e8b772' if i==0 else '#dce5e6')
sheet.save(O/'04-v3-pilot-control.png')
(O/'src').mkdir(exist_ok=True)
(O/'src'/'v3-camera-check.json').write_text(json.dumps({'camera':{'eye':eye.tolist(),'yaw':0,'pitch':-8,'fov_y':72,'viewport':[W,H]},'planes':planes,'ports':ports,'checks':checks},indent=2),encoding='utf-8')
