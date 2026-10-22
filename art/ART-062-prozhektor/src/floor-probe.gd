extends SceneTree
func _initialize():
 for depth in [45,90]:
  for x in range(150,261,10):
   var pos=Vector3(x,-depth,0)+Searchlight.LAMP
   print(depth," x ",x," floor ",Seabed.height(x,0)," hit0 ",Searchlight.floor_hit(pos,0,14,120)," hit90 ",Searchlight.floor_hit(pos,PI/2,14,120))
 quit()
