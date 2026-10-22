from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,hashlib
R=Path(__file__).resolve().parents[1];rows=json.loads((R/'parametry.json').read_text());depths=np.array([r['depth'] for r in rows])
def linear(x):return np.where(x<=.04045,x/12.92,((x+.055)/1.055)**2.4)
def srgb(x):return np.where(x<=.0031308,12.92*x,1.055*x**(1/2.4)-.055)
colors=np.array([[int(r['fog'][i:i+2],16)/255 for i in [0,2,4]] for r in rows]);c=linear(colors)
d=np.linspace(0,120,64);rgb=srgb(np.stack([np.interp(d,depths,c[:,i]) for i in range(3)],-1))
rgb=np.uint8(np.rint(np.clip(rgb,0,1)*255));a=np.repeat(rgb[:,None,:],1024,axis=1);Image.fromarray(a).save(R/'voda-palitra.png',optimize=True)
assert np.array_equal(a[0,0],[58,129,144]);assert np.array_equal(a[-1,0],[4,13,23]);assert (R/'voda-palitra.png').stat().st_size<64_000
F='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
sheet=Image.new('RGB',(3200,1680),'#0B1C24');dr=ImageDraw.Draw(sheet)
def txt(x,y,s,n=30,c='#D5E4E8'):dr.text((x,y),s,font=ImageFont.truetype(F,n),fill=c)
txt(20,12,'ART-059 · ВОДА ПО ГЛУБИНЕ · ПРИМЕРКА ПАЛИТРЫ',42)
for i,depth in enumerate([8,20,45,90]):
 x=(i%2)*1600;y=75+(i//2)*790
 row=next(r for r in rows if r['depth']==depth)
 txt(x+20,y,f"{depth} м · туман #{row['fog']} · рассеянный свет {row['ambient']}",32,'#9AD9E8')
 im=Image.open(R/f'source/{depth}-new.png').convert('RGB');assert im.size==(1600,720);sheet.paste(im,(x,y+45))
txt(20,1650,'Настоящие кадры с временными параметрами Environment. 45 и 90 м — на более глубоком склоне; код игры не изменён.',25,'#9AD9E8')
sheet.save(R/'voda-kadry.jpg',quality=94)
# Labelled technical chart, separate from the exact LUT.
proof=Image.new('RGB',(1536,768),'#0B1C24');dr=ImageDraw.Draw(proof)
dr.text((25,15),'ПАЛИТРА 0–120 м · глубина сверху вниз',font=ImageFont.truetype(F,34),fill='#D5E4E8')
proof.paste(Image.fromarray(a).resize((320,640),Image.Resampling.BILINEAR),(25,80))
for idx,row in enumerate(rows):
 yy=80+row['depth']/120*640
 dr.line((345,yy,375,yy),fill='#D5E4E8',width=2);dr.text((390,85+idx*60),f"{row['depth']:3} м   #{row['fog']}   плотность {row['density']:.4f}   экспозиция {row['exposure']:.3f}",font=ImageFont.truetype(F,23),fill='#D5E4E8')
proof.save(R/'voda-proverka.png',optimize=True)
report={'lut_size':[1024,64],'orientation':'V top=0m bottom=120m, U constant','interpolation':'linear-light RGB, bilinear LUT','bytes':(R/'voda-palitra.png').stat().st_size,'sha256':hashlib.sha256((R/'voda-palitra.png').read_bytes()).hexdigest(),'max_adjacent_row_step':int(np.max(np.abs(np.diff(a[:,0,:].astype(int),axis=0)))),'luminance_monotone':bool(np.all(np.diff(linear(a[:,0,:]/255)@np.array([.2126,.7152,.0722]))<=0))}
assert report['luminance_monotone'];(R/'validation.json').write_text(json.dumps(report,indent=2));print(report)
