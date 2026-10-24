extends TestCase
## «Журнал экспедиции» ART-047 из главного меню (Journal, JournalPanel): раскладка по макету, карта мест, сводка с
## настоящими знаменателями, «—» для неизвестной истории, касания и «Назад».

const SIZE := Vector2(2400, 1080)

var main: Main


func after() -> void:
	Main.menu = false
	Main.intro = false
	if main:
		main.queue_free()
		main = null
		await frames(1)


func test_layout_by_mockup() -> void:
	near(Journal.left(Vector2(2400, 1080)), 360.0, 1e-3, "2400: L = 360")
	near(Journal.left(Vector2(2340, 1080)), 330.0, 1e-3, "2340: L = 330")
	near(Journal.left(Vector2(1920, 1080)), 120.0, 1e-3, "1920 (16:9): L = 120")
	near(Journal.left(Vector2(1280, 720)), 120.0, 1e-3, "16:9 меньше — тот же макет")
	eq(Journal.back_rect(SIZE), Rect2(1740, 52, 300, 112), "«Назад» у правого края контента")
	eq(Journal.map_rect(SIZE), Rect2(360, 270, 730, 570), "карта")
	var c := Journal.place_center("flower", SIZE)
	ok(c.is_equal_approx(Vector2(360 + 365 + 1.25 * 40.0, 560 + 1.25 * -50.0)), "u = L + 365 + 1,25·x, v = 560 + 1,25·z")
	var map := Journal.map_rect(SIZE)
	for k: String in Run.PLACES:
		var r := Journal.place_rect(k, SIZE)
		ok(map.encloses(r), "%s — кнопка целиком на карте" % k)
		ok(r.size.x >= 96.0, "кнопка места ≥ 96 px")
		for o: String in Run.PLACES:
			if o != k:
				ok(not r.intersects(Journal.place_rect(o, SIZE)), "%s и %s не налезают" % [k, o])
	var half := Vector2(1200, 540)
	eq(Journal.back_rect(half).size, Vector2(150, 56), "кнопки — по высоте экрана")


func test_summary_and_unknown_history() -> void:
	var e := Expedition.new()
	e.runs = 5
	e.deepest = 340
	var rows := Journal.summary(e, 7, 12, Species.count())
	eq(rows[0][1], "Видов изучено 7 из %d" % Species.count(), "знаменатель — настоящий каталог")
	eq(rows[1][1], "Образцов в трюме 12", "без «из 24»: ёмкость не утверждена")
	eq(rows[2][1], "Забегов 5")
	eq(rows[3][1], "Глубже всего 340 м")
	ok(rows[0][0] != "" and ResourceLoader.exists(rows[0][0]), "иконка видов ART-026")
	var old := Expedition.new()
	old.full = false
	rows = Journal.summary(old, 0, 1, Species.count())
	eq(rows[2][1], "Забегов —", "старое сохранение — не ноль, а «—»")
	eq(rows[3][1], "Глубже всего —")
	var j := Journal.new()
	eq(j.footer(old)[0][0], Journal.NO_HISTORY, "история не записана")
	eq(j.footer(old).size(), 1, "совета «Дальше» нет")
	ok(Journal.empty(Expedition.new(), 0, 0), "ничего нет — первый запуск")
	ok(not Journal.empty(Expedition.new(), 0, 1), "есть груз — не пусто")


func test_footer_next_and_pick() -> void:
	var e := Expedition.new()
	for k in ["flower", "bones", "well"]:
		var p := Run.place_xz(k)
		e.visit(p.x, p.y)
	var j := Journal.new()
	j.show()
	var f := j.footer(e)
	eq(f[0][0], "Посещено 3 из 6")
	eq(f[1][0], "Дальше: Чёрный курильщик", "первое непосещённое по маршрутам")
	eq(f[2][0], Journal.ROUTE_HINT)
	eq(j.hit(Journal.place_center("geyser", SIZE), SIZE), "place:geyser", "касание места")
	eq(j.press("place:geyser"), "place", "забег не начинается")
	ok(j.open, "журнал открыт")
	eq(j.footer(e)[0][0], "Чёрный курильщик · не посещено", "название под картой")
	j.press("place:well")
	eq(j.footer(e)[0][0], "Световой колодец · посещено")
	eq(j.hit(Journal.back_rect(SIZE).get_center(), SIZE), "back")
	eq(j.hit(Vector2(5, 1075), SIZE), "", "мимо — ничего")
	eq(j.press("back"), "back")
	ok(not j.open and j.picked == "", "закрыт, выбор сброшен")
	eq(j.hit(Journal.back_rect(SIZE).get_center(), SIZE), "", "закрытый не ловит касания")


func test_menu_item() -> void:
	var m := MainMenu.new()
	m.open = true
	var size := Vector2(2340, 1080)
	eq(m.hit(MainMenu.screen_rect("journal", size).get_center(), size), "journal", "пункт «Журнал экспедиции»")
	eq(m.press("journal"), "journal", "поверх меню")
	ok(m.open, "меню ждёт")
	var ids := MainMenu.ITEMS.map(func(it: Array) -> String: return it[0])
	eq(ids.find("journal"), ids.find("crew") + 1, "после «Экипаж»")


func test_scene_open_from_menu_and_back() -> void:
	Main.menu = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var r := main.overlay.router
	var size := main.get_viewport().get_visible_rect().size
	r.begin(1, MainMenu.screen_rect("journal", size).get_center())
	main.step(1.0 / 30.0)
	r.end(1)
	ok(main.main_menu.open and main.logbook.open, "журнал поверх меню")
	ok(main.logbook_panel.visible and not main.menu_panel.visible, "журнал на экране, меню скрыто")
	ok(not main.overlay.visible, "крестовина скрыта")
	r.begin(2, Journal.place_center("drop", size))
	main.step(1.0 / 30.0)
	r.end(2)
	eq(main.logbook.picked, "drop", "касание места — его название")
	ok(main.main_menu.open, "забег не начался")
	main.back_pressed()
	ok(not main.logbook.open and main.main_menu.open, "системная «Назад» — снова меню")
	ok(main.menu_panel.visible and not main.logbook_panel.visible, "меню вернулось")
	main.step(1.0 / 30.0)
	r.begin(3, MainMenu.screen_rect("journal", size).get_center())
	main.step(1.0 / 30.0)
	r.end(3)
	main.step(1.0 / 30.0)
	r.begin(4, Journal.back_rect(size).get_center())
	main.step(1.0 / 30.0)
	r.end(4)
	ok(not main.logbook.open and main.main_menu.open, "кнопка «Назад» — в меню")
	main.step(1.0 / 30.0)
	ok(main.main_menu.open, "палец с «Назад» не нажал кнопку меню под ним")
