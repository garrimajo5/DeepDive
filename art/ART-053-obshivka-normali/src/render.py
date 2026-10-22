import bpy,math
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1];P=R/'renders'
bpy.ops.wm.read_factory_settings(use_empty=True)
# Same gently curved2x2m hull coupon, same camera, same grazing light for all states.
verts=[];faces=[];steps=48
for j in range(steps+1):
 for i in range(steps+1):
  x=-1+2*i/steps;y=-1+2*j/steps;verts.append((x,y,-.06*x*x))
for j in range(steps):
 for i in range(steps):
  q=j*(steps+1)+i;faces.append((q,q+1,q+steps+2,q+steps+1))
me=bpy.data.meshes.new('Hull2m');me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new('SameHullCoupon',me);bpy.context.collection.objects.link(ob)
uv=me.uv_layers.new(name='UVMap')
for face in me.polygons:
 face.use_smooth=True
 for li in face.loop_indices:
  co=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=((co.x+1)/2,(co.y+1)/2)
m=bpy.data.materials.new('HullMaterial');m.use_nodes=True;me.materials.append(m);ns=m.node_tree.nodes;ls=m.node_tree.links;p=ns.get('Principled BSDF');p.inputs['Metallic'].default_value=.3
def image_node(path,data=False):
 n=ns.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(path));n.image.colorspace_settings.name='Non-Color' if data else 'sRGB';n.extension='REPEAT';n.interpolation='Linear';return n
c=image_node(P/'color-clean.png');ls.new(c.outputs['Color'],p.inputs['Base Color'])
rough=image_node(R/'obshivka-sheroh.png',True)
n=image_node(R/'obshivka-normali.png',True);nm=ns.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=1;ls.new(n.outputs['Color'],nm.inputs['Color'])
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.cycles.use_denoising=True;sc.render.resolution_x=1024;sc.render.resolution_y=1024;sc.render.resolution_percentage=100
sc.world=bpy.data.worlds.new('DarkWater');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.025,.045,.06,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.3
bpy.ops.object.light_add(type='AREA',location=(-3,1.2,.45));light=bpy.context.object;light.data.energy=240;light.data.shape='DISK';light.data.size=.65;light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-.15,5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.16;sc.camera=cam
sc.view_settings.view_transform='AgX';sc.render.image_settings.file_format='PNG'
for k in ['flat','normal','damage15','clay']:
 for link in list(p.inputs['Normal'].links):ls.remove(link)
 for link in list(p.inputs['Roughness'].links):ls.remove(link)
 ls.new(rough.outputs['Color'],p.inputs['Roughness'])
 if k!='flat':ls.new(nm.outputs['Normal'],p.inputs['Normal'])
 c.image=bpy.data.images.load(str(P/('color-15.png' if k=='damage15' else 'color-clean.png')))
 if k in ['damage15','clay']:
  n.image=bpy.data.images.load(str(P/'normal-15.png'));n.image.colorspace_settings.name='Non-Color'
 if k=='clay':
  for link in list(p.inputs['Base Color'].links):ls.remove(link)
  p.inputs['Base Color'].default_value=(.3,.3,.3,1)
 sc.render.filepath=str(P/(k+'.png'));bpy.ops.render.render(write_still=True)
