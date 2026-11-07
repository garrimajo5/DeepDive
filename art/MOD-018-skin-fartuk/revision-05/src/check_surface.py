exec(compile((__import__('pathlib').Path(__file__).parent/'scene.py').read_text(encoding='utf-8'),__file__,'exec'))
D=json.loads((O/'game-poses-dense.json').read_text());report=[]
for o in [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('gear-')]:
 arm=o.find_armature();sex='zh' if o.name.endswith('-zh') else 'm';body=bpy.data.objects['body-'+sex];rec={'name':o.name,'poses':{}}
 for key,trans in {'rest':None,**D[sex]}.items():
  pose(arm,'rest')
  if trans:
   for b in arm.pose.bones:b.matrix=C@Matrix(trans[b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
  bp,bf=ev(body);gp,gf=ev(o);bt=BVHTree.FromPolygons(bp,bf,all_triangles=True);ds=[];signed=[]
  for f in gf:
   a,b,c=[gp[i] for i in f]
   for p in [(a+b+c)/3,(a+b)/2,(a+c)/2,(b+c)/2]:
    q,n,ix,d=bt.find_nearest(p);ds.append(d);signed.append(d if (p-q).dot(n)>=0 else -d)
  rec['poses'][key]={'samples':len(ds),'min_abs':min(ds),'max_abs':max(ds),'min_signed':min(signed),'over_4cm':sum(d>.04 for d in ds),'outside_rest_1to2cm':sum(d<.01 or d>.02 for d in ds) if key=='rest' else None}
 pose(arm,'rest');report.append(rec)
(R/'validation-surface-samples.json').write_text(json.dumps(report,indent=2))
print([(x['name'],max(p['max_abs'] for p in x['poses'].values()),x['poses']['rest']) for x in report])
