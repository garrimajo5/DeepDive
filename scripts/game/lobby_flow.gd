class_name LobbyFlow
extends RefCounted
## Сбор экипажа ART-028 и вход по адресу ART-039 поверх меню сцены `Main` (#755). Вход сбора — поиск забегов
## (`main.finder`), «Создать забег» (хост `main.net_host`, маяк `main.beacon`), подключение из списка
## (`main.lobby_join`), «По адресу» (`main.address`, попытка `main.address_client`); комната — у хоста
## `LobbyLink.serve`, у гостя `LobbyLink.take` (`main.lobby_client`). Старт забега — `NetGame.seat_guest`/`_begin_run`
## у хоста и `NetGame.enter_client` у гостя. Состояние — поля `main.lobby`, `main.address`, панели —
## `main.lobby_panel`, `main.address_panel`. Живёт полем `main.lobby_flow`; входы для тестов и `tools/`
## (`open_lobby`, `open_address`) — тонкие пересылки у `Main`.

var main: Main


func _init(m: Main) -> void:
	main = m


## Сбор экипажа ART-028 по «Экипаж»: вход — поиск забегов в сети (`finder`), «Создать забег», «По адресу».
func open_lobby(why := "") -> void:
	main.lobby.show_entry(why)
	if main.finder.udp == null:
		main.finder.start()   # порт занят — список пуст, «Никого нет»; «По адресу» работает
	else:
		main.finder.search()
	_runs()
	lobby_show()
	main.overlay.router.clear()   # палец с кнопки «Экипаж» не нажмёт кнопку входа под ним


func lobby_show() -> void:
	if main.lobby_panel == null:
		main.lobby_panel = LobbyPanel.new()
		main.add_child(main.lobby_panel)
	main.lobby_panel.show_lobby(main.lobby)
	main.lobby_panel.visible = main.lobby.open and not main.address.open   # «По адресу» — экран адреса поверх входа
	if main.menu_panel:
		main.menu_panel.visible = main.main_menu.open and not main.lobby.open and not main.address.open


## Шаг сбора экипажа: касания кнопок; у хоста — гости в комнату (`LobbyLink.serve`), у гостя — снимок хоста
## (`LobbyLink.take`); «Начать погружение» — забег у всех с ролями из комнаты.
func lobby_step(r: Touch.Router, dt: float) -> void:
	var size := main.get_viewport().get_visible_rect().size
	for p in r.taps:
		var id := main.lobby.hit(p, size)
		if id == "":
			continue
		if main.lobby.entry:
			match main.lobby.press(id):
				"create":
					main.finder.stop()
					_create()
				"address":
					open_address()
				"refresh":
					main.finder.search()
					_runs()
				"join":
					_join_start()
			main.overlay.router.clear()
			lobby_show()
			return
		var q := ""
		if main.net_host:
			q = LobbyLink.host_press(main.lobby, main.net_host, id)
		elif main.lobby_client:
			q = LobbyLink.guest_press(main.lobby, main.lobby_client, id)
		if q == "back":
			lobby_back(true)
			return
		if q == "retry" and main.lobby_client and main.lobby_client.rejoin(NetLink.TIMEOUT) != OK:
			main.lobby.retry_failed("timeout")
	if main.lobby.entry:
		main.finder.poll(dt)
		_runs()
		if main.lobby_join:
			_join_step(dt)
	elif main.net_host:
		main.beacon.step(dt, main.lobby, main.lobby_port)
		LobbyLink.serve(main.lobby, main.net_host, main.net_host.poll(dt))
		if main.lobby.started:
			_start_host()
			return
	elif main.lobby_client:
		main.lobby_client.poll(dt)
		if main.lobby.lost:   # карточка «Связь потеряна»: ждём ответа на «Повторить»
			if main.lobby.retrying:
				match main.lobby_client.state:
					NetLink.State.JOINED:
						main.lobby.rejoined()
						LobbyLink.take(main.lobby, main.lobby_client)
					NetLink.State.REFUSED, NetLink.State.LOST, NetLink.State.OFF:
						main.lobby.retry_failed(main.lobby_client.why)
		else:
			LobbyLink.take(main.lobby, main.lobby_client)
			if main.lobby.started and main.lobby_client.joined():
				_start_guest()
				return
			if not main.lobby_client.joined():   # хост закрыл забег или связь пропала — «Повторить» / «К списку забегов»
				main.lobby.lose()
	lobby_show()


## Список найденных забегов — на экран входа (строку подключения держит, пока идёт попытка).
func _runs() -> void:
	if main.lobby_join == null:
		main.lobby.runs = main.finder.runs.duplicate()
	main.lobby.searching = not main.finder.done()


## «Подключиться» в строке забега: вход к хосту по адресу и порту из маяка.
func _join_start() -> void:
	var run: RunBeacon.Found = main.lobby.runs[main.lobby.joining]
	main.lobby_join = NetLink.Client.new()
	if main.lobby_join.join(run.address, run.port) != OK:
		_join_end("timeout")


## Ответ хоста на подключение из списка: принят — в его комнату, отказ или тишина — причина вместо заголовка.
func _join_step(dt: float) -> void:
	main.lobby_join.poll(dt)
	match main.lobby_join.state:
		NetLink.State.JOINED:
			var c := main.lobby_join
			main.lobby_join = null
			main.finder.stop()
			main.lobby_client = c
			main.lobby.guest()
			LobbyLink.take(main.lobby, c)
		NetLink.State.REFUSED, NetLink.State.LOST, NetLink.State.OFF:
			_join_end(main.lobby_join.why if main.lobby_join.why != "" else "timeout")


## Попытка из списка кончилась ничем (why — ключ `NetLink.WHY`; "" — отменена); список снова живой.
func _join_end(why: String) -> void:
	if main.lobby_join:
		main.lobby_join.stop()
		main.lobby_join = null
	main.lobby.joining = -1
	main.lobby.why = why
	_runs()


## «Создать забег»: открыть хост и комнату, где хост — первый игрок со своим адресом (ART-039).
func _create() -> void:
	main.net_host = NetLink.Host.new()
	if main.net_host.start(main.lobby_port) != OK:
		main.net_host = null
		open_lobby("port")
		return
	main.lobby.host("", Lobby.local_address())
	main.lobby.open = true
	main.beacon.start()   # нет сети — маяка нет, вход по адресу работает
	lobby_show()


## Выйти из комнаты: хост закрывает забег (у гостей — «Связь с хостом потеряна»), гость уходит; со входа — в меню.
## pressed — «Назад» уже нажата (комната закрыта), иначе — системная «Назад».
func lobby_back(pressed := false) -> void:
	if main.lobby_join and not pressed:   # «Назад» во время подключения из списка — отменить попытку, остаться в поиске
		_join_end("")
		lobby_show()
		return
	var in_room := not main.lobby.entry
	if not in_room:
		main.finder.stop()
	if not pressed:
		main.lobby.back()
	main.beacon.stop()
	if main.net_host:
		main.net_host.stop()
		main.net_host = null
	if main.lobby_client:
		main.lobby_client.stop()
		main.lobby_client = null
	if in_room:
		open_lobby()
		return
	lobby_show()
	if main.menu_panel:
		main.menu_panel.show_menu(main.main_menu)


## Хост: «Начать погружение» принято — роли гостей из комнаты (`LobbyLink.seat`), свой — тоже, гости на палубе,
## забег с начала. Снимок со стартом уже ушёл всем (`LobbyLink.host_press`).
func _start_host() -> void:
	main.beacon.stop()   # забег начался — в списках гостей он больше не нужен
	LobbyLink.seat(main.lobby, main.net_host)
	var mine := main.lobby.mine()
	if mine and mine.role >= 0:
		main.me.role = mine.role
		main.me.name = mine.name
	main.close_menu()
	for g: NetLink.Guest in main.net_host.guests.values():
		var p := main.lobby.find(g.id)
		var m := main.net_game.seat_guest(g)
		if p:
			m.name = p.name   # имя как в комнате («Игрок 3», если телефон не назвался)
	main.crew_view.set_members(main.crew, main.me)
	main.net_game.net_index()
	main._begin_run()


## Гость: старт у хоста — дальше кадры хоста (`NetGame.enter_client`); облёта у гостя нет.
func _start_guest() -> void:
	var c := main.lobby_client
	main.lobby_client = null
	main.close_menu()
	c.quiet = 0.0   # в комнате кадров не было — «Нет связи» не мигнёт до первого кадра
	main.net_game.enter_client(c)


## Экран «Войти по адресу» ART-039 поверх входа сбора экипажа ART-028 («По адресу»).
func open_address() -> void:
	main.address.show()
	if main.address_panel == null:
		main.address_panel = AddressPanel.new()
		main.add_child(main.address_panel)
	main.address_panel.show_screen(main.address)
	if main.menu_panel:
		main.menu_panel.visible = false
	if main.lobby_panel:
		main.lobby_panel.visible = false


## Шаг экрана адреса: клавиши, «Войти» / «Отмена», «Назад»; попытка входа ждёт ответа хоста здесь, под экраном.
## На борту — экран и меню закрыты, дальше — шаг клиента (`NetGame.enter_client`).
func address_step(r: Touch.Router, dt: float) -> void:
	for p in r.taps:
		address_do(main.address.press(main.address.hit(p, main.get_viewport().get_visible_rect().size)))
	if main.address_client:
		main.address_client.poll(dt)
		if main.address.result(main.address_client.state, main.address_client.why):   # хост принял — в его комнату (ART-028)
			var c := main.address_client
			main.address_client = null
			main.address.open = false
			main.address_panel.show_screen(main.address)
			main.lobby_client = c
			main.finder.stop()
			main.lobby.guest()
			LobbyLink.take(main.lobby, c)
			lobby_show()
			return
		if not main.address.field.connecting:
			main.address_client = null
	if main.address_panel:
		main.address_panel.show_screen(main.address)


## Что сказал экран адреса: подключаться, бросить попытку или вернуться в меню.
func address_do(what: String) -> void:
	match what:
		"join":
			main.address_client = NetLink.Client.new()
			if main.address_client.join(main.address.field.text) != OK:
				main.address_client = null
				main.address.failed()
		"cancel", "back":
			if main.address_client:
				main.address_client.stop()
				main.address_client = null
			if what == "back":
				if main.address_panel:
					main.address_panel.show_screen(main.address)
				if main.lobby.open:   # назад — ко входу сбора экипажа
					lobby_show()
				elif main.menu_panel:
					main.menu_panel.show_menu(main.main_menu)
