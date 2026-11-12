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

# Diagnostic only: bare source body; no garment and no geometry edits.
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=24;sc.render.resolution_x=800;sc.render.resolution_y=450;sc.render.resolution_percentage=100
sc.world=bpy.data.worlds.new('Diagnostic World');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.055,.065,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for o in bpy.data.objects:
 if o.type=='MESH':o.hide_render=True
for pos,power in [((3,4,5),600),((-3,2,3),400),((0,-3,4),500)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=4;l.rotation_euler=(Vector((0,0,1.2))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;sc.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.05;cam.location=(2.5,5,1.3);cam.rotation_euler=(Vector((0,0,1.12))-cam.location).to_track_quat('-Z','Y').to_euler()
materials=[]
for name,color in [('Other',(.22,.26,.28,1)),('Forearms',(.06,.65,.78,1)),('Torso',(.48,.36,.17,1)),('Contact',(.95,.78,.32,1))]:
 m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.75;materials.append(m)
for sex in ['m','zh']:
 body=bpy.data.objects['body-'+sex];arm=body.find_armature();body.data.materials.clear()
 for m in materials:body.data.materials.append(m)
 for key in ['standing','walk5']:
  pose(arm,'rest')
  for b in arm.pose.bones:b.matrix=C@Matrix(D[sex][key][b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
  rec=next(x for x in report if x['sex']==sex and x['pose']==key);contact={p[1] for p in rec['pairs']};body.data.calc_loop_triangles();contactpolys={body.data.loop_triangles[i].polygon_index for i in contact}
  for f in body.data.polygons:
   names=[body.vertex_groups[max(body.data.vertices[i].groups,key=lambda g:g.weight).group].name for i in f.vertices]
   f.material_index=1 if all('ForeArm' in n or 'Hand' in n for n in names) else 2 if all(n in ['Hips','Spine','Spine01','Spine02','LeftUpLeg','RightUpLeg'] for n in names) else 0
   if f.index in contactpolys:f.material_index=3
  body.hide_render=False;sc.render.filepath=str(R/f'body-{sex}-{key}.png');bpy.ops.render.render(write_still=True);body.hide_render=True
