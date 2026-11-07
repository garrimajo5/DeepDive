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
