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
for name,strength in [('pol',.6),('stena',.8),('potolok',.7)]:
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
 if part['name']=='Пол':kind='pol'
 elif part['name'] in ['Потолок','Скос потолка']:kind='potolok'
 elif part['name'].startswith(('Борт','Корма','Нос:')):kind='stena'
 objects.append((ob,paint,kind))

def add_model(name,at,ry=0,parent=None):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(REPO/'models'/f'{name}.glb'));new=set(bpy.data.objects)-before
 root=bpy.data.objects.new(name+'-preview-root',None);bpy.context.collection.objects.link(root)
 for ob in new:
  if ob.parent not in new:ob.parent=root
 root.location=(at[0],-at[2],at[1]);root.rotation_euler.z=math.radians(ry)
 if parent:root.parent=parent
 return root
energy=add_model('pult-energii',(-4.9,0,-2),-90)
for xx in [.34,.17,0,-.17,-.34]:add_model('polzunok',(xx,1,-.32425),parent=energy)
add_model('lyuk-rama',(0,0,2));door=add_model('lyuk-stvorka',(0,-.1,2.14));add_model('lyuk-koleso',(0,1.05,2.04))

sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.cycles.use_denoising=True;sc.render.resolution_x=1000;sc.render.resolution_y=600;sc.render.resolution_percentage=100
sc.world=bpy.data.worlds.new('InteriorFill');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.03,.04,.05,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.15
def light(name,at,target,hex,power,size):
 bpy.ops.object.light_add(type='AREA',location=(at[0],-at[2],at[1]));ob=bpy.context.object;ob.name=name;ob.data.energy=power;ob.data.color=rgb(hex);ob.data.shape='DISK';ob.data.size=size;goal=Vector((target[0],-target[2],target[1]));ob.rotation_euler=(goal-ob.location).to_track_quat('-Z','Y').to_euler();return ob
warm=light('WarmCeiling',(0,2.9,-.5),(-3,1.1,-.5),'F6DEAC',650,2.5)
cool=light('ConsoleBlue',(-4.35,1.35,-2),(-2.5,1,-.8),'67DDEB',60,1.2)
fill=light('WeakWindow',(0,2,-5.7),(-3,1,0),'9AD9E8',70,3)
bpy.ops.object.camera_add(location=(1,3,1.6));cam=bpy.context.object;cam.rotation_euler=(Vector((-4,-1,1.45))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=19;cam.data.clip_start=.05;sc.camera=cam
sc.view_settings.view_transform='AgX';sc.render.image_settings.file_format='PNG'
for mode in ['warm','blue']:
 warm.data.energy=650 if mode=='warm' else 70;cool.data.energy=50 if mode=='warm' else 320;lamp.inputs['Emission Strength'].default_value=1.4 if mode=='warm' else .25
 for maps in [False,True]:
  for ob,paint,kind in objects:ob.data.materials[0]=textured[kind] if maps and kind else flat[paint]
  sc.render.filepath=str(OUT/f'{mode}-{int(maps)}.png');bpy.ops.render.render(write_still=True)
