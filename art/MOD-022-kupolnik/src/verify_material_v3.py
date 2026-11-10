import bpy,json,numpy as np,struct
from pathlib import Path
P=Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik');p=P/'kupolnik-v3-draft.glb';raw=p.read_bytes();j=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(p))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');bs=next(n for n in o.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
def find(node):
 if node.type=='TEX_IMAGE':return node.image
 for i in node.inputs:
  for l in i.links:
   r=find(l.from_node)
   if r:return r
im=find(bs.inputs['Roughness'].links[0].from_node);a=np.array(im.pixels[:]).reshape(-1,4);o.data.calc_loop_triangles()
r={'file_bytes':len(raw),'triangles':len(o.data.loop_triangles),'roughness_G_minmax':[float(a[:,1].min()),float(a[:,1].max())],'metallic_B_max':float(a[:,2].max()),'material':j['materials'],'nodes':j['nodes'],'skins':len(j.get('skins',[])),'animations':len(j.get('animations',[])),'status':'DRAFT; topology and valve criteria failed visual inspection'}
assert r['roughness_G_minmax'][0]>.74
(P/'verification-v3.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
