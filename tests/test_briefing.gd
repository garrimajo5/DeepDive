extends TestCase
## Голограмма брифинга по ART-016 (Briefing): карта отмели над голостолом у поста «Маршрут», места и линии маршрутов.


func test_scale_and_places() -> void:
	near(Briefing.SCALE, 1.13 / 700.0, 1e-9, "700 м во вписанный квадрат 1,13 м")
	near(Briefing.table_xz(Vector2(350, -350)).x, 0.565, 1e-6, "край карты — на краю квадрата")
	eq(Briefing.table_xz(Vector2(0, -100)).y < 0.0, true, "нос (−Z) — вверх, к носу стола")
	for k in Run.PLACES:
		ok(Briefing.NUMBERS.has(k) and Briefing.ORDER.has(k), "у места %s есть номер" % k)
		var t := Briefing.table_xz(Run.place_xz(k))
		ok(absf(t.x) < Briefing.SIDE / 2 and absf(t.y) < Briefing.SIDE / 2, "место %s на карте стола" % k)
	eq(Briefing.NUMBERS["bones"], 4, "номера — по таблице ART-016")
	eq(Briefing.ORDER.size(), 6)


func test_segments_follow_routes() -> void:
	var segs := Briefing.segments()
	eq(segs.size(), 4, "1→4→5, 2→3, 5→6")
	ok(segs.size() <= Briefing.MAX_SEGS, "шейдер держит все отрезки")
	eq(segs[0]["route"], 0)
	eq(segs[0]["a"], Briefing.table_xz(Run.place_xz("flower")))
	eq(segs[1]["b"], Briefing.table_xz(Run.place_xz("well")))
	near(segs[1]["start"], (segs[0]["a"] as Vector2).distance_to(segs[0]["b"]), 1e-6, "путь от начала маршрута")
	eq(segs[2]["start"], 0.0, "новый маршрут — с нуля")
	eq(segs[3]["route"], 2)
	near(Briefing.route_length(1), Briefing.table_xz(Run.place_xz("geyser")).distance_to(
		Briefing.table_xz(Run.place_xz("shell"))), 1e-6)
	eq([Briefing.dash(0), Briefing.dash(1), Briefing.dash(2)], [Briefing.Dash.SOLID, Briefing.Dash.LONG,
		Briefing.Dash.DOTS], "тип линии — по маршруту")


func test_wanted_and_fade() -> void:
	ok(Briefing.wanted("route", false, false), "у поста «Маршрут» — брифинг")
	ok(not Briefing.wanted("sonar", false, false), "у сонара — сонар")
	ok(not Briefing.wanted("route", true, false), "в голосовании — нет")
	ok(not Briefing.wanted("route", false, true), "забег окончен — нет")
	var f := Briefing.Fade.new()
	near(f.update(0.1, true), 0.4, 1e-6, "переход 0,25 с")
	eq(f.update(0.5, true), 1.0)
	near(f.update(0.125, false), 0.5, 1e-6)
	eq(f.update(1.0, false), 0.0)


func test_place_states() -> void:
	var run := Run.new()
	eq(Array(SonarView.place_states(run)), [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "без маршрута — все тусклые")
	run.choose(0)
	run.update(40.0, -50.0)   # Каменный цветок пройден
	# порядок ORDER: flower, geyser, shell, bones, well, drop
	eq(Array(SonarView.place_states(run)), [2.0, 0.0, 0.0, 3.0, 1.0, 0.0], "пройдено, следующая, на маршруте")


func test_scene_briefing_at_route_post() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var mat := main.sonar_view.mat
	main.step(0.5)
	eq(mat.get_shader_parameter("brief_k"), 0.0, "у входа — сонар")
	ok(not main.sonar_view.numbers[0].visible, "номера мест скрыты")
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.step(0.1)
	eq(main.near_post, "route")
	near(mat.get_shader_parameter("brief_k"), 0.4, 1e-4, "переход начался")
	main.step(0.2)
	eq(mat.get_shader_parameter("brief_k"), 1.0, "брифинг на голостоле")
	ok(main.sonar_view.numbers[3].visible, "номера мест видны")
	eq(main.sonar_view.numbers[3].text, "4")
	main.use_post("route")
	main.step(0.05)
	eq(mat.get_shader_parameter("sel_route"), 0, "выбранный маршрут ярче")
	near(mat.get_shader_parameter("route_len"), Briefing.route_length(0), 1e-4)
	main.complete_route()
	main.use_post("route")   # маршрут пройден — голосование
	ok(main.at_vote)
	main.step(0.3)
	eq(mat.get_shader_parameter("brief_k"), 0.0, "в голосовании брифинг гаснет")
	main.queue_free()
	await frames(1)


func test_icons() -> void:
	for k in Briefing.ORDER:
		var tex: Texture2D = load(Briefing.icon_path(k))
		ok(tex != null, "иконка места %s есть в игре" % k)
		if tex:
			eq(tex.get_size(), Vector2(256, 256), "иконка %s — 256 × 256 (ART-005)" % k)
	eq(Briefing.icon_alpha(0.0), Briefing.ICON_DIM, "место не на маршруте — тусклое")
	eq(Briefing.icon_alpha(3.0), 1.0, "следующая точка — ярко")


func test_scene_icons() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var sv := main.sonar_view
	eq(sv.icons.size(), 6, "шесть иконок мест")
	ok(not sv.icons[0].visible, "вне брифинга иконки скрыты")
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.use_post("route")   # «Рифовый сад»: 1 → 4 → 5
	main.step(0.3)
	ok(sv.icons[0].visible, "у поста «Маршрут» иконки видны")
	eq(sv.icons[0].modulate.a, 1.0, "место маршрута — ярко")
	near(sv.icons[1].modulate.a, Briefing.ICON_DIM, 1e-5, "курильщик не на маршруте — тусклый")
	var t := Briefing.table_xz(Run.place_xz("bones"))
	near(sv.icons[3].position.x, t.x, 1e-5, "иконка стоит на точке места")
	near(sv.icons[3].position.z, t.y, 1e-5)
	near(sv.icons[3].pixel_size * 256.0, Briefing.ICON_SIZE, 1e-6, "размер на столе")
	main.queue_free()
	await frames(1)
