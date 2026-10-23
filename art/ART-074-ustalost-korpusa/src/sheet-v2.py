from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np, json
P=Path(__file__).resolve().parents[1]
FONT='C:/Windows/Fonts/DejaVuSansCondensed.ttf'
def f(s): return ImageFont.truetype(FONT,s)
def frame(name): return P/'source'/((name+'-v2' if name in ['engine15','eco15'] else name)+'.png')
ink='#d4e1de'; muted='#8ca9ae'; aqua='#80bdce'; amber='#e7c28b'
im=Image.new('RGB',(1600,720),'#102027');d=ImageDraw.Draw(im)
d.text((18,10),'ART-074 · «Ковчег» устал',font=f(29),fill=ink)
d.text((615,18),'Следы корпуса · Forward Mobile · без пробоины',font=f(19),fill=muted)
for n,(name,label) in enumerate([('wide70','Мостик · 70% · сухо'),('wide40','Мостик · 40% · первые следы'),('wide15','Мостик · 15% · конденсат'),('engine15','Машинное · 15% · слабая утечка')]):
 x=16+(n%2)*592;y=58+(n//2)*288
 pic=Image.open(frame(name)).convert('RGB');pic.resize((580,261),Image.Resampling.LANCZOS)
 im.paste(pic.resize((580,261),Image.Resampling.LANCZOS),(x,y+23))
 d.rectangle((x,y,x+580,y+23),fill='#20343a');d.text((x+8,y+1),label,font=f(18),fill=ink)
# Maps in ship coordinates, nose (-Z) upwards.
def room(x,y,scale,half,z0,z1,title,posts,drops,steam=None,spark=None):
 d.text((x-8,y-29),title,font=f(19),fill=ink)
 def xy(a,b):return (x+(a+half)*scale,y+(b-z0)*scale)
 d.rectangle([xy(-half,z0),xy(half,z1)],fill='#24383b',outline=muted,width=2)
 for side in [-1,1]:
  x0=xy(side*(half-.25),z0)[0]
  d.line([(x0,y+2),(x0,y+(z1-z0)*scale-2)],fill='#46605b',width=7)
 for px,pz,label in posts:
  u,v=xy(px,pz);r=scale*.65
  d.ellipse((u-r,v-r,u+r,v+r),outline='#81968a',width=1)
  d.text((u+4,v-8),label,font=f(12),fill=ink)
 for px,pz in drops:
  u,v=xy(px,pz);d.ellipse((u-3,v-3,u+3,v+3),fill=aqua)
 for item,color,letter in [(steam,muted,'П'),(spark,amber,'И')]:
  if item:
   u,v=xy(*item);d.rectangle((u-4,v-4,u+4,v+4),fill=color);d.text((u+6,v-10),letter,font=f(13),fill=color)
 d.text((x+8,y+3),'−Z ↑',font=f(13),fill=muted)
room(1235,94,29,5,-6,2,'Мостик · сверху · 10 × 8 м',[(-3.9,-2,'Э'),(3.85,-2,'С'),(0,-4.2,'Ш'),(-3.9,-.5,'З'),(0,-1.2,'О')],[(s*4.66,(.8 if s<0 and z==-.35 else z)) for s in [-1,1] for z in [-4.65,-.35,1.2]],spark=(-4.58,-.98))
room(1287,386,29,3,14,19.5,'Машинное · 6 × 5,5 м',[(-2.2,17.2,'В'),(2.2,17.2,'Щ'),(0,17.2,'Р')],[(s*2.72,z) for s in [-1,1] for z in [14.7,15.4,18.8]],steam=(-2.92,17.2))
d.text((1215,565),'● капли   И искры   П пар',font=f(17),fill=aqua)
d.text((1215,590),'Круги — посты экипажа',font=f(16),fill=muted)
d.text((1215,614),'Влажный пол — у бортов',font=f(16),fill=muted)
d.text((18,651),'Ремонт: искры → пар → капли → сухие стены. Окна, экраны и щиток остаются чистыми.',font=f(20),fill=ink)
d.text((18,684),'24 карточки / 12 «Экономно» · 1 вызов частиц · 0 новых вызовов для потёков · 0 новых источников света',font=f(17),fill=muted)
im.save(P/'ustalost-list-v2.png',optimize=True)
# Straight alpha / data-channel diagnostic, no repainted scenes.
proof=Image.new('RGB',(1600,900),'#102027');dr=ImageDraw.Draw(proof)
dr.text((18,12),'ART-074 · материал и частицы крупно',font=f(28),fill=ink)
a=Image.open(P/'ustalost-atlas.png')
checker=Image.new('RGBA',(512,512),(42,53,58,255));cd=ImageDraw.Draw(checker)
for y in range(0,512,16):
 for x in range(0,512,16):
  if (x//16+y//16)%2:cd.rectangle((x,y,x+15,y+15),fill=(54,66,71,255))
checker.alpha_composite(a);proof.paste(checker.convert('RGB'),(18,65))
dr.text((18,585),'0–3 капли · 4–7 искры · 8–15 пар',font=f(20),fill=ink)
mask=Image.open(P/'ustalost-maska.png')
for i,label in enumerate(['R · потёки','G · влажный пол','B · потеря корпуса']):
 ch=mask.getchannel(i).resize((240,240),Image.Resampling.NEAREST)
 proof.paste(ch.convert('RGB'),(560+i*252,65));dr.text((560+i*252,317),label,font=f(18),fill=ink)
for i,(name,label) in enumerate([('spark15','Редкая искра у пульта'),('engine15','Конденсат и пар'),('eco15','«Экономно» · 12 карточек')]):
 pic=Image.open(frame(name)).convert('RGB')
 pic=pic.crop((620,280,1020,540) if name=='spark15' else (0,100,1600,650)).resize((490,168),Image.Resampling.LANCZOS)
 proof.paste(pic,(18+i*524,655));dr.text((18+i*524,832),label,font=f(19),fill=ink)
dr.text((560,360),'Плитка 1 × 1 м · линейные RGB-данные',font=f(20),fill=ink)
dr.text((560,391),'Края R/G/B совпадают. Атлас: straight alpha, отступ 12 px.',font=f(18),fill=muted)
dr.text((560,428),'Переход кадров — в premultiplied space, затем straight alpha.',font=f(18),fill=muted)
dr.text((560,466),'Материал: влажный тёмный след + гладкая плёнка, без свечения.',font=f(18),fill=muted)
dr.text((560,503),'Искры: тёплый белый / янтарь, без красного света.',font=f(18),fill=muted)
proof.save(P/'ustalost-proverka-v2.png',optimize=True)
for name in ['engine15-v2','eco15-v2','engine15-v2-control']:
 Image.open(P/'source'/f'{name}.png').convert('RGB').save(P/'source'/f'{name}.jpg',quality=94,subsampling=0)
Image.open(P/'source/engine15-control.png').convert('RGB').save(P/'source/legacy-valve-control-v2.jpg',quality=94,subsampling=0)
# Numeric validation of data maps, padding, monotonic repair response.
m=np.asarray(mask); ar=np.asarray(a)
assert np.array_equal(m[0],m[-1]) and np.array_equal(m[:,0],m[:,-1])
for i in range(16):
 tile=ar[i//4*128:(i//4+1)*128,i%4*128:(i%4+1)*128,3]
 assert not tile[:10].any() and not tile[-10:].any() and not tile[:,:10].any() and not tile[:,-10:].any()
b=m[:,:,2]/255
amounts=[]
for hull in [100,70,40,15,0]:
 t=np.clip(((1-hull/100)-b)/.14,0,1);gate=t*t*(3-2*t)
 amounts.append({'hull':hull,'mean_R_weight':float(np.mean(gate*m[:,:,0]/255)),'mean_G_weight':float(np.mean(gate*m[:,:,1]/255))})
assert all(amounts[i]['mean_R_weight']<=amounts[i+1]['mean_R_weight'] for i in range(4))
assert amounts[0]['mean_R_weight']==amounts[1]['mean_R_weight']==0
report={'seam_error':0,'alpha_border_max':0,'mask':list(mask.size),'atlas':list(a.size),'repair_weights':amounts,'captures':{}}
for name in ['wide70','wide40','wide15','engine15','eco15','spark15']:
 metrics=json.loads((P/'source'/f'{name+"-v2" if name in ["engine15","eco15"] else name}-metrics.json').read_text())
 assert metrics['surface_only']==metrics['baseline']
 assert metrics['after']-metrics['baseline']<=1
 assert metrics['cards']<=24
 report['captures'][name]=metrics
for file in list(P.glob('*.png'))+list((P/'source').glob('*.jpg')):
 assert file.stat().st_size<2*1024*1024,(file,file.stat().st_size)
(P/'source/validation-v2.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False,indent=2))
