import bpy,json,pathlib
from mathutils import Vector
root=pathlib.Path(r'C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-023-terrasa-vrat')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
report=[]; shared=None
for i in range(3):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(root/f'lod{i}-source/model.glb'))
 objs=[o for o in bpy.data.objects if o not in before and o.type=='MESH']
 for o in objs:
  pts=[o.matrix_world@Vector(c) for c in o.bound_box];lo=Vector([min(p[j] for p in pts) for j in range(3)]);hi=Vector([max(p[j] for p in pts) for j in range(3)])
  # Blender import maps glTF Y-up to Blender Z-up.
  dims=hi-lo;center=(lo+hi)/2
  for v in o.data.vertices:
   p=o.matrix_world@v.co
   v.co=((p.x-center.x)*120/dims.x,(p.y-center.y)*23/dims.y,(p.z-lo.z)*58/dims.z)
  o.matrix_world.identity();o.name=f'LOD{i}_Mineral'
  parent=bpy.data.objects.new(f'LOD{i}',None);bpy.context.collection.objects.link(parent);o.parent=parent
  if shared is None:
   shared=o.data.materials[0]
   for n in shared.node_tree.nodes:
    if n.type=='BSDF_PRINCIPLED':
     for link in list(n.inputs['Metallic'].links):shared.node_tree.links.remove(link)
     n.inputs['Metallic'].default_value=0
     n.inputs['Emission Color'].default_value=(0,0,0,1)
    if n.type=='TEX_IMAGE' and n.image:
     n.image.scale(1024,1024)
  o.data.materials.clear();o.data.materials.append(shared)
  o.data.calc_loop_triangles()
  report.append({'lod':i,'triangles':len(o.data.loop_triangles),'size_m':[120,58,23]})
bpy.ops.export_scene.gltf(filepath=str(root/'arch-draft.glb'),export_format='GLB',export_image_format='JPEG',export_jpeg_quality=80,export_animations=False)
report.append({'bytes':(root/'arch-draft.glb').stat().st_size,'status':'DRAFT: contact details and clearance checks pending'})
(root/'arch-report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
