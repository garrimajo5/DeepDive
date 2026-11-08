import bpy,pathlib,json
p=pathlib.Path(r'C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-023-terrasa-vrat')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p/'arch-draft-v3.glb'))
def clip(poly,axis,bound,sign):
 out=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  da=(a[axis]-bound)*sign;db=(b[axis]-bound)*sign
  if da>=0:out.append(a)
  if (da>=0)!=(db>=0):out.append(a+(b-a)*(da/(da-db)))
 return out
r=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 o.data.calc_loop_triangles();bad=0
 for t in o.data.loop_triangles:
  poly=[o.matrix_world@o.data.vertices[i].co for i in t.vertices]
  for axis,bound,sign in [(0,-29.999,1),(0,29.999,-1),(2,0.001,1),(2,35.999,-1)]:
   if not poly:break
   poly=clip(poly,axis,bound,sign)
  if len(poly)>=3:bad+=1
 r.append({'name':o.name,'triangles_intersecting_passage':bad})
(p/'triangle-clearance-v3.json').write_text(json.dumps(r,indent=2));print(r)
