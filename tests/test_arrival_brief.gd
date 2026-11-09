extends TestCase
## Брифинг прибытия у старта 00 (#827, TXT-001 §1): восемь экранов, переход касанием, без таймера; пока идёт —
## подсказки ждут и события слоя не открываются; прочитан — знание `LayerLore.BRIEF`, загрузка его не повторяет.

var main: Main


func after() -> void:
	Main.hints = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func _shown(b: ArrivalBrief) -> void:
	b.update(1.0, false)   # проявилась и простояла дольше MIN_SHOW


func test_screens_from_txt001() -> void:
	eq(ArrivalBrief.count(), 8, "восемь экранов L1_BRIEF_01…08")
	eq(ArrivalBrief.line(0, 0), "Талассия-IV.", "первая строка")
	eq(ArrivalBrief.line(3, 1), "", "у экрана 4 второй строки нет — «—» игроку не показываем")
	eq(ArrivalBrief.line(7, 1), "Идём малым ходом.", "последняя строка")
	for i in ArrivalBrief.count():
		ok(ArrivalBrief.line(i, 0) != "", "у экрана %d есть первая строка" % (i + 1))
	for t in ArrivalBrief.LINES:
		ok(t.length() <= 60 and t != "—", "строка не длиннее 60 знаков: %s" % t)
	var doc := FileAccess.get_file_as_string("res://docs/teksty/TXT-001-sloj1.md")
	for i in ArrivalBrief.count():   # строки — как в принятом тексте, экран в экран
		var row := "| L1_BRIEF_%02d | %s | %s |" % [i + 1, ArrivalBrief.line(i, 0),
			ArrivalBrief.line(i, 1) if ArrivalBrief.line(i, 1) != "" else "—"]
		ok(doc.contains(row), "экран %d как в TXT-001" % (i + 1))


func test_tap_turns_screens_no_timer() -> void:
	var b := ArrivalBrief.new()
	b.on = true
	ok(not b.tap(), "невидимая плашка касанием не листается")
	eq(b.screen, 0, "экран 1")
	b.update(ArrivalBrief.FADE, false)
	ok(not b.tap() and b.screen == 0, "раньше MIN_SHOW касание не листает (случайное двойное)")
	b.update(600.0, false)
	eq(b.screen, 0, "таймер экран не закрывает")
	ok(not b.tap(), "касание — дальше, брифинг ещё идёт")
	eq(b.screen, 1, "экран 2")
	eq(b.footer(), "2 / 8 · " + ArrivalBrief.HINT, "номер и подсказка")
	for i in 6:
		_shown(b)
		ok(not b.tap(), "экран %d" % (i + 3))
	eq(b.footer(), "8 / 8 · " + ArrivalBrief.HINT_LAST, "на последнем — «к постам»")
	_shown(b)
	ok(b.tap(), "последнее касание — брифинг пройден")
	ok(not b.active(), "больше не идёт")
	ok(not b.tap(), "после конца касания ничего не делают")


func test_hidden_stands() -> void:
	var b := ArrivalBrief.new()
	b.on = true
	b.update(5.0, true)
	ok(not b.shown(), "под облётом и меню не видна")
	eq(b.t, 0.0, "время экрана не идёт")
	ok(b.active(), "но брифинг ждёт")


func test_box_clears_controls() -> void:   # над крестовиной и кнопками: плашка в верхней половине, по центру
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720), Vector2(1920, 1080)]:
		var r := ArrivalBrief.box(size)
		near(r.get_center().x, size.x * 0.5, 0.5, "по центру %s" % size)
		ok(r.end.y <= size.y * 0.5, "в верхней половине %s" % size)
		ok(r.position.x >= 0.0 and r.end.x <= size.x, "в экране %s" % size)


func test_long_line_fits_plate() -> void:
	var font := ThemeDB.fallback_font
	var size := Vector2(1600, 720)
	var s := ArrivalBrief.scale(size)
	var width := ArrivalBrief.box(size).size.x - 2.0 * ArrivalBrief.LINE1_AT.x * s
	for t in ArrivalBrief.LINES:
		var px := ArrivalBriefPanel.fit_px(font, t, int(ArrivalBrief.LINE_PX * s), width)
		ok(font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width + 0.5, "влезает: %s" % t)
		ok(px >= int(ArrivalBrief.LINE_PX * s * 0.75), "и не мельче 3/4 кегля: %s" % t)


func test_scene_brief_before_hints() -> void:
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.arrival.active(), "первое прибытие — брифинг")
	for i in 30:
		main.step(1.0 / 30.0)
	ok(main.arrival_panel.visible, "плашка брифинга видна")
	ok(not main.tutorial.shown(), "подсказки ждут конца брифинга")
	ok(main.events_held(), "события слоя ждут")
	var size := main.get_viewport().get_visible_rect().size
	for i in ArrivalBrief.count():
		main.overlay.router.taps.append(ArrivalBrief.box(size).get_center())
		main.step(1.0 / 30.0)
		for j in 15:
			main.step(1.0 / 30.0)
	ok(not main.arrival.active(), "восемь касаний — пройден")
	ok(main.lore.knows(LayerLore.BRIEF), "знание «брифинг прочитан»")
	for i in 15:
		main.step(1.0 / 30.0)
	ok(main.tutorial.shown(), "дальше — подсказки первого забега")
	ok(not main.arrival_panel.visible, "плашки брифинга нет")


func test_scene_pad_does_not_turn() -> void:   # крестовина ведёт игрока, а не листает брифинг
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	for i in 30:
		main.step(1.0 / 30.0)
	main.overlay.router.taps.append(main.overlay.router.layout.pad.c)
	main.step(1.0 / 30.0)
	eq(main.arrival.screen, 0, "касание крестовины экран не листает")


func test_scene_loaded_brief_not_repeated() -> void:   # загрузка после брифинга — сразу подсказки
	const PATH := "user://test_arrival_save.json"
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": SaveGame.VERSION, "lore": [LayerLore.BRIEF]}))
	f.close()
	SaveGame.default_path = PATH
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	SaveGame.default_path = ""
	DirAccess.remove_absolute(PATH)
	ok(not main.arrival.active(), "брифинг не повторяется")
	ok(main.tutorial.on, "подсказки ещё не пройдены — идут")


func test_scene_off_in_tests() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(not main.arrival.active(), "в тестах и снимках брифинга нет (Main.hints = false)")
	ok(not main.events_held(), "события не ждут")


## Табло тревог ART-025 под плашкой не угадывается: заливка глухая (#1429, решение UX — 1,0).
func test_fill_hides_alarm_board() -> void:
	eq(ArrivalBriefPanel.FILL, 1.0, "заливка плашки глухая")


## Строки живого мира не перебивают брифинг: последняя ждёт его конца и выходит после 8/8 (#1429).
func test_scene_world_lines_wait_for_brief() -> void:
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	for i in 30:
		main.step(1.0 / 30.0)
	ok(main.arrival.shown(), "брифинг на экране")
	var before: String = main.message.text
	main.on_eco_event({"type": EcoLink.MESSAGE, "text": "Из песка что-то схватило рыбу"})
	main.on_eco_event({"type": EcoLink.MESSAGE, "text": "На светящиеся споры слетаются рыбы"})
	eq(main.message.text, before, "во время брифинга строка мира не выходит")
	eq(main.world_wait, "На светящиеся споры слетаются рыбы", "ждёт одна, последняя")
	var size := main.get_viewport().get_visible_rect().size
	var pending := ""
	for i in ArrivalBrief.count():
		for j in 15:
			main.step(1.0 / 30.0)
		ok(main.arrival.active(), "брифинг ещё идёт")
		eq(main.message.text, before, "строка приборов под брифингом не меняется (экран %d)" % (i + 1))
		pending = main.world_wait   # живой мир может сменить отложенную строку на свежую — ждёт последняя
		main.overlay.router.taps.append(ArrivalBrief.box(size).get_center())
		main.step(1.0 / 30.0)
	ok(not main.arrival.active(), "брифинг пройден")
	ok(pending != "", "строка ждала")
	ok(main.message.text != before and main.message.text != "", "после брифинга — отложенная строка на приборах")
	eq(main.world_wait, "", "отложенной больше нет")


func test_scene_queued_world_line_waits_for_brief() -> void:
	# #1429, отчёт 1840-brif: строка мира ждала своей секунды в Status.Message до брифинга и вышла уже под плашкой
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	for i in 30:
		main.step(1.0 / 30.0)
	ok(main.arrival.shown(), "брифинг на экране")
	main.world_wait = ""
	main.message.say("Из песка что-то схватило круглую рыбку", Status.MESSAGE_SECONDS, true)
	main.message.say("Стайка круглых рыбок пасётся на светящемся мху", Status.MESSAGE_SECONDS, true)   # в очереди
	for i in 60:
		main.step(1.0 / 30.0)
		ok(not main.message.text.contains("рыб"), "строка мира не выходит под брифингом (кадр %d)" % i)
	eq(main.world_wait, "Стайка круглых рыбок пасётся на светящемся мху", "ждёт последняя из очереди")
