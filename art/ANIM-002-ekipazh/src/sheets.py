from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
R=Path(__file__).resolve().parents[1];D=R/'renders'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
def label(im,text,xy=(16,10),fill='#e5edf2',f=font):ImageDraw.Draw(im).text(xy,text,font=f,fill=fill)
def img(sex,clip,f,view):return Image.open(D/f'{sex}-{clip}-{f}-{view}.png').convert('RGB')
a=Image.new('RGB',(1320,1120),'#101a22')
label(a,'ANIM-002 · ЧЕРНОВИК · исходная A-поза, 1,8 м',fill='#eab46b')
for row,sex in enumerate(['muzhchina','zhenshchina']):
 for col,view in enumerate(['front','side','back']):
  tile=Image.open(D/f'{sex}-rest-{view}.png').convert('RGB');dr=ImageDraw.Draw(tile)
  dr.line((25,477,25,43),fill='#9ad9e8',width=2)
  for h in [0,.6,1.2,1.8]:
   y=477-h/1.8*434;dr.line((20,y,30,y),fill='#9ad9e8',width=2);dr.text((34,y-12),str(h)+' м',font=small,fill='#9ad9e8')
  a.paste(tile,(col*440,40+row*540))
a.save(R/'01-preview.jpg',quality=88)
titles={'Idle':'Покой','Walk':'Ходьба — проверка подошв НЕ пройдена','SitIdle':'В кресле','PostIdle':'У пульта'}
for clip,count in [('Idle',120),('Walk',24),('SitIdle',120),('PostIdle',120)]:
 sheet=Image.new('RGB',(1760,2190),'#101a22')
 label(sheet,'ЧЕРНОВИК · '+titles[clip]+' · 0 / 25 / 50 / 75 %',fill='#eab46b')
 for row,(sex,view) in enumerate([(s,v) for s in ['muzhchina','zhenshchina'] for v in ['three','side']]):
  for col,f in enumerate([0,count//4,count//2,count*3//4]):
   tile=img(sex,clip,f,view);label(tile,('Мужчина' if sex=='muzhchina' else 'Женщина')+' · '+str(col*25)+' %',f=small)
   sheet.paste(tile,(col*440,50+row*535))
 sheet.save(R/('02-phases-'+clip+'.jpg'),quality=86)
for clip,count,step,ms in [('Walk',24,1,33),('Idle',120,6,200)]:
 frames=[]
 for f in range(0,count,step):
  a=Image.new('RGB',(660,430),'#101a22');label(a,'ЧЕРНОВИК · '+titles[clip],f=small,fill='#eab46b')
  for col,sex in enumerate(['muzhchina','zhenshchina']):
   tile=img(sex,clip,f,'three').resize((330,390),Image.Resampling.LANCZOS);a.paste(tile,(col*330,40))
  frames.append(a.quantize(colors=96))
 frames[0].save(R/(clip+'.gif'),save_all=True,append_images=frames[1:],duration=([30,30,40]*8 if clip=="Walk" else ms),loop=0,optimize=True)
for p in list(R.glob('*.jpg'))+list(R.glob('*.gif')):
 print(p.name,p.stat().st_size);assert p.stat().st_size<=2000000
