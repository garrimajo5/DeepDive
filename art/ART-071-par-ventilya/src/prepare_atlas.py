"""Resize/crop the generated 4x4 RGBA atlas, preserving its alpha.
Usage: python prepare_atlas.py input.png output.png
Input: the original 1254-square imagegen result (see notes prompt).
"""
from PIL import Image
import sys
s=Image.open(sys.argv[1]).convert("RGBA")
out=Image.new("RGBA",(512,512))
for i in range(16):
 x,y=i%4,i//4
 cell=s.crop((round(x*s.width/4),round(y*s.height/4),round((x+1)*s.width/4),round((y+1)*s.height/4)))
 cell=cell.resize((104,104),Image.Resampling.LANCZOS)
 out.paste(cell,(x*128+12,y*128+12))
out.save(sys.argv[2],optimize=True)
