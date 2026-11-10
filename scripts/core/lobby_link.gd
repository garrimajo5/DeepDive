class_name LobbyLink
## Сбор экипажа ART-028 по сети: комната `Lobby` поверх транспорта `NetLink` без узлов сцены.
## Хост: телефон пришёл — в комнату (`Lobby.add`), ушёл — роль свободна, запрос гостя (`lq`) решает `Lobby.act`
## (роль закрепляет хост, чужой выбор не перезаписать), ответ — только ему (`ans`: отказ «Занято»), снимок комнаты —
## всем (`room`), когда что-то сменилось. Гость: свой id от хоста (`Client.id`), нажатие — запрос хосту (`press`),
## снимок хоста и ответы — в свою комнату (`take`). «Начать погружение» у хоста: снимок с `go` — у всех забег,
## роли гостей на палубе — из комнаты (`seat` → `Guest.role`).


## Хост: события `Host.poll` (join / leave / room) в комнату; true — комната сменилась и снимок уже ушёл всем.
## Остальные события (не комнаты) возвращает в rest, если он передан.
static func serve(lobby: Lobby, host: NetLink.Host, events: Array, rest: Array = []) -> bool:
	var changed := false
	for e: Dictionary in events:
		var g: NetLink.Guest = e.get("guest")
		match str(e.get("k", "")):
			"join":
				changed = lobby.add(g.id, g.name) or changed
			"leave":
				if lobby.find(g.id) != null:
					lobby.remove(g.id)
					changed = true
			"room":
				var q: String = e.get("q", "")
				var why := lobby.act(g.id, q)
				host.answer(g.id, q, why)
				changed = changed or why == ""
			_:
				rest.append(e)
	if changed:
		share(lobby, host)
	return changed


## Хост: снимок комнаты всем гостям (после своего нажатия или событий).
static func share(lobby: Lobby, host: NetLink.Host) -> void:
	host.send_room(lobby.pack())


## Хост: своё нажатие кнопки id (`Lobby.press`); принятое — снимок всем. Возвращает запрос ("back" — вышел).
static func host_press(lobby: Lobby, host: NetLink.Host, id: String) -> String:
	var q := lobby.press(id)
	if q != "" and q != "back":
		share(lobby, host)
	return q


## Хост после старта: роли гостей на палубе — из комнаты (кто без роли — роль из `join`).
static func seat(lobby: Lobby, host: NetLink.Host) -> void:
	for g: NetLink.Guest in host.guests.values():
		var p := lobby.find(g.id)
		if p and p.role >= 0:
			g.role = p.role


## Гость: своё нажатие кнопки id — запрос хосту. Возвращает запрос ("back" — выйти из комнаты, "" — ничего).
static func guest_press(lobby: Lobby, client: NetLink.Client, id: String) -> String:
	var q := lobby.press(id)
	if q != "" and q != "back":
		client.send_room(q)
	return q


## Гость: ответы и свежий снимок хоста в свою комнату; true — комната сменилась.
static func take(lobby: Lobby, client: NetLink.Client) -> bool:
	var changed := false
	if client.id != 0:
		lobby.me = client.id
	for a: Array in client.take_answers():
		lobby.answer(a[1], a[0])
		changed = changed or a[1] != ""
	var r := client.take_room()
	if not r.is_empty():
		lobby.unpack(r)
		changed = true
	return changed
