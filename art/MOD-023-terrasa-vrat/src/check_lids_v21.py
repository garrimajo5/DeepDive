import bpy,pathlib,json,math
from mathutils.bvhtree import BVHTree
p=pathlib.Path(__file__).resolve().parents[1];bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p/'terrasa-vrat-v21.glb'))
def tree(o):
 o.data.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[t.vertices for t in o.data.loop_triangles],all_triangles=True)
report={}
for lod in range(3):
 static=tree(bpy.data.objects[f'LOD{lod}_Mineral']);report[f'LOD{lod}']={}
 for name in ['Stvorka0','Stvorka1','Stvorka2']:
  o=bpy.data.objects[name];o.rotation_mode='XYZ';a=[]
  for deg in range(0,91,5):
   o.rotation_euler.x=-math.radians(deg);bpy.context.view_layer.update();a.append({'degrees':deg,'overlapping_triangle_pairs':len(static.overlap(tree(o)))})
  report[f'LOD{lod}'][name]=a
(p/'lid-clearance-v21.json').write_text(json.dumps(report,indent=2))
print('overlaps',[(lod,name,item) for lod,objects in report.items() for name,items in objects.items() for item in items if item['overlapping_triangle_pairs']])
assert not any(item['overlapping_triangle_pairs'] for objects in report.values() for items in objects.values() for item in items)
