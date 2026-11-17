import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from build import *
for sex in ['muzhchina','zhenshchina']:
 d,b=read(REPO/'models'/('ekipazh-'+sex+'.glb'));r,g=sample(d,b,'PostIdle')
 print(sex,{n:list(g[r.names[n]].translation) for n in ['Head','headfront','head_end','neck']})
