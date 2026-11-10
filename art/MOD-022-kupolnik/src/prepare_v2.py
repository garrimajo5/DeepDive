import bpy,json,numpy as np
from pathlib import Path
from mathutils import Vector
P=Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(P/'remesh-v2/model.glb'))
o=[o for o in bpy.context.scene.objects if o.type=='MESH'][0]
bpy.context.view_layer.objects.active=o;o.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
a=np.array([v.co[:] for v in o.data.vertices]);lo=a.min(0);hi=a.max(0)
a=(a-lo)/(hi-lo)*np.array([1.8,3,1.2]);a[:,0]-=.9;a[:,1]-=1.5
# Imported source front is Blender -Y; glTF front must -Z => Blender +Y.
a[:,0]*=-1;a[:,1]*=-1
for v,p in zip(o.data.vertices,a):v.co=p
o.name='Kupolnik';o.data.name='Kupolnik'
m=o.data.materials[0];nt=m.node_tree;bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
for n in nt.nodes:
 if n.type=='TEX_IMAGE' and n.image:
  n.image.scale(1024,1024);n.image.pack()
for l in list(bs.inputs['Metallic'].links):nt.links.remove(l)
bs.inputs['Metallic'].default_value=0
# Keep roughness map but lift it to matte range.
links=list(bs.inputs['Roughness'].links)
if links:
 src=links[0].from_socket;nt.links.remove(links[0]);mul=nt.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY_ADD';mul.inputs[1].default_value=.2;mul.inputs[2].default_value=.75;nt.links.new(src,mul.inputs[0]);nt.links.new(mul.outputs[0],bs.inputs['Roughness'])
else:bs.inputs['Roughness'].default_value=.85
base=bs.inputs['Base Color'].links[0].from_node.image
pix=np.array(base.pixels[:],dtype=np.float32).reshape(-1,4)
mask=(pix[:,1]>pix[:,0]*1.35)&(pix[:,2]>pix[:,0]*1.35)&(pix[:,1]>.25)
em=bpy.data.images.new('PhotophoreMask',width=1024,height=1024,alpha=False)
e=np.zeros_like(pix);e[:,3]=1;e[mask,:3]=[.1356,.7231,.8228];em.pixels.foreach_set(e.ravel());em.pack()
n=nt.nodes.new('ShaderNodeTexImage');n.image=em;nt.links.new(n.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=1
bpy.ops.export_scene.gltf(filepath=str(P/'kupolnik-v2-draft.glb'),export_format='GLB',use_selection=True,export_animations=False)
o.data.calc_loop_triangles()
(P/'draft-v2-report.json').write_text(json.dumps({'triangles':len(o.data.loop_triangles),'dimensions_gltf':[1.8,1.2,3],'scale':list(o.scale),'emission_mask_pixels':int(mask.sum()),'status':'DRAFT: topology loops and siphon valves unverified'},indent=2))
