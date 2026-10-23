extends TestCase
## Шторка «Корпус разрушен» по ART-036 (`Wreck`, `WreckView`, `Main._on_destroyed`).


func test_timeline() -> void:
	near(Wreck.cracks(Wreck.HIT), 0.6, 1e-5, "удар: трещины 0,6")
	near(Wreck.vignette(Wreck.HIT), 0.12, 1e-5, "удар: виньетка 0,12 от конечной")
	eq(Wreck.text(0.1), 0.0, "в удар надписей ещё нет")
	near(Wreck.text(Wreck.TEXT_IN), 1.0, 1e-5, "надписи читаются с 0,4 с")
	near(Wreck.cracks(1.0), 0.9, 1e-5, "к 1 с трещины 0,9")
	near(Wreck.vignette(1.0), 0.6, 1e-5, "к 1 с виньетка 0,6")
	for t in [1.5, 2.0, 2.5, 3.1]:
		eq(Wreck.vignette(t), 1.0, "%.1f с: виньетка в полную силу" % t)
		eq(Wreck.text(t), 1.0, "%.1f с: надписи на месте" % t)
		eq(Wreck.solid(t), 0.0, "%.1f с: сплошной шторки нет" % t)
	near(Wreck.solid(Wreck.RESTART_AT - 1e-4), 1.0, 1e-3, "к 3,5 с шторка сплошная")
	near(Wreck.text(Wreck.RESTART_AT - 1e-4), 0.0, 1e-3, "надписи ушли")
	near(Wreck.cracks(Wreck.RESTART_AT - 1e-4), 0.0, 1e-3, "трещины ушли")
	eq(Wreck.solid(Wreck.END), 0.0, "шторка растаяла")
	ok(Wreck.solid(Wreck.RESTART_AT + 0.1) < 1.0 and Wreck.solid(Wreck.RESTART_AT + 0.1) > 0.0, "тает за 0,3 с")


func test_shift_once() -> void:
	eq(Wreck.shift(0.0), Vector2.ZERO, "в начале на месте")
	near(Wreck.shift(Wreck.HIT * 0.5).x, Wreck.SHIFT_PX, 1e-4, "сдвиг на 4 px")
	eq(Wreck.shift(Wreck.HIT), Vector2.ZERO, "и возврат")
	eq(Wreck.shift(1.0), Vector2.ZERO, "дальше неподвижно")


func test_lamps() -> void:
	eq(Wreck.lamps(-1.0), 1.0, "без шторки свет как был")
	eq(Wreck.lamps(0.3), 1.0, "до 0,4 с плафоны горят")
	near(Wreck.lamps(0.5), Wreck.LAMP_DIP, 1e-4, "провал")
	near(Wreck.lamps(0.6), Wreck.LAMP_BACK, 1e-4, "частичный возврат в 0,6 с")
	eq(Wreck.lamps(1.0), 0.0, "к 1 с темнота")
	eq(Wreck.lamps(3.0), 0.0, "темно до сплошной шторки")
	eq(Wreck.lamps(Wreck.RESTART_AT), 1.0, "новый забег — свет")


func test_vignette_formula() -> void:
	near(Wreck.vignette_alpha(Vector2(0.5, 0.5)), 0.58, 1e-6, "центр")
	near(Wreck.vignette_alpha(Vector2(0.0, 0.5)), 0.93, 1e-6, "край")
	near(Wreck.vignette_alpha(Vector2(0.0, 0.0)), 0.93, 1e-6, "угол — не больше края")
	var x := (1700.0 - 1200.0) / 1200.0   # точка макета (1700, 700)
	var y := (700.0 - 540.0) / 540.0
	near(Wreck.vignette_alpha(Vector2(1700.0 / 2400.0, 700.0 / 1080.0)), 0.58 + 0.35 * (x * x + y * y), 1e-5, "по формуле")


func test_update_restarts_once() -> void:
	var w := Wreck.new()
	ok(not w.active() and not w.update(0.1), "шторки нет")
	w.start()
	var restarts := 0
	var steps := 0
	while w.active() and steps < 100:
		if w.update(0.1):
			restarts += 1
			near(w.t, Wreck.RESTART_AT, 0.11, "подъём — когда шторка сплошная")
		steps += 1
	eq(restarts, 1, "подъём ровно один раз")
	ok(not w.active(), "шторка кончилась")
	w.follow(1.2)
	ok(w.active(), "гость: шторка по времени хоста")
	w.follow(-1.0)
	ok(not w.active(), "гость: хост без шторки")


func test_scene_curtain_then_restart() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.sit_at_helm()
	main.helm.pos = Vector3(30.0, -40.0, -60.0)
	main.vitals.hit(100, "")
	ok(main.wreck.active(), "корпус разрушен — шторка")
	ok(not main.pilot.seated, "пилот встал")
	ok(main.helm.pos.distance_to(Vector3(30.0, -40.0, -60.0)) < 0.5, "под шторкой корабль ещё на месте")
	var r := main.overlay.router
	r.begin(3, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.9))   # крестовина вперёд — не идёт в игру
	var z := main.walker.z
	for i in 12:
		main.step(0.1)
	r.end(3)
	near(main.walker.z, z, 1e-4, "игрок не идёт")
	ok(not main.overlay.visible, "крестовина и кнопка скрыты")
	ok(main.wreck_view.root.visible, "шторка на экране")
	near(main.wreck_view.title.modulate.a, 1.0, 1e-4, "заголовок читается")
	eq(main.wreck_view.title.text, "Корпус разрушен", "заголовок")
	eq(main.wreck_view.sub.text, "Ковчег поднимают к началу спуска", "подпись")
	near(main.wreck_view.cracks.modulate.a, 0.9, 1e-3, "трещины")
	ok(main.wreck_view.cracks.texture != null, "текстура трещин")
	eq(main.vitals.hull, 0.0, "корпус ещё разрушен")
	for i in 23:
		main.step(0.1)
	ok(main.vitals.hull == Vitals.MAX, "под сплошной шторкой — подъём с целым корпусом")
	ok(main.helm.pos.distance_to(Vector3(30.0, -40.0, -60.0)) > 1.0, "Ковчег у начала спуска")
	for i in 5:
		main.step(0.1)
	ok(not main.wreck.active() and not main.wreck_view.root.visible, "шторка убрана")
	ok(main.overlay.visible, "управление вернулось")
	main.queue_free()
	await frames(1)

