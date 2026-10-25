extends TestCase
## Рация ART-041: «Нажать и держать» — передача только пока палец на кнопке, меню и пауза обрывают её сразу;
## «Вас слышно» — только когда голос реально уходит; «По голосу» — кнопка вкл/выкл; нет разрешения — «Нет доступа» и
## просьба «В настройки», передача сама не включается; список говорящих — имя держится 0,4 с после пакета, выход 0,15 с,
## до трёх строк, звук товарищей выкл. — пусто; места над «Светом», нижние углы свободны; в игре скрыта до голоса.

const SIZE := Vector2(2400, 1080)
const DT := 1.0 / 30.0

var main: Main


func after() -> void:
	Radio.enabled = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func _radio() -> Radio:
	var r := Radio.new()
	r.on = true
	return r


func test_hold_sends_only_while_down_and_linked() -> void:
	var r := _radio()
	r.update(DT, false, false)
	eq(r.state_text(), "Удерживайте", "покой")
	r.update(DT, true, false)
	ok(r.wants(), "палец на кнопке — хочет говорить")
	ok(not r.sending(), "голоса нет — не уходит")
	eq(r.state_text(), "Нет передачи", "«Вас слышно» не пишем, пока голос не уходит")
	r.link = true
	r.update(DT, true, false)
	ok(r.sending(), "голос уходит")
	eq(r.state_text(), "Вас слышно", "вас слышно")
	r.update(DT, false, false)
	ok(not r.sending(), "отпустил — сразу стоп")
	eq(r.button_text(), "Говорить", "подпись кнопки")


func test_hidden_cuts_transmission() -> void:
	var r := _radio()
	r.link = true
	r.update(DT, true, false)
	ok(r.sending(), "говорит")
	r.update(DT, true, true)
	ok(not r.sending(), "меню/пауза — передача прекращена, хоть палец и на кнопке")
	ok(r.blocks(SIZE).is_empty(), "под меню кнопка не берёт касания")
	r.update(DT, true, false)
	ok(r.sending(), "после паузы — снова держит")
	r.on = false
	r.update(DT, true, false)
	ok(not r.sending(), "рация выключена (не кооп) — молчит")


func test_voice_mode_toggles() -> void:
	var r := _radio()
	r.link = true
	r.mode = Radio.Mode.VOICE
	eq(r.button_text(), "Микрофон", "в режиме «По голосу» — «Микрофон»")
	r.update(DT, true, false)
	ok(r.sending(), "касание включило микрофон")
	r.update(DT, true, false)
	r.update(DT, false, false)
	ok(r.sending(), "держать не нужно")
	r.update(DT, true, false)
	ok(not r.sending(), "второе касание выключило")
	r.update(DT, false, false)
	r.update(DT, true, false)
	ok(r.sending(), "снова вкл")
	r.update(DT, false, true)
	r.update(DT, false, false)
	ok(not r.sending(), "меню выключает микрофон, сам не включается")
	r.mic_on = false
	r.update(DT, true, false)
	ok(not r.sending(), "микрофон выключен в настройках")


func test_no_permission_asks_and_does_not_send() -> void:
	var r := _radio()
	r.link = true
	r.mic = false
	eq(r.state_text(), "Нет доступа", "нет разрешения")
	r.update(DT, true, false)
	ok(not r.sending(), "передача сама не включается")
	ok(r.ask > 0.0, "просим разрешение")
	ok(r.blocks(SIZE).has(Radio.ask_button_rect(SIZE)), "«В настройки» не крутит взгляд")
	ok(r.tap(Radio.ask_button_rect(SIZE).get_center(), SIZE), "касание «В настройки»")
	ok(r.settings_wanted, "просьба ушла в игру")
	eq(r.ask, 0.0, "просьба закрыта")
	r.update(DT, false, false)
	r.update(DT, true, false)
	for i in int(Radio.ASK_TIME / DT) + 2:
		r.update(DT, true, false)
	eq(r.ask, 0.0, "просьба гаснет сама")
	r.mic = true
	r.update(DT, true, false)
	ok(r.wants(), "разрешили — палец на кнопке говорит")


func test_talkers_hold_fade_and_limit() -> void:
	var r := _radio()
	r.heard(1, "Игорь", Crew.Role.ENGINEER)
	r.update(Radio.FADE, false, false)
	eq(r.rows().size(), 1, "заговорил — строка")
	near(r.rows()[0].a, 1.0, 0.001, "вход за 0,15 с")
	r.update(Radio.HOLD - Radio.FADE - 0.01, false, false)
	near(r.rows()[0].a, 1.0, 0.001, "держится 0,4 с после пакета")
	r.update(0.02, false, false)
	r.update(Radio.FADE, false, false)
	eq(r.rows().size(), 0, "затих — ушла за 0,15 с")
	eq(r.talkers.size(), 0, "и из списка")
	for i in 4:
		r.heard(10 + i, "Игрок %d" % i, i)
	r.update(Radio.FADE, false, false)
	eq(r.rows().size(), Radio.ROWS, "не больше трёх строк")
	eq(r.rows()[0].id, 10, "по порядку, кто заговорил первым")
	r.heard(10, "Игрок 0", 0, 0.5, false)
	ok(not r.rows()[0].seen, "за стеной — «Вне поля зрения»")
	eq(r.talkers.size(), 4, "повторный пакет не дублирует строку")
	r.hear = false
	r.update(Radio.FADE, false, false)
	eq(r.rows().size(), 0, "звук товарищей выкл. — список пуст")
	eq(r.state_text(), "Звук выкл.", "строка состояния")


func test_bars_move_only_while_talking() -> void:
	var t := Radio.Talker.new()
	t.level = 1.0
	var a := Radio.bars(t, 0.0)
	var b := Radio.bars(t, 0.2)
	eq(a.size(), 3, "три штриха")
	ok(a != b, "говорит — штрихи движутся")
	t.since = Radio.HOLD + 0.1
	eq(Radio.bars(t, 0.0), Radio.bars(t, 0.3), "замолчал — штрихи стоят")


func test_layout_above_light_and_corners_free() -> void:
	for size: Vector2 in [SIZE, Vector2(1920, 1080), Vector2(1600, 720), Vector2(2340, 1080)]:
		var lay := Touch.Layout.new()
		lay.compute(Rect2(Vector2.ZERO, size))
		var s := Radio.scale(size)
		var b := Radio.button_rect(size)
		ok(b.end.y < lay.light.c.y - lay.light.r, "кнопка выше «Света» %s" % size)
		ok(b.end.x <= size.x and b.position.x > 0.0, "в экране")
		for c: Touch.Circle in [lay.action, lay.up, lay.down, lay.light, lay.pad]:
			ok(not _hits(b, c), "кнопка не на органах управления %s" % size)
		ok(not _hits(b, lay.noclip), "и не на тестовой кнопке")
		ok(b.end.y <= 760.0 * s, "нижние углы — только прежнее управление")
		var st := Radio.state_rect(size)
		ok(st.end.y <= b.position.y and st.position.x == b.position.x, "строка состояния над кнопкой")
		var last := Radio.row_rect(Radio.ROWS - 1, size)
		ok(last.end.x < b.position.x and last.end.x < st.position.x, "список левее кнопки")
		ok(Radio.row_rect(1, size).position.y >= Radio.row_rect(0, size).end.y, "строки не налезают")
		ok(Radio.ask_rect(size).end.x < Radio.row_rect(0, size).position.x, "просьба левее списка")
		ok(Radio.head_at(size).y > 0.0, "заголовок списка на экране")


func _hits(r: Rect2, c: Touch.Circle) -> bool:
	var q := Vector2(clampf(c.c.x, r.position.x, r.end.x), clampf(c.c.y, r.position.y, r.end.y))
	return q.distance_to(c.c) < c.r


func test_router_held_in() -> void:
	var rt := Touch.Router.new()
	rt.layout.compute(Rect2(Vector2.ZERO, SIZE))
	var b := Radio.button_rect(SIZE)
	rt.blocks = [b]
	rt.begin(0, b.get_center())
	ok(rt.held_in(b), "палец на кнопке")
	eq(rt.look, Vector2.ZERO, "взгляд не крутится")
	rt.moved(0, b.get_center() + Vector2(0, b.size.y))
	ok(rt.held_in(b), "сполз с кнопки — держит, пока не отпустил")
	eq(rt.look, Vector2.ZERO, "и взгляд не крутится")
	rt.begin(1, Vector2(1200, 300))
	ok(rt.held_in(b), "второй палец крутит взгляд, первый держит")
	rt.end(0)
	ok(not rt.held_in(b), "отпустил")
	rt.begin(2, Vector2(1200, 300) + Vector2(0, 10))
	ok(not rt.held_in(b), "касание мимо кнопки — не рация")


func test_scene_hidden_until_voice() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(DT)
	ok(not main.radio_panel.visible, "голоса нет — рация в игре скрыта")
	ok(not main.overlay.router.blocks.has(Radio.button_rect(main.get_viewport().get_visible_rect().size)),
		"место кнопки — взгляду")


func test_scene_coop_shows_and_pause_hides() -> void:
	Radio.enabled = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(DT)
	ok(not main.radio_panel.visible, "один — рации нет")
	main.net_mates[7] = main.add_mate(-1.0, 4.0, 0.0, Crew.Role.BIOLOGIST, 1)
	main.step(DT)
	ok(main.radio_panel.visible, "кооп — кнопка на экране")
	var size := main.get_viewport().get_visible_rect().size
	var b := Radio.button_rect(size)
	ok(main.overlay.router.blocks.has(b), "кнопка не крутит взгляд")
	main.overlay.router.begin(0, b.get_center())
	main.step(DT)
	ok(main.radio.wants(), "палец держит «Говорить»")
	main.back_pressed()
	main.step(DT)
	ok(main.pause.open, "пауза")
	ok(not main.radio.wants(), "пауза обрывает передачу")
	ok(not main.radio_panel.visible, "под паузой рации не видно")
	main.overlay.router.end(0)
	main.net_mates.clear()
