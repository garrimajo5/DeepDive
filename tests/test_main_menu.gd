extends TestCase
## Главное меню ART-037 после заставки: раскладка по макету, кнопки, «Погрузиться» — забег с облётом.

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
		var safe := Splash.rect_to_screen(Rect2(240, 0, 1920, 1080), size)
		var prev := Rect2()
		for it: Array in MainMenu.ITEMS:
			var r := MainMenu.screen_rect(it[0], size)
			ok(r.size.x > 0.0 and Rect2(Vector2.ZERO, size).encloses(r), "%s на экране %s" % [it[1], size])
			ok(safe.encloses(r), "%s в безопасной ширине 1920 макета (%s)" % [it[1], size])
			if prev.size.x > 0.0:
				ok(not prev.intersects(r), "кнопки не налезают")
			prev = r
		near(MainMenu.screen_rect("dive", size).size.y, 112.0 * size.y / 1080.0, 0.01, "высота кнопки по H/1080")
	for i in MainMenu.ITEMS.size():   # нижние углы макета (x < 360 и x > 2040 при y > 760) пусты
		var b := MainMenu.button_rect(i)
		ok(b.end.y <= 760.0 or (b.position.x >= 360.0 and b.end.x <= 2040.0), "кнопка %d не в нижнем углу" % i)
	near(Splash.to_screen(Vector2(1200, 0), Vector2(1920, 1080)).x, 960.0, 0.01, "центр макета — центр экрана")


func test_buttons() -> void:
	var m := MainMenu.new()
	var size := Vector2(1600, 720)
	var dive := MainMenu.screen_rect("dive", size).get_center()
	var crew := MainMenu.screen_rect("crew", size).get_center()
	eq(m.hit(dive, size), "", "закрытое меню касаний не берёт")
	m.open = true
	eq(m.hit(dive, size), "dive", "касание «Погрузиться»")
	eq(m.hit(crew, size), "", "«Экипаж» погашена до экрана сбора ART-028")
	eq(m.hit(MainMenu.screen_rect("settings", size).get_center(), size), "", "«Настройки» погашены")
	eq(m.hit(Vector2(size.x - 10, size.y - 10), size), "", "мимо кнопок — ничего")
	eq(m.press("crew"), "", "погашенная не нажимается")
	ok(m.open, "меню открыто")
	eq(m.press("dive"), "dive", "«Погрузиться» — забег")
	ok(not m.open, "меню закрыто")
	eq(MainMenu.version_line("0.1"), "Версия 0.1")


func test_scene_menu_then_dive() -> void:
	Main.menu = true
	Main.intro = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ok(main.main_menu.open, "после заставки — главное меню")
	ok(main.menu_panel.visible, "меню на экране")
	ok(not main.overlay.visible, "крестовина и кнопка под меню скрыты")
	eq(main.menu_panel.version, str(ProjectSettings.get_setting("application/config/version")), "версия из project.godot")
	var r := main.overlay.router
	var size := main.get_viewport().get_visible_rect().size
	var start := Vector2(main.walker.x, main.walker.z)
	var pos: Vector3 = main.helm.pos
	r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))   # крестовина вперёд — игра стоит
	for i in 30:
		main.step(1.0 / 30.0)
	r.end(1)
	eq(Vector2(main.walker.x, main.walker.z), start, "игрок под меню не ходит")
	ok(main.helm.pos.is_equal_approx(pos), "корабль под меню стоит")
	r.begin(2, MainMenu.screen_rect("crew", size).get_center())
	main.step(1.0 / 30.0)
	r.end(2)
	ok(main.main_menu.open, "погашенная «Экипаж» меню не закрывает")
	r.begin(3, MainMenu.screen_rect("dive", size).get_center())   # палец остаётся на экране
	main.step(1.0 / 30.0)
	ok(not main.main_menu.open, "«Погрузиться» — меню закрыто")
	ok(not main.menu_panel.visible, "меню скрыто")
	ok(main.overlay.visible, "крестовина и кнопка вернулись")
	near(main.run.start["t"], main.time, 1e-6, "часы забега — с погружения, не с запуска")
	main.step(1.0 / 30.0)
	ok(main.flyby.kind == Flyby.Kind.START, "облёт с борта не пропущен пальцем с кнопки меню")
	r.end(3)
	main.step(1.0 / 30.0)
	ok(main.flyby.active(), "облёт идёт")


func test_net_closes_menu() -> void:
	Main.menu = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.main_menu.open, "меню открыто")
	main.host_game(NetLink.PORT + 41)
	ok(not main.main_menu.open, "сетевой забег — без меню")
	ok(main.overlay.visible, "управление на экране")
