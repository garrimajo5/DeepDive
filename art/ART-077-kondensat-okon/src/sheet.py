from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np, json, hashlib
P=Path('art/ART-077-kondensat-okon'); S=P/'source'
font='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
def f(n):return ImageFont.truetype(font,n)
BG='#0B1821'; FG='#D0E3E9'; DIM='#8CAAB6'; LINE='#345466'
def text(d,pos,t,n=20,col=FG):d.text(pos,t,font=f(n),fill=col)
def window(case,stage):return Image.open(S/f'{case}-{stage}.png').convert('RGB').crop((140,202,1440,515))
# Three equal pairs, crops of actual rendered window pixels. No hand-painted effect.
a=Image.new('RGB',(1600,720),BG);d=ImageDraw.Draw(a)
text(d,(20,12),'АРТ-077 · КОНДЕНСАТ И ИНЕЙ НА ОКНАХ',28)
text(d,(20,52),'БЕЗ ДОБАВЛЕННОГО СЛОЯ · СТЕКЛО АРТ-057',18,DIM)
text(d,(815,52),'С КОНДЕНСАТОМ И ИНЕЕМ',18,'#9EDCE7')
for case,label,y in [('front8','8 м · корпус 100 % · край сухой',100),('front45','45 м · корпус 100 % · холод у рамы',304),('front45h30','45 м · корпус 30 % · капель больше',508)]:
 text(d,(20,y-24),label,18)
 for x,st in [(20,'before'),(815,'after')]:
  a.paste(window(case,st).resize((740,178),Image.Resampling.LANCZOS),(x,y));d.rectangle((x,y,x+740,y+178),outline=LINE)
text(d,(20,694),'Настоящие кадры Forward Mobile · чистый центр каждого окна · 0 новых мешей, огней и вызовов',17,DIM)
a.save(P/'kondensat-list.png',optimize=True)
# A data/readability sheet: map channels, close eye positions and thermal states.
a=Image.new('RGB',(1600,900),BG);d=ImageDraw.Draw(a)
text(d,(20,12),'КАРТА ДАННЫХ · КРУПНЫЙ ПЛАН · ТАЯНИЕ',28)
mask=Image.open(P/'kondensat-maska.png'); labels=['R · высота капель','G · дорожки','B · иней','A · порог от рамы']
for i in range(4):
 x=20+i*245
 tile=mask.getchannel(i).convert('RGB').resize((220,220),Image.Resampling.NEAREST)
 a.paste(tile,(x,58));d.rectangle((x,58,x+220,278),outline=LINE)
 text(d,(x,286),labels[i],17)
for j,t in enumerate(['256 × 256 · RGBA8 · данные','Нормали из производных R/G','Центр 56 × 56 %: слой = 0','Полный: +2 выборки','Экономно: +1 выборка','Меши / огни / вызовы: +0']):text(d,(1020,65+j*35),t,21,'#A9CED7')
for case,label,x in [('close45','Близко к стеклу · 45 м · корпус 30 %',20),('turn45','Поворот головы на 12° · тот же слой',815)]:
 text(d,(x,330),label,20)
 im=Image.open(S/f'{case}-after.png').convert('RGB').crop((0,110,1600,650)).resize((765,258),Image.Resampling.LANCZOS)
 a.paste(im,(x,361));d.rectangle((x,361,x+765,619),outline=LINE)
for case,label,x in [('front45h30','Холодное стекло',20),('half45','Частичное таяние · нагрев 60°',550),('melt45','После прогрева · нагрев 85°',1080)]:
 text(d,(x,649),label,19)
 a.paste(window(case,'after').resize((500,120),Image.Resampling.LANCZOS),(x,683));d.rectangle((x,683,x+500,803),outline=LINE)
text(d,(20,831),'Таяние показано в установившихся состояниях. Переходы: 6–30 с, без мигания и прокрутки текстуры.',20,DIM)
text(d,(20,862),'Вода и блики АРТ-067 остаются в сцене; новые цветовые акценты — только холодные.',18,DIM)
a.save(P/'kondensat-proverka.png',optimize=True)
# Full native frames retained as JPEG for review; PNG intermediates are reproducible, ignored.
metrics={}
for m in sorted(S.glob('*-metrics.json')):
 case=m.name.removesuffix('-metrics.json');j=json.loads(m.read_text());metrics[case]=j
 for stage in ['before','after']:
  Image.open(S/f'{case}-{stage}.png').convert('RGB').save(S/f'{case}-{stage}.jpg',quality=93,subsampling=0,optimize=True)
 before=np.array(Image.open(S/f'{case}-before.png').convert('RGB')).astype(float)
 after=np.array(Image.open(S/f'{case}-after.png').convert('RGB')).astype(float)
 zero=np.array(Image.open(S/f'{case}-zero.png').convert('RGB')).astype(float)
 # Only the forward standing camera projects this exact clean centre ROI.
 if case in ['front8','front45','front45h30','melt45','half45','eco45']:
  roi=(slice(290,430),slice(710,885))
  j['analysis']={'clean_roi_xywh':[710,290,175,140], 'after_vs_before_mae_255':float(np.abs(after[roi]-before[roi]).mean()),'zero_vs_before_mae_255':float(np.abs(zero[roi]-before[roi]).mean())}
assert all(v['stages']['before']['draws']==v['stages']['after']['draws']==v['stages']['zero']['draws'] for v in metrics.values())
maskarr=np.array(mask);y,x=np.mgrid[0:256,0:256]/255;clean=(x>=.22)&(x<=.78)&(y>=.22)&(y<=.78)
assert mask.mode=='RGBA' and mask.size==(256,256)
assert maskarr[clean,:3].max()==0 and maskarr[clean,3].min()==255
validation={'base_main':'6ba73eec066e9ac696bf670bef12f12098469e49','mask_mode':mask.mode,'mask_size':mask.size,'mask_file_bytes':(P/'kondensat-maska.png').stat().st_size,'mask_raw_bytes':256*256*4,'mask_with_mips_bytes':sum((2**n)**2*4 for n in range(9)),'sha256':hashlib.sha256((P/'kondensat-maska.png').read_bytes()).hexdigest(),'centre_rgb_max':int(maskarr[clean,:3].max()),'centre_a_min':int(maskarr[clean,3].min()),'extra_reads_full':2,'extra_reads_eco':1,'extra_meshes':0,'extra_lights':0,'captures':metrics}
(P/'proverka.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf8')
# Inspectable contact sheet of ALL delivered native images (review aid, outside repository).
a=Image.new('RGB',(1600,8*220),BG);d=ImageDraw.Draw(a)
for i,case in enumerate(sorted(metrics)):
 for k,stage in enumerate(['before','after']):
  a.paste(Image.open(S/f'{case}-{stage}.jpg').resize((780,175)),(10+k*800,i*220+30));text(d,(10+k*800,i*220+4),case+' / '+stage,19)
a.save('C:/Users/FEDYA/.codex/visualizations/art077-all.jpg',quality=90)
print(json.dumps({'captures':[(k,v['stages']['before']['draws'],v.get('analysis')) for k,v in metrics.items()],'files':[(p.name,p.stat().st_size) for p in P.glob('*.png')]},ensure_ascii=False))
