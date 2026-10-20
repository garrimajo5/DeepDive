extends TestCase
## Маршрут забега (Run, js/run.js): выбор у голостола, точки по местам отмели, строка на приборах, отметка на голостоле.


func test_places_match_map() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var by_name := {}
	for l in data["locations"]:
		by_name[l["name"]] = Vector2(float(l["x"]), float(l["z"]))
	for k in Run.PLACES:
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
	ok(msg.begins_with("Маршрут «Рифовый сад»: Каменный цветок → Кости левиафана → Световой колодец"), msg)
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
