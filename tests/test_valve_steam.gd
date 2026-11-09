extends TestCase
## Пар вентиля по ART-071 (ValveSteam): выпуск и предел, путь от сопла, кривые размера и альфы, кадры атласа,
## оттенок по перегреву и SCRAM, «Экономно», один MultiMesh в машинном.


func _run(st: ValveSteam, secs: float, on: bool) -> void:
	for i in int(round(secs * 60.0)):
		st.update(1.0 / 60.0, on)


func test_rate_and_cap() -> void:
	var st := ValveSteam.new()
	_run(st, 1.0, false)
	eq(st.puffs.size(), 0, "без вентиля пара нет")
	_run(st, 3.0, true)
	ok(st.puffs.size() >= 46 and st.puffs.size() <= ValveSteam.LIMIT, "48 живых при выпуске 38,4/с (%d)" % st.puffs.size())
	for p in st.puffs:
		ok(p.age < ValveSteam.LIFE, "живут меньше 1,25 с")
	var born := st.born
	_run(st, 0.5, false)
	eq(st.born, born, "отпустили — рождения нет")
	ok(st.puffs.size() > 0, "живые доживают")
	_run(st, 0.8, false)
	eq(st.puffs.size(), 0, "через жизнь — пусто")


func test_lite_half() -> void:
	var st := ValveSteam.new()
	st.lite = true
	_run(st, 3.0, true)
	ok(st.puffs.size() >= 22 and st.puffs.size() <= ValveSteam.LIMIT_LITE, "«Экономно» — 24 живых (%d)" % st.puffs.size())


func test_path_from_nozzle() -> void:
	near(ValveSteam.NOZZLE.distance_to(Vector3(-2.82, 1.42, 17.2)), 0.0, 1e-5, "сопло у маховика")
	near(ValveSteam.pos(0.0, 1.0).distance_to(ValveSteam.NOZZLE), 0.0, 1e-6, "рождается в сопле")
	var mid := ValveSteam.pos(0.6, 0.0) - ValveSteam.NOZZLE
	ok(mid.x > 0.15 and mid.y > 0.35, "от стены (+X) и вверх: %s" % mid)
	var end := ValveSteam.pos(ValveSteam.LIFE, 0.0) - ValveSteam.NOZZLE
	near(end.x, 0.70 * 1.25 / (1.0 + 2.5 * 1.25), 1e-5, "x = 0,70s / (1 + 2,5s)")
	near(end.y, 0.75 * 1.25 - 0.10 * 1.25 * 1.25 - 0.30, 1e-5, "в конце клочья оседают на 0,30 м")
	var a := ValveSteam.pos(0.625, 0.0) - ValveSteam.pos(0.625, PI)
	near(a.length(), 2.0 * ValveSteam.SPREAD, 1e-5, "разброс sin(πa)·0,075 по углу частицы")


func test_curves() -> void:
	near(ValveSteam.size(0.0).y, 0.09, 1e-6, "высота у сопла 0,09 м")
	near(ValveSteam.size(1.0).y, 0.42, 1e-6, "к концу 0,42 м")
	near(ValveSteam.size(0.0).x, 0.09 * 0.6, 1e-6, "узкая струя: ширина 0,6 h")
	near(ValveSteam.size(1.0).x, 0.42, 1e-6, "клочья — квадрат")
	near(ValveSteam.alpha(0.0), 0.0, 1e-6, "появляется из нуля")
	near(ValveSteam.alpha(0.3), 0.25, 1e-6, "в середине 0,25")
	near(ValveSteam.alpha(1.0), 0.0, 1e-6, "к концу тает")
	var f: Array = ValveSteam.frames(0.0)
	eq([f[0], f[1]], [0, 1], "начало — кадры 0 и 1")
	f = ValveSteam.frames(0.5)
	eq([f[0], f[1]], [7, 8], "середина — кадр 7,5")
	near(f[2], 0.5, 1e-6, "вес второго — smoothstep(fract)")
	f = ValveSteam.frames(1.0)
	eq([f[0], f[1]], [15, 15], "15→0 не зацикливается")


func test_tint() -> void:
	var r := Reactor.new()
	var cold := ValveSteam.tint(r)
	near(cold.r, ValveSteam.COLD.r, 1e-6, "обычный — #C6D6DE")
	r.start_hot(false)
	r.heat = 95.0
	var hot := ValveSteam.tint(r)
	ok(hot.r > cold.r and hot.b < cold.b, "на перегреве теплее")
	ok(hot.r < 0.95 and hot.g > 0.7, "без красного (#129)")
	r.scram = 5.0
	near(ValveSteam.tint(r).b, ValveSteam.COLD.b, 1e-6, "SCRAM убирает тёплую долю")
	near(ValveSteam.tint(Reactor.new(), 0.0).g, ValveSteam.COLD.g * ValveSteam.DARK, 1e-6, "в темноте — слабое 0,08")


func test_one_multimesh_in_engine_room() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var view: SteamView = main.rooms.steam
	ok(view is MultiMeshInstance3D, "пар — MultiMesh")
	eq(view.layers, OceanView.LAYER_SHIP, "на слое корабля")
	eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без теней")
	eq(view.find_children("*", "Light3D", true, false).size(), 0, "без новых огней")
	eq(main.rooms.find_children("*", "CPUParticles3D", true, false).size(), 0, "старых частиц пара нет")
	ok(not view.visible, "без вентиля скрыт")
	main.debug_vent = true
	main.reactor.start_hot(false)
	main.reactor.heat = 90.0
	for i in 90:
		main.step(1.0 / 60.0)
	ok(view.visible and view.shown > 40, "держат вентиль — клубы (%d)" % view.shown)
	var tint: Color = view.mat.get_shader_parameter("tint")
	ok(tint.r > ValveSteam.COLD.r, "перегрев подкрашивает пар")
	main.queue_free()
	await frames(1)
