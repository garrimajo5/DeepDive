extends TestCase
## Внутренняя связь ART-040: очередь и показ не меньше 8 с, «Код: слово» у своего и «Код: …» у подделки, проверка
## одной кнопкой («Код совпал» / чужой код → «Это был не наш» → «Понятно», молчание — «Нет ответа»), откладывание при
## модальных экранах, места плашки на широком и узком экране, касания кнопки не крутят взгляд.

const SIZE := Vector2(2400, 1080)
const DT := 1.0 / 30.0

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func _run(c: Comms, s: float, hidden := false) -> void:
	for i in int(round(s / DT)):
		c.update(DT, hidden)


func _ask(c: Comms) -> bool:
	return c.tap(Comms.button_rect(SIZE).get_center(), SIZE)


func test_code_word_per_run() -> void:
	var c := Comms.new()
	c.reset_run(1)
	eq(c.code, Comms.WORDS[1], "слово по числу забега")
	c.reset_run(1 + Comms.WORDS.size())
	eq(c.code, Comms.WORDS[1], "по кругу")
	c.reset_run(-1)
	eq(c.code, Comms.WORDS[-1], "отрицательное число — тоже слово")
	for w: String in Comms.WORDS:
		ok(w.length() <= 6, "короткое слово: %s" % w)


func test_real_message_shows_code_and_stays_8s() -> void:
	var c := Comms.new()
	c.reset_run(0)
	c.push(Crew.Role.ENGINEER, "Сбросьте ход, перегрев")
	_run(c, 0.2)
	near(c.a, 1.0, 1e-6, "вошла за 0,15 с")
	eq(c.title(), "Инженер", "роль")
	eq(c.line(), "Сбросьте ход, перегрев", "команда")
	eq(c.code_line(), "Код: Иней", "своё сообщение — код забега")
	eq(c.button_text(), "Спросить код", "кнопка")
	ok(c.speaking(), "речь идёт — индикатор движется")
	_run(c, 7.5)
	ok(c.cur != null and not c.closing, "8 с ещё не прошло")
	ok(not c.speaking(), "речь кончилась — штрихи стоят")
	_run(c, 0.35)
	ok(c.closing, "после 8 с плашка уходит")
	_run(c, 0.25)
	ok(c.cur == null and c.a == 0.0, "ушла за 0,15 с")


func test_long_speech_holds_longer() -> void:
	var c := Comms.new()
	c.push(Crew.Role.SONAR, "Контакт по курсу, держите ход, я веду его сонаром и скажу, когда он уйдёт за гряду, а пока свет не включайте и не шумите")
	ok(c.queue[0].show_time() > Comms.MIN_SHOW, "длинная речь — речь + 2 с")
	eq(c.queue[0].show_time(), c.queue[0].speech + Comms.AFTER_SPEECH, "ровно речь + 2 с")


func test_queue_one_plate() -> void:
	var c := Comms.new()
	c.push(Crew.Role.PILOT, "Первое")
	c.push(Crew.Role.BIOLOGIST, "Второе")
	_run(c, 1.0)
	eq(c.line(), "Первое", "одна плашка — первое")
	eq(c.queue.size(), 1, "второе ждёт в очереди, не стопкой")
	_run(c, 7.5)
	eq(c.line(), "Второе", "после первого — второе")
	for i in 10:
		c.push(0, "лишнее %d" % i)
	eq(c.queue.size(), Comms.QUEUE_MAX, "очередь не растёт без конца")


func test_fake_without_code_and_exposed() -> void:
	var c := Comms.new()
	c.reset_run(0)
	c.push(Crew.Role.PILOT, "Дайте импульс", true, "ping")
	_run(c, 0.5)
	eq(c.code_line(), "Код: …", "подделка — вариант А: «Код: …»")
	eq(c.title(), "Пилот", "та же плашка, та же роль")
	ok(_ask(c), "кнопка взяла касание")
	eq(c.state, Comms.Ask.WAIT, "ждём ответ")
	eq(c.code_line(), "Ждём ответ…", "нижняя строка")
	eq(c.button_text(), "Проверяем", "кнопка")
	ok(not c.button_live(), "кнопка погашена")
	_run(c, 1.05)
	eq(c.state, Comms.Ask.WRONG, "ответ с чужим кодом")
	ok(c.code_line() != "Код: Иней" and c.code_line().begins_with("Код: "), "показан чужой код: %s" % c.code_line())
	eq(c.button_text(), "Код не совпал", "кнопка")
	_run(c, 1.55)
	eq(c.state, Comms.Ask.EXPOSED, "подтверждено — «Это был не наш»")
	eq([c.title(), c.line(), c.code_line(), c.button_text()], ["Связь", "Это был не наш", "Код не совпал", "Понятно"],
		"строки разоблачения")
	eq(c.exposed, 1, "разоблачение посчитано")
	ok(not c.sub_wanted(SIZE), "без «· экипаж»")
	ok(_ask(c), "«Понятно»")
	ok(c.closing, "закрыла плашку")


func test_exposed_closes_itself() -> void:
	var c := Comms.new()
	c.push(Crew.Role.PILOT, "Свет на полную", true, "light")
	_run(c, 0.3)
	_ask(c)
	_run(c, Comms.ANSWER_TIME + Comms.WRONG_TIME + 0.2)
	eq(c.state, Comms.Ask.EXPOSED, "разоблачение")
	_run(c, Comms.EXPOSED_TIME)
	ok(c.closing, "через 4 с плашка уходит сама")


func test_real_answer_matches() -> void:
	var c := Comms.new()
	c.reset_run(3)
	c.push(Crew.Role.ENGINEER, "Сбросьте ход")
	_run(c, 0.3)
	_ask(c)
	_run(c, 1.05)
	eq(c.state, Comms.Ask.MATCH, "свой отвечает своим кодом")
	eq(c.code_line(), "Код совпал", "строка")
	eq(c.button_text(), "Проверено", "кнопка")
	ok(not _ask(c) or c.state == Comms.Ask.MATCH, "повторное нажатие ничего не ломает")
	eq(c.exposed, 0, "не разоблачение")


func test_wait_pins_plate() -> void:
	var c := Comms.new()
	c.push(Crew.Role.ENGINEER, "Сбросьте ход", true, "", true)
	_run(c, 7.9)
	_ask(c)
	_run(c, 1.0)
	ok(not c.closing, "пока ждём ответа, плашка закреплена — 8 с не закрывают")
	_run(c, Comms.SILENT_TIME)
	eq(c.state, Comms.Ask.SILENT, "молчание")
	eq(c.code_line(), "Нет ответа", "«Нет ответа»")
	eq(c.exposed, 0, "нет ответа — не разоблачение")
	ok(c.button_live(), "можно спросить снова")
	eq(c.button_text(), "Спросить код", "кнопка снова живая")


func test_hidden_defers_and_stops_clock() -> void:
	var c := Comms.new()
	c.push(Crew.Role.ENGINEER, "Сбросьте ход")
	_run(c, 1.0)
	var t := c.cur.t
	_run(c, 20.0, true)
	eq(c.a, 0.0, "при голосовании и меню — растаяла")
	eq(c.cur.t, t, "часы чтения стоят, пока не видно")
	ok(not c.closing, "сообщение не пропало")
	ok(not _ask(c), "скрытую кнопку не нажать")
	eq(c.blocks(SIZE), [] as Array[Rect2], "скрытая не держит касания")
	_run(c, 0.2)
	near(c.a, 1.0, 1e-6, "снова видно")


func test_layout_wide_and_narrow() -> void:
	eq(Comms.plate_rect(SIZE), Rect2(520, 720, 1260, 310), "2400×1080 — по макету")
	eq(Comms.button_rect(SIZE), Rect2(1360, 886, 380, 112), "кнопка")
	eq(Comms.bars_rect(SIZE).position.x, 1615.0, "индикатор")
	var c := Comms.new()
	c.push(0, "x")
	_run(c, 0.2)
	ok(c.sub_wanted(SIZE), "широкий экран — «· экипаж»")
	var n := Vector2(1920, 1080)
	eq(Comms.plate_rect(n), Rect2(520, 680, 780, 350), "16:9 — выше и уже")
	eq(Comms.button_rect(n).position, Vector2(880, 886), "кнопка у правого края")
	eq(Comms.code_at(n).y, 834.0, "код над кнопкой")
	ok(not c.sub_wanted(n), "узкий — без «· экипаж»")
	var half := Vector2(1200, 540)
	eq(Comms.plate_rect(half), Rect2(260, 360, 630, 155), "масштаб H/1080")
	# управление не перекрыто: крестовина слева, «Вверх/Вниз» и «Действие» справа
	for size: Vector2 in [SIZE, Vector2(2340, 1080), n, Vector2(2400, 1080) * 0.5]:
		var l := Touch.Layout.new()
		l.compute(Rect2(Vector2.ZERO, size))
		var p := Comms.plate_rect(size)
		ok(l.pad.c.x + l.pad.r <= p.position.x, "крестовина левее плашки при %s" % size)
		ok(l.down.c.x - l.down.r >= p.end.x and l.up.c.x - l.up.r >= p.end.x, "«Вверх/Вниз» правее при %s" % size)
		ok(p.end.y <= size.y, "плашка в экране")


func test_scene_voice_plate_and_taps() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.comms.reset_run(0)
	main.on_eco_event(EcoLink.voice(Crew.Role.ENGINEER, "Сбросьте ход, перегрев"))
	for i in 10:
		main.step(DT)
	ok(main.comms_panel.visible, "плашка на экране")
	var size := main.get_viewport().get_visible_rect().size
	var b := Comms.button_rect(size)
	ok(main.overlay.router.blocks.has(b), "кнопка не крутит взгляд")
	main.overlay.router.taps.append(b.get_center())
	main.step(DT)
	eq(main.comms.state, Comms.Ask.WAIT, "касание «Спросить код» дошло")
	main.open_vote()
	for i in 10:
		main.step(DT)
	ok(not main.comms_panel.visible, "при голосовании связь отложена")
	eq(main.comms.state, Comms.Ask.WAIT, "проверка не прошла, пока не видно")


func test_scene_new_run_clears() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.on_eco_event(EcoLink.voice(Crew.Role.PILOT, "Свет на полную", true, "light"))
	main.step(DT)
	ok(main.comms.active(), "сообщение есть")
	main._restart()
	ok(not main.comms.active() and main.comms.queue.is_empty(), "новый забег — связь с чистого листа")
	ok(Comms.WORDS.has(main.comms.code), "новое кодовое слово из списка")
