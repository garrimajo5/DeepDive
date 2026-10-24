"""Reproduce frozen pose fixtures in an isolated Godot project; game checkout is read only."""
from pathlib import Path
import argparse,subprocess,tempfile,shutil
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--revision',default='cd46392b13d2f884fd03a0e601db969c1b0b8dd2');a=p.parse_args()
root=Path(__file__).resolve().parent.parent;repo=root.parents[2];out=root/'renders';out.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='mod018-poses-') as temp:
 temp=Path(temp)
 paths=subprocess.check_output(['git','-C',str(repo),'ls-tree','-r','--name-only',a.revision,'scripts/core'],text=True).splitlines()
 for name in paths:
  if not name.endswith('.gd'):continue
  target=temp/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(subprocess.check_output(['git','-C',str(repo),'show',a.revision+':'+name]))
 (temp/'project.godot').write_text('config_version=5\n[application]\nconfig/name="MOD018 pose diagnostics"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
 for name in ['export_poses.gd','export_points.gd','export_cloth_points.gd']:shutil.copyfile(root/'src'/name,temp/name)
 subprocess.run([a.godot,'--headless','--editor','--path',str(temp),'--quit'],check=True)
 for script,result in [('export_poses.gd','game-poses.json'),('export_points.gd','body-points.json'),('export_cloth_points.gd','cloth-points.json')]:
  subprocess.run([a.godot,'--headless','--path',str(temp),'--script',script,'--',str(repo/'models'),str(out/result),str(root)],check=True)
  assert (out/result).is_file(),result
print(out)
