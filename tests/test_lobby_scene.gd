extends TestCase
## Сбор экипажа ART-028 в игре: «Экипаж» в меню — вход «Создать забег» / «По адресу»; хост — комната со своим
## адресом, гости в комнату, не на палубу; «Начать погружение» — забег у всех с ролями из комнаты; гость по адресу —
## в комнату хоста, старт — на борт кадрами хоста. «Назад» — из комнаты ко входу, со входа в меню.

const PORT := 24760
const DT := 1.0 / 30.0
const PUMP := 150
var main: Main
var host: NetLink.Host
var client: NetLink.Client
var room: Lobby


func after() -> void:
	Main.menu = false
	if client:
		client.stop()
		client = null
	if main:
		if main.net_client:
			main.net_client.stop()
		if main.lobby_client:
			main.lobby_client.stop()
		if main.net_host:
			main.net_host.stop()
		main.queue_free()
		main = null
	if host:
		host.stop()
		host = null
	await frames(1)


func _main() -> void:
	Main.menu = true
	main = load("res://scenes/main.tscn").instantiate()
	main.lobby_port = PORT
	tree.root.add_child(main)
	await frames(2)


func _tap(p: Vector2) -> void:
	var r := main.overlay.router
	r.begin(7, p)
	main.step(DT)
	r.end(7)
	main.step(DT)


func _size() -> Vector2:
	return main.get_viewport().get_visible_rect().size


## Шаги сцены и гостя-теста, пока cond не станет true.
func _pump(cond: Callable) -> bool:
	for i in PUMP:
		main.step(DT)
		if host:
			LobbyLink.serve(room, host, host.poll(DT))
		if client and client.peer:
			client.poll(DT)
			LobbyLink.take(room, client)
		if cond.call():
			return true
		OS.delay_msec(2)
	return false


func test_entry_and_back() -> void:
	await _main()
	_tap(MainMenu.screen_rect("crew", _size()).get_center())
	ok(main.lobby.open and main.lobby.entry, "«Экипаж» — вход сбора")
	ok(main.lobby_panel.visible and not main.menu_panel.visible, "вход вместо меню")
	ok(main.lobby.enabled("new") and main.lobby.enabled("address") and main.lobby.enabled("create"))
	ok(not main.lobby.enabled("search"), "«Подключиться» погашена до поиска забегов")
	eq(main.lobby.entry_head(), "Кооп-забег")
	main.back_pressed()
	ok(not main.lobby.open and main.menu_panel.visible, "«Назад» — меню")
	ok(main.main_menu.open)


func test_host_room_and_start() -> void:
	await _main()
	_tap(MainMenu.screen_rect("crew", _size()).get_center())
	_tap(Lobby.screen_rect("new", _size()).get_center())
	ok(main.net_host != null and main.net_host.active(), "«Создать забег» — хост открыт")
	ok(main.lobby.open and not main.lobby.entry and main.lobby.is_host(), "комната хоста")
	eq(main.lobby.players.size(), 1)
	eq(main.lobby.mine().name, "Игрок 1")
	ok(main.main_menu.open, "под комнатой игра стоит")
	# гость по адресу — в комнату, не на палубу
	client = NetLink.Client.new()
	eq(client.join("127.0.0.1", PORT, "Ира", Crew.Role.PILOT, 1), OK)
	room = Lobby.new()
	room.guest()
	ok(_pump(func() -> bool: return room.players.size() == 2 and main.lobby.players.size() == 2), "гость в комнате")
	eq(main.crew.size(), 1, "на палубе гостя нет")
	eq((main.net_host.guests.values()[0] as NetLink.Guest).index, -1, "кадров гостю нет")
	# роли и готовность
	_tap(main.lobby.rect("pick2", _size()).get_center())
	eq(main.lobby.mine().role, Crew.Role.ENGINEER, "хост — инженер")
	_tap(main.lobby.rect("ready", _size()).get_center())
	LobbyLink.guest_press(room, client, "pick1")
	ok(_pump(func() -> bool: return room.mine() != null and room.mine().role == 1), "гость — сонарщик")
	LobbyLink.guest_press(room, client, "ready")
	ok(_pump(func() -> bool: return main.lobby.can_start()), "все готовы")
	_tap(main.lobby.rect("start", _size()).get_center())
	ok(not main.main_menu.open and not main.lobby.open, "«Начать погружение» — меню и комната закрыты")
	ok(not main.lobby_panel.visible)
	eq(main.me.role, Crew.Role.ENGINEER, "свой игрок — роль из комнаты")
	eq(main.crew.size(), 2, "гость на палубе")
	var m: Crew.Member = main.crew[1]
	eq(m.role, Crew.Role.SONAR, "роль гостя — из комнаты, не из join")
	eq(m.name, "Ира")
	ok(_pump(func() -> bool: return room.started), "старт и у гостя")
	var got := false
	for i in PUMP:
		main.step(DT)
		if not client.poll(DT).is_empty():
			got = true
			break
		OS.delay_msec(2)
	ok(got, "гость получает кадры")
	eq(client.me, 1, "его место в экипаже")
	# запрос комнаты после старта (опоздавший пакет) — не уход с палубы
	client.send_room("ready")
	for i in 20:
		main.step(DT)
		client.poll(DT)
		OS.delay_msec(2)
	eq(main.crew.size(), 2, "запрос комнаты после старта не убирает гостя")


func test_host_back_closes_room() -> void:
	await _main()
	_tap(MainMenu.screen_rect("crew", _size()).get_center())
	_tap(Lobby.screen_rect("new", _size()).get_center())
	ok(main.net_host != null)
	_tap(main.lobby.rect("leave", _size()).get_center())
	ok(main.net_host == null, "«Назад» хоста — забег закрыт")
	ok(main.lobby.open and main.lobby.entry, "снова вход")
	_tap(Lobby.screen_rect("new", _size()).get_center())
	ok(main.net_host != null, "забег открывается снова на том же порту")
	main.back_pressed()
	ok(main.net_host == null and main.lobby.entry, "системная «Назад» из комнаты — тоже вход")


func test_guest_by_address_to_deck() -> void:
	host = NetLink.Host.new()
	eq(host.start(PORT + 1), OK)
	room = Lobby.new()
	room.host("Лена", "127.0.0.1")
	room.open = true
	await _main()
	_tap(MainMenu.screen_rect("crew", _size()).get_center())
	_tap(Lobby.screen_rect("address", _size()).get_center())
	ok(main.address.open)
	main.address_client = NetLink.Client.new()
	eq(main.address_client.join("127.0.0.1", PORT + 1), OK)
	main.address.field.text = "127.0.0.1"
	main.address.field.begin()
	ok(_pump(func() -> bool: return main.lobby_client != null and main.lobby.players.size() == 2), "гость в комнате")
	ok(not main.lobby.is_host())
	eq(main.lobby.host_name(), "Лена")
	ok(main.main_menu.open and main.net_client == null, "в комнате — не на борту")
	_tap(main.lobby.rect("pick3", _size()).get_center())
	ok(_pump(func() -> bool: return main.lobby.mine() != null and main.lobby.mine().role == 3), "хост закрепил роль")
	_tap(main.lobby.rect("ready", _size()).get_center())
	room.press("pick0")
	room.press("ready")
	ok(_pump(func() -> bool: return room.can_start()), "все готовы у хоста")
	room.press("start")
	LobbyLink.share(room, host)
	ok(_pump(func() -> bool: return main.net_client != null), "старт хоста — гость на борту")
	ok(not main.main_menu.open and not main.lobby.open, "меню и комната закрыты")
	ok(main.lobby_client == null)


func test_guest_host_gone() -> void:
	host = NetLink.Host.new()
	eq(host.start(PORT + 2), OK)
	room = Lobby.new()
	room.host("Лена", "127.0.0.1")
	room.open = true
	await _main()
	_tap(MainMenu.screen_rect("crew", _size()).get_center())
	_tap(Lobby.screen_rect("address", _size()).get_center())
	main.address.field.text = "127.0.0.1"
	main.address.field.begin()
	main.address_client = NetLink.Client.new()
	eq(main.address_client.join("127.0.0.1", PORT + 2), OK)
	ok(_pump(func() -> bool: return main.lobby_client != null), "гость в комнате")
	host.stop()
	host = null
	ok(_pump(func() -> bool: return main.lobby.entry), "хост ушёл — вход")
	eq(main.lobby.entry_head(), "Связь с хостом потеряна")
	ok(main.lobby_client == null and main.net_client == null)
