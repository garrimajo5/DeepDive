from pathlib import Path
from PIL import Image
import numpy as np,json
P=Path(__file__).resolve().parents[1]
x=np.linspace(0,1,256);rows=[0,8,14,20,32.5,45,90,None]
keys=[0,8,20,45,90];colors=['3A8190','286B80','1A4667','0D2943','05131F'];strength=[.22,.32,.48,.82,.58];lift=[1.8,1.9,2.2,3.0,3.2]
def lin(h):
 v=np.array([int(h[i:i+2],16)/255 for i in [0,2,4]])
 return np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4)
lut=np.zeros((8,256,4),float);t=np.clip((x-.15)/.8,0,1);curve=x**3.2*t*t*(3-2*t)
for j,d in enumerate(rows):
 if d is None:lut[j,:,:3]=lin('184653');continue
 c=np.array([np.interp(d,keys,[lin(h)[k] for h in colors]) for k in range(3)])*np.interp(d,keys,lift)
 lut[j,:,:3]=c;lut[j,:,3]=curve*np.interp(d,keys,strength)
Image.fromarray(np.uint8(np.clip(lut*255,0,255)),'RGBA').save(P/'obodok-gradient.png',optimize=True)
data={'rows_m':rows,'row_7':'silt','depth_keys':keys,'water_srgb':colors,'strength':strength,'linear_light_multiplier':lift,'x':'1-dot(Ngeo,V)','ao':'procedural: existing seam mask plus HullPlan contacts','new_texture_samples':1,'ao_weights':{'seam':.18,'contacts':.34,'min':.55,'albedo_influence':.55,'light_affect':.15,'damage_protection':.8,'eco_contacts':False},'contacts':{'mounts':{'center_abs_x_y_z':[3.45,1,26.3],'half_size':[.75,.225,.7],'feather_m':.18},'recesses':{'center_abs_x_y_z':[5.4,1,26.5],'radius_start':1.0,'radius_end':1.29,'z_width':.72},'rudder_roots':{'center_abs_x_y_z':[3.95,2.6,24.6],'width':[.28,.3,1]},'stabilizer_upper':{'center':[0,3.42,25],'width':[.28,.25,1.3]},'stabilizer_lower':{'center':[0,-.2,25],'width':[.25,.24,1.1]}}}
(P/'obodok-parametry.json').write_text(json.dumps(data,indent=2),encoding='utf8')
