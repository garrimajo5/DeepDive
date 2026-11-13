extends TestCase
## Подсказки первого забега ART-038: семь шагов (#1346 — курс к цели) по событиям своего игрока, «Выполнено» 0,5 с, промежуточные фразы,
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
	eq(t.step_line(), "Первый забег · 1 / 7", "первый шаг")
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
	_pass(t, Tutorial.Ev.ROUTE)
	eq(t.target(), "helm", "шаг 7 — снова штурвал")
	eq(t.step_line(), "Первый забег · 7 / 7")
	ok(t.steer(Tutorial.COURSE_TIME + 0.1, true, 1.0, true), "2 с ходом к цели — шаг 7")
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


## шаг по времени крупнее кадра: подсказки ждут секунды (DONE_TIME, COURSE_TIME), не кадры
func _secs(s: float) -> void:
	for i in ceili(s / 0.1 - 0.001):
		main.step(0.1)


func _course_step() -> Tutorial:
	var t := Tutorial.new()
	t.step = Tutorial.STEPS.size() - 1
	return t


func test_route_text_by_place() -> void:   # #1346: шаг 6 — где пост «Маршрут», пока игрок не у него
	var t := Tutorial.new()
	t.step = 5
	eq(t.text(false, "sonar"), "Вправо от голостола — кнопка «Маршрут»", "у голостола на кнопке «Сонар»")
	eq(t.text(false, ""), Tutorial.FIND_ROUTE, "не у поста")
	eq(t.text(false, "route"), "Нажмите «Маршрут» — выберите путь", "у поста «Маршрут»")
	eq(t.highlight(false, false, "sonar"), "", "у «Сонара» кнопку не обводим")
	eq(t.highlight(false, false, "route"), "action", "у поста — кнопка «Маршрут»")
	var tip: Vector3 = HintPointer.ANCHORS["route"]
	near(Vector2(tip.x, tip.z).distance_to(Vector2(0.0, BridgeProps.TABLE_Z)), 1.1, 0.05, "указатель — на кромке стола")
	ok(tip.y < 1.2, "на высоте кромки, а не 1,5 м у стены")
	ok(tip.x > 0.0, "со стороны поста справа")


func test_course_step() -> void:   # #1346: засчитан по курсу и ходу, не стоя и не боком
	var t := _course_step()
	eq(t.text(true, ""), "За штурвалом ведите к цели — стрелка вверху")
	eq(t.highlight(true, false, ""), "goal", "за штурвалом — обведена плашка цели")
	eq(t.highlight(false, false, "helm"), "action", "у штурвала — кнопка «Штурвал»")
	eq(t.text(false, ""), Tutorial.TO_HELM, "не за штурвалом — «Сядьте за штурвал…»")
	eq(t.pointer_target(false), "helm", "указатель на кресло, пока не сел")
	eq(t.pointer_target(true), "", "сел — указателя нет")
	var dt := 1.0 / 30.0
	for i in 120:
		ok(not t.steer(dt, true, 0.0, true), "стоит на месте — не засчитан") if i == 0 else t.steer(dt, true, 0.0, true)
	eq(t.done_t, -1.0, "4 с без хода — не засчитан")
	for i in 120:
		t.steer(dt, true, 1.5, false)
	eq(t.done_t, -1.0, "ход боком к цели — не засчитан")
	for i in 120:
		t.steer(dt, false, 1.5, true)
	eq(t.done_t, -1.0, "не за штурвалом — не засчитан")
	for i in 50:
		t.steer(dt, true, 1.0, true)
	t.steer(dt, true, 1.0, false)   # сбился с курса — счёт заново
	for i in 50:
		t.steer(dt, true, 1.0, true)
	eq(t.done_t, -1.0, "по 1,7 с с перерывом — не засчитан")
	var got := false
	for i in 70:
		got = t.steer(dt, true, 0.6, true) or got
	ok(got and t.done_t >= 0.0, "2 с подряд ходом > 0,5 м/с к цели — «Выполнено»")
	t.update(Tutorial.DONE_TIME + 0.01, false)
	ok(t.finished(), "обучение пройдено")


func test_course_holds_events_max_90s() -> void:   # #1346: события ждут шага 7 не дольше 90 с после выбора маршрута
	var t := Tutorial.new()
	t.step = 5
	ok(t.note(Tutorial.Ev.ROUTE), "маршрут выбран")
	t.update(Tutorial.DONE_TIME + 0.01, false)
	eq(t.step, 6, "шаг 7")
	ok(t.holds_events(), "сразу после выбора — события ждут")
	for i in 89:
		t.update(1.0, i % 2 == 0)   # и под тревогой время идёт
	ok(t.holds_events(), "89,5 с — ещё ждут")
	t.update(0.5, false)
	ok(not t.holds_events(), "90 с — события идут, хоть шаг и не пройден")
	ok(t.active(), "подсказка шага 7 остаётся")


func test_guest_six_steps() -> void:   # #1346: у гостя маршрута нет — без шага 7
	var t := Tutorial.new()
	t.set_guest(true)
	eq(t.step_line(), "Первый забег · 1 / 6")
	t.step = 5
	ok(t.note(Tutorial.Ev.ROUTE), "маршрут — последний шаг гостя")
	ok(t.update(Tutorial.DONE_TIME + 0.01, false), "пройдено")
	ok(t.finished() and not t.holds_events(), "шага 7 нет")


func test_box_under_goal_plate() -> void:   # #1346: подсказка не ложится на плашку цели за штурвалом
	var size := Vector2(2400, 1080)
	var goal := Rect2(900, 32, 600, 88)
	var b := Tutorial.box(size, Rect2(), Rect2(), goal)
	ok(not b.intersects(goal), "под плашкой цели")
	near(b.position.y, goal.end.y + Tutorial.GAP, 1e-3, "с зазором")
	var status := Rect2(16, 16, 700, 160)
	var low := Rect2(1000, 186, 400, 88)   # плашка цели опущена под строку приборов
	var c := Tutorial.box(size, status, Rect2(), low)
	ok(not c.intersects(status) and not c.intersects(low), "ни на строку приборов, ни на плашку цели")


func test_scene_route_hint_beside_card() -> void:   # #1346: у поста «Маршрут» подсказка не ложится на карточку целей
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.arrival.on = false   # брифинг прибытия до подсказок — test_arrival_brief
	main.tutorial.step = 5
	main.walker.x = Main.ROUTE_POST.x + 0.1
	main.walker.z = Main.ROUTE_POST.y
	main.walker.yaw = PI * 0.5
	main.walker.pitch = deg_to_rad(-30.0)
	_secs(2.0)
	eq(main.tutorial_panel.line, "Нажмите «Маршрут» — выберите путь", "у поста — текст поста")
	ok(main.route_card.visible, "карточка целей слоя у стола")
	ok(not main.tutorial_panel.box().intersects(main.route_card.rect), "подсказка не на карточке")


func test_scene_six_steps() -> void:
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.arrival.on = false   # брифинг прибытия до подсказок — test_arrival_brief
	var t := main.tutorial
	ok(t.on, "в первом забеге включено")
	_secs(0.4)
	ok(main.tutorial_panel.visible, "плашка на экране")
	main.walker.x = 0.0
	main.walker.z = Deck.CHAIR_Z
	_tick()
	eq(main.tutorial_panel.ring, "action", "у штурвала обведена кнопка «Штурвал»")
	main.use_post("helm")
	eq(t.done_t >= 0.0, true, "сел — шаг 1 выполнен")
	_secs(0.7)
	eq(t.step, 1, "шаг 2")
	var r := main.overlay.router
	r.move = Vector2i(0, 1)
	_tick()
	r.move = Vector2i.ZERO
	_secs(0.7)
	eq(t.step, 2, "ход дан — шаг 3")
	r.light_pressed = true
	_tick()
	_secs(0.7)
	eq(t.step, 3, "прожектор переключён — шаг 4")
	eq(main.tutorial_panel.line, Tutorial.STAND_UP, "сидит — «Нажмите «Встать»…»")
	main.stand_up()
	main.open_power()
	r.move = Vector2i(-1, 0)   # убавить долю: свободной энергии на старте нет
	_secs(0.4)
	r.move = Vector2i.ZERO
	main.close_power()
	_secs(0.7)
	eq(t.step, 4, "доля изменена — шаг 5")
	main.vitals.energy = 100.0
	main.use_post("sonar")
	_secs(0.7)
	eq(t.step, 5, "импульс прошёл — шаг 6")
	main.near_post = "sonar"
	_tick()
	eq(main.tutorial_panel.line, Tutorial.FIND_ROUTE, "у голостола — «Вправо от голостола…»")
	main.use_post("route")
	_secs(0.7)
	eq(t.step, 6, "маршрут выбран — шаг 7")
	ok(not t.finished() and main.events_held(), "события ещё ждут")
	main.use_post("helm")
	main.helm.yaw = GoalPlate.delta(0.0, Vector2(main.helm.pos.x, main.helm.pos.z), Run.place_xz(main.run.next_key())) \
		* PI / 180.0   # нос на цель
	main.helm.speed = 1.0
	_tick()
	eq(main.goal_plate.kind, GoalPlate.Kind.AHEAD, "плашка цели — «прямо»")
	eq(main.tutorial_panel.ring, "goal", "обведена плашка цели")
	ok(not main.tutorial_panel.box().intersects(main.goal_plate_view.rect), "подсказка не на плашке цели")
	r.move = Vector2i(0, 1)
	_secs(2.5)
	r.move = Vector2i.ZERO
	_secs(0.7)
	ok(t.finished(), "2,5 с ходом к цели — обучение пройдено")
	ok(main.settings.hints_done, "запомнено в настройках")
	ok(not main.tutorial_panel.visible, "плашки больше нет")


func test_scene_light_by_mate_not_counted() -> void:
	# свет, переключённый без своего нажатия, шаг не засчитывает; тревога прячет плашку, шаг стоит
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.arrival.on = false   # брифинг прибытия до подсказок — test_arrival_brief
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
	main.arrival.on = false   # брифинг прибытия до подсказок — test_arrival_brief
	ok(not main.tutorial.on, "раннер выключил подсказки")
	_tick(5)
	ok(not main.tutorial_panel.visible, "плашки нет")


func test_guest_has_sonar_step() -> void:   # импульс гостя идёт хосту — у гостя шесть шагов с сонаром, без курса
	var t := Tutorial.new()
	t.set_guest(true)
	eq(t.step_line(), "Первый забег · 1 / 6")
	_pass(t, Tutorial.Ev.SAT)
	_pass(t, Tutorial.Ev.THRUST)
	_pass(t, Tutorial.Ev.LIGHT)
	_pass(t, Tutorial.Ev.SHARE)
	eq(t.target(), "sonar", "после энергии — сонар")
	eq(t.step_line(), "Первый забег · 5 / 6")
	var g := Tutorial.Guest.new()
	var sh: Array = [2, 2, 2, 2, 2]
	var dt := 1.0 / 30.0
	g.update(dt, false, false, "sonar", Vector2.ZERO, false, false, false, sh, -1, 3)
	eq(g.update(dt, false, false, "sonar", Vector2.ZERO, false, false, false, sh, -1, 4), [],
		"чужой импульс без своего нажатия — не считается")
	g.update(dt, false, false, "sonar", Vector2.ZERO, false, true, false, sh, -1, 4)
	eq(g.update(dt, false, false, "sonar", Vector2.ZERO, false, false, false, sh, -1, 4), [], "ждём кадр хоста")
	eq(g.update(dt, false, false, "sonar", Vector2.ZERO, false, false, false, sh, -1, 5), [Tutorial.Ev.PING],
		"кнопка у голостола — в кадре новый импульс хоста")
	ok(t.note(Tutorial.Ev.PING), "шаг сонара засчитан")


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


## Кнопка «Схема» ART-042 на плашке: пока игрок ищет пост-цель; у поста, в «Выполнено» и без цели — нет.
func test_map_button_wanted_and_place() -> void:
	var t := Tutorial.new()
	t.a = 1.0
	ok(t.map_wanted("helm", "", false), "ищет штурвал — «Схема»")
	ok(not t.map_wanted("helm", "helm", false), "у штурвала — нет")
	ok(not t.map_wanted("", "", false), "цели нет (сидит, шаг штурвала) — нет")
	ok(t.map_wanted("energy", "", false), "шаг энергии из кресла — «Схема»")
	ok(not t.map_wanted("energy", "energy", true), "пульт открыт — нет")
	t.note(Tutorial.Ev.SAT)
	ok(not t.map_wanted("helm", "", false), "«Выполнено» — нет")
	t.a = 0.0
	ok(not Tutorial.new().map_wanted("helm", "", false), "плашки не видно — нет")
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720)]:
		var b := Tutorial.box(size)
		var m := Tutorial.map_rect(b, size)
		var s := size.y / Tutorial.REF_H
		near(m.size.x, 360.0 * s, 1e-3, "ширина 360")
		near(m.size.y, 112.0 * s, 1e-3, "высота 112")
		ok(b.encloses(m), "кнопка на плашке")
		near(b.end.x - m.end.x, Tutorial.MAP_RIGHT * s, 1e-3, "у правого края")
		var font := ThemeDB.fallback_font
		# тексты, при которых бывает «Схема» (игрок не у поста-цели): шаг 7 за штурвалом без кнопки — не в счёт
		var lines: Array = [Tutorial.STAND_UP, Tutorial.FIND_ROUTE, Tutorial.TO_HELM]
		for st in Tutorial.STEPS:
			if st[1] != Tutorial.Ev.COURSE:
				lines.append(st[0])
		for line: String in lines:
			var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(Tutorial.TEXT_PX * s)).x
			ok(b.position.x + Tutorial.TEXT_AT.x * s + w < m.position.x, "текст «%s» не под кнопкой" % line)


func test_scene_map_from_hint_and_back() -> void:
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.arrival.on = false   # брифинг прибытия до подсказок — test_arrival_brief
	main.walker.x = 2.0   # далеко от штурвала: шаг 1 — найдите пост
	main.walker.z = 1.0
	_tick(10)
	var m: Rect2 = main.tutorial_panel.map_rect()
	ok(m.has_area(), "на плашке «Схема»")
	ok(main.overlay.router.blocks.has(m), "палец на кнопке не крутит взгляд")
	var r := main.overlay.router
	r.begin(1, m.get_center())
	_tick()
	r.end(1)
	_tick()
	ok(main.ship_map.open and main.ship_map.from == "hint", "схема открыта с подсказки")
	ok(main.pause.open and not main.pause_panel.visible, "игра стоит, кнопок паузы не видно")
	ok(not main.overlay.visible, "управление скрыто")
	var size := main.get_viewport().get_visible_rect().size
	r.begin(2, ShipMap.back_rect(size).get_center())
	_tick()
	r.end(2)
	_tick(10)
	ok(not main.ship_map.open and not main.pause.open, "«Назад» — сразу к подсказке, без паузы")
	ok(main.overlay.visible and main.tutorial_panel.visible, "управление и подсказка снова на экране")
	eq(main.tutorial.step, 0, "шаг тот же")
	main.walker.x = 0.0
	main.walker.z = Deck.CHAIR_Z
	_tick(10)
	ok(not main.tutorial_panel.map_rect().has_area(), "у штурвала кнопки нет")
	main.walker.x = 2.0
	main.walker.z = 1.0
	_tick(10)
	main.back_pressed()   # не мешает обычной паузе
	_tick()
	ok(main.pause.open and not main.ship_map.open, "системная «Назад» — обычная пауза")


func test_holds_events_while_active() -> void:   # #827: события слоя ждут конца обучения
	var t := Tutorial.new()
	ok(t.holds_events(), "обучение идёт — события ждут")
	t.on = false
	ok(not t.holds_events(), "обучение выключено — события идут")
	t.on = true
	t.step = Tutorial.STEPS.size()
	ok(not t.holds_events(), "пройдено — события идут")


func test_scene_no_events_during_hints() -> void:   # #827: ни нападения, ни пробоины, ни подделок, пока подсказки
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.arrival.on = false   # брифинг прибытия до подсказок — test_arrival_brief
	ok(main.tutorial.on and main.events_held(), "первый забег: подсказки, события ждут")
	var hull := main.vitals.hull
	main.on_eco_event({"type": EcoLink.HIT, "damage": 0.12, "by": "Серпохвост"})
	eq(main.vitals.hull, hull, "удар существа не снял корпус")
	ok(main.breach.active == null, "пробоины нет")
	var energy := main.vitals.energy
	main.on_eco_event({"type": EcoLink.DRAIN, "by": "Присоска", "units": 5.0})
	eq(main.vitals.energy, energy, "присоски не тянут энергию")
	main.on_eco_event({"type": EcoLink.DRAG, "k": 0.3})
	eq(main.helm.extra_drag, 0.0, "присоски не тормозят")
	var n := main.comms.queue.size() + (1 if main.comms.cur != null else 0)
	main.on_eco_event({"type": EcoLink.VOICE, "role": Crew.Role.PILOT, "text": "Включите прожектор!", "fake": true,
		"ask": "light"})
	eq(main.comms.queue.size() + (1 if main.comms.cur != null else 0), n, "подделка в эфир не попала")
	main.on_eco_event({"type": EcoLink.VOICE, "role": Crew.Role.PILOT, "text": "Курс держим.", "fake": false})
	eq(main.comms.queue.size() + (1 if main.comms.cur != null else 0), n + 1, "свой доклад идёт")
	main.vitals.hit(20, "scrape")   # удар о дно на учебном ходу: корпус — да, пробоина и ил — нет
	ok(main.vitals.hull < hull, "удар о дно снимает корпус")
	ok(main.breach.active == null, "пробоины от удара о дно нет")
	eq(main.silt.clouds.size(), 0, "ила от удара нет")
	main.tutorial.step = Tutorial.STEPS.size()   # обучение пройдено
	ok(not main.events_held(), "после обучения события идут")
	hull = main.vitals.hull
	main.on_eco_event({"type": EcoLink.HIT, "damage": 0.12, "by": "Серпохвост"})
	ok(main.vitals.hull < hull, "удар доходит")
	ok(main.breach.active != null, "и пробивает корпус")


func test_scene_finish_learns_intro() -> void:   # #827: пройденное обучение — знание кампании
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.arrival.on = false   # брифинг прибытия до подсказок — test_arrival_brief
	main.tutorial.step = Tutorial.STEPS.size() - 1
	ok(main.tutorial.note(Tutorial.Ev.COURSE), "последний шаг засчитан")
	_secs(1.0)
	ok(main.tutorial.finished(), "пройдено")
	ok(main.lore.knows(LayerLore.INTRO), "знание «обучение просмотрено»")


func test_scene_loaded_campaign_no_hints() -> void:   # #827: загрузка сохранения обучение заново не запускает
	const PATH := "user://test_tutorial_save.json"
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": SaveGame.VERSION, "lore": [LayerLore.INTRO]}))
	f.close()
	SaveGame.default_path = PATH
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.arrival.on = false   # брифинг прибытия до подсказок — test_arrival_brief
	SaveGame.default_path = ""
	DirAccess.remove_absolute(PATH)
	ok(main.lore.knows(LayerLore.INTRO), "знание прочитано из сохранения")
	ok(not main.tutorial.on, "подсказок нет")
	ok(not main.events_held(), "события слоя не ждут")
