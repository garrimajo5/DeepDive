extends SceneTree
## Скриншот главной сцены без телефона.
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x720 -s tools/shot.gd -- out.png [ключ=значение ...]
## Ключи: x, z, yaw, pitch — игрок на палубе (yaw в градусах, 0 — к носу); noclip=1 y=<м> — тестовый полёт (глаз в x,y,z, сквозь корпус — смотреть живой мир); frames — сколько кадров ждать;
## pilot=1 — сесть за штурвал; thrust, turn, vert — ввод пилота; secs — сколько секунд вести корабль до снимка;
## light=0 — погасить прожектор; lock=1 — шлюз трюма открыт; zap=1 — разряд (рычаг внизу, шкала погашена); ping=1 — импульс сонара с пробными отметками (age=<с> после импульса); power=1 — встать к пульту энергии; hot=<градусы> — перегрев реактора; energy=<ед.> — заряд корабля; hull=<%> — прочность корпуса (следы ART-049 снаружи); relief=0 — обшивка и мостик без рельефа ART-053/054; drain=1 — стеклоуст на корпусе; ship=x,y,z — поставить корабль (например ship=200,-80,0 — глубокий склон на востоке); view=x,y,z — камера снаружи в осях корабля (корпус). mate=x,z,курс[,роль[,внешность 0…1]] — ещё один член экипажа на палубе, несколько — через «;» (mate=helm — за штурвалом, mate=energy — инженер у пульта: метка «Занято» ART-033 вблизи), tag=a;l;- — состояния их табличек ART-033 (a — нажимает, l — нет связи), gone=1 — последний из них отключился (плашка хоста ART-043); cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории). save=<путь> — груз и поднятые образцы из файла сохранения. silt=1 — корабль в облаке ила (сонарная тьма). breach=n — пробоина в месте n (0 мостик … 3 машинное), weld=<доля>, water=<м>. observe=fish:flee,pred:ping — наблюдения в журнале, scanned=fish — изученные виды, journal=n — страница журнала (0 — сводка). route=n — маршрут забега n (0…2) выбран у голостола; vote=1 — маршрут пройден, решение «глубже или наверх», vote=coop — двое у стола (с mate=…), свой голос «глубже», ждём товарища; vote=up — итог забега (с мостика: итог на голограмме; с flyby=surface — вид с борта). flyby=start|surface — камера с борта (облёт в начале забега, вид при всплытии), age=<с> от начала облёта. splash=<доля> — заставка прогрева (ART-034), hint=<с> — подсказка на это время. use=<пост> — нажать кнопку действия у поста (scram, zap, sonar…; без x/z — игрок шагает к посту сам), снимок 0,3 с спустя — frames=1.


var projector_texture:ImageTexture
func _initialize() -> void:
	var im=Image.load_from_file("res://art/ART-062-prozhektor/prozhektor-maska.png")
	im.convert(Image.FORMAT_RGBA8)
	projector_texture=ImageTexture.create_from_image(im)
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
	main.helm.yaw=deg_to_rad(float(kv.get("heading","90")))
	main._place_ship()
	for i in int(kv.get("frames", "8")):
		await process_frame

	main.process_mode=Node.PROCESS_MODE_DISABLED
	var density=0.018 if main.helm.depth()<60 else 0.022
	var fog=Color("0D2943") if main.helm.depth()<60 else Color("05131F")
	main.env.fog_light_color=fog.lerp(Silt.FAR_COLOR,0.75*main.silt.k)
	main.env.background_color=main.env.fog_light_color
	main.env.fog_density=density+0.03*main.silt.k
	main.env.ambient_light_energy=0.16 if main.helm.depth()<60 else 0.045
	main.env.tonemap_exposure=0.94 if main.helm.depth()<60 else 0.98
	main.ocean.sun.light_energy=0.085 if main.helm.depth()<60 else 0.012
	var glass=main.bridge.get_node("Стекло окна")
	var gm=glass.material_override.duplicate()
	var gc=gm.albedo_color
	var ambient=0.16 if main.helm.depth()<60 else 0.045
	gm.albedo_color=Color(gc.r*ambient,gc.g*ambient,gc.b*ambient,gc.a)
	glass.material_override=gm
	var im=main.ocean.ice.material_override.duplicate()
	im.emission_energy_multiplier*=exp(-main.helm.depth()/16.0)
	main.ocean.ice.material_override=im
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.replace(".png","-base.png"))
	print("BASE draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	main.searchlight.spot.shadow_enabled=true
	main.searchlight.spot.shadow_caster_mask=OceanView.LAYER_WORLD
	main.searchlight.spot.light_projector=projector_texture
	var m=ShaderMaterial.new()
	m.shader=load("res://art/ART-062-prozhektor/src/beam-preview.gdshader")
	m.set_shader_parameter("mask_tex",ImageTexture.create_from_image(Image.load_from_file("res://art/ART-062-prozhektor/prozhektor-luch.png")))
	m.set_shader_parameter("fog_density",main.env.fog_density)
	m.set_shader_parameter("silt_k",main.silt.k)
	m.set_shader_parameter("phase",8.0)
	main.searchlight.beam.material_override=m
	for n in 16: await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.replace(".png","-new.png"))
	print("NEW draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," depth ",main.helm.depth()," silt ",main.silt.k)
	main.searchlight.spot.light_energy=Searchlight.DARK
	main.searchlight.beam.visible=false
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.replace(".png","-off.png"))
	quit(0)
