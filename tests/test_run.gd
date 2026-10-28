extends TestCase
## Маршрут забега (Run, js/run.js): выбор у голостола, точки по местам отмели, строка на приборах, отметка на голостоле.


func test_places_match_map() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var by_name := {}
	for l in data["locations"]:
		by_name[l["name"]] = Vector2(float(l["x"]), float(l["z"]))
	for k in Run.PLACES:
		if LayerMap.id_of(k) == "00" or not LayerMap.POINTS[LayerMap.id_of(k)]["accepted"]:
			continue   # старт и места слоя 1 (#829) — не ART-005, их сверяет test_layer_map
		ok(by_name.has(Run.place_name(k)), "место %s есть на карте" % k)
		eq(Run.place_xz(k), by_name[Run.place_name(k)], "место %s — по карте ART-005" % k)
	eq(Run.place_xz("geyser"), Reactor.VENT_POS, "курильщик там же, где перегрев")
	eq(Run.place_xz("drop"), Silt.DROP, "Край отмели там же, где оползни")
	for r in Run.ROUTES:
		for k in r["places"]:
			ok(Run.PLACES.has(k), "у маршрута %s места из списка" % r["id"])


func test_cycle_and_progress() -> void:
	var run := Run.new()
	eq(run.status(0, 0), "", "без маршрута строки нет")
	eq(run.waypoint(), Vector2.INF, "без маршрута отметки нет")
	eq(run.label(), "Маршрут: выбрать")
	var msg := run.cycle()
	eq(run.route, 0, "первое нажатие — первый маршрут")
	ok(msg.begins_with("Маршрут «Рифовый сад»: Каменный цветок, Кости левиафана, Световой колодец"), msg)
	ok(msg.ends_with("много серпохвостов"), "строка риска")
	eq(run.label(), "Маршрут: сменить")
	eq(run.waypoint(), Run.place_xz("flower"), "первая точка на голостоле")
	eq(run.status(40.0, 50.0), "Рифовый сад 0/3: Каменный цветок 100 м", "строка на приборах")
	eq(run.update(40.0, 0.0), "", "далеко — точка не пройдена")
	eq(run.update(40.0, -10.0), "Точка маршрута пройдена: Каменный цветок. Дальше — Кости левиафана")
	eq(run.update(40.0, -10.0), "", "сообщение один раз")
	eq(run.waypoint(), Run.place_xz("bones"))
	# по пути зашли в третью точку раньше второй — тоже засчитана, следующей остаётся вторая
	eq(run.update(-170.0, -70.0), "Точка маршрута пройдена: Световой колодец. Дальше — Кости левиафана")
	eq(run.update(-30.0, -148.0), "Маршрут «Рифовый сад» пройден: глубже или наверх?")
	ok(run.done, "маршрут закрыт")
	eq(run.waypoint(), Vector2.INF, "отметки больше нет")
	eq(run.status(0, 0), "маршрут «Рифовый сад» пройден")
	eq(run.update(40.0, -50.0), "", "закрытый маршрут молчит")
	run.cycle()
	eq(run.route, 1, "следующее нажатие — следующий маршрут")
	ok(not run.done and run.visited.is_empty(), "прогресс с нуля")
	run.cycle()
	run.cycle()
	eq(run.route, 0, "по кругу")


func test_scene_route_post() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var post := Deck.nearest(main.posts, Main.ROUTE_POST.x, Main.ROUTE_POST.y)
	eq(post.id, "route", "у правого борта голостола — пост «Маршрут»")
	eq(Deck.nearest(main.posts, 0.0, -2.6).id, "sonar", "с носа — сонар")
	eq(Deck.nearest(main.posts, 0.0, 0.2).id, "sonar", "с кормы — сонар")
	eq(Deck.nearest(main.posts, -1.4, -1.2).id, "sonar", "слева — сонар")
	eq(Deck.nearest(main.posts, 0.9, 0.0).id, "sonar", "где сценарий тестера даёт импульс — сонар")
	ok(Deck.can_stand(Main.ROUTE_POST.x, Main.ROUTE_POST.y), "у поста можно стоять")
	main.use_post("route")
	eq(main.run.route, 0, "нажатие выбрало маршрут")
	ok(main.message.text.begins_with("Маршрут «Рифовый сад»"), "на приборах — маршрут")
	main.step(1.0 / 30.0)
	eq(main.sonar_view.mat.get_shader_parameter("wp_on"), 1.0, "на голостоле — отметка точки")
	eq(main.sonar_view.mat.get_shader_parameter("wp_xz"), Run.place_xz("flower"))
	ok(Status.join(main.status_parts()).contains("Рифовый сад 0/3: Каменный цветок"), "строка маршрута на приборах")
	main.helm.pos = Vector3(40.0, main.helm.pos.y, -40.0)
	main.step(1.0 / 30.0)
	eq(main.run.visited, ["flower"] as Array[String], "корабль у Каменного цветка — точка пройдена")
	ok(main.message.text.begins_with("Точка маршрута пройдена"), main.message.text)
	eq(main.sonar_view.mat.get_shader_parameter("wp_xz"), Run.place_xz("bones"), "отметка — на следующей точке")
	main.queue_free()
	await frames(1)


func test_vote_and_finish() -> void:
	var run := Run.new()
	run.begin(100.0, 2, 3, 1)
	var ops := Run.opinions(80.0, 90.0, false, false, 1)
	eq(ops.size(), 4, "четыре роли")
	for o in ops:
		ok(not o[1], "всё в порядке — все за «глубже»: %s" % o[0])
	ops = Run.opinions(30.0, 20.0, false, true, 5)
	eq(ops[0][2], "корпус 30% — второй такой удар не выдержим")
	eq(ops[1][2], "энергии 20 — не хватит на обратный путь")
	ok(ops[2][1] and ops[3][1], "в иле и с полным трюмом — наверх")
	eq(Run.opinions(80.0, 90.0, true, false, 0)[1][2], "реактор перегрет")
	run.open_vote()
	eq(run.vote_nav(Vector2i(0, 1)), "", "крестовину держали с открытия — не голос")
	eq(run.vote_nav(Vector2i.ZERO), "")
	eq(run.vote_nav(Vector2i(0, -1)), "deep", "вниз — глубже")
	eq(run.vote_nav(Vector2i(0, -1)), "", "один голос за нажатие")
	run.choose(1)
	run.update(-126.0, 45.0)
	eq(run.update(162.0, -36.0), "Маршрут «Тёплые трубы» пройден: глубже или наверх?")
	eq(run.routes, 1)
	eq(run.label(), "Глубже или наверх?")
	eq(run.go_deeper(), "Глубже: 2-й спуск, хищники чутче на 15 %. Маршрут — у голостола")
	ok(run.route == -1 and not run.done, "маршрут выбирать заново")
	var rows := run.finish(100.0 + 7.0 * 60.0, 4, 5, 2, 64.0)
	ok(run.ended, "забег окончен")
	eq(rows[0], ["Время под водой", "7 мин"])
	eq(rows[1], ["Спусков", "2"])
	eq(rows[3], ["Новых видов в журнале", "2"])
	eq(rows[4], ["Образцов поднято", "2"])
	eq(rows[5], ["Пробоин", "1"])
	eq(rows[6], ["Корпус на финише", "64%"])
	eq(run.score, 2 * 10 + 2 * 5 + 20 + 25 + 6, "очки как в js/run.js без мест и улучшений")
	eq(run.summary(4, 5, 2), [["Образцы", "2"], ["Виды", "2"], ["Места", "2"], ["Пробоины", "1"]],
		"итог на голограмме: четыре строки за забег, места — «Тёплые трубы»")
	var d := Run.detail(rows)
	eq(d.size(), 4, "на панели — время, спуски, маршруты, корпус")
	eq(d[3], ["Корпус на финише", "64%"])
	run.begin(0.0, 0, 0, 0)
	ok(run.depth == 0 and run.routes == 0 and not run.ended and run.route == -1, "новый забег с нуля")
	eq(run.seen.size(), 0, "места нового забега — с нуля")


func test_places_seen_once() -> void:
	var run := Run.new()
	run.begin(0.0, 0, 0, 0)
	run.choose(0)   # «Рифовый сад»: цветок, кости, колодец
	for k in Run.ROUTES[0]["places"]:
		var p := Run.place_xz(k)
		run.update(p.x, p.y)
	eq(run.seen.size(), 3)
	run.go_deeper()
	run.choose(2)   # «Край отмели»: колодец уже был
	for k in Run.ROUTES[2]["places"]:
		var p := Run.place_xz(k)
		run.update(p.x, p.y)
	eq(run.seen.size(), 4, "колодец второй раз не считается")
	eq(run.summary(0, 0, 0)[2], ["Места", "4"])


func test_scene_vote() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.use_post("route")
	main.complete_route()
	ok(main.run.done, "маршрут пройден")
	main.step(1.0 / 30.0)
	eq(main.overlay.action_label, "Маршрут")
	main.use_post("route")
	ok(main.at_vote and main.vote_panel.visible, "у голостола — решение")
	eq(main.vote_panel.rows.size(), 4, "мнения четырёх ролей")
	var r := main.overlay.router
	var pad := r.layout.pad
	main.step(1.0 / 30.0)   # крестовину отпустили после открытия
	r.begin(1, pad.c + Vector2(0, pad.r * 0.7))   # вниз — глубже
	main.step(1.0 / 30.0)
	r.end(1)
	main.step(1.0 / 30.0)
	ok(not main.at_vote and not main.vote_panel.visible, "решили — панель закрыта")
	eq(main.run.depth, 1, "второй спуск")
	eq(main.run.route, -1, "маршрут заново")
	main.complete_route()
	main.vitals.hull = 70.0
	main.use_post("route")
	main.step(1.0 / 30.0)
	r.begin(1, pad.c - Vector2(0, pad.r * 0.7))   # вверх — наверх
	main.step(1.0 / 30.0)
	r.end(1)
	main.step(1.0 / 30.0)
	ok(main.run.ended and main.vote_panel.results, "наверх — итог забега")
	eq(main.vote_panel.sub, "Очки экспедиции: %d" % main.run.score)
	eq(main.overlay.action_label, "Дальше")
	main.helm.pos = Vector3(100.0, -30.0, 0.0)
	r.begin(2, r.layout.action.c)   # первое нажатие — с вида с борта к итогу на мостике
	main.step(1.0 / 30.0)
	r.end(2)
	main.step(1.0 / 30.0)
	ok(main.run.ended and not main.flyby.active(), "вид с борта пропущен, итог открыт")
	r.begin(2, r.layout.action.c)
	main.step(1.0 / 30.0)
	r.end(2)
	main.step(1.0 / 30.0)
	ok(not main.at_vote, "итог закрыт")
	ok(not main.run.ended and main.run.depth == 0, "новый забег")
	near(main.helm.pos.distance_to(Helm.Ship.START), 0.0, 0.5, "Ковчег у начала спуска")
	near(main.vitals.hull, Vitals.MAX, 1e-4, "корпус целый")
	main.queue_free()
	await frames(1)


func test_qa_logs_run() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var qa := main.start_qa('[{"do": "goto", "x": 1.6, "z": -1.2, "yaw": 90}, {"do": "press", "what": "action"}, ' +
		'{"do": "route"}, {"do": "press", "what": "action"}, {"do": "log", "note": "решение"}, ' +
		'{"do": "hold", "what": "pad", "dir": [0, -1], "s": 0.3}, {"do": "log", "note": "глубже"}]')
	for i in 60:
		main.step(1.0 / 30.0)
	var log := "\n".join(qa.log_lines)
	ok(log.contains("решение | ") and log.contains("маршрут «Рифовый сад» пройден · решение у голостола"), "в логе — решение")
	ok(log.contains("глубже | ") and log.contains("спуск 2"), "в логе — второй спуск")
	eq(main.run.depth, 1)
	main.queue_free()
	await frames(1)
