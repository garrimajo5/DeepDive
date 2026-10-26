import bpy,bmesh
from pathlib import Path
R=Path('work/DeepDive/art/MOD-021-eholovec').resolve()
for p in R.glob('*.glb'):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(p));o=next(o for o in bpy.context.scene.objects if o.type=='MESH');b=bmesh.new();b.from_mesh(o.data);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.00001);print('QA',p.name,'boundary',sum(e.is_boundary for e in b.edges),'nonmanifold',sum(not e.is_manifold for e in b.edges));b.free()
