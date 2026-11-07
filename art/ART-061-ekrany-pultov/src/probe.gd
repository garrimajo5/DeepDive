extends SceneTree
func _initialize():
 var n=load("res://models/pult-ekrany.glb").instantiate()
 for m in n.find_children("*","MeshInstance3D",true,false):
  print(m.name," ",m.get_aabb())
  var v=m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for index in 3:
   var pts=[]
   for p in v:
    var k=0 if p.x<-.35 else (2 if p.x>.35 else 1)
    if k==index:pts.append(p)
   print(index," ",pts)
 quit()
