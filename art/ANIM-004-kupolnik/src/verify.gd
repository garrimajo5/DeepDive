extends SceneTree
func _initialize():
 var doc = GLTFDocument.new()
 var state = GLTFState.new()
 var path = ProjectSettings.globalize_path("res://../kupolnik-anim.glb")
 var error = doc.append_from_file(path,state)
 if error != OK:
  push_error("GLB import: %s" % error)
  quit(1)
  return
 var scene = doc.generate_scene(state)
 root.add_child(scene)
 var skeletons = scene.find_children("*","Skeleton3D",true,false)
 var meshes = scene.find_children("*","MeshInstance3D",true,false)
 var players = scene.find_children("*","AnimationPlayer",true,false)
 var report = {"godot":Engine.get_version_info().string,"skeletons":skeletons.size(),"meshes":meshes.size(),"all_meshes_have_skin":true,"clips":{}}
 for mesh in meshes:
  if mesh.skin == null: report.all_meshes_have_skin=false
 for player in players:
  for clip in player.get_animation_list():report.clips[clip]=player.get_animation(clip).length
 var file=FileAccess.open("res://../godot-audit.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 var valid = skeletons.size()==1 and report.all_meshes_have_skin
 for clip in {"Idle":4.0,"Swim":3.0,"OpenPetal":5.0}:
  valid = valid and report.clips.has(clip) and abs(report.clips.get(clip,0)-{"Idle":4.0,"Swim":3.0,"OpenPetal":5.0}[clip])<.001
 quit(0 if valid else 1)
