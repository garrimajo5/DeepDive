exec(compile((__import__('pathlib').Path(__file__).parent/'scene_exported.py').read_text(encoding='utf-8'),__file__,'exec'))
D=json.loads((O/'game-poses-dense.json').read_text());report=[];mask_report=[]
for o in [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('gear-')]:
 arm=o.find_armature();sex='zh' if o.name.endswith('-zh') else 'm';body=bpy.data.objects['body-'+sex]
 world=body.matrix_world.copy();body.parent=arm;body.matrix_world=world
 for modifier in body.modifiers:
  if modifier.type=='ARMATURE':modifier.object=arm
 pose(arm,'rest');rp,rf=ev(o);bp,bf=ev(body)
 rest_body=BVHTree.FromPolygons(bp,bf,all_triangles=True)
 groups={}
 for v in body.data.vertices:
  weights={body.vertex_groups[g.group].name:g.weight for g in v.groups}
  groups[v.index]=max(weights,key=weights.get) if weights else ''
 leg_faces={side:[f for f in bf if all(groups[i] in [side+'UpLeg',side+'Leg'] for i in f)] for side in ['Left','Right']}
 def inner_gap(p):
  if o.name!='gear-fartuk-zh':return None
  if rest_body.ray_cast(Vector((p.x,3,p.z)),Vector((0,-1,0)),6)[0] is not None:return None
  ranges=[]
  for side in ['Left','Right']:
   xs=[]
   for face in leg_faces[side]:
    for i,j in [(face[0],face[1]),(face[1],face[2]),(face[2],face[0])]:
     a,b=bp[i],bp[j]
     if (a.z-p.z)*(b.z-p.z)>0 or abs(a.z-b.z)<1e-8:continue
     t=(p.z-a.z)/(b.z-a.z)
     if 0<=t<=1:xs.append(a.x+t*(b.x-a.x))
   if not xs:return None
   ranges.append((min(xs),max(xs)))
  ranges.sort();left=ranges[0][1];right=ranges[1][0]
  if left+.002<p.x<right-.002:return [left,right]
  return None
 samples=[]
 for fi,f in enumerate(rf):
  a,b,c=[rp[i] for i in f]
  for si,p in enumerate([(a+b+c)/3,(a+b)/2,(a+c)/2,(b+c)/2]):
   gap=inner_gap(p);samples.append((fi,si,gap is not None))
   if gap:mask_report.append({'name':o.name,'face':fi,'sample':si,'rest_point':list(p),'gap_x':gap})
 rec={'name':o.name,'poses':{}}
 for key,trans in {'rest':None,**D[sex]}.items():
  pose(arm,'rest')
  if trans:
   for b in arm.pose.bones:b.matrix=C@Matrix(trans[b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
  pp,pf=ev(body);gp,gf=ev(o);bt=BVHTree.FromPolygons(pp,pf,all_triangles=True);gt=BVHTree.FromPolygons(gp,gf,all_triangles=True);raw=[];checked=[];ex=[];worst=[]
  for fi,si,eligible in samples:
   a,b,c=[gp[i] for i in gf[fi]];p=[(a+b+c)/3,(a+b)/2,(a+c)/2,(b+c)/2][si];q,n,ix,d=bt.find_nearest(p);raw.append(d)
   # Only fixed rest-material samples strictly inside the leg silhouette gap are exempt.
   # No vertex, torso/strap region, other garment or collision is excluded.
   if eligible and bt.ray_cast(Vector((p.x,3,p.z)),Vector((0,-1,0)),6)[0] is None:ex.append(d)
   else:checked.append(d);worst.append((d,fi,si))
  rec['poses'][key]={'all_max':max(raw),'checked_max':max(checked),'checked_over_4cm':sum(d>.04 for d in checked),'exempt_samples':len(ex),'exempt_max':max(ex,default=0),'intersections_all':len(gt.overlap(bt)),'rest_outside_1to2cm':sum(d<.01 or d>.02 for d in checked) if key=='rest' else None,'worst_checked':sorted(worst,reverse=True)[:8]}
 pose(arm,'rest');report.append(rec)
 print(o.name,'max',max(x['checked_max'] for x in rec['poses'].values()),'hits',sum(x['intersections_all'] for x in rec['poses'].values()),'excluded',rec['poses']['rest']['exempt_samples'],flush=True)
(O/'validation-exported-gap.json').write_text(json.dumps(report,indent=2));(O/'exported-gap-mask.json').write_text(json.dumps(mask_report,indent=2))
