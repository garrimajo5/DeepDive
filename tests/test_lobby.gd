extends TestCase
## Экран сбора экипажа ART-028 (`Lobby`, `LobbyPanel`): правила комнаты (роль закрепляет хост, чужой выбор не
## перезаписывается, смена роли снимает готовность, старт — только хост при 2–4 готовых), строки по макету, снимок
## для гостя, раскладка на телефонах и касания.

const SIZES := [Vector2(2400, 1080), Vector2(1600, 720), Vector2(1920, 1080), Vector2(2340, 1080), Vector2(2560, 1080)]


func _room() -> Lobby:
	var l := Lobby.new()
	l.host("Игрок 1")
	l.open = true
	l.add(2, "Игорь")
	l.add(3, "")
	return l


func test_seats_and_names() -> void:
	var l := _room()
	eq(l.players.size(), 3)
	eq(l.find(3).name, "Игрок 3", "без имени — «Игрок N»")
	ok(l.add(4, "Лена"), "четвёртый входит")
	ok(not l.add(5, "Пятый"), "пятому места нет")
	eq(Lobby.short("Александра-Мария Петровна", 1).length(), Lobby.NAME_MAX, "длинное имя — одной строкой")
	ok(Lobby.short("Александра-Мария Петровна", 1).ends_with("…"))
	l.remove(4)
	eq(l.head(), "3 из 4 мест · все подключённые выбирают роль")


func test_role_rules() -> void:
	var l := _room()
	eq(l.act(2, "role:1"), "")
	eq(l.act(3, "role:1"), "taken", "чужой выбор не перезаписывается")
	eq(l.holder(1).id, 2)
	eq(l.act(2, "ready"), "")
	ok(l.find(2).ready)
	eq(l.act(2, "role:3"), "", "своя роль меняется на свободную")
	ok(not l.find(2).ready, "смена роли снимает готовность")
	eq(l.holder(1), null, "прежняя роль свободна")
	eq(l.act(3, "ready"), "no_role", "без роли не готов")
	l.remove(2)
	eq(l.holder(3), null, "ушёл — роль свободна")


func test_start_only_host_all_ready() -> void:
	var l := Lobby.new()
	l.host("Игрок 1")
	l.act(Lobby.HOST, "role:0")
	l.act(Lobby.HOST, "ready")
	ok(not l.can_start(), "один — не старт")
	eq(l.note(), "Ждём товарищей · нужно от 2 до 4 игроков")
	l.add(2, "Игорь")
	ok(not l.can_start(), "товарищ без роли")
	l.act(2, "role:2")
	eq(l.note(), "Готовы 1 из 2 · ждём остальных")
	l.act(2, "ready")
	ok(l.can_start(), "двое готовы — свободные места не мешают")
	eq(l.act(2, "start"), "not_host", "старт — только хост")
	ok(not l.started)
	eq(l.note(), "Все 2 игрока готовы · свободное место не мешает старту")
	eq(l.act(Lobby.HOST, "start"), "")
	ok(l.started)
	eq(l.act(2, "unready"), "gone", "после старта комната не меняется")


func test_rows_show_state_not_only_color() -> void:
	var l := _room()
	l.act(Lobby.HOST, "role:0")
	l.act(2, "role:1")
	l.act(2, "ready")
	eq(l.look(0), Lobby.Look.WAIT)
	eq(l.look(1), Lobby.Look.READY)
	eq(l.look(3), Lobby.Look.FREE)
	eq(l.who(0), "Игрок 1 · вы · хост")
	eq(l.who(1), "Игорь")
	eq(l.who(3), "Свободно")
	eq(l.subtitle(), "Забег «Игрок 1» · вы — хост")
	eq(l.note(), "Готовы 1 из 3 · подтвердите готовность")
	eq(l.ready_text(), "Готов")


func test_host_press_applies_and_refuses() -> void:
	var l := _room()
	l.act(2, "role:1")
	ok(not l.enabled("pick1"), "у занятой роли нет «Выбрать роль»")
	eq(l.press("pick1"), "", "погашенная не отвечает")
	ok(not l.enabled("ready"), "без роли «Готов» погашен")
	eq(l.press("pick0"), "role:0")
	eq(l.mine().role, 0, "у хоста запрос сразу применён")
	eq(l.press("ready"), "ready")
	ok(l.mine().ready)
	eq(l.ready_text(), "Отменить готовность")
	eq(l.press("ready"), "unready")
	ok(not l.mine().ready)
	ok(not l.enabled("start"))
	ok(not l.enabled("create") and not l.enabled("search"), "в комнате «Создать» и «Подключиться» погашены")


func test_guest_sees_host_snapshot_and_refusal() -> void:
	var h := _room()
	h.act(Lobby.HOST, "role:0")
	h.act(2, "role:1")
	h.act(2, "ready")
	var g := Lobby.new()
	g.open = true
	g.me = 3
	g.unpack(h.pack())
	eq(g.players.size(), 3)
	eq(g.who(0), "Игрок 1 · хост")
	eq(g.look(1), Lobby.Look.READY)
	eq(g.subtitle(), "Забег «Игрок 1» · подключено")
	eq(g.start_text(), "Ждём начала от хоста")
	eq(g.press("pick0"), "", "занятую роль гость не просит")
	var q := g.press("pick2")
	eq(q, "role:2", "гость шлёт запрос хосту")
	eq(g.mine().role, -1, "у гостя роль ставит хост")
	g.answer(h.act(3, q), q)
	g.unpack(h.pack())
	eq(g.mine().role, 2)
	# Отказ: двое одновременно попросили одну роль — второму «Занято»
	h.act(2, "role:3")
	var g2 := Lobby.new()
	g2.me = 2
	g2.open = true
	g2.unpack(h.pack())
	h.act(Lobby.HOST, "role:1")   # хост успел раньше
	g2.answer(h.act(2, "role:1"), "role:1")
	g2.unpack(h.pack())
	eq(g2.look(1), Lobby.Look.TAKEN, "отказ — «Занято» в строке")
	ok(not g2.shows_back(), "своя роль осталась — кнопки готовности на месте")
	var g3 := Lobby.new()
	g3.me = 4
	g3.open = true
	h.add(4, "Лена")
	g3.answer(h.act(4, "role:1"), "role:1")
	g3.unpack(h.pack())
	eq(g3.look(1), Lobby.Look.TAKEN, "отказ — замок «Занято»")
	ok(g3.shows_back(), "«Назад к списку»")
	ok(not g3.enabled("ready"))
	eq(g3.note(), "Сонарщик уже занят: Игрок 1. Выберите П.")
	eq(g3.subtitle(), "Забег «Игрок 1» · выберите свободную роль")
	eq(g3.press("back"), "back")
	ok(not g3.open)


func test_layout_fits_and_spacing() -> void:
	for size: Vector2 in SIZES:
		var screen := Rect2(Vector2.ZERO, size)
		var ids := ["create", "search", "ready", "start", "back"]
		for i in Lobby.SEATS:
			ids.append("pick%d" % i)
			var row := Lobby.rect_to_screen(Lobby.row_rect(i), size)
			ok(screen.encloses(row), "строка %d на экране %s" % [i, size])
			ok(row.encloses(Lobby.screen_rect("pick%d" % i, size)), "«Выбрать роль» внутри строки")
		for id: String in ids:
			var r := Lobby.screen_rect(id, size)
			ok(screen.encloses(r), "%s на экране %s" % [id, size])
			ok(r.size.y >= 96.0 * Lobby.scale(size) - 0.01, "кнопка ≥ 96 px макета")
		ok(not Lobby.screen_rect("ready", size).intersects(Lobby.screen_rect("start", size)))
		near(Lobby.screen_rect("start", size).position.x - Lobby.screen_rect("ready", size).end.x,
			40.0 * Lobby.scale(size), 0.01, "между кнопками ≥ 30 px макета")
		for id: String in ["leave", "ready", "start", "back", "note", "pick3"]:   # хост: всё ниже на SHIFT
			ok(screen.encloses(Lobby.screen_rect(id, size, Lobby.SHIFT)), "%s хоста на экране %s" % [id, size])
		ok(screen.encloses(Lobby.rect_to_screen(Lobby.ADDR, size)))
		ok(screen.encloses(Lobby.rect_to_screen(Lobby.row_rect(3, Lobby.SHIFT), size)))
	ok(Lobby.row_rect(3, Lobby.SHIFT).end.y <= Lobby.NOTE.position.y + Lobby.SHIFT, "роли не заходят на строку под ними")
	ok(Lobby.NOTE.end.y + Lobby.SHIFT <= Lobby.READY.position.y + Lobby.SHIFT)
	ok(Lobby.READY.end.y + Lobby.SHIFT <= Lobby.H, "кнопки хоста на экране")
	# углы под крестовиной и кнопкой действия пусты (макет: x < 360 и x > 2040 при y > 760)
	for r: Rect2 in [Lobby.READY, Lobby.START, Lobby.BACK, Lobby.NOTE]:
		ok(r.position.x >= 360.0 and r.end.x <= 2040.0, "низ экрана — между углами")


func test_hit_finds_buttons() -> void:
	var l := _room()
	var size := Vector2(1600, 720)
	eq(l.hit(l.rect("pick2", size).get_center(), size), "pick2")
	eq(l.hit(l.rect("ready", size).get_center(), size), "", "без роли «Готов» не нажать")
	eq(l.hit(Lobby.screen_rect("create", size).get_center(), size), "")
	l.press("pick0")
	eq(l.hit(l.rect("ready", size).get_center(), size), "ready")
	l.open = false
	eq(l.hit(l.rect("pick2", size).get_center(), size), "", "закрыт — касания мимо")


## ART-039: у хоста «Ваш адрес» над ролями, строки ниже на 20 px, «Назад» вверху вместо «Создать» / «Подключиться».
func test_host_address_plate() -> void:
	var l := Lobby.new()
	l.host("Игрок 1", "192.168.43.17")
	l.open = true
	ok(l.shows_address())
	eq(l.address_text(), "192.168.43.17")
	eq(l.address_hint(), "Скажите его товарищам")
	near(l.dy(), 20.0, 0.001)
	eq(Lobby.row_rect(0, l.dy()).position.y, 320.0, "первая строка — 320 по макету ART-039")
	eq(l.rect("ready", Vector2(Lobby.W, Lobby.H)).position.y, 920.0)
	ok(Lobby.ADDR.end.y + 30.0 <= Lobby.row_rect(0, l.dy()).position.y, "30 px между адресом и первой строкой")
	ok(not Lobby.ADDR.intersects(Lobby.LEAVE), "«Назад» не на плашке")
	var size := Vector2(1600, 720)
	eq(l.hit(l.rect("leave", size).get_center(), size), "leave")
	eq(l.hit(Lobby.screen_rect("create", size).get_center(), size), "", "«Создать забег» у хоста нет")
	eq(l.press("leave"), "back", "«Назад» — выйти из комнаты")
	ok(not l.open)
	var none := Lobby.new()
	none.host("Игрок 1")
	eq(none.address_text(), "Нет адреса сети")
	eq(none.address_hint(), "Подключитесь к сети")
	# у гостя плашки нет: макет ART-028 без сдвига, «Назад» вверху не работает
	var g := Lobby.new()
	g.open = true
	g.me = 3
	g.unpack(l.pack())
	ok(not g.shows_address())
	eq(g.dy(), 0.0)
	eq(g.hit(Lobby.screen_rect("leave", size).get_center(), size), "")
	# адрес устройства — локальная сеть, если есть
	var a := Lobby.local_address()
	ok(a == "" or AddressPad.check(a) == AddressPad.Check.OK, "адрес устройства — IPv4 или пусто")


func test_panel_draws() -> void:
	var l := _room()
	l.press("pick0")
	var p := LobbyPanel.new()
	tree.root.add_child(p)
	p.show_lobby(l)
	ok(p.visible)
	await frames(2)
	var e := Lobby.new()   # поиск: строки забегов и подключение
	e.show_entry()
	var run := RunBeacon.Found.new()
	run.name = "Лена"
	run.players = 2
	run.vacant = [3]
	e.runs = [run, RunBeacon.Found.new()]
	e.joining = 0
	p.show_lobby(e)
	await frames(2)
	e.runs = []
	e.joining = -1
	p.show_lobby(e)
	await frames(1)
	l.open = false
	p.show_lobby(l)
	ok(not p.visible, "закрыт — скрыт")
	p.queue_free()
	await frames(1)


## Поиск забегов ART-028: три кнопки внизу между углами с зазором ≥ 30 px, строки забегов на экране и над кнопками,
## «Подключиться» внутри строки; заголовок, подпись и кнопки по найденному.
func test_search_list() -> void:
	for size: Vector2 in SIZES:
		var screen := Rect2(Vector2.ZERO, size)
		for i in Lobby.RUN_ROWS:
			var row := Lobby.rect_to_screen(Lobby.run_rect(i), size)
			ok(screen.encloses(row), "строка забега %d на экране" % i)
			ok(row.encloses(Lobby.screen_rect("join%d" % i, size)), "«Подключиться» внутри строки")
	ok(Lobby.run_rect(Lobby.RUN_ROWS - 1).end.y + 30.0 <= Lobby.NEW.position.y, "строки над кнопками")
	ok(Lobby.RUN_ROW.position.y >= Lobby.LIST_HEAD_AT.y + Lobby.ROLE_PX, "заголовок над строками")
	var bottom: Array[Rect2] = [Lobby.NEW, Lobby.BY_ADDR, Lobby.REFRESH]
	for k in bottom.size():
		ok(bottom[k].position.x >= 360.0 and bottom[k].end.x <= 2040.0, "низ — между углами")
		ok(bottom[k].size.y >= 96.0)
		if k > 0:
			ok(bottom[k].position.x - bottom[k - 1].end.x >= 30.0, "между кнопками ≥ 30 px")
	ok(Lobby.JOIN.size.y >= 96.0)
	var l := Lobby.new()
	l.show_entry()
	l.searching = true
	eq(l.entry_head(), "Ищем забеги…")
	eq(l.entry_sub(), "Одна сеть Wi-Fi · ищем забеги…")
	l.searching = false
	eq(l.entry_head(), "Никого нет")
	ok(not l.enabled("join0"))
	var a := RunBeacon.Found.new()
	a.name = "Лена"
	a.players = 2
	a.vacant = [2, 3]
	var b := RunBeacon.Found.new()
	b.name = "Игорь"
	b.players = 4
	l.runs = [a, b]
	eq(l.entry_head(), "Найдено 2 забега")
	eq(l.entry_sub(), "Одна сеть Wi-Fi · выберите забег")
	ok(l.enabled("join0") and not l.enabled("join1"), "полный забег не открыть")
	eq(l.join_text(1), "Мест нет")
	var size := Vector2(1600, 720)
	eq(l.hit(l.rect("join0", size).get_center(), size), "join0")
	eq(l.hit(l.rect("refresh", size).get_center(), size), "refresh")
	eq(l.press("refresh"), "refresh")
	eq(l.press("search"), "refresh", "«Подключиться» вверху — поиск заново")
	eq(l.press("join0"), "join")
	eq(l.joining, 0)
	eq(l.join_text(0), "Подключаемся…")
	for id: String in ["new", "address", "refresh", "create", "search", "join0"]:
		ok(not l.enabled(id), "%s ждёт, пока идёт подключение" % id)
	l.joining = -1
	l.why = "full"
	eq(l.entry_head(), "Экипаж полон", "отказ хоста — вместо заголовка")
	l.press("refresh")
	eq(l.entry_head(), "Найдено 2 забега", "новый поиск снимает причину")
	l.runs = [a, b, a, b]
	eq(l.shown_runs(), Lobby.RUN_ROWS)
	ok(not l.enabled("join3"))


## Лист ART-028 «05 · Связь потеряна»: у гостя вместо ролей карточка, готовность сброшена; «Повторить» ждёт хоста
## («Подключаемся…»), неудача — причина первой строкой; «К списку забегов» — выйти из комнаты; повтор удался — снова
## в комнате по снимку хоста.
func test_lost_card() -> void:
	var host := _room()
	host.act(Lobby.HOST, "role:0")
	host.act(3, "role:2")
	host.act(3, "ready")
	var l := Lobby.new()
	l.guest()
	l.me = 3
	l.unpack(host.pack())
	ok(l.mine().ready)
	l.lose()
	ok(l.lost and not l.mine().ready, "готовность сброшена")
	eq(l.subtitle(), "Забег «Игрок 1» · соединение прервано")
	eq(l.lost_lines(), ["Проверьте Wi-Fi и телефон хоста.", "Готовность будет сброшена."])
	var size := Vector2(1600, 720)
	for id: String in ["ready", "pick1", "pick3", "start", "back", "create", "search"]:
		ok(not l.enabled(id), "%s под карточкой не работает" % id)
	eq(l.hit(l.rect("retry", size).get_center(), size), "retry")
	eq(l.press("retry"), "retry")
	ok(l.retrying and not l.enabled("retry"), "ждём хоста — второй раз не нажать")
	eq(l.retry_text(), "Подключаемся…")
	ok(l.enabled("tolist"), "к списку — и во время попытки")
	l.retry_failed("timeout")
	ok(not l.retrying and l.enabled("retry"))
	eq(l.lost_lines()[0], "Хост не отвечает. Проверьте Wi-Fi и телефон хоста.")
	eq(l.retry_text(), "Повторить")
	l.rejoined()
	ok(not l.lost and l.players.is_empty(), "снова в комнате — ждём снимок хоста")
	l.me = 4
	host.remove(3)
	host.add(4, "")
	l.unpack(host.pack())
	ok(l.mine() != null and l.mine().role < 0 and not l.mine().ready, "роль и готовность — заново")
	l.lose()
	eq(l.press("tolist"), "back", "«К списку забегов» — выйти из комнаты")
	ok(not l.open)
	l.show_entry()
	ok(not l.lost, "на входе карточки нет")


func test_lost_card_layout() -> void:
	for size: Vector2 in SIZES:
		var screen := Rect2(Vector2.ZERO, size)
		var box := Lobby.rect_to_screen(Lobby.LOST_BOX, size)
		ok(screen.encloses(box))
		for id: String in ["retry", "tolist"]:
			var r := Lobby.screen_rect(id, size)
			ok(box.encloses(r), "%s в карточке на %s" % [id, size])
			ok(r.size.y >= 96.0 * Lobby.scale(size) - 0.01)
	ok(Lobby.TO_LIST.position.x - Lobby.RETRY.end.x >= 30.0, "между кнопками ≥ 30 px")
	ok(Lobby.LOST_BOX.position.x >= 360.0 and Lobby.LOST_BOX.end.x <= 2040.0, "мимо углов крестовины и действия")
