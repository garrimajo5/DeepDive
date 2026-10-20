extends TestCase
## Сонарная тьма (Silt, js/silt.js): облако ила от удара о дно и оползня у Края отмели, дрейф, оседание, сонар
## вязнет в иле, луч короче, табло тревог одной строкой.


func test_scrape_raises_cloud_and_enters() -> void:
	var s := Silt.new()
	var ship := Vector3(10.0, -20.0, 5.0)
	s.on_scrape(ship, -40.0)
	eq(s.clouds.size(), 1, "удар о дно — облако")
	near(s.clouds[0].c.y, -22.0, 1e-4, "на 2 м ниже корабля")
	eq(s.update(0.1, ship, Vector3.ZERO), Silt.ENTER_MSG, "вошли в ил — сообщение")
	eq(s.update(0.1, ship, Vector3.ZERO), "", "сообщение один раз")
	eq(s.alarm(), Silt.ALARM, "табло: сонарная тьма")
	s.on_scrape(ship, -40.0)
	eq(s.clouds.size(), 1, "второй удар в той же туче — она густеет, новой нет")
	near(s.clouds[0].life, Silt.SCRAPE_LIFE, 1e-4, "жизнь снова полная")


func test_cloud_floor_and_limit() -> void:
	var s := Silt.new()
	s.on_scrape(Vector3(0.0, -38.0, 0.0), -40.0)
	near(s.clouds[0].c.y, -37.0, 1e-4, "не ниже 3 м над дном")
	for i in 4:
		s.spawn(Vector3(100.0 * i, 0.0, 0.0), 10.0, 20.0, "test")
	eq(s.clouds.size(), Silt.MAX_CLOUDS, "не больше трёх облаков")
	near(s.clouds[0].c.x, 100.0, 1e-4, "старое ушло первым")


func test_drift_settle_and_leave() -> void:
	var s := Silt.new()
	var cl := s.spawn(Vector3.ZERO, Silt.SCRAPE_R, Silt.SCRAPE_LIFE, "scrape")
	var cur := Vector3(0.3, 0.0, 0.0)
	for i in 100:
		s.update(0.1, Vector3(50.0, 0.0, 0.0), cur)
	near(cl.c.x, 0.3 * Silt.DRIFT * 10.0, 1e-3, "несёт течением")
	near(cl.c.y, -Silt.SINK * 10.0, 1e-3, "оседает")
	ok(s.inside == null, "корабль далеко — не в иле")
	for i in 400:
		s.update(0.1, Vector3.ZERO, Vector3.ZERO)
	eq(s.clouds.size(), 0, "облако осело")
	ok(s.k < 0.01 and s.alarm().is_empty(), "тьма кончилась")


func test_slide_at_drop() -> void:
	var s := Silt.new()
	var msg := s.update(Silt.SLIDE_FIRST - 1.0, Vector3.ZERO, Vector3.ZERO)
	eq(s.clouds.size(), 0, "оползня ещё нет")
	msg = s.update(1.0, Vector3.ZERO, Vector3.ZERO)
	eq(msg, Silt.SLIDE_MSG, "оползень у Края отмели")
	eq(s.clouds[0].why, "slide", "облако оползня")
	near(Vector2(s.clouds[0].c.x, s.clouds[0].c.z).distance_to(Silt.DROP), 0.0, 1e-3, "у Края отмели")
	ok(s.clouds[0].c.y >= -55.1 and s.clouds[0].c.y > Seabed.height(Silt.DROP.x, Silt.DROP.y), "над дном, не глубже 55 м")
	near(s.slide_t, Silt.SLIDE_PERIOD, 1e-4, "следующий через 5 минут")


func test_sonar_jam_beam_and_noise() -> void:
	var s := Silt.new()
	ok(not s.jam_ping(1.0), "без ила импульс чистый")
	near(s.beam_k(), 1.0, 1e-6, "луч полный")
	s.spawn(Vector3.ZERO, Silt.SCRAPE_R, Silt.SCRAPE_LIFE, "scrape").life = 30.0
	for i in 60:
		s.update(0.1, Vector3.ZERO, Vector3.ZERO)
	ok(s.k > 0.99, "корабль в иле")
	near(s.beam_k(), Silt.BEAM_K, 0.01, "луч короче в 0,45 раза")
	ok(s.jam_ping(10.0), "импульс вяз в иле")
	near(s.noise(11.0), 1.0, 1e-6, "помехи на голостоле")
	var sonar := Sonar.new()
	sonar.ping(10.0, 1.0)
	sonar.jammed = true
	sonar.take_contacts([EcoLink.near("svetlyak", "светляк", Vector3(5, 0, 5), Vector3.ZERO)], Vector3.ZERO)
	eq(sonar.blips.size(), 0, "отметок нет")
	sonar.ping(14.0, 1.0)
	ok(not sonar.jammed, "новый импульс — снова чистый")


func test_alarm_one_line() -> void:
	eq(Status.alarm(["", "ПЕРЕГРЕВ", Silt.ALARM]), "ПЕРЕГРЕВ", "реактор важнее ила")
	eq(Status.alarm(["ПРОБОИНА", "ПЕРЕГРЕВ"]), "ПРОБОИНА", "пробоина важнее всего")
	eq(Status.alarm(["", ""]), "", "тревог нет")


func test_scene_silt_blinds_sonar() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.vitals.hit_taken.emit(3, "scrape")
	eq(main.silt.clouds.size(), 1, "удар о дно в сцене поднимает ил")
	main.silt.reset()
	main.open_silt()
	main.step(1.0 / 30.0)
	ok(main.silt.inside != null, "корабль в облаке")
	ok(main.status_parts()[0] == Silt.ALARM, "табло тревог — первой частью строки")
	ok(main.silt_view.shown > 0, "хлопья ила видны")
	var mi := main.silt_view.multimesh
	var inside := 0
	for i in mi.visible_instance_count:
		var p := mi.get_instance_transform(i).origin
		if HullPlan.inside_world(p, main.helm.pos, main.helm.yaw):
			inside += 1
	eq(inside, 0, "внутри корабля ила нет")
	main.time += Sonar.COOLDOWN
	main.ping_sonar()
	ok(main.sonar.jammed, "импульс завяз")
	eq(main.message.text, Silt.JAM_MSG, "на приборах: сонар ослеп")
	main.step(1.0 / 30.0)
	eq(main.sonar.blips.size(), 0, "отметок нет")
	var full := Searchlight.range_m(main.reactor.k(Reactor.Sys.LAMP))
	near(main.eco_ship.light_range, full * main.silt.beam_k(), 1e-3, "существа видят свет ближе")
	ok(main.eco_ship.light_range < full * 0.6, "луч в иле короче")
	main.silt.reset()
	main.step(1.0 / 30.0)
	ok(not main.status_parts()[0].begins_with("СОНАРНАЯ"), "ил ушёл — тревоги нет")
	main.queue_free()
	await frames(1)
