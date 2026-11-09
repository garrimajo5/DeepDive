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


## Кооп: снимок хоста по сети (как в кадре) — гость видит ту же плашку и ход проверки, свои часы не ведёт.
func _net(host: Comms, guest: Comms) -> void:
	guest.apply(bytes_to_var(var_to_bytes(host.pack())))


func test_guest_follows_host_plate() -> void:
	var h := Comms.new()
	h.reset_run(3)
	var g := Comms.new()
	g.follow = true
	g.code = ""
	_net(h, g)
	eq(g.code, h.code, "кодовое слово забега — хоста")
	ok(not g.active(), "сообщения нет")
	h.push(Crew.Role.PILOT, "Дайте импульс", true, "ping")
	_run(h, 0.5)
	_net(h, g)
	_run(g, 0.5)
	ok(g.active() and g.a > 0.99, "плашка у гостя")
	eq([g.title(), g.line(), g.code_line(), g.button_text()], [h.title(), h.line(), h.code_line(), h.button_text()],
		"те же строки")
	eq(h.pack()["m"][4], "", "ответ подделки до вопроса не едет")
	g.update(DT, true)
	_run(g, 0.3, true)
	ok(g.a <= 0.0, "у гостя связь отложена своим экраном — плашка тает")
	_run(g, 0.3)
	ok(_ask(g), "кнопка взяла касание")
	eq(g.state, Comms.Ask.NONE, "гость сам проверку не начинает")
	eq(g.asked, h.cur.id, "нажатие — сообщению хоста")
	ok(not h.press(h.cur.id + 1), "старое нажатие не действует")
	ok(h.press(g.asked), "хост принял нажатие гостя")
	_run(h, 1.05)
	_net(h, g)
	eq(g.state, Comms.Ask.WRONG, "у гостя — ответ с чужим кодом")
	eq(g.code_line(), h.code_line(), "тот же чужой код")
	_run(h, 1.55)
	_net(h, g)
	eq(g.line(), "Это был не наш", "разоблачение у гостя")
	eq(g.exposed, 1)
	g.asked = 0
	ok(_ask(g) and g.asked == h.cur.id, "«Понятно» гостя")
	ok(h.press(g.asked) and h.closing, "закрывает у всех")
	_run(h, 0.3)
	ok(not h.active(), "у хоста плашка ушла")
	_net(h, g)
	ok(g.closing, "у гостя тает")
	_run(g, 0.3)
	ok(not g.active(), "и уходит")


func test_guest_new_message_by_id() -> void:
	var h := Comms.new()
	h.reset_run(0)
	var g := Comms.new()
	g.follow = true
	h.push(Crew.Role.ENGINEER, "Первое")
	h.push(Crew.Role.BIOLOGIST, "Второе")
	_run(h, 0.2)
	_net(h, g)
	var first := g.cur
	eq(g.line(), "Первое")
	_run(h, Comms.MIN_SHOW + 0.5)
	_net(h, g)
	eq(g.line(), "Второе", "следующее сообщение хоста")
	ok(g.cur != first and g.cur.role == Crew.Role.BIOLOGIST, "новое — с начала")
	g.apply(null)
	g.apply({"k": "Маяк", "m": [1, 2]})   # битый снимок
	eq(g.code, "Маяк", "код берём, битое сообщение — плашка тает")
	ok(g.closing)


func test_scene_mate_ask_reaches_host() -> void:   # «Спросить код» товарища (гость по сети — Pad.ask) — у хоста
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var mate: Crew.Member = main.add_mate(-1.0, 4.0, 0.0, Crew.Role.BIOLOGIST, 1)
	main.on_eco_event(EcoLink.voice(Crew.Role.ENGINEER, "Сбросьте ход"))
	for i in 10:
		main.step(DT)
	mate.pad.apply({"ask": main.comms.cur.id})
	main.step(DT)
	eq(main.comms.state, Comms.Ask.WAIT, "нажатие товарища начало проверку")
	eq(mate.pad.ask, 0, "нажатие съедено")


## Ближайшая точка прямоугольника к центру круга дальше радиуса — не пересекаются.
static func _clear(r: Rect2, c: Touch.Circle) -> bool:
	var q := Vector2(clampf(c.c.x, r.position.x, r.end.x), clampf(c.c.y, r.position.y, r.end.y))
	return q.distance_to(c.c) > c.r


func test_plate_clear_of_controls_with_cutout() -> void:   # issue #603: вырез сдвигал крестовину под плашку
	var cases := [Rect2(133, 0, 2267, 1080), Rect2(0, 0, 2400, 1080), Rect2(133, 0, 2134, 1080),
		Rect2(0, 0, 2240, 1080), Rect2(0, 0, 1920, 1080), Rect2(0, 0, 1600, 720), Rect2(90, 0, 1510, 720)]
	for safe: Rect2 in cases:
		var lay := Touch.Layout.new()
		lay.compute(safe)
		eq(lay.area, safe, "раскладка помнит безопасную область")
		var plate := Comms.plate_rect(lay.area.size)
		plate.position += lay.area.position
		var b := Comms.button_rect(lay.area.size)
		b.position += lay.area.position
		ok(plate.encloses(b), "%s: кнопка внутри плашки" % safe)
		for name in ["pad", "action", "light", "up", "down"]:
			ok(_clear(plate, lay.get(name)), "%s: плашка не на «%s»" % [safe, name])
	var cut := Touch.Layout.new()
	cut.compute(Rect2(133, 0, 2267, 1080))
	ok(not _clear(Comms.plate_rect(Vector2(2400, 1080)), cut.pad), "по всему экрану, а не по области, — наезжала (как в отчёте)")


func test_scene_plate_in_safe_area() -> void:   # issue #603: на телефоне с вырезом плашка — от безопасной области
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var vis := main.get_viewport().get_visible_rect()
	var safe := Rect2(vis.position + Vector2(vis.size.x * 0.06, 0.0), vis.size - Vector2(vis.size.x * 0.06, 0.0))
	main.overlay.router.layout.compute(safe)
	eq(main.comms_area(), safe, "плашка раскладывается по безопасной области")
	main.comms.reset_run(0)
	main.on_eco_event(EcoLink.voice(Crew.Role.ENGINEER, "Сбросьте ход, перегрев"))
	for i in 10:
		main.step(DT)
	eq(main.comms_panel.area, safe, "панель рисует от неё же")
	var plate := Comms.plate_rect(safe.size)
	plate.position += safe.position
	ok(_clear(plate, main.overlay.router.layout.pad), "плашка не на крестовине")
	var b := Comms.button_rect(safe.size)
	b.position += safe.position
	ok(main.overlay.router.blocks.has(b), "кнопка держит касания на своём месте")
	main.overlay.router.taps.append(b.get_center())
	main.step(DT)
	eq(main.comms.state, Comms.Ask.WAIT, "касание «Спросить код» по сдвинутой кнопке дошло")
