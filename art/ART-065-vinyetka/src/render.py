from pathlib import Path
import subprocess
P=Path(__file__).resolve().parents[1];ROOT=P.parents[1]
si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
shots=[('8-on','mel',['ship=0,-8,0']),('8-off','mel',['ship=0,-8,0','light=0']),('20-on','sredniy',['ship=0,-20,0']),('20-off','sredniy',['ship=0,-20,0','light=0']),('45-on','glubina',['ship=180,-45,0']),('45-off','glubina',['ship=180,-45,0','light=0']),('90-on','glubina',['ship=215,-90,0']),('90-off','glubina',['ship=215,-90,0','light=0']),('flyby','mel',['ship=0,-8,0','flyby=start','age=3']),('silt','il',['ship=180,-45,0','silt=1'])]
for name,preset,args in shots:
 with (P/(name+'.log')).open('w',encoding='utf-8') as log:
  r=subprocess.run(['D:/Godot/Godot_v4.7.2-stable_win64.exe','--path',str(ROOT),'--resolution','1600x720','-s',str(P/'src/capture.gd'),'--',str(P/'source'/f'{name}.png'),'z=-3','yaw=0','frames=8','grade='+preset]+args,startupinfo=si,stdout=log,stderr=subprocess.STDOUT,timeout=120)
 if r.returncode:raise RuntimeError(name)
 print(name,flush=True)
