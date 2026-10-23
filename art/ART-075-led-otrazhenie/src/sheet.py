from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json
P=Path(__file__).resolve().parents[1]
font='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
def f(n):return ImageFont.truetype(font,n)
ink='#d4e1de';muted='#8ca9ae'
im=Image.new('RGB',(1600,720),'#102027');d=ImageDraw.Draw(im)
d.text((16,5),'ART-075 · лёд снизу: светлое окно и тёмная отражающая гладь',font=f(23),fill=ink)
d.text((1265,8),'0 новых вызовов · 2 выборки',font=f(17),fill=muted)
for row,(name,label) in enumerate([('bridge8','Мостик · 8 м · взгляд вверх'),('flyby8','Начало спуска · облёт · 8 м'),('bridge30','Мостик · 30 м · эффект затухает')]):
 y=36+row*226
 for col,suffix in enumerate(['','-control']):
  x=16+col*792
  pic=Image.open(P/'source'/f'{name}{suffix}.png').convert('RGB')
  crop=(0,20,1600,440) if name.startswith('flyby') else (0,170,1600,590)
  im.paste(pic.crop(crop).resize((784,206),Image.Resampling.LANCZOS),(x,y+20))
  d.text((x+5,y),('С эффектом · ' if col==0 else 'Без эффекта · ')+label,font=f(17),fill=ink)
im.save(P/'otrazhenie-list.png',optimize=True)
proof=Image.new('RGB',(1600,900),'#102027');dr=ImageDraw.Draw(proof)
dr.text((18,12),'ART-075 · окно Снелля, карты и затухание',font=f(28),fill=ink)
lut=np.asarray(Image.open(P/'otrazhenie-gradient.png'))
v=lut[:,:,:3]/255;v=np.where(v<=.0031308,v*12.92,1.055*v**(1/2.4)-.055)
proof.paste(Image.fromarray(np.uint8(np.clip(v*255,0,255))).resize((512,160),Image.Resampling.NEAREST),(18,90))
dr.text((18,61),'RGB LUT · здесь показан перевод linear → sRGB',font=f(17),fill=ink)
for yy,depth in [(0,0),(3,8),(7,20),(11,45),(15,90)]:dr.text((535,90+yy*10),str(depth),font=f(12),fill=muted)
proof.paste(Image.fromarray(lut[:,:,3]).convert('RGB').resize((512,64),Image.Resampling.NEAREST),(18,288))
dr.text((18,260),'A · доля отражения: косинус 0 → 1',font=f(18),fill=ink)
proof.paste(Image.open(P/'otrazhenie-maska.png').convert('RGB').resize((256,256)),(18,398))
dr.text((18,369),'Гладкость · 16 × 16 м',font=f(18),fill=ink)
x0,y0=306,417;ww,hh=224,202
dr.rectangle((x0,y0,x0+ww,y0+hh),outline=muted)
curve=lut[3,:,3]/255
pts=[(x0+i/255*ww,y0+(1-a)*hh) for i,a in enumerate(curve)]
dr.line(pts,fill='#80BDCE',width=2)
crit=.6614378;xx=x0+crit*ww;dr.line((xx,y0,xx,y0+hh),fill='#627C83',width=1)
dr.text((x0,y0+hh+8),'0     cos θ      1',font=f(17),fill=muted)
dr.text((310,373),'8 м · коэффициент A',font=f(17),fill=ink)
dr.text((325,660),'48,59° · cos 0,6614',font=f(17),fill=muted)
openpic=Image.open(P/'source/open8.png').convert('RGB')
proof.paste(openpic.resize((1020,459),Image.Resampling.LANCZOS),(565,79))
dr.text((565,49),'Внешняя проверка · 8 м · полный угол без крыши мостика',font=f(19),fill=ink)
for i,(name,label) in enumerate([('eco8','Экономно · 1 выборка'),('bridge45','45 м · почти исчезло'),('silt8','Ил · отражение выключено')]):
 x=565+i*342;pic=Image.open(P/'source'/f'{name}.png').convert('RGB')
 proof.paste(pic.crop((0,170,1600,670)).resize((330,148),Image.Resampling.LANCZOS),(x,589))
 dr.text((x,561),label,font=f(16),fill=ink)
dr.text((18,770),'Полное внутреннее отражение у горизонта · светлое окно сверху · трещины пропускают свет',font=f(23),fill=ink)
dr.text((18,812),'Один материал льда · 0 новых мешей / камер / проб · без SSR · нормали ART-056 сохранены',font=f(21),fill=muted)
dr.text((18,852),'Линейные данные · плавная граница · прежние шахты ART-052 · карты не содержат тёплого света',font=f(20),fill=muted)
proof.save(P/'otrazhenie-proverka.png',optimize=True)
report={'critical_degrees':48.590377890729144,'extra_calls':0,'captures':{},'seam_error':0}
m=np.asarray(Image.open(P/'otrazhenie-maska.png'));assert m.ndim==2 and np.array_equal(m[0],m[-1]) and np.array_equal(m[:,0],m[:,-1])
assert lut.shape==(16,256,4)
assert np.max(np.diff(lut[:,:,3].astype(int),axis=1))<=0
assert np.max(np.diff(lut[:,:,3].astype(int),axis=0))<=0
for name in ['bridge8','flyby8','flyby','bridge30','open8','eco8','bridge45','silt8']:
 data=json.loads((P/'source'/f'{name}-metrics.json').read_text())
 assert data['baseline']==data['after']==data['zero_gain']
 a=np.asarray(Image.open(P/'source'/f'{name}.png')).astype(float)
 z=np.asarray(Image.open(P/'source'/f'{name}-zero.png')).astype(float)
 b=np.asarray(Image.open(P/'source'/f'{name}-control.png')).astype(float)
 # Same geometry/shading, mirror effect compared with proposed shader at gain zero.
 roi=(slice(220,540),slice(330,1270),slice(0,3))
 data['effect_vs_zero_roi_mae']=float(np.abs(a[roi]-z[roi]).mean())
 data['control_vs_zero_roi_mae']=float(np.abs(b[roi]-z[roi]).mean())
 report['captures'][name]=data
 for suffix in ['', '-control']:
  Image.open(P/'source'/f'{name}{suffix}.png').convert('RGB').save(P/'source'/f'{name}{suffix}.jpg',quality=94,subsampling=0)
for path in list(P.glob('*.png'))+list((P/'source').glob('*.jpg')):assert path.stat().st_size<2*1024*1024,(path,path.stat().st_size)
(P/'source/validation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report,indent=2))
