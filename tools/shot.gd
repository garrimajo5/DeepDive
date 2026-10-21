extends SceneTree
## Скриншот главной сцены без телефона.
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x720 -s tools/shot.gd -- out.png [ключ=значение ...]
## Ключи: x, z, yaw, pitch — игрок на палубе (yaw в градусах, 0 — к носу); noclip=1 y=<м> — тестовый полёт (глаз в x,y,z, сквозь корпус — смотреть живой мир); frames — сколько кадров ждать;
## pilot=1 — сесть за штурвал; thrust, turn, vert — ввод пилота; secs — сколько секунд вести корабль до снимка;
## light=0 — погасить прожектор; lock=1 — шлюз трюма открыт; zap=1 — разряд (рычаг внизу, шкала погашена); ping=1 — импульс сонара с пробными отметками (age=<с> после импульса); power=1 — встать к пульту энергии; hot=<градусы> — перегрев реактора; energy=<ед.> — заряд корабля; drain=1 — стеклоуст на корпусе; ship=x,y,z — поставить корабль (например ship=200,-80,0 — глубокий склон на востоке); view=x,y,z — камера снаружи в осях корабля (корпус). mate=x,z,курс[,роль[,внешность 0…1]] — ещё один член экипажа на палубе, несколько — через «;» (mate=helm — за штурвалом); cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории). save=<путь> — груз и поднятые образцы из файла сохранения. silt=1 — корабль в облаке ила (сонарная тьма). breach=n — пробоина в месте n (0 мостик … 3 машинное), weld=<доля>, water=<м>. observe=fish:flee,pred:ping — наблюдения в журнале, scanned=fish — изученные виды, journal=n — страница журнала (0 — сводка). route=n — маршрут забега n (0…2) выбран у голостола; vote=1 — маршрут пройден, решение «глубже или наверх», vote=coop — двое у стола (с mate=…), свой голос «глубже», ждём товарища; vote=up — итог забега (с мостика: итог на голограмме; с flyby=surface — вид с борта). flyby=start|surface — камера с борта (облёт в начале забега, вид при всплытии), age=<с> от начала облёта. splash=<доля> — заставка прогрева (ART-034), hint=<с> — подсказка на это время. use=<пост> — нажать кнопку действия у поста (scram, zap, sonar…; без x/z — игрок шагает к посту сам), снимок 0,3 с спустя — frames=1.


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
	for i in int(kv.get("frames", "8")):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT ", out, " ", img.get_size(), " вызовов отрисовки: ",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		", примитивов: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	quit(0)
