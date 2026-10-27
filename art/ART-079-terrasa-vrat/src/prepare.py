from pathlib import Path
from PIL import Image
import sys
out=Path(__file__).resolve().parents[1]
for source,name in [(sys.argv[1],'01-ansambl.png'),(sys.argv[2],'02-kontakt.png')]:
    im=Image.open(source).convert('RGB').resize((2048,1152),Image.Resampling.LANCZOS)
    im=im.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
    im.save(out/name,optimize=True)
atlas=Image.open(sys.argv[3]).convert('RGBA')
w,h=atlas.size
for box,name in [((0,0,922,h),'03-terrasa-vrat.png'),((922,0,w,h),'04-nablyudenie-polya.png')]:
    im=atlas.crop(box)
    bbox=im.getchannel('A').getbbox()
    im=im.crop(bbox)
    im.thumbnail((236,236),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(256,256))
    canvas.alpha_composite(im,((256-im.width)//2,(256-im.height)//2))
    canvas.save(out/name,optimize=True)
for p in out.glob('*.png'):
    im=Image.open(p); im.verify()
    assert p.stat().st_size<2_000_000,p
    print(p.name,Image.open(p).size,Image.open(p).mode,p.stat().st_size)
