extends TestCase
## Уход к Кристальному лесу у 10 (#828, часть 2б): затемнение, экран «в разработке», возвращение к 10 и сохранение.


func test_phases() -> void:
	var tr := DescentTrip.new()
	eq(tr.update(1.0), "", "не начат — молчит")
	eq(tr.alpha(), 0.0)
	tr.start()
	eq(tr.update(DescentTrip.SINK * 0.5), "")
	near(tr.alpha(), 0.5, 1e-4, "затемнение")
	eq(tr.text_alpha(), 0.0, "надписи — после затемнения")
	eq(tr.update(DescentTrip.SINK * 0.5 + 1.0), "")
	near(tr.alpha(), 1.0, 1e-4, "экран закрыт")
	ok(tr.text_alpha() > 0.0, "надпись видна")
	eq(tr.update(DescentTrip.HOLD * 0.5), "arrive", "посреди экрана — вернуть корабль")
	eq(tr.update(0.1), "", "один раз")
	var n := 0
	var got := ""
	while tr.active and n < 200:
		got = tr.update(0.1)
		n += 1
	eq(got, "done", "конец")
	eq(tr.alpha(), 0.0, "свет вернулся")


func test_return_spot_inside_ten_toward_07() -> void:
	var p := DescentTrip.return_spot()
	var ten := Run.place_xz(Run.DESCENT)
	ok(Vector2(p.x, p.z).distance_to(ten) < float(Run.PLACES[Run.DESCENT][2]), "в круге места 10")
	var to07 := Vector2(LayerMap.POINTS["07"]["x"], LayerMap.POINTS["07"]["z"])
	ok(Vector2(p.x, p.z).distance_to(to07) < ten.distance_to(to07), "ближе к террасе 07, чем центр 10")
	near(p.y - Seabed.height(p.x, p.z), DescentTrip.DEPTH_ABOVE, 1e-3, "над дном")


func test_scene_deeper_at_ten_returns_with_lore() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var at := Run.place_xz(Run.DESCENT)
	main.helm.pos = Vector3(at.x + 10.0, Seabed.height(at.x + 10.0, at.y) + 20.0, at.y)
	main.step(1.0 / 30.0)
	ok(main.run.voting, "у спуска — голосование")
	main.decide("deep")
	ok(main.trip.active, "кат-сцена началась")
	main.step(1.0 / 30.0)
	ok(main.trip_view.shown(), "шторка на экране")
	ok(not main.run.voting, "голосование закрыто")
	ok(not main.lore.knows(LayerLore.DOWN), "знание — только после ухода")
	var worst := 0   # #1090: камни и ракушки у 10 — заранее, по CELLS_STEP за шаг, а не весь радиус в кадре возвращения
	for i in int((DescentTrip.SINK + DescentTrip.HOLD + DescentTrip.RISE) * 30.0) + 5:
		var done := main.ocean.stones.stones.cells_done + main.ocean.shells.stones.cells_done
		main.step(1.0 / 30.0)
		worst = maxi(worst, main.ocean.stones.stones.cells_done + main.ocean.shells.stones.cells_done - done)
	ok(worst <= 4 * SeabedStones.CELLS_STEP, "за шаг клеток не больше 4 × CELLS_STEP: %d" % worst)
	ok(not main.trip.active and not main.trip_view.shown(), "шторка убрана")
	var back := DescentTrip.return_spot()
	ok(Vector2(main.helm.pos.x, main.helm.pos.z).distance_to(Vector2(back.x, back.z)) < 3.0, "корабль — у 10")
	ok(main.lore.knows(LayerLore.DOWN) and main.lore.knows(LayerLore.BACK), "знания: ушли и вернулись")
	ok(not main.run.voting and not main.run.ended, "забег идёт, голосование не открылось снова")
	main.queue_free()
	await frames(1)


func test_scene_deeper_elsewhere_no_trip() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.open_vote()
	main.decide("deep")
	ok(not main.trip.active, "не у 10 — обычный следующий спуск, без кат-сцены")
	eq(main.run.depth, 1)
	main.queue_free()
	await frames(1)


## Часть 2в: в коопе шторка у гостя идёт за хостом; возвращение корабля у гостя не срабатывает.
func test_guest_follows_host_time() -> void:
	var host := DescentTrip.new()
	eq(host.pack(), -1.0, "нет шторки — −1")
	host.start()
	host.update(DescentTrip.SINK + 1.0)
	var g := DescentTrip.new()
	g.follow(host.pack())
	ok(g.active, "гость: шторка по времени хоста")
	near(g.alpha(), 1.0, 1e-4, "экран закрыт и у гостя")
	var got := []
	while g.active and got.size() < 200:
		got.append(g.update(0.1))
	ok(not got.has("arrive"), "у гостя корабль не возвращается — его приносит кадр хоста")
	g.follow(1.0)
	g.follow(-1.0)
	ok(not g.active, "у хоста шторки нет — у гостя тоже")
	eq(g.alpha(), 0.0)


func test_scene_guest_curtain_from_frame() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var host := DescentTrip.new()
	host.start()
	host.update(DescentTrip.SINK + 1.0)
	main.net_client = NetLink.Client.new()   # гость без сокета: кадры подаём сами
	var f := NetSnap.frame(5, main.time, main.helm, main.reactor, main.vitals, main.light_on, main.crew, {"d": host.pack()})
	main.net_game.client_frame(f)
	ok(main.trip.active, "кадр хоста с «d» — шторка у гостя")
	main.trip_view.apply(main.trip)
	ok(main.trip_view.shown(), "шторка на экране")
	var f2 := NetSnap.frame(6, main.time, main.helm, main.reactor, main.vitals, main.light_on, main.crew, {"d": -1.0})
	main.net_game.client_frame(f2)
	ok(not main.trip.active, "хост закончил — у гостя тоже")
	main.net_client = null
	main.queue_free()
	await frames(1)
