"""Compose actual Blender frames into Russian-labelled review images (Pillow)."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import argparse
p=argparse.ArgumentParser();p.add_argument('--frames',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();r=a.frames;o=a.out
font='C:/Windows/Fonts/arial.ttf'
def f(n):return ImageFont.truetype(font,n)
bg='#0B1C24';white='#D5E4E8';cyan='#67DDEB'
# Three orthographic angles and tail strike, calibrated scale in side view.
im=Image.new('RGB',(1024,1024),bg);d=ImageDraw.Draw(im);d.text((24,20),'СЕРПОХВОСТ / ANIM-001',font=f(30),fill=white);d.text((24,62),'Скелет и четыре движения · принятая модель MOD-011',font=f(18),fill=cyan)
for path,label,x,y in [('rest-three.png','Общий вид',16,125),('rest-side.png','Сбоку · длина 6 м',520,125),('rest-top.png','Сверху · исходная поза',16,470),('TailStrike-pose2.png','Удар серпом · середина движения',520,470)]:
 im.paste(Image.open(r/path).convert('RGB').resize((488,275)),(x,y+32));d.text((x,y),label,font=f(18),fill=white)
# ortho width is 7.6 m -> 488/7.6 pixels per metre.
d.line((760,445,760+round(488/7.6),445),fill=cyan,width=3);d.text((760,418),'1 м',font=f(16),fill=white)
d.text((24,830),'Хвост: три кости, волна от корня к серпу.',font=f(23),fill=white)
d.text((24,867),'Челюсть: до 35°. Плавники: мягкая коррекция.',font=f(23),fill=white)
d.text((24,923),'Метры · Y вверх · нос −Z · движения на месте',font=f(19),fill=cyan)
d.text((24,960),'Образец для приёмки. В игровую сцену ещё не подключён.',font=f(18),fill=white)
im.save(o/'01-preview.jpg',quality=92)
# Four key poses per action; clear side/top view makes openings visible.
im=Image.new('RGB',(1600,1120),bg);d=ImageDraw.Draw(im);d.text((24,20),'СЕРПОХВОСТ / ФАЗЫ ДВИЖЕНИЯ',font=f(32),fill=white)
labels=[('Swim','Плавание · цикл 2,4 с'),('SwimFast','Быстрое плавание · цикл 1,2 с'),('Bite','Укус · 1,2 с'),('TailStrike','Удар серпом · 0,6 с')]
for row,(name,label) in enumerate(labels):
 y=80+row*250;d.text((24,y),label,font=f(23),fill=cyan)
 for k in range(4):
  im.paste(Image.open(r/f'{name}-pose{k}.png').convert('RGB').resize((392,220)),(8+k*398,y+28))
d.text((24,1085),'Фазы: 0% / 25% / 50% / 75%. Укус и удар завершаются возвратом в исходную позу.',font=f(18),fill=white);im.save(o/'02-motion-sheet.jpg',quality=90)
frames=[]
for t in range(24):
 im=Image.new('RGB',(800,540),bg);d=ImageDraw.Draw(im);d.text((14,9),'СЕРПОХВОСТ · ЧЕТЫРЕ КЛИПА',font=f(22),fill=white)
 for i,(name,label) in enumerate(labels):
  files=sorted((r/name).glob('*.png'));x=(i%2)*400;y=43+(i//2)*248
  d.text((x+10,y),label,font=f(16),fill=cyan);im.paste(Image.open(files[(t*3//2)%len(files)]).convert('RGB').resize((400,225)),(x,y+23))
 frames.append(im.resize((560,378)).quantize(colors=64,method=Image.Quantize.MEDIANCUT))
frames[0].save(o/'03-animation.gif',save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=True,disposal=2)
print([(p.name,p.stat().st_size) for p in o.iterdir() if p.is_file()])
