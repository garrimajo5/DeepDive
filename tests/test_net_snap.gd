extends TestCase
## Снимки для сети: кадр хоста переносит корабль, реактор, корпус и экипаж к клиенту; ввод клиента — к хосту.


func _host() -> Dictionary:
	var helm := Helm.Ship.new()
	helm.pos = Vector3(12.5, -31.0, 40.25)
	helm.yaw = 0.7
	helm.speed = 2.5
	helm.vy = -0.4
	helm.turn = 0.3
	helm.in_thrust = 1.0
	helm.in_turn = -0.5
	var r := Reactor.new()
	r.share[Reactor.Sys.ENGINES] = 40
	r.heat = 77.5
	r.hot = true
	var v := Vitals.new()
	v.hull = 63.0
	v.energy = 41.5
	var crew: Array = []
	for role in 4:
		var m := Crew.Member.new(role)
		m.place(0.5 * role - 1.0, -2.0 + 0.3 * role, 0.2 * role)
		crew.append(m)
	(crew[1] as Crew.Member).sit()
	(crew[2] as Crew.Member).at_power = true
	(crew[2] as Crew.Member).sync_post()
	(crew[3] as Crew.Member).at_vote = true
	(crew[0] as Crew.Member).hold(Vector3(-3.6, 1.1, -2.0))
	(crew[3] as Crew.Member).weld(Vector3(1.0, 1.2, -3.0), Vector3(-1.0, 0.0, 0.0))
	return {"helm": helm, "r": r, "v": v, "crew": crew}


func test_frame_round_trip() -> void:
	var h := _host()
	var f := NetSnap.frame(5, 12.0, h.helm, h.r, h.v, false, h.crew)
	var data: Variant = bytes_to_var(var_to_bytes(f))   # как по сети
	var helm := Helm.Ship.new()
	var r := Reactor.new()
	var v := Vitals.new()
	var crew: Array = [Crew.Member.new()]
	eq(NetSnap.apply_frame(data, -1, helm, r, v, crew), 5, "кадр принят")
	ok(helm.pos.is_equal_approx(Vector3(12.5, -31.0, 40.25)), "корабль на месте хоста")
	near(helm.yaw, 0.7, 1e-6, "курс")
	near(helm.speed, 2.5, 1e-6, "ход")
	near(helm.in_turn, -0.5, 1e-6, "ввод пилота — для роторов и рулей")
	eq(r.share[Reactor.Sys.ENGINES], 40, "доля двигателей")
	ok(r.hot, "перегрев")
	near(r.heat, 77.5, 1e-6, "нагрев")
	near(v.hull, 63.0, 1e-6, "корпус")
	near(v.energy, 41.5, 1e-6, "заряд")
	eq(data["light"], false, "свет погашен")
	eq(crew.size(), 4, "экипаж дополнен до четырёх")
	var c: Array = crew
	eq((c[1] as Crew.Member).role, Crew.Role.SONAR, "роль второго")
	ok((c[1] as Crew.Member).seated, "второй за штурвалом")
	eq((c[1] as Crew.Member).post, "helm", "держит штурвал")
	ok((c[2] as Crew.Member).at_power, "третий у пульта")
	eq((c[2] as Crew.Member).post, "energy", "держит пульт")
	ok((c[3] as Crew.Member).at_vote, "четвёртый у голосования")
	ok((c[3] as Crew.Member).welding(), "и варит")
	near((c[0] as Crew.Member).x, -1.0, 1e-6, "место первого")
	ok((c[0] as Crew.Member).hands[0].is_equal_approx(Vector3(-3.6, 1.1, -2.0)), "левая рука на посте")
	ok(not (c[0] as Crew.Member).hands[1].is_finite(), "правая свободна")
	eq((c[2] as Crew.Member).name, "Инженер", "имя")


func test_old_frame_ignored() -> void:
	var h := _host()
	var helm := Helm.Ship.new()
	var r := Reactor.new()
	var v := Vitals.new()
	var crew: Array = []
	var f := NetSnap.frame(7, 1.0, h.helm, h.r, h.v, true, h.crew)
	eq(NetSnap.apply_frame(f, 9, helm, r, v, crew), 9, "кадр старше принятого не применяется")
	ok(helm.pos.is_equal_approx(Helm.Ship.START), "корабль не сдвинут")
	f["v"] = NetSnap.VERSION + 1
	f["seq"] = 20
	eq(NetSnap.apply_frame(f, 9, helm, r, v, crew), 9, "чужая версия формата не применяется")


func test_crew_shrinks() -> void:
	var h := _host()
	var crew: Array = []
	for i in 4:
		crew.append(Crew.Member.new())
	var f := NetSnap.frame(1, 0.0, h.helm, h.r, h.v, true, (h.crew as Array).slice(0, 2))
	NetSnap.apply_frame(f, 0, Helm.Ship.new(), Reactor.new(), Vitals.new(), crew)
	eq(crew.size(), 2, "ушедшие игроки убраны")


## Самый тяжёлый кадр: четыре игрока, открытая пробоина, три облака ила и длинное сообщение события.
func _busy_events() -> Dictionary:
	var b := Breach.new()
	b.start(b.all[3])
	b.hold(1.0)
	b.update(5.0, 1.0, 80.0)
	var s := Silt.new()
	for i in Silt.MAX_CLOUDS:
		s.spawn(Vector3(10.0 * i, -50.0, 3.0), Silt.SLIDE_R, Silt.SLIDE_LIFE, "slide")
	s.inside = s.clouds[1]
	s.k = 0.6
	s.jam_t = 98.5
	return NetSnap.events(b, s, 100.0, true, [12, Silt.ENTER_MSG])


func test_frame_fits_packet() -> void:
	var h := _host()
	var f := NetSnap.frame(123456, 3600.0, h.helm, h.r, h.v, true, h.crew, _busy_events())
	var ev: Dictionary = f["ev"]
	f.erase("ev")   # события NetLink шлёт следом отдельным пакетом
	var n := NetSnap.bytes(f)
	ok(n <= NetSnap.MAX_BYTES, "кадр с четырьмя игроками — %d байт, не больше %d" % [n, NetSnap.MAX_BYTES])
	n = NetSnap.bytes(ev)
	ok(n <= NetSnap.MAX_BYTES / 2, "события — %d байт" % n)


func test_pad_round_trip() -> void:   # ввод клиента у хоста: крестовина, свайп копится, нажатие не теряется
	var p := Crew.Pad.new()
	p.move = Vector2(0.0, 1.0)
	p.look = Vector2(3.0, -2.0)
	p.action = true
	var host := Crew.Pad.new()
	host.apply(bytes_to_var(var_to_bytes(p.snapshot())))
	host.apply({"mx": 1.0, "my": 1.0, "lx": 1.0, "ly": 0.0, "act": false})
	near(host.move.length(), 1.0, 1e-5, "крестовина не больше 1")
	eq(host.look, Vector2(4.0, -2.0), "свайп двух пакетов сложен")
	ok(host.action, "нажатие из первого пакета не стёрто вторым")


func test_pad_vert_and_light() -> void:   # за штурвалом: «вверх/вниз» как есть, «Свет» не теряется
	var p := Crew.Pad.new()
	p.vert = -1
	p.light = true
	var host := Crew.Pad.new()
	host.apply(p.snapshot())
	host.apply({"mx": 0.0, "my": 0.0, "v": 1, "light": false})
	eq(host.vert, 1, "«вверх/вниз» — из последнего пакета")
	ok(host.light, "«Свет» из первого пакета не стёрт вторым")
	host.apply({"v": 5})
	eq(host.vert, 1, "не больше 1")


func test_events_round_trip() -> void:   # пробоина и ил хоста — у клиента такие же
	var ev: Dictionary = bytes_to_var(var_to_bytes(_busy_events()))
	var b := Breach.new()
	var s := Silt.new()
	var n := NetSnap.apply_events(ev, b, s, 10.0)
	ok(b.active == b.all[3] and b.last == b.all[3] and b.water_spot == b.all[3], "пробоина в машинном")
	eq(b.count, 1)
	near(b.weld, Breach.WELD_RATE, 1e-4, "шов прирос")
	near(b.water, 5.0 * Breach.WATER_RISE, 1e-4, "вода")
	ok(b.welding, "варят")
	eq(s.clouds.size(), Silt.MAX_CLOUDS, "три облака")
	ok(s.inside == s.clouds[1], "корабль во втором")
	ok(s.clouds[2].c.distance_to(Vector3(20.0, -50.0, 3.0)) < 1e-3, "место облака")
	near(s.clouds[0].r, Silt.SLIDE_R, 1e-4)
	near(s.k, 0.6, 1e-4)
	near(s.noise(10.0), 1.0, 1e-4, "импульс завяз 1,5 с назад по часам хоста — помехи и на своих часах")
	near(s.noise(10.0 + Silt.JAM_TIME), 0.6, 1e-4, "помехи кончились — осталась муть")
	eq(n, [12, Silt.ENTER_MSG], "сообщение события")
	var closed := Breach.new()
	closed.start(closed.all[0])
	closed.hold(10.0)
	n = NetSnap.apply_events(NetSnap.events(closed, Silt.new(), 0.0, false), b, s, 0.0)
	ok(b.active == null and b.last == b.all[0], "заварено, шов — на мостике")
	ok(not b.welding)
	ok(s.clouds.is_empty() and s.inside == null, "ил осел")
	eq(n, [], "без сообщения")


func test_events_bad_data_ignored() -> void:   # испорченный пакет событий не ломает пробоину и ил
	var b := Breach.new()
	b.start(b.all[2])
	var s := Silt.new()
	s.spawn(Vector3.ZERO, 5.0, 10.0, "scrape")
	NetSnap.apply_events({"b": PackedFloat32Array([1, 2]), "s": PackedFloat32Array([0, 0, 0, 1]), "n": "x"}, b, s, 0.0)
	ok(b.active == b.all[2], "пробоина та же")
	eq(s.clouds.size(), 1, "облако то же")


func test_run_round_trip() -> void:   # маршрут, голосование и итог хоста — у клиента такие же
	var run := Run.new()
	run.begin(0.0, 0, 0, 0)
	run.choose(1)
	run.update(Run.place_xz("geyser").x, Run.place_xz("geyser").y)
	run.depth = 2
	var ops := Run.opinions(40.0, 80.0, false, false, 1)
	var st: Dictionary = bytes_to_var(var_to_bytes(NetSnap.run_state(run, {"deep": [0, 3], "up": [2]}, 12, 0.4,
		"голосов 2 из 3 · 12 с", ops, [], [])))
	var my := Run.new()
	var got := NetSnap.apply_run(st, my)
	eq(my.route, 1, "маршрут «Тёплые трубы»")
	eq(my.visited, ["geyser"], "пройден курильщик")
	eq(my.seen, ["geyser"])
	eq(my.depth, 2)
	ok(not my.done and not my.ended)
	eq(my.waypoint(), Run.place_xz("shell"), "следующая точка — раковина")
	eq(got["marks"], {"deep": [0, 3], "up": [2]}, "метки голосов")
	eq(got["secs"], 12)
	near(got["frac"], 0.4, 1e-4)
	eq(got["tally"], "голосов 2 из 3 · 12 с")
	eq(got["ops"], [], "мнения — только когда решают")
	run.update(Run.place_xz("shell").x, Run.place_xz("shell").y)
	ok(run.done, "маршрут пройден")
	got = NetSnap.apply_run(NetSnap.run_state(run, {}, -1, -1.0, "", ops, [], []), my)
	ok(my.done, "решают")
	eq(got["ops"], ops, "мнения ролей")
	eq(got["secs"], -1, "таймера нет")
	run.finish(600.0, 3, 2, 1, 70.0)
	var rows := run.summary(3, 2, 1)
	var detail := Run.detail(run.results(600.0, 3, 2, 1, 70.0))
	got = NetSnap.apply_run(NetSnap.run_state(run, {}, -1, -1.0, "", [], rows, detail), my)
	ok(my.ended, "наверх")
	eq(my.score, run.score, "очки")
	eq(got["rows"], rows, "итог на голограмме")
	eq(got["detail"], detail, "итог на панели")
	ok(NetSnap.bytes({"ev": NetSnap.run_state(run, {}, -1, -1.0, "", [], rows, detail)}) < NetSnap.MAX_BYTES,
		"итог влезает в пакет")


func test_run_bad_data_ignored() -> void:   # испорченный маршрут не ломает свой
	var my := Run.new()
	my.choose(2)
	eq(NetSnap.apply_run({"ru": PackedInt32Array([0, 1])}, my), {}, "короткий — мимо")
	eq(NetSnap.apply_run("x", my), {})
	eq(my.route, 2, "маршрут тот же")
	var st := NetSnap.run_state(Run.new(), {}, -1, -1.0, "", [], [], [])
	st["ru"][0] = 99
	st["rv"] = PackedByteArray([200, 4])
	NetSnap.apply_run(st, my)
	eq(my.route, -1, "чужой номер маршрута — без маршрута")
	eq(my.visited, ["well"], "чужой номер места пропущен")


func test_scorch_marks_reach_guest() -> void:   # следы разрядов у дна (ART-066) — у гостя те же, возраст по своим часам
	var h := Seabed.Scorch.new()
	var fy := -30.0
	ok(h.add(Vector3(4.0, fy + Helm.Ship.CLEARANCE, -9.0), fy, 1.0, 100.0), "разряд у дна — след у хоста")
	ok(h.add(Vector3(-6.0, fy + Helm.Ship.CLEARANCE + 3.0, 12.0), fy, 0.8, 150.0), "второй слабее")
	var g := Seabed.Scorch.new()
	ok(NetSnap.apply_scorch(NetSnap.scorch(h, 160.0), g, 20.0), "гость принял")
	eq(g.all.size(), 2)
	eq(g.count, 2)
	for i in 2:
		near(g.all[i].at.x, h.all[i].at.x, 1e-4, "место x")
		near(g.all[i].at.y, h.all[i].at.y, 1e-4, "место z")
		near(g.all[i].rot, h.all[i].rot, 1e-4, "поворот")
		near(g.all[i].size, h.all[i].size, 1e-4, "размер")
		near(g.all[i].k, h.all[i].k, 1e-4, "сила")
		eq(g.all[i].index, h.all[i].index, "ячейка А/Б")
	near(20.0 - float(g.all[0].t), 60.0, 1e-3, "возраст первого — 60 с, часы гостя свои")
	near(Seabed.Scorch.old(g.all[0], 20.0), Seabed.Scorch.old(h.all[0], 160.0), 1e-4, "стареет так же")
	ok(not NetSnap.apply_scorch(NetSnap.scorch(h, 161.0), g, 21.0), "тот же счёт — не переставляет")
	near(20.0 - float(g.all[0].t), 60.0, 1e-3, "время следа осталось")
	h.clear()
	ok(NetSnap.apply_scorch(NetSnap.scorch(h, 200.0), g, 60.0), "новый забег у хоста")
	ok(g.all.is_empty() and g.count == 0, "у гостя чистое дно")
	ok(not NetSnap.apply_scorch(PackedFloat32Array([1.0, 2.0]), g, 0.0), "битый пакет не трогает")
	ok(not NetSnap.apply_scorch(null, g, 0.0), "нет поля — не трогает")
