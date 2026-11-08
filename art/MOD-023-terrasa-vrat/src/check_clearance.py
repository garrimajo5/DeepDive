import bpy,pathlib,json
root=pathlib.Path(r'C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-023-terrasa-vrat')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root/'arch-draft.glb'))
r=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 points=[o.matrix_world@v.co for v in o.data.vertices]
 bad=[p for p in points if abs(p.x)<30 and 0.01<p.z<36]
 r.append({'name':o.name,'vertices_inside_required_passage':len(bad),'lowest_obstruction_m':min((p.z for p in bad),default=None)})
(root/'clearance-report.json').write_text(json.dumps(r,indent=2),encoding='utf8');print(json.dumps(r))
