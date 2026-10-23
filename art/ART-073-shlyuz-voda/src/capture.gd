extends SceneTree
## Скриншот главной сцены без телефона.
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x720 -s tools/shot.gd -- out.png [ключ=значение ...]
## Ключи: x, z, yaw, pitch — игрок на палубе (yaw в градусах, 0 — к носу); noclip=1 y=<м> — тестовый полёт (глаз в x,y,z, сквозь корпус — смотреть живой мир); frames — сколько кадров ждать;
## pilot=1 — сесть за штурвал; thrust, turn, vert — ввод пилота; secs — сколько секунд вести корабль до снимка;
## light=0 — погасить прожектор; lock=1 — шлюз трюма открыт; zap=1 — разряд (рычаг внизу, шкала погашена), zap_age=<с> — дуги по обшивке ART-068 через столько секунд (у окна — до 0,22 с, у дна — если киль ≤ 3 м над дном); ping=1 — импульс сонара с пробными отметками (age=<с> после импульса); power=1 — встать к пульту энергии; hot=<градусы> — перегрев реактора; energy=<ед.> — заряд корабля; hull=<%> — прочность корпуса (следы ART-049 снаружи); relief=0 — обшивка, мостик и лёд без рельефа ART-053/054/056, взвесь ART-058 «Экономно»; drain=1 — стеклоуст на корпусе; ship=x,y,z — поставить корабль (например ship=200,-80,0 — глубокий склон на востоке); view=x,y,z — камера снаружи в осях корабля (корпус). mate=x,z,курс[,роль[,внешность 0…1]] — ещё один член экипажа на палубе, несколько — через «;» (mate=helm — за штурвалом, mate=energy — инженер у пульта: метка «Занято» ART-033 вблизи), tag=a;l;- — состояния их табличек ART-033 (a — нажимает, l — нет связи), gone=1 — последний из них отключился (плашка хоста ART-043); cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории). save=<путь> — груз и поднятые образцы из файла сохранения. silt=1 — корабль в облаке ила (сонарная тьма). breach=n — пробоина в месте n (0 мостик … 3 машинное), weld=<доля>, water=<м>. observe=fish:flee,pred:ping — наблюдения в журнале, scanned=fish — изученные виды, journal=n — страница журнала (0 — сводка). route=n — маршрут забега n (0…2) выбран у голостола; vote=1 — маршрут пройден, решение «глубже или наверх», vote=coop — двое у стола (с mate=…), свой голос «глубже», ждём товарища; vote=up — итог забега (с мостика: итог на голограмме; с flyby=surface — вид с борта). flyby=start|surface — камера с борта (облёт в начале забега, вид при всплытии), age=<с> от начала облёта. vent=<с> — выпуски пузырей у сервисных крышек ART-063 через столько секунд после продувки (след винтов — по thrust и secs). grade=0 — без виньетки и цветокоррекции ART-065 (relief=0 — только овал «Экономно»). glints=0 — без бликов воды на потолке и полу мостика ART-067 (relief=0 — тоже выкл). wreck=<с> — шторка «Корпус разрушен» (ART-036) на этом времени. splash=<доля> — заставка прогрева (ART-034), hint=<с> — подсказка на это время. menu=1 — главное меню ART-037 (как при запуске). pause=1|new|exit — пауза ART-037 (new / exit — с подтверждением). scorch=n — n следов разряда ART-066 на дне перед носом (первый — старое пятно). use=<пост> — нажать кнопку действия у поста (scram, zap, sonar…; без x/z — игрок шагает к посту сам), снимок 0,3 с спустя — frames=1.


func _initialize() -> void:
	SaveGame.default_path = ""   # не читать и не писать сохранение игрока
	Main.intro = false   # снимок с мостика; flyby=start|surface — вид с борта
	Main.menu = "menu=1" in OS.get_cmdline_user_args()   # menu=1 — главное меню ART-037 поверх сцены
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
	if kv.has("wreck"):   # wreck=<с> — шторка «Корпус разрушен» ART-036 через столько секунд после разрушения
		main.vitals.hull = 0.0
		main.vitals.destroyed.emit()
		while main.wreck.active() and main.wreck.t < float(kv["wreck"]):
			main.step(1.0 / 30.0)
		main.set_process(false)   # кадр — ровно на этом времени шторки
	if kv.has("zap_age"):   # zap=1 zap_age=<с> — дуги по обшивке ART-068 через столько секунд после разряда
		main.step(0.0)
		while main.zap.flicker > 0.0 and Zap.arc_time(main.zap.flicker) < float(kv["zap_age"]) - 1e-3:
			main.step(1.0 / 30.0)
		main.set_process(false)   # кадр — ровно на этом времени разряда
	if kv.has("pause"):   # pause=1|new|exit — пауза ART-037 по «Назад», new / exit — открыто подтверждение
		main.back_pressed()
		if kv["pause"] in ["new", "exit"]:
			main.pause.press(kv["pause"])
			main.pause_panel.show_pause(main.pause)
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
	if kv.has("weak"):   # weak=1 — плашка «Слабая связь» у гостя (ART-043)
		var wl := WeakLink.new()
		wl.update(1.0, NetLink.WEAK_AFTER + 0.1)
		var wp := DropPanel.new()
		root.add_child(wp)
		wp.show_weak(wl)
	main.step(0.000001)
	main.set_process(false)
	if kv.has("event"):
		main.rooms.set_winch(Vector3(0.0,Airlock.Y+0.98 if kv["event"]=="leave" else Airlock.Y-0.45,Airlock.Z),kv["event"]=="leave",Color("9DFFD0"))
	var mesh:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(2.2,2.2)
	mesh.mesh=plane
	mesh.position=Vector3(0,Airlock.Y+0.03,Airlock.Z)
	mesh.layers=OceanView.LAYER_SHIP
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://art/ART-073-shlyuz-voda/src/water.gdshader")
	mat.set_shader_parameter("ripple",ImageTexture.create_from_image(Image.load_from_file("res://art/ART-073-shlyuz-voda/shlyuz-voda-normal.png")))
	mat.set_shader_parameter("rings",ImageTexture.create_from_image(Image.load_from_file("res://art/ART-073-shlyuz-voda/shlyuz-voda-kolca.png")))
	var c: Color=Seabed.Water.fog_color(main.helm.depth())
	mat.set_shader_parameter("water_color",c*0.65)
	mat.set_shader_parameter("ambient",Seabed.Water.ambient(main.helm.depth()))
	mat.set_shader_parameter("deepness",Seabed.Water.k(main.helm.depth()))
	mat.set_shader_parameter("camera_ship",main.ship.to_local(main.camera.global_position))
	mat.set_shader_parameter("clock",float(kv.get("phase","2.0")))
	mat.set_shader_parameter("water_y",mesh.position.y)
	var cargo: Array=ShipLayout.ROOMS[ShipLayout.Room.CARGO]
	mat.set_shader_parameter("lamp_ship",Vector3(0,float(cargo[3])-0.02,(float(cargo[0])+float(cargo[1]))*0.5))
	mat.set_shader_parameter("lamp_extent",Vector2(0.72,(float(cargo[1])-float(cargo[0])-0.6)*0.5+0.2))
	var speed:float=absf(float(kv.get("speed",str(main.helm.speed))))
	var gain:float=1.20+0.80*clampf(speed/5.0,0,1)+0.30*(1.0-clampf(main.vitals.hull/100.0,0,1))
	if kv.has("hit_age"): gain+=1.1*exp(-float(kv["hit_age"])/0.65)
	if kv.get("eco","0")=="1": gain*=0.625
	mat.set_shader_parameter("amplitude",gain)
	mat.set_shader_parameter("lamp_k",main.vitals.lamp_k(main.time,false))
	if kv.has("event"):
		mat.set_shader_parameter("event_age",float(kv.get("event_age","0.36")))
		mat.set_shader_parameter("event_kind",1.0 if kv["event"]=="leave" else 0.0)
	mesh.material_override=mat
	main.rooms.add_child(mesh)
	mesh.visible=false
	for j in 12: await process_frame
	await RenderingServer.frame_post_draw
	var base_calls: float=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	root.get_texture().get_image().save_png(out.replace(".png","-control.png"))
	mesh.visible=main.airlock.t>0.02
	for i in int(kv.get("frames", "12")):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT ", out, " ", img.get_size(), " вызовов отрисовки: ",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		", примитивов: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var calls:float=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	mesh.visible=false
	for j in 12: await process_frame
	await RenderingServer.frame_post_draw
	var file:=FileAccess.open(out.replace(".png","-metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"baseline":base_calls,"after":calls,"control":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"water_y":mesh.position.y,"airlock_t":main.airlock.t,"depth":main.helm.depth(),"amplitude":gain,"event":kv.get("event","none")},"  "))
	quit(0)
