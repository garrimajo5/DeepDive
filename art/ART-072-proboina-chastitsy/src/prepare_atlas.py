"""Crop/rescale a generated 4x4 RGBA atlas, preserving its alpha.
Usage: python prepare_atlas.py input.png output.png
"""
from PIL import Image
import sys
s=Image.open(sys.argv[1]).convert("RGBA")
a=Image.new("RGBA",(512,512))
for i in range(16):
 x,y=i%4,i//4
 c=s.crop((round(x*s.width/4),round(y*s.height/4),round((x+1)*s.width/4),round((y+1)*s.height/4)))
 c=c.resize((104,104),Image.Resampling.LANCZOS)
 a.paste(c,(x*128+12,y*128+12))
a.save(sys.argv[2],optimize=True)
