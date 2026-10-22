extends SceneTree
## Скриншот главной сцены без телефона.
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x720 -s tools/shot.gd -- out.png [ключ=значение ...]
## Ключи: x, z, yaw, pitch — игрок на палубе (yaw в градусах, 0 — к носу); noclip=1 y=<м> — тестовый полёт (глаз в x,y,z, сквозь корпус — смотреть живой мир); frames — сколько кадров ждать;
## pilot=1 — сесть за штурвал; thrust, turn, vert — ввод пилота; secs — сколько секунд вести корабль до снимка;
## light=0 — погасить прожектор; lock=1 — шлюз трюма открыт; zap=1 — разряд (рычаг внизу, шкала погашена); ping=1 — импульс сонара с пробными отметками (age=<с> после импульса); power=1 — встать к пульту энергии; hot=<градусы> — перегрев реактора; energy=<ед.> — заряд корабля; hull=<%> — прочность корпуса (следы ART-049 снаружи); relief=0 — обшивка, мостик и лёд без рельефа ART-053/054/056, взвесь ART-058 «Экономно»; drain=1 — стеклоуст на корпусе; ship=x,y,z — поставить корабль (например ship=200,-80,0 — глубокий склон на востоке); view=x,y,z — камера снаружи в осях корабля (корпус). mate=x,z,курс[,роль[,внешность 0…1]] — ещё один член экипажа на палубе, несколько — через «;» (mate=helm — за штурвалом, mate=energy — инженер у пульта: метка «Занято» ART-033 вблизи), tag=a;l;- — состояния их табличек ART-033 (a — нажимает, l — нет связи), gone=1 — последний из них отключился (плашка хоста ART-043); cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории). save=<путь> — груз и поднятые образцы из файла сохранения. silt=1 — корабль в облаке ила (сонарная тьма). breach=n — пробоина в месте n (0 мостик … 3 машинное), weld=<доля>, water=<м>. observe=fish:flee,pred:ping — наблюдения в журнале, scanned=fish — изученные виды, journal=n — страница журнала (0 — сводка). route=n — маршрут забега n (0…2) выбран у голостола; vote=1 — маршрут пройден, решение «глубже или наверх», vote=coop — двое у стола (с mate=…), свой голос «глубже», ждём товарища; vote=up — итог забега (с мостика: итог на голограмме; с flyby=surface — вид с борта). flyby=start|surface — камера с борта (облёт в начале забега, вид при всплытии), age=<с> от начала облёта. splash=<доля> — заставка прогрева (ART-034), hint=<с> — подсказка на это время. use=<пост> — нажать кнопку действия у поста (scram, zap, sonar…; без x/z — игрок шагает к посту сам), снимок 0,3 с спустя — frames=1.


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
	main.helm.yaw=PI/2
	main._place_ship()
	for i in int(kv.get("frames", "8")):
		await process_frame

	main.process_mode=Node.PROCESS_MODE_DISABLED
	if kv.has("freecam"):
		main.camera.position=Vector3(float(kv.get("x","0")),1.65,float(kv.get("z","20.1")))
		main.camera.rotation=Vector3(deg_to_rad(float(kv.get("pitch","0"))),deg_to_rad(float(kv.get("yaw","180"))),0)
		for index in main.crew_view.members.size():
			if main.crew_view.members[index]==main.me:main.crew_view.figures[index].visible=false
		print("CAMERA ",main.camera.position,main.camera.rotation)
	var valve_nodes=main.rooms.valve_wheel.find_children("*","MeshInstance3D",true,false)
	if main.rooms.valve_wheel is MeshInstance3D:valve_nodes.append(main.rooms.valve_wheel)
	for mesh in valve_nodes:
		for surf in mesh.mesh.get_surface_count():
			var vm=mesh.get_active_material(surf).duplicate()
			if vm is BaseMaterial3D:
				vm.albedo_texture=null
				vm.albedo_color=Color("8C806B")
				mesh.set_surface_override_material(surf,vm)
	# Accepted ART-059 context, identical for all before/after frames.
	main.env.fog_light_color=Color("0D2943")
	main.env.background_color=Color("0D2943")
	main.env.fog_density=.018
	main.env.ambient_light_energy=.16
	main.env.tonemap_exposure=.94
	main.ocean.sun.light_energy=.085
	var counts_before=main.find_children("*","Light3D",true,false).size()
	await _save(out.replace(".png","-base.png"))
	print("BASE draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," light_nodes ",counts_before)
	var face=ImageTexture.create_from_image(Image.load_from_file("res://art/ART-064-svet-vnutri/plafon.png"))
	var mats=[]
	for hull in [main.bridge.mesh_instance,main.rooms.mesh_instance]:
		var m=ShaderMaterial.new()
		m.shader=load("res://art/ART-064-svet-vnutri/src/plafon-preview.gdshader")
		m.set_shader_parameter("bridge",hull==main.bridge.mesh_instance)
		m.set_shader_parameter("diffuser",face)
		m.set_shader_parameter("lamp_k",main.vitals.lamp_k(main.time,main.zap.flicker>0.0))
		for idx in hull.mesh.get_surface_count():
			var old=hull.get_active_material(idx)
			if old is BaseMaterial3D and old.emission_enabled:
				hull.set_surface_override_material(idx,m)
		mats.append(m)
	_lights(main,false,1.0,kv.get("fault","мостик"))
	await _save(out.replace(".png","-normal.png"))
	print("NORMAL draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var bindex=3 if kv.get("fault","")=="машинное" else 0
	main.breach.start(main.breach.all[bindex])
	main.breach.time=.25
	main.breach_view.apply()
	main.alarm_board.show_alarms(main.alarms_on(),main.time,main.breach.active)
	await _save(out.replace(".png","-event-base.png"))
	print("EVENT baseline draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	# Existing event alarm is replaced by the existing room lamp, no doubled amber light.
	main.breach_view.alarm.light_energy=0.0
	for m in mats:
		m.set_shader_parameter("alarm",true)
		m.set_shader_parameter("pulse",1.0)
	_lights(main,true,1.0,kv.get("fault","мостик"))
	await _save(out.replace(".png","-alarm.png"))
	print("ALARM draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," light_nodes ",main.find_children("*","Light3D",true,false).size())
	for m in mats:m.set_shader_parameter("pulse",0.0)
	_lights(main,true,0.0,kv.get("fault","мостик"))
	await _save(out.replace(".png","-dim.png"))
	quit(0)

func _save(path:String)->void:
	for n in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _lights(main,alarm:bool,pulse:float,fault:String)->void:
	var config=JSON.parse_string(FileAccess.get_file_as_string("res://art/ART-064-svet-vnutri/sources.json"))
	var lights=[]
	lights.append_array(main.bridge.lamps)
	lights.append_array(main.rooms.lamps)
	lights.append(main.rooms.reactor_light)
	for index in lights.size():
		var l:OmniLight3D=lights[index]
		var c:Dictionary=config[index]
		l.global_position=main.ship.to_global(Vector3(c.pos[0],c.pos[1],c.pos[2]))
		l.light_color=Color(c.color)
		var k=1.0
		if alarm and c.kind=="safe":
			k=.48
			l.light_color=Color("A9DDE7")
		elif alarm and c.kind=="alarm":
			k=(.35+.65*pulse) if c.room==fault else (.40+.20*pulse)
			l.light_color=Color("FFB259")
		l.light_energy=c.energy*k*main.vitals.lamp_k(main.time,main.zap.flicker>0.0)
		if c.kind=="reactor":l.light_energy=0.0 if main.reactor.scram>0.0 else c.energy
		l.omni_range=c.range
		l.omni_attenuation=c.attenuation
		l.light_cull_mask=OceanView.LAYER_SHIP
		l.shadow_enabled=false
	main.rooms._rod_mat.emission_energy_multiplier=0.0 if main.reactor.scram>0.0 else .45
	for m in main.rooms._ring_mats:m.emission_energy_multiplier=(.28 if alarm else .7)*main.vitals.lamp_k(main.time,main.zap.flicker>0.0)
