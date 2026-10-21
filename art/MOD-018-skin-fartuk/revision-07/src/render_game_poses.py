exec(compile((__import__('pathlib').Path(__file__).parent/'scene.py').read_text(encoding='utf-8'),__file__,'exec'))
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.render.resolution_x=650;sc.render.resolution_y=490;sc.render.resolution_percentage=100
sc.world=bpy.data.worlds.new('Diagnostic world');sc.world.color=(.055,.065,.075)
for o in list(bpy.data.objects):
 if o.type in ['LIGHT','CAMERA']:bpy.data.objects.remove(o,do_unlink=True)
for pos,power,size in [((3,4,5),500,4),((-3,2,3),350,3),((0,-3,4),500,3)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(Vector((0,0,1))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;sc.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.55
for sex in ['m','zh']:
 for kind in ['fartuk','tunika']:
  for o in bpy.data.objects:
   if o.type=='MESH':o.hide_render=True
  gear=bpy.data.objects['gear-'+kind+'-'+sex];arm=gear.find_armature();body=bpy.data.objects['body-'+sex];gear.hide_render=False;body.hide_render=False
  for key in ['standing','seat1','post20']:
   pose(arm,'rest')
   for b in arm.pose.bones:b.matrix=C@Matrix(D[sex][key][b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
   pts,faces=ev(body);center=Vector([(min(v[i] for v in pts)+max(v[i] for v in pts))/2 for i in range(3)])
   cam.location=center+Vector((3,5,1.4));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
   sc.render.filepath=str(R/(gear.name+'-'+key+'.png'));bpy.ops.render.render(write_still=True)
