extends TestCase
## Поиск забегов ART-028 (`RunBeacon`): маяк хоста по комнате — имя, места, свободные роли, порт; гость собирает
## список, забывает молчащие, другую версию не берёт; строки списка «Найдено 2 забега», «2 / 4 · свободны И / Б».
## Сеть настоящая (127.0.0.1), ожидание — до PUMP_MS.

const PUMP_MS := 3000
var _port := 24810


func _room(name: String, roles: Array) -> Lobby:
	var l := Lobby.new()
	l.host(name)
	l.open = true
	for i in roles.size():
		if i > 0:
			l.add(10 + i, "Гость %d" % i)
		l.players[i].role = roles[i]
	return l


func test_info_of_room() -> void:
	var l := _room("Лена", [Crew.Role.PILOT, Crew.Role.SONAR])
	var d := RunBeacon.info(l, 24700)
	eq(d["k"], "run")
	eq(d["v"], NetSnap.VERSION)
	eq(d["name"], "Лена")
	eq(d["n"], 2)
	eq(d["free"], [Crew.Role.ENGINEER, Crew.Role.BIOLOGIST], "свободны И и Б")
	eq(d["port"], 24700)
	l.add(30, "Без роли")
	eq(RunBeacon.info(l, 1)["n"], 3, "игрок без роли — место занято, роль свободна")
	eq(RunBeacon.info(l, 1)["free"].size(), 2)


func test_lines() -> void:
	var r := RunBeacon.Found.new()
	r.name = "Лена"
	r.players = 2
	r.vacant = [2, 3]
	eq(r.title(), "Забег «Лена»")
	eq(r.line(), "2 / 4 · свободны И / Б")
	r.players = 3
	r.vacant = [1]
	eq(r.line(), "3 / 4 · свободна С")
	r.players = 4
	r.vacant = []
	eq(r.line(), "4 / 4 · мест нет")
	ok(not r.open(), "полный забег не открыт")
	eq(RunBeacon.plural(1), "забег")
	eq(RunBeacon.plural(2), "забега")
	eq(RunBeacon.plural(5), "забегов")
	eq(RunBeacon.plural(11), "забегов")
	eq(RunBeacon.plural(21), "забег")


func test_finder_list_and_forget() -> void:
	var f := RunBeacon.Finder.new()
	f.search()
	eq(f.head(), "Ищем забеги…")
	ok(f.take(RunBeacon.info(_room("Лена", [0, 1]), 24680), "192.168.1.5"), "новый забег")
	ok(not f.take(RunBeacon.info(_room("Лена", [0, 1]), 24680), "192.168.1.5"), "тот же маяк — без перемен")
	ok(f.take(RunBeacon.info(_room("Игорь", [0, 2, 3]), 24680), "192.168.1.7"))
	eq(f.runs.size(), 2)
	eq(f.head(), "Найдено 2 забега")
	ok(f.take(RunBeacon.info(_room("Лена", [0, 1, 2]), 24680), "192.168.1.5"), "занято больше — список сменился")
	eq(f.runs.size(), 2, "тот же хост — та же строка")
	eq(f.find("192.168.1.5", 24680).line(), "3 / 4 · свободна Б")
	ok(not f.take({"k": "run", "v": NetSnap.VERSION + 1, "name": "Старый"}, "192.168.1.9"), "другая версия — нет")
	ok(not f.take({"k": "x"}, "192.168.1.9"))
	ok(not f.take({}, "192.168.1.9"), "мусор — нет")
	# Игорь молчит, Лена шлёт
	for i in 4:
		f.poll(1.0)
		f.take(RunBeacon.info(_room("Лена", [0, 1, 2]), 24680), "192.168.1.5")
	eq(f.runs.size(), 1, "молчащий забыт")
	eq(f.runs[0].name, "Лена")
	eq(f.head(), "Найден 1 забег")
	ok(f.done(), "поиск завершён")
	f.poll(RunBeacon.FORGET + 0.1)
	eq(f.head(), "Никого нет")
	f.search()
	ok(not f.done(), "«Обновить список» — снова ищем")


func test_beacon_over_udp() -> void:
	_port += 1
	var f := RunBeacon.Finder.new()
	f.port = _port
	eq(f.start(), OK, "гость слушает")
	var b := RunBeacon.Beacon.new()
	b.to = "127.0.0.1"
	b.to_port = _port
	eq(b.start(), OK, "маяк открыт")
	var l := _room("Лена", [Crew.Role.PILOT])
	ok(b.step(0.0, l, 24699), "первый маяк — сразу")
	ok(not b.step(0.5, l, 24699), "следующий — через секунду")
	var t0 := Time.get_ticks_msec()
	while f.runs.is_empty() and Time.get_ticks_msec() - t0 < PUMP_MS:
		f.poll(0.0)
		OS.delay_msec(5)
	eq(f.runs.size(), 1, "забег найден")
	var r := f.runs[0]
	eq(r.address, "127.0.0.1")
	eq(r.port, 24699, "порт ENet из маяка")
	eq(r.title(), "Забег «Лена»")
	eq(r.line(), "1 / 4 · свободны С / И / Б")
	ok(b.step(0.6, l, 24699), "второй маяк")
	eq(b.sent, 2)
	b.stop()
	f.stop()
	ok(f.udp == null and b.udp == null)
	ok(not b.step(5.0, l, 1), "закрытый маяк молчит")
