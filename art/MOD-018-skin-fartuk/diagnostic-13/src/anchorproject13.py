from pathlib import Path
__file__=str(Path('work/DeepDive/art/MOD-018-skin-fartuk/revision-12/src/scene.py').resolve())
exec(compile(Path(__file__).read_text(),__file__,'exec'))
from mathutils.geometry import barycentric_transform
D=json.loads((O/'game-poses-dense.json').read_text());o=bpy.data.objects['gear-fartuk-m'];arm=o.find_armature();body=bpy.data.objects['body-m'];pose(arm,'rest');rp,faces=ev(o);bp,bf=ev(body);bt=BVHTree.FromPolygons(bp,bf,all_triangles=True);states=[]
for key,tr in {'rest':None,**D['m']}.items():
 pose(arm,'rest')
 if tr:
  for b in arm.pose.bones:b.matrix=C@Matrix(tr[b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
 pp,pf=ev(body);gp,gf=ev(o);states.append((key,BVHTree.FromPolygons(pp,pf,all_triangles=True),gp,{b.name:b.matrix@b.bone.matrix_local.inverted() for b in arm.pose.bones}))
pose(arm,'rest');ids=list(range(156,204));fs=[f for f in faces if any(i in ids for i in f)];orig={i:rp[i] for i in ids};oldweights={i:{o.vertex_groups[g.group].name:g.weight for g in o.data.vertices[i].groups} for i in ids}
def measure(ps,weights):
 hits=0;gap=0;restgap=0;selfhits=0
 for key,bodytree,pts,mats in states:
  for i in ids:pts[i]=sum((w*(mats[n]@ps[i]) for n,w in weights[i].items()),Vector())
  tree=BVHTree.FromPolygons(pts,fs,all_triangles=True);hits+=len(tree.overlap(bodytree))
  selfhits+=sum(1 for a,b in tree.overlap(tree) if a<b and not(set(fs[a])&set(fs[b])))
  for f in fs:
   a,b,c=[pts[j] for j in f]
   for p in [(a+b+c)/3,(a+b)/2,(a+c)/2,(b+c)/2]:
    d=bodytree.find_nearest(p)[3];gap=max(gap,d)
    if key=='rest':restgap=max(restgap,d)
 return hits,selfhits,gap,restgap

base=measure(orig,oldweights);print('BASE',base,flush=True);best=None;winner=None;report=[]
for edge in [(140,142),(137,139),(139,140)]:
 for rows in [4,6,8]:
  for bulge in [.01,.015,.02,.025]:
   ps={i:p.copy() for i,p in orig.items()};ws={i:dict(w) for i,w in oldweights.items()}
   ews=[{o.vertex_groups[g.group].name:g.weight for g in o.data.vertices[v].groups} for v in edge]
   for row in range(rows):
    t=row/rows
    for col in range(3):
     u=col/2;i=156+row*3+col;end=156+rows*3+col;start=rp[edge[0]].lerp(rp[edge[1]],u)
     ps[i]=start.lerp(orig[end],t)+Vector((0,bulge*math.sin(math.pi*t),0))
     w={n:((1-u)*ews[0].get(n,0)+u*ews[1].get(n,0))*(1-t)+oldweights[end].get(n,0)*t for n in set(ews[0])|set(ews[1])|set(oldweights[end])}
     if row>0:
      q,n,fi,d=bt.find_nearest(ps[i]);ps[i]=q+n*bulge
      a,b,c=[bp[j] for j in bf[fi]];bc=barycentric_transform(q,a,b,c,Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)));w={}
      for vi,factor in zip(bf[fi],bc):
       for g in body.data.vertices[vi].groups:
        name=body.vertex_groups[g.group].name
        if name in ['LeftArm','LeftShoulder','Spine','Spine01','Spine02']:w[name]=w.get(name,0)+max(0,factor)*g.weight
     w=dict(sorted(w.items(),key=lambda v:-v[1])[:4]);total=sum(w.values());ws[i]={n:v/total for n,v in w.items() if v>1e-7}
   ms=measure(ps,ws);print('TRY',edge,rows,bulge,ms,flush=True)
   score=(ms[0],ms[1],ms[2])
   if ms[2]<=.04 and (best is None or score<best):best=score;winner=(ps,ws);report=[{'edge':edge,'rows':rows,'bulge':bulge,'before':base,'after':ms,'positions':{str(i):list(p) for i,p in ps.items()},'weights':ws}]
if winner:
 ps,ws=winner
 for i in ids:
  o.data.vertices[i].co=ps[i]
  for g in o.vertex_groups:g.remove([i])
  for n,w in ws[i].items():
   vg=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);vg.add([i],w,'REPLACE')
 print('WIN',best,flush=True)
Path('work/skin-work/anchorproject13.json').write_text(json.dumps(report,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(Path('work/skin-work/anchorproject13.blend').resolve()))
