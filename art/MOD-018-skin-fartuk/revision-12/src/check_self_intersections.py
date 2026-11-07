from pathlib import Path
__file__=str(Path(__file__).with_name('scene.py'))
exec(compile(Path(__file__).read_text(),__file__,'exec'))
D=json.loads((O/'game-poses-dense.json').read_text());reports=[]
for o in [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('gear-')]:
 arm=o.find_armature();sex='zh' if o.name.endswith('-zh') else 'm';rec={'name':o.name,'poses':{}}
 for key,tr in {'rest':None,**D[sex]}.items():
  pose(arm,'rest')
  if tr:
   for b in arm.pose.bones:b.matrix=C@Matrix(tr[b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
  ps,fs=ev(o);bt=BVHTree.FromPolygons(ps,fs,all_triangles=True);pairs=[]
  for a,b in bt.overlap(bt):
   if a>=b or set(fs[a])&set(fs[b]):continue
   if any((ps[i]-ps[j]).length<1e-6 for i in fs[a] for j in fs[b]):continue
   pairs.append([a,b])
  rec['poses'][key]=pairs
 reports.append(rec);print(o.name,sum(len(v) for v in rec['poses'].values()),flush=True)
(O/'validation-self-intersections.json').write_text(json.dumps(reports,indent=2))
