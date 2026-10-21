import bpy,bmesh,numpy as np,json,math
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).parent;OUT=R.parent/'DeepDive/art/MOD-021-eholovec';OUT.mkdir(parents=True,exist_ok=True)
def lin(x):
 a=np.array(x)/255.;return np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4)
def cleanmat(o,name,ear=False):
 mat=o.data.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');im=bs.inputs['Base Color'].links[0].from_node.image;im.scale(1024,1024)
 a=np.array(im.pixels[:]).reshape(1024,1024,4);a[:,:,3]=1
 for n in list(nodes):
  if n.type not in ['OUTPUT_MATERIAL','BSDF_PRINCIPLED']:nodes.remove(n)
 for socket in ['Base Color','Emission Color','Metallic','Roughness','Normal']:
  for l in list(bs.inputs[socket].links):links.remove(l)
 tex=nodes.new('ShaderNodeTexImage');tex.image=im;links.new(tex.outputs['Color'],bs.inputs['Base Color']);bs.inputs['Metallic'].default_value=0;bs.inputs['Roughness'].default_value=.86;bs.inputs['Emission Color'].default_value=(0,0,0,1);bs.inputs['Emission Strength'].default_value=0
 if ear:
  em=np.zeros_like(a);em[:,:,3]=1
  mask=np.zeros((1024,1024),bool)
  o.data.update();o.data.calc_loop_triangles();uv=o.data.uv_layers.active
  for tri in o.data.loop_triangles:
   pts=[o.data.vertices[i].co for i in tri.vertices];c=sum(pts,Vector())/3;n=tri.normal
   radial=Vector((c.x-.1,c.y+.05,0));rr=radial.length
   # Interior faces point towards the bell axis and lie below the lip.
   if not (.34<c.z<.66 and .09<rr<.39 and n.dot(radial)<-.015):continue
   xy=np.array([uv.data[i].uv[:] for i in tri.loops])*1024
   x0=max(0,int(xy[:,0].min()));x1=min(1023,int(xy[:,0].max())+1);y0=max(0,int(xy[:,1].min()));y1=min(1023,int(xy[:,1].max())+1)
   if x1<x0 or y1<y0:continue
   X,Y=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5);A,B,C=xy;den=(B[1]-C[1])*(A[0]-C[0])+(C[0]-B[0])*(A[1]-C[1])
   if abs(den)<1e-6:continue
   u=((B[1]-C[1])*(X-C[0])+(C[0]-B[0])*(Y-C[1]))/den;v=((C[1]-A[1])*(X-C[0])+(A[0]-C[0])*(Y-C[1]))/den
   inside=(u>=0)&(v>=0)&(u+v<=1)
   # Only dark recess pixels on those interior polygons emit.
   lum=a[y0:y1+1,x0:x1+1,:3].mean(2);inside&=(lum<.20)
   mask[y0:y1+1,x0:x1+1]|=inside
  em[mask,:3]=lin([103,221,235]);e=bpy.data.images.new('ear-fold-emission',1024,1024);e.pixels[:]=em.ravel();e.filepath_raw=str(R/'emission.png');e.file_format='PNG';e.save();e=bpy.data.images.load(e.filepath_raw,check_existing=False);t=nodes.new('ShaderNodeTexImage');t.image=e;links.new(t.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.12;print('emission pixels',int(mask.sum()))
 mat.name=name;return mat

def cap(o):
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS');edges=[e for e in bm.edges if e.is_boundary]
 if edges:
  new=bmesh.ops.holes_fill(bm,edges=edges,sides=0).get('faces',[]);uv=bm.loops.layers.uv.active
  for f in new:
   if uv:
    for loop in f.loops:loop[uv].uv=(.02,.02)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()

def export(o,name,pivot=(0,0,0)):
 p=Vector(pivot)
 for v in o.data.vertices:v.co-=p
 o.location=(0,0,0);o.rotation_euler=(0,0,0);o.scale=(1,1,1);o.name=name
 o.data.validate(clean_customdata=False);o.data.update();o.data.calc_loop_triangles();bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_image_format='AUTO')
 vs=[v.co for v in o.data.vertices];lo=[min(v[i] for v in vs) for i in range(3)];hi=[max(v[i] for v in vs) for i in range(3)]
 return {'triangles':len(o.data.loop_triangles),'bounds_blender':[lo,hi],'pivot_godot':[p.x,p.z,-p.y]}

def weld(o):
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001);bm.to_mesh(o.data);bm.free();o.data.update()

def hull(o):
 bm=bmesh.new();bm.from_mesh(o.data);uv=bm.loops.layers.uv.active
 im=next(n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
 pixels=np.array(im.pixels[:]).reshape(1024,1024,4);target=np.array([75,97,110])/255.;yy,xx=np.unravel_index(np.square(pixels[:,:,:3]-target).sum(2).argmin(),(1024,1024));flat=Vector(((xx+.5)/1024,(yy+.5)/1024))
 bmesh.ops.delete(bm,geom=list(bm.faces),context='FACES_ONLY')
 result=bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
 trash=list(set(result.get('geom_interior',[])+result.get('geom_unused',[])))
 if trash:bmesh.ops.delete(bm,geom=trash,context='VERTS')
 for f in bm.faces:
  for l in f.loops:
   if uv:l[uv].uv=flat
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()

stats={};bpy.ops.wm.open_mainfile(filepath=str(R/'body-raw.blend'));body=next(o for o in bpy.context.scene.objects if o.type=='MESH');me=body.data;weld(body)
lo=[min(v.co[i] for v in me.vertices) for i in range(3)];hi=[max(v.co[i] for v in me.vertices) for i in range(3)];s=3/(hi[1]-lo[1])
for v in me.vertices:v.co=Vector(((v.co.x-(lo[0]+hi[0])/2)*s,(v.co.y-(lo[1]+hi[1])/2)*s,(v.co.z-lo[2])*s-.7))
bpy.context.view_layer.objects.active=body;mod=body.modifiers.new('budget','DECIMATE');mod.ratio=3300/4398;mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name);cleanmat(body,'echo-skin');dz=-.7-min(v.co.z for v in body.data.vertices)
for v in body.data.vertices:v.co.z+=dz
body.data.update()
# Use shared source vertices along each seam; the body keeps the exact edge of the extracted parts.
def group(c):
 f=-c.y
 if abs(c.x)<.33 and f>.80 and -.50<c.z<-.305:
  return 'chelyust' if f>1.15 else 'meshok'
 return 'telo'
for name in ['telo','meshok','chelyust']:
 o=body.copy();o.data=body.data.copy();bpy.context.collection.objects.link(o);bm=bmesh.new();bm.from_mesh(o.data)
 bmesh.ops.delete(bm,geom=[f for f in bm.faces if group(f.calc_center_median())!=name],context='FACES');bm.to_mesh(o.data);bm.free();cap(o)
 if name=='telo':
  back=body.copy();back.data=body.data.copy();bpy.context.collection.objects.link(back);bm=bmesh.new();bm.from_mesh(back.data)
  bmesh.ops.delete(bm,geom=[f for f in bm.faces if group(f.calc_center_median())=='telo'],context='FACES');bm.to_mesh(back.data);bm.free();cap(back);hull(back)
  center=sum((v.co for v in back.data.vertices),Vector())/len(back.data.vertices)
  for v in back.data.vertices:v.co=center+(v.co-center)*.85;v.co.z+=.055
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);back.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.join()
 if not o.data.vertices:raise ValueError(name+' empty')
 if name=='telo':pivot=(0,0,0)
 elif name=='chelyust':pivot=(0,-1.15,-.305)
 else:
  vs=[v.co for v in o.data.vertices];pivot=tuple((min(v[i] for v in vs)+max(v[i] for v in vs))/2 for i in range(3))
 if name!='telo':
  hull(o)
  for poly in o.data.polygons:poly.use_smooth=True
 stats[name]=export(o,'eholovec-'+name,pivot)

bpy.ops.wm.open_mainfile(filepath=str(R/'ear-raw.blend'));ear=next(o for o in bpy.context.scene.objects if o.type=='MESH');me=ear.data;weld(ear)
# Straighten the bell axis while retaining the generated folds and flexible stem.
rot=Matrix.Rotation(math.radians(-65),3,'X');neck=Vector((0,.18,-.15))
for v in me.vertices:
 w=max(0,min(1,(v.co.z+.5)/.45));q=rot@(v.co-neck)+neck;v.co=v.co.lerp(q,w)
lo=[min(v.co[i] for v in me.vertices) for i in range(3)];hi=[max(v.co[i] for v in me.vertices) for i in range(3)]
low=[v.co for v in me.vertices if v.co.z<lo[2]+.1];base=Vector((sum(v.x for v in low)/len(low),sum(v.y for v in low)/len(low),lo[2]))
for v in me.vertices:
 q=v.co-base;v.co=Vector((q.x/(hi[0]-lo[0]),q.y/(hi[0]-lo[0]),q.z*.8/(hi[2]-lo[2])));v.co.x+=.40*(v.co.z/.8)
 if v.co.z<.22:
  k=.2+.8*max(0,v.co.z/.22);v.co.x*=k;v.co.y*=k
cleanmat(ear,'echo-ear',True);cap(ear);bm=bmesh.new();bm.from_mesh(ear.data);bmesh.ops.create_icosphere(bm,subdivisions=1,radius=.09);bm.to_mesh(ear.data);bm.free();stats['uho']=export(ear,'eholovec-uho')
(R/'stats.json').write_text(json.dumps(stats,indent=2));print(json.dumps(stats))
