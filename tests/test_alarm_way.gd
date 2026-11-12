extends TestCase
## #1361: тревога на строке приборов говорит «куда» и «что делать» по месту игрока (AlarmWay); сообщение мира
## во время тревоги — во втором ряду, не в третьем; имя отсека в первом ряду — короткое.


func test_doors_and_side() -> void:
	var R := ShipLayout.Room
	eq(AlarmWay.doors(R.BRIDGE, R.ENGINE), 3, "мостик → машинное: 3 люка")
	eq(AlarmWay.doors(R.CARGO, R.ENGINE), 1, "трюм → машинное: 1 люк")
	eq(AlarmWay.side(R.BRIDGE, R.ENGINE), "в корму", "к корме")
	eq(AlarmWay.side(R.CARGO, R.LAB), "в нос", "к носу")
	eq(AlarmWay.side(R.LAB, R.LAB), "", "уже там")
	eq(AlarmWay.doors_text(1), "1 люк")
	eq(AlarmWay.doors_text(3), "3 люка")
	eq(AlarmWay.next_door(R.BRIDGE, R.ENGINE), 0, "с мостика — люк в переборке z 2")
	eq(AlarmWay.next_door(R.CARGO, R.BRIDGE), 3, "из трюма — люк z 19,5")
	eq(AlarmWay.next_door(R.ENGINE, R.ENGINE), -1, "в отсеке цели люка нет")
	eq(ShipLayout.DOOR_Z[AlarmWay.next_door(R.LAB, R.CORRIDOR)], 8.0, "из лаборатории в нос — z 8")


## Пробоина в каждом из четырёх мест, игрок в каждом отсеке: в отсеке пробоины — «держите «Сварка»», иначе
## отсек, сторона и число люков.
func test_breach_line_every_room() -> void:
	var b := Breach.new()
	for s in b.all:
		b.active = s
		b.water = 0.04
		for room in 5:
			var line := AlarmWay.breach_line(b, room)
			if room == s.room:
				eq(line, "ПРОБОИНА · вода 4 см · держите «Сварка»", "%s, игрок там же" % s.name)
				continue
			var n := absi(room - s.room)
			var want := "ПРОБОИНА · %s · вода 4 см · %s, %d %s" % [AlarmWay.ROOMS[s.room],
				"в корму" if s.room > room else "в нос", n, "люк" if n == 1 else "люка"]
			eq(line, want, "%s, игрок в %s" % [s.name, AlarmWay.ROOMS[room]])
	b.active = null
	b.water_spot = b.all[3]
	b.water = 0.08
	eq(AlarmWay.breach_line(b, 0), b.status(), "после сварки — как раньше, вода")
	b.water = 0.0
	eq(AlarmWay.breach_line(b, 0), "", "нет пробоины — пусто")
	eq(AlarmWay.breach_line(Breach.new(), 0), "", "спокойно")


func test_heat_line() -> void:
	var r := Reactor.new()
	eq(AlarmWay.heat_line(r, 0), "", "реактор спокоен")
	r.hot = true
	r.heat = 112.0
	eq(AlarmWay.heat_line(r, ShipLayout.Room.BRIDGE), "ПЕРЕГРЕВ 112° · вентиль в машинном, в корму", "с мостика")
	eq(AlarmWay.heat_line(r, ShipLayout.Room.CARGO), "ПЕРЕГРЕВ 112° · вентиль в машинном, в нос", "из трюма")
	eq(AlarmWay.heat_line(r, ShipLayout.Room.ENGINE), "ПЕРЕГРЕВ 112° · держите «Вентиль»", "в машинном")
	r.scram = 5.0
	eq(AlarmWay.heat_line(r, 0), r.alert(), "сброс — как раньше")
	ok(AlarmWay.heat_line(r, 0).begins_with("АВАРИЙНЫЙ СБРОС"), "сброс")


## Сцена: пробоина в машинном. У пробоины — «держите «Сварка»», первый ряд «Машинное», на экране ≤ 3 строк;
## на мостике — «в корму, 3 люка»; сообщение во время тревоги — во втором ряду.
func test_scene_breach_rows() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.open_breach(3)
	main.step(0.1)
	var rows := main.status_rows()
	eq(str(rows[0][0]), "Машинное", "короткое имя отсека")
	ok(str(rows[2][0]).begins_with("ПРОБОИНА · вода ") and str(rows[2][0]).ends_with("держите «Сварка»"),
		"у пробоины — что делать: %s" % [rows[2]])
	for i in 50:   # сообщение о пробоине погасло
		main.step(0.1)
	main.step(0.1)
	ok(main.hint.text.split("\n").size() <= 3, "в машинном на экране ≤ 3 строк:\n%s" % main.hint.text)
	main.walker.x = 0.0
	main.walker.z = -2.0
	main.step(0.1)
	rows = main.status_rows()
	ok(str(rows[2][0]).begins_with("ПРОБОИНА · машинное · вода ") and str(rows[2][0]).ends_with("в корму, 3 люка"),
		"с мостика — куда идти: %s" % [rows[2]])
	main.say("Проверка связи")
	rows = main.status_rows()
	eq(rows[1], ["Проверка связи"], "сообщение во время тревоги — вторым рядом")
	ok(not rows[2].has("Проверка связи"), "к тревоге не клеится: %s" % [rows[2]])
	main.queue_free()
	await frames(1)


## Без тревоги сообщение — в третьем ряду, как было; данные поста во втором.
func test_scene_message_without_alarm() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.say("Проверка связи")
	var rows := main.status_rows()
	ok(rows[2].has("Проверка связи"), "сообщение в третьем ряду: %s" % [rows])
	ok(not rows[1].has("Проверка связи"), "второй ряд — данные поста")
	main.queue_free()
	await frames(1)


## #1361, часть B: указатель на цель тревоги — только в соло, после подсказок, не в отсеке цели; пробоина раньше
## перегрева; остриё — над ближним люком по пути, со стороны игрока.
func test_pointer_rules() -> void:
	var R := ShipLayout.Room
	var b := Breach.new()
	var r := Reactor.new()
	eq(AlarmWay.pointer(b, r, R.BRIDGE, true, false), null, "тревоги нет — указателя нет")
	b.active = b.all[3]
	var p := AlarmWay.pointer(b, r, R.BRIDGE, true, false)
	ok(p != null, "пробоина в соло — указатель")
	eq(p.room, b.all[3].room, "цель — отсек пробоины")
	eq(p.door, AlarmWay.next_door(R.BRIDGE, p.room), "ближний люк по пути")
	near(p.anchor.y, ShipLayout.DOOR_H + 0.25, 0.001, "над проёмом на 0,25 м")
	ok(p.anchor.z < ShipLayout.DOOR_Z[p.door], "с мостика — со стороны носа (игрока)")
	eq(p.anchor.x, 0.0, "над серединой проёма")
	eq(p.label(), "Пробоина · %s" % AlarmWay.ROOMS[p.room])
	eq(p.word, "Пробоина")
	var back := AlarmWay.pointer(b, r, R.CARGO, true, false)
	if b.all[3].room < R.CARGO:
		ok(back.anchor.z > ShipLayout.DOOR_Z[back.door], "из трюма — со стороны кормы")
	eq(AlarmWay.pointer(b, r, b.all[3].room, true, false), null, "в отсеке цели гаснет")
	eq(AlarmWay.pointer(b, r, R.BRIDGE, false, false), null, "кооп — нет")
	eq(AlarmWay.pointer(b, r, R.BRIDGE, true, true), null, "пока идут подсказки — нет")
	r.hot = true
	eq(AlarmWay.pointer(b, r, R.BRIDGE, true, false).word, "Пробоина", "пробоина раньше перегрева")
	b.active = null
	p = AlarmWay.pointer(b, r, R.BRIDGE, true, false)
	eq(p.word, "Перегрев", "перегрев")
	eq(p.room, R.ENGINE, "вентиль — в машинном")
	eq(p.label(), "Перегрев · машинное")
	eq(AlarmWay.pointer(b, r, R.ENGINE, true, false), null, "в машинном гаснет")
	r.scram = 3.0
	eq(AlarmWay.pointer(b, r, R.BRIDGE, true, false), null, "аварийный сброс — без указателя")


## Подпись не выходит за экран: над кольцом в середине и у краёв, под стрелкой у левого и правого края.
func test_label_rect_on_screen() -> void:
	for size: Vector2 in [Vector2(1600, 720), Vector2(2400, 1080), Vector2(1920, 1080)]:
		var screen := Rect2(Vector2.ZERO, size)
		var s := size.y / 1080.0
		var mid := Rect2(size * 0.5 - Vector2(60, 60) * s, Vector2(120, 120) * s)
		var r := AlarmWay.label_rect(300.0 * s, mid, false, size)
		ok(screen.encloses(r), "в кадре: %s" % r)
		ok(r.end.y <= mid.position.y, "над кольцом")
		near(r.get_center().x, mid.get_center().x, 0.5, "по центру кольца")
		var top := Rect2(Vector2(0, 0), Vector2(120, 120) * s)
		ok(screen.encloses(AlarmWay.label_rect(300.0 * s, top, false, size)), "кольцо у верхнего края")
		for right in [false, true]:
			var local := Vector3(1.0 if right else -1.0, 0.0, 2.0)   # за спиной
			var e := HintPointer.edge(local, Vector2(-1, -1), size)
			var cell: Rect2 = e[0]
			if e[1]:
				cell = Rect2(cell.position.x + cell.size.x, cell.position.y, -cell.size.x, cell.size.y)
			var lr := AlarmWay.label_rect(160.0 * s, cell, true, size)
			ok(screen.encloses(lr), "под стрелкой у края в кадре: %s" % lr)
			ok(lr.position.y > cell.get_center().y, "под символом")


func test_white_atlas_keeps_alpha() -> void:
	var src: Image = (load(HintPointer.PATH) as Texture2D).get_image()
	var img := HintPointer.white_image(src)
	var a := 0
	for y in range(0, 256, 4):
		for x in range(0, 256, 4):
			var c := img.get_pixel(x, y)
			near(c.a, src.get_pixel(x, y).a, 0.01, "альфа как была")
			if c.a > 0.5:
				a += 1
				ok(c.r > 0.97 and c.g > 0.97 and c.b > 0.97, "белый: %s" % c)
	ok(a > 100, "символ есть")


## Сцена: пробоина в машинном, игрок на мостике лицом в нос — стрелка у края и слово «Пробоина»; лицом к корме —
## указатель над люком z 2 в мире и подпись «Пробоина · машинное»; в машинном и в коопе — ничего.
func test_scene_pointer() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.open_breach(3)
	main.walker.x = 0.0
	main.walker.z = -2.0
	main.walker.yaw = 0.0
	main.walker.pitch = 0.0
	main.step(0.1)
	await frames(1)
	ok(main.alarm_pointer != null, "указатель есть")
	ok(main.alarm_pointer_panel.visible, "панель видна")
	eq(main.alarm_pointer_panel.arrow.size(), 2, "лицом в нос — стрелка у края")
	eq(main.alarm_pointer_panel.text, "Пробоина")
	ok(not main.hint_pointer.sprite.visible, "в мире скрыт")
	main.walker.yaw = PI
	main.step(0.1)
	await frames(1)
	ok(main.hint_pointer.sprite.visible, "лицом к корме — над люком")
	eq(main.hint_pointer.sprite.texture, main.hint_pointer.amber, "янтарный атлас")
	eq(main.hint_pointer.sprite.modulate.r, AlarmBoard.WORD_ON.r, "цвет тревоги")
	eq(main.alarm_pointer_panel.text, "Пробоина · машинное")
	var screen := main.get_viewport().get_visible_rect()
	ok(screen.encloses(main.alarm_pointer_panel.box()), "подпись в кадре")
	main.walker.z = 16.0   # машинное
	main.step(0.1)
	await frames(1)
	eq(main.alarm_pointer, null, "у пробоины — дальше ведёт рамка")
	ok(not main.alarm_pointer_panel.visible and not main.hint_pointer.sprite.visible, "скрыт")
	main.walker.z = -2.0
	main.add_mate(1.0, -1.0, 0.0, 1, 0)
	main.step(0.1)
	await frames(1)
	eq(main.alarm_pointer, null, "кооп — нет")
	main.queue_free()
	await frames(1)


## Люк вплотную над головой: остриё выше TIP_MIN_Y опускается до него (кольцо в кадре, не стрелка вбок); сбоку, за
## спиной и ниже — как есть.
func test_lower_tip() -> void:
	var size := Vector2(1600, 720)
	var s := size.y / 1080.0
	var low := HintPointer.lower_tip(Vector2(800, 10), 1.8, size, AlarmWay.TIP_MIN_Y)
	near(low.y, AlarmWay.TIP_MIN_Y * s, 0.01, "опущено")
	eq(HintPointer.mode(Vector3(0, 0.5, -1.8), low, size), "world", "кольцо в кадре")
	eq(HintPointer.lower_tip(Vector2(800, 500), 1.8, size, AlarmWay.TIP_MIN_Y), Vector2(800, 500), "ниже — как есть")
	eq(HintPointer.lower_tip(Vector2(-50, 10), 1.8, size, AlarmWay.TIP_MIN_Y), Vector2(-50, 10), "сбоку — стрелка")
	near(HintPointer.lower_tip(Vector2(800, 10), 0.1, size, AlarmWay.TIP_MIN_Y).y, AlarmWay.TIP_MIN_Y * s, 0.01,
		"вплотную над головой — тоже опущено (#1367)")
	eq(HintPointer.lower_tip(Vector2(800, 10), -0.1, size, AlarmWay.TIP_MIN_Y), Vector2(800, 10), "за спиной — как есть")


## #1709: ил — выход по кратчайшему пути из шара облака на мостике, путь к штурвалу из других отсеков.
func test_silt_line() -> void:
	var s := Silt.new()
	eq(AlarmWay.silt_line(s, Vector3.ZERO, ShipLayout.Room.BRIDGE), "", "не в иле — пусто")
	var cl := Silt.Cloud.new()
	cl.c = Vector3(100.0, -40.0, 50.0)
	cl.r = 16.0
	s.inside = cl
	eq(AlarmWay.silt_line(s, cl.c + Vector3(4.0, 0.0, 0.0), ShipLayout.Room.BRIDGE),
		"ИЛ — СОНАР СЛЕП · выход: курс 90°, 12 м", "к востоку")
	eq(AlarmWay.silt_line(s, cl.c + Vector3(0.0, 4.0, 0.0), ShipLayout.Room.BRIDGE),
		"ИЛ — СОНАР СЛЕП · выход: вверх 12 м", "к верху")
	eq(AlarmWay.silt_exit(cl, cl.c + Vector3(0.0, 0.0, -6.0)), "курс 0°, 10 м", "север — −Z")
	eq(AlarmWay.silt_exit(cl, cl.c + Vector3(-3.0, 0.0, 3.0)), "курс 225°, 12 м", "юго-запад")
	eq(AlarmWay.silt_exit(cl, cl.c + Vector3(1.0, 0.0, -10.0)), "курс 5°, 6 м", "до 5°: 5,7° → 5°")
	eq(AlarmWay.silt_exit(cl, cl.c + Vector3(3.0, -6.0, 0.0)), "курс 90°, 9 м", "вниз — не «вниз», а по горизонтали")
	eq(AlarmWay.silt_exit(cl, cl.c), "вверх 16 м", "в самом центре — вверх")
	for room in [1, 2, 3, 4]:
		var want := "ИЛ — СОНАР СЛЕП · штурвал: в нос, %s" % AlarmWay.doors_text(room)
		eq(AlarmWay.silt_line(s, cl.c, room), want, AlarmWay.ROOMS[room])
		ok(want.length() <= Run.LINE_MAX, "≤ 48: " + want)
	ok(AlarmWay.silt_line(s, cl.c + Vector3(0.1, 0.0, 0.1), 0).length() <= Run.LINE_MAX, "на мостике ≤ 48")


## #1709: присоска — у рычага «жмите «Разряд»», на мостике «рычаг у левого борта», иначе путь на мостик.
func test_drain_line() -> void:
	var v := Vitals.new()
	eq(AlarmWay.drain_line(v, 0, false), "", "без присоски — пусто")
	v.drain("Стеклоуст", 3.0)
	eq(AlarmWay.drain_line(v, 0, true), "СТЕКЛОУСТ ПЬЁТ ЗАРЯД · жмите «Разряд»", "у рычага")
	eq(AlarmWay.drain_line(v, 0, false), "СТЕКЛОУСТ ПЬЁТ ЗАРЯД · рычаг у левого борта", "на мостике")
	eq(AlarmWay.drain_line(v, 1, false), "СТЕКЛОУСТ ПЬЁТ ЗАРЯД · мостик, в нос, 1 люк", "из коридора")
	eq(AlarmWay.drain_line(v, 2, false), "СТЕКЛОУСТ ПЬЁТ ЗАРЯД · мостик, в нос, 2 люка", "из лаборатории")
	v.drain("Двенадцатьбу", 3.0)   # 12 знаков — своё имя, худшая длина
	for room in 5:
		ok(AlarmWay.drain_line(v, room, false).length() <= Run.LINE_MAX, AlarmWay.drain_line(v, room, false))
	eq(AlarmWay.drain_line(v, 4, false), "ДВЕНАДЦАТЬБУ ПЬЁТ ЗАРЯД · мостик, в нос, 4 люка")
	v.drain("Очень длинное имя", 3.0)
	eq(AlarmWay.drain_line(v, 0, false), "СУЩЕСТВО ПЬЁТ ЗАРЯД · рычаг у левого борта", "длинное — «существо»")


## #1709: указатель присоски — к люку на мостик; на мостике нет; пробоина главнее, присоска главнее перегрева.
func test_pointer_drain() -> void:
	var b := Breach.new()
	var r := Reactor.new()
	var v := Vitals.new()
	var R := ShipLayout.Room
	v.drain("Стеклоуст", 3.0)
	var p := AlarmWay.pointer(b, r, R.CORRIDOR, true, false, v)
	ok(p != null, "из коридора — есть")
	eq(p.label(), "Стеклоуст · мостик")
	eq(p.door, 0, "люк z 2")
	ok(p.anchor.z > ShipLayout.DOOR_Z[0], "со стороны игрока")
	eq(AlarmWay.pointer(b, r, R.CARGO, true, false, v).door, 3, "из трюма — ближний люк z 19,5")
	eq(AlarmWay.pointer(b, r, R.BRIDGE, true, false, v), null, "на мостике — рамка у щитка")
	r.hot = true
	eq(AlarmWay.pointer(b, r, R.CORRIDOR, true, false, v).word, "Стеклоуст", "присоска главнее перегрева")
	b.active = b.all[3]
	eq(AlarmWay.pointer(b, r, R.CORRIDOR, true, false, v).word, "Пробоина", "пробоина главнее присоски")
	eq(AlarmWay.pointer(Breach.new(), Reactor.new(), R.CORRIDOR, true, false, null), null, "без заряда — без присоски")


## Сцена: строка ила и присоски по месту игрока; у рычага — «жмите «Разряд»» (кнопка действия «Разряд»).
func test_scene_silt_drain_rows() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.open_silt()
	main.step(0.1)
	main.walker.x = 0.0
	main.walker.z = -1.0
	main.step(0.1)
	ok(str(main.status_rows()[2][0]).begins_with("ИЛ — СОНАР СЛЕП · выход: "), "на мостике: %s" % [main.status_rows()[2]])
	main.walker.z = 6.0
	main.step(0.1)
	eq(str(main.status_rows()[2][0]), "ИЛ — СОНАР СЛЕП · штурвал: в нос, 1 люк", "из коридора")
	main.silt.reset()
	main.vitals.drain("Стеклоуст", 0.5)
	main.step(0.05)
	main.vitals.drain("Стеклоуст", 0.5)
	eq(str(main.status_rows()[2][0]), "СТЕКЛОУСТ ПЬЁТ ЗАРЯД · мостик, в нос, 1 люк", "из коридора")
	var zap: Deck.Post = null
	for post in main.posts:
		if post.id == "zap":
			zap = post
	main.walker.x = zap.at.x
	main.walker.z = zap.at.y
	ok(main._at_lever(), "у рычага")
	eq(str(main.status_rows()[2][0]), "СТЕКЛОУСТ ПЬЁТ ЗАРЯД · жмите «Разряд»", "у рычага")
	main.queue_free()
	await frames(1)
