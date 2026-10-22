from pathlib import Path
__file__=str(Path(__file__).with_name('scene.py'))
exec(compile(Path(__file__).read_text(),__file__,'exec'))

o=bpy.data.objects['gear-fartuk-zh'];arm=o.find_armature();pose(arm,'rest');body=bpy.data.objects['body-zh']
for x in bpy.data.objects:
 if x.type=='MESH':x.hide_render=x not in [o,body]
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.render.resolution_x=1600;sc.render.resolution_y=900;sc.render.resolution_percentage=100;sc.world=bpy.data.worlds.new('W');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.055,.065,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for pos,power in [((3,4,5),600),((-3,2,3),400)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.size=4;l.rotation_euler=(Vector((0,0,.8))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;sc.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=.95;cam.location=(.7,5,.8);cam.rotation_euler=(Vector((0,0,.78))-cam.location).to_track_quat('-Z','Y').to_euler()
for b in arm.pose.bones:b.matrix=C@Matrix(D['zh']['standing'][b.name])@CI@b.bone.matrix_local;bpy.context.view_layer.update()
gp,gf=ev(o);center=Vector((0,0,1.43));cam.location=center+Vector((0,3,.15));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.9;sc.render.filepath=str(O/'renders'/('detail-'+(__import__('sys').argv[__import__('sys').argv.index('--')+2] if '--' in __import__('sys').argv and len(__import__('sys').argv)>__import__('sys').argv.index('--')+2 else 'after')+'.png'));bpy.ops.render.render(write_still=True)
