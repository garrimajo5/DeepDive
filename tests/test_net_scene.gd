extends TestCase
## Хост в сцене (Main.host_game): телефон по loopback встаёт членом экипажа, его ввод ведёт фигуру,
## кадры уходят раз в SEND_DT, ушедший пропадает с палубы.

const PORT := 24710
const DT := 1.0 / 30.0
var main: Main
var client: NetLink.Client
var frame := {}


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	eq(main.host_game(PORT), OK, "хост открыт")
	client = NetLink.Client.new()
	client.join("127.0.0.1", PORT, "Ира", Crew.Role.BIOLOGIST, 1)


func after() -> void:
	client.stop()
	main.net_host.stop()


## Шаги хоста и клиента, пока cond не true (до 3 с настоящего времени).
func _pump(cond: Callable) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		main.step(DT)
		var f := client.poll(DT)
		if not f.is_empty():
			frame = f
		if cond.call():
			return true
		OS.delay_msec(2)
	return false


func test_guest_joins_as_mate() -> void:
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	var m: Crew.Member = main.crew[1]
	eq(m.role, Crew.Role.BIOLOGIST, "роль гостя")
	eq(m.look, 1, "внешность гостя")
	eq(m.name, "Ира", "имя гостя")
	eq(main.crew_view.figures.size(), 2, "фигура гостя")
	ok(main.crew_view.figures[1].visible, "видна")
	var g: NetLink.Guest = main.net_host.guests.values()[0]
	ok(m.pad == g.pad, "ввод члена экипажа — ввод гостя")
	eq(g.index, 1, "место гостя в экипаже")


func test_frames_reach_guest_with_place() -> void:
	main.helm.pos = Vector3(3.0, -30.0, 12.0)
	ok(_pump(func() -> bool: return client.got >= 3), "кадры идут")
	eq(client.me, 1, "своё место — второй")
	var helm := Helm.Ship.new()
	var crew: Array = []
	NetSnap.apply_frame(frame, -1, helm, Reactor.new(), Vitals.new(), crew)
	ok(helm.pos.distance_to(main.helm.pos) < 0.5, "корабль как у хоста")
	eq(crew.size(), 2, "экипаж как у хоста")
	eq((crew[1] as Crew.Member).role, Crew.Role.BIOLOGIST)
	# 20 кадров в секунду: за секунду шагов хоста — около 20 (не 30)
	var before := main.net_host.seq
	for i in 30:
		main.step(DT)
	eq(main.net_host.seq - before, 20, "кадр раз в SEND_DT")


func test_guest_pad_walks_mate() -> void:
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	var m: Crew.Member = main.crew[1]
	var z0 := m.walker.z
	var pad := Crew.Pad.new()
	pad.move = Vector2(0.0, 1.0)   # вперёд — к носу (−Z)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and m.walker.z > z0 - 0.5:
		client.send_pad(pad)
		main.step(DT)
		client.poll(DT)
		OS.delay_msec(2)
	ok(m.walker.z < z0 - 0.5, "фигура гостя идёт его крестовиной (%.2f → %.2f)" % [z0, m.walker.z])


func test_guest_leaves() -> void:
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	client.stop()
	ok(_pump(func() -> bool: return main.crew.size() == 1), "ушёл с палубы")
	ok(main.crew[0] == main.me, "остался свой игрок")
	eq(main.net_mates.size(), 0)
	ok(not main.crew_view.figures[1].visible, "фигура гостя скрыта")
	ok(main.notice.active(), "у хоста уведомление (ART-043)")
	eq(main.notice.title, "Ира отключилась", "женская внешность — «отключилась»")
	eq(main.notice.sub, "Роль свободна", "поста не держала")
	ok(main.drop_panel.visible, "плашка на экране")
	for i in int(HostNotice.LEFT_TIME / DT) + 2:
		main.step(DT)
	ok(not main.notice.active(), "через 4 с плашки нет")
	ok(not main.drop_panel.visible)


func test_guest_comes_back() -> void:   # ART-043: «Ира вернулась» — тот же гость по имени
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	client.stop()
	ok(_pump(func() -> bool: return main.crew.size() == 1), "ушла")
	client = NetLink.Client.new()
	client.join("127.0.0.1", PORT, "Ира", Crew.Role.BIOLOGIST, 1)
	ok(_pump(func() -> bool: return main.crew.size() == 2), "вошла снова")
	eq(main.notice.title, "Ира вернулась")
	ok(main.notice.active())
	eq(main.notice.time, HostNotice.BACK_TIME, "2 с")


## Гость на посту правит кораблём (по сети): за штурвалом — ход, руль, «Вниз», «Свет»; у пульта — доли энергии.
func _seat_guest(x: float, z: float) -> Crew.Member:
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	var m: Crew.Member = main.crew[1]
	m.place(x, z, 0.0)
	m.walker.x = x
	m.walker.z = z
	var pad := Crew.Pad.new()
	pad.action = true
	client.send_pad(pad)
	ok(_pump(func() -> bool: return m.busy()), "гость встал к посту своей кнопкой")
	return m


func test_guest_at_helm_drives_ship() -> void:
	var m := _seat_guest(0.0, Deck.CHAIR_Z)
	ok(m.seated, "сел за штурвал")
	var pad := Crew.Pad.new()
	pad.move = Vector2(1.0, 1.0)   # по диагонали: у хоста ход и руль полные, как у своей крестовины
	pad.vert = -1
	var z0 := main.helm.pos
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and main.helm.speed < 0.5:
		client.send_pad(pad)
		main.step(DT)
		client.poll(DT)
		OS.delay_msec(2)
	near(main.helm.in_thrust, 1.0, 1e-5, "ход — крестовина гостя")
	near(main.helm.in_turn, 1.0, 1e-5, "руль — крестовина гостя")
	near(main.helm.in_vert, -1.0, 1e-5, "«Вниз» гостя")
	ok(main.helm.speed > 0.5, "корабль пошёл (%.2f м/с)" % main.helm.speed)
	ok(main.helm.pos.distance_to(z0) > 0.01, "сдвинулся")
	var lit := main.light_on
	pad.light = true
	client.send_pad(pad)
	ok(_pump(func() -> bool: return main.light_on != lit), "«Свет» гостя переключил прожектор")
	for i in 10:
		client.send_pad(pad)   # без нового нажатия свет не мигает
		main.step(DT)
		client.poll(DT)
	ok(main.light_on != lit, "одно нажатие — одно переключение")


func test_guest_at_power_moves_shares() -> void:
	var m := _seat_guest(Main.POWER_STAND.x, Main.POWER_STAND.y)
	ok(m.at_power, "у пульта энергии")
	var before := main.reactor.share.duplicate()
	var pad := Crew.Pad.new()
	pad.move = Vector2(-1.0, 0.0)   # влево — снять у выбранной системы
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and main.reactor.share == before:
		client.send_pad(pad)
		main.step(DT)
		client.poll(DT)
		OS.delay_msec(2)
	ok(main.reactor.share != before, "доли реактора правит крестовина гостя (%s → %s)" % [before, main.reactor.share])


func test_guest_picks_route_and_gets_vote() -> void:   # кнопка гостя у поста «Маршрут» листает маршрут, кадр везёт его
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	var m: Crew.Member = main.crew[1]
	m.place(Main.ROUTE_POST.x, Main.ROUTE_POST.y, 0.0)
	m.walker.x = Main.ROUTE_POST.x
	m.walker.z = Main.ROUTE_POST.y
	var pad := Crew.Pad.new()
	pad.action = true
	client.send_pad(pad)
	ok(_pump(func() -> bool: return main.run.route == 0), "маршрут выбрал гость")
	ok(not m.busy(), "маршрут не пройден — к столу не встал")
	var my := Run.new()
	ok(_pump(func() -> bool:
		var ev: Variant = frame.get("ev", {})
		return ev is Dictionary and not NetSnap.apply_run(ev.get("r"), my).is_empty() and my.route == 0),
		"маршрут хоста — в кадре гостю")
	main.complete_route()
	pad = Crew.Pad.new()
	pad.action = true
	client.send_pad(pad)
	ok(_pump(func() -> bool: return m.at_vote), "маршрут пройден — гость у стола")
	var got := [{}]   # лямбда меняет содержимое, не саму переменную
	ok(_pump(func() -> bool:
		var ev: Variant = frame.get("ev", {})
		got[0] = NetSnap.apply_run(ev.get("r") if ev is Dictionary else null, my)
		return my.done and not got[0].is_empty() and not got[0]["ops"].is_empty()), "мнения ролей — гостю")
	eq(got[0]["marks"], VoteHolo.votes(got[0]["ops"]), "голосует один — метки по мнениям ролей")


func test_guest_pings_sonar_for_all() -> void:   # кнопка гостя у голостола — импульс хоста, кадр везёт его гостю
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	var m: Crew.Member = main.crew[1]
	m.place(-1.3, -1.6, 0.0)
	m.walker.x = -1.3
	m.walker.z = -1.6
	main.time = 50.0
	var n := main.sonar.count
	var pad := Crew.Pad.new()
	pad.action = true
	client.send_pad(pad)
	ok(_pump(func() -> bool: return main.sonar.count == n + 1), "импульс у хоста от кнопки гостя")
	var mine := Sonar.new()
	ok(_pump(func() -> bool:
		var ev: Variant = frame.get("ev", {})
		return ev is Dictionary and NetSnap.apply_sonar(ev.get("so"), mine, 0.0)), "импульс хоста — в кадре гостю")
	eq(mine.count, main.sonar.count, "тот же счёт импульсов")
	ok(mine.ping_time > -1.0, "волна идёт на часах гостя: %.2f" % mine.ping_time)
