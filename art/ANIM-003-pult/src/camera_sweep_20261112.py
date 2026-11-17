"""Camera-calibrated feasibility sweep. Blender -b -P this.py."""
import sys,json,inspect,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import build as m
from gltf_support import *
m.EYE=Vector((0,1.4541,-.6476))
# Updated figure origin is ship X=-2.85, console X=-4.9.
exec(inspect.getsource(m.solve).replace('-1.9-','-2.05-'),m.__dict__)
rows=[]
for sex in ['muzhchina','zhenshchina']:
 d,b=read(m.REPO/'models'/('ekipazh-'+sex+'.glb'));r,base=m.sample(d,b,'PostIdle')
 for lean in [.6,.75,.9]:
  hip=base[r.names['Hips']].translation;delta=Matrix.Translation(hip)@rot('X',-lean+math.radians(10)).to_4x4()@Matrix.Translation(-hip)
  bg={i:g.copy() for i,g in base.items()}
  for i in r.j:
   n=d['nodes'][i]['name']
   if not any(t in n for t in ['Leg','Foot','Toe']):bg[i]=delta@bg[i]
  for distance in [.15,.2,.25,.3,.35]:
   samples=[]
   for share in [0,.25,.5,.75,1]:
    try:g=m.solve(r,bg,share,distance=distance)
    except ValueError: samples.append({'share':share,'reachable':False});continue
    mask=m.mask_for(d,b,r,g,'Right');left=m.mask_for(d,b,r,g,'Left');p,_,_=m.skin(d,b,r,g)
    samples.append({'share':share,'reachable':True,'right_pixels':int(mask.sum()),'left_pixels':int(left.sum()),'table_pixels':int(mask[190:669,1660:2361].sum()),'min_vertex_eye_distance':float(np.linalg.norm(p-np.array(m.EYE),axis=1).min())})
   row={'sex':sex,'lean':lean,'distance':distance,'samples':samples};rows.append(row)
   if all(s['reachable'] for s in samples): print(sex,lean,distance,'max area',max(s['right_pixels'] for s in samples),'table',max(s['table_pixels'] for s in samples),flush=True)
(m.ROOT/'camera-sweep-20261112.json').write_text(json.dumps(rows,indent=2))
