extends SceneTree
## РЎРєСЂРёРЅС€РѕС‚ РіР»Р°РІРЅРѕР№ СЃС†РµРЅС‹ Р±РµР· С‚РµР»РµС„РѕРЅР°.
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x720 -s tools/shot.gd -- out.png [РєР»СЋС‡=Р·РЅР°С‡РµРЅРёРµ ...]
## РљР»СЋС‡Рё: x, z, yaw, pitch вЂ” РёРіСЂРѕРє РЅР° РїР°Р»СѓР±Рµ (yaw РІ РіСЂР°РґСѓСЃР°С…, 0 вЂ” Рє РЅРѕСЃСѓ); noclip=1 y=<Рј> вЂ” С‚РµСЃС‚РѕРІС‹Р№ РїРѕР»С‘С‚ (РіР»Р°Р· РІ x,y,z, СЃРєРІРѕР·СЊ РєРѕСЂРїСѓСЃ вЂ” СЃРјРѕС‚СЂРµС‚СЊ Р¶РёРІРѕР№ РјРёСЂ); frames вЂ” СЃРєРѕР»СЊРєРѕ РєР°РґСЂРѕРІ Р¶РґР°С‚СЊ;
## pilot=1 вЂ” СЃРµСЃС‚СЊ Р·Р° С€С‚СѓСЂРІР°Р»; thrust, turn, vert вЂ” РІРІРѕРґ РїРёР»РѕС‚Р°; secs вЂ” СЃРєРѕР»СЊРєРѕ СЃРµРєСѓРЅРґ РІРµСЃС‚Рё РєРѕСЂР°Р±Р»СЊ РґРѕ СЃРЅРёРјРєР°;
## light=0 вЂ” РїРѕРіР°СЃРёС‚СЊ РїСЂРѕР¶РµРєС‚РѕСЂ; lock=1 вЂ” С€Р»СЋР· С‚СЂСЋРјР° РѕС‚РєСЂС‹С‚; zap=1 вЂ” СЂР°Р·СЂСЏРґ (СЂС‹С‡Р°Рі РІРЅРёР·Сѓ, С€РєР°Р»Р° РїРѕРіР°С€РµРЅР°); ping=1 вЂ” РёРјРїСѓР»СЊСЃ СЃРѕРЅР°СЂР° СЃ РїСЂРѕР±РЅС‹РјРё РѕС‚РјРµС‚РєР°РјРё (age=<СЃ> РїРѕСЃР»Рµ РёРјРїСѓР»СЊСЃР°); power=1 вЂ” РІСЃС‚Р°С‚СЊ Рє РїСѓР»СЊС‚Сѓ СЌРЅРµСЂРіРёРё; hot=<РіСЂР°РґСѓСЃС‹> вЂ” РїРµСЂРµРіСЂРµРІ СЂРµР°РєС‚РѕСЂР°; energy=<РµРґ.> вЂ” Р·Р°СЂСЏРґ РєРѕСЂР°Р±Р»СЏ; hull=<%> вЂ” РїСЂРѕС‡РЅРѕСЃС‚СЊ РєРѕСЂРїСѓСЃР° (СЃР»РµРґС‹ ART-049 СЃРЅР°СЂСѓР¶Рё); relief=0 вЂ” РѕР±С€РёРІРєР°, РјРѕСЃС‚РёРє Рё Р»С‘Рґ Р±РµР· СЂРµР»СЊРµС„Р° ART-053/054/056, РІР·РІРµСЃСЊ ART-058 В«Р­РєРѕРЅРѕРјРЅРѕВ»; drain=1 вЂ” СЃС‚РµРєР»РѕСѓСЃС‚ РЅР° РєРѕСЂРїСѓСЃРµ; ship=x,y,z вЂ” РїРѕСЃС‚Р°РІРёС‚СЊ РєРѕСЂР°Р±Р»СЊ (РЅР°РїСЂРёРјРµСЂ ship=200,-80,0 вЂ” РіР»СѓР±РѕРєРёР№ СЃРєР»РѕРЅ РЅР° РІРѕСЃС‚РѕРєРµ); view=x,y,z вЂ” РєР°РјРµСЂР° СЃРЅР°СЂСѓР¶Рё РІ РѕСЃСЏС… РєРѕСЂР°Р±Р»СЏ (РєРѕСЂРїСѓСЃ). mate=x,z,РєСѓСЂСЃ[,СЂРѕР»СЊ[,РІРЅРµС€РЅРѕСЃС‚СЊ 0вЂ¦1]] вЂ” РµС‰С‘ РѕРґРёРЅ С‡Р»РµРЅ СЌРєРёРїР°Р¶Р° РЅР° РїР°Р»СѓР±Рµ, РЅРµСЃРєРѕР»СЊРєРѕ вЂ” С‡РµСЂРµР· В«;В» (mate=helm вЂ” Р·Р° С€С‚СѓСЂРІР°Р»РѕРј, mate=energy вЂ” РёРЅР¶РµРЅРµСЂ Сѓ РїСѓР»СЊС‚Р°: РјРµС‚РєР° В«Р—Р°РЅСЏС‚РѕВ» ART-033 РІР±Р»РёР·Рё), tag=a;l;- вЂ” СЃРѕСЃС‚РѕСЏРЅРёСЏ РёС… С‚Р°Р±Р»РёС‡РµРє ART-033 (a вЂ” РЅР°Р¶РёРјР°РµС‚, l вЂ” РЅРµС‚ СЃРІСЏР·Рё), gone=1 вЂ” РїРѕСЃР»РµРґРЅРёР№ РёР· РЅРёС… РѕС‚РєР»СЋС‡РёР»СЃСЏ (РїР»Р°С€РєР° С…РѕСЃС‚Р° ART-043); cargo=0,2,1 вЂ” РІРёРґС‹ РѕР±СЂР°Р·С†РѕРІ РІ С‚СЂСЋРјРµ (Рё РІ РєРѕР»Р±Р°С… Р»Р°Р±РѕСЂР°С‚РѕСЂРёРё). save=<РїСѓС‚СЊ> вЂ” РіСЂСѓР· Рё РїРѕРґРЅСЏС‚С‹Рµ РѕР±СЂР°Р·С†С‹ РёР· С„Р°Р№Р»Р° СЃРѕС…СЂР°РЅРµРЅРёСЏ. silt=1 вЂ” РєРѕСЂР°Р±Р»СЊ РІ РѕР±Р»Р°РєРµ РёР»Р° (СЃРѕРЅР°СЂРЅР°СЏ С‚СЊРјР°). breach=n вЂ” РїСЂРѕР±РѕРёРЅР° РІ РјРµСЃС‚Рµ n (0 РјРѕСЃС‚РёРє вЂ¦ 3 РјР°С€РёРЅРЅРѕРµ), weld=<РґРѕР»СЏ>, water=<Рј>. observe=fish:flee,pred:ping вЂ” РЅР°Р±Р»СЋРґРµРЅРёСЏ РІ Р¶СѓСЂРЅР°Р»Рµ, scanned=fish вЂ” РёР·СѓС‡РµРЅРЅС‹Рµ РІРёРґС‹, journal=n вЂ” СЃС‚СЂР°РЅРёС†Р° Р¶СѓСЂРЅР°Р»Р° (0 вЂ” СЃРІРѕРґРєР°). route=n вЂ” РјР°СЂС€СЂСѓС‚ Р·Р°Р±РµРіР° n (0вЂ¦2) РІС‹Р±СЂР°РЅ Сѓ РіРѕР»РѕСЃС‚РѕР»Р°; vote=1 вЂ” РјР°СЂС€СЂСѓС‚ РїСЂРѕР№РґРµРЅ, СЂРµС€РµРЅРёРµ В«РіР»СѓР±Р¶Рµ РёР»Рё РЅР°РІРµСЂС…В», vote=coop вЂ” РґРІРѕРµ Сѓ СЃС‚РѕР»Р° (СЃ mate=вЂ¦), СЃРІРѕР№ РіРѕР»РѕСЃ В«РіР»СѓР±Р¶РµВ», Р¶РґС‘Рј С‚РѕРІР°СЂРёС‰Р°; vote=up вЂ” РёС‚РѕРі Р·Р°Р±РµРіР° (СЃ РјРѕСЃС‚РёРєР°: РёС‚РѕРі РЅР° РіРѕР»РѕРіСЂР°РјРјРµ; СЃ flyby=surface вЂ” РІРёРґ СЃ Р±РѕСЂС‚Р°). flyby=start|surface вЂ” РєР°РјРµСЂР° СЃ Р±РѕСЂС‚Р° (РѕР±Р»С‘С‚ РІ РЅР°С‡Р°Р»Рµ Р·Р°Р±РµРіР°, РІРёРґ РїСЂРё РІСЃРїР»С‹С‚РёРё), age=<СЃ> РѕС‚ РЅР°С‡Р°Р»Р° РѕР±Р»С‘С‚Р°. vent=<СЃ> вЂ” РІС‹РїСѓСЃРєРё РїСѓР·С‹СЂРµР№ Сѓ СЃРµСЂРІРёСЃРЅС‹С… РєСЂС‹С€РµРє ART-063 С‡РµСЂРµР· СЃС‚РѕР»СЊРєРѕ СЃРµРєСѓРЅРґ РїРѕСЃР»Рµ РїСЂРѕРґСѓРІРєРё (СЃР»РµРґ РІРёРЅС‚РѕРІ вЂ” РїРѕ thrust Рё secs). grade=0 вЂ” Р±РµР· РІРёРЅСЊРµС‚РєРё Рё С†РІРµС‚РѕРєРѕСЂСЂРµРєС†РёРё ART-065 (relief=0 вЂ” С‚РѕР»СЊРєРѕ РѕРІР°Р» В«Р­РєРѕРЅРѕРјРЅРѕВ»). wreck=<СЃ> вЂ” С€С‚РѕСЂРєР° В«РљРѕСЂРїСѓСЃ СЂР°Р·СЂСѓС€РµРЅВ» (ART-036) РЅР° СЌС‚РѕРј РІСЂРµРјРµРЅРё. splash=<РґРѕР»СЏ> вЂ” Р·Р°СЃС‚Р°РІРєР° РїСЂРѕРіСЂРµРІР° (ART-034), hint=<СЃ> вЂ” РїРѕРґСЃРєР°Р·РєР° РЅР° СЌС‚Рѕ РІСЂРµРјСЏ. menu=1 вЂ” РіР»Р°РІРЅРѕРµ РјРµРЅСЋ ART-037 (РєР°Рє РїСЂРё Р·Р°РїСѓСЃРєРµ). pause=1|new|exit вЂ” РїР°СѓР·Р° ART-037 (new / exit вЂ” СЃ РїРѕРґС‚РІРµСЂР¶РґРµРЅРёРµРј). use=<РїРѕСЃС‚> вЂ” РЅР°Р¶Р°С‚СЊ РєРЅРѕРїРєСѓ РґРµР№СЃС‚РІРёСЏ Сѓ РїРѕСЃС‚Р° (scram, zap, sonarвЂ¦; Р±РµР· x/z вЂ” РёРіСЂРѕРє С€Р°РіР°РµС‚ Рє РїРѕСЃС‚Сѓ СЃР°Рј), СЃРЅРёРјРѕРє 0,3 СЃ СЃРїСѓСЃС‚СЏ вЂ” frames=1.


func _initialize() -> void:
	SaveGame.default_path = ""   # РЅРµ С‡РёС‚Р°С‚СЊ Рё РЅРµ РїРёСЃР°С‚СЊ СЃРѕС…СЂР°РЅРµРЅРёРµ РёРіСЂРѕРєР°
	Main.intro = false   # СЃРЅРёРјРѕРє СЃ РјРѕСЃС‚РёРєР°; flyby=start|surface вЂ” РІРёРґ СЃ Р±РѕСЂС‚Р°
	Main.menu = "menu=1" in OS.get_cmdline_user_args()   # menu=1 вЂ” РіР»Р°РІРЅРѕРµ РјРµРЅСЋ ART-037 РїРѕРІРµСЂС… СЃС†РµРЅС‹
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "shot.png"
	var kv := {}
	for a in args:
		if a.contains("="):
			var p := a.split("=", true, 1)
			kv[p[0]] = p[1]
		else:
			out = a
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	while main.has_method("warming") and main.warming():   # РїСЂРѕРіСЂРµРІ С€РµР№РґРµСЂРѕРІ РїРѕРґ С€С‚РѕСЂРєРѕР№ (Warmup)
		await process_frame
	if kv.has("save"):  # save=<РїСѓС‚СЊ> вЂ” РіСЂСѓР· Рё РїРѕРґРЅСЏС‚С‹Рµ РѕР±СЂР°Р·С†С‹ РёР· С„Р°Р№Р»Р° СЃРѕС…СЂР°РЅРµРЅРёСЏ (РєР°Рє РїСЂРё Р·Р°РїСѓСЃРєРµ РёРіСЂС‹)
		var sg := SaveGame.new()
		sg.path = kv["save"]
		print("СЃРѕС…СЂР°РЅРµРЅРёРµ: ", sg.load_into(main.samples))
	if main.has_method("debug_setup"):
		await main.debug_setup(kv)
	var w = main.get("walker")
	if w:
		if kv.has("x"): w.x = float(kv["x"])
		if kv.has("z"): w.z = float(kv["z"])
		if kv.has("yaw"): w.yaw = deg_to_rad(float(kv["yaw"]))
		if kv.has("pitch"): w.pitch = deg_to_rad(float(kv["pitch"]))
		if kv.has("noclip"): w.noclip = kv["noclip"] != "0"   # С‚РµСЃС‚РѕРІС‹Р№ РїРѕР»С‘С‚: РіР»Р°Р· РІ (x, y, z), СЃРєРІРѕР·СЊ РєРѕСЂРїСѓСЃ
		if kv.has("y"): w.y = float(kv["y"])
	if kv.has("splash"):   # splash=<РґРѕР»СЏ 0вЂ¦1> вЂ” Р·Р°СЃС‚Р°РІРєР° РїСЂРѕРіСЂРµРІР° ART-034 РїРѕРІРµСЂС… СЃС†РµРЅС‹, hint=<СЃ> вЂ” РІСЂРµРјСЏ РїРѕРґСЃРєР°Р·РєРё
		var sp := WarmSplash.new()
		root.add_child(sp)
		sp.set_progress(float(kv["splash"]))
		sp._process(float(kv.get("hint", "0")))
	if kv.has("wreck"):   # wreck=<СЃ> вЂ” С€С‚РѕСЂРєР° В«РљРѕСЂРїСѓСЃ СЂР°Р·СЂСѓС€РµРЅВ» ART-036 С‡РµСЂРµР· СЃС‚РѕР»СЊРєРѕ СЃРµРєСѓРЅРґ РїРѕСЃР»Рµ СЂР°Р·СЂСѓС€РµРЅРёСЏ
		main.vitals.hull = 0.0
		main.vitals.destroyed.emit()
		while main.wreck.active() and main.wreck.t < float(kv["wreck"]):
			main.step(1.0 / 30.0)
		main.set_process(false)   # РєР°РґСЂ вЂ” СЂРѕРІРЅРѕ РЅР° СЌС‚РѕРј РІСЂРµРјРµРЅРё С€С‚РѕСЂРєРё
	if kv.has("pause"):   # pause=1|new|exit вЂ” РїР°СѓР·Р° ART-037 РїРѕ В«РќР°Р·Р°РґВ», new / exit вЂ” РѕС‚РєСЂС‹С‚Рѕ РїРѕРґС‚РІРµСЂР¶РґРµРЅРёРµ
		main.back_pressed()
		if kv["pause"] in ["new", "exit"]:
			main.pause.press(kv["pause"])
			main.pause_panel.show_pause(main.pause)
	if kv.has("drop"):   # drop=wait|retry|no|refused|solo|back вЂ” РґРёР°Р»РѕРі В«РЎРІСЏР·СЊ СЃ С…РѕСЃС‚РѕРј РїРѕС‚РµСЂСЏРЅР°В» (ART-043), t=<СЃ> РІ РѕРєРЅРµ
		var d := NetDrop.new()
		d.open()
		match kv["drop"]:
			"retry":
				d.update(NetDrop.WINDOW)
				d.press("wait")
			"no":
				d.update(NetDrop.WINDOW)
			"refused":
				d.refused("full")
			"solo":
				d.press("solo")
			"back":
				d.restored()
		d.update(float(kv.get("t", "3.2")))
		var dp := DropPanel.new()
		root.add_child(dp)
		dp.show_drop(d)
	if kv.has("weak"):   # weak=1 вЂ” РїР»Р°С€РєР° В«РЎР»Р°Р±Р°СЏ СЃРІСЏР·СЊВ» Сѓ РіРѕСЃС‚СЏ (ART-043)
		var wl := WeakLink.new()
		wl.update(1.0, NetLink.WEAK_AFTER + 0.1)
		var wp := DropPanel.new()
		root.add_child(wp)
		wp.show_weak(wl)
	for i in int(kv.get("frames", "8")):
		await process_frame
	await RenderingServer.frame_post_draw
	paused=true
	var tex:=ImageTexture.create_from_image(Image.load_from_file("res://art/ART-068-razryad-korpus/razryad-dugi.png"))
	var mats: Array=[]
	for node in main.find_children("*","MeshInstance3D",true,false):
		var mesh: Mesh=node.mesh
		if not mesh:continue
		for i in mesh.get_surface_count():
			var m: Material=mesh.surface_get_material(i)
			if m is ShaderMaterial and m.shader and m.shader.resource_path=="res://shaders/hull_plating.gdshader" and not m in mats:mats.append(m)
	for m in mats:
		m.shader=load("res://art/ART-068-razryad-korpus/src/hull-preview.gdshader")
		m.set_shader_parameter("arcs",tex)
		m.set_shader_parameter("age",float(kv.get("agezap","0.3")))
	var age: float=float(kv.get("agezap","0.3"))
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_strip(st,Vector3(-3.8,0.94,-6.15),Vector3(3.8,0.94,-6.15),Vector3(0,0.32,0),0.0)
	var ground_world: Vector3=main.ship.to_global(Vector3(0,-1.6,10))
	ground_world.y=Seabed.height(ground_world.x,ground_world.z)+0.08
	var gp: Vector3=main.ship.to_local(ground_world)
	if kv.has("ground"):
		add_strip(st,Vector3(0,-1.6,10),gp,Vector3(0.35,0,0),1.0)
		main.ocean.seabed_mat.shader=load("res://art/ART-068-razryad-korpus/src/ground-preview.gdshader")
		main.ocean.seabed_mat.set_shader_parameter("event_burn",load("res://textures/dno/dekali.png"))
		main.ocean.seabed_mat.set_shader_parameter("event_point",Vector2(ground_world.x,ground_world.z))
	var mesh_node:=MeshInstance3D.new()
	mesh_node.mesh=st.commit()
	var sm:=ShaderMaterial.new()
	sm.shader=load("res://art/ART-068-razryad-korpus/src/strip.gdshader")
	sm.set_shader_parameter("arcs",tex)
	sm.set_shader_parameter("age",age)
	mesh_node.material_override=sm
	main.ship.add_child(mesh_node)
	main.zap_light.light_energy*=maxf(0.0,1.0-float(kv.get("agezap","0.3"))/0.8)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT ", out, " ", img.get_size(), " РІС‹Р·РѕРІРѕРІ РѕС‚СЂРёСЃРѕРІРєРё: ",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		", РїСЂРёРјРёС‚РёРІРѕРІ: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	quit(0)

func add_strip(st: SurfaceTool,a: Vector3,b: Vector3,w: Vector3,kind: float) -> void:
	var points: Array=[a-w,b-w,b+w,a+w]
	var uv: Array=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for i in [0,1,2,0,2,3]:
		st.set_color(Color(kind,0,0,1))
		st.set_uv(uv[i])
		st.add_vertex(points[i])