class_name NetLink
## Транспорт сетевого забега по локальной сети: встроенный ENet Godot (`ENetMultiplayerPeer`) без MultiplayerAPI
## и узлов сцены. Пакеты — словари `var_to_bytes` без объектов. Хост (`Host`) считает `Main.step`, принимает ввод
## клиентов (`Crew.Pad`) и раз в `NetSnap.SEND_DT` шлёт каждому кадр `NetSnap.frame` с его местом в экипаже `me`;
## клиент (`Client`) шага корабля не считает — шлёт свой ввод и применяет кадр (`NetSnap.apply_frame`).
##
## Сообщения: клиент → хост `join` (версия, имя, роль, внешность; надёжно) и `pad` (ввод, счётчик нажатий `n`;
## по порядку, без повторов — счётчик не теряет нажатие при потере пакета); хост → клиент `hello` / `no`
## (надёжно) и `f` — кадр (по порядку, без повторов: старый не придёт после нового).

const PORT := 24680             ## порт хоста по умолчанию (UDP)
const MAX_CLIENTS := 3          ## хост и три телефона — четыре роли
const CHANNELS := 3
const CH_CTRL := 0              ## join, hello, no — надёжно
const CH_FRAME := 1             ## кадры хоста
const CH_PAD := 2               ## ввод клиентов
const TIMEOUT := 5.0            ## клиент ждёт ответа хоста столько секунд

enum State { OFF, CONNECTING, JOINED, REFUSED, LOST }

const WHY := {"version": "Другая версия игры", "full": "Экипаж полон", "timeout": "Хост не отвечает"}


static func encode(msg: Dictionary) -> PackedByteArray:
	return var_to_bytes(msg)


## Пакет обратно в словарь; испорченный или не словарь — пустой (объекты `bytes_to_var` не создаёт).
static func decode(b: PackedByteArray) -> Dictionary:
	if b.size() < 4:
		return {}
	var v: Variant = bytes_to_var(b)
	return v if v is Dictionary else {}


static func _put(peer: ENetMultiplayerPeer, to: int, channel: int, reliable: bool, msg: Dictionary) -> void:
	peer.set_target_peer(to)
	peer.transfer_channel = channel
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	peer.put_packet(encode(msg))


## Телефон на борту у хоста: его ввод и место в экипаже.
class Guest:
	extends RefCounted
	var id := 0            ## peer id ENet
	var name := ""
	var role := 0
	var look := 0
	var pad := Crew.Pad.new()   ## ввод клиента: Main ставит его члену экипажа (`Member.pad`)
	var index := -1        ## место в `main.crew` — уходит клиенту в кадре (`me`); −1 — ещё не на палубе
	var acts := 0          ## последний принятый счётчик нажатий


class Host:
	extends RefCounted
	var peer: ENetMultiplayerPeer
	var guests := {}       ## peer id → Guest
	var seq := 0           ## номер последнего кадра
	var sent := 0          ## кадров отправлено (каждому гостю — свой пакет)
	var _acc := 0.0
	var _left: Array[int] = []

	## Открыть хост на порту; ошибка — порт занят или сеть недоступна.
	func start(port: int = NetLink.PORT) -> Error:
		stop()
		peer = ENetMultiplayerPeer.new()
		# на одно место больше: лишнему телефону ответим «Экипаж полон», а не молчанием
		var err := peer.create_server(port, NetLink.MAX_CLIENTS + 1, NetLink.CHANNELS)
		if err != OK:
			peer = null
			return err
		peer.peer_disconnected.connect(func(id: int) -> void: _left.append(id))
		return OK

	func stop() -> void:
		if peer:
			peer.close()
		peer = null
		guests.clear()
		_left.clear()

	func active() -> bool:
		return peer != null

	## Принять пакеты. События: {"k": "join", "guest": Guest} — телефон на борту (поставить члена экипажа),
	## {"k": "leave", "guest": Guest} — ушёл (убрать). Ввод гостей копится в `Guest.pad`.
	func poll() -> Array:
		var out: Array = []
		if peer == null:
			return out
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var from := peer.get_packet_peer()
			var msg := NetLink.decode(peer.get_packet())
			match str(msg.get("k", "")):
				"join":
					_join(from, msg, out)
				"pad":
					var g: Guest = guests.get(from)
					if g:
						var s: Dictionary = msg.get("pad", {})
						var n := int(msg.get("n", g.acts))
						s["act"] = n > g.acts   # нажатие — по счётчику: потерянный пакет его не съест, повтор не удвоит
						g.acts = maxi(g.acts, n)
						g.pad.apply(s)
		for id in _left:
			var g: Guest = guests.get(id)
			if g:
				guests.erase(id)
				out.append({"k": "leave", "guest": g})
		_left.clear()
		return out

	func _join(from: int, msg: Dictionary, out: Array) -> void:
		if guests.has(from):
			return
		var why := ""
		if int(msg.get("v", -1)) != NetSnap.VERSION:
			why = "version"
		elif guests.size() >= NetLink.MAX_CLIENTS:
			why = "full"
		if why != "":
			NetLink._put(peer, from, NetLink.CH_CTRL, true, {"k": "no", "why": why})
			peer.get_peer(from).peer_disconnect_later()   # «no» уйдёт раньше разрыва (disconnect_peer сбросил бы очередь)
			return
		var g := Guest.new()
		g.id = from
		g.name = str(msg.get("name", "")).left(24)
		g.role = clampi(int(msg.get("role", 0)), 0, 3)
		g.look = clampi(int(msg.get("look", 0)), 0, 1)
		guests[from] = g
		NetLink._put(peer, from, NetLink.CH_CTRL, true, {"k": "hello", "v": NetSnap.VERSION, "id": from})
		out.append({"k": "join", "guest": g})

	## Пора ли слать кадр: раз в `NetSnap.SEND_DT` (номер кадра растёт).
	func due(dt: float) -> bool:
		_acc += dt
		if _acc + 1e-6 < NetSnap.SEND_DT:
			return false
		_acc = fmod(_acc, NetSnap.SEND_DT) if _acc < NetSnap.SEND_DT * 3.0 else 0.0
		seq += 1
		return true

	## Кадр всем гостям на палубе; каждому — его место в экипаже `me`.
	func send_frame(f: Dictionary) -> void:
		if peer == null:
			return
		for g: Guest in guests.values():
			if g.index < 0:
				continue
			f["me"] = g.index
			NetLink._put(peer, g.id, NetLink.CH_FRAME, false, {"k": "f", "f": f})
			sent += 1
		f.erase("me")


class Client:
	extends RefCounted
	var peer: ENetMultiplayerPeer
	var state := NetLink.State.OFF
	var why := ""          ## причина отказа (NetLink.WHY)
	var id := 0            ## свой peer id у хоста
	var me := -1           ## своё место в экипаже хоста — из последнего кадра
	var version := NetSnap.VERSION   ## версия кадра; тест подменяет
	var acts := 0          ## счётчик нажатий кнопки действия
	var got := 0           ## кадров принято
	var _info := {}
	var _wait := 0.0
	var _seq := -1

	## Подключиться к хосту по адресу в локальной сети.
	func join(address: String, port: int = NetLink.PORT, name: String = "", role: int = 0, look: int = 0) -> Error:
		stop()
		peer = ENetMultiplayerPeer.new()
		var err := peer.create_client(address, port, NetLink.CHANNELS)
		if err != OK:
			peer = null
			return err
		_info = {"k": "join", "v": version, "name": name, "role": role, "look": look}
		state = NetLink.State.CONNECTING
		why = ""
		_wait = 0.0
		_seq = -1
		peer.peer_connected.connect(func(pid: int) -> void:
			if pid == 1:
				NetLink._put(peer, 1, NetLink.CH_CTRL, true, _info))
		return OK

	func stop() -> void:
		if peer:
			peer.close()
		peer = null
		if state == NetLink.State.CONNECTING or state == NetLink.State.JOINED:
			state = NetLink.State.OFF

	func joined() -> bool:
		return state == NetLink.State.JOINED

	## Принять пакеты; возвращает самый свежий кадр за этот вызов ({} — нового нет). dt — для ожидания ответа.
	func poll(dt: float = 0.0) -> Dictionary:
		var newest := {}
		if peer == null:
			return newest
		peer.poll()
		while peer and peer.get_available_packet_count() > 0:
			var msg := NetLink.decode(peer.get_packet())
			match str(msg.get("k", "")):
				"hello":
					state = NetLink.State.JOINED
					id = int(msg.get("id", 0))
				"no":
					why = str(msg.get("why", ""))
					state = NetLink.State.REFUSED
				"f":
					var f: Dictionary = msg.get("f", {})
					var s := int(f.get("seq", -1))
					if state == NetLink.State.JOINED and s > _seq:
						_seq = s
						newest = f
						got += 1
		if not newest.is_empty():
			me = int(newest.get("me", me))
		if state == NetLink.State.CONNECTING:
			_wait += dt
			if _wait > NetLink.TIMEOUT:
				why = "timeout"
				state = NetLink.State.REFUSED
		if peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			if state == NetLink.State.JOINED:
				state = NetLink.State.LOST
			elif state == NetLink.State.CONNECTING:
				why = "timeout"
				state = NetLink.State.REFUSED
		if state == NetLink.State.REFUSED or state == NetLink.State.LOST:
			peer.close()
			peer = null
		return newest

	## Свой ввод хосту (каждый кадр): крестовина как есть, свайп и нажатие съедаются — копятся до отправки.
	func send_pad(pad: Crew.Pad) -> void:
		if not joined() or peer == null:
			return
		if pad.action:
			acts += 1
		var s := pad.snapshot()
		s.erase("act")
		NetLink._put(peer, 1, NetLink.CH_PAD, false, {"k": "pad", "pad": s, "n": acts})
		pad.look = Vector2.ZERO
		pad.action = false

	## Строка для экрана подключения.
	func label() -> String:
		match state:
			NetLink.State.CONNECTING:
				return "Подключение…"
			NetLink.State.JOINED:
				return "На борту"
			NetLink.State.REFUSED:
				return NetLink.WHY.get(why, "Отказ хоста")
			NetLink.State.LOST:
				return "Связь с хостом потеряна"
		return ""
