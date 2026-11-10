import bpy,bmesh,json,struct,numpy as np,hashlib
from pathlib import Path
from mathutils import Vector
P=Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik');file=P/'kupolnik.glb'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(file))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');m=o.data;m.calc_loop_triangles();p=np.array([v.co[:] for v in m.vertices]);raw=file.read_bytes();j=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
areas=[(m.vertices[t.vertices[1]].co-m.vertices[t.vertices[0]].co).cross(m.vertices[t.vertices[2]].co-m.vertices[t.vertices[0]].co).length/2 for t in m.loop_triangles]
r={'file':'kupolnik.glb','sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'triangles':len(m.loop_triangles),'zero_area_triangles':sum(a<1e-12 for a in areas),'smallest_triangle_area_m2':min(areas),'dimensions_gltf_xyz_m':[(p[:,0].max()-p[:,0].min()),(p[:,2].max()-p[:,2].min()),(p[:,1].max()-p[:,1].min())],'bounds_gltf':[ [p[:,0].min(),p[:,2].min(),-p[:,1].max()], [p[:,0].max(),p[:,2].max(),-p[:,1].min()] ],'meshes':len(j['meshes']),'primitives':len(j['meshes'][0]['primitives']),'materials':j['materials'],'nodes':j['nodes'],'skins':len(j.get('skins',[])),'animations':len(j.get('animations',[])),'maps':[]}
for im in bpy.data.images:
 if len(im.pixels[:])==0:continue
 a=np.array(im.pixels[:]).reshape(-1,4);q={'name':im.name,'size':list(im.size),'rgb_min':a[:,:3].min(0).tolist(),'rgb_max':a[:,:3].max(0).tolist()}
 if 'mask' in im.name.lower():
  on=a[:,:3].max(1)>.01;q['emitting_pixels']=int(on.sum());q['emitting_rgb_unique']=np.unique(np.round(a[on,:3]*255).astype(int),axis=0).tolist()
 r['maps'].append(q)
# Independent geometric proof: six closed 16-edge ring contours remain after glTF triangulation.
bm=bmesh.new();bm.from_mesh(m);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-5)
shift=json.loads((P/'pivot-shift.json').read_text())
rs=json.loads((P/'retopology-v5.json').read_text());checks=[]
for part in rs['parts'][:3]:
 for c0 in part['ring_centers_blender'][1:-1]:
  c=[c0[i]+shift[i] for i in range(3)]
  vs=[v for v in bm.verts if abs(v.co.y-c[1])<1e-5 and abs(v.co.x-c[0])<.16 and abs(v.co.z-c[2])<.16]
  ids=set(vs);es=[e for e in bm.edges if all(v in ids for v in e.verts)]
  checks.append({'part':part['part'],'y_blender':c[1],'vertices':len(vs),'edges':len(es),'closed':len(vs)==16 and len(es)==16 and all(sum(v in e.verts for e in es)==2 for v in vs)})
r['transverse_rings']=checks;r['boundary_edges_after_position_weld']=sum(e.is_boundary for e in bm.edges);r['nonmanifold_multi_face_edges']=sum(len(e.link_faces)>2 for e in bm.edges);bm.free()
assert r['triangles']<=8000 and len(raw)<5000000 and r['zero_area_triangles']==0
assert r['meshes']==1 and r['primitives']==1 and len(r['materials'])==1 and r['skins']==r['animations']==0
assert all(c['closed'] for c in checks)
assert len(r['maps'])==4
assert all(q['size']==[1024,1024] for q in r['maps'])
(P/'verification-final.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
