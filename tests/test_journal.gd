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
	ok(c.is_equal_approx(Vector2(360 + 360 + 0.95 * 215.0, 555 + 0.95 * 90.0)), "u = L + 360 + 0,95·x, v = 555 + 0,95·z")
	var map := Journal.map_rect(SIZE)
	eq(Run.PLACES.size(), 11, "на карте все 11 мест слоя 1 (#829)")
	for k: String in Run.PLACES:
		var r := Journal.place_rect(k, SIZE)
		ok(map.encloses(r), "%s — кнопка целиком на карте" % k)
		var true_at := Vector2(360, 0) + Journal.MAP_CENTER + Run.place_xz(k) * Journal.PX_PER_M
		# место за краем карты (10 на склоне, #822) — у края карты со своей стороны
		var inset := Vector2.ONE * (Journal.PLACE_BUTTON * 0.5 + Journal.PLACE_GAP)
		true_at = true_at.clamp(map.position + inset, map.end - inset)
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
		ok(br.position.y >= b.end.y and absf(br.get_center().x - b.get_center().x) < 1.0, "%s: под кнопкой 08" % size)
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
		ok(top < Journal.GRID_TITLE_TOP, "сводка над сеткой")
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
