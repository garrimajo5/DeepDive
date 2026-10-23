extends TestCase
## Пауза одиночного забега ART-037: «Назад», кнопки, подтверждения с выделенным «Нет», новый забег, выход в меню.

var main: Main


func after() -> void:
	Main.menu = false
	Main.intro = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_layout_fits_phones() -> void:
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720), Vector2(1920, 1080), Vector2(2340, 1080)]:
		var screen := Rect2(Vector2.ZERO, size)
		var prev := Rect2()
		for it: Array in Pause.ITEMS:
			var r := Pause.screen_rect(it[0], size)
			ok(r.size.x > 0.0 and screen.encloses(r), "%s на экране %s" % [it[1], size])
			if prev.size.x > 0.0:
				ok(not prev.intersects(r), "кнопки не налезают")
			prev = r
		var yes := Pause.screen_rect("yes", size)
		var no := Pause.screen_rect("no", size)
		var box := Splash.rect_to_screen(Pause.BOX, size)
		ok(box.encloses(yes) and box.encloses(no), "«Да» и «Нет» в окне (%s)" % size)
		ok(not yes.intersects(no), "«Да» и «Нет» не налезают")
		ok(yes.position.x < no.position.x, "«Да» слева, «Нет» справа")
	near(Pause.screen_rect("resume", Vector2(2400, 1080)).get_center().x, 1200.0, 0.01, "кнопки по центру")
	eq(Pause.button_rect(3).end.y, 310.0 + 142.0 * 3 + 112.0, "четвёртая кнопка по макету")


func test_back_and_confirm() -> void:
	var p := Pause.new()
	var size := Vector2(1600, 720)
	eq(p.hit(Pause.screen_rect("resume", size).get_center(), size), "", "закрытая пауза касаний не берёт")
	eq(p.back(), "pause", "«Назад» — пауза")
	ok(p.open, "пауза открыта")
	eq(p.hit(Pause.screen_rect("resume", size).get_center(), size), "resume", "касание «Продолжить»")
	eq(p.hit(Pause.screen_rect("settings", size).get_center(), size), "", "«Настройки» погашены до своей части")
	eq(p.press("new"), "", "«Новый забег» — сначала подтверждение")
	eq(p.ask, "new", "подтверждение нового забега")
	eq(p.hit(Pause.screen_rect("exit", size).get_center(), size), "", "под подтверждением кнопки паузы не берутся")
	eq(p.hit(Pause.screen_rect("no", size).get_center(), size), "no", "касание «Нет»")
	eq(p.press("no"), "", "«Нет» — назад к паузе")
	ok(p.open and p.ask == "", "пауза открыта, диалога нет")
	p.press("exit")
	eq(p.back(), "", "«Назад» закрывает сначала подтверждение")
	ok(p.open and p.ask == "", "пауза осталась")
	p.press("exit")
	eq(Pause.ASK["exit"][1], "Забег будет потерян.", "одна строка без повтора заголовка (замечание приёмки)")
	eq(p.press("yes"), "exit", "«Да» — выйти в меню")
	ok(not p.open, "пауза закрыта")
	p.back()
	eq(p.press("resume"), "resume", "«Продолжить»")
	ok(not p.open, "пауза закрыта")
	p.back()
	eq(p.back(), "resume", "второй «Назад» закрывает паузу")


func _tap(id: String, finger: int) -> void:
	var r := main.overlay.router
	r.begin(finger, Pause.screen_rect(id, main.get_viewport().get_visible_rect().size).get_center())
	main.step(1.0 / 30.0)
	r.end(finger)
	main.step(1.0 / 30.0)


func test_scene_pause_stops_game_then_new_run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.sit_at_helm()
	main.helm.pos = Vector3(30.0, -40.0, -60.0)
	main.back_pressed()
	ok(main.pause.open and main.pause_panel.visible, "«Назад» — пауза на экране")
	ok(not main.overlay.visible, "крестовина и кнопка под паузой скрыты")
	ok(not main.hint.visible, "строки приборов под паузой скрыты")
	var r := main.overlay.router
	var t: float = main.run.start["t"]
	r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))   # крестовина вперёд — игра стоит
	for i in 30:
		main.step(1.0 / 30.0)
	r.end(1)
	ok(main.helm.pos.is_equal_approx(Vector3(30.0, -40.0, -60.0)), "корабль под паузой стоит")
	_tap("resume", 2)
	ok(not main.pause.open and not main.pause_panel.visible, "«Продолжить» — пауза закрыта")
	ok(main.overlay.visible, "управление вернулось")
	ok(main.hint.visible, "строки приборов вернулись")
	ok(main.pilot.seated, "пилот на месте")
	main.back_pressed()
	var held: Vector3 = main.helm.pos
	_tap("new", 3)
	ok(main.pause.open and main.pause.ask == "new", "подтверждение нового забега")
	_tap("no", 4)
	ok(main.pause.open and main.pause.ask == "", "«Нет» — снова пауза")
	ok(main.helm.pos.is_equal_approx(held), "забег не сброшен, корабль стоит")
	_tap("new", 5)
	_tap("yes", 6)
	ok(not main.pause.open, "пауза закрыта")
	ok(not main.pilot.seated, "пилот встал")
	ok(main.helm.pos.distance_to(Vector3(30.0, -40.0, -60.0)) > 1.0, "Ковчег у начала спуска")
	ok(main.run.start["t"] > t, "часы забега — заново")
	ok(main.overlay.visible, "управление на экране")


func test_scene_exit_to_menu() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.back_pressed()
	_tap("exit", 1)
	_tap("yes", 2)
	ok(not main.pause.open and not main.pause_panel.visible, "пауза закрыта")
	ok(main.main_menu.open and main.menu_panel.visible, "главное меню")
	ok(not main.overlay.visible, "управление под меню скрыто")
	var r := main.overlay.router
	r.begin(3, MainMenu.screen_rect("dive", main.get_viewport().get_visible_rect().size).get_center())
	main.step(1.0 / 30.0)
	r.end(3)
	ok(not main.main_menu.open and main.overlay.visible, "«Погрузиться» — снова забег")


func test_back_ignored_in_wreck_and_net() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.vitals.hit(100, "")
	main.back_pressed()
	ok(not main.pause.open, "под шторкой «Корпус разрушен» паузы нет")
	for i in 60:
		main.step(0.1)
	main.host_game(NetLink.PORT + 43)
	main.back_pressed()
	ok(not main.pause.open, "в сетевом забеге — пока без паузы (меню забега — следующей частью)")


func test_destroyed_closes_pause() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.back_pressed()
	main.vitals.hit(100, "")
	ok(not main.pause.open and not main.pause_panel.visible, "разрушение закрывает паузу")
	ok(main.wreck.active(), "шторка идёт")


func test_qa_steps() -> void:
	var q := QaScript.parse('[{"do": "back"}, {"do": "press", "what": "new"}, {"do": "press", "what": "yes"}]')
	eq(q.errors.size(), 0, "шаги паузы разобраны")
	var out := q.advance(0.0)
	eq(out[0], ["back"], "команда «Назад»")
