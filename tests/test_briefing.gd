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
	eq(Briefing.ORDER.size(), 11, "все 11 мест слоя 1 (#829)")
	eq(Briefing.ORDER, Array(Run.PLACES.keys()), "порядок шейдера — как Run.PLACES")
	for k: String in Briefing.ORDER:
		eq(Briefing.NUMBERS[k], int(LayerMap.id_of(k)), "номер места %s — по карте слоя" % k)
	var src := FileAccess.get_file_as_string("res://shaders/sonar_holo.gdshader")
	ok(src.contains("places[%d]" % Briefing.ORDER.size()) and src.contains("place_state[%d]" % Briefing.ORDER.size())
		and src.contains("i < %d;" % Briefing.ORDER.size()), "шейдер держит все места")


## #829: места слоя 1 на столе не налезают иконками друг на друга (по горизонтали стола, с запасом на номер).
func test_places_apart_on_table() -> void:
	for a: String in Briefing.ORDER:
		for b: String in Briefing.ORDER:
			if a < b:
				var d := Briefing.table_xz(Run.place_xz(a)).distance_to(Briefing.table_xz(Run.place_xz(b)))
				ok(d >= Briefing.ICON_SIZE, "%s и %s дальше иконки на столе (%.3f м)" % [a, b, d])


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
	eq(Array(SonarView.place_states(run)), [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"без маршрута — все тусклые")
	run.choose(0)
	run.update(40.0, -50.0)   # Каменный цветок пройден
	# порядок ORDER: flower, geyser, shell, bones, well, drop, start, gate, field, cove, descent
	eq(Array(SonarView.place_states(run)), [2.0, 0.0, 0.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"пройдено, следующая, на маршруте; места слоя 1 вне маршрутов — тусклые")


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
	main.run.open_vote()   # в слое голосование откроет переход у 10 (#828)
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
	eq(sv.icons.size(), 11, "иконки всех 11 мест слоя 1 (#829)")
	eq(sv.numbers[Briefing.ORDER.find("descent")].text, "10", "спуск к лесу — «10»")
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


func test_card_lines() -> void:
	eq(Briefing.card_lines(-1).size(), 0, "маршрут не выбран — карточки нет")
	var l := Briefing.card_lines(0)
	eq(l[0], "Рифовый сад", "название")
	eq(l.slice(1, 4), ["1  Каменный цветок", "4  Кости левиафана", "5  Световой колодец"], "места по порядку с номерами карты")
	eq(l[4], "Риск: много серпохвостов", "одна строка риска — последняя")
	eq(Briefing.card_lines(1).size(), 4, "«Тёплые трубы»: два места")
	eq(Briefing.RISK_COLOR, Color("F1A23D"), "риск янтарным, как в ART-016")


func test_card_rect() -> void:
	var scr := Vector2(1600, 720)
	var sz := Vector2(300, 170)
	var r := Briefing.card_rect(Vector2(1000, 240), sz, scr)
	eq(r.position, Vector2(1000 + Briefing.CARD_GAP, 155), "справа от точки, по её высоте")
	r = Briefing.card_rect(Vector2(1500, 240), sz, scr)
	ok(r.end.x <= scr.x - Briefing.CARD_RIGHT_FREE, "не заходит на кнопку действия")
	r = Briefing.card_rect(Vector2(500, 20), sz, scr)
	eq(r.position.y, Briefing.CARD_TOP_FREE, "не закрывает строки приборов")
	r = Briefing.card_rect(Vector2(500, 710), sz, scr)
	eq(r.end.y, scr.y - Briefing.CARD_MARGIN, "не уходит под нижний край")
	r = Briefing.card_rect(Vector2(-400, 300), sz, scr)
	eq(r.position.x, Briefing.CARD_MARGIN, "не уходит за левый край")


## #913: карточка встаёт мимо карты на экране — справа от неё, но не дальше кнопки действия.
func test_card_rect_beside_map() -> void:
	var scr := Vector2(1600, 720)
	var sz := Vector2(330, 300)
	var map := Rect2(575, 150, 400, 180)
	var r := Briefing.card_rect(Vector2(800, 240), sz, scr, map)
	eq(r.position.x, map.end.x + Briefing.CARD_GAP, "точка над картой — карточка правее карты")
	ok(not r.intersects(map), "карту не закрывает")
	map = Rect2(575, 150, 600, 180)
	r = Briefing.card_rect(Vector2(800, 240), sz, scr, map)
	eq(r.end.x, scr.x - Briefing.CARD_RIGHT_FREE, "справа места мало — у правого предела, не на кнопке действия")
	eq(Briefing.map_points().size(), 8, "углы карты на столе и на высоте номеров")


## #913: с точки сценария 09c-route карточка «Рифового сада» закрывала места 4, 7, 8 на голостоле.
func test_scene_card_clear_of_places() -> void:
	var was := tree.root.size
	tree.root.size = Vector2i(1600, 720)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.walker.x = 1.6
	main.walker.z = -1.2
	main.walker.yaw = PI / 2.0
	main.walker.pitch = deg_to_rad(-38.0)
	main.run.choose(0)
	main.step(0.5)
	await frames(1)
	ok(main.route_card.visible, "карточка видна")
	var cam := main.get_viewport().get_camera_3d()
	var sv := main.sonar_view
	for i in Briefing.ORDER.size():
		var k := Briefing.ORDER[i]
		var ico := _screen_rect(cam, sv.icons[i].global_position, Vector2.ONE * Briefing.ICON_SIZE * 0.35)
		var l := sv.numbers[i]
		var c := l.global_position + (cam.global_basis.x * l.offset.x + cam.global_basis.y * l.offset.y) * l.pixel_size
		var num := _screen_rect(cam, c, Vector2(0.4, 0.5) * l.font_size * l.pixel_size * 0.6)
		ok(not main.route_card.rect.intersects(ico), "иконка места %d не под карточкой: %s / %s" % [Briefing.NUMBERS[k],
			ico, main.route_card.rect])
		ok(not main.route_card.rect.intersects(num), "номер места %d не под карточкой" % Briefing.NUMBERS[k])
	ok(Rect2(Vector2.ZERO, Vector2(1600, 720)).encloses(main.route_card.rect), "карточка на экране")
	main.queue_free()
	tree.root.size = was
	await frames(1)


func test_scene_route_card() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.step(0.3)
	ok(not main.route_card.visible, "у входа карточки нет")
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.walker.yaw = PI / 2   # лицом к голостолу (−X)
	main.walker.pitch = -0.5
	main.run.choose(2)
	main.step(0.3)
	main.step(0.05)
	ok(main.route_card.visible, "у поста «Маршрут» — карточка выбранного маршрута")
	eq(main.route_card.lines[0], "Край отмели")
	near(main.route_card.alpha, 1.0, 1e-5, "переход закончен — карточка непрозрачна")
	var scr := main.get_viewport().get_visible_rect().size
	ok(Rect2(Vector2.ZERO, scr).encloses(main.route_card.rect), "карточка на экране")
	main.walker.yaw = -PI / 2   # отвернулся — точка привязки за спиной
	main.step(0.05)
	ok(not main.route_card.visible, "точка за спиной — карточки нет")
	main.walker.yaw = PI / 2
	main.complete_route()
	main.run.open_vote()   # в слое голосование откроет переход у 10 (#828)
	main.use_post("route")   # голосование — брифинг гаснет
	main.step(0.3)
	ok(not main.route_card.visible, "в голосовании карточки нет")
	main.queue_free()
	await frames(1)


## Прямоугольник билборда на экране: центр c (мир), полуразмеры h (м) по осям камеры.
func _screen_rect(cam: Camera3D, c: Vector3, h: Vector2) -> Rect2:
	var a := cam.unproject_position(c - cam.global_basis.x * h.x - cam.global_basis.y * h.y)
	var b := cam.unproject_position(c + cam.global_basis.x * h.x + cam.global_basis.y * h.y)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## #194: с точки сценария 09c-route номер «1» ложился на иконку места 3 (и «3» — на иконку 1).
func test_scene_numbers_clear_of_icons() -> void:
	var was := tree.root.size
	tree.root.size = Vector2i(1600, 720)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.walker.x = 1.6
	main.walker.z = -1.2
	main.walker.yaw = PI / 2.0
	main.walker.pitch = deg_to_rad(-38.0)
	main.run.choose(0)
	main.step(0.5)
	await frames(1)
	var cam := main.get_viewport().get_camera_3d()
	var sv := main.sonar_view
	var num := {}
	var ico := {}
	for i in Briefing.ORDER.size():
		var k := Briefing.ORDER[i]
		var l := sv.numbers[i]
		var c := l.global_position + (cam.global_basis.x * l.offset.x + cam.global_basis.y * l.offset.y) * l.pixel_size
		num[k] = _screen_rect(cam, c, Vector2(0.4, 0.5) * l.font_size * l.pixel_size * 0.6)
		ico[k] = _screen_rect(cam, sv.icons[i].global_position, Vector2.ONE * Briefing.ICON_SIZE * 0.35)
	for pair in [["flower", "shell"], ["shell", "flower"]]:
		ok(not num[pair[0]].intersects(ico[pair[1]]), "номер %d не на иконке %d: %s / %s" % [Briefing.NUMBERS[pair[0]],
			Briefing.NUMBERS[pair[1]], num[pair[0]], ico[pair[1]]])
	ok(not num["flower"].grow(4.0).intersects(num["shell"]), "номера 1 и 3 не теснятся")
	main.queue_free()
	tree.root.size = was
	await frames(1)


## #829: с точки сценария 09c-route дальний ряд мест (5, 8, 2, 9) читался плохо — номера мельче ближних втрое, «5» пряталась
## за иконками ближних мест. Дальние номера крупнее (Briefing.number_scale): каждый не ниже NUMBER_MIN_PX на экране,
## номера не налезают друг на друга и не уходят
## под иконки мест ближе к посту.
func test_scene_far_numbers_readable() -> void:
	var was := tree.root.size
	tree.root.size = Vector2i(1600, 720)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.walker.x = 1.6
	main.walker.z = -1.2
	main.walker.yaw = PI / 2.0
	main.walker.pitch = deg_to_rad(-38.0)
	main.run.choose(0)
	main.step(0.5)
	await frames(1)
	var cam := main.get_viewport().get_camera_3d()
	var sv := main.sonar_view
	var num := {}
	var ico := {}
	for i in Briefing.ORDER.size():
		var k := Briefing.ORDER[i]
		var l := sv.numbers[i]
		var c := l.global_position + (cam.global_basis.x * l.offset.x + cam.global_basis.y * l.offset.y) * l.pixel_size
		num[k] = _screen_rect(cam, c, Vector2(0.4 * l.text.length(), 0.5) * l.font_size * l.pixel_size * 0.6)
		ico[k] = _screen_rect(cam, sv.icons[i].global_position, Vector2.ONE * Briefing.ICON_SIZE * 0.35)
	for k in Briefing.ORDER:
		var h: float = num[k].size.y
		ok(h >= Briefing.NUMBER_MIN_PX, "номер %d не мельче %d px: %.1f" % [Briefing.NUMBERS[k], Briefing.NUMBER_MIN_PX, h])
		for o in Briefing.ORDER:
			if o == k:
				continue
			if Run.place_xz(o).x > Run.place_xz(k).x:   # ближняя к посту иконка закрыла бы номер (дальнюю номер перекрывает сам)
				ok(not num[k].intersects(ico[o]), "номер %d не под иконкой %d" % [Briefing.NUMBERS[k], Briefing.NUMBERS[o]])
			if Briefing.ORDER.find(o) > Briefing.ORDER.find(k):
				ok(not num[k].intersects(num[o]), "номера %d и %d не налезают" % [Briefing.NUMBERS[k], Briefing.NUMBERS[o]])
	main.queue_free()
	tree.root.size = was
	await frames(1)


func test_number_scale() -> void:
	near(Briefing.number_scale(Vector2(Briefing.SIDE * 0.5, 0.0)), 1.0, 1e-6, "ближний край стола — как было")
	near(Briefing.number_scale(Vector2(-Briefing.SIDE * 0.5, 0.0)), 1.0 + Briefing.NUMBER_GROW, 1e-6, "дальний — крупнее")
	ok(Briefing.number_scale(Vector2(-0.2, 0.0)) > Briefing.number_scale(Vector2(0.2, 0.0)), "чем дальше от поста, тем крупнее")


## ART-040: страница «Связь» карточки брифинга — кодовое слово забега.
func test_code_lines() -> void:
	eq(Briefing.code_lines("").size(), 0, "слова нет — страницы нет")
	eq(Briefing.code_lines("  ").size(), 0)
	var l := Briefing.code_lines("Иней")
	eq(l, [Briefing.CODE_TITLE, "Иней", Briefing.CODE_HINT[0], Briefing.CODE_HINT[1], Briefing.CODE_NOTE],
		"заголовок, слово, подсказка в две строки, примечание")
	eq(l.size(), RouteCard.CODE_PX.size(), "кегль на каждую строку")
	eq(RouteCard.CODE_ROW.size(), RouteCard.CODE_PX.size())
	for px in RouteCard.CODE_PX:
		ok(px >= 18, "экранный кегль не меньше 18 px (ART-016)")


func test_scene_code_on_briefing() -> void:
	var was := tree.root.size
	tree.root.size = Vector2i(1600, 720)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.walker.yaw = PI / 2
	main.walker.pitch = -0.5
	main.step(0.3)
	main.step(0.05)
	ok(main.run.route < 0, "маршрут ещё не выбран")
	ok(main.route_card.visible, "у голостола — карточка со словом, даже без маршрута")
	eq(main.route_card.lines.size(), 0, "строк маршрута нет")
	eq(main.route_card.code[1], main.comms.code, "кодовое слово забега — то же, что проверяет связь")
	var only := main.route_card.rect
	main.run.choose(0)
	main.step(0.05)
	eq(main.route_card.lines[0], "Рифовый сад", "маршрут выбран — сверху маршрут")
	eq(main.route_card.code[1], main.comms.code, "под ним — страница «Связь»")
	ok(main.route_card.rect.size.y > only.size.y + 100.0, "карточка выросла на строки маршрута")
	var scr := main.get_viewport().get_visible_rect().size
	ok(Rect2(Vector2.ZERO, scr).encloses(main.route_card.rect), "вся карточка на экране 1600 × 720")
	ok(main.route_card.rect.end.x <= scr.x - Briefing.CARD_RIGHT_FREE, "не заходит на кнопку действия")
	main.comms.reset_run(7)
	main.step(0.05)
	eq(main.route_card.code[1], main.comms.code, "новый забег — новое слово на карточке")
	main.walker.x = 0.0
	main.walker.z = 1.5
	main.step(0.5)
	ok(not main.route_card.visible, "отошёл от поста — карточки нет")
	main.queue_free()
	await frames(1)
	tree.root.size = was
