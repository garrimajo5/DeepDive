extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var sc=load("res://study.glb").instantiate()
 root.add_child(sc)
 var sks=sc.find_children("*","Skeleton3D",true,false)
 var aps=sc.find_children("*","AnimationPlayer",true,false)
 var meshes=sc.find_children("*","MeshInstance3D",true,false)
 var skins=0
 for m in meshes:
  if m.skin!=null:skins+=1
 var ap=aps[0]
 var lens={}
 for n in ap.get_animation_list():lens[n]=ap.get_animation(n).length
 var metrics={}
 var tool=load("res://clip_tip.gd")
 for hz in [30,60]:metrics[str(hz)]=tool.measure(root,"res://study.glb","Tail03",Vector3(0,-.19,4.2),hz)
 var old={}
 for hz in [30,60]:old[str(hz)]=tool.measure(root,"res://source.glb","Tail03",Vector3(0,-.19,4.2),hz)
 var result={"skeletons":sks.size(),"bones":sks[0].get_bone_count(),"meshes":meshes.size(),"skins":skins,"lengths":lens,"after":metrics,"before_same_import":old}
 var f=FileAccess.open("res://../godot-final.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(result,"  "))
 print(JSON.stringify(result))
 quit()
