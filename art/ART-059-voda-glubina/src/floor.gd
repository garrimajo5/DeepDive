extends SceneTree
func _initialize():
 for x in [0,80,120,160,200,220,240,260]:
  print(x," floor ",Seabed.height(x,0))
 quit()
