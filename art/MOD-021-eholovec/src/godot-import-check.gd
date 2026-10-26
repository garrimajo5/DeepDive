extends SceneTree
func _initialize():
 var base="C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/DeepDive/art/MOD-021-eholovec/"
 for part in ["telo","uho","meshok","chelyust"]:
  var doc=GLTFDocument.new()
  var state=GLTFState.new()
  var err=doc.append_from_file(base+"eholovec-"+part+".glb",state)
  assert(err==OK,part)
  var scene=doc.generate_scene(state)
  assert(scene!=null)
  var meshes=scene.find_children("*","MeshInstance3D",true,false)
  if scene is MeshInstance3D: meshes.append(scene)
  assert(meshes.size()==1,part+" mesh count")
  var mesh=meshes[0].mesh
  assert(mesh.get_surface_count()==1)
  var mat=mesh.surface_get_material(0)
  assert(mat.albedo_texture.get_width()==1024)
  assert(mat.albedo_texture.get_height()==1024)
  print("PASS ",part," surfaces=1 texture=1024 emission=",mat.emission_enabled," aabb=",mesh.get_aabb())
  scene.free()
 quit()
