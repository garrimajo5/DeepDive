extends SceneTree
# Run after initial GLB import, then repeat --editor --import.
func _initialize():
 for path in OS.get_cmdline_user_args():
  var cfg=ConfigFile.new()
  var result=cfg.load(path+".import")
  if result!=OK:
   push_error("Import first: "+path)
   quit(1)
   return
  var animations={}
  for name in ["Idle","Walk","SitIdle","PostIdle"]:
   animations[name]={"settings/loop_mode":1}
  cfg.set_value("params","_subresources",{"animations":animations})
  cfg.set_value("params","animation/fps",30)
  cfg.save(path+".import")
 quit()
