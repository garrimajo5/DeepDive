"""Linear Fresnel LUT and rough-ice smoothness data, ART-075."""
from pathlib import Path
from PIL import Image,ImageFilter
import numpy as np,json
P=Path(__file__).resolve().parents[1]
mu=np.linspace(0,1,256);n=4/3;ct=np.sqrt(np.maximum(0,1-n*n*(1-mu*mu)))
rs=((n*mu-ct)/(n*mu+ct+1e-10))**2;rp=((mu-n*ct)/(mu+n*ct+1e-10))**2
F=np.where(n*n*(1-mu*mu)>=1,1,(rs+rp)/2)
F=np.asarray(Image.fromarray(np.uint8(F[None,:]*255)).filter(ImageFilter.GaussianBlur(1.8)))[0]/255
keys_y=np.array([0,3,7,11,15]);keys_d=np.array([0,8,20,45,90]);gains=np.array([.92,.85,.42,.012,0])
colors=['204D5B','193F50','102D43','091C2D','04101B']
def lin(c):
 v=np.array([int(c[i:i+2],16)/255 for i in [0,2,4]])
 return np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4)
lut=np.zeros((16,256,4),float)
for y in range(16):
 dep=np.interp(y,keys_y,keys_d);gain=np.interp(dep,keys_d,gains)
 col=np.array([np.interp(dep,keys_d,[lin(c)[k] for c in colors]) for k in range(3)])
 bottom=np.exp(-((mu-.43)/.22)**2)
 lut[y,:,:3]=col[None,:]*(.78+.22*bottom[:,None]);lut[y,:,3]=F*gain
Image.fromarray(np.uint8(np.clip(lut*255,0,255)),'RGBA').save(P/'otrazhenie-gradient.png',optimize=True)
normal=np.asarray(Image.open(P.parents[1]/'textures/ice/normali.png').convert('RGB').resize((512,512),Image.Resampling.LANCZOS)).astype(float)/255*2-1
rough=np.sqrt(normal[:,:,0]**2+normal[:,:,1]**2)
smooth=np.clip(1-rough*1.7,.18,1)
x,y=np.meshgrid(np.linspace(0,2*np.pi,512),np.linspace(0,2*np.pi,512))
smooth*=.72+.28*(.5+.5*np.sin(x*2+.7*np.cos(y))*np.cos(y*3))
a=np.uint8(smooth*255);a[-1]=a[0];a[:,-1]=a[:,0]
Image.fromarray(a,'L').save(P/'otrazhenie-maska.png',optimize=True)
data={'index_ratio':n,'critical_degrees':float(np.degrees(np.arcsin(1/n))),'critical_cos':float(np.sqrt(1-1/n**2)),'key_rows':keys_y.tolist(),'key_depths':keys_d.tolist(),'row_depths':np.interp(np.arange(16),keys_y,keys_d).tolist(),'reflect_gains':gains.tolist(),'colors_srgb_reference':colors,'critical_blur_texels':1.8,'linear_data':True,'tile_m':16}
(P/'otrazhenie-parametry.json').write_text(json.dumps(data,indent=2),encoding='utf8')
