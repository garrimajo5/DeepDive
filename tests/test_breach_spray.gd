extends TestCase
## Частицы пробоины по ART-072 (BreachSpray): выпуск и пределы трёх групп, «Экономно», путь струи до воды,
## брызги на воде, искры с отскоком и гашением в воде, кривые и кадры атласа, один материал на три MultiMesh.


func _breach(n: int = 0) -> Breach:
	var b := Breach.new()
	b.start(b.all[n])
	return b


func _run(sp: BreachSpray, b: Breach, secs: float, weld: bool) -> void:
	for i in int(round(secs * 60.0)):
		b.welding = weld and b.active != null
		sp.update(1.0 / 60.0, b)


func test_limits() -> void:
	var b := _breach()
	var sp := BreachSpray.new()
	_run(sp, b, 2.0, false)
	ok(sp.jet.size() >= 44 and sp.jet.size() <= BreachSpray.JET_LIMIT, "струя ~48 (%d)" % sp.jet.size())
	ok(sp.splash.size() >= 29 and sp.splash.size() <= BreachSpray.SPLASH_LIMIT, "брызги ~32 (%d)" % sp.splash.size())
	eq(sp.sparks.size(), 0, "не варят — искр нет")
	ok(not sp.flash, "электрода нет")
	_run(sp, b, 2.0, true)
	ok(sp.sparks.size() >= 26 and sp.sparks.size() <= BreachSpray.SPARK_LIMIT, "искры ~31 (%d)" % sp.sparks.size())
	ok(sp.flash, "вспышка электрода")
	ok(sp.count() <= 112, "≤ 112 частиц по ART-072 (%d)" % sp.count())
	for p in sp.jet:
		ok(p.age < p.life, "струя живёт до воды")


func test_lite() -> void:
	var b := _breach()
	var sp := BreachSpray.new()
	sp.lite = true
	_run(sp, b, 3.0, true)
	ok(sp.jet.size() <= BreachSpray.JET_LIMIT_LITE and sp.jet.size() >= 20, "«Экономно»: струя 24 (%d)" % sp.jet.size())
	ok(sp.splash.size() <= BreachSpray.SPLASH_LIMIT_LITE, "брызги 16")
	ok(sp.sparks.size() <= BreachSpray.SPARK_LIMIT_LITE, "искры 15")
	near(BreachSpray.jet_size(0.0, true).y, 0.30 * 1.45, 1e-6, "сегменты струи × 1,45")


func test_stop_lets_live_ones_finish() -> void:
	var b := _breach()
	var sp := BreachSpray.new()
	_run(sp, b, 1.0, true)
	b.hold(10.0)   # заварили
	ok(b.active == null, "закрыта")
	var born := sp.born
	_run(sp, b, 0.1, false)
	eq(sp.born, born, "закрыли — рождения нет")
	ok(sp.jet.size() > 0, "живые доживают")
	_run(sp, b, 1.0, false)
	eq(sp.count(), 0, "через жизнь — пусто")


func test_jet_path_lands_on_water() -> void:
	var s: Breach.Spot = Breach.spots()[0]
	var w := 0.1
	var t := BreachSpray.jet_life(s, w)
	ok(t > 0.4 and t < 0.8, "жизнь струи ≈ 0,64 с при воде 0,1 м (%.2f)" % t)
	near(BreachSpray.jet_pos(0.0, 0.0).z, 0.05, 0.04, "рождается у отверстия")
	var end := BreachSpray.jet_pos(t, PI * 0.5)   # разброс по x — y без смещения
	near(end.y, w - s.p.y, 0.02, "падает на воду")
	near(end.z, Breach.jet_reach(s, w), 0.06, "там, где брызги")
	ok(BreachSpray.jet_vel(t).y < 0.0, "в конце падает вниз")
	near(BreachSpray.jet_v0().length(), Breach.JET_V, 1e-5, "скорость Breach.JET_V")


func test_jet_cut_by_corridor_wall() -> void:
	var s: Breach.Spot = Breach.spots()[1]   # коридор узкий
	var t := BreachSpray.jet_life(s, 0.0)
	ok(BreachSpray.jet_pos(t, PI * 0.5).z <= Breach._across(s), "веер не простреливает соседний отсек")


func test_splash_on_water() -> void:
	var s: Breach.Spot = Breach.spots()[0]
	var c := BreachSpray.splash_at(s, 0.2)
	near(c.y, 0.2 - s.p.y + 0.012, 1e-6, "брызги на уровне воды")
	for i in 20:
		var a := float(i) / 19.0 * BreachSpray.SPLASH_LIFE
		var p := BreachSpray.splash_pos(c, a, 1.3, 1.0)
		ok(p.y >= c.y - 1e-6, "не ниже воды")
		ok(Vector2(p.x - c.x, p.z - c.z).length() <= BreachSpray.SPLASH_R + 1e-6, "разлёт ≤ 0,34 м")
	near(BreachSpray.splash_alpha(0.0), 0.0, 1e-6, "появляется из нуля")
	near(BreachSpray.splash_alpha(1.0), 0.0, 1e-6, "тает")
	near(BreachSpray.splash_size(0.5).y, 0.16, 1e-6, "высота 0,06 + 0,10·sin(πa)")


func test_sparks_bounce_once() -> void:
	var floor_y := -1.0
	for i in 12:
		var v := BreachSpray.spark_v0(fposmod(i * 0.618034, 1.0), fposmod(i * 2.399963, TAU))
		ok(v.length() >= 1.5 - 1e-5 and v.length() <= 3.0 + 1e-5, "1,5–3 м/с")
		ok(v.z > 0.0, "внутрь отсека")
		var lowest := 0.0
		for j in 73:
			var p := BreachSpray.spark_pos(v, j * 0.01, floor_y)
			lowest = minf(lowest, p.y)
		ok(lowest >= floor_y - 1e-4, "не проваливается сквозь пол")
	var v := Vector3(0.0, 0.0, 2.0)
	var tb := (sqrt(2.0 * BreachSpray.SPARK_G * 1.0)) / BreachSpray.SPARK_G
	near(BreachSpray.spark_pos(v, tb, floor_y).y, floor_y, 1e-4, "долетела до пола")
	var after := BreachSpray.spark_vel(v, tb + 0.001, floor_y)
	ok(after.y > 0.0 and after.y < 4.5 * 0.23 + 0.01, "отскок вверх × 0,23 (%.2f)" % after.y)
	near(after.z, 2.0 * 0.55, 1e-6, "горизонталь × 0,55")


func test_sparks_quench_in_water() -> void:
	var v := Vector3(0.0, -0.5, 2.0)
	near(BreachSpray.spark_life(v, -1.0, 0.0), BreachSpray.SPARK_LIFE, 1e-6, "сухо — 0,72 с")
	near(BreachSpray.spark_life(v, -1.0, 0.015), BreachSpray.SPARK_LIFE, 1e-6, "вода ≤ 2 см — не гаснут")
	var wet := BreachSpray.spark_life(v, -1.0, 0.3)
	ok(wet < BreachSpray.SPARK_LIFE, "в воде гаснет раньше (%.2f)" % wet)
	var t_in := wet - BreachSpray.SPARK_QUENCH
	near(BreachSpray.spark_pos(v, t_in, -1.0).y, -1.0 + 0.3, 1e-4, "гаснет через 0,08 с после входа в воду")


func test_spark_look() -> void:
	near(BreachSpray.spark_size(Vector3(0, 0, 1)).y, 0.12, 1e-6, "медленная — 0,12 м")
	near(BreachSpray.spark_size(Vector3(0, 0, 10)).y, 0.32, 1e-6, "быстрая — не длиннее 0,32 м")
	ok(BreachSpray.spark_color(0.0).is_equal_approx(BreachSpray.HOT), "у резака #FFF2D5")
	ok(BreachSpray.spark_color(1.0).is_equal_approx(BreachSpray.COOL), "остыла — #F18A3D")
	for a in [0.0, 0.5, 1.0]:
		var c := BreachSpray.spark_color(a)
		ok(c.g > 0.5, "без красного (#129): %s" % c)


func test_frames_stay_in_group() -> void:
	near(BreachSpray.frame(0.0, BreachSpray.JET_FRAMES), 0.0, 1e-6, "струя с кадра 0")
	near(BreachSpray.frame(1.0, BreachSpray.JET_FRAMES), 7.0, 1e-6, "струя до 7 (7a)")
	near(BreachSpray.frame(0.5, BreachSpray.SPLASH_FRAMES), 9.5, 1e-6, "брызги 8 + 3a")
	near(BreachSpray.frame(1.0, BreachSpray.SPARK_FRAMES), 14.0, 1e-6, "искры 12 + 2a — до 14, не в электрод")
	near(BreachSpray.jet_alpha(0.5), 0.58, 1e-6, "струя 0,58")
	near(BreachSpray.jet_alpha(1.0), 0.0, 1e-6, "струя тает к воде")


func test_moving_spot_clears() -> void:
	var b := _breach(0)
	var sp := BreachSpray.new()
	_run(sp, b, 1.0, false)
	b.hold(10.0)
	b.cd = 0.0
	b.start(b.all[3])
	sp.update(0.001, b)
	ok(sp.jet.size() <= 1, "новое место — прежние частицы не переносятся")


func test_scene_three_multimesh_one_material() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var v := main.breach_view
	eq(v.find_children("*", "CPUParticles3D", true, false).size(), 0, "круглых точек CPUParticles больше нет")
	var mats := {}
	for n: MultiMeshInstance3D in [v.jet_mm, v.splash_mm, v.spark_mm]:
		eq(n.layers, OceanView.LAYER_SHIP, "%s — слой корабля" % n.name)
		eq(n.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без теней")
		mats[n.multimesh.mesh.surface_get_material(0)] = true
	eq(mats.size(), 1, "один общий материал")
	eq(v.find_children("*", "Light3D", true, false).size(), 2, "без новых огней: свет сварки и тревога")
	main.open_breach(0)
	main.debug_weld = true
	for i in 30:
		main.step(1.0 / 30.0)
	ok(v.jet_mm.multimesh.visible_instance_count > 30, "струя рисуется (%d)" % v.jet_mm.multimesh.visible_instance_count)
	ok(v.spark_mm.visible and v.splash_mm.visible, "искры и брызги")
	main.queue_free()
	await frames(1)
