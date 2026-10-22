from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,sys
P=Path(sys.argv[1]);F='C:/Windows/Fonts/DejaVuSansCondensed.ttf';B='C:/Windows/Fonts/DejaVuSansCondensed-Bold.ttf'
def font(s,b=False):return ImageFont.truetype(B if b else F,s)
def frame(tag,state='new'):
 im=Image.open(P/'source'/f'{tag}-{state}.png').convert('RGB');x=(im.width-1600)//2;y=(im.height-720)//2
 return im.crop((x,y,x+1600,y+720))
for tag in ['full','slow','surface','idle']:
 for state in ['base','new']:frame(tag,state).save(P/'source'/f'{tag}-{state}.jpg',quality=93)
 frame(tag).save(P/f'sled-{tag}.jpg',quality=95)
im=Image.new('RGB',(3200,2100),'#0B1C24');d=ImageDraw.Draw(im)
d.text((32,16),'СЛЕД ВИНТОВ · НАПРАВЛЕНИЕ ХОДА И ВСПЛЫТИЕ',font=font(42,True),fill='#E6FBFF')
atlas=Image.open(P/'sled-atlas.png');bg=Image.new('RGBA',atlas.size,'#152C36');bg.alpha_composite(atlas);im.paste(bg.convert('RGB'),(32,80))
for k in range(16):
 x=32+(k%4)*128;y=80+(k//4)*128
 d.rectangle((x,y,x+127,y+127),outline='#31535E');d.text((x+5,y+3),str(k),fill='#8DAFB8',font=font(18))
for y,line in [(100,'0–7 · одиночные пузыри и пары'),(165,'8–11 · разреженные группы'),(230,'12–15 · завитки; это варианты, не анимация'),(310,'Один материал · один MultiMesh · без эмиссии'),(375,'Полный ход: 160 карточек · малый ход: 64'),(440,'Всплытие: 72 за роторами + 72 над клапанами'),(505,'Стоянка после затухания: 0 · общий потолок: 200')]:
 d.text((620,y),line,font=font(34),fill='#B1D1D8')
for tag,x,y,title in [('full',0,660,'Полный ход · взгляд с кормовой четверти'),('slow',1600,660,'Малый ход / поворот · изогнутый след'),('surface',0,1380,'Всплытие · выпуск над сервисными крышками')]:
 im.paste(frame(tag),(x,y));d.rectangle((x,y,x+1600,y+45),fill='#0B1C24');d.text((x+20,y+4),title,font=font(30,True),fill='#E6FBFF')
# Independent idle comparison at the same stern camera as full thrust.
im.paste(frame('idle').resize((800,360)),(1600,1430));d.text((1620,1385),'Стоянка · струи нет',fill='#E6FBFF',font=font(30,True))
crop=frame('full').crop((1050,250,1570,610));im.paste(crop.resize((650,450)),(2470,1450))
d.text((2470,1385),'Струя крупнее',fill='#E6FBFF',font=font(30,True))
d.text((1630,1915),'Рождение — у выхода кожуха, след остаётся в воде.',fill='#B1D1D8',font=font(29))
d.text((1630,1970),'Пузыри дрейфуют и всплывают; туман гасит их вдали.',fill='#B1D1D8',font=font(29))
d.text((1630,2025),'Три полных кадра 1600 × 720 сохранены отдельно.',fill='#67DDEB',font=font(29))
im.save(P/'sled-list.png',optimize=True)
while (P/'sled-list.png').stat().st_size>2_000_000:
 im=im.resize((int(im.width*.9),int(im.height*.9)),Image.Resampling.LANCZOS);im.save(P/'sled-list.png',optimize=True)
assert (P/'sled-list.png').stat().st_size<=2_000_000
v=json.loads((P/'validation.json').read_text())
v['previews']={tag:(P/f'{tag}.log').read_text(encoding='utf8').splitlines()[-3:] for tag in ['full','slow','surface','idle']}
base=np.array(frame('idle','base'));new=np.array(frame('idle'));v['idle_max_pixel_difference']=int(np.abs(base.astype(int)-new.astype(int)).max())
v['sheet_size']=im.size;v['sheet_bytes']=(P/'sled-list.png').stat().st_size
(P/'validation.json').write_text(json.dumps(v,indent=2,ensure_ascii=False),encoding='utf8')
print('sheet',im.size,v['sheet_bytes'],'idle delta',v['idle_max_pixel_difference'])
