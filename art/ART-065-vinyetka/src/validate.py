from pathlib import Path
import numpy as np,json,re
from PIL import Image
from make_luts import SPEC,lut
P=Path(__file__).resolve().parents[1]
rng=np.random.default_rng(450);c=rng.random((100000,3));reports={}
for name,s in SPEC.items():
 a=np.asarray(Image.open(P/f'lut-{name}.png')).astype(float)/255
 z=np.floor(c[:,2]*15+.5);x=c[:,0]*15;y=c[:,1]*15
 x0=np.floor(x).astype(int);x1=np.minimum(x0+1,15);y0=np.floor(y).astype(int);y1=np.minimum(y0+1,15);zb=(16*z).astype(int)
 tx=(x-x0)[:,None];ty=(y-y0)[:,None]
 g=(a[y0,zb+x0]*(1-tx)+a[y0,zb+x1]*tx)*(1-ty)+(a[y1,zb+x0]*(1-tx)+a[y1,zb+x1]*tx)*ty
 g+=np.array(s['matrix'])[:,2]*(c[:,2]-z/15)[:,None]
 exact=c@np.array(s['matrix']).T+s['offset'];err=float(np.max(np.abs(g-exact)));assert err<=.5/255+1e-10,(name,err)
 reports[name]={'max_error_in_8bit_codes':err*255,'size':[256,16],'disk_bytes':(P/f'lut-{name}.png').stat().st_size}
assert np.array_equal(lut(np.eye(3),[0,0,0])[0,:16,0],np.arange(16)*17)
frames={}
for log in sorted(P.glob('*.log')):
 if log.stem not in ['import','shader']:
  t=log.read_text(encoding='utf-8');assert 'Error' not in t and 'ERROR' not in t,t
  base=re.search(r'BASELINE_CALLS (\d+)',t);after=re.search(r'отрисовки: (\d+)',t)
  frames[log.stem]={'before_calls':int(base[1]),'after_calls':int(after[1])}
  assert int(after[1])-int(base[1])==1,(log.name,base[1],after[1])
files={f.name:f.stat().st_size for f in P.glob('*') if f.is_file() and f.suffix in ['.png','.jpg']};assert max(files.values())<2_000_000
report={'issue':450,'main':'512bd54','renderer':'Godot 4.7.2 Forward Mobile Vulkan','LUT':reports,'identity_nodes_exact':True,'random_samples_per_LUT':100000,'texture_payload_CPU_RGB8_plus_one_GPU_RGBA8_bytes':65536,'calls':frames,'files_bytes':files,'phone_checked':False}
(P/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'calls':frames,'errors':[v['max_error_in_8bit_codes'] for v in reports.values()]}))
