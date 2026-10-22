import bpy,json,math
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent.parent;R=O/'renders';R.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
colors=['8C806B','514D43','F6DEAC','E9F7FF','9AD9E8'];materials=[]
for k,c in enumerate(colors):
 m=bpy.data.materials.new(c);m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');rgb=tuple(int(c[i:i+2],16)/255 for i in [0,2,4]);n.inputs['Base Color'].default_value=(*rgb,1);n.inputs['Roughness'].default_value=.75;n.inputs['Metallic'].default_value=.3 if k<2 else 0
 if k>1:n.inputs['Emission Color'].default_value=(*rgb,1);n.inputs['Emission Strength'].default_value=.85
 materials.append(m)
tex=materials[0].node_tree.nodes.new('ShaderNodeTexImage');materials[0].node_tree.links.new(tex.outputs['Color'],materials[0].node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
for part in json.loads((O/'source/hull.json').read_text()):
 vs=[(v[2],v[0],v[1]) for v in part['vertices']];idx=part['indices'];fs=[tuple(reversed(idx[i:i+3])) for i in range(0,len(idx),3)]
 me=bpy.data.meshes.new(part['name']);me.from_pydata(vs,[],fs);me.update();ob=bpy.data.objects.new(part['name'],me);bpy.context.collection.objects.link(ob);me.materials.append(materials[part['paint']]);uv=me.uv_layers.new(name='Projection2m')
 for f in me.polygons:
  f.use_smooth=True;axis=max(range(3),key=lambda j:abs(f.normal[j]))
  for li in f.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co
   # Godot tri projection p.zy / p.xz / p.xy, dominant-plane approximation for preview.
   uv.data[li].uv=((v.x/2,v.z/2) if axis==1 else ((v.y/2,v.x/2) if axis==2 else (v.y/2,v.z/2)))
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.render.resolution_x=1000;sc.render.resolution_y=340;sc.render.resolution_percentage=100
sc.world=bpy.data.worlds.new('Sea');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.065,.085,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for loc,power,size in [((0,-15,20),10000,25),((25,10,16),6000,18)]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(Vector((10,0,1.6))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(10,-65,6));cam=bpy.context.object;cam.rotation_euler=(Vector((10,0,1.2))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=42;sc.camera=cam
sc.view_settings.view_transform='AgX';sc.view_settings.look='Medium High Contrast' if 'Medium High Contrast' in [i.name for i in sc.view_settings.bl_rna.properties['look'].enum_items] else 'None'
sc.render.image_settings.file_format='PNG'
for hull in [100,70,40,15]:
 tex.image=bpy.data.images.load(str(R/f'plate-{hull}.png'));sc.render.filepath=str(R/f'hull-{hull}.png');bpy.ops.render.render(write_still=True)
