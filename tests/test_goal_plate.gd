extends TestCase
## Плашка цели маршрута за штурвалом (#1344): угол и стрелка по курсу и пеленгу, переход через 0°/360°, «на месте»
## 2 с, нет маршрута, решение у стола; место между строкой приборов и noclip; в сцене — видна сидя, без строки маршрута
## в приборах, скрыта, когда игрок встал.

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_delta_by_course_and_bearing() -> void:
	var o := Vector2.ZERO
	near(GoalPlate.delta(0.0, o, Vector2(0, -100)), 0.0, 1e-4, "нос в −Z, цель впереди — прямо")
	near(GoalPlate.delta(0.0, o, Vector2(-100, 0)), 90.0, 1e-4, "цель в −X (левый борт) — левее на 90°")
	near(GoalPlate.delta(0.0, o, Vector2(100, 0)), -90.0, 1e-4, "цель у правого борта — правее")
	near(absf(GoalPlate.delta(0.0, o, Vector2(0, 100))), 180.0, 1e-4, "цель за кормой — 180°")
	near(GoalPlate.delta(PI * 0.5, o, Vector2(-100, 0)), 0.0, 1e-4, "повернули влево на 90° — цель прямо")
	# переход через 0°/360°: курс 350° (yaw = +10° — чуть влево), цель на курсе 10° (чуть вправо от −Z)
	var yaw := deg_to_rad(10.0)
	var to := Vector2(sin(deg_to_rad(10.0)), -cos(deg_to_rad(10.0))) * 100.0
	near(GoalPlate.delta(yaw, o, to), -20.0, 1e-3, "через север — 20° вправо, а не 340°")
	near(GoalPlate.delta(deg_to_rad(-170.0), o, Vector2(-sin(deg_to_rad(-170.0)), -cos(deg_to_rad(-170.0))) * 100.0),
		0.0, 1e-3, "курс у 180° — цель прямо")


func test_kind_by_angle() -> void:
	eq(GoalPlate.kind_of(0.0), GoalPlate.Kind.AHEAD)
	eq(GoalPlate.kind_of(10.0), GoalPlate.Kind.AHEAD, "10° — ещё прямо")
	eq(GoalPlate.kind_of(-10.5), GoalPlate.Kind.RIGHT, "правее 10°")
	eq(GoalPlate.kind_of(40.0), GoalPlate.Kind.LEFT)
	eq(GoalPlate.kind_of(120.0), GoalPlate.Kind.LEFT, "120° — ещё стрелка")
	eq(GoalPlate.kind_of(-121.0), GoalPlate.Kind.BEHIND, "больше 120° — развернитесь")


func test_texts_and_states() -> void:
	var run := Run.new()
	run.begin(0.0, 0, 0, 0)
	var p := GoalPlate.new()
	p.update(0.1, run, 0.0, Vector2.ZERO)
	eq(p.kind, GoalPlate.Kind.NONE, "маршрута нет")
	eq(p.text, GoalPlate.NONE_TEXT)
	eq(p.edge(), UiStyle.OFF, "погашенная рамка")
	run.choose(0)   # Рифовый сад: Каменный цветок первым
	var flower := Run.place_xz("flower")
	var from := flower + Vector2(0, 138)   # точка в 138 м прямо по носу (нос в −Z)
	ok(p.update(0.1, run, 0.0, from), "маршрут выбран — вид сменился")
	eq(p.kind, GoalPlate.Kind.AHEAD)
	eq(p.text, "Каменный цветок · 138 м", "прямо — без угла")
	ok(p.has_icon(), "стрелка")
	p.update(0.1, run, deg_to_rad(-40.0), from)   # нос повернули вправо на 40° — цель левее
	eq(p.kind, GoalPlate.Kind.LEFT)
	eq(p.text, "40°   Каменный цветок · 138 м")
	p.update(0.1, run, deg_to_rad(95.0), from)
	eq(p.kind, GoalPlate.Kind.RIGHT)
	eq(p.text, "95°   Каменный цветок · 138 м")
	p.update(0.1, run, PI, from)
	eq(p.text, "Развернитесь · Каменный цветок · 138 м")
	var rev := p.rev
	ok(not p.update(0.1, run, PI + 0.001, from + Vector2(0, 0.2)), "угол и метры те же — без перерисовки")
	eq(p.rev, rev)
	run.update(flower.x, flower.y)   # точка пройдена
	p.update(0.1, run, 0.0, flower)
	eq(p.kind, GoalPlate.Kind.ARRIVED, "пройдена — «на месте»")
	eq(p.text, "Каменный цветок — на месте")
	eq(p.edge(), GoalPlate.AMBER, "рамка янтарём")
	ok(not p.has_icon())
	p.update(1.5, run, 0.0, flower)
	eq(p.kind, GoalPlate.Kind.ARRIVED, "1,6 с — ещё на месте")
	p.update(0.5, run, 0.0, flower)
	ok(p.text.contains(Run.place_name("bones")), "через 2 с — следующая цель: " + p.text)
	run.choose(1)   # смена маршрута у стола — без «на месте»
	p.update(0.1, run, 0.0, flower)
	ok(p.kind != GoalPlate.Kind.ARRIVED, "сменили маршрут — сразу новая цель")
	run.open_vote()
	p.update(0.1, run, 0.0, flower)
	eq(p.kind, GoalPlate.Kind.VOTE)
	eq(p.text, GoalPlate.VOTE_TEXT)
	eq(p.edge(), GoalPlate.AMBER)


func test_route_done_shows_none() -> void:
	var run := Run.new()
	run.begin(0.0, 0, 0, 0)
	run.choose(2)   # Край отмели: два места
	var p := GoalPlate.new()
	for k in ["well", "drop"]:
		var at := Run.place_xz(k)
		run.update(at.x, at.y)
		p.update(0.1, run, 0.0, at)
	eq(p.kind, GoalPlate.Kind.ARRIVED, "последняя точка — тоже «на месте»")
	p.update(2.5, run, 0.0, Vector2.ZERO)
	eq(p.kind, GoalPlate.Kind.NONE, "маршрут пройден — «Маршрут не выбран — голостол»")


## Плашка не ложится на строку приборов и noclip при 1600×720 и 2400×1080 — во всех состояниях.
func test_rect_clear_of_status_and_noclip() -> void:
	var font := ThemeDB.fallback_font
	for size: Vector2 in [Vector2(1600, 720), Vector2(2400, 1080)]:
		var l := Touch.Layout.new()
		l.compute(Rect2(Vector2.ZERO, size))
		var nc := Rect2(l.noclip.c - Vector2(l.noclip.r, l.noclip.r), Vector2(l.noclip.r, l.noclip.r) * 2.0)
		var status := Rect2(14, 9, 920, 104)   # строка приборов за штурвалом во всю ширину (900 + поля)
		var p := GoalPlate.new()
		var run := Run.new()
		run.begin(0.0, 0, 0, 0)
		for yaw in [0.0, 0.7, PI]:
			for r in [-1, 3]:
				if r >= 0:
					run.choose(r)
				p.update(0.1, run, yaw, Vector2(300, 300))
				var px := roundi(GoalPlate.TEXT_PX * size.y / GoalPlate.REF_H)
				var fit := p.fit(font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, size, status, nc)
				var rect: Rect2 = fit[0]
				ok(fit[1] >= GoalPlate.MIN_K, tag_of(size, p) + ": кегль не мельче MIN_K")
				if p.kind == GoalPlate.Kind.BEHIND and size.x == 1600.0:
					ok(rect.position.y < status.end.y, "«Развернитесь» при 1600×720 — в полосе, мельче, а не под строкой")
				var tag := tag_of(size, p)
				ok(not rect.intersects(status), tag + ": не на строке приборов")
				ok(not rect.intersects(nc), tag + ": не на noclip")
				ok(rect.position.x >= 0.0 and rect.end.x <= size.x, tag + ": в экране")
				near(rect.size.y, GoalPlate.HEIGHT * size.y / GoalPlate.REF_H, 1e-3, tag + ": высота 88 при 1080")
	var wide: Array = GoalPlate.new().fit(2000.0, Vector2(2400, 1080), Rect2(14, 9, 920, 104), Rect2(2250, 30, 120, 120))
	ok((wide[0] as Rect2).position.y > 113.0, "не влезла и мельче — под строкой приборов")
	eq(wide[1], 1.0, "там — полный кегль")


func tag_of(size: Vector2, p: GoalPlate) -> String:
	return "%s «%s»" % [size, p.text]


func test_scene_seated_plate() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.run.choose(0)
	main.walker.x = 0.0
	main.walker.z = Deck.CHAIR_Z
	main.step(1.0 / 30.0)
	ok(not main.goal_plate_view.visible, "на палубе плашки нет")
	ok(Status.join(main.status_parts()).contains("Рифовый сад 0/3"), "на палубе строка маршрута — в приборах")
	main.use_post("helm")
	ok(main.pilot.seated, "сел")
	main.step(1.0 / 30.0)
	ok(main.goal_plate_view.visible, "за штурвалом — плашка цели")
	ok(main.goal_plate.text.contains("Каменный цветок"), main.goal_plate.text)
	ok(not Status.join(main.status_parts()).contains("Рифовый сад"), "строка маршрута ушла из приборов")
	var r := main.goal_plate_view.rect
	ok(r.has_area() and not r.intersects(main.status_rect()), "плашка мимо строки приборов")
	main.set_hud(false)   # кадры для магазина и пробы света: плашки цели в кадре нет (#1350)
	main.step(1.0 / 30.0)
	ok(not main.goal_plate_view.visible, "hud=0 — плашки нет")
	ok(not main.hint.visible, "hud=0 — строки приборов нет")
	main.set_hud(true)
	main.step(1.0 / 30.0)
	ok(main.goal_plate_view.visible, "интерфейс вернулся — плашка снова")
	main.stand_up()
	main.step(1.0 / 30.0)
	ok(not main.goal_plate_view.visible, "встал — плашки нет")
