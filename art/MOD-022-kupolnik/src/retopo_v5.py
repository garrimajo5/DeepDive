import bpy,bmesh,math,json,numpy as np
from pathlib import Path
from mathutils import Vector
P=Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(P/'kupolnik-v3-draft.glb'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');mat=o.data.materials[0]
bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bm.to_mesh(o.data);bm.free()
bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('BudgetBeforeRetopo','DECIMATE');mod.ratio=.73;bpy.ops.object.modifier_apply(modifier=mod.name)
bm=bmesh.new();bm.from_mesh(o.data);uv=bm.loops.layers.uv.active
# Reserve rightmost 64 atlas columns for rebuilt soft surfaces, preserving original UV islands.
for f in bm.faces:
 for l in f.loops:l[uv].uv.x*=.9375
ims={n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image}
for im in ims:
 w,h=im.size;arr=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4);out=arr.copy();out[:,:960]=arr[:,np.minimum((np.arange(960)*w/960).astype(int),w-1)]
 name=im.name.lower();print('IMAGE',name)
 if 'normal' in name:out[:,960:,:]=(.5,.5,1,1)
 elif 'metallic' in name or 'rough' in name:out[:,960:,:]=(1,.85,0,1)
 elif 'emiss' in name or 'mask' in name:out[:,960:,:]=(0,0,0,1)
 else:
  # Store the specified base-color palette in the reserved atlas strip.
  rgb=np.array([101,88,112])/255.;rgb=np.array([101,88,112])/255.
  for row in range(h):out[row,960:,:3]=rgb*(.92+.08*math.cos(row/h*math.pi*32))
  out[:,960:,3]=1
 im.pixels.foreach_set(out.ravel());im.pack()

def addface(vs,us=None):
 try:f=bm.faces.new(vs)
 except ValueError:return None
 f.smooth=True
 for k,l in enumerate(f.loops):l[uv].uv=(.941+(.055*(k%2)), .2+.6*((k//2)%2)) if us is None else us[k]
 return f

def band(a,b):
 # Connect equal closed rings with quads.
 for i in range(len(a)):addface([a[i],a[(i+1)%len(a)],b[(i+1)%len(b)],b[i]],[(.94+.055*i/len(a),.25),(.94+.055*(i+1)/len(a),.25),(.94+.055*(i+1)/len(a),.75),(.94+.055*i/len(a),.75)])
def bridge(a,b):
 # Angular zipper joins unequal boundary counts without loose seams.
 ia=ib=0;na=len(a);nb=len(b)
 while ia<na or ib<nb:
  ta=(ia+1)/na if ia<na else 2;tb=(ib+1)/nb if ib<nb else 2
  if abs(ta-tb)<1e-8:addface([a[ia%na],a[(ia+1)%na],b[(ib+1)%nb],b[ib%nb]]);ia+=1;ib+=1
  elif ta<tb:addface([a[ia%na],a[(ia+1)%na],b[ib%nb]]);ia+=1
  else:addface([a[ia%na],b[(ib+1)%nb],b[ib%nb]]);ib+=1

def cut(y,predicate):
 fs=[f for f in bm.faces if any(predicate(v.co) for v in f.verts)]
 geom=set(fs)
 for f in fs:geom.update(f.edges);geom.update(f.verts)
 bmesh.ops.bisect_plane(bm,geom=list(geom),dist=1e-7,plane_co=(0,y,0),plane_no=(0,1,0))
def ring_at(y,predicate):
 es=[e for e in bm.edges if e.is_boundary and all(abs(v.co.y-y)<1e-5 and predicate(v.co) for v in e.verts)]
 vs=list({v for e in es for v in e.verts})
 assert len(vs)>6,(y,len(vs))
 c=sum((v.co for v in vs),Vector())/len(vs)
 vs.sort(key=lambda v: math.atan2(v.co.z-c.z,v.co.x-c.x)%(2*math.pi))
 return vs,c
report={'parts':[]}
# Each replacement has six complete internal transverse rings, 16 vertices each.
for side,y0,y1 in [(-1,.60,.83),(0,.72,.92),(1,.60,.83)]:
 def pred(p):return p.z<.55 and (abs(p.x)<.25 if side==0 else p.x*side>.35)
 cut(y0,pred);cut(y1,pred)
 fs=[f for f in bm.faces if y0+1e-6<f.calc_center_median().y<y1-1e-6 and pred(f.calc_center_median())]
 bmesh.ops.delete(bm,geom=fs,context='FACES')
 a,ca=ring_at(y0,pred);b,cb=ring_at(y1,pred)
 padverts=[v for v in bm.verts if v.co.y>=y1-1e-5 and pred(v.co)]
 end=max(v.co.y for v in padverts);newstart=end-.45
 for v in padverts:v.co.y=newstart+(v.co.y-y1)*.45/(end-y1)
 cb.y=newstart
 prev=a;centers=[ca]
 for j in range(1,7):
  t=j/7;c=ca.lerp(cb,t);c.z-=.035*math.sin(math.pi*t)
  rx=(max(v.co.x for v in a)-min(v.co.x for v in a))*.5*(1-t)+(max(v.co.x for v in b)-min(v.co.x for v in b))*.5*t
  rz=(max(v.co.z for v in a)-min(v.co.z for v in a))*.5*(1-t)+(max(v.co.z for v in b)-min(v.co.z for v in b))*.5*t
  ring=[bm.verts.new(c+Vector((rx*math.cos(2*math.pi*k/16),0,rz*math.sin(2*math.pi*k/16)))) for k in range(16)]
  (bridge if j==1 else band)(prev,ring);prev=ring;centers.append(c)
 bridge(prev,b);centers.append(cb)
 report['parts'].append({'part':'grasper_'+str(side),'rings':6,'ring_vertices':16,'ring_centers_blender':[list(c) for c in centers]})
# Replace closed raw siphon tips by open, short tubes and three recessed organic valve leaves.
cut(-1.245,lambda p:True)
fs=[f for f in bm.faces if f.calc_center_median().y< -1.245-1e-6];bmesh.ops.delete(bm,geom=fs,context='FACES')
for side in [-1,1]:
 a,ca=ring_at(-1.245,lambda p:p.x*side>0)
 ca.x=side*.17;ca.z=.75;prev=a;N=20
 for j,(y,r) in enumerate([(-1.28,.117),(-1.36,.123),(-1.44,.125),(-1.48,.123),(-1.48,.101),(-1.39,.097),(-1.29,.09)]):
  c=Vector((ca.x,y,ca.z));ring=[bm.verts.new(c+Vector((r*math.cos(2*math.pi*k/N),0,r*math.sin(2*math.pi*k/N)))) for k in range(N)]
  (bridge if j==0 else band)(prev,ring);prev=ring
 # Three folds, each narrowing toward the throat, attached to the inner mouth ring.
 for petal in range(3):
  verts=[]
  for j in range(4):
   t=j/3;r=.095*(1-t)+.018*t;y=-1.30-.11*math.sin(math.pi*t/2)
   row=[]
   for k in range(6):
    ang=2*math.pi*petal/3+(k/5-.5)*(1.8*(1-.35*t));rr=r+.009*math.sin(math.pi*k/5)*math.sin(math.pi*t)
    row.append(bm.verts.new((ca.x+rr*math.cos(ang),y-.012*math.sin(math.pi*k/5),ca.z+rr*math.sin(ang))))
   verts.append(row)
  for j in range(3):
   for k in range(5):addface([verts[j][k],verts[j][k+1],verts[j+1][k+1],verts[j+1][k]])
 report['parts'].append({'part':'siphon_'+str(side),'mouth_blender':[ca.x,-1.48,ca.z],'diameter':.25,'outer_transverse_rings':3,'valve_folds':3})
# Mantle: insert three parallel deformation loops across its underside, retaining source contour/UV.
for z in [.49,.53,.57]:
 fs=[f for f in bm.faces if all(-1.1<v.co.y<.50 for v in f.verts) and any(abs(v.co.z-z)<.09 for v in f.verts)]
 geom=set(fs)
 for f in fs:geom.update(f.edges);geom.update(f.verts)
 bmesh.ops.bisect_plane(bm,geom=list(geom),dist=1e-7,plane_co=(0,0,z),plane_no=(0,0,1))
# Clean only orphan edges and vertices.
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
for f in bm.faces:f.smooth=True
bm.to_mesh(o.data);bm.free();o.data.update();o.data.calc_loop_triangles()
report['triangles']=len(o.data.loop_triangles);report['vertices']=len(o.data.vertices)
print(json.dumps(report));(P/'retopology-v5.json').write_text(json.dumps(report,indent=2))
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.wm.save_as_mainfile(filepath=str(P/'retopology-v5.blend'))
bpy.ops.export_scene.gltf(filepath=str(P/'kupolnik-v5-draft.glb'),export_format='GLB',use_selection=True,export_animations=False)
