import bpy,bmesh,numpy as np,json,math,struct
from pathlib import Path
from mathutils import Vector
P=Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik')
bpy.ops.wm.open_mainfile(filepath=str(P/'retopology-v5.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');m=o.data;mat=m.materials[0];bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
# Remove stale custom split normals after topology edits, then recalculate smooth surface normals.
bpy.context.view_layer.objects.active=o;o.select_set(True)
if m.has_custom_normals:bpy.ops.mesh.customdata_custom_splitnormals_clear()
for f in m.polygons:f.use_smooth=True
for n in mat.node_tree.nodes:
 if n.type=='NORMAL_MAP':n.inputs['Strength'].default_value=.4
m.calc_loop_triangles();uv=m.uv_layers.active.data
# Only shell-rim UV pixels can emit. Rasterize accepted shell triangle UVs; exclude pads/stems.
allow=np.zeros((1024,1024),bool)
for tri in m.loop_triangles:
 p=[m.vertices[v].co for v in tri.vertices]
 c=sum((v for v in p),p[0]*0)/3
 if c.z<.59 or c.y>1.0:continue
 q=np.array([uv[i].uv[:] for i in tri.loops])*1024
 lo=np.maximum(0,np.floor(q.min(0)).astype(int)-1);hi=np.minimum(1023,np.ceil(q.max(0)).astype(int)+1)
 if np.any(hi<lo):continue
 xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1)+.5,np.arange(lo[1],hi[1]+1)+.5)
 a,b,d=q;den=(b[1]-d[1])*(a[0]-d[0])+(d[0]-b[0])*(a[1]-d[1])
 if abs(den)<1e-8:continue
 u=((b[1]-d[1])*(xx-d[0])+(d[0]-b[0])*(yy-d[1]))/den
 v=((d[1]-a[1])*(xx-d[0])+(a[0]-d[0])*(yy-d[1]))/den
 allow[lo[1]:hi[1]+1,lo[0]:hi[0]+1]|=(u>=-.025)&(v>=-.025)&(u+v<=1.025)
for n in mat.node_tree.nodes:
 if n.type!='TEX_IMAGE' or not n.image:continue
 im=n.image;a=np.array(im.pixels[:],dtype=np.float32).reshape(1024,1024,4)
 if 'mask' in im.name.lower():
  a[~allow,:3]=0
  # Set exact sRGB #67DDEB in the PNG, export emissiveFactor=1.
  on=np.max(a[:,:,:3],axis=2)>.01;a[on,:3]=np.array([103,221,235])/255
  im.pixels.foreach_set(a.ravel());im.pack();print('EMISSION_PIXELS',int(on.sum()))
 elif im.name=='texture_0':
  cyan=(a[:,:,1]>a[:,:,0]*1.35)&(a[:,:,2]>a[:,:,0]*1.35)&(a[:,:,1]>.25)&~allow
  a[cyan,:3]=np.array([101,88,112])/255.;im.pixels.foreach_set(a.ravel());im.pack();print('STRAY_CYAN_REMOVED',int(cyan.sum()))
coords=np.array([v.co[:] for v in m.vertices]);shift=np.array([-(coords[:,0].min()+coords[:,0].max())/2,-(coords[:,1].min()+coords[:,1].max())/2,-coords[:,2].min()])
for v in m.vertices:v.co+=Vector(shift)
(P/'pivot-shift.json').write_text(json.dumps(shift.tolist()))
# Explicit metadata used by next ANIM order, in glTF axes.
o['front']='-Z';o['units']='metres';o['source']='Meshy multi-image-to-3d 01a1c58f-5908-77ba-aec4-ea6e408a106a; remesh 01a1c591-5794-74fe-909f-cce9f3bd0aa6'
bpy.ops.wm.save_as_mainfile(filepath=str(P/'kupolnik-source.blend'))
bpy.ops.export_scene.gltf(filepath=str(P/'kupolnik.glb'),export_format='GLB',use_selection=True,export_animations=False,export_extras=True)
