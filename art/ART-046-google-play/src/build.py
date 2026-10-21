from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import sys
P=Path(__file__).resolve().parents[1]; R=P.parents[1]; D=R/'docs/concept-art'
FONT='C:/Users/FEDYA/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/share/fonts/DejaVuSans.ttf'
font=lambda s:ImageFont.truetype(FONT,s)
if len(sys.argv)>1:
 im=Image.open(sys.argv[1]).convert('RGB').resize((1008,492),Image.Resampling.LANCZOS)
 c=Image.new('RGB',(1024,500),'#0B1C24');c.paste(im,(8,4));c.save(P/'oblozhka.png',optimize=True)
 c.resize((320,156),Image.Resampling.LANCZOS).save(P/'src/proverka-320.png')
frames=[('Ведите батискаф вчетвером','mostik-vid-ot-vhoda.jpg'),('Чините пробоины вместе','proboina-mostik.jpg'),('Изучайте живую отмель','kovcheg-7-nad-rifom.jpg'),('Глубже или наверх?','golostol-brifing-mostik.jpg')]
sheet=Image.new('RGB',(3840,2160),'#0B1C24')
for n,(title,file) in enumerate(frames):
 c=Image.new('RGB',(1920,1080),'#0B1C24');d=ImageDraw.Draw(c)
 src=Image.open(D/file).convert('RGB');src=src.crop((0,0,src.width,int(src.height*.90)))
 # Exact 16:9 replacement window: no crop or stretched gameplay when swapped.
 c.paste(ImageOps.fit(src,(784,441)).resize((1568,882),Image.Resampling.NEAREST),(176,170))
 d.rectangle((176,170,1743,1051),outline='#67DDEB',width=4)
 d.text((960,78),title,font=font(66),fill='#D5E4E8',anchor='mm')
 d.rectangle((178,984,1741,1049),fill='#102B37')
 d.text((960,1016),'КОНЦЕПТ · МЕСТО ДЛЯ СНИМКА ИГРЫ',font=font(30),fill='#9AD9E8',anchor='mm')
 sheet.paste(c,((n%2)*1920,(n//2)*1080))
for colors in [160,128,96,64,48,32]:
 sheet.quantize(colors=colors,method=Image.Quantize.MEDIANCUT).save(P/'kadry-podpisi.png',optimize=True)
 if (P/'kadry-podpisi.png').stat().st_size<1000000:break
print('colors',colors)
for f in P.glob('*.png'):
 print(f.name,Image.open(f).size,f.stat().st_size);assert f.stat().st_size<1000000

