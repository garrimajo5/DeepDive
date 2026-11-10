extends TestCase
## След винтов по ART-063: рождение по тяге, предел живых, мировые координаты, выпуски при всплытии, «Экономно».


func _ship(z: float = 0.0, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, -20.0, z))


func _run(w: Wake, secs: float, spin: float, ship := Transform3D.IDENTITY) -> void:
	if ship == Transform3D.IDENTITY:
		ship = _ship()
	for i in int(secs * 30.0):
		w.update(1.0 / 30.0, ship, spin)


func test_no_thrust_no_birth() -> void:
	var w := Wake.new()
	_run(w, 3.0, 0.0)
	eq(w.bubbles.size(), 0, "без тяги рождения нет")
	_run(w, 3.0, 0.03)
	eq(w.bubbles.size(), 0, "тяга меньше 0,04 — тоже нет")
	eq(w.rotor_cap(1.0), 80, "80 живых на ротор на полной тяге")
	eq(w.rotor_cap(0.5), 40, "по тяге")


func test_full_thrust_fills_to_cap() -> void:
	var w := Wake.new()
	_run(w, 8.0, 1.0)
	var l := w.alive(Wake.Src.LEFT)
	var r := w.alive(Wake.Src.RIGHT)
	ok(l > 60 and l <= 80, "левый ротор: до 80 живых (%d)" % l)
	ok(r > 60 and r <= 80, "правый ротор: до 80 живых (%d)" % r)
	ok(w.bubbles.size() <= Wake.LIMIT, "общий предел 200")


func test_born_behind_rotors_and_drift_back() -> void:
	var w := Wake.new()
	var ship := _ship(0.0)
	w.update(1.0 / 30.0, ship, 1.0)
	_run(w, 0.5, 1.0, ship)
	ok(w.bubbles.size() > 0, "родились")
	var inv := ship.affine_inverse()
	for b in w.bubbles:
		var p := inv * b.pos
		ok(absf(absf(p.x) - HullPlan.ENGINE_X) < Wake.SPREAD, "у ротора по x (%.2f)" % p.x)
		ok(p.z >= Wake.EXIT_Z - 0.05, "за задним срезом кожуха (%.2f)" % p.z)
	# реверс — передний выход, струя к носу
	var w2 := Wake.new()
	_run(w2, 0.5, -1.0, ship)
	for b in w2.bubbles:
		ok((inv * b.pos).z < Wake.FRONT_Z + 0.05, "при реверсе — впереди кожуха")


func test_world_space_not_riding_with_ship() -> void:
	var w := Wake.new()
	w.update(1.0 / 30.0, _ship(0.0), 1.0)
	_run(w, 0.3, 1.0, _ship(0.0))
	var b: Wake.Bubble = w.bubbles[0]
	var before := b.pos
	# корабль ушёл на 3 м, пузырь стоит на своём месте (плюс собственный ход)
	w.update(1.0 / 30.0, _ship(-0.1), 0.0)
	ok(b.pos.distance_to(before) < 0.5, "пузырь не прыгает вслед за кораблём")


func test_rise_and_fade_out() -> void:
	var w := Wake.new()
	_run(w, 0.2, 1.0)
	var b: Wake.Bubble = w.bubbles[0]
	var y0 := b.pos.y
	_run(w, 1.0, 0.0)
	ok(b.pos.y > y0, "пузыри всплывают")
	_run(w, 5.0, 0.0)
	eq(w.bubbles.size(), 0, "без тяги живые доживают и исчезают")
	near(Wake.alpha(0.0, 3.0), 0.0, 1e-6, "появление с нуля")
	near(Wake.alpha(0.12, 3.0), 1.0, 1e-6, "за 0,12 с")
	near(Wake.alpha(2.0, 3.0), 1.0, 1e-6, "до последней трети — полностью")
	near(Wake.alpha(2.5, 3.0), 0.5, 1e-4, "в последней трети гаснет")
	near(Wake.alpha(1.0, 3.0, -0.5), 0.25, 1e-4, "у льда гаснет")


func test_sizes_and_cells() -> void:
	var w := Wake.new()
	_run(w, 8.0, 1.0)
	var curls := 0
	for b in w.bubbles:
		ok(b.cell >= 0 and b.cell <= 15, "ячейка атласа")
		if b.cell >= 12:
			curls += 1
			ok(b.size >= 0.63 and b.size <= 1.22, "завиток 0,63…1,22 м")
		else:
			ok(b.size >= 0.35 and b.size <= 0.68, "карточка 0,35…0,68 м")
	ok(curls > 0 and curls < w.bubbles.size() / 4, "завитков немного (%d)" % curls)
	eq(Wake.cell_uv(13), Vector2(0.25, 0.75), "UV ячейки 13")


func test_vents_on_surfacing() -> void:
	var w := Wake.new()
	w.vent()
	ok(w.venting(), "продувка началась")
	_run(w, 1.2, 0.0)
	var a := w.alive(Wake.Src.VENT_A)
	var b := w.alive(Wake.Src.VENT_B)
	ok(a > 3 and a <= 36, "выпуск A (%d)" % a)
	ok(b > 3 and b <= 36, "выпуск B (%d)" % b)
	var inv := _ship().affine_inverse()
	for p in w.bubbles:
		ok((inv * p.pos).y > 4.0, "над сервисными крышками")
	_run(w, 8.0, 0.0)
	ok(not w.venting(), "серии кончаются")
	eq(w.bubbles.size(), 0, "и пузыри доживают")


func test_vent_shares_limit_with_rotors() -> void:
	var w := Wake.new()
	eq(w.vent_cap(160), 20, "при полном ходе — остаток поровну")
	eq(w.vent_cap(0), 36, "не больше 36 на выпуск")
	_run(w, 8.0, 1.0)
	w.vent()
	for i in 90:
		w.update(1.0 / 30.0, _ship(), 1.0)
		ok(w.bubbles.size() <= Wake.LIMIT, "не больше 200 живых")


func test_lite() -> void:
	var w := Wake.new()
	w.lite = true
	_run(w, 8.0, 1.0)
	ok(w.bubbles.size() <= Wake.LIMIT_LITE, "«Экономно» — до 96")
	ok(w.alive(Wake.Src.LEFT) <= 36, "36 на ротор")
	for b in w.bubbles:
		ok(b.cell <= 11, "только кадры 0–11")
		eq(b.spin, 0.0, "без вращения")
		near(b.life, 2.5, 1e-6, "жизнь 2,5 с")
	eq(w.vent_cap(0), 12, "12 на выпуск")


func test_view_in_scene() -> void:
	var m: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	await frames(2)
	var v := m.wake_view
	ok(v != null and v.get_parent() == m.ocean, "узел в «Отмели»")
	eq(v.multimesh.instance_count, Wake.LIMIT, "один MultiMesh на 200")
	ok(not v.visible, "без хода пусто")
	for i in 90:   # роторы на полной тяге (ввод пилота — в своих тестах)
		m.hull_motion.spin = 1.0
		m._wake(1.0 / 30.0)
	ok(v.visible and v.shown > 20, "на ходу пузыри видны (%d)" % v.shown)
	eq(v.multimesh.visible_instance_count, v.shown, "рисуется столько, сколько живых")
	m.queue_free()
	await frames(1)
