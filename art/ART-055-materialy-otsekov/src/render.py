import bpy,math,json
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1];REPO=R.parents[1];OUT=R/'renders';OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def rgb(c):
 a=[int(c[i:i+2],16)/255 for i in [0,2,4]];return tuple(((x+.055)/1.055)**2.4 if x>.04045 else x/12.92 for x in a)
def plain(name,hex,rough=.75,metal=.25):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb(hex),1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;return m
colors=['8C806B','514D43','0B1C24','34484C','F6DEAC']
flat=[plain(str(i),c) for i,c in enumerate(colors)]
lamp=flat[4].node_tree.nodes.get('Principled BSDF');lamp.inputs['Emission Color'].default_value=(*rgb('F6DEAC'),1)
textured={}
for name,strength in [('mash-pol',.6),('mash-stena',.65),('tryum-pol',.6),('tryum-stena',.65),('otsek-potolok',.6)]:
 m=plain(name,'8C806B');nt=m.node_tree;ns=nt.nodes;ls=nt.links;p=ns.get('Principled BSDF')
 def tex(suffix,data=False):
  n=ns.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(R/f'{name}-{suffix}.png'));n.image.colorspace_settings.name='Non-Color' if data else 'sRGB';n.extension='REPEAT';n.interpolation='Linear';return n
 col=tex('tsvet');normal=tex('normali',True);orm=tex('orm',True)
 sep=ns.new('ShaderNodeSeparateColor');ls.new(orm.outputs['Color'],sep.inputs['Color'])
 # Approximate AO applied at quarter strength for this comparison, not painted directional shadows.
 ao=ns.new('ShaderNodeMath');ao.operation='MULTIPLY_ADD';ao.inputs[1].default_value=.25;ao.inputs[2].default_value=.75;ls.new(sep.outputs['Red'],ao.inputs[0])
 mul=ns.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1;ls.new(col.outputs['Color'],mul.inputs[1]);ls.new(ao.outputs[0],mul.inputs[2]);ls.new(mul.outputs[0],p.inputs['Base Color'])
 nm=ns.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=strength;ls.new(normal.outputs['Color'],nm.inputs['Color']);ls.new(nm.outputs['Normal'],p.inputs['Normal'])
 ls.new(sep.outputs['Green'],p.inputs['Roughness']);ls.new(sep.outputs['Blue'],p.inputs['Metallic']);textured[name]=m

objects=[]
for part in json.loads((R/'source/bridge.json').read_text('utf-8')):
 # Blender axes: (x,-GodotZ,GodotY).
 size=part['size'];pos=part['center'];bpy.ops.mesh.primitive_cube_add(size=1,location=(pos[0],-pos[2],pos[1]));ob=bpy.context.object;ob.name=part['name'];ob.scale=(size[0],size[2],size[1]);ob.rotation_euler.x=math.radians(part['rx']);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 uv=ob.data.uv_layers.active or ob.data.uv_layers.new(name='UVMap')
 for face in ob.data.polygons:
  axis=max(range(3),key=lambda i:abs(face.normal[i]))
  for li in face.loop_indices:
   co=ob.data.vertices[ob.data.loops[li].vertex_index].co
   # Planar metre UV per face; same orientation across the whole part. No face stretching.
   if axis==2:pair=(co.x+ob.location.x,co.y+ob.location.y)
   elif axis==0:pair=(co.y+ob.location.y,co.z+ob.location.z)
   else:pair=(co.x+ob.location.x,co.z+ob.location.z)
   uv.data[li].uv=pair
 paint=part['paint'];ob.data.materials.append(flat[paint]);kind=None
 room='mash' if pos[2]<19.5 else 'tryum'
 if part['name'].startswith('Пол'):kind=room+'-pol'
 elif part['name'].startswith('Потолок'):kind='otsek-potolok'
 elif part['name'].startswith(('Борт','Корма','Переборка','Над люком')):kind=room+'-stena'
 if pos[2]<13.9:ob.hide_render=True
 objects.append((ob,paint,kind))

def add_model(name,at,ry=0,parent=None):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(REPO/'models'/f'{name}.glb'));new=set(bpy.data.objects)-before
 root=bpy.data.objects.new(name+'-preview-root',None);bpy.context.collection.objects.link(root)
 for ob in new:
  if ob.parent not in new:ob.parent=root
 root.location=(at[0],-at[2],at[1]);root.rotation_euler.z=math.radians(ry)
 if parent:root.parent=parent
 return root
for n in ['reaktor-osnova','reaktor-kozhuh','reaktor-sterzhen']:add_model(n,(0,0,17.2))
add_model('ventil-truba',(-3,1.3,17.2));add_model('ventil-koleso',(-2.68,1.3,17.2))
add_model('shchitok',(3,1.4,17.2));add_model('shchitok-kryshka',(2.822,1.425,17.2))
add_model('lebedka-opora',(-.6,0,23.1));add_model('lebedka-baraban',(0,2.4,22));add_model('lebedka-zahvat',(0,1.1,22))
add_model('lyuk-tryuma-kryshka',(0,-1.15,20.9))
for xx,angle in [(-2.5,0),(2.5,180)]:
 add_model('stellazh-tryuma',(xx,0,21.8),angle)
 for yy in [.55,1.3,2.05]:
  for zz in [20.6,21.4,22.2,23]:
   add_model('banka-obraztsa',(-2.215 if xx<0 else 2.215,yy,zz));add_model('banka-steklo',(-2.215 if xx<0 else 2.215,yy,zz))
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.cycles.use_denoising=True;sc.render.resolution_x=1000;sc.render.resolution_y=600;sc.render.resolution_percentage=100
sc.world=bpy.data.worlds.new('InteriorFill');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.03,.04,.05,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.15
def light(name,at,target,hex,power,size):
 bpy.ops.object.light_add(type='AREA',location=(at[0],-at[2],at[1]));ob=bpy.context.object;ob.name=name;ob.data.energy=power;ob.data.color=rgb(hex);ob.data.shape='DISK';ob.data.size=size;goal=Vector((target[0],-target[2],target[1]));ob.rotation_euler=(goal-ob.location).to_track_quat('-Z','Y').to_euler();return ob
warm=light('WarmCeiling',(0,2.9,16),(0,0,17.2),'F6DEAC',900,3)
side=light('RoomFill',(-2.7,2.7,17.2),(0,1,17.2),'F6DEAC',180,2)
cool=light('Reactor',(0,1.7,17.2),(-2,1,16),'67DDEB',50,1)
cargo=light('CargoCeiling',(0,2.7,21),(0,0,22),'F6DEAC',700,2)
water=light('AirlockWater',(0,-.4,22),(0,2,22),'67DDEB',35,1)
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.lens=17;cam.data.clip_start=.05;sc.camera=cam
sc.view_settings.view_transform='AgX';sc.render.image_settings.file_format='PNG'
for mode in ['engine-warm','engine-hot','cargo-warm']:
 at=(0,1.65,14.05) if mode.startswith('engine') else (1.65,1.7,19.9)
 goal=(0,1.5,17.4) if mode.startswith('engine') else (-.5,1.3,22.4)
 cam.data.lens=14 if mode.startswith('engine') else 17
 cam.location=(at[0],-at[2],at[1]);cam.rotation_euler=(Vector((goal[0],-goal[2],goal[1]))-cam.location).to_track_quat('-Z','Y').to_euler()
 cool.data.color=rgb('FFB259' if mode=='engine-hot' else '67DDEB');cool.data.energy=260 if mode=='engine-hot' else 50
 # Override only rod emission in the preview, retain accepted mesh and base material.
 for ob in bpy.data.objects:
  if ob.type=='MESH' and 'sterzhen' in ob.name:
   for m in ob.data.materials:
    if m and m.use_nodes:
     pp=m.node_tree.nodes.get('Principled BSDF')
     if pp:pp.inputs['Emission Color'].default_value=(*cool.data.color,1);pp.inputs['Emission Strength'].default_value=2
 for maps in [False,True]:
  for ob,paint,kind in objects:ob.data.materials[0]=textured[kind] if maps and kind else flat[paint]
  sc.render.filepath=str(OUT/f'{mode}-{int(maps)}.png');bpy.ops.render.render(write_still=True)
