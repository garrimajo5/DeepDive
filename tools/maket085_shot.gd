extends SceneTree
## Снимки из кресла пилота макета ART-085 v3 в ЖИВОМ мире игры — критерий владельца 17.11 (#1788):
## «виды 00→01 из штатного кресла пилота с органами управления, 1280×720 и 1600×720: наблюдаемость
## жизни у мха, предупреждения серпохвоста и кроны у 01 — через центральный порт». Продолжение
## приёмки атмосферы #1400 на новом корабле: те же ракурсы `ShotSetup.scena` (scena=1|2|3,
## scena_t=, zamer=, strah= — как у tools/shot.gd), но мостик/отсеки/корпус игры спрятаны, вместо
## них — кабина макета (`Maket085.build_cabin`), камера — глаз пилота v3 (EYE, pitch −8°, FOV 72).
## Прожектор перенесён под нос макета (0; 0,2; −13,4) — лампа нынешнего корпуса (0; 0,8; −6,8)
## оказалась бы внутри кабины. Приборы (HUD) — штатные, hud=0 гасит. Мир и код игры не меняются.
##
##   godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##       --resolution 1280x720 -s tools/maket085_shot.gd -- out.png [ключи shot.gd] [свои ниже]
##
## Свои ключи (с ключами shot.gd сочетаются; scena= и поза корабля — из shot_setup.gd):
## glaza=0,1.65,-2.5,0,-8 — глаз в осях корабля: x,y,z[,курс°,наклон°] — внутренние кадры пути соло
## vokrug=20,6,140 — камера снаружи: дистанция,высота,угол° (0 — за кормой, 180 — перед носом);
##       строится кожух макета (Maket085.build_hull) вместо кабины; имеет смысл со scena= или ship=
## С ship= стоянка держится против течения все frames= кадров (как сценарий тестера — возврат на
## стоянку за 0,3 с до кадра, #1757): длинный frames= для поздней фазы не сдвигает ракурс.
## С kupol=1 в лог печатается клип купольника, t и «створка гнезда 1: …» (как строка снимка сценария).
## kino=9 — непрерывный фрагмент (как kino= у shot.gd): мир идёт столько секунд ровным шагом SCENA_DT,
##       стоянку ship= держит каждый шаг, кадры <out>-kino/0000.png…; kino_fps=10 — кадров на секунду
##       мира (шаг мира — 1/30 с); в лог раз в секунду мира — клип купольника, t и строка створки
##       (моменты фаз для комментария). Сборка — GIF (Pillow) или ffmpeg -framerate <fps> -i %04d.png.

const Maket := preload("res://tools/maket085.gd")
const ShotSetup := preload("res://tools/shot_setup.gd")
const QaRun := preload("res://scripts/game/qa_runner.gd")   # petal_note — строка створки как у снимка сценария

## Куда переносится прожектор для макета: под нос, под порты (у нынешнего корпуса — (0; 0,8; −6,8),
## что для макета внутри кабины).
const MAKET_LAMP := Vector3(0.0, 0.2, -13.4)


func _initialize() -> void:
	SaveGame.default_path = ""   # не читать и не писать сохранение игрока
	AddressScreen.default_path = ""   # и последний адрес входа ART-039
	Settings.default_path = ""   # и настройки ART-037
	RunTimeline.default_path = ""   # и хронометраж забегов (#633)
	Main.intro = false
	Main.menu = false
	Main.hints = false
	Main.offer = false
	_go.call_deferred()


func _go() -> void:
	var parsed := ShotSetup.parse_args(OS.get_cmdline_user_args())
	var out: String = parsed["out"]
	var kv: Dictionary = parsed["kv"]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	while main.has_method("warming") and main.warming():   # прогрев шейдеров под шторкой (Warmup)
		await process_frame
	ShotSetup.apply(main, kv)
	var cam := _maket_view(main, kv)
	if kv.get("hud", "1") == "0":
		main.set_hud(false)
	var stoyat := Vector3.INF
	var stoyat_yaw := 0.0
	if kv.has("ship"):  # стоянку держим против течения все кадры ожидания фазы (как сценарий, #1757)
		var sp: PackedFloat64Array = (kv["ship"] as String).split_floats(",")
		stoyat = Vector3(sp[0], sp[1], sp[2])
		stoyat_yaw = main.helm.yaw
	if kv.has("kino"):   # kino=<с> — непрерывный фрагмент: кадры <out>-kino/NNNN.png (#1788)
		await _kino(main, out, float(kv["kino"]), int(kv.get("kino_fps", "15")), stoyat, stoyat_yaw)
		quit(0)
		return
	for i in int(kv.get("frames", "8")):
		if stoyat != Vector3.INF:
			main.helm.yaw = stoyat_yaw
			main.helm.turn = 0.0
			main.park_at(stoyat)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	if kv.has("scena"):
		print(ShotSetup.scena_line(main))
		if not kv.has("vokrug"):
			print(_ground_line(main, cam))
		if kv.has("zamer"):
			ShotSetup.zamer_log(main)
	if kv.get("kupol", "0") == "1" and main.gate_view:
		var d: EcoDome = main.eco.dome
		print("купольник: клип %s, t %.1f с%s" % [d.clip(), d.t,
			QaRun.petal_note(EcoDome.NEST, main.gate_view.petal(EcoDome.NEST))])
	print("SHOT ", out, " ", img.get_size(), " вызовов отрисовки: ",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		", примитивов: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	quit(0)


## Ролик (kino=): main сам не шагает, мир идёт `ShotSetup.kino_steps` шагов SCENA_DT на кадр, стоянку
## держим против течения после каждого шага (как у одиночного кадра с ship=). Кадры — <out>-kino/NNNN.png;
## раз в секунду мира в лог — клип купольника, t и строка створки (моменты фаз для комментария в issue).
func _kino(main: Node, out: String, seconds: float, fps: int, stoyat: Vector3, stoyat_yaw: float) -> void:
	main.set_process(false)
	var dir := out.get_basename() + "-kino"
	DirAccess.make_dir_recursive_absolute(dir)
	var per := ShotSetup.kino_steps(fps)
	var was_sec := -1
	for f in int(round(seconds * fps)):
		for i in per:
			main.step(ShotSetup.SCENA_DT)
			if stoyat != Vector3.INF:
				main.helm.yaw = stoyat_yaw
				main.helm.turn = 0.0
				main.park_at(stoyat)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%04d.png" % [dir, f])
		var sec := int(f / float(fps))
		if sec != was_sec:
			was_sec = sec
			var d: EcoDome = main.eco.dome
			print("kino %d с: клип %s, t %.1f с%s" % [sec, d.clip(), d.t,
				QaRun.petal_note(EcoDome.NEST, main.gate_view.petal(EcoDome.NEST))])
	print("KINO ", dir, " кадров ", int(round(seconds * fps)), ", ", fps, " в секунду")


## Прячет вид корабля игры (мостик, отсеки, корпус, экипаж, метки), ставит кабину/кожух макета
## и камеру макета; возвращает камеру. Прожектор переносится под нос макета. Кабина запоминается
## в мете main (maket_cabin) — для замера «грунт в порту» заслоны считаются только по ней
## (луч прожектора — не заслон).
func _maket_view(main: Node, kv: Dictionary) -> Camera3D:
	var ship: Node3D = main.ship
	for v in [main.bridge, main.rooms, main.hull, main.crew_view, main.ghost_view,
			main.name_tags, main.ghost_tags, main.busy_marks, main.hint_pointer, main.breach_view]:
		(v as Node3D).visible = false
	main.searchlight.position = MAKET_LAMP
	var cam := Camera3D.new()
	cam.name = "Глаза макета"
	cam.fov = Maket.FOV
	cam.near = 0.05
	cam.far = 400.0
	if kv.has("vokrug"):   # внешний вид: кожух макета, камера из мира
		ship.add_child(Maket.build_hull())
		var p := (kv["vokrug"] as String).split_floats(",")
		var a := deg_to_rad(p[2] if p.size() > 2 else 140.0)
		var dist: float = p[0]
		var up: float = p[1] if p.size() > 1 else 5.0
		root.add_child(cam)
		var base: Vector3 = main.helm.pos
		var off := Vector3(sin(a) * dist, up, cos(a) * dist).rotated(Vector3.UP, main.helm.yaw)
		cam.position = base + off
		cam.look_at(base + Vector3(0.0, 0.5, 0.0), Vector3.UP)
	else:   # кабина макета; глаз — пилот v3 или glaza=
		var cabin := Maket.build_cabin()
		ship.add_child(cabin)
		main.set_meta("maket_cabin", cabin)
		ship.add_child(cam)
		if kv.has("glaza"):
			var p := (kv["glaza"] as String).split_floats(",")
			cam.position = Vector3(p[0], p[1], p[2])
			cam.rotation = Vector3(deg_to_rad(p[4] if p.size() > 4 else 0.0),
					deg_to_rad(p[3] if p.size() > 3 else 0.0), 0.0)
		else:
			cam.position = Maket.EYE
			cam.rotation = Vector3(Maket.PITCH, 0.0, 0.0)
	cam.make_current()
	return cam


## Аналог ShotSetup.ground_line для макета: заслоны — только кабина макета (стена с реальными
## просветами портов; луч прожектора и прочее — не заслон), камера — глаз макета.
func _ground_line(main: Node, cam: Camera3D) -> String:
	var occ: Array = []
	if main.has_meta("maket_cabin"):
		var cabin: Node = main.get_meta("maket_cabin")
		occ = ShotSetup.occluders([cabin])
	var h := cam.get_viewport().get_visible_rect().size.y
	var names := ["слева", "по центру", "справа"]
	var dist: Array[String] = []
	var edge: Array[String] = []
	for i in ShotSetup.GROUND_COLS.size():
		var r := ShotSetup.ground_ahead(cam, ShotSetup.GROUND_COLS[i], occ, Seabed.mesh_height)
		dist.append("%s %s" % [names[i], "нет" if r.is_empty() else "с %d м" % roundi(r["dist"])])
		edge.append("—" if r.is_empty() else str(roundi((h - r["row"]) / h * 100.0)))
	return "грунт в порту макета (#1400): %s · кромка на %s %% кадра снизу" % [", ".join(dist), "/".join(edge)]
