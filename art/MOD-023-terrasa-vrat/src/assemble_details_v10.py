import bpy,math,pathlib,json,numpy as np
from mathutils import Vector
p=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p/'arch-draft-v10.glb'))
mineral=bpy.data.objects['LOD0_Mineral'].data.materials[0]
static=[];moving=[]
def mesh(name,verts,faces,mat,move=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);me.materials.append(mat)
 uv=me.uv_layers.new();lo=[min(v[k] for v in verts) for k in range(3)];hi=[max(v[k] for v in verts) for k in range(3)]
 for f in me.polygons:
  f.use_smooth=True
  for li in f.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co;u=(v.x-lo[0])/max(.001,hi[0]-lo[0]);w=(v.z-lo[2])/max(.001,hi[2]-lo[2]);uv.data[li].uv=(.51+.48*u,.51+.48*w) if mat==mineral else (u,w)
 (moving if move else static).append(o);return o

def ring(name,c,profiles,n=24):
 x,y,z=c;v=[]
 for radius,depth in profiles:
  for j in range(n):
   a=j*math.tau/n;r=radius*(1+.025*math.sin(3*a));v.append((x+r*math.cos(a),y+depth,z+r*math.sin(a)))
 faces=[]
 for k in range(len(profiles)-1):
  for j in range(n):a=k*n+j;b=k*n+(j+1)%n;faces.append((a,b,b+n) if k==len(profiles)-2 and profiles[-1][0]==0 else (a,b,b+n,a+n))
 return mesh(name,v,faces,mineral)
centers=[(48,-11.8,1.8),(52,-11.8,1.8),(50,-11.8,1.8+math.sqrt(12))]
for i,c in enumerate(centers):
 x,y,z=c
 ring('Socket'+str(i),c,[(1.45,2.6),(.92,.05),(.80,0),(.63,.35),(0,.35)])
 for a in (math.pi/2,math.pi*7/6,math.pi*11/6):
  ring('Port', (x+.36*math.cos(a),y+.32,z+.36*math.sin(a)),[(.14,0),(.1,-.035),(.075,.04)],8)
 # Thin lenticular lid: explicit 1.7 x 1.5 x .12, origin on arc axis.
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=6,location=(x,y-.09,z));o=bpy.context.object;o.name=f'Stvorka{i}';o.scale=(.85,.06,.75);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mineral)
 for uv in o.data.uv_layers.active.data:uv.uv=Vector((.51,.51))+uv.uv*.48
 pivot=Vector((x,y-.09+.7,z+.7));delta=o.location-pivot
 for v in o.data.vertices:v.co+=delta
 o.location=pivot;moving.append(o);o.select_set(False)

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
verts=[(54.5,-11.55,3.0)]
for rx,rz,depth in [(1.55,1.0,-11.55),(1.8,1.2,-9.0)]:
 for j in range(16):
  a=j*math.tau/16;verts.append((54.5+rx*math.cos(a),depth,3.0+rz*math.sin(a)))
faces=[(0,j+1,(j+1)%16+1) for j in range(16)]+[(j+1,(j+1)%16+1,(j+1)%16+17,j+17) for j in range(16)]
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
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();ob=group[0];ob.name=f'LOD{lod}_{mat.name}';ob.parent=root;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
for o in static:bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
r={}
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.data.calc_loop_triangles();r[o.name]=len(o.data.loop_triangles)
bpy.ops.export_scene.gltf(filepath=str(p/'terrasa-draft-v10.glb'),export_format='GLB',export_image_format='JPEG',export_jpeg_quality=78,export_animations=False)
(p/'assembly-v10.json').write_text(json.dumps({'triangles':r,'cable_lengths':lengths,'bytes':(p/'terrasa-draft-v10.glb').stat().st_size,'socket_centers_blender':centers,'lid_axis':'X, -90 degrees, +1.4m elevation'},indent=2))
