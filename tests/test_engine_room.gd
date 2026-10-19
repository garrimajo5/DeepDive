extends TestCase
## Машинное (ART-008, MOD-009): вентиль сброса пара удержанием остужает реактор и шумит, щиток «Аварийный сброс»
## глушит перегретый реактор на 6 с, после пуска он холоднее, чем после срыва.


func _hot(r: Reactor, heat: float) -> void:
	r.start_hot(false)
	r.heat = heat


func test_valve_cools_while_held() -> void:
	var r := Reactor.new()
	var e := EngineRoom.new()
	var said: Array[String] = []
	e.message.connect(func(t: String) -> void: said.append(t))
	_hot(r, 80.0)
	for i in 30:
		e.update(0.1, r, true)
	near(r.heat, 80.0 - EngineRoom.VENT_RATE * 3.0, 1e-3, "за 3 с остыл на 24°")
	ok(e.venting, "пар идёт")
	ok(e.wheel_deg > 100.0, "маховик крутится")
	eq(said, ["Сброс пара: реактор остывает"], "сообщение один раз за удержание")
	near(e.noise(0.1), EngineRoom.VENT_NOISE, 1e-6, "пар шумит громче хода")
	e.update(0.1, r, false)
	ok(not e.venting, "отпустили — пар не идёт")
	near(e.noise(0.1), 0.1, 1e-6, "без пара — шум хода")
	for i in 80:
		e.update(0.1, r, true)
	near(r.heat, 0.0, 1e-6, "не ниже нуля")


func test_scram_panel() -> void:
	var r := Reactor.new()
	var e := EngineRoom.new()
	var said: Array[String] = []
	e.message.connect(func(t: String) -> void: said.append(t))
	ok(not e.press(r), "без перегрева сброс не нужен")
	eq(said[-1], "Сброс не нужен: реактор в норме", "подсказка")
	near(r.scram, 0.0, 1e-9, "реактор работает")
	_hot(r, 90.0)
	ok(e.press(r), "перегрет — заглушили")
	near(r.scram, EngineRoom.MANUAL_SCRAM, 1e-9, "обесточен на 6 с")
	near(r.k(Reactor.Sys.ENGINES), 0.0, 1e-9, "системы без силы")
	ok(not e.press(r), "второй раз — уже обесточен")
	for i in 5:
		e.update(0.1, r, false)
		r.update(0.1, false)
	near(e.lid, 1.0, 1e-6, "крышка откинута")
	for i in 60:
		e.update(0.1, r, false)
		r.update(0.1, false)
	near(r.scram, 0.0, 1e-9, "пущен через 6 с")
	ok(r.heat < 30.0, "после ручного сброса холоднее, чем после срыва (%.1f°)" % r.heat)
	near(e.lid, 0.0, 1e-6, "крышка закрылась")


func test_auto_scram_restarts_at_50() -> void:
	var r := Reactor.new()
	_hot(r, 99.9)
	for i in 3:
		r.set_share(i, 60)
	r.update(1.0, false)
	ok(r.scram > 0.0, "сорвался на 100°")
	for i in int(Reactor.SCRAM_TIME / 0.1) + 1:
		r.update(0.1, false)
	ok(r.scram == 0.0 and r.heat >= 50.0 and r.heat < 55.0, "после срыва — 50° (%.1f°)" % r.heat)


func test_valve_and_panel_on_walls() -> void:
	var l := ShipLayout.new()
	ok(not l.can_stand(-2.6, 17.2), "в вентиль не войти")
	ok(not l.can_stand(2.6, 17.2), "в щиток не войти")
	ok(l.can_stand(EngineRoom.VALVE_POST.x, EngineRoom.VALVE_POST.y), "к вентилю можно подойти")
	ok(l.can_stand(EngineRoom.PANEL_POST.x, EngineRoom.PANEL_POST.y), "к щитку можно подойти")
	var p := Deck.nearest(Deck.posts(), EngineRoom.VALVE_POST.x, EngineRoom.VALVE_POST.y)
	eq(p.id, "valve", "пост вентиля")
	p = Deck.nearest(Deck.posts(), EngineRoom.PANEL_POST.x, EngineRoom.PANEL_POST.y)
	eq(p.id, "scram", "пост щитка")


func test_scene_vent_and_scram() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.reactor.start_hot(false)
	main.reactor.heat = 70.0
	main.walker.x = EngineRoom.VALVE_POST.x
	main.walker.z = EngineRoom.VALVE_POST.y
	main.step(1.0 / 30.0)
	eq(main.overlay.action_label, "Вентиль", "кнопка «Вентиль»")
	var r := main.overlay.router
	r.begin(5, r.layout.action.c)
	for i in 30:
		main.step(1.0 / 30.0)
	ok(main.reactor.heat < 70.0 - 2.0, "держим — остывает (%.1f°)" % main.reactor.heat)
	ok(main.rooms.steam.emitting, "пар виден")
	ok(absf(main.rooms.valve_wheel.rotation_degrees.x) > 1.0, "маховик повёрнут")
	ok(main.eco_ship.hull_noise >= EngineRoom.VENT_NOISE, "существа слышат пар")
	r.end(5)
	main.step(1.0 / 30.0)
	ok(not main.rooms.steam.emitting, "отпустили — пара нет")
	main.walker.x = EngineRoom.PANEL_POST.x
	main.walker.z = EngineRoom.PANEL_POST.y
	main.step(1.0 / 30.0)
	r.begin(5, r.layout.action.c)
	main.step(1.0 / 30.0)
	r.end(5)
	for i in 15:
		main.step(1.0 / 30.0)
	ok(main.reactor.scram > 0.0, "щиток заглушил реактор")
	ok(main.rooms.panel_lid.rotation_degrees.z < -100.0, "крышка щитка открыта")
	main.queue_free()
	await frames(1)
