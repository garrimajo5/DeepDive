extends SceneTree
func _initialize():
 var results=[]
 for sex in ["muzhchina","zhenshchina"]:
  var filename="ekipazh-"+sex+".glb"
  var scene=load("res://"+filename).instantiate()
  root.add_child(scene)
  var skeletons=scene.find_children("*","Skeleton3D",true,false)
  var players=scene.find_children("*","AnimationPlayer",true,false)
  var sk=skeletons[0]
  var ap=players[0]
  var meshes=scene.find_children("*","MeshInstance3D",true,false)
  var skins_ok=true
  for mesh in meshes: skins_ok=skins_ok and mesh.skin!=null
  var clips={}
  for name in ap.get_animation_list():
   var anim=ap.get_animation(name)
   clips[name]={"length":anim.length,"loop_mode":anim.loop_mode,"tracks":anim.get_track_count()}
  var doc=GLTFDocument.new()
  var state=GLTFState.new()
  doc.append_from_file("res://original/"+filename,state)
  var original=doc.generate_scene(state)
  root.add_child(original)
  var osk=original.find_children("*","Skeleton3D",true,false)[0]
  var delta=0.0
  for i in sk.get_bone_count():
   var oi=osk.find_bone(sk.get_bone_name(i))
   var a=sk.get_bone_rest(i)
   var b=osk.get_bone_rest(oi)
   delta=max(delta,(a.origin-b.origin).length())
   for k in 3: delta=max(delta,(a.basis[k]-b.basis[k]).length())
  results.append({"file":filename,"mesh_count":meshes.size(),"all_meshes_skinned":skins_ok,"skeleton_count":skeletons.size(),"bones":sk.get_bone_count(),"rest_max_delta":delta,"clips":clips})
  scene.queue_free()
  original.queue_free()
 var f=FileAccess.open("res://godot-report.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(results,"  "))
 print(JSON.stringify(results))
 quit()
