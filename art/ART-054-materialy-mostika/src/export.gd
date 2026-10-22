extends SceneTree
func _initialize():
 var data=[]
 for p in BridgePlan.parts():
  var t=p.xform()
  data.append({"name":p.name,"paint":p.paint,"size":[p.size.x,p.size.y,p.size.z],"center":[p.center.x,p.center.y,p.center.z],"rx":p.rx})
 var out=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
 out.store_string(JSON.stringify(data))
 quit()
