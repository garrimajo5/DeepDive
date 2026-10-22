from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,re,sys
P=Path(sys.argv[1]);F='C:/Windows/Fonts/DejaVuSansCondensed.ttf';B='C:/Windows/Fonts/DejaVuSansCondensed-Bold.ttf'
def font(s,b=False):return ImageFont.truetype(B if b else F,s)
def frame(tag,mode):
 im=Image.open(P/'source'/f'{tag}-{mode}.png').convert('RGB');x=(im.width-1600)//2;y=(im.height-720)//2
 return im.crop((x,y,x+1600,y+720))
shots=[('front','Мостик · к носовому окну'),('back','Мостик · к постам и выходу'),('engine','Машинное · реактор и рабочая зона'),('cargo','Трюм · от кормового прохода')]
for tag,title in shots:
 for mode in ['base','event-base','normal','alarm','dim']:
  im=frame(tag,mode);im.save(P/'source'/f'{tag}-{mode}.jpg',quality=93)
  if mode in ['normal','alarm']:im.save(P/f'svet-{tag}-{mode}.jpg',quality=95)
 pair=Image.new('RGB',(3200,770),'#0B1C24');d=ImageDraw.Draw(pair)
 pair.paste(frame(tag,'normal'),(0,50));pair.paste(frame(tag,'alarm'),(1600,50))
 d.text((24,8),title+' · обычный',font=font(30,True),fill='#E6FBFF');d.text((1624,8),'аварийный · пик янтарного импульса',font=font(30,True),fill='#FFB259')
 pair.save(P/f'svet-{tag}-para.jpg',quality=93)
# Overview, retain full-res native frames separately.
canvas=Image.new('RGB',(3200,3160),'#0B1C24');d=ImageDraw.Draw(canvas)
d.text((32,18),'СВЕТ ВНУТРИ · ОБЫЧНЫЙ И АВАРИЙНЫЙ РЕЖИМ',font=font(45,True),fill='#E6FBFF')
d.text((32,80),'7 рабочих источников · тени плафонов выключены · без новых огней',font=font(30),fill='#B1D1D8')
d.text((32,128),'Слева обычный режим, справа аварийный. Полные кадры 1600 × 720 — отдельно.',font=font(29),fill='#B1D1D8')
for index,(tag,title) in enumerate(shots):
 y=225+index*730
 canvas.paste(frame(tag,'normal'),(0,y));canvas.paste(frame(tag,'alarm'),(1600,y))
 d.rectangle((0,y,3200,y+45),fill='#0B1C24');d.text((22,y+4),title,font=font(30,True),fill='#E6FBFF');d.text((1622,y+4),'АВАРИЯ · холодная опора + янтарная пульсация',font=font(30,True),fill='#FFB259')
canvas.save(P/'svet-list.png',optimize=True)
while (P/'svet-list.png').stat().st_size>2_000_000:
 canvas=canvas.resize((int(canvas.width*.9),int(canvas.height*.9)),Image.Resampling.LANCZOS);canvas.save(P/'svet-list.png',optimize=True)
# Control of the same interior with the exterior searchlight on.
for mode in ['base','event-base','normal','alarm','dim']:
 frame('front-on',mode).save(P/'source'/f'front-on-{mode}.jpg',quality=93)
# Two phases where the alarm board is not in view.
phase=Image.new('RGB',(3200,810),'#0B1C24');pd=ImageDraw.Draw(phase)
phase.paste(frame('back','dim'),(0,70));phase.paste(frame('back','alarm'),(1600,70))
pd.text((24,12),'t = 0 · нижняя яркость',font=font(32,True),fill='#B1D1D8');pd.text((1624,12),'t = 0,6 с · верхняя яркость',font=font(32,True),fill='#FFB259');phase.save(P/'svet-ritm.jpg',quality=94)
v={'plafon':{'size':[256,256],'mode':Image.open(P/'plafon.png').mode,'bytes':(P/'plafon.png').stat().st_size},'sheet_size':canvas.size,'sheet_bytes':(P/'svet-list.png').stat().st_size,'lights_regular':7,'previews':{}}
for tag,title in shots:
 log=(P/f'{tag}.log').read_text(encoding='utf8');assert 'ERROR:' not in log,log
 v['previews'][tag]=[line for line in log.splitlines() if 'draws' in line]
 values={k:float(re.search(pat,log).group(1)) for k,pat in [('base',r'BASE draws ([0-9.]+)'),('normal',r'NORMAL draws ([0-9.]+)'),('event',r'EVENT baseline draws ([0-9.]+)'),('alarm',r'ALARM draws ([0-9.]+)')]}
 assert values['base']==values['normal'],values
 assert values['event']==values['alarm'],values
 v['previews'][tag+'_comparison']=values
assert Image.open(P/'plafon.png').getchannel('A').getextrema()==(0,255)
for f in P.rglob('*'):
 if f.is_file() and f.suffix.lower() in ['.jpg','.png'] and not (f.parent==P/'source' and f.suffix=='.png'):
  assert f.stat().st_size<=2_000_000,(f,f.stat().st_size)
(P/'validation.json').write_text(json.dumps(v,indent=2,ensure_ascii=False),encoding='utf8')
print('sheet',canvas.size,v['sheet_bytes'])
