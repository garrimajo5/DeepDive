exec(compile((__import__('pathlib').Path(__file__).parent/'scene.py').read_text(encoding='utf-8'),__file__,'exec'))
o=bpy.data.objects['gear-fartuk-zh'];arm=o.find_armature();pose(arm,'rest');body=bpy.data.objects['body-zh'];gp,gf=ev(o);bp,bf=ev(body);bt=BVHTree.FromPolygons(bp,bf,all_triangles=True);a,b,c=[gp[i] for i in gf[97]];samples=[(a+b+c)/3,(a+b)/2,(a+c)/2,(b+c)/2];p=max(samples,key=lambda p:bt.find_nearest(p)[3]);q,n,ix,d=bt.find_nearest(p)
(R/'hem-distance.json').write_text(json.dumps({'cloth_face':97,'cloth_point_blender':list(p),'nearest_body_point_blender':list(q),'distance_m':d,'pose':'rest'},indent=2))
for x in bpy.data.objects:
 if x.type=='MESH':x.hide_render=x not in [o,body]
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.render.resolution_x=1600;sc.render.resolution_y=900;sc.render.resolution_percentage=100;sc.world=bpy.data.worlds.new('W');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.055,.065,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for pos,power in [((3,4,5),600),((-3,2,3),400)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.size=4;l.rotation_euler=(Vector((0,0,.8))-l.location).to_track_quat('-Z','Y').to_euler()
m=bpy.data.materials.new('Measurement');m.diffuse_color=(.95,.78,.32,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.95,.78,.32,1)
for at in [p,q]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.008,location=at);bpy.context.object.data.materials.append(m)
bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.002,depth=(p-q).length,location=(p+q)/2);bpy.context.object.rotation_euler=(p-q).to_track_quat('Z','Y').to_euler();bpy.context.object.data.materials.append(m)
bpy.ops.object.camera_add();cam=bpy.context.object;sc.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.1;cam.location=(.7,5,.8);cam.rotation_euler=(Vector((0,0,.75))-cam.location).to_track_quat('-Z','Y').to_euler();sc.render.filepath=str(R/'hem-closeup.png');bpy.ops.render.render(write_still=True)
