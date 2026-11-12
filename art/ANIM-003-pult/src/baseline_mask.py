import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import build as m
import bpy,numpy as np
rows=[]
for sex in ['muzhchina','zhenshchina']:
 d,b=m.read(m.REPO/'models'/('ekipazh-'+sex+'.glb'));r,g=m.sample(d,b,'PostIdle')
 for z in [0,-.1,-.2]:
  m.EYE=m.Vector((0,1.65,z));l=m.mask_for(d,b,r,g,'Left');right=m.mask_for(d,b,r,g,'Right');row={'sex':sex,'eye':[0,1.65,z],'left_pixels':int(l.sum()),'right_pixels':int(right.sum())};rows.append(row);print(row)
  if z==0:
   pixels=np.zeros((1080,2400,4),dtype=np.float32);pixels[:,:,:3]=(.025,.045,.065);pixels[:,:,3]=1;pixels[l,:3]=(.95,.3,.035);pixels[right,:3]=(.03,.6,.9);pixels[190:669,1660:1663,:3]=1;pixels[190:669,2358:2361,:3]=1;pixels[190:193,1660:2361,:3]=1;pixels[666:669,1660:2361,:3]=1
   im=bpy.data.images.new('mask',width=2400,height=1080);im.pixels.foreach_set(pixels[::-1].ravel());im.filepath_raw=str(m.ROOT/(sex+'-PostIdle-mask.png'));im.file_format='PNG';im.save();bpy.data.images.remove(im)
(m.ROOT/'baseline-mask.json').write_text(json.dumps(rows,indent=2))
