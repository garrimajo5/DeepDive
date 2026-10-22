from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
R=Path(__file__).resolve().parents[1]
im=Image.new('RGBA',(1024,512),(0,0,0,0));d=ImageDraw.Draw(im)
F='C:/Windows/Fonts/DejaVuSansCondensed.ttf';B='C:/Windows/Fonts/DejaVuSansCondensed-Bold.ttf'
def font(n,b=False):return ImageFont.truetype(B if b else F,n)
def txt(x,y,s,n=20,c='#67DDEB',b=False):d.text((x,y),s,font=font(n,b),fill=c)
for x in [0,352,704]:
 d.rectangle((x+1,1,x+318,134),fill='#0B1C24',outline='#315C68',width=2)
 d.line((x+8,35,x+312,35),fill='#173B48',width=1)
txt(12,8,'КУРС',20,b=True)
for x in range(16,305,12):d.line((x,119 if (x-16)%48 else 111,x,126),fill='#507E88',width=2)
d.line((12,105,308,105),fill='#315C68',width=1)
txt(364,5,'ГЛУБИНА',17,b=True);txt(452,46,'м',18)
txt(364,85,'ХОД',17,b=True);txt(612,91,'м/с',18)
d.line((364,76,659,76),fill='#315C68',width=1)
for x in range(364,657,16):d.line((x,124,x,129),fill='#315C68',width=1)
txt(716,8,'СВЕТ',20,b=True);txt(716,82,'СОНАР',20,b=True)
d.line((716,72,1012,72),fill='#173B48',width=1)
d.ellipse((970,12,1002,44),outline='#315C68',width=2);d.ellipse((970,84,1002,116),outline='#315C68',width=2)
# Fixed searchlight and sonar pictograms, without status arrows or values.
d.rectangle((847,14,863,34),outline='#507E88',width=2)
for yy in [12,24,36]:d.line((870,24,892,yy),fill='#507E88',width=2)
for rr in [8,15,22]:d.arc((864-rr,100-rr,864+rr,100+rr),-65,65,fill='#507E88',width=2)
chars=list('0123456789.м°/−с')
for i,ch in enumerate(chars):
 box=d.textbbox((0,0),ch,font=font(56,True));w=box[2]-box[0];h=box[3]-box[1];d.text((i*64+(64-w)/2-box[0],384+(64-h)/2-box[1]),ch,font=font(56,True),fill='#FFFFFF')
im.save(R/'ekran-atlas.png',optimize=True)
assert (R/'ekran-atlas.png').stat().st_size<512_000
(R/'layout.json').write_text(json.dumps({'size':[1024,512],'panels':{'course':[0,0,320,136],'depth_speed':[352,0,672,136],'light_sonar':[704,0,1024,136]},'glyphs':{ch:[i*64,384,(i+1)*64,448] for i,ch in enumerate(chars)},'glyph_inner_sample':[12,0,52,64]},ensure_ascii=False,indent=2),encoding='utf8')
bg=Image.new('RGBA',im.size,'#102830');bg.alpha_composite(im);bg.convert('RGB').save(R/'source/atlas-fon.jpg',quality=95)
print('atlas', (R/'ekran-atlas.png').stat().st_size)
