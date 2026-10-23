extends SceneTree
func _initialize()->void:
 go.call_deferred()
func go()->void:
 var p = load("res://art/ART-072-proboina-chastitsy/src/preview.gd").new()
 p.welding=true;p.water_h=0.1
 root.add_child(p)
 var below:=0
 var min_splash:=100.0
 for k in 121:
  p.sample(k/60.0)
  await process_frame
  await process_frame
  for i in p.counts[1]:
   var tr: Transform3D=p.groups[1].multimesh.get_instance_transform(i)
   var foot: float=tr.origin.y-tr.basis.y.length()*0.5
   min_splash=minf(min_splash,foot)
   if foot<p.water_h-p.hole_y-0.0001: below+=1
 print("MOTION ",JSON.stringify({"samples":121,"below_water_splash":below,"min_splash_local":min_splash,"jet_life":p.jet_life,"hit_z":p.hit_z,"total":p.counts[0]+p.counts[1]+p.counts[2]}))
 quit(0)
