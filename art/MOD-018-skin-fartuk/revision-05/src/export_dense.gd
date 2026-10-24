extends SceneTree
func _initialize():
 var args=OS.get_cmdline_user_args()
 var result={}
 for sex in ["m","zh"]:
  var doc=GLTFDocument.new()
  var st=GLTFState.new()
  assert(doc.append_from_file(args[0]+"/ekipazh-"+("muzhchina" if sex=="m" else "zhenshchina")+".glb",st)==OK)
  var scene=doc.generate_scene(st)
  root.add_child(scene)
  var sk=scene.find_children("*","Skeleton3D",true,false)[0]
  var names=PackedStringArray()
  var parents=PackedInt32Array()
  var local:Array[Transform3D]=[]
  for i in sk.get_bone_count():
   names.append(sk.get_bone_name(i));parents.append(sk.get_bone_parent(i));local.append(sk.get_bone_rest(i))
  var rest=CrewRig.Rest.new(names,parents,local)
  var poses={}
  var keys=["standing"]
  for i in 32:keys.append("walk"+str(i))
  for i in 9:keys.append("seat"+str(i))
  for i in range(10,21,2):keys.append("post"+str(i))
  for key in keys:
   var m=Crew.Member.new()
   m.follow(0,0,0,false,0,0.1)
   if key.begins_with("walk"):
    m.phase=float(key.trim_prefix("walk"))*TAU/32.0;m.swing=1.0
   if key.begins_with("seat"):
    m.follow(0,Deck.SEAT_Z,0,true,float(key.trim_prefix("seat"))/4.0-1.0,0.1)
   if key.begins_with("post"):
    m.hold(Vector3(-0.2,1.2,-0.45),Vector3(0.2,1.2,-0.45));m.smooth_lean=true;m.lean=deg_to_rad(float(key.trim_prefix("post")))
   var g=CrewRig.pose(rest,m.joints(),CrewRig.SEAT_BEND if m.seated else 0.0)
   var bones={}
   for i in g.size():
    var d:Transform3D=g[i]*rest.global[i].affine_inverse()
    bones[names[i]]=[[d.basis.x.x,d.basis.y.x,d.basis.z.x,d.origin.x],[d.basis.x.y,d.basis.y.y,d.basis.z.y,d.origin.y],[d.basis.x.z,d.basis.y.z,d.basis.z.z,d.origin.z],[0,0,0,1]]
   poses[key]=bones
  result[sex]=poses
  scene.free()
 FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(result))
 print("EXPORTED GAME POSES")
 quit()
