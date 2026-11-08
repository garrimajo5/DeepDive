import bpy,pathlib,math,json
p=pathlib.Path(r'C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-023-terrasa-vrat')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p/'arch-draft.glb'))
r=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 for v in o.data.vertices:
  x=v.co.x; w=max(0,min(1,(46-v.co.z)/9)); v.co.x=x*(1-w)+math.copysign(60*(abs(x)/60)**0.40,x)*w
 bad=[v.co for v in o.data.vertices if abs(v.co.x)<30 and 0.01<v.co.z<36]
 r.append({'name':o.name,'intruding_vertices':len(bad)})
bpy.ops.export_scene.gltf(filepath=str(p/'arch-draft-v4.glb'),export_format='GLB',export_image_format='JPEG',export_jpeg_quality=80,export_animations=False)
(p/'clearance-v4.json').write_text(json.dumps(r,indent=2));print(r)


