extends SceneTree
func _initialize():
 var doc = GLTFDocument.new()
 var state = GLTFState.new()
 var err = doc.append_from_file("../kupolnik.glb", state)
 var result = {"godot": Engine.get_version_info().string, "append_error": err}
 if err != OK:
  print(JSON.stringify(result)); quit(1); return
 var scene = doc.generate_scene(state)
 var stack = [scene]
 var meshes = 0
 var triangles = 0
 var surfaces = 0
 while not stack.is_empty():
  var node = stack.pop_back()
  stack.append_array(node.get_children())
  if node is MeshInstance3D:
   meshes += 1
   for i in range(node.mesh.get_surface_count()):
    surfaces += 1
    var a = node.mesh.surface_get_arrays(i)
    triangles += a[Mesh.ARRAY_INDEX].size() / 3
    result["aabb"] = str(node.mesh.get_aabb())
    var mat = node.mesh.surface_get_material(i)
    result["metallic"] = mat.metallic
    result["emission_enabled"] = mat.emission_enabled
 result["mesh_instances"] = meshes
 result["surfaces"] = surfaces
 result["triangles"] = triangles
 var f = FileAccess.open("../godot-verification.json", FileAccess.WRITE)
 f.store_string(JSON.stringify(result, "  ")); f.close()
 print(JSON.stringify(result))
 scene.free()
 quit(0 if meshes == 1 and triangles <= 8000 else 1)
