extends SceneTree
func _initialize():
 var data=[]
 for part in HullPlan.parts():
  if not HullMesh.drawn(part): continue
  var b=HullMesh.unit(part.form)
  var xf=part.xform()
  var vertices=[]
  for v in b.pos:
   var q=xf*v
   vertices.append([q.x,q.y,q.z])
  data.append({"name":part.name,"paint":part.paint,"vertices":vertices,"indices":Array(b.idx)})
 var f=FileAccess.open("res://hull.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(data))
 print("EXPORTED ",data.size()," hull parts")
 quit()
