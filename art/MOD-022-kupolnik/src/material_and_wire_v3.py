import bpy,json,numpy as np
from pathlib import Path
from mathutils import Vector
P=Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(P/'kupolnik-v2-draft.glb'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');m=o.data.materials[0];nt=m.node_tree;bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
def images(node,seen=None):
 seen=set() if seen is None else seen
 if node in seen:return []
 seen.add(node)
 if node.type=='TEX_IMAGE':return [node.image]
 return [im for inp in node.inputs for l in inp.links for im in images(l.from_node,seen)]
ims=images(bs.inputs['Roughness'].links[0].from_node)
report={}
for im in ims:
 p=np.array(im.pixels[:],dtype=np.float32).reshape(-1,4);report['roughness_before']=[float(p[:,1].min()),float(p[:,1].max())];p[:,1]=.75+.2*p[:,1];p[:,2]=0;im.pixels.foreach_set(p.ravel());im.pack();report['roughness_after']=[float(p[:,1].min()),float(p[:,1].max())]
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.export_scene.gltf(filepath=str(P/'kupolnik-v3-draft.glb'),export_format='GLB',use_selection=True,export_animations=False)
(P/'material-v3.json').write_text(json.dumps(report,indent=2))
# Diagnostic wireframe render from the same mesh; no geometry exported from render setup.
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=12;s.render.resolution_x=1024;s.render.resolution_y=1024;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.05,.07,.09,1)
mat=bpy.data.materials.new('WireDiagnostic');mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;b=n.get('Principled BSDF');b.inputs['Base Color'].default_value=(.35,.5,.55,1);b.inputs['Roughness'].default_value=1
w=n.new('ShaderNodeWireframe');w.use_pixel_size=True;w.inputs['Size'].default_value=.8
mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.35,.5,.55,1);mix.inputs[2].default_value=(.01,.02,.02,1);l.new(w.outputs[0],mix.inputs[0]);l.new(mix.outputs[0],b.inputs['Base Color']);o.data.materials.clear();o.data.materials.append(mat)
bpy.ops.object.light_add(type='AREA',location=(2,4,4));bpy.context.object.data.energy=500;bpy.context.object.data.size=4
bpy.ops.object.camera_add();cam=bpy.context.object;s.camera=cam;cam.data.type='ORTHO'
for name,pos,target,scale in [('graspers',(0,4,1), (0,.9,.35),2),('siphons',(0,-4,1.2),(0,-1.35,.6),1.2)]:
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale;s.render.filepath=str(P/('wire-v3-'+name+'.png'));bpy.ops.render.render(write_still=True)
