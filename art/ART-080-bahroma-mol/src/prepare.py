from pathlib import Path
from PIL import Image, ImageOps
import sys
out=Path(__file__).resolve().parents[1]
for name,source in [('01-bahroma.png',sys.argv[1]),('02-mol.png',sys.argv[2])]:
    im=Image.open(source).convert('RGB').resize((2048,1152),Image.Resampling.LANCZOS)
    ImageOps.posterize(im,6).save(out/name,optimize=True)
im=Image.open(sys.argv[3]).convert('RGBA')
w,h=im.size
atlas=Image.new('RGBA',(256,256))
for row in range(2):
    for col in range(2):
        cell=im.crop((col*w//2,row*h//2,(col+1)*w//2,(row+1)*h//2))
        cell=cell.crop(cell.getchannel('A').getbbox())
        cell.thumbnail((96,96),Image.Resampling.LANCZOS)
        atlas.alpha_composite(cell,(col*128+(128-cell.width)//2,row*128+(128-cell.height)//2))
atlas.save(out/'03-mol-atlas.png',optimize=True)
for p in out.glob('*.png'):
    with Image.open(p) as img:
        print(p.name,img.size,img.mode,p.stat().st_size)
        img.verify()
    assert p.stat().st_size<2_000_000
