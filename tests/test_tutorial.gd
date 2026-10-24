extends TestCase
## Подсказки первого забега ART-038: шесть шагов по событиям своего игрока, «Выполнено» 0,5 с, промежуточные фразы,
## обводка управления, скрытие под тревогой, место плашки, запоминание пройденного.

var main: Main


func after() -> void:
	Main.hints = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func _pass(t: Tutorial, ev: Tutorial.Ev) -> void:
	ok(t.note(ev), "событие %d засчитано" % ev)
	t.update(Tutorial.DONE_TIME + 0.01, false)


func test_steps_in_order() -> void:
	var t := Tutorial.new()
	eq(t.step_line(), "Первый забег · 1 / 6", "первый шаг")
	eq(t.text(false, ""), "Подойдите к штурвалу — кнопка справа", "текст шага 1 по макету")
	ok(not t.note(Tutorial.Ev.LIGHT), "событие другого шага не считается")
	ok(t.note(Tutorial.Ev.SAT), "сел за штурвал — шаг 1")
	ok(not t.note(Tutorial.Ev.SAT), "второй раз в «Выполнено» не считается")
	eq(t.text(true, ""), Tutorial.DONE, "«Выполнено»")
	eq(t.highlight(true, false, ""), "", "в «Выполнено» ничего не обводим")
	t.update(0.3, false)
	eq(t.step, 0, "по таймеру не листаем раньше 0,5 с")
	t.update(0.25, false)
	eq(t.step, 1, "после «Выполнено» — шаг 2")
	eq(t.highlight(true, false, ""), "up", "шаг хода — верх крестовины")
	_pass(t, Tutorial.Ev.THRUST)
	eq(t.highlight(true, false, ""), "light", "шаг света — «Свет»")
	_pass(t, Tutorial.Ev.LIGHT)
	eq(t.text(true, ""), Tutorial.STAND_UP, "сидит перед шагом энергии — «Встать»")
	eq(t.highlight(true, false, ""), "action", "обведена кнопка «Встать»")
	eq(t.text(false, "energy"), Tutorial.AT_POWER, "у пульта до открытия")
	eq(t.text(false, ""), "Пульт энергии: крестовиной меняйте доли", "иначе — текст шага")
	eq(t.highlight(false, true, ""), "pad", "у открытого пульта — крестовина")
	_pass(t, Tutorial.Ev.SHARE)
	eq(t.highlight(false, false, "helm"), "", "не у голостола — кнопку не обводим")
	eq(t.highlight(false, false, "sonar"), "action", "у голостола — «Сонар»")
	_pass(t, Tutorial.Ev.PING)
	eq(t.target(), "route", "цель — пост «Маршрут»")
	ok(t.note(Tutorial.Ev.ROUTE), "маршрут выбран")
	ok(t.update(Tutorial.DONE_TIME + 0.01, false), "пройдено целиком — сообщает один раз")
	ok(t.finished() and not t.active() and not t.shown(), "больше не показывается")
	ok(not t.update(0.1, false), "второй раз не сообщает")


func test_hidden_keeps_step_and_fades() -> void:
	var t := Tutorial.new()
	t.update(Tutorial.FADE * 0.5, false)
	near(t.a, 0.5, 1e-4, "появляется за 0,15 с")
	t.update(1.0, false)
	eq(t.a, 1.0, "видна")
	t.update(1.0, true)
	eq(t.a, 0.0, "тревога — скрыта")
	eq(t.step, 0, "шаг сохраняется")
	t.on = false
	t.update(1.0, false)
	ok(not t.shown(), "выключенное обучение не показывается")
	ok(not t.note(Tutorial.Ev.SAT), "и шагов не считает")


func test_box_scale_and_status() -> void:
	var b := Tutorial.box(Vector2(2400, 1080))
	eq(b, Rect2(520, 32, 1360, 174), "плашка по макету")
	var c := Tutorial.box(Vector2(1600, 720))
	near(c.get_center().x, 800.0, 1e-3, "по центру экрана")
	near(c.size.y, 116.0, 1e-3, "масштаб H/1080")
	var status := Rect2(14, 9, 700, 60)
	var d := Tutorial.box(Vector2(1600, 720), status)
	ok(not d.intersects(status), "на строку приборов не ложится")
	near(d.position.y, status.end.y + Tutorial.GAP * 720.0 / 1080.0, 1e-3, "сразу под ней")
	var panel := Rect2(1010, 124, 560, 330)   # пульт энергии справа
	var e := Tutorial.box(Vector2(1600, 720), status, panel)
	ok(not e.intersects(panel) and not e.intersects(status), "открытый пульт — плашка левее него")
	ok(e.position.x >= 16.0, "в краях экрана")
	var wide := Rect2(200, 50, 1300, 300)
	var f := Tutorial.box(Vector2(1600, 720), Rect2(), wide)
	ok(not f.intersects(wide), "не помещается сбоку — под панелью")
	var narrow := Tutorial.box(Vector2(800, 720))
	ok(narrow.position.x >= 16.0 and narrow.end.x <= 784.0, "узкий экран — в краях")
	ok(Tutorial.TEXT_PX >= 36.0, "основной кегль не меньше 36 px при H = 1080")


func test_rings() -> void:
	var l := Touch.Layout.new()
	l.compute(Rect2(0, 0, 1600, 720))
	eq(Tutorial.ring_of("action", l), l.action, "кнопка действия")
	eq(Tutorial.ring_of("light", l), l.light, "«Свет»")
	var up := Tutorial.ring_of("up", l)
	ok(l.pad.has(up.c) and up.c.y < l.pad.c.y and up.c.x == l.pad.c.x, "верх крестовины — внутри круга сверху")
	ok(up.c.distance_to(l.pad.c) + up.r <= l.pad.r, "обводка стрелки не выходит за крестовину")
	eq(Tutorial.ring_of("", l), null, "нечего обводить")


func test_settings_remember() -> void:
	var path := "user://test_podskazki.cfg"
	var s := Settings.new()
	s.path = path
	ok(not s.hints_done, "по умолчанию не пройдено")
	s.hints_done = true
	ok(s.write(), "записано")
	var u := Settings.new()
	u.path = path
	ok(u.read() and u.hints_done, "пройденное помнится")
	DirAccess.remove_absolute(path)


func _tick(n: int = 1) -> void:
	for i in n:
		main.step(1.0 / 30.0)


func test_scene_six_steps() -> void:
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var t := main.tutorial
	ok(t.on, "в первом забеге включено")
	_tick(10)
	ok(main.tutorial_panel.visible, "плашка на экране")
	main.walker.x = 0.0
	main.walker.z = Deck.CHAIR_Z
	_tick()
	eq(main.tutorial_panel.ring, "action", "у штурвала обведена кнопка «Штурвал»")
	main.use_post("helm")
	eq(t.done_t >= 0.0, true, "сел — шаг 1 выполнен")
	_tick(20)
	eq(t.step, 1, "шаг 2")
	var r := main.overlay.router
	r.move = Vector2i(0, 1)
	_tick()
	r.move = Vector2i.ZERO
	_tick(20)
	eq(t.step, 2, "ход дан — шаг 3")
	r.light_pressed = true
	_tick()
	_tick(20)
	eq(t.step, 3, "прожектор переключён — шаг 4")
	eq(main.tutorial_panel.line, Tutorial.STAND_UP, "сидит — «Нажмите «Встать»…»")
	main.stand_up()
	main.open_power()
	r.move = Vector2i(-1, 0)   # убавить долю: свободной энергии на старте нет
	_tick(10)
	r.move = Vector2i.ZERO
	main.close_power()
	_tick(20)
	eq(t.step, 4, "доля изменена — шаг 5")
	main.vitals.energy = 100.0
	main.use_post("sonar")
	_tick(20)
	eq(t.step, 5, "импульс прошёл — шаг 6")
	main.use_post("route")
	_tick(20)
	ok(t.finished(), "маршрут выбран — обучение пройдено")
	ok(main.settings.hints_done, "запомнено в настройках")
	ok(not main.tutorial_panel.visible, "плашки больше нет")


func test_scene_light_by_mate_not_counted() -> void:
	# свет, переключённый без своего нажатия, шаг не засчитывает; тревога прячет плашку, шаг стоит
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.tutorial.step = 2
	main.toggle_light()
	_tick(20)
	eq(main.tutorial.step, 2, "свет не своим нажатием за штурвалом — не засчитан")
	ok(main.tutorial_panel.visible, "плашка видна")
	main.open_breach(0)
	_tick(10)
	ok(not main.tutorial_panel.visible, "пробоина — плашка скрыта")
	eq(main.tutorial.step, 2, "шаг сохранён")


func test_scene_off_in_tests_and_done() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(not main.tutorial.on, "раннер выключил подсказки")
	_tick(5)
	ok(not main.tutorial_panel.visible, "плашки нет")


func test_guest_skips_sonar() -> void:   # у гостя сети шага сонара нет: «… / 5», с маршрута — сразу после энергии
	var t := Tutorial.new()
	t.set_guest(true)
	eq(t.step_line(), "Первый забег · 1 / 5", "у гостя пять шагов")
	_pass(t, Tutorial.Ev.SAT)
	_pass(t, Tutorial.Ev.THRUST)
	_pass(t, Tutorial.Ev.LIGHT)
	eq(t.step_line(), "Первый забег · 4 / 5", "энергия — четвёртый")
	_pass(t, Tutorial.Ev.SHARE)
	eq(t.target(), "route", "после энергии — маршрут, сонар пропущен")
	eq(t.step_line(), "Первый забег · 5 / 5")
	ok(t.note(Tutorial.Ev.ROUTE), "маршрут")
	ok(t.update(Tutorial.DONE_TIME + 0.01, false) and t.finished(), "пройдено без сонара")
	var s := Tutorial.new()
	s.step = 4   # стоял на сонаре в своей игре и вошёл к хосту
	s.set_guest(true)
	eq(s.target(), "route", "шаг сонара у гостя сразу пропущен")
	s.set_guest(false)
	eq(s.step_line(), "Первый забег · 6 / 6", "в своей игре снова шесть")


func test_guest_events_by_host_frame() -> void:
	var g := Tutorial.Guest.new()
	var sh: Array = [2, 2, 2, 2, 2]
	var dt := 1.0 / 30.0
	eq(g.update(dt, false, false, "helm", Vector2.ZERO, false, false, false, sh, -1), [], "первый шаг — только запомнить")
	eq(g.update(dt, true, false, "helm", Vector2.ZERO, false, false, false, sh, -1), [Tutorial.Ev.SAT],
		"кадр: свой пост — за штурвалом")
	eq(g.update(dt, true, false, "", Vector2(0, 1), false, false, false, sh, -1), [Tutorial.Ev.THRUST],
		"своя крестовина вверх за штурвалом")
	eq(g.update(dt, true, false, "", Vector2.ZERO, false, false, true, sh, -1), [],
		"свет сменился без своего нажатия — не считается")
	eq(g.update(dt, true, false, "", Vector2.ZERO, true, false, true, sh, -1), [], "нажал «Свет» — ждём кадр")
	eq(g.update(0.5, true, false, "", Vector2.ZERO, false, false, false, sh, -1), [Tutorial.Ev.LIGHT],
		"кадр хоста: свет сменился")
	eq(g.update(dt, false, true, "energy", Vector2(-1, 0), false, false, false, sh, -1), [], "крестовина у пульта")
	eq(g.update(Tutorial.Guest.WAIT + 0.1, false, true, "energy", Vector2.ZERO, false, false, false, sh, -1), [],
		"кадр так и не пришёл")
	var sh2: Array = [1, 2, 2, 2, 2]
	eq(g.update(dt, false, true, "energy", Vector2.ZERO, false, false, false, sh2, -1), [],
		"доли сменились позже ожидания — не своё")
	g.update(dt, false, true, "energy", Vector2(1, 0), false, false, false, sh2, -1)
	eq(g.update(dt, false, true, "energy", Vector2.ZERO, false, false, false, sh, -1), [Tutorial.Ev.SHARE],
		"доли сменились после своей крестовины")
	g.update(dt, false, false, "route", Vector2.ZERO, false, true, false, sh, -1)
	eq(g.update(dt, false, false, "route", Vector2.ZERO, false, false, false, sh, 0), [Tutorial.Ev.ROUTE],
		"кнопка у поста «Маршрут» — маршрут в кадре сменился")
