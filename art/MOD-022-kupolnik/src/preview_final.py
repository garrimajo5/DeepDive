import bpy,json,math
from pathlib import Path
from mathutils import Vector
P=Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(P/'kupolnik.glb'));o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.018,.028,.040,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.4
for p in [(3,4,5),(-4,1,2),(0,-3,3)]:
 bpy.ops.object.light_add(type='AREA',location=p);l=bpy.context.object;l.data.energy=350;l.data.size=4;l.rotation_euler=(Vector((0,0,.6))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();c=bpy.context.object;s.camera=c;c.data.type='ORTHO'
for name,pos,target,scale in [('front',(0,5,.6),(0,0,.6),2.4),('side',(5,0,.6),(0,0,.6),3.5),('top',(0,0,5),(0,0,.5),3.4),('valves',(0,-5,1.1),(0,-1.3,.75),.9)]:
 c.location=pos;c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=scale;s.render.filepath=str(P/('panel-'+name+'.png'));bpy.ops.render.render(write_still=True)
mat=bpy.data.materials.new('Wire diagnostic only');mat.use_nodes=True;n=mat.node_tree.nodes;links=mat.node_tree.links;b=n.get('Principled BSDF');b.inputs['Roughness'].default_value=1
w=n.new('ShaderNodeWireframe');w.use_pixel_size=True;w.inputs['Size'].default_value=.7;mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.23,.35,.40,1);mix.inputs[2].default_value=(.006,.012,.02,1);links.new(w.outputs[0],mix.inputs[0]);links.new(mix.outputs[0],b.inputs['Base Color']);o.data.materials.clear();o.data.materials.append(mat)
# Highlight actual exported transverse edge contours, not conceptual guide rings.
em=bpy.data.materials.new('Ring edge highlight');em.diffuse_color=(.1,.8,.9,1);em.use_nodes=True;bs=em.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.1,.8,.9,1);bs.inputs['Emission Color'].default_value=(.03,.3,.4,1);bs.inputs['Emission Strength'].default_value=.5
shift=json.loads((P/'pivot-shift.json').read_text());part=json.loads((P/'retopology-v5.json').read_text())['parts'][2]
for c0 in part['ring_centers_blender'][1:-1]:
 center=Vector([c0[i]+shift[i] for i in range(3)]);points={tuple(round(v,6) for v in p.co) for p in o.data.vertices if abs(p.co.y-center.y)<1e-5 and abs(p.co.x-center.x)<.16 and abs(p.co.z-center.z)<.16};points=sorted(points,key=lambda p:math.atan2(p[2]-center.z,p[0]-center.x))
 curve=bpy.data.curves.new('Exported ring','CURVE');curve.dimensions='3D';curve.bevel_depth=.0011;curve.bevel_resolution=1;sp=curve.splines.new('POLY');sp.points.add(len(points)-1)
 for q,p in zip(sp.points,points):q.co=(*p,1)
 sp.use_cyclic_u=True;ob=bpy.data.objects.new('Ring overlay',curve);s.collection.objects.link(ob);ob.data.materials.append(em)
c.location=(3,3,1.2);target=Vector((.58,.85,.35));c.rotation_euler=(target-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=1.05;s.render.filepath=str(P/'panel-wire.png');bpy.ops.render.render(write_still=True)
