extends TestCase
## Сбор экипажа ART-028 по сети (`LobbyLink`, сообщения `lq` / `ans` / `room` в `NetLink`): телефоны приходят в комнату
## хоста, роль закрепляет хост, отказ «Занято» — только тому, кто просил, снимок комнаты — всем, «Начать погружение» —
## старт у всех, роли гостей на палубе — из комнаты. Сеть настоящая (127.0.0.1), ожидание — до PUMP_MS.

const PUMP_MS := 3000
var _port := 24790
var host: NetLink.Host
var room: Lobby
var _clients: Array = []   ## [Client, Lobby]
var rest: Array = []


func before() -> void:
	host = NetLink.Host.new()
	_port += 1
	eq(host.start(_port), OK, "хост открыт")
	room = Lobby.new()
	room.host("Капитан", "192.168.1.5")
	room.open = true


func after() -> void:
	for c: Array in _clients:
		(c[0] as NetLink.Client).stop()
	_clients.clear()
	host.stop()
	rest.clear()


func _guest(name: String) -> Array:
	var c := NetLink.Client.new()
	eq(c.join("127.0.0.1", _port, name, Crew.Role.PILOT, 0), OK, "клиент создан")
	var l := Lobby.new()
	l.me = -1
	l.open = true
	var pair := [c, l]
	_clients.append(pair)
	return pair


func _pump(cond: Callable) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < PUMP_MS:
		LobbyLink.serve(room, host, host.poll(), rest)
		for pair: Array in _clients:
			var c: NetLink.Client = pair[0]
			if c.peer:
				c.poll(0.0)
				LobbyLink.take(pair[1], c)
		if cond.call():
			return true
		OS.delay_msec(2)
	return false


func _two() -> Array:
	var a := _guest("Ира")
	var b := _guest("Игорь")
	ok(_pump(func() -> bool: return (a[1] as Lobby).players.size() == 3 and (b[1] as Lobby).players.size() == 3),
		"оба видят комнату на троих")
	return [a, b]


func test_guests_enter_room_not_deck() -> void:
	var ab := _two()
	var a: Array = ab[0]
	var la: Lobby = a[1]
	eq(room.players.size(), 3, "у хоста трое")
	eq(la.me, (a[0] as NetLink.Client).id, "свой id — от хоста")
	eq(la.mine().name, "Ира")
	ok(not la.is_host(), "гость — не хост")
	eq(la.host_name(), "Капитан")
	eq(la.subtitle(), "Забег «Капитан» · подключено")
	ok(not la.shows_address(), "плашка адреса только у хоста")
	for g: NetLink.Guest in host.guests.values():
		eq(g.index, -1, "на палубе гостей нет — кадров им не шлют")
	eq(rest.size(), 0, "события комнаты не уходят дальше")


func test_host_fixes_role_and_refuses_taken() -> void:
	var ab := _two()
	var la: Lobby = ab[0][1]
	var lb: Lobby = ab[1][1]
	eq(LobbyLink.guest_press(la, ab[0][0], "pick1"), "role:1", "запрос хосту")
	eq(la.mine().role, -1, "у гостя роль только после ответа хоста")
	ok(_pump(func() -> bool: return lb.holder(1) != null), "второй гость видит занятую роль")
	eq(room.holder(1).name, "Ира", "роль закрепил хост")
	eq(la.mine().role, 1)
	(ab[1][0] as NetLink.Client).send_room("role:1")   # нажал по старому снимку
	ok(_pump(func() -> bool: return lb.refused == 1), "отказ «Занято» дошёл")
	eq(room.holder(1).name, "Ира", "чужой выбор не перезаписан")
	eq(la.refused, -1, "первому отказ не приходил")


func test_refusal_shows_taken_row() -> void:
	var ab := _two()
	var la: Lobby = ab[0][1]
	var lb: Lobby = ab[1][1]
	LobbyLink.guest_press(la, ab[0][0], "pick2")
	ok(_pump(func() -> bool: return lb.holder(2) != null), "И у первого")
	# второй жмёт ту же роль, пока снимок шёл: «Выбрать роль» у него ещё было
	(ab[1][0] as NetLink.Client).send_room("role:2")
	ok(_pump(func() -> bool: return lb.refused == 2), "хост отказал")
	eq(lb.look(2), Lobby.Look.TAKEN, "замок «Занято» в строке")
	ok(lb.note().begins_with("Инженер уже занят: Ира."), lb.note())
	ok(lb.shows_back(), "«Назад к списку»")


func test_ready_and_start_seat_roles() -> void:
	var ab := _two()
	var ca: NetLink.Client = ab[0][0]
	var cb: NetLink.Client = ab[1][0]
	var la: Lobby = ab[0][1]
	var lb: Lobby = ab[1][1]
	LobbyLink.host_press(room, host, "pick0")
	LobbyLink.guest_press(la, ca, "pick1")
	LobbyLink.guest_press(lb, cb, "pick3")
	ok(_pump(func() -> bool: return lb.holder(1) != null and la.holder(3) != null and la.holder(0) != null),
		"роли у всех")
	LobbyLink.host_press(room, host, "ready")
	LobbyLink.guest_press(la, ca, "ready")
	ok(_pump(func() -> bool: return la.mine().ready and lb.find(ca.id).ready), "готовность видна")
	ok(not room.enabled("start"), "не все готовы — старта нет")
	eq(lb.note(), "Готовы 2 из 3 · подтвердите готовность")
	LobbyLink.guest_press(lb, cb, "ready")
	ok(_pump(func() -> bool: return room.can_start()), "все готовы")
	eq(LobbyLink.guest_press(la, ca, "start"), "", "у гостя старта нет")
	eq(LobbyLink.host_press(room, host, "start"), "start")
	ok(room.started)
	ok(_pump(func() -> bool: return la.started and lb.started), "старт у всех")
	LobbyLink.seat(room, host)
	eq((host.guests[ca.id] as NetLink.Guest).role, Crew.Role.SONAR, "роль на палубе — из комнаты, не из join")
	eq((host.guests[cb.id] as NetLink.Guest).role, 3)


func test_leave_frees_role() -> void:
	var ab := _two()
	var ca: NetLink.Client = ab[0][0]
	var lb: Lobby = ab[1][1]
	LobbyLink.guest_press(ab[0][1], ca, "pick1")
	ok(_pump(func() -> bool: return lb.holder(1) != null), "роль занята")
	ca.stop()
	ok(_pump(func() -> bool: return lb.players.size() == 2), "ушёл — у второго двое")
	eq(room.holder(1), null, "роль свободна")
	ok(lb.can_pick(1), "можно выбрать")


func test_room_messages_ignored_before_hello() -> void:
	var c := NetLink.Client.new()
	c.send_room("role:0")   # не на борту — не шлёт и не падает
	eq(c.take_room(), {})
	eq(c.take_answers(), [])
