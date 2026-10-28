from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import sys
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1])
im=Image.open(source).convert('RGBA')
files=['ikonka-start.png','ikonka-tihaya-zavod.png','ikonka-spusk-k-lesu.png']
for name,box in zip(files,[(0,0,738,758),(738,0,1375,758),(1375,0,2073,758)]):
    p=im.crop(box)
    a=p.getchannel('A').point(lambda v: 0 if v<8 else v)
    p.putalpha(a)
    p=p.crop(a.getbbox())
    p.thumbnail((236,236),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(256,256),(0,0,0,0))
    canvas.alpha_composite(p,((256-p.width)//2,246-p.height))
    canvas.save(out/name,optimize=True)
font=lambda size: ImageFont.truetype('C:/Windows/Fonts/arial.ttf',size)
sheet=Image.new('RGB',(2048,1152),'#0b1c24'); d=ImageDraw.Draw(sheet)
d.text((70,45),'ПОДЛЁДНЫЙ САД • ИКОНКИ МЕСТ',font=font(44),fill='#d9f5fa')
d.text((70,105),'ART-082 • новые 00 / 09 / 10 рядом с принятыми 07 / 08',font=font(26),fill='#86bccb')
items=[(out/files[0],'00 • Старт «Ковчега-7»','30 м'),(root/'docs/concept-art/ikonka-terrasa-vrat.png','07 • Терраса врат','35 м • образец'),(root/'docs/concept-art/ikonka-nablyudenie-polya.png','08 • Наблюдение поля','35 м • образец'),(out/files[1],'09 • Тихая заводь','32 м'),(out/files[2],'10 • Спуск к лесу','290 м')]
for i,(path,label,depth) in enumerate(items):
    x=70+i*390
    d.rounded_rectangle((x-10,175,x+355,555),radius=18,fill='#102b37',outline='#244957',width=2)
    icon=Image.open(path).convert('RGBA')
    sheet.paste(icon,(x+45,200),icon)
    d.text((x+172,480),label,anchor='mm',font=font(25),fill='#d9f5fa')
    d.text((x+172,522),depth,anchor='mm',font=font(22),fill='#86bccb')
    small=icon.resize((70,70),Image.Resampling.LANCZOS)
    sheet.paste(small,(x+137,660),small)
    light=Image.new('RGB',(100,100),'#b9dce4'); light.paste(small,(15,15),small)
    sheet.paste(light,(x+122,800))
d.text((70,594),'ПРОВЕРКА 70 × 70 px • тёмный фон',font=font(24),fill='#86bccb')
d.text((70,752),'ПРОВЕРКА 70 × 70 px • светлый фон',font=font(24),fill='#86bccb')
d.text((70,966),'Файлы: 256 × 256 RGBA • прозрачный фон • без номера внутри иконки',font=font(28),fill='#d9f5fa')
d.text((70,1016),'Миниатюры условные: глубины относятся к положению корабля, не к размеру значка.',font=font(24),fill='#86bccb')
d.text((70,1060),'Проверка здесь — в пикселях; видимость голограммы высотой 0,13 м проверяется при встраивании в игру.',font=font(23),fill='#86bccb')
sheet.save(out/'04-sravnenie.png',optimize=True)
for path in sorted(out.glob('*.png')):
    pic=Image.open(path)
    print(path.name,pic.size,pic.mode,path.stat().st_size)
    assert path.stat().st_size<2_000_000
    if path.name.startswith('ikonka-'):
        assert pic.size==(256,256) and pic.mode=='RGBA'
        a=pic.getchannel('A')
        assert all(a.getpixel((x,y))==0 for x in range(256) for y in (0,255))
        assert all(a.getpixel((x,y))==0 for y in range(256) for x in (0,255))
        print('alpha bounds',a.getbbox())
