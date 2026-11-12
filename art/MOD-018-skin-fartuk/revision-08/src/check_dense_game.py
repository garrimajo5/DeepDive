exec(compile((__import__('pathlib').Path(__file__).parent/'scene.py').read_text(encoding='utf-8'),__file__,'exec'))
D=json.loads((O/'game-poses-dense.json').read_text())
report=[]
for o in [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('gear-')]:
 arm=o.find_armature();body=next(x for x in bpy.data.objects if x.name.startswith('body-') and x.find_armature()==arm);sex='zh' if o.name.endswith('-zh') else 'm';rec={'name':o.name,'poses':{}}
 for key,trans in {"rest":None,**D[sex]}.items():
  pose(arm,'rest')
  for b in ([] if trans is None else arm.pose.bones):
   b.matrix=C@Matrix(trans[b.name])@CI@b.bone.matrix_local
   bpy.context.view_layer.update()
  bp,bf=ev(body);gp,gf=ev(o);bt=BVHTree.FromPolygons(bp,bf,all_triangles=True);gt=BVHTree.FromPolygons(gp,gf,all_triangles=True);gaps=[]
  for p in gp:
   q,n,i,d=bt.find_nearest(p);gaps.append(d if (p-q).dot(n)>=0 else -d)
  rec['poses'][key]={'min':min(gaps),'max':max(gaps),'inside':sum(g<-.002 for g in gaps),'far':sum(g>.04 for g in gaps),'intersections':len(gt.overlap(bt))}
 pose(arm,'rest');report.append(rec)
(R/'validation-dense-game.json').write_text(json.dumps(report,indent=2));print([(v['name'],sum(p['intersections'] for p in v['poses'].values()),min(p['min'] for p in v['poses'].values()),max(p['max'] for p in v['poses'].values())) for v in report])
