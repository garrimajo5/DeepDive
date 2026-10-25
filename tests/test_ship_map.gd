extends TestCase
## Схема корабля ART-042: раскладка плана по числам `ShipLayout`/`Deck`, люки, значки постов, отметки экипажа,
## тревога, вход из паузы и «Назад».

const SIZES: Array[Vector2] = [Vector2(2400, 1080), Vector2(2340, 1080), Vector2(1920, 1080), Vector2(1600, 720)]

var main: Main


func after() -> void:
	Main.menu = false
	Main.intro = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_scale_and_origin_by_art() -> void:
	near(ShipMap.plan_s(Vector2(2400, 1080)), 50.0, 1e-4, "2400 — 50 px/м")
	near(ShipMap.plan_s(Vector2(2340, 1080)), 50.0, 1e-4, "2340 — 50 px/м")
	near(ShipMap.plan_s(Vector2(1920, 1080)), 40.0, 1e-4, "16:9 — 40 px/м")
	near(ShipMap.plan_x0(Vector2(2400, 1080)), 450.0, 1e-4, "X0 = (W − 30·s)/2")
	var bridge := ShipMap.room_rect(ShipLayout.Room.BRIDGE, Vector2(2400, 1080))
	ok(bridge.is_equal_approx(Rect2(450, 270, 400, 500)), "мостик x −5…5, z −6…2 по формуле макета: %s" % bridge)
	var p := ShipMap.to_screen(Deck.posts()[2].at.x, Deck.posts()[2].at.y, Vector2(2400, 1080))
	ok(p.y < 520.0, "сканер (правый борт, +X) — выше оси")
	var half := ShipMap.to_screen(0.0, 0.0, Vector2(1200, 540))
	ok(half.is_equal_approx(ShipMap.to_screen(0.0, 0.0, Vector2(2400, 1080)) * 0.5), "масштаб H/1080")


func test_layout_fits_screens() -> void:
	for size in SIZES:
		var screen := Rect2(Vector2.ZERO, size)
		var plan := Rect2()
		for room in ShipMap.NAMES.size():
			var r := ShipMap.room_rect(room, size)
			ok(screen.encloses(r), "%s на экране %s" % [ShipMap.NAMES[room], size])
			plan = r if room == 0 else plan.merge(r)
			if room > 0:
				near(r.position.x, ShipMap.room_rect(room - 1, size).end.x, 0.01, "отсеки примыкают")
		var back := ShipMap.back_rect(size)
		ok(screen.encloses(back) and not back.intersects(plan), "«Назад» на экране и не на плане (%s)" % size)
		for i in ShipMap.LEGEND.size():
			var c := ShipMap.legend_at(i, size)
			ok(screen.has_point(c) and c.y > plan.end.y + ShipMap.ICON * ShipMap.k(size) * 0.5,
				"легенда под планом (%s)" % size)
		var ru := ShipMap.ruler(size)
		near((ru[1] - ru[0]).x, ShipMap.RULER_M * ShipMap.plan_s(size) * ShipMap.k(size), 0.01, "линейка — 5 м")


func test_posts_inside_rooms_and_cells() -> void:
	var size := Vector2(2400, 1080)
	var ids: Array = []
	for p: Array in ShipMap.posts():
		ids.append(p[0])
		var room := ShipLayout.room_at(p[1].y)
		ok(ShipMap.room_rect(room, size).encloses(ShipMap.icon_rect(p[1], size)), "значок «%s» внутри отсека" % p[0])
		ok(Rect2(0, 0, 512, 384).encloses(ShipMap.cell(p[0])), "ячейка атласа")
	eq(ids.size(), 8, "все восемь постов со значками")
	near(ShipMap.icon_rect(Vector2.ZERO, Vector2(1600, 720)).size.x, 32.0, 0.01, "значок 48 px макета на 720")
	eq(ShipMap.cell("weld"), Rect2(0, 256, 128, 128), "сварка — 0,2")


func test_doors_on_bulkheads() -> void:
	var size := Vector2(2400, 1080)
	for i in ShipLayout.DOOR_Z.size():
		var d := ShipMap.door_rect(i, size)
		near(d.size.y, ShipLayout.DOOR_HALF * 2.0 * 50.0, 0.01, "проём 1,4 м")
		near(d.get_center().y, 520.0, 0.01, "по оси корабля")
		var label := ShipMap.door_label(i, size)
		for room in ShipMap.NAMES.size():
			ok(not ShipMap.room_rect(room, size).has_point(label), "«Люк закрыт» под отсеками, не на плане")


func test_marks_own_first_and_spread() -> void:
	var size := Vector2(2400, 1080)
	var pts := [Vector2(0.0, -3.0), Vector2(0.1, -3.1), Vector2(0.0, 10.0), Vector2(-0.1, -2.9)]
	var ms := ShipMap.marks(pts, ["С", "П", "Б", "И"], 1, size)
	eq(ms.size(), 4, "все отметки")
	ok(ms[0].own and ms[0].letter == "П", "свой — первым")
	ok(ms[0].pos == ms[0].at, "свой — на настоящем месте")
	for a in ms:
		for b in ms:
			if a != b:
				ok(a.pos.distance_to(b.pos) >= ShipMap.MARK - 0.02, "кружки не налезают")
	for m in ms:
		ok(m.pos.distance_to(m.at) <= ShipMap.SPREAD + 0.01, "разнос не дальше 48 px")
	var solo := ShipMap.marks([Vector2(0.0, 5.0)], ["П"], 0, size)
	eq(solo.size(), 1, "соло — только своя отметка")
	eq(ShipMap.letter(Crew.Role.BIOLOGIST), "Б", "буква роли")


func test_alarm_targets() -> void:
	eq(ShipMap.alarm(-1, null), null, "нет тревог — нет цели")
	eq(ShipMap.alarm(AlarmBoard.Field.BREACH, null), null, "пробоина без места — нет цели")
	eq(ShipMap.alarm(AlarmBoard.Field.SILT, null), null, "ил — без места ремонта")
	var size := Vector2(2400, 1080)
	for s in Breach.spots():
		var a := ShipMap.alarm(AlarmBoard.Field.BREACH, s)
		eq(a.room, s.room, "отсек пробоины")
		eq(a.icon, "weld", "значок сварки")
		eq(a.lines[0], "Пробоина", "первая строка")
		ok(a.lines[1].ends_with("· сварка"), "вторая строка — отсек и сварка")
		ok(ShipMap.room_rect(s.room, size).encloses(ShipMap.alarm_box(a, size)), "рамка 64² внутри отсека")
		ok(Rect2(Vector2.ZERO, size).has_point(ShipMap.alarm_label(a, size)), "подпись на экране")
	var heat := ShipMap.alarm(AlarmBoard.Field.HEAT, null)
	ok(heat.room == ShipLayout.Room.ENGINE and heat.at == EngineRoom.VALVE_POST, "перегрев — вентиль в машинном")
	eq(ShipMap.alarm(AlarmBoard.Field.DRAIN, null).at, Zap.POST_AT, "стеклоуст — рычаг разряда")


func test_open_back_hit() -> void:
	var m := ShipMap.new()
	var size := Vector2(1600, 720)
	eq(m.hit(ShipMap.back_rect(size).get_center(), size), "", "закрытая схема касаний не берёт")
	m.open_from("pause")
	eq(m.hit(ShipMap.room_rect(0, size).get_center(), size), "", "касание плана ничего не делает")
	eq(m.hit(ShipMap.back_rect(size).get_center(), size), "back", "«Назад»")
	eq(m.back(), "pause", "назад — в паузу")
	ok(not m.open, "закрыта")


func test_pause_has_map_after_resume() -> void:
	eq(Pause.ITEMS[1][0], "map", "«Схема корабля» сразу после «Продолжить»")
	eq(Pause.GUEST_ITEMS[1][0], "map", "и в меню забега гостя")
	var p := Pause.new()
	p.back()
	eq(p.press("map"), "map", "пункт открывает схему")
	ok(p.open, "пауза под схемой открыта")


func _tap(r: Rect2, finger: int) -> void:
	var router := main.overlay.router
	router.begin(finger, r.get_center())
	main.step(1.0 / 30.0)
	router.end(finger)
	main.step(1.0 / 30.0)


func test_scene_map_from_pause_and_back() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var size := main.get_viewport().get_visible_rect().size
	main.open_breach(1)
	main.back_pressed()
	_tap(main.pause.rect("map", size), 1)
	ok(main.ship_map.open and main.ship_map_panel.visible, "схема на экране")
	ok(not main.pause_panel.visible, "кнопки паузы под схемой скрыты")
	ok(main.pause.open, "игра стоит — пауза под схемой")
	ok(not main.overlay.visible, "управление скрыто")
	eq(main.ship_map_panel.marks.size(), main.crew.size(), "отметки экипажа")
	eq(main.ship_map_panel.own, main.crew.find(main.me), "своя отметка")
	ok(main.ship_map_panel.alarm != null and main.ship_map_panel.alarm.room == ShipLayout.Room.CORRIDOR,
		"пробоина в коридоре — на схеме")
	eq(main.ship_map_panel.doors.size(), ShipLayout.DOOR_Z.size(), "люки")
	_tap(ShipMap.back_rect(size), 2)
	ok(not main.ship_map.open and not main.ship_map_panel.visible, "«Назад» закрыл схему")
	ok(main.pause.open and main.pause_panel.visible, "снова пауза")
	_tap(main.pause.rect("map", size), 3)
	main.back_pressed()
	ok(not main.ship_map.open and main.pause.open, "системная «Назад» — из схемы в паузу")
	_tap(main.pause.rect("map", size), 4)
	main._on_destroyed()
	ok(not main.ship_map.open and not main.ship_map_panel.visible, "шторка «Корпус разрушен» закрывает схему")
	await frames(1)
