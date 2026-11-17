from pathlib import Path
__file__=str(Path('work/DeepDive/art/MOD-018-skin-fartuk/revision-12/src/scene.py').resolve())
exec(compile(Path(__file__).read_text(),__file__,'exec'))
from mathutils.geometry import barycentric_transform
D=json.loads((O/'game-poses-dense.json').read_text());report=[]
for o in [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('gear-')]:
 arm=o.find_armature();sex='zh' if o.name.endswith('-zh') else 'm';body=bpy.data.objects['body-'+sex];pose(arm,'rest');rp,faces=ev(o);bp,bf=ev(body);bt=BVHTree.FromPolygons(bp,bf,all_triangles=True);states=[]
 for key,tr in {'rest':None,**D[sex]}.items():
  pose(arm,'rest')
  if tr:
   for b in arm.pose.bones:b.matrix=C@Matrix(tr[b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
  pp,pf=ev(body);gp,gf=ev(o);states.append((key,BVHTree.FromPolygons(pp,pf,all_triangles=True),gp,{b.name:b.matrix@b.bone.matrix_local.inverted() for b in arm.pose.bones}))
 pose(arm,'rest');count={'gear-fartuk-m':156,'gear-fartuk-zh':182,'gear-tunika-m':270,'gear-tunika-zh':281}[o.name]
 ids=set(range(count));uvs={}
 for poly in o.data.polygons:
  for li in poly.loop_indices:uvs.setdefault(o.data.loops[li].vertex_index,o.data.uv_layers.active.data[li].uv.copy())
 target={};newweights={};weights={i:{o.vertex_groups[g.group].name:g.weight for g in o.data.vertices[i].groups} for i in ids}
 oldweights={i:dict(w) for i,w in weights.items()}
 for i in ids:
  newweights[i]=weights[i]
  uv=uvs[i];side=1 if rp[i].y>=0 else -1;u=uv.x-(.5 if side<0 else 0);x=(u*2-.5)*.64;z=uv.y*1.1+.55
  if abs(x)>.3 or not .55<z<1.7:target[i]=rp[i];continue
  q,n,ix,d=bt.ray_cast(Vector((x,side*2,z)),Vector((0,-side,0)),4)
  target[i]=Vector((x,q.y+side*.015,z)) if q is not None else rp[i]
  if q is not None:
   a,b,c=[bp[j] for j in bf[ix]];bc=barycentric_transform(q,a,b,c,Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)));w={}
   for vi,t in zip(bf[ix],bc):
    for g in body.data.vertices[vi].groups:
     name=body.vertex_groups[g.group].name
     if name not in ['Hips','Spine','Spine01','Spine02','LeftUpLeg','RightUpLeg']:continue
     w[name]=w.get(name,0)+max(0,t)*g.weight
   if w:
    w=dict(sorted(w.items(),key=lambda x:-x[1])[:4]);total=sum(w.values());w={n:v/total for n,v in w.items()}
    if z>=.9:
     extra=sum(max(0,v-.5) for n,v in w.items() if n.endswith('UpLeg'));w={n:min(.5,v) if n.endswith('UpLeg') else v for n,v in w.items()};w['Hips']=w.get('Hips',0)+extra
    w=dict(sorted(w.items(),key=lambda x:-x[1])[:4]);total=sum(w.values());newweights[i]={n:v/total for n,v in w.items() if v>1e-7}
 def measure(ps):
  hits=0;selfhits=0;gap=0;restgap=0
  for key,bodytree,pts,mats in states:
   for i in ids:pts[i]=sum((w*(mats[n]@ps[i]) for n,w in weights[i].items()),Vector())
   tree=BVHTree.FromPolygons(pts,faces,all_triangles=True);hits+=len(tree.overlap(bodytree))
   selfhits+=sum(1 for a,b in tree.overlap(tree) if a<b and not(set(faces[a])&set(faces[b])) and not any((pts[i]-pts[j]).length<1e-6 for i in faces[a] for j in faces[b]))
   for f in faces:
    a,b,c=[pts[j] for j in f]
    for p in [(a+b+c)/3,(a+b)/2,(a+c)/2,(b+c)/2]:
     d=bodytree.find_nearest(p)[3];gap=max(gap,d)
     if key=='rest':restgap=max(restgap,d)
  return hits,selfhits,gap,restgap
 original={i:rp[i] for i in ids};base=measure(original);best=base;winner=None;print('BASE',o.name,base,flush=True)
 for blend in [.25,.5,.75,1]:
  weights={i:dict(w) for i,w in newweights.items()}
  ps={i:rp[i].lerp(target[i],blend) for i in ids};ms=measure(ps);print('TRY',blend,ms,flush=True)
  if ms[0]<=base[0] and ms[1]<best[1] and ms[2]<=max(.04,base[2])+1e-6 and ms[3]<=max(.02,base[3])+1e-6:best=ms;winner=ps
 if winner:
  for i,p in winner.items():
   o.data.vertices[i].co=p
   for vg in o.vertex_groups:vg.remove([i])
   for n,w in newweights[i].items():
    vg=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);vg.add([i],w,'REPLACE')
  report.append({'name':o.name,'before':base,'after':best,'positions':{str(i):list(p) for i,p in winner.items()},'weights':newweights});print('WIN',o.name,best,flush=True)
 o.data.update();pose(arm,'rest')
Path('work/skin-work/uvweights13.json').write_text(json.dumps(report,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(Path('work/skin-work/uvweights13.blend').resolve()))
