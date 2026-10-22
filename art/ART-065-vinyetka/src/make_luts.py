from pathlib import Path
import numpy as np,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SPEC={
 'mel':{'matrix':[[.96,.015,.005],[.005,.975,.012],[.003,.008,.980]],'offset':[.003,.006,.009],'vignette':.18},
 'sredniy':{'matrix':[[.90,.025,.010],[.005,.955,.020],[.005,.020,.957]],'offset':[.002,.009,.018],'vignette':.26},
 'glubina':{'matrix':[[.82,.035,.015],[.008,.88,.040],[.008,.045,.925]],'offset':[.002,.008,.022],'vignette':.34},
 'il':{'matrix':[[.84,.060,.015],[.025,.870,.035],[.025,.060,.850]],'offset':[.009,.014,.010],'vignette':.38}}
def lut(matrix,offset):
 y,x=np.mgrid[0:16,0:256]
 rgb=np.stack([x%16,y,x//16],axis=-1)/15
 return np.rint(np.clip(rgb@np.array(matrix).T+offset,0,1)*255).astype('uint8')
if __name__=='__main__':
 for name,s in SPEC.items():
  Image.fromarray(lut(s['matrix'],s['offset']),'RGB').save(ROOT/f'lut-{name}.png',optimize=True)
 (ROOT/'lut-spec.json').write_text(json.dumps(SPEC,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('Four LUTs; disk bytes:',sum((ROOT/f'lut-{n}.png').stat().st_size for n in SPEC))
