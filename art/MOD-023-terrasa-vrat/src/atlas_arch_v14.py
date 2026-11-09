import bpy, pathlib, json, math, numpy as np
from mathutils import Vector
p=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
# Preserve each remesh's own UV/material pair, packed in separate atlas quadrants.
slots=[(0,0),(1,0),(0,1)]; atlas={}; evidence=[]
for i in range(3):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(p/f'lod{i}-source/model.glb'))
 o=next(o for o in bpy.data.objects if o not in before and o.type=='MESH');m=o.data.materials[0]
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 def findimage(socket):
  seen=set();todo=[link.from_node for link in socket.links]
  while todo:
   n=todo.pop()
   if n in seen:continue
   seen.add(n)
   if n.type=='TEX_IMAGE':return n.image
   todo.extend(l.from_node for s in n.inputs for l in s.links)
 for key,socket in [('color','Base Color'),('normal','Normal'),('rough','Roughness')]:
  im=findimage(bs.inputs[socket]);assert im,(i,key)
  evidence.append({'lod':i,'map':key,'image':im.name,'original_size':list(im.size)})
  im.scale(1024,1024);a=np.array(im.pixels[:],dtype=np.float32).reshape(1024,1024,4)
  if key not in atlas:atlas[key]=np.ones((2048,2048,4),dtype=np.float32)
  x,y=slots[i];atlas[key][y*1024:(y+1)*1024,x*1024:(x+1)*1024]=a
 pts=[o.matrix_world@Vector(c) for c in o.bound_box];lo=Vector([min(q[j] for q in pts) for j in range(3)]);hi=Vector([max(q[j] for q in pts) for j in range(3)]);d=hi-lo;c=(hi+lo)/2
 if i==0:
  raw=[o.matrix_world@v.co for v in o.data.vertices];zx=np.array([((q.x-c.x)*120/d.x,(q.z-lo.z)*58/d.z) for q in raw]);heights=np.linspace(0,58,117);mins=[];maxs=[]
  for height in heights:
   rows=zx[np.abs(zx[:,1]-height)<.6]
   if len(rows)==0:rows=zx[np.argsort(np.abs(zx[:,1]-height))[:20]]
   mins.append(float(np.min(np.abs(rows[:,0]))));maxs.append(float(np.max(np.abs(rows[:,0]))))
 import bmesh
 bm=bmesh.new();bm.from_mesh(o.data)
 for repeat in range(3):
  edges=[e for e in bm.edges if ((e.verts[0].co-e.verts[1].co).length*120/d.x)>8]
  if edges:bmesh.ops.subdivide_edges(bm,edges=edges,cuts=1,use_grid_fill=True)
 bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 for v in o.data.vertices:
  q=o.matrix_world@v.co;x=(q.x-c.x)*120/d.x;y=(q.y-c.y)*23/d.y;z=(q.z-lo.z)*58/d.z;source_inner=float(np.interp(z,heights,mins));source_outer=float(np.interp(z,heights,maxs));inner=float(np.interp(z,[0,4,12,20,28,36,40,58],[31.5,36,43,38,31.5,31.5,0,0]));outer=float(np.interp(z,[0,8,16,24,30,36,42,48,54,58],[60,57,56,46,45,43,35,20,7,.1]));t=max(0,min(1,(abs(x)-source_inner)/max(.01,source_outer-source_inner)));xx=inner+t*(outer-inner);taper=max(.035,max(0,1-z/58)**.65);v.co=(math.copysign(xx,x),y*taper,z+(6*math.sin(math.pi*(z-36)/22)*max(0,1-(xx/35)**2) if z>36 else 0))
 for v in o.data.vertices:
  if v.co.z>52:
   factor=max(.001,(58-v.co.z)/6)**1.5;v.co.x*=factor;v.co.y*=factor
 # Repair only long boundary triangles which cross the rectangular clearance.
 o.data.calc_loop_triangles()
 for tri in o.data.loop_triangles:
  vv=[o.data.vertices[k] for k in tri.vertices]
  if min(v.co.z for v in vv)<36 and max(v.co.z for v in vv)>36:
   for v in vv:
    if v.co.z>=36 and abs(v.co.x)<31.5:v.co.x=math.copysign(31.5,v.co.x)
 o.matrix_world.identity();o.name=f'LOD{i}_Mineral'
 root=bpy.data.objects.new(f'LOD{i}',None);bpy.context.collection.objects.link(root);o.parent=root
 for uv in o.data.uv_layers.active.data:uv.uv=(uv.uv+Vector(slots[i]))*.5
# Fourth quadrant is reserved for new contact geometry, never samples the whole arch atlas.
y,x=np.mgrid[0:1024,0:1024];x=x/1024;y=y/1024
rng=np.random.default_rng(23)
h=np.zeros_like(x)
for freq,amp in [(4,.13),(11,.07),(29,.045),(73,.018),(181,.007)]:
 for wave in range(5):
  angle=rng.uniform(0,math.tau);phase=rng.uniform(0,math.tau);h+=amp/3*np.sin((x*math.cos(angle)+y*math.sin(angle))*freq*math.tau+phase)
# Shallow mineral pores and elongated folds, no emissive.
for k in range(170):
 cx,cy=rng.uniform(0,1,2);rx=rng.uniform(.003,.018);ry=rx*rng.uniform(.5,2.5)
 d=np.sqrt(((x-cx)/rx)**2+((y-cy)/ry)**2)
 h-=.12*np.exp(-d*d*2);h+=.045*np.exp(-((d-1.2)*4)**2)
fold=np.sin((x*.7+y+np.sin(x*18)*.025)*90);h+=0*fold
shade=np.clip(.55+h,0,1);col=np.stack([.16+.28*shade,.24+.29*shade,.28+.29*shade,np.ones_like(x)],axis=-1)
atlas['color'][1024:,1024:]=col
gy,gx=np.gradient(h);normal=np.stack([-gx*35,-gy*35,np.ones_like(x)],axis=-1);normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
atlas['normal'][1024:,1024:,:3]=normal*.5+.5
atlas['rough'][1024:,1024:]=[1,.83,0,1]
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(p/'cluster-remesh-v14-fine/model.glb'));socket=next(o for o in bpy.data.objects if o not in before and o.type=='MESH');bs=next(n for n in socket.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for key,sock in [('color','Base Color'),('normal','Normal'),('rough','Roughness')]:
 im=findimage(bs.inputs[sock]);assert im;im.scale(768,1024);atlas[key][1024:,1024:1792]=np.array(im.pixels[:],dtype=np.float32).reshape(1024,768,4)
 evidence.append({'source':'cluster-remesh-v14','map':key,'size':[768,1024]})
for ob in list(bpy.data.objects):
 if ob not in before:bpy.data.objects.remove(ob,do_unlink=True)
m=bpy.data.materials.new('Mineral');m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=0
for key,a in atlas.items():
 im=bpy.data.images.new('MineralAtlas_'+key,2048,2048,alpha=False);im.colorspace_settings.name='sRGB' if key=='color' else 'Non-Color';im.pixels.foreach_set(a.ravel());im.pack();node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=im
 if key=='normal':
  nm=m.node_tree.nodes.new('ShaderNodeNormalMap');m.node_tree.links.new(node.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
 elif key=='rough':
  sep=m.node_tree.nodes.new('ShaderNodeSeparateColor');m.node_tree.links.new(node.outputs['Color'],sep.inputs[0]);m.node_tree.links.new(sep.outputs['Green'],bs.inputs['Roughness'])
 else:m.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.data.materials.clear();o.data.materials.append(m)
import bmesh
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':
  bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(ob.data);bm.free()
  if ob.data.has_custom_normals:
   bpy.context.view_layer.objects.active=ob; bpy.ops.mesh.customdata_custom_splitnormals_clear()
  for face in ob.data.polygons:face.use_smooth=True
ob=bpy.data.objects['LOD2_Mineral'];bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('LOD2 reserve for porous socket folds','DECIMATE');mod.ratio=.75;bpy.ops.object.modifier_apply(modifier=mod.name)
ob=bpy.data.objects['LOD0_Mineral'];bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Reserve for contact cluster','DECIMATE');mod.ratio=.92;bpy.ops.object.modifier_apply(modifier=mod.name)
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':ob.data.validate(clean_customdata=True);ob.data.update()
bpy.ops.export_scene.gltf(filepath=str(p/'arch-draft-v14.glb'),export_format='GLB',export_image_format='JPEG',export_jpeg_quality=65,export_image_quality=65,export_animations=False)
(p/'atlas-v14.json').write_text(json.dumps({'source_maps':evidence,'layout':'LOD0 lower-left; LOD1 lower-right; LOD2 upper-left; contact upper-right','bytes':(p/'arch-draft-v14.glb').stat().st_size},indent=2))
