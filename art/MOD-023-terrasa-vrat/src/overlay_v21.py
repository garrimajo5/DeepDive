import bpy,pathlib,numpy as np,json
p=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(p/'terrasa-vrat-v21.glb'))
o=bpy.data.objects['LOD0_Mineral'];o.data.calc_loop_triangles()
w,h=1054,576;scale=968/120;cx=544;floor=495
mask=np.zeros((h,w),bool)
verts=np.array([tuple(o.matrix_world@v.co) for v in o.data.vertices]);pts=np.stack([cx+verts[:,0]*scale,floor-verts[:,2]*scale],axis=1)
for tri in o.data.loop_triangles:
 a,b,c=pts[list(tri.vertices)];lo=np.maximum(np.floor(np.minimum(np.minimum(a,b),c)).astype(int),[0,0]);hi=np.minimum(np.ceil(np.maximum(np.maximum(a,b),c)).astype(int),[w-1,h-1])
 if np.any(hi<lo):continue
 yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];q=np.stack([xx+.5,yy+.5],axis=-1)
 def edge(u,v):return (v[0]-u[0])*(q[:,:,1]-u[1])-(v[1]-u[1])*(q[:,:,0]-u[0])
 e1,e2,e3=edge(a,b),edge(b,c),edge(c,a)
 inside=((e1>=0)&(e2>=0)&(e3>=0))|((e1<=0)&(e2<=0)&(e3<=0))
 mask[lo[1]:hi[1]+1,lo[0]:hi[0]+1]|=inside
im=bpy.data.images.load(str(p.parents[1]/'docs/concept-art/terrasa-vrat-ansambl.png'));iw,ih=im.size
arr=np.array(im.pixels[:],dtype=np.float32).reshape(ih,iw,4)[::-1,:][:h,:w].copy()
# Orange is the exported front projection; painting remains visible under it.
arr[mask,:3]=arr[mask,:3]*.6+np.array([1,.36,.06])*.4
edge=mask.copy();edge[1:-1,1:-1]&=~(mask[:-2,1:-1]&mask[2:,1:-1]&mask[1:-1,:-2]&mask[1:-1,2:])
arr[edge,:3]=[1,.45,.08]
x0,x1=round(cx-24*scale),round(cx+24*scale);y0,y1=round(floor-22*scale),floor
arr[y0:y0+3,x0:x1,:3]=[.1,1,.2];arr[y1-2:y1+1,x0:x1,:3]=[.1,1,.2]
arr[y0:y1,x0:x0+3,:3]=[.1,1,.2];arr[y0:y1,x1-2:x1+1,:3]=[.1,1,.2]
out=bpy.data.images.new('Overlay',w,h);out.pixels.foreach_set(arr[::-1].copy().ravel());out.filepath_raw=str(p/'overlay-v21.png');out.file_format='PNG';out.save()
(p/'overlay-v21.json').write_text(json.dumps({'pixels_per_metre':scale,'model_origin_pixel':[cx,floor],'width_120m_pixels':[60,1028],'passage_m':[48,22],'method':'LOD0 triangle projection, orange outline and 40% fill. Green clearance rectangle. No independent vertical rescaling. Concept crop 1054x576.'},indent=2))
