import bpy,math,pathlib,json
from mathutils import Vector
p=pathlib.Path(r'C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-023-terrasa-vrat')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p/'arch-draft-v4.glb'))
mineral=bpy.data.objects['LOD0_Mineral'].data.materials[0]
def mat(name,c,emit=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*c,1);n.inputs['Roughness'].default_value=.8
 if emit:n.inputs['Emission Color'].default_value=(*c,1);n.inputs['Emission Strength'].default_value=1.5
 return m
cable=mat('HumanCable',(0.32,.125,.048));polyps=mat('Polyps',(0.135,.724,.823),True)
def tube(name,pts,r,material):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=1;c.resolution_u=1;s=c.splines.new('POLY');s.points.add(len(pts)-1)
 for a,b in zip(s.points,pts):a.co=(*b,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(material);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False);return o
centers=[(48,-9,1.8),(52,-9,1.8),(50,-9,1.8+math.sqrt(12))]
for i,(x,y,z) in enumerate(centers):
 bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=6,location=(x,y,z),rotation=(math.pi/2,0,0),major_radius=.8,minor_radius=.08);o=bpy.context.object;o.name=f'Gnezdo{i}';o.data.materials.append(mineral);o.select_set(False)
 # Shallow mineral bowl facing approach (+Z glTF = -Y Blender).
 verts=[(x,y+.35,z)]+[(x+.76*math.cos(j*math.tau/20),y,z+.76*math.sin(j*math.tau/20)) for j in range(20)]
 me=bpy.data.meshes.new('Bowl');me.from_pydata(verts,[],[(0,j+1,(j+1)%20+1) for j in range(20)]);ob=bpy.data.objects.new(f'Chasha{i}',me);bpy.context.collection.objects.link(ob);me.materials.append(mineral)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=6,location=(x,y-.12,z));o=bpy.context.object;o.name=f'Stvorka{i}';o.scale=(.85,.06,.75);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mineral)
 # Arc axis X, pivot one metre behind the lid, opening by -90 degrees.
 pivot=Vector((x,y+.88,z));delta=o.location-pivot
 for v in o.data.vertices:v.co+=delta
 o.location=pivot;o.select_set(False)
for i,x in enumerate((48,52)):
 pts=[(x+(j/12)*(.8 if i==0 else -.8),-9.15-5*(j/12),1.8-1.4*math.sin(j/12*math.pi/2)) for j in range(13)]
 tube(f'Cable{i}',pts,.04,cable)
parts=[]
for a in (-1,0,1):parts.append(tube('Vein',[(54+a*1.2*(1-t),-9.3,2+t*1.8) for t in [j/6 for j in range(7)]],.035,mineral))
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();parts[0].name='Diagnostika';bpy.ops.object.select_all(action='DESELECT')
for i in range(12):
 a=i*2.4;x=47+(i%4)*1.7;z=.6+(i//4)*.3
 tube(f'Polyp{i}',[(x,-9,z),(x+.08*math.cos(a),-9.3,z+.25)],.045,polyps)
# Raise the contact assembly onto a continuous mineral growth outside the passage.
for ob in list(bpy.context.scene.objects):
 if ob.type=='MESH' and not ob.name.startswith('LOD'):ob.location.y-=3.3
bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(50,-11.3,3.2))
base=bpy.context.object;base.name='ContactGrowth';base.scale=(4.5,1.5,3.2);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);base.data.materials.append(mineral)
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':
  for face in ob.data.polygons:face.use_smooth=True
# Triangulation and exported draft.
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.data.calc_loop_triangles()
r={o.name:len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'}
bpy.ops.export_scene.gltf(filepath=str(p/'terrasa-draft-v6.glb'),export_format='GLB',export_image_format='JPEG',export_jpeg_quality=80,export_animations=False)
(p/'assembly-v6.json').write_text(json.dumps({'triangles':r,'bytes':(p/'terrasa-draft-v6.glb').stat().st_size,'status':'DRAFT: surface fit, lids, UV and final views unverified'},indent=2))

