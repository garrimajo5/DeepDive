import bpy,pathlib,json,struct,math
from mathutils import Vector
p=pathlib.Path(__file__).resolve().parents[1];file=p/'terrasa-vrat-v18.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(file))
def clip(poly,axis,bound,sign):
 out=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  da=(a[axis]-bound)*sign;db=(b[axis]-bound)*sign
  if da>=0:out.append(a)
  if (da>=0)!=(db>=0):out.append(a+(b-a)*da/(da-db))
 return out
r={};allpoints=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 o.data.calc_loop_triangles();bad=0;degenerate=0
 pts=[o.matrix_world@v.co for v in o.data.vertices];allpoints+=pts
 for tri in o.data.loop_triangles:
  poly=[pts[v] for v in tri.vertices]
  if (poly[1]-poly[0]).cross(poly[2]-poly[0]).length<1e-9:degenerate+=1
  for axis,bound,sign in [(0,-23.999,1),(0,23.999,-1),(2,.001,1),(2,21.999,-1)]:
   if not poly:break
   poly=clip(poly,axis,bound,sign)
  if len(poly)>=3:bad+=1
 lo=[min(q[k] for q in pts) for k in range(3)];hi=[max(q[k] for q in pts) for k in range(3)]
 r[o.name]={'triangles':len(o.data.loop_triangles),'passage_intersections':bad,'degenerate':degenerate,'dimensions_gltf':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'scale':list(o.scale)}
lid=bpy.data.objects['Stvorka2'];before=sum((lid.matrix_world@v.co for v in lid.data.vertices),Vector())/len(lid.data.vertices);lid.rotation_mode='XYZ';lid.rotation_euler.x=-math.pi/2;bpy.context.view_layer.update();after=sum((lid.matrix_world@v.co for v in lid.data.vertices),Vector())/len(lid.data.vertices)
b=file.read_bytes();j=json.loads(b[20:20+struct.unpack_from('<I',b,12)[0]])
shared=sum(v['triangles'] for k,v in r.items() if not k.startswith('LOD'))
totals=[sum(v['triangles'] for k,v in r.items() if k.startswith(f'LOD{i}_'))+shared for i in range(3)]
image_sizes={im.name:list(im.size) for im in bpy.data.images if im.type=='IMAGE' and im.size[0]>0}
pivots={n['name']:n.get('translation',[0,0,0]) for n in j['nodes'] if n.get('name','').startswith(('Stvorka','Diagnostika'))}
report={'image_sizes':image_sizes,'pivots_gltf':pivots,'file_bytes':len(b),'lod_totals':totals,'moving_triangles':shared,'objects':r,'materials':j['materials'],'animations':len(j.get('animations',[])),'skins':len(j.get('skins',[])),'lid_opening_elevation':after.z-before.z,'overall_dimensions_gltf':[max(q[k] for q in allpoints)-min(q[k] for q in allpoints) for k in (0,2,1)]}
(p/'validation-v18.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k not in ['objects','materials']},indent=2))
assert len(b)<=5000000;assert all(n<=cap for n,cap in zip(totals,[42000,12000,5000]));assert shared<=2000;assert all(v['passage_intersections']==0 for v in r.values());assert len(j['materials'])==3;assert not j.get('animations');assert not j.get('skins')

assert all(v['degenerate']==0 for v in r.values());assert all(all(abs(s-1)<1e-6 for s in v['scale']) for v in r.values())
