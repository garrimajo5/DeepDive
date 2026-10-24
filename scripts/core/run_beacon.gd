class_name RunBeacon
## Поиск забегов в локальной сети по ART-028 (лист «01 · Поиск: забеги найдены»): хост, пока открыта комната сбора,
## раз в `EVERY` секунд шлёт широковещательный UDP-пакет «маяк» на `PORT` — имя забега, занято мест, свободные
## роли, порт ENet и версию кадра; гость слушает этот порт (`Finder`) и собирает список забегов, забывая молчащие
## дольше `FORGET`. Без узлов сцены и MultiplayerAPI: `PacketPeerUDP`, пакеты — словари `NetLink.encode`.
## Забег другой версии игры в список не попадает (к нему не войти). Экран списка — следующая часть ART-028.

const PORT := 24681            ## порт маяков (рядом с `NetLink.PORT`)
const EVERY := 1.0             ## хост шлёт маяк раз в столько секунд
const FORGET := 3.5            ## гость забывает забег, молчащий столько секунд (три маяка пропали)
const SEARCH_TIME := 3.0       ## «Обновить список»: столько секунд ищем, потом — «поиск завершён»
const BROADCAST := "255.255.255.255"


## Маяк хоста по комнате lobby: имя забега, игроков, свободные роли, порт ENet.
static func info(lobby: Lobby, port: int) -> Dictionary:
	var free := []
	for i in Lobby.SEATS:
		if lobby.holder(i) == null:
			free.append(i)
	return {"k": "run", "v": NetSnap.VERSION, "name": lobby.host_name(), "n": lobby.players.size(), "free": free,
		"port": port}


## Найденный забег в списке гостя.
class Found:
	extends RefCounted
	var address := ""
	var port := NetLink.PORT
	var name := ""
	var players := 0
	var vacant: Array[int] = []
	var age := 0.0          ## секунд с последнего маяка

	## «Забег «Лена»» — как подзаголовок комнаты (`Lobby.subtitle`).
	func title() -> String:
		return "Забег «%s»" % name

	## «2 / 4 · свободны И / Б», «3 / 4 · свободна С», «4 / 4 · мест нет».
	func line() -> String:
		var s := "%d / %d · " % [players, Lobby.SEATS]
		if vacant.is_empty():
			return s + "мест нет"
		var l := []
		for r in vacant:
			l.append(Lobby.LETTERS[r])
		return s + ("свободна " if vacant.size() == 1 else "свободны ") + " / ".join(l)

	## Можно ли войти: есть свободное место.
	func open() -> bool:
		return players < Lobby.SEATS


## Хост: маяк в сеть, пока открыта комната.
class Beacon:
	extends RefCounted
	var udp: PacketPeerUDP
	var to := RunBeacon.BROADCAST   ## тест шлёт на 127.0.0.1
	var to_port := RunBeacon.PORT
	var sent := 0
	var _acc := 0.0

	func start() -> Error:
		stop()
		udp = PacketPeerUDP.new()
		udp.set_broadcast_enabled(true)
		var e := udp.set_dest_address(to, to_port)
		if e != OK:
			udp = null
		_acc = RunBeacon.EVERY   # первый маяк — сразу
		return e

	func stop() -> void:
		if udp:
			udp.close()
		udp = null

	## Шаг хоста: раз в EVERY — маяк с `info`. true — маяк ушёл в этот шаг.
	func step(dt: float, lobby: Lobby, port: int) -> bool:
		if udp == null:
			return false
		_acc += dt
		if _acc < RunBeacon.EVERY:
			return false
		_acc = 0.0
		if udp.put_packet(NetLink.encode(RunBeacon.info(lobby, port))) == OK:
			sent += 1
			return true
		return false


## Гость: слушает маяки и держит список забегов.
class Finder:
	extends RefCounted
	var udp: PacketPeerUDP
	var port := RunBeacon.PORT
	var runs: Array[Found] = []
	var searching := 0.0    ## секунд поиска осталось (`search`); 0 — «поиск завершён»
	var version := NetSnap.VERSION   ## тест подменяет

	## Слушать порт; ошибка — порт занят (второй экземпляр игры на телефоне).
	func start() -> Error:
		stop()
		udp = PacketPeerUDP.new()
		var e := udp.bind(port, "*")
		if e != OK:
			udp = null
			return e
		search()
		return OK

	func stop() -> void:
		if udp:
			udp.close()
		udp = null
		searching = 0.0

	## «Обновить список»: список с нуля, снова ищем SEARCH_TIME.
	func search() -> void:
		runs.clear()
		searching = RunBeacon.SEARCH_TIME

	func done() -> bool:
		return searching <= 0.0

	## Шаг гостя: принять маяки, состарить и забыть молчащие. true — список сменился.
	func poll(dt: float) -> bool:
		var changed := false
		searching = maxf(searching - dt, 0.0)
		for r in runs:
			r.age += dt
		var n := runs.size()
		runs = runs.filter(func(r: Found) -> bool: return r.age <= RunBeacon.FORGET)
		changed = runs.size() != n
		if udp == null:
			return changed
		while udp.get_available_packet_count() > 0:
			var b := udp.get_packet()
			var ip := udp.get_packet_ip()
			changed = take(NetLink.decode(b), ip) or changed
		return changed

	## Маяк msg с адреса ip в список. true — список сменился.
	func take(msg: Dictionary, ip: String) -> bool:
		if str(msg.get("k", "")) != "run" or int(msg.get("v", -1)) != version or ip == "":
			return false
		var p := int(msg.get("port", NetLink.PORT))
		var r := find(ip, p)
		var fresh := r == null
		if fresh:
			r = Found.new()
			r.address = ip
			r.port = p
			runs.append(r)
		var was := [r.name, r.players, r.vacant.duplicate()]
		r.name = Lobby.short(str(msg.get("name", "")), 1)
		r.players = clampi(int(msg.get("n", 0)), 0, Lobby.SEATS)
		r.vacant.clear()
		var f: Variant = msg.get("free", [])
		if f is Array:
			for x: Variant in f:
				if int(x) >= 0 and int(x) < Lobby.SEATS and not r.vacant.has(int(x)):
					r.vacant.append(int(x))
		r.age = 0.0
		if fresh:
			runs.sort_custom(func(a: Found, c: Found) -> bool: return a.address + str(a.port) < c.address + str(c.port))
		return fresh or was != [r.name, r.players, r.vacant]

	func find(ip: String, p: int) -> Found:
		for r in runs:
			if r.address == ip and r.port == p:
				return r
		return null

	## Заголовок списка: «Найдено 2 забега», «Найден 1 забег», «Ищем забеги…», «Никого нет».
	func head() -> String:
		var n := runs.size()
		if n == 0:
			return "Ищем забеги…" if not done() else "Никого нет"
		return ("Найден %d " if n % 10 == 1 and n % 100 != 11 else "Найдено %d ") % n + RunBeacon.plural(n)


## «забег», «забега», «забегов».
static func plural(n: int) -> String:
	var m := n % 100
	if m >= 11 and m <= 14:
		return "забегов"
	match n % 10:
		1:
			return "забег"
		2, 3, 4:
			return "забега"
	return "забегов"
