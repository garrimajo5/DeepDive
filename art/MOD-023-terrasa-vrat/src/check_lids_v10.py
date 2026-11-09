import bpy,pathlib,json,math
from mathutils.bvhtree import BVHTree
p=pathlib.Path(__file__).resolve().parents[1];bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p/'terrasa-draft-v10.glb'))
def tree(o):
 o.data.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[t.vertices for t in o.data.loop_triangles],all_triangles=True)
static=tree(bpy.data.objects['LOD0_Mineral']);report={}
for name in ['Stvorka0','Stvorka1','Stvorka2']:
 o=bpy.data.objects[name];o.rotation_mode='XYZ';a=[]
 for deg in [0,15,30,45,60,75,90]:
  o.rotation_euler.x=-math.radians(deg);bpy.context.view_layer.update();a.append({'degrees':deg,'overlapping_triangle_pairs':len(static.overlap(tree(o)))})
 report[name]=a
(p/'lid-clearance-v10.json').write_text(json.dumps(report,indent=2));print(report)
