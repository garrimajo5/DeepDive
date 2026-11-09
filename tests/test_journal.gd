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
	var c := Journal.place_center("drop", SIZE)   # рядом никого — не раздвинута
	ok(c.is_equal_approx(Vector2(360 + 290 + 0.95 * 215.0, 555 + 0.95 * 90.0)), "u = L + 290 + 0,95·x, v = 555 + 0,95·z")
	var map := Journal.map_rect(SIZE)
	eq(Run.PLACES.size(), 11, "на карте все 11 мест слоя 1 (#829)")
	for k: String in Run.PLACES:
		var r := Journal.place_rect(k, SIZE)
		ok(map.encloses(r), "%s — кнопка целиком на карте" % k)
		var true_at := Vector2(360, 0) + Journal.map_point(Run.place_xz(k))
		ok(r.get_center().distance_to(true_at) < Journal.PLACE_BUTTON * 0.5,
			"%s — кнопка раздвинута не дальше полукнопки от своей точки" % k)
		ok(r.size.x >= 96.0, "кнопка места ≥ 96 px")
		for o: String in Run.PLACES:
			if o != k:
				ok(not r.intersects(Journal.place_rect(o, SIZE)), "%s и %s не налезают" % [k, o])
	var half := Vector2(1200, 540)
	eq(Journal.back_rect(half).size, Vector2(150, 56), "кнопки — по высоте экрана")


func test_border_label_at_08() -> void:
	ok(not Journal.border_shown(null), "без знаний подписи нет")
	var l := LayerLore.new()
	ok(not Journal.border_shown(l), "поле не замечено — подписи нет")
	l.learn(LayerLore.FIELD08)
	ok(Journal.border_shown(l), "поле 08 замечено — «граница»")
	for size: Vector2 in [SIZE, Vector2(1920, 1080), Vector2(1280, 720)]:
		var br := Journal.border_rect(size)
		ok(Journal.map_rect(size).encloses(br), "%s: подпись на карте" % size)
		var b := Journal.place_rect("field", size)
		ok(br.position.y >= b.end.y and br.position.x <= b.get_center().x and br.end.x >= b.get_center().x,
			"%s: под кнопкой 08" % size)
		for k: String in Run.PLACES:
			ok(not br.intersects(Journal.place_rect(k, size)), "%s: подпись не на кнопке %s" % [size, k])


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
	eq(f[0][0], "Посещено 3 из 11")
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
	ok(main.logbook.blank, "пустой журнал: карты нет")
	r.begin(9, Journal.place_center("drop", size))
	main.step(1.0 / 30.0)
	r.end(9)
	eq(main.logbook.picked, "", "невидимая карта касаний не ловит")
	main.expedition.runs = 1   # журнал ожил — карта на экране
	main.step(1.0 / 30.0)
	ok(not main.logbook.blank, "есть забег — не пусто")
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


func test_grid_pages() -> void:
	var n := Species.count()
	eq(Journal.pages(), ceili(n / 6.0), "страниц — по 6 видов из каталога")
	eq(Journal.page_ids(0), Species.ids().slice(0, 6), "порядок каталога")
	eq(Journal.grid_title(0), "Виды · 1–6 из %d" % n, "знаменатель — настоящий каталог")
	var last := Journal.pages() - 1
	eq(Journal.grid_title(last), "Виды · %d–%d из %d" % [last * 6 + 1, n, n], "последняя страница — до конца каталога")
	eq(Journal.cell_rect(0, SIZE), Rect2(1140, 550, 280, 160), "первая ячейка от (R, 550)")
	eq(Journal.cell_rect(4, SIZE), Rect2(1440, 730, 280, 160), "шаг 300 × 180")
	eq(Journal.prev_rect(SIZE), Rect2(1140, 922, 240, 112), "«Ранее»")
	eq(Journal.next_rect(SIZE).end.x, Journal.left(SIZE) + Journal.CONTENT_W, "«Далее» у правого края контента")
	ok(Journal.next_rect(SIZE).end.y <= SIZE.y, "кнопки страниц в кадре")
	for w in [2400.0, 2340.0, 1920.0]:
		var sz := Vector2(w, 1080)
		var map := Journal.map_rect(sz)
		for i in 6:
			var c := Journal.cell_rect(i, sz)
			ok(not c.intersects(map) and not c.intersects(Journal.back_rect(sz)), "%d: ячейка %d мимо карты и «Назад»" % [w, i])
			ok(c.end.x <= w, "%d: ячейка %d в кадре" % [w, i])
		var top := Journal.SUMMARY_AT.y + Journal.SUMMARY_STEP * 3 + Journal.SUMMARY_PX
		ok(top <= Journal.TAB[0].position.y, "сводка над вкладками")
	var j := Journal.new()
	j.show()
	eq(j.press("prev"), "", "на первой странице «Ранее» неактивна")
	eq(j.page, 0)
	eq(j.hit(Journal.next_rect(SIZE).get_center(), SIZE), "next")
	eq(j.press("next"), "page")
	eq(j.page, 1)
	for i in 20:
		j.press("next")
	eq(j.page, last, "на последней — «Далее» неактивна")
	eq(j.hit(Journal.cell_rect(0, SIZE).get_center(), SIZE), "species:" + Journal.page_ids(last)[0], "ячейка — вид этой страницы")
	if Journal.page_ids(last).size() < 6:
		eq(j.hit(Journal.cell_rect(5, SIZE).get_center(), SIZE), "", "пустая ячейка за концом каталога — ничего")
	j.show()
	eq(j.page, 0, "журнал открывается с первой страницы")


func test_unknown_species_and_card() -> void:
	var sc := Scanner.new()
	sc.scanned["pred"] = true
	sc.observe("pred", Species.info("pred").notes[0][0])
	var e := Expedition.new()
	var j := Journal.new()
	j.show()
	eq(j.press("species:fish", sc.scanned, e), "ask", "неизученный — карточки нет")
	eq(j.asked, "fish", "в ячейке «Изучите вид сканером»")
	eq(j.card, "")
	ok(e.is_new("pred", sc.scanned.keys()), "изученный, карточка не открыта — «новое»")
	eq(j.press("species:pred", sc.scanned, e), "card")
	eq(j.card, "pred", "карточка изученного")
	eq(j.asked, "", "подсказка снята")
	ok(not e.is_new("pred", sc.scanned.keys()), "открыли карточку — «новое» снято")
	ok(e.read.has("pred"))
	var lines := Journal.card_text(sc, "pred")
	eq(lines[0], "ЖУРНАЛ · ВИД 1 ИЗ 1", "номер среди изученных")
	eq(lines[1], "Серпохвост", "имя — `Lab.card_lines`")
	eq(lines[2], "Наблюдений 1 из %d" % Species.info("pred").notes.size())
	eq(j.hit(Journal.cell_rect(0, SIZE).get_center(), SIZE), "", "под карточкой сетка не ловит")
	eq(j.hit(Journal.back_rect(SIZE).get_center(), SIZE), "", "и «Назад» экрана тоже")
	eq(j.hit(Journal.close_rect(SIZE).get_center(), SIZE), "close")
	var cr := Journal.card_rect(SIZE)
	eq(cr, Rect2(540, 182.5, 1320, 715), "карточка 1320 × 715 по центру")
	ok(cr.encloses(Journal.close_rect(SIZE)) and cr.encloses(Journal.in_card(Journal.CARD_PIC, SIZE)), "«Закрыть» и картинка в карточке")
	eq(j.back(), "card", "системная «Назад» сначала закрывает карточку")
	ok(j.open and j.card == "", "журнал открыт")
	j.press("species:pred", sc.scanned, e)
	eq(j.press("close"), "card")
	ok(j.open and j.card == "", "«Закрыть»")
	sc.scanned["fish"] = true
	eq(Journal.card_index("pred", sc.scanned), Vector2i(2, 2), "порядок каталога: светляк первым")
	eq(j.back(), "back", "без карточки — журнал закрыт")
	ok(not j.open)


func test_blank_journal_catches_only_back() -> void:
	var j := Journal.new()
	j.show()
	j.blank = true
	eq(j.hit(Journal.cell_rect(0, SIZE).get_center(), SIZE), "", "пусто — сетки нет")
	eq(j.hit(Journal.place_center("flower", SIZE), SIZE), "", "и карты")
	eq(j.hit(Journal.back_rect(SIZE).get_center(), SIZE), "back")


func test_scene_card_from_grid() -> void:
	Main.menu = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.scanner.scanned["fish"] = true
	main.open_journal()
	main.step(1.0 / 30.0)
	ok(not main.logbook.blank, "изучен вид — журнал не пуст")
	var r := main.overlay.router
	var size := main.get_viewport().get_visible_rect().size
	r.begin(1, Journal.cell_rect(0, size).get_center())
	main.step(1.0 / 30.0)
	r.end(1)
	eq(main.logbook.card, "fish", "касание ячейки — карточка")
	ok(main.expedition.read.has("fish"), "«новое» снято")
	await frames(1)
	r.begin(2, Journal.close_rect(size).get_center())
	main.step(1.0 / 30.0)
	r.end(2)
	eq(main.logbook.card, "", "«Закрыть»")
	ok(main.logbook.open, "журнал остался")
	r.begin(3, Journal.cell_rect(1, size).get_center())
	main.step(1.0 / 30.0)
	r.end(3)
	eq(main.logbook.asked, Species.ids()[1], "неизученный — подсказка")
	r.begin(4, Journal.next_rect(size).get_center())
	main.step(1.0 / 30.0)
	r.end(4)
	eq(main.logbook.page, 1, "«Далее»")
	main.logbook.press("species:fish", main.scanner.scanned, main.expedition)
	main.back_pressed()
	ok(main.logbook.open and main.logbook.card == "", "«Назад» — сначала карточка")
	main.back_pressed()
	ok(not main.logbook.open and main.main_menu.open, "потом журнал")


func test_slope_band_holds_place_10() -> void:   # #829: склон за восточным краем — сжатая полоса, 10 на ней, не у края
	var band := Journal.east_rect(SIZE)
	var map := Journal.map_rect(SIZE)
	ok(map.encloses(band), "полоса склона — внутри карты")
	near(band.position.x, 360 + 290 + 0.95 * 350.0, 1e-3, "начинается у восточного края отмели (350 м)")
	near(band.size.x, 350.0 * Journal.EAST_PX, 1e-3, "350 м склона в сжатом масштабе")
	var c := Journal.place_center("descent", SIZE)
	var want := Vector2(360, 0) + Journal.map_point(LayerMap.xz("10"))
	ok(c.distance_to(want) < 1.0, "10 — на своей точке склона, не прижато к краю")
	ok(band.has_point(c), "10 — на полосе склона")
	near(Journal.map_point(Vector2(350.0, 0.0)).x, Journal.map_point(Vector2(350.001, 0.0)).x, 0.01, "без скачка на краю")


func test_lore_lines() -> void:   # #825 ч. 2, UX #1335 п. 8: «Узнано · n / 8», служебные отметки — не знания
	eq(Journal.LORE_LINES.size(), 8, "восемь знаний слоя")
	for k: String in [LayerLore.INTRO, LayerLore.BRIEF, LayerLore.DOWN, LayerLore.BACK]:
		ok(not Journal.LORE_LINES.has(k), "%s — служебная отметка, не строка" % k)
	for k: String in LayerLore.KEYS:
		if not k in [LayerLore.INTRO, LayerLore.BRIEF, LayerLore.DOWN, LayerLore.BACK]:
			ok(Journal.LORE_LINES.has(k), "%s — есть строка" % k)
	for k: String in Journal.LORE_LINES:
		var line: Array = Journal.LORE_LINES[k]
		ok(line[1].length() <= Journal.LORE_MAX, "%s: ≤ 36 знаков" % k)
		ok(line[0] == "" or Run.PLACES.has(line[0]), "%s: место из слоя" % k)
	eq(Journal.lore_title(null), "Узнано · 0 / 8", "без знаний")
	var l := LayerLore.new()
	l.learn(LayerLore.INTRO)
	l.learn(LayerLore.D07_RETURN)
	l.learn(LayerLore.SHELL03)
	l.learn(LayerLore.K2)
	l.learn(LayerLore.FIELD08)
	eq(Journal.lore_title(l), "Узнано · 4 / 8", "счёт без служебных")
	eq(Journal.lore_facts(l), [LayerLore.FIELD08, LayerLore.K2, LayerLore.SHELL03, LayerLore.D07_RETURN], "новое сверху")
	eq(Journal.lore_pages(l), 2, "по 3 на страницу")
	eq(Journal.lore_page(l, 1), [LayerLore.D07_RETURN], "вторая страница")


func test_lore_tab_layout() -> void:
	for sz: Vector2 in [SIZE, Vector2(2340, 1080), Vector2(1920, 1080), Vector2(1280, 720)]:
		var s := Journal.scale(sz)
		var t0 := Journal.tab_rect(0, sz)
		var t1 := Journal.tab_rect(1, sz)
		ok(not t0.intersects(t1), "%s: вкладки не налезают" % sz)
		var sum_bottom := (Journal.SUMMARY_AT.y + Journal.SUMMARY_STEP * 3 + Journal.SUMMARY_PX) * s
		for t in [t0, t1]:
			ok(t.position.y >= sum_bottom - 0.01, "%s: вкладка под сводкой" % sz)
			ok(not t.intersects(Journal.cell_rect(0, sz)) and not t.intersects(Journal.map_rect(sz)), "%s: мимо сетки и карты" % sz)
			ok(t.end.x <= sz.x, "%s: в кадре" % sz)
		for i in Journal.LORE_PER_PAGE:
			var row := Journal.lore_rect(i, sz)
			ok(row.position.y >= t0.end.y and row.end.y <= Journal.prev_rect(sz).position.y, "%s: строка %d между вкладками и «Ранее»" % [sz, i])
			ok(not row.intersects(Journal.map_rect(sz)), "%s: строка %d мимо карты" % [sz, i])
			if i > 0:
				ok(not row.intersects(Journal.lore_rect(i - 1, sz)), "%s: строки не налезают" % sz)


func test_lore_tab_press() -> void:
	var l := LayerLore.new()
	for k: String in [LayerLore.D07_RETURN, LayerLore.D07_RELAY, LayerLore.SHELL03, LayerLore.K2]:
		l.learn(k)
	var j := Journal.new()
	j.lore = l
	j.show()
	eq(j.tab, "species", "журнал открывается на «Виды»")
	j.press("next")
	eq(j.hit(Journal.tab_rect(1, SIZE).get_center(), SIZE), "tab:lore")
	eq(j.press("tab:lore"), "tab")
	eq(j.page, 0, "вкладка — с первой страницы")
	eq(j.press("tab:lore"), "", "та же вкладка — ничего")
	eq(j.hit(Journal.lore_rect(0, SIZE).get_center(), SIZE), "lore:" + LayerLore.K2, "первая строка — новое")
	eq(j.press("lore:" + LayerLore.K2), "", "К-2 — на борту, места нет")
	eq(j.press("lore:" + LayerLore.SHELL03), "place", "строка — её место на карте")
	eq(j.picked, "shell")
	eq(j.press("next"), "page")
	eq(j.page, 1)
	eq(j.press("next"), "", "4 знания — 2 страницы")
	eq(j.hit(Journal.lore_rect(0, SIZE).get_center(), SIZE), "lore:" + LayerLore.D07_RETURN)
	eq(j.hit(Journal.lore_rect(1, SIZE).get_center(), SIZE), "", "пустая строка — ничего")
	eq(j.press("tab:species"), "tab")
	eq(j.page, 0)
	j.press("tab:lore")
	j.back()
	j.show()
	eq(j.tab, "species", "закрыт и открыт — снова «Виды»")


func test_scene_lore_tab() -> void:
	Main.menu = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.lore.learn(LayerLore.FIELD08)
	main.scanner.scanned["fish"] = true
	main.open_journal()
	main.step(1.0 / 30.0)
	var r := main.overlay.router
	var size := main.get_viewport().get_visible_rect().size
	r.begin(1, Journal.tab_rect(1, size).get_center())
	main.step(1.0 / 30.0)
	r.end(1)
	eq(main.logbook.tab, "lore", "касание вкладки — «Узнано»")
	eq(main.logbook_panel.lore, main.lore, "панель видит знания")
	r.begin(2, Journal.lore_rect(0, size).get_center())
	main.step(1.0 / 30.0)
	r.end(2)
	eq(main.logbook.picked, "field", "строка поля 08 — место на карте")
	await frames(1)
