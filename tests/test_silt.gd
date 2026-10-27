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
	sonar.ping(10.0, 1.0, true)
	ok(sonar.jammed, "импульс в иле завяз")
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
	ok(main.silt_view.near_bow >= 60, "перед мостиком рой хлопьев (ART-048), а не пусто: %d" % main.silt_view.near_bow)
	var mi := main.silt_view.multimesh
	var inside := 0
	for i in mi.visible_instance_count:
		var p := main.silt_view.flake(i).origin
		if HullPlan.inside_world(p, main.helm.pos, main.helm.yaw):
			inside += 1
	eq(inside, 0, "внутри корабля ила нет")
	main.time += Sonar.COOLDOWN
	main.ping_sonar()
	ok(main.sonar.jammed, "импульс завяз")
	eq(main.message.text, Silt.JAM_MSG, "на приборах: сонар ослеп")
	main.step(1.0 / 30.0)
	eq(main.sonar_view.mat.get_shader_parameter("jam"), 1.0, "голограмма знает: кольцо вязнет")
	ok(float(main.sonar_view.mat.get_shader_parameter("noise")) > 0.9, "сильный след ряби")
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


## ART-048: ил серо-зелёный, не бурый.
func test_palette_grey_green() -> void:
	eq(Silt.COLOR, Color("#45584F"), "тёмный ил")
	eq(Silt.FLAKE_COLOR, Color("#728479"), "средние хлопья")
	for c in [Silt.COLOR, Silt.FLAKE_COLOR, Silt.EDGE_COLOR, Silt.FAR_COLOR]:
		ok(c.g >= c.r and c.g >= c.b, "зелёный преобладает: %s" % c.to_html(false))


## ART-048: пятна 0,10–0,40 м внутри карточки 1,6 м, рваная маска, крупные карточки — до 0,7 м.
func test_flake_mask() -> void:
	var spots := Silt.flake_spots()
	eq(spots.size(), Silt.SPOTS, "пятен в карточке")
	var biggest := 0.0
	for sp in spots:
		var d: float = sp["d"]
		ok(d >= Silt.SPOT_MIN - 1e-6 and d <= Silt.SPOT_MAX + 1e-6, "поперечник %.2f м" % d)
		var c: Vector2 = sp["c"]
		var m := d * 0.5 / Silt.CARD
		ok(c.x - m > 0.0 and c.x + m < 1.0 and c.y - m > 0.0 and c.y + m < 1.0, "пятно не за краем карточки")
		biggest = maxf(biggest, d)
	ok(biggest * SiltView.BIG_SCALE <= 0.71, "крупные ближние хлопья не больше 0,7 м")
	var img := Silt.flake_image(64)
	var cover := 0
	var semi := 0
	for y in 64:
		for x in 64:
			var a := img.get_pixel(x, y).a
			if a > 0.5:
				cover += 1
			elif a > 0.02:
				semi += 1
	var frac := cover / 4096.0
	ok(frac > 0.03 and frac < 0.35, "пятна, а не сплошная карточка: %.2f" % frac)
	ok(semi > 0, "края мягкие и рваные")
	eq(img.get_pixel(0, 0).a, 0.0, "угол карточки прозрачный")
	var big := 0
	for j in SiltView.PER_CLOUD:
		if SiltView.card_scale(j) > 1.5:
			big += 1
	ok(big > 20 and big < 50, "крупных карточек мало: %d" % big)


## Маска не плодит шейдер: ил и морской снег — один шейдер (issue #159).
func test_flakes_one_shader() -> void:
	var mask := ImageTexture.create_from_image(Silt.flake_image(16))
	eq(ShaderKey.of(ShaderKey.flakes(Color.WHITE, mask)), ShaderKey.of(ShaderKey.flakes(Color.RED)), "ключ шейдера тот же")


## ART-048: завязший импульс не обновляет отметки — старые гаснут, как гасли, не прыгают; дальность прежняя.
func test_jam_keeps_old_blips_fading() -> void:
	var sonar := Sonar.new()
	sonar.ping(0.0, 1.0)
	sonar.take_contacts([EcoLink.near("svetlyak", "светляк", Vector3(5, 0, 5), Vector3.ZERO)], Vector3.ZERO)
	eq(sonar.blips.size(), 1, "отметка до ила")
	var before := sonar.blip_alpha(6.0)
	sonar.ping(6.0, 0.5, true)
	eq(sonar.blips.size(), 1, "старая отметка не пропала")
	near(sonar.blip_alpha(6.0), before, 1e-6, "яркость не прыгнула")
	near(sonar.blip_alpha(12.0), 0.0, 1e-6, "гаснет к 12 с от своего импульса")
	near(sonar.range_m, Sonar.BASE_RANGE, 1e-6, "дальность круга прежняя")
	sonar.take_contacts([EcoLink.near("veil", "вуаль", Vector3(9, 0, 1), Vector3.ZERO)], Vector3.ZERO)
	eq(sonar.blips.size(), 1, "новых отметок нет")
	sonar.ping(10.0, 1.0)
	eq(sonar.blips.size(), 0, "чистый импульс после выхода снимает заново")
	near(sonar.blip_alpha(10.0), 1.0, 1e-6, "новые отметки ярки")


## Рой у носа стоит в мире: корабль сдвинулся — точки на месте, ушедшие за окно переносятся вперёд.
func test_bow_swarm_wraps() -> void:
	var v := SiltView.wrap_box(Vector3(13.0, -6.0, 0.0))
	near(v.x, 13.0 - SiltView.LOCAL_BOX.x, 1e-4, "за правым краем — к левому")
	near(v.y, -6.0 + SiltView.LOCAL_BOX.y, 1e-4, "под низом — наверх")
	var sv := SiltView.new()
	var s := Silt.new()
	s.spawn(Vector3.ZERO, Silt.SCRAPE_R, Silt.SCRAPE_LIFE, "scrape").life = 30.0
	for i in 30:
		s.update(0.1, Vector3.ZERO, Vector3.ZERO)
	sv.apply(s, 0.0, Vector3.ZERO, 0.0)
	var a := sv.flake(0).origin
	sv.apply(s, 0.0, Vector3(0.0, 0.0, -0.5), 0.0)
	near(sv.flake(0).origin.distance_to(a), 0.0, 1e-4, "хлопок не едет с кораблём")
	s.reset()
	sv.apply(s, 0.0, Vector3.ZERO, 0.0)
	eq(sv.shown, 0, "ила нет — хлопьев нет")
	sv.free()


## #847: хлопья уходят одним буфером, а не 900 вызовами; без ила — ни одной записи за кадр.
func test_flakes_one_buffer_and_idle_without_silt() -> void:
	var sv := SiltView.new()
	var s := Silt.new()
	sv.apply(s, 0.0, Vector3.ZERO, 0.0)
	sv.apply(s, 0.1, Vector3.ZERO, 0.0)
	eq(sv.writes, 0, "ила нет — буфер не отправляется")
	s.spawn(Vector3(0, 0, -40), Silt.SCRAPE_R, Silt.SCRAPE_LIFE, "scrape").life = 30.0
	for i in 30:
		s.update(0.1, Vector3.ZERO, Vector3.ZERO)
	sv.apply(s, 1.0, Vector3(500, 0, 500), 0.0)   # корабль далеко: ни один хлопок не пропущен, j-й — j-я карточка
	eq(sv.writes, 1, "один вызов на кадр")
	ok(sv.shown > 0, "хлопья есть")
	var j := 8   # каждая девятая — крупная
	var tr := sv.flake(j)
	near(tr.basis.x.x, SiltView.card_scale(j), 1e-5, "масштаб карточки в буфере")
	near(tr.basis.x.y, 0.0, 1e-6, "без поворота")
	s.reset()
	sv.apply(s, 2.0, Vector3.ZERO, 0.0)
	ok(not sv.visible and sv.shown == 0, "ил осел — скрыт")
	sv.apply(s, 2.1, Vector3.ZERO, 0.0)
	eq(sv.writes, 1, "и больше не пишет")
	sv.free()
