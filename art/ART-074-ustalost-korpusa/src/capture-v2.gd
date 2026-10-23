extends SceneTree
func _initialize():
 SaveGame.default_path=""
 Main.intro=false
 Main.menu=false
 _go.call_deferred()
func _go():
 var args=OS.get_cmdline_user_args()
 var kv={}
 for a in args.slice(1):
  var p=a.split("=",true,1)
  kv[p[0]]=p[1]
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 await process_frame
 while main.warming(): await process_frame
 await main.debug_setup(kv)
 for key in ["x","z"]:
  if kv.has(key): main.walker.set(key,float(kv[key]))
 for key in ["yaw","pitch"]:
  if kv.has(key): main.walker.set(key,deg_to_rad(float(kv[key])))
 main.step(0.000001)
 main.set_process(false)
 # Warmup may leave fading legacy valve puffs alive after emitting=false.
 # This artistic shot demonstrates ART-074, not an active valve discharge.
 main.rooms.steam.visible=false
 main.rooms.steam.emitting=false
 var mats=[]
 var originals=[]
 for view in [main.bridge,main.rooms]:
  var mesh=view.mesh_instance.mesh
  for i in mesh.get_surface_count():
   var m=mesh.surface_get_material(i)
   if m is ShaderMaterial and m.shader.resource_path.ends_with("ship_surface.gdshader"):
    originals.append(m.shader)
    mats.append(m)
 var preview=load("res://art/ART-074-ustalost-korpusa/src/preview.gd").new()
 preview.hull=float(kv.get("hull","15"))
 preview.eco=kv.get("eco","0")=="1"
 main.ship.add_child(preview)
 preview.sample(float(kv.get("phase","2.3")))
 preview.visible=false
 for j in 14: await process_frame
 await RenderingServer.frame_post_draw
 var before=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
 root.get_texture().get_image().save_png(args[0].replace(".png","-control.png"))
 for m in mats:
  var col=m.get_shader_parameter("base_color")
  m.shader=load("res://art/ART-074-ustalost-korpusa/src/surface.gdshader")
  m.set_shader_parameter("wear_mask",texture_file("res://art/ART-074-ustalost-korpusa/ustalost-maska.png"))
  m.set_shader_parameter("wear_loss",1.0-preview.hull/100.0)
  m.set_shader_parameter("wear_floor",col is Color and col.b>col.r)
 preview.visible=preview.hull<62.0
 for j in 14: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(args[0])
 var after=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
 preview.visible=false
 for j in 14: await process_frame
 await RenderingServer.frame_post_draw
 var data={"baseline":before,"after":after,"surface_only":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"cards":preview.count,"hull":preview.hull,"surface_materials":mats.size(),"legacy_valve_hidden":not main.rooms.steam.visible,"steam_emission":0.0}
 FileAccess.open(args[0].replace(".png","-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
 print(data)
 quit()


func texture_file(path:String):
 var im=Image.load_from_file(path)
 im.generate_mipmaps()
 return ImageTexture.create_from_image(im)
