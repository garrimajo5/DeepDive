extends TestCase
## Хронометраж забега (RunTimeline, эпик #633): лента событий, сводка (доля под событиями, затишье, два сразу),
## файл последних забегов, недописанный забег, сцена — пробоина и итог «наверх».

const TEST_PATH := "user://test_zabegi.txt"


func after() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func _tl() -> RunTimeline:
	var r := RunTimeline.new()
	r.path = ""
	return r


func test_runner_keeps_player_file() -> void:
	eq(RunTimeline.default_path, "", "раннер выключил файл хронометража")


func test_clock() -> void:
	eq(RunTimeline.clock(0.0), "00:00")
	eq(RunTimeline.clock(65.4), "01:05")
	eq(RunTimeline.clock(754.0), "12:34")


func test_spans_and_summary() -> void:
	var r := _tl()
	r.begin(100.0)
	r.watch(110.0, {"пробоина": false, "перегрев": false}, 100.0, 12.0)
	r.watch(120.0, {"пробоина": true, "перегрев": false}, 99.0, 20.0)   # с 20 с — пробоина
	r.watch(130.0, {"пробоина": true, "перегрев": true}, 99.0, 25.0)    # с 30 с — и перегрев
	r.watch(150.0, {"пробоина": false, "перегрев": true}, 98.5, 18.0)   # 50 с — заварили
	r.watch(160.0, {"пробоина": false, "перегрев": false}, 98.5, 10.0)  # 60 с — остыл
	r.mark(170.0, "разряд")
	var lines := r.finish(220.0, "наверх, очки 40")
	eq(lines[0], "Забег 1 · 02:00 · наверх, очки 40", "заголовок: номер, длина и итог")
	ok(lines.has("00:00 начало"), "начало")
	ok(lines.has("00:20 пробоина — началось"), "пробоина в ленте")
	ok(lines.has("00:50 пробоина — кончилось (00:30)"), "и сколько шла")
	ok(lines.has("01:00 перегрев — кончилось (00:30)"), "перегрев")
	ok(lines.has("01:10 разряд"), "разовое событие")
	ok(lines.has("Под событиями 00:40 из 02:00 (33%), два сразу — 00:20"), "доля и два сразу: %s" % [lines])
	ok(lines.has("Самое долгое затишье 00:50 (01:10–02:00)"), "затишье после разряда до конца: %s" % [lines])
	ok(lines.has("События: пробоина ×1, перегрев ×1, ударов 0 · глубже всего 25 м · корпус 99%"),
		"счёт событий, глубина, корпус: %s" % [lines])
	ok(not r.running, "забег закрыт")
	eq(r.finish(230.0, "ещё раз").size(), 0, "второй раз не закрывается")


func test_hit_only_on_big_drop() -> void:
	var r := _tl()
	r.begin(0.0)
	r.watch(1.0, {}, 99.5, 0.0)   # вода пробоины точит понемногу — не удар
	r.watch(2.0, {}, 99.0, 0.0)
	r.watch(3.0, {}, 91.0, 0.0)   # укус
	var hits := r.events.filter(func(e: Array) -> bool: return String(e[1]).begins_with("удар"))
	eq(hits.size(), 1, "один удар")
	eq(hits[0][1], "удар: корпус 91%")


func test_open_event_counts_to_end() -> void:
	var r := _tl()
	r.begin(0.0)
	r.watch(30.0, {"сонарная тьма": true}, 100.0, 0.0)
	var lines := r.finish(60.0, "корпус разрушен")
	ok(lines.has("Под событиями 00:30 из 01:00 (50%), два сразу — 00:00"), "идущее считается до конца: %s" % [lines])
	ok(lines.has("01:00 сонарная тьма — кончилось (00:30)"), "и закрывается концом забега")


func test_file_newest_first_and_numbered() -> void:
	var r := RunTimeline.new()
	r.path = TEST_PATH
	r.begin(0.0)
	r.watch(20.0, {}, 100.0, 5.0)
	r.finish(20.0, "наверх, очки 10", "2026-10-26 10:00:00")
	r.begin(100.0)
	r.watch(105.0, {}, 100.0, 5.0)
	r.finish(105.0, "наверх, очки 1")   # короче SHORT — не пишется
	r.begin(200.0)
	r.watch(240.0, {}, 100.0, 5.0)
	r.finish(240.0, "корпус разрушен", "2026-10-26 10:05:00")
	var text := FileAccess.get_file_as_string(TEST_PATH)
	ok(text.begins_with("Забег 2 · 2026-10-26 10:05:00 · 00:40 · корпус разрушен"), "новый — сверху: %s" % text)
	ok(text.contains("\n\nЗабег 1 · 2026-10-26 10:00:00 · 00:20 · наверх, очки 10"), "прошлый ниже")
	ok(not text.contains("очки 1\n"), "короткий забег не записан")
	var again := RunTimeline.new()
	again.path = TEST_PATH
	again._load()
	eq(again._old.size(), 2, "файл читается обратно")
	eq(again._n, 2, "номер продолжается")


func test_keep_last_runs() -> void:
	var r := RunTimeline.new()
	r.path = TEST_PATH
	for i in RunTimeline.KEEP + 3:
		r.begin(i * 100.0)
		r.watch(i * 100.0 + 30.0, {}, 100.0, 0.0)
		r.finish(i * 100.0 + 30.0, "наверх")
	var again := RunTimeline.new()
	again.path = TEST_PATH
	again._load()
	eq(again._old.size(), RunTimeline.KEEP, "в файле последние KEEP")
	ok(again._old[0].begins_with("Забег %d · " % (RunTimeline.KEEP + 3)), "первый — самый свежий")


func test_unfinished_saved_then_completed() -> void:
	var r := RunTimeline.new()
	r.path = TEST_PATH
	r.begin(0.0)
	r.watch(30.0, {"пробоина": true}, 100.0, 0.0)
	r.save("2026-10-26 11:00:00")   # свернули игру
	var text := FileAccess.get_file_as_string(TEST_PATH)
	ok(text.begins_with("Забег 1 · 2026-10-26 11:00:00 · 00:30 · не закончен"),
		"недописанный — шапка как у законченных (#692): %s" % text)
	ok(r._on.has("пробоина") and r.spans[0][2] < 0.0, "запись не закрыла идущую пробоину")
	r.watch(50.0, {"пробоина": false}, 100.0, 0.0)   # вернулись и доиграли
	r.finish(60.0, "наверх")
	text = FileAccess.get_file_as_string(TEST_PATH)
	ok(text.begins_with("Забег 1 · 01:00 · наверх"), "дописан вместо недописанного: %s" % text)
	ok(not text.contains("не закончен"), "недописанного больше нет")
	ok(text.contains("00:50 пробоина — кончилось (00:20)"), "пробоина закрыта по-настоящему")


## #692: сценарий тестера ставит износ корпуса — это не удар.
func test_set_hull_not_a_hit() -> void:
	var r := _tl()
	r.begin(0.0)
	r.watch(1.0, {}, 100.0, 0.0)
	r.set_hull(2.0, 30.0)
	r.watch(2.0, {}, 30.0, 0.0)
	r.set_hull(3.0, 15.0)
	r.watch(3.0, {}, 15.0, 0.0)
	r.watch(4.0, {}, 5.0, 0.0)   # а это настоящий удар
	var lines := r.finish(20.0, "наверх")
	ok(lines.has("00:02 корпус задан: 30%"), "износ сценария помечен: %s" % [lines])
	ok(not lines.has("00:02 удар: корпус 30%"), "и не удар")
	ok(lines.has("00:04 удар: корпус 5%"), "настоящий удар остался")
	ok(lines[-1].contains("ударов 1"), "в сводке один удар: %s" % lines[-1])


## #692: перегрев на кадр снимка (00:00) — мигание, в ленту и сводку не идёт; идущие рядом не сбиваются.
func test_blink_dropped() -> void:
	var r := _tl()
	r.begin(0.0)
	r.watch(5.0, {"пробоина": true, "перегрев": false}, 100.0, 0.0)
	r.watch(10.0, {"пробоина": true, "перегрев": true}, 100.0, 0.0)
	r.watch(10.2, {"пробоина": true, "перегрев": false}, 100.0, 0.0)
	r.watch(20.0, {"пробоина": false, "перегрев": false}, 100.0, 0.0)
	var lines := r.finish(30.0, "наверх")
	for l in lines:
		ok(not l.contains("перегрев"), "мигнувшего перегрева нет: %s" % l)
	ok(lines.has("00:20 пробоина — кончилось (00:15)"), "пробоина закрыта своим отрезком: %s" % [lines])
	eq(r.spans.size(), 1, "один отрезок")


func test_unfinished_without_stamp_same_header() -> void:
	var r := RunTimeline.new()
	r.path = TEST_PATH
	r.begin(0.0)
	r.watch(23.0, {}, 100.0, 0.0)
	r.save()
	var head := FileAccess.get_file_as_string(TEST_PATH).get_slice("\n", 0)
	eq(head, "Забег 1 · 00:23 · не закончен", "без даты — тот же разделитель")


func test_old_unfinished_header_loads() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("Забег 3, не закончен · 00:23 · идёт\n00:00 начало\n\nЗабег 2 · 00:11 · корпус разрушен\n")
	f.close()
	var r := RunTimeline.new()
	r.path = TEST_PATH
	r._load()
	eq(r._n, 3, "номер из старой шапки")
	eq(r._old.size(), 2)


func test_killed_run_stays_in_file() -> void:
	var r := RunTimeline.new()
	r.path = TEST_PATH
	r.begin(0.0)
	r.watch(30.0, {}, 100.0, 0.0)
	r.save()   # и игру убили
	var next := RunTimeline.new()
	next.path = TEST_PATH
	next._load()
	eq(next._old.size(), 1, "недописанный остался записью")
	eq(next._n, 1, "следующий — второй")


func test_new_run_after_menu_not_written() -> void:
	var r := _tl()
	r.begin(0.0)   # старт игры: забег начат под меню, шаги не шли
	r.begin(40.0)  # «Погрузиться» через 40 с в меню
	eq(r._n, 0, "пустой забег из-под меню не записан")
	r.watch(70.0, {}, 100.0, 0.0)
	r.begin(80.0)  # новый забег посреди
	eq(r._n, 1, "прерванный записан")
	ok(r._old[0].contains("00:30 · прерван новым забегом"), "длина — по последнему шагу: %s" % r._old[0])


func test_scene_breach_and_surface() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.timeline.running, "забег идёт с начала игры")
	for i in 20:
		main.step(0.1)
	main.open_breach(0)
	for i in 30:
		main.step(0.1)
	ok(main.timeline._on.has("пробоина"), "пробоина в хронометраже")
	main.breach.reset()
	main.step(0.1)
	ok(not main.timeline._on.has("пробоина"), "и кончилась")
	for i in 100:
		main.step(0.1)
	main.decide("up")
	ok(not main.timeline.running, "итог «наверх» закрыл забег")
	eq(main.timeline._n, 1, "забег записан")
	ok(main.timeline._old[0].contains("пробоина — кончилось (00:03)"), "в ленте: %s" % main.timeline._old[0])
	ok(main.timeline._old[0].contains("наверх, очки"), "итог в заголовке")
	main.queue_free()
	await frames(1)


func test_legs_between_places() -> void:
	var r := _tl()
	r.begin(0.0)
	var p00 := LayerMap.xz("00")
	var p01 := LayerMap.xz("01")
	var p07 := LayerMap.xz("07")
	r.place(1.0, p00.x, p00.y)      # старт у 00
	r.place(30.0, 0.0, 30.0)        # между местами — не место
	r.place(70.0, p01.x, p01.y)     # 00→01 за 69 с
	r.place(80.0, 0.0, 30.0)
	r.place(90.0, p01.x, p01.y)     # вернулся к тому же — не участок
	r.place(250.0, p07.x, p07.y)    # 01→07 за 180 с от прихода к 01
	eq(r.legs.size(), 2, "два участка")
	eq(r.legs[0], ["00", "01", 69.0])
	eq(r.legs[1], ["01", "07", 180.0])
	var lines := r.finish(260.0, "наверх")
	ok(lines.has("Участки: 00→01 01:09 · 01→07 03:00"), "участки в сводке: %s" % "\n".join(lines))
	r.begin(300.0)
	eq(r.legs.size(), 0, "новый забег — участки с нуля")


func test_no_legs_line_without_places() -> void:
	var r := _tl()
	r.begin(0.0)
	r.place(5.0, LayerMap.xz("00").x, LayerMap.xz("00").y)
	for l in r.finish(60.0, "наверх"):
		ok(not l.begins_with("Участки"), "одно место — участков нет")


func test_place_at_ids() -> void:
	eq(RunTimeline.place_at(LayerMap.xz("10").x, LayerMap.xz("10").y), "10")
	eq(RunTimeline.place_at(LayerMap.xz("04").x, LayerMap.xz("04").y), "04")
	eq(RunTimeline.place_at(0.0, 30.0), "", "между 00 и 01 — не место")


func test_scene_leg_from_start() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.1)
	eq(main.timeline._place, "00", "забег начался у старта")
	var p := LayerMap.xz("01")
	main.helm.pos = Vector3(p.x, main.helm.pos.y, p.y)
	main.step(0.1)
	eq(main.timeline.legs.size(), 1, "пришли к 01 — участок")
	eq(main.timeline.legs[0][1], "01")
	main.queue_free()
	await frames(1)
