extends SceneTree
var meshes: Array = []
var materials: Dictionary = {}
var errors: Array = []
func visit(node: Node) -> void:
 if node is MeshInstance3D:
  var triangles: int = 0
  for s in node.mesh.get_surface_count():
   var a: Array = node.mesh.surface_get_arrays(s)
   triangles += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] != null and a[Mesh.ARRAY_INDEX].size() > 0 else a[Mesh.ARRAY_VERTEX].size()) / 3
   var mat: Material = node.mesh.surface_get_material(s)
   if mat is StandardMaterial3D:
    materials[mat.resource_name] = {"emission":mat.emission_enabled,"mask":mat.emission_texture != null,"normal":mat.normal_enabled,"roughness_map":mat.roughness_texture != null,"metallic":mat.metallic}
   var vs: PackedVector3Array = node.mesh.get_faces()
   for x in [-29.0,0.0,29.0]:
    for y in [0.1,18.0,35.9]:
     for t in range(0,vs.size(),3):
      if Geometry3D.ray_intersects_triangle(Vector3(x,y,50),Vector3(0,0,-1),node.global_transform*vs[t],node.global_transform*vs[t+1],node.global_transform*vs[t+2]) != null:
       errors.append("Blocked passage ray at %s,%s by %s" % [x,y,node.name])
  meshes.append({"node":str(node.name),"triangles":triangles,"scale":str(node.scale),"aabb":str(node.mesh.get_aabb())})
  if not node.scale.is_equal_approx(Vector3.ONE):errors.append("Non-unit scale: "+str(node.name))
 if node is Skeleton3D or node is AnimationPlayer:errors.append("Unexpected animation/skeleton")
 for child in node.get_children():visit(child)
func _initialize() -> void:
 call_deferred("_audit")
func _audit() -> void:
 var args: PackedStringArray = OS.get_cmdline_user_args()
 var doc := GLTFDocument.new()
 var state := GLTFState.new()
 var err := doc.append_from_file(args[0],state)
 if err != OK: push_error("GLTF load failed: "+str(err));quit(1);return
 var scene := doc.generate_scene(state)
 root.add_child(scene)
 visit(scene)
 var report := {"godot":Engine.get_version_info().string,"mesh_count":meshes.size(),"meshes":meshes,"materials":materials,"errors":errors,"ray_grid":"3 x 3 rays through each mesh; full triangle volume clipping is in Blender report"}
 var out := FileAccess.open(args[1],FileAccess.WRITE)
 out.store_string(JSON.stringify(report,"  "));out.close()
 print(JSON.stringify({"mesh_count":meshes.size(),"materials":materials,"errors":errors}))
 scene.queue_free();quit(0 if errors.is_empty() else 1)
