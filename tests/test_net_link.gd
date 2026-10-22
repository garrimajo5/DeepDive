extends TestCase
## Транспорт ENet по loopback: телефон подключается к хосту, шлёт ввод, получает кадры; отказ по версии и месту,
## уход гостя. Сеть настоящая (127.0.0.1), ожидание — до PUMP_MS, исход от скорости не зависит.

const PUMP_MS := 3000
var _port := 24690
var _hosts: Array = []
var _clients: Array = []
var events: Array = []


func after() -> void:
	for c: NetLink.Client in _clients:
		c.stop()
	for h: NetLink.Host in _hosts:
		h.stop()
	_clients.clear()
	_hosts.clear()
	events.clear()


func _host() -> NetLink.Host:
	var h := NetLink.Host.new()
	_port += 1
	eq(h.start(_port), OK, "хост открыт")
	_hosts.append(h)
	return h


func _client(name: String = "Ира", role: int = Crew.Role.SONAR, look: int = 1) -> NetLink.Client:
	var c := NetLink.Client.new()
	eq(c.join("127.0.0.1", _port, name, role, look), OK, "клиент создан")
	_clients.append(c)
	return c


## Крутить хост и клиентов, пока cond не станет true (или не выйдет время). Кадры клиентов — в c.set_meta("f").
func _pump(cond: Callable) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < PUMP_MS:
		for h: NetLink.Host in _hosts:
			events.append_array(h.poll())
		for c: NetLink.Client in _clients:
			var f := c.poll(0.0)
			if not f.is_empty():
				c.set_meta("f", f)
		if cond.call():
			return true
		OS.delay_msec(2)
	return false


func test_join_hello() -> void:
	var h := _host()
	var c := _client()
	eq(c.state, NetLink.State.CONNECTING, "сначала подключается")
	eq(c.label(), "Подключение…")
	ok(_pump(func() -> bool: return c.joined() and not events.is_empty()), "клиент на борту")
	eq(c.label(), "На борту")
	eq(events.size(), 1, "одно событие")
	eq(events[0]["k"], "join")
	var g: NetLink.Guest = events[0]["guest"]
	eq(g.name, "Ира")
	eq(g.role, Crew.Role.SONAR)
	eq(g.look, 1)
	eq(g.id, c.id, "id гостя — тот, что получил клиент")
	eq(h.guests.size(), 1)


func test_pad_reaches_host_and_press_counted_once() -> void:
	var h := _host()
	var c := _client()
	ok(_pump(func() -> bool: return c.joined() and not events.is_empty()), "на борту")
	var g: NetLink.Guest = events[0]["guest"]
	var pad := Crew.Pad.new()
	pad.move = Vector2(0.0, 1.0)
	pad.look = Vector2(7.0, -2.0)
	pad.action = true
	c.send_pad(pad)
	eq(pad.look, Vector2.ZERO, "свайп съеден отправкой")
	eq(pad.action, false, "нажатие съедено отправкой")
	ok(_pump(func() -> bool: return g.pad.action), "нажатие дошло")
	eq(g.pad.move, Vector2(0.0, 1.0), "крестовина")
	eq(g.pad.look, Vector2(7.0, -2.0), "свайп")
	g.pad.action = false   # хост съел нажатие шагом
	g.pad.look = Vector2.ZERO
	pad.move = Vector2(-1.0, 0.0)
	c.send_pad(pad)        # без нового нажатия: счётчик тот же — нажатие не повторится
	ok(_pump(func() -> bool: return g.pad.move.x < 0.0), "новая крестовина дошла")
	eq(g.pad.action, false, "нажатие не повторилось")
	eq(c.acts, 1)


func test_frames_every_send_dt_and_client_applies() -> void:
	var h := _host()
	var c := _client()
	ok(_pump(func() -> bool: return c.joined() and not events.is_empty()), "на борту")
	var g: NetLink.Guest = events[0]["guest"]
	g.index = 1
	eq(h.due(0.02), false, "рано")
	eq(h.due(0.03), true, "через SEND_DT")
	eq(h.seq, 1)
	eq(h.due(0.01), false, "остаток — к следующему")
	var helm := Helm.Ship.new()
	helm.pos = Vector3(4.0, -25.0, 9.5)
	helm.yaw = 1.25
	var r := Reactor.new()
	r.heat = 55.0
	var v := Vitals.new()
	v.hull = 71.0
	var crew: Array = [Crew.Member.new(Crew.Role.PILOT), Crew.Member.new(Crew.Role.SONAR)]
	(crew[1] as Crew.Member).place(1.5, -2.0, 0.4)
	var f := NetSnap.frame(h.seq, 3.0, helm, r, v, true, crew)
	h.send_frame(f)
	ok(not f.has("me"), "кадр хоста не испорчен местом гостя")
	ok(_pump(func() -> bool: return c.has_meta("f")), "кадр дошёл")
	eq(c.me, 1, "своё место в экипаже")
	eq(c.got, 1)
	var my_helm := Helm.Ship.new()
	var my_r := Reactor.new()
	var my_v := Vitals.new()
	var my_crew: Array = [Crew.Member.new(Crew.Role.PILOT)]
	eq(NetSnap.apply_frame(c.get_meta("f"), -1, my_helm, my_r, my_v, my_crew), 1, "кадр применён")
	near(my_helm.pos.z, 9.5, 1e-5, "корабль как у хоста")
	near(my_helm.yaw, 1.25, 1e-5)
	near(my_r.heat, 55.0, 1e-5)
	near(my_v.hull, 71.0, 1e-5)
	eq(my_crew.size(), 2, "экипаж как у хоста")
	near((my_crew[1] as Crew.Member).x, 1.5, 1e-5)


func test_guest_without_place_gets_no_frame() -> void:
	var h := _host()
	var c := _client()
	ok(_pump(func() -> bool: return c.joined() and not events.is_empty()), "на борту")
	h.send_frame({"v": NetSnap.VERSION, "seq": 1})
	eq(h.sent, 0, "гость не на палубе (index −1) — кадр не шлём")


func test_wrong_version_refused() -> void:
	var h := _host()
	var c := NetLink.Client.new()
	c.version = NetSnap.VERSION + 1
	eq(c.join("127.0.0.1", _port), OK)
	_clients.append(c)
	ok(_pump(func() -> bool: return c.state == NetLink.State.REFUSED), "отказ")
	eq(c.why, "version")
	eq(c.label(), "Другая версия игры")
	eq(h.guests.size(), 0, "не на борту")
	eq(events.size(), 0, "события join нет")


func test_fourth_phone_refused_full() -> void:
	var h := _host()
	var cs: Array = []
	for i in NetLink.MAX_CLIENTS:
		cs.append(_client("Т%d" % i, i + 1, 0))
	ok(_pump(func() -> bool: return h.guests.size() == NetLink.MAX_CLIENTS), "трое на борту")
	var extra := _client("Лишний", 0, 0)
	ok(_pump(func() -> bool: return extra.state == NetLink.State.REFUSED), "четвёртому отказ")
	eq(extra.why, "full")
	eq(extra.label(), "Экипаж полон")
	eq(h.guests.size(), NetLink.MAX_CLIENTS)


func test_leave_event() -> void:
	var h := _host()
	var c := _client()
	ok(_pump(func() -> bool: return c.joined() and not events.is_empty()), "на борту")
	var g: NetLink.Guest = events[0]["guest"]
	c.stop()
	ok(_pump(func() -> bool: return events.size() >= 2), "уход замечен")
	eq(events[1]["k"], "leave")
	ok(events[1]["guest"] == g, "ушёл тот же гость")
	eq(h.guests.size(), 0)


func test_lost_host() -> void:
	var h := _host()
	var c := _client()
	ok(_pump(func() -> bool: return c.joined()), "на борту")
	h.stop()
	_hosts.clear()
	ok(_pump(func() -> bool: return c.state == NetLink.State.LOST), "связь потеряна")
	eq(c.label(), "Связь с хостом потеряна")


func test_timeout_without_host() -> void:
	var c := NetLink.Client.new()
	eq(c.join("127.0.0.1", 24689), OK)   # здесь никто не слушает
	_clients.append(c)
	c.poll(NetLink.TIMEOUT * 0.5)
	eq(c.state, NetLink.State.CONNECTING, "ещё ждёт")
	c.poll(NetLink.TIMEOUT * 0.6)
	eq(c.state, NetLink.State.REFUSED, "не дождался")
	eq(c.label(), "Хост не отвечает")


func test_decode_garbage() -> void:
	eq(NetLink.decode(PackedByteArray()), {}, "пусто")
	eq(NetLink.decode(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8])), {}, "мусор")
	eq(NetLink.decode(var_to_bytes([1, 2])), {}, "не словарь")
	eq(NetLink.decode(NetLink.encode({"k": "pad"})), {"k": "pad"})


func test_due_at_30_fps_sends_20_per_second() -> void:
	var h := NetLink.Host.new()
	var n := 0
	for i in 30:
		if h.due(1.0 / 30.0):
			n += 1
	eq(n, 20, "кадров за секунду при 30 к/с")
	n = 0
	for i in 60:
		if h.due(1.0 / 60.0):
			n += 1
	eq(n, 20, "кадров за секунду при 60 к/с")
	eq(h.due(0.5), true, "долгий кадр — один кадр")
	eq(h.due(0.01), false, "без пачки догоняющих")


## События идут отдельным пакетом за кадром и приезжают к клиенту в кадре («ev»); у хоста кадр не испорчен.
func test_events_ride_with_frame() -> void:
	var h := _host()
	var c := _client()
	ok(_pump(func() -> bool: return c.joined() and not events.is_empty()), "на борту")
	(events[0]["guest"] as NetLink.Guest).index = 0
	var b := Breach.new()
	b.start(b.all[2])
	var ev := NetSnap.events(b, Silt.new(), 0.0, false, [3, "Пробоина: лаборатория"])
	var f := NetSnap.frame(1, 0.0, Helm.Ship.new(), Reactor.new(), Vitals.new(), true, [Crew.Member.new()], ev)
	h.send_frame(f)
	ok(f.get("ev") == ev, "кадр хоста с событиями как был")
	ok(_pump(func() -> bool: return c.has_meta("f") and (c.get_meta("f") as Dictionary).has("ev")), "события дошли с кадром")
	var got: Dictionary = c.get_meta("f")
	var my := Breach.new()
	eq(NetSnap.apply_events(got["ev"], my, Silt.new(), 0.0), [3, "Пробоина: лаборатория"])
	ok(my.active == my.all[2], "пробоина в лаборатории")
	c.remove_meta("f")
	h.send_frame(NetSnap.frame(2, 0.0, Helm.Ship.new(), Reactor.new(), Vitals.new(), true, [Crew.Member.new()]))
	ok(_pump(func() -> bool: return c.has_meta("f")), "кадр без событий")
	ok(not (c.get_meta("f") as Dictionary).has("ev"), "старые события второй раз не приходят")


func test_quiet_guest_and_host_lost() -> void:   # «Нет связи» на табличке (ART-033): по тишине в канале
	var h := _host()
	var c := _client()
	ok(_pump(func() -> bool: return c.joined() and not events.is_empty()), "на борту")
	var g: NetLink.Guest = events[0]["guest"]
	ok(not g.lost(), "только что пришёл — на связи")
	h.poll(NetLink.LOST_AFTER + 0.1)
	ok(g.lost(), "без ввода дольше LOST_AFTER — «Нет связи»")
	c.send_pad(Crew.Pad.new())
	ok(_pump(func() -> bool: return not g.lost()), "ввод пришёл — снова на связи")
	ok(not c.lost(), "у гостя кадров ещё не ждали")
	c.poll(NetLink.LOST_AFTER + 0.1)
	ok(c.lost(), "кадры хоста не идут — у гостя «Нет связи»")
	g.index = 0
	h.send_frame({"v": NetSnap.VERSION, "seq": 1})
	ok(_pump(func() -> bool: return not c.lost()), "кадр пришёл — связь есть")
