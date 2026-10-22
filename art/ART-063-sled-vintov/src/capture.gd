extends SceneTree
## Скриншот главной сцены без телефона.
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x720 -s tools/shot.gd -- out.png [ключ=значение ...]
## Ключи: x, z, yaw, pitch — игрок на палубе (yaw в градусах, 0 — к носу); noclip=1 y=<м> — тестовый полёт (глаз в x,y,z, сквозь корпус — смотреть живой мир); frames — сколько кадров ждать;
## pilot=1 — сесть за штурвал; thrust, turn, vert — ввод пилота; secs — сколько секунд вести корабль до снимка;
## light=0 — погасить прожектор; lock=1 — шлюз трюма открыт; zap=1 — разряд (рычаг внизу, шкала погашена); ping=1 — импульс сонара с пробными отметками (age=<с> после импульса); power=1 — встать к пульту энергии; hot=<градусы> — перегрев реактора; energy=<ед.> — заряд корабля; hull=<%> — прочность корпуса (следы ART-049 снаружи); relief=0 — обшивка, мостик и лёд без рельефа ART-053/054/056; drain=1 — стеклоуст на корпусе; ship=x,y,z — поставить корабль (например ship=200,-80,0 — глубокий склон на востоке); view=x,y,z — камера снаружи в осях корабля (корпус). mate=x,z,курс[,роль[,внешность 0…1]] — ещё один член экипажа на палубе, несколько — через «;» (mate=helm — за штурвалом, mate=energy — инженер у пульта: метка «Занято» ART-033 вблизи), tag=a;l;- — состояния их табличек ART-033 (a — нажимает, l — нет связи), gone=1 — последний из них отключился (плашка хоста ART-043); cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории). save=<путь> — груз и поднятые образцы из файла сохранения. silt=1 — корабль в облаке ила (сонарная тьма). breach=n — пробоина в месте n (0 мостик … 3 машинное), weld=<доля>, water=<м>. observe=fish:flee,pred:ping — наблюдения в журнале, scanned=fish — изученные виды, journal=n — страница журнала (0 — сводка). route=n — маршрут забега n (0…2) выбран у голостола; vote=1 — маршрут пройден, решение «глубже или наверх», vote=coop — двое у стола (с mate=…), свой голос «глубже», ждём товарища; vote=up — итог забега (с мостика: итог на голограмме; с flyby=surface — вид с борта). flyby=start|surface — камера с борта (облёт в начале забега, вид при всплытии), age=<с> от начала облёта. splash=<доля> — заставка прогрева (ART-034), hint=<с> — подсказка на это время. use=<пост> — нажать кнопку действия у поста (scram, zap, sonar…; без x/z — игрок шагает к посту сам), снимок 0,3 с спустя — frames=1.


func _initialize() -> void:
	SaveGame.default_path = ""   # не читать и не писать сохранение игрока
	Main.intro = false   # снимок с мостика; flyby=start|surface — вид с борта
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
	while main.has_method("warming") and main.warming():   # прогрев шейдеров под шторкой (Warmup)
		await process_frame
	if kv.has("save"):  # save=<путь> — груз и поднятые образцы из файла сохранения (как при запуске игры)
		var sg := SaveGame.new()
		sg.path = kv["save"]
		print("сохранение: ", sg.load_into(main.samples))
	if main.has_method("debug_setup"):
		await main.debug_setup(kv)
	var w = main.get("walker")
	if w:
		if kv.has("x"): w.x = float(kv["x"])
		if kv.has("z"): w.z = float(kv["z"])
		if kv.has("yaw"): w.yaw = deg_to_rad(float(kv["yaw"]))
		if kv.has("pitch"): w.pitch = deg_to_rad(float(kv["pitch"]))
		if kv.has("noclip"): w.noclip = kv["noclip"] != "0"   # тестовый полёт: глаз в (x, y, z), сквозь корпус
		if kv.has("y"): w.y = float(kv["y"])
	if kv.has("splash"):   # splash=<доля 0…1> — заставка прогрева ART-034 поверх сцены, hint=<с> — время подсказки
		var sp := WarmSplash.new()
		root.add_child(sp)
		sp.set_progress(float(kv["splash"]))
		sp._process(float(kv.get("hint", "0")))
	if kv.has("drop"):   # drop=wait|retry|no|refused|solo|back — диалог «Связь с хостом потеряна» (ART-043), t=<с> в окне
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
	for i in int(kv.get("frames", "8")):
		await process_frame

	main.process_mode=Node.PROCESS_MODE_DISABLED
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.replace(".png","-base.png"))
	print("BASE ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var state=kv.get("wake","full")
	var n=160 if state=="full" else (64 if state=="slow" else (144 if state=="surface" else 0))
	var mm=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	mm.use_custom_data=true
	var quad=QuadMesh.new()
	quad.size=Vector2.ONE
	mm.mesh=quad
	mm.instance_count=n
	var cam=root.get_camera_3d()
	var rng=RandomNumberGenerator.new()
	rng.seed=630437
	for index in n:
		var side=-1.0 if index%2==0 else 1.0
		var age=rng.randf_range(0.03,3.8)
		var t=age/3.8
		var id=rng.randi_range(0,11)
		var size=rng.randf_range(0.35,0.68)
		var spread=0.20+age*0.30
		var anchor=Vector3(side*HullPlan.ENGINE_X,HullPlan.ENGINE_Y,HullPlan.ENGINE_Z+HullPlan.SHROUD_L/2.0+0.15)
		var travel=Vector3(rng.randfn()*spread,0.12*age*age+rng.randfn()*spread,age*(3.8 if state=="full" else 1.8))
		if state=="slow":
			travel.x+=age*age*0.32
			if side<0.0: travel.z*=0.55
		if index%11==0:
			id=rng.randi_range(12,15)
			size*=1.8
		if state=="surface" and index>=72:
			anchor=Vector3(-0.9 if side<0 else 0.9,4.79,15.5 if side<0 else 19.0)
			travel=Vector3(rng.randfn()*age*.12,age*.9,rng.randfn()*age*.12)
			id=rng.randi_range(0,7)
			size*=0.8
		var world:Vector3=main.ship.to_global(anchor+travel)
		mm.set_instance_transform(index,Transform3D(cam.global_basis.scaled(Vector3.ONE*size),world))
		mm.set_instance_color(index,Color(1,1,1,smoothstep(0.0,0.12,age)*(1.0-smoothstep(0.65,1.0,t))*0.94))
		mm.set_instance_custom_data(index,Color(float(id),0,0,0))
	var node=MultiMeshInstance3D.new()
	node.multimesh=mm
	node.layers=OceanView.LAYER_WORLD
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=ShaderMaterial.new()
	mat.shader=load("res://art/ART-063-sled-vintov/src/preview.gdshader")
	mat.set_shader_parameter("atlas",ImageTexture.create_from_image(Image.load_from_file("res://art/ART-063-sled-vintov/sled-atlas.png")))
	node.material_override=mat
	main.add_child(node)
	for frame in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.replace(".png","-new.png"))
	print("WAKE ",state," instances ",n," draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit(0)
