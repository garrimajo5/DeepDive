exec(compile((__import__('pathlib').Path(__file__).parent/'scene.py').read_text(encoding='utf-8'),__file__,'exec'))
D=json.loads((O/'game-poses.json').read_text());C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));CI=C.inverted();report=[]
for sex in ['m','zh']:
 body=bpy.data.objects['body-'+sex];arm=body.find_armature();body.data.calc_loop_triangles();names=[]
 for t in body.data.loop_triangles:
  ws={}
  for i in t.vertices:
   for g in body.data.vertices[i].groups:
    n=body.vertex_groups[g.group].name;ws[n]=ws.get(n,0)+g.weight
  dom=[body.vertex_groups[max(body.data.vertices[i].groups,key=lambda g:g.weight).group].name for i in t.vertices]
  names.append(dom[0] if len(set(dom))==1 else 'mixed')
 for key in ['standing','walk5','seat1','post20']:
  pose(arm,'rest')
  for b in arm.pose.bones:b.matrix=C@Matrix(D[sex][key][b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
  p,f=ev(body);torso=[i for i,n in enumerate(names) if n in ['Hips','Spine','Spine01','Spine02','LeftUpLeg','RightUpLeg']];arms=[i for i,n in enumerate(names) if 'ForeArm' in n or 'Hand' in n];bt=BVHTree.FromPolygons(p,[f[i] for i in torso],all_triangles=True);at=BVHTree.FromPolygons(p,[f[i] for i in arms],all_triangles=True);pairs=[]
  for a,b in at.overlap(bt):
   ia,ib=arms[a],torso[b]
   if set(f[ia])&set(f[ib]):continue
   pairs.append([ia,ib,names[ia],names[ib]])
  report.append({'sex':sex,'pose':key,'pairs':pairs});print(sex,key,len(pairs),flush=True)
(R/'body-contacts.json').write_text(json.dumps(report,indent=2))
