import bpy,math,pathlib,json,numpy as np
from mathutils import Vector
p=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p/'arch-draft-v16.glb'))
mineral=bpy.data.objects['LOD0_Mineral'].data.materials[0]
static=[];moving=[]
def mesh(name,verts,faces,mat,move=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);me.materials.append(mat)
 uv=me.uv_layers.new();lo=[min(v[k] for v in verts) for k in range(3)];hi=[max(v[k] for v in verts) for k in range(3)]
 for f in me.polygons:
  f.use_smooth=True
  for li in f.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co;u=(v.x-lo[0])/max(.001,hi[0]-lo[0]);w=(v.z-lo[2])/max(.001,hi[2]-lo[2]);uv.data[li].uv=(.76+.23*u,.88+.11*w) if mat==mineral else (u,w)
 (moving if move else static).append(o);return o

def ring(name,c,profiles,n=24):
 x,y,z=c;v=[]
 for radius,depth in profiles:
  for j in range(n):
   a=j*math.tau/n;r=radius*(1+.025*math.sin(3*a));point=Vector((x+r*math.cos(a),y+depth,z+r*math.sin(a)))
   if False:
    hit,loc,norm,index=bpy.data.objects['LOD0_Mineral'].closest_point_on_mesh(point)
    if hit:point=loc
   v.append(tuple(point))
 faces=[]
 for k in range(len(profiles)-1):
  for j in range(n):a=k*n+j;b=k*n+(j+1)%n;faces.append((a,b,b+n) if k==len(profiles)-2 and profiles[-1][0]==0 else (a,b,b+n,a+n))
 return mesh(name,v,faces,mineral)
centers=[(48,-11.8,1.8),(52,-11.8,1.8),(50,-11.8,1.8+math.sqrt(12))]
from mathutils import Matrix
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(p/'cluster-remesh-v14-fine/model.glb'));source=next(o for o in bpy.data.objects if o not in before and o.type=='MESH')
rot=Matrix.Rotation(math.pi/4,4,'X');points=[rot@source.matrix_world@v.co for v in source.data.vertices]
source_centers=[(-.546,-.405),(.529,-.402),(-.0115,.144)]
# Affine layout correction outside the cups; local uniform scale retains circular rims.
A=np.array([[x,z,1] for x,z in source_centers]);tx=np.linalg.solve(A,np.array([48,52,50]));tz=np.linalg.solve(A,np.array([1.8,1.8,1.8+math.sqrt(12)]))
ob=source;ob.name='ContactCluster';ob.matrix_world.identity();ob.data.materials.clear();ob.data.materials.append(mineral)
for vertex,point in zip(ob.data.vertices,points):
 weights=[];targets=[]
 base=Vector((float(np.dot([point.x,point.z,1],tx)),-11.78+max(0,(point.y+.22)*5),float(np.dot([point.x,point.z,1],tz))))
 for (sx,sz),c in zip(source_centers,centers):
  dx=point.x-sx;dz=point.z-sz;radius=math.hypot(dx,dz);weight=max(0,min(1,(.44-radius)/.2));weight=weight*weight*(3-2*weight)
  target=Vector((c[0]+dx*4.7,-11.78+max(0,min(.35,(point.y+.22)*2)),c[2]+dz*4.7))
  weights.append(weight);targets.append(target)
 total=sum(weights)
 q=base*(1-min(1,total))
 for weight,target in zip(weights,targets):q+=target*weight/max(1,total)
 # Sink the rear mineral mass into the support; keep bowls and their rims at the specified plane.
 if point.y>.03:q.y+=min(4,(point.y-.03)*12)
 q.z=max(0,q.z)
 for cx,cy,cz in centers:
  if abs(q.x-cx)<1.2 and cz+.25<q.z<cz+2.5:q.y=max(q.y,-10.98)
 for cx,cy,cz in centers:
  rr=math.sqrt(((q.x-cx)/.85)**2+((q.z-cz)/.75)**2)
  if 1.05<rr<1.6 and q.z<cz+.25:
   w=math.sin((rr-1.05)/.55*math.pi);q.y=min(q.y,q.y*(1-w)+(-12.01)*w)
 vertex.co=q
for uv in ob.data.uv_layers.active.data:uv.uv=Vector((.5,.5))+Vector((uv.uv.x*.25,uv.uv.y*.5))
for face in ob.data.polygons:face.use_smooth=True
if ob.data.has_custom_normals:
 bpy.context.view_layer.objects.active=ob;bpy.ops.mesh.customdata_custom_splitnormals_clear()
static.append(ob)
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(p/'lid-remesh-v15/model.glb'));lid_source=next(o for o in bpy.data.objects if o not in before and o.type=='MESH')
lp=np.array([tuple(lid_source.matrix_world@v.co) for v in lid_source.data.vertices]);lc=lp.mean(axis=0);evals,axes=np.linalg.eigh(np.cov((lp-lc).T));normal=axes[:,0]
if normal[2]<0:normal=-normal
right=axes[:,2]
if right[0]<0:right=-right
up=np.cross(normal,right);local=np.stack([(lp-lc)@right,(lp-lc)@normal,(lp-lc)@up],axis=1);lo=local.min(axis=0);hi=local.max(axis=0);local=(local-(lo+hi)/2)/(hi-lo)*np.array([1.7,-.12,1.5])
for i,c in enumerate(centers):
 x,y,z=c;o=lid_source.copy();o.data=lid_source.data.copy();bpy.context.collection.objects.link(o);o.matrix_world.identity();o.name=f'Stvorka{i}';o.data.materials.clear();o.data.materials.append(mineral);pivot=Vector((x,y-.09+.7,z+.7))
 for v,point in zip(o.data.vertices,local):v.co=Vector(point)+Vector((x,y-.09,z))-pivot
 o.location=pivot
 for uv in o.data.uv_layers.active.data:uv.uv=Vector((.75,.5))+Vector((uv.uv.x*.25,uv.uv.y*.375))
 for face in o.data.polygons:face.use_smooth=True
 if o.data.has_custom_normals:
  bpy.context.view_layer.objects.active=o;bpy.ops.mesh.customdata_custom_splitnormals_clear()
 moving.append(o)
bpy.data.objects.remove(lid_source,do_unlink=True)
def simplemat(name,col):
 m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*col,1);b.inputs['Roughness'].default_value=.8;return m
cable=simplemat('HumanCable',(.332,.125,.047));polyp=simplemat('Polyps',(.08,.2,.22))
# Mask is dark on stalks, luminous near the rim, with a secondary pale-blue sector.
a=np.zeros((512,512,4),dtype=np.float32);a[:,:,3]=1
for y in range(512):
 t=y/511;gain=max(0,min(1,(t-.65)/.15));a[y,:,:3]=np.array((.1356,.7231,.8308))*gain;a[y,256:,:3]=np.array((.3231,.6939,.807))*gain
im=bpy.data.images.new('PolypEmissionMask',512,512,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(a.ravel());im.pack();n=polyp.node_tree.nodes.new('ShaderNodeTexImage');n.image=im;bs=polyp.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Strength'].default_value=1;polyp.node_tree.links.new(n.outputs['Color'],bs.inputs['Emission Color'])

def tube(name,pts,r,mat,sides=6,move=False):
 verts=[]
 for k,q in enumerate(pts):
  d=Vector(pts[min(k+1,len(pts)-1)])-Vector(pts[max(0,k-1)]);d.normalize();u=d.cross(Vector((0,1,0)))
  if u.length<.01:u=d.cross(Vector((0,0,1)))
  u.normalize();v=d.cross(u)
  for j in range(sides):verts.append(tuple(Vector(q)+r*(math.cos(j*math.tau/sides)*u+math.sin(j*math.tau/sides)*v)))
 faces=[(k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j) for k in range(len(pts)-1) for j in range(sides)]
 return mesh(name,verts,faces,mat,move)
lengths=[]
for i,x in enumerate((48,52)):
 pts=[((48+5*j/12) if i==0 else (52-2*j/12+2.25*math.sin(j/12*math.pi)),-11.98,(1.8-1.5*math.sin(j/12*math.pi)) if i==0 else (1.8+math.sqrt(12)*j/12)) for j in range(13)]
 lengths.append(sum((Vector(a)-Vector(b)).length for a,b in zip(pts,pts[1:])))
 tube('Cable'+str(i),pts,.04,cable)
 for k in (0,6,12):
  q=pts[k];tube('Clamp',[(q[0]-.07,q[1],q[2]),(q[0]+.07,q[1],q[2])],.07,cable,6)
# Local grown diagnostic surface, matching the 2.8 x 1.8 m relief footprint.
verts=[]
for row in range(7):
 for col in range(7):
  u=(col-3)/3;v=(row-3)/3;edge=max(abs(u),abs(v));depth=-11.55+max(0,(edge-.72)/.28)*2.55
  angle=math.atan2(v,u);rough=1+.08*math.sin(angle*5)+.035*math.sin(angle*9);verts.append((54.5+u*math.sqrt(1-v*v/2)*1.85*rough,depth,3+v*math.sqrt(1-u*u/2)*1.3*rough))
faces=[(row*7+col,row*7+col+1,(row+1)*7+col+1,(row+1)*7+col) for row in range(6) for col in range(6)]
mesh('DiagnosticGrowth',verts,faces,mineral)
parts=[]
for branch in (-1,0,1):
 pts=[]
 for j in range(5):
  t=j/4;x=54.5+branch*1.4*(1-t);z=2.1+1.8*t
  # Base is a shallow conical surface; veins lie on its front with 0.07m relief.
  radius=math.sqrt(((x-54.5)/1.65)**2+((z-3.0)/1.1)**2)
  pts.append((x,-11.585,z))
 parts.append(tube('Vein',pts,.035,mineral,4,True))
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();parts[0].name='Diagnostika';pivot=Vector((54.5,-11.585,3.0));
for v in parts[0].data.vertices:v.co-=pivot
parts[0].location=pivot;bpy.ops.object.select_all(action='DESELECT')
for i in range(8):
 x=47.5+(i%4)*1.5;z=.65+(i//4)*.5;tube('Polyp',[(x,-11.2,z),(x,-11.45,z+.23),(x,-11.42,z+.28)],.055,polyp,4)
# Shared moving parts outside LODs; static detail merged once per material under each LOD.
for lod in range(3):
 root=bpy.data.objects[f'LOD{lod}']
 for mat in (mineral,cable,polyp):
  group=[]
  if mat==mineral:group=[bpy.data.objects[f'LOD{lod}_Mineral']]
  for src in static:
   if src.data.materials[0]!=mat:continue
   cp=src.copy();cp.data=src.data.copy();bpy.context.collection.objects.link(cp);group.append(cp)
   if src.name=='ContactCluster' and lod>0:
    bpy.context.view_layer.objects.active=cp;mod=cp.modifiers.new('Contact distance simplification','DECIMATE');mod.ratio=.39 if lod==1 else .35;bpy.ops.object.modifier_apply(modifier=mod.name);cp.data.validate(clean_customdata=True)
    for v in cp.data.vertices:
     for cx,cy,cz in centers:
      rr=math.sqrt(((v.co.x-cx)/.85)**2+((v.co.z-cz)/.75)**2)
      if rr<1.04:v.co.y=max(v.co.y,-11.76)
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();ob=group[0];ob.name=f'LOD{lod}_{mat.name}';ob.parent=root;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
for o in static:bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
import bmesh
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':
  bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bad=[f for f in bm.faces if f.calc_area()<1e-8]
  if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
  bm.to_mesh(ob.data);bm.free();ob.data.validate(clean_customdata=True);ob.data.update()
# Restore local movement clearances after simplifying the static mineral.
from mathutils.bvhtree import BVHTree
def bvh(ob):
 ob.data.calc_loop_triangles();return BVHTree.FromPolygons([ob.matrix_world@v.co for v in ob.data.vertices],[t.vertices for t in ob.data.loop_triangles],all_triangles=True)
for lod in range(3):
 ob=bpy.data.objects[f'LOD{lod}_Mineral']
 # Long LOD edges crossing the top corners of the passage need a small horizontal margin.
 for tri in ob.data.loop_triangles:
  vv=[ob.data.vertices[k] for k in tri.vertices]
  if min(v.co.z for v in vv)<36 and max(v.co.z for v in vv)>36:
   for v in vv:
    if 36<=v.co.z<38.5 and abs(v.co.x)<32.5:v.co.x=math.copysign(32.5,v.co.x)
 for iteration in range(4):
  touched=set()
  for name in ['Stvorka0','Stvorka1','Stvorka2']:
   lid=bpy.data.objects[name];lid.rotation_mode='XYZ'
   for degrees in range(0,91,5):
    lid.rotation_euler.x=-math.radians(degrees);bpy.context.view_layer.update();pairs=bvh(ob).overlap(bvh(lid))
    for face_index,_ in pairs:
     for k in ob.data.loop_triangles[face_index].vertices:
      ob.data.vertices[k].co.y=max(ob.data.vertices[k].co.y,-11.74 if degrees<=15 else -10.94);touched.add(k)
   lid.rotation_euler.x=0
  ob.data.update();bpy.context.view_layer.update()
  if not touched:break
r={}
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.data.calc_loop_triangles();r[o.name]=len(o.data.loop_triangles)
bpy.ops.export_scene.gltf(filepath=str(p/'terrasa-vrat-v16.glb'),export_format='GLB',export_image_format='JPEG',export_jpeg_quality=65,export_image_quality=65,export_animations=False)
(p/'assembly-v16.json').write_text(json.dumps({'triangles':r,'cable_lengths':lengths,'bytes':(p/'terrasa-vrat-v16.glb').stat().st_size,'socket_centers_blender':centers,'lid_axis':'X, -90 degrees, +1.4m elevation'},indent=2))
