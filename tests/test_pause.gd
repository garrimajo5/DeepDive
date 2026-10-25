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
	eq(Pause.button_rect(4).end.y, 310.0 + 136.0 * 4 + 112.0, "пятая кнопка по макету (шаг 136 со схемой ART-042)")


func test_back_and_confirm() -> void:
	var p := Pause.new()
	var size := Vector2(1600, 720)
	eq(p.hit(Pause.screen_rect("resume", size).get_center(), size), "", "закрытая пауза касаний не берёт")
	eq(p.back(), "pause", "«Назад» — пауза")
	ok(p.open, "пауза открыта")
	eq(p.hit(Pause.screen_rect("resume", size).get_center(), size), "resume", "касание «Продолжить»")
	eq(p.hit(Pause.screen_rect("settings", size).get_center(), size), "settings", "касание «Настройки»")
	eq(p.press("settings"), "settings", "«Настройки» — поверх паузы")
	ok(p.open, "пауза под настройками открыта")
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


## Палец на крестовине «вперёд» мимо кнопок паузы (на узком окне кнопки ложатся на крестовину).
func _pad_point() -> Vector2:
	var r := main.overlay.router
	var size := main.get_viewport().get_visible_rect().size
	for k in [0.7, 0.5, 0.3, 0.1]:
		var p := r.layout.pad.c + Vector2(0, -r.layout.pad.r * k)
		if main.pause.hit(p, size) == "":
			return p
	return r.layout.pad.c + Vector2(-r.layout.pad.r * 0.7, 0)


func _tap(id: String, finger: int) -> void:
	var r := main.overlay.router
	r.begin(finger, main.pause.rect(id, main.get_viewport().get_visible_rect().size).get_center())
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
	r.begin(1, _pad_point())   # крестовина вперёд — игра стоит
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
	ok(main.pause.open and main.pause.mode == "host", "в сетевом забеге — «Меню забега» хоста")
	main.vitals.hit(100, "")
	main.step(1.0 / 30.0)
	ok(not main.pause.open and not main.pause_panel.visible, "шторка «Корпус разрушен» закрывает меню забега")
	main.net_host.stop()


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


func test_net_modes() -> void:
	var p := Pause.new()
	ok(p.stops_world(), "одиночная пауза — игра стоит")
	eq(p.title(), "Пауза")
	eq(p.subtitle(), "")
	p.set_mode("host")
	ok(not p.stops_world(), "меню сетевого забега — мир идёт")
	eq(p.title(), "Меню забега")
	eq(p.subtitle(), "Вы — хост · забег продолжается")
	eq(p.items().map(func(it: Array) -> String: return it[0]), ["resume", "map", "new", "settings", "exit"], "у хоста пять (со схемой ART-042)")
	p.back()
	p.set_mode("guest")
	eq(p.mode, "host", "открытое меню режим не меняет")
	p.press("exit")
	eq(p.ask_lines(), ["Выйти в меню?", "Забег закончится у всех игроков.", "Завершить забег экипажа?"])
	p.press("no")
	p.press("new")
	eq(p.ask_lines()[1], "Забег закончится у всех игроков.", "новый забег — тоже у всех")
	eq(p.press("yes"), "new")
	eq(p.press("leave"), "", "закрытое меню кнопок не берёт")
	p.set_mode("guest")
	p.back()
	eq(p.subtitle(), "Вы — гость · забег продолжается")
	eq(p.items().map(func(it: Array) -> String: return it[0]), ["resume", "map", "settings", "leave"], "у гостя четыре (со схемой ART-042)")
	eq(p.press("new"), "", "у гостя нового забега нет")
	eq(p.press("exit"), "", "и выхода в меню хоста нет")
	eq(p.ask, "")
	var size := Vector2(1600, 720)
	eq(p.hit(p.rect("leave", size).get_center(), size), "leave", "касание «Покинуть экипаж»")
	eq(p.hit(Pause.screen_rect("exit", size).get_center(), size), "", "на месте четвёртой кнопки у гостя пусто")
	p.press("leave")
	eq(p.ask_lines(), ["Покинуть экипаж?", "Вы выйдете из текущего забега."])
	eq(p.press("yes"), "leave")
	ok(not p.open)
	p.set_mode("solo")
	p.back()
	p.press("exit")
	eq(p.ask_lines(), Pause.ASK["exit"], "одиночный выход — прежний текст")


func test_net_layout_fits_phones() -> void:
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720), Vector2(2340, 1080)]:
		var screen := Rect2(Vector2.ZERO, size)
		var title_bottom := Splash.to_screen(Vector2(0.0, Pause.SUB_TOP + Pause.SUB_PX), size).y
		for m: String in ["host", "guest"]:
			for it: Array in Pause.items_of(m):
				var r := Pause.screen_rect(it[0], size, m)
				ok(screen.encloses(r), "%s (%s) на экране %s" % [it[1], m, size])
				ok(r.position.y > title_bottom, "подпись коопа над кнопками")
		var box := Splash.rect_to_screen(Pause.BOX, size)
		var last := Splash.to_screen(Vector2(0.0, Pause.LINE_TOP + Pause.LINE_STEP + Pause.LINE_PX), size).y
		ok(last < Pause.screen_rect("yes", size).position.y, "две строки подтверждения над «Да» / «Нет»")
		ok(last < box.end.y, "в окне")


func test_scene_host_menu_world_goes_on_then_exit() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	eq(main.host_game(NetLink.PORT + 44), OK, "хост открыт")
	var mate := main.add_mate(1.0, 4.0, 0.0, Crew.Role.SONAR, 0)
	main.net_mates[777] = mate   # гость на палубе (без сокета)
	main.sit_at_helm()
	main.helm.speed = 3.0
	main.back_pressed()
	ok(main.pause.open and main.pause.mode == "host", "«Назад» — меню забега хоста")
	ok(not main.overlay.visible, "крестовина скрыта")
	var r := main.overlay.router
	r.begin(1, _pad_point())   # крестовина вперёд — своему игроку не идёт
	var p: Vector3 = main.helm.pos
	var t: float = main.time
	for i in 30:
		main.step(1.0 / 30.0)
	r.end(1)
	ok(main.time > t + 0.9, "часы мира идут")
	ok(main.helm.pos.distance_to(p) > 0.1, "корабль идёт по инерции — мир не стоит")
	eq(main.helm.in_thrust, 0.0, "ход под меню не задан")
	ok(main.pilot.seated, "пилот на месте")
	_tap("exit", 2)
	eq(main.pause.ask_lines()[1], "Забег закончится у всех игроков.")
	_tap("yes", 3)
	ok(main.net_host == null, "сетевой забег закрыт")
	ok(not main.crew.has(mate) and main.net_mates.is_empty(), "гости убраны с палубы")
	ok(not main.pause.open and main.main_menu.open, "главное меню")


func test_scene_host_new_run_for_all() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	eq(main.host_game(NetLink.PORT + 45), OK)
	main.helm.pos = Vector3(30.0, -40.0, -60.0)
	main.back_pressed()
	_tap("new", 1)
	_tap("yes", 2)
	ok(not main.pause.open, "меню закрыто")
	ok(main.net_host != null, "забег у экипажа продолжается с начала")
	ok(main.helm.pos.distance_to(Vector3(30.0, -40.0, -60.0)) > 1.0, "Ковчег у начала спуска")
	eq(main.news[1], "Хост начал новый забег: Ковчег у начала спуска", "сообщение — всем гостям")
	main.net_host.stop()
