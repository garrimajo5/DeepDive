class_name NetSnap
## Снимки для сетевого забега (без сокетов): хост считает `Main.step` и раз в SEND_DT шлёт клиентам кадр — корабль,
## реактор, корпус и заряд, свет, экипаж (`Crew.Member.snapshot`); клиент шлёт хосту свой ввод (`Crew.Pad.snapshot`).
## Кадр — словарь из чисел, строк и массивов: `var_to_bytes` без объектов, размер — `bytes`.

const SEND_DT := 0.05          ## хост шлёт кадр 20 раз в секунду
const MAX_BYTES := 1200        ## кадр с четырьмя членами экипажа влезает в один UDP-пакет (MTU 1280 с запасом)
const VERSION := 1             ## формат кадра; клиент другой версии не подключается


## Корабль: место, курс, ход и ввод пилота (клиент рисует роторы и рули так же, как хост).
static func ship(helm: Helm.Ship) -> Dictionary:
	return {"p": [helm.pos.x, helm.pos.y, helm.pos.z], "yaw": helm.yaw, "v": helm.speed, "vy": helm.vy,
		"turn": helm.turn, "in": [helm.in_thrust, helm.in_turn, helm.in_vert]}


static func apply_ship(s: Dictionary, helm: Helm.Ship) -> void:
	var p: Array = s.get("p", [])
	if p.size() == 3:
		helm.pos = Vector3(p[0], p[1], p[2])
	helm.yaw = float(s.get("yaw", helm.yaw))
	helm.speed = float(s.get("v", helm.speed))
	helm.vy = float(s.get("vy", helm.vy))
	helm.turn = float(s.get("turn", helm.turn))
	var i: Array = s.get("in", [])
	if i.size() == 3:
		helm.in_thrust = i[0]
		helm.in_turn = i[1]
		helm.in_vert = i[2]


## Реактор: доли систем, перегрев, сброс.
static func reactor(r: Reactor) -> Dictionary:
	return {"share": Array(r.share), "hot": r.hot, "heat": r.heat, "scram": r.scram}


static func apply_reactor(s: Dictionary, r: Reactor) -> void:
	var sh: Array = s.get("share", [])
	if sh.size() == r.share.size():
		for i in sh.size():
			r.share[i] = int(sh[i])
	r.hot = bool(s.get("hot", r.hot))
	r.heat = float(s.get("heat", r.heat))
	r.scram = float(s.get("scram", r.scram))


## Корпус и заряд, вспышка удара.
static func vitals(v: Vitals) -> Dictionary:
	return {"hull": v.hull, "energy": v.energy, "flash": v.flash}


static func apply_vitals(s: Dictionary, v: Vitals) -> void:
	v.hull = float(s.get("hull", v.hull))
	v.energy = float(s.get("energy", v.energy))
	v.flash = float(s.get("flash", v.flash))


## Кадр хоста: номер, время игры, корабль, реактор, корпус, свет, экипаж (по порядку `crew`).
static func frame(seq: int, time: float, helm: Helm.Ship, r: Reactor, v: Vitals, light_on: bool, crew: Array) -> Dictionary:
	var members: Array = []
	for m: Crew.Member in crew:
		members.append(pack_member(m.snapshot()))
	return {"v": VERSION, "seq": seq, "t": time, "ship": ship(helm), "reactor": reactor(r), "vitals": vitals(v),
		"light": light_on, "crew": members}


## Клиент принимает кадр: корабль, реактор, корпус — как у хоста; экипаж — по порядку (недостающих добавляет,
## лишних убирает). Старый кадр (seq не больше last_seq) не применяется. Возвращает seq принятого кадра или last_seq.
static func apply_frame(f: Dictionary, last_seq: int, helm: Helm.Ship, r: Reactor, v: Vitals, crew: Array) -> int:
	if int(f.get("v", -1)) != VERSION:
		return last_seq
	var seq := int(f.get("seq", -1))
	if seq <= last_seq:
		return last_seq
	apply_ship(f.get("ship", {}), helm)
	apply_reactor(f.get("reactor", {}), r)
	apply_vitals(f.get("vitals", {}), v)
	var members: Array = f.get("crew", [])
	while crew.size() > members.size():
		crew.pop_back()
	for i in members.size():
		var ms := unpack_member(members[i])
		if ms.is_empty():
			continue
		if i >= crew.size():
			crew.append(Crew.Member.new(int(ms["role"])))
		(crew[i] as Crew.Member).apply(ms)
	return seq


const POSTS := ["", "helm", "energy"]


## Член экипажа в кадре — плотно: [байты (роль, внешность, флаги постов, пост), числа float32, имя]. Словарь
## `Member.snapshot` с ключами-строками вчетверо больше: четыре игрока не влезли бы в пакет.
static func pack_member(s: Dictionary) -> Array:
	var flags := (1 if s.get("seated", false) else 0) | (2 if s.get("power", false) else 0) | (4 if s.get("vote", false) else 0)
	var b := PackedByteArray([int(s.get("role", 0)), int(s.get("look", 0)), flags, maxi(POSTS.find(s.get("post", "")), 0)])
	var f := PackedFloat32Array([s.get("x", 0.0), s.get("z", 0.0), s.get("yaw", 0.0), s.get("turn", 0.0),
		s.get("phase", 0.0), s.get("swing", 0.0)])
	f.append_array(_nan_pad(s.get("weld", []), 6))
	f.append_array(_nan_pad(s.get("hand_l", []), 3))
	f.append_array(_nan_pad(s.get("hand_r", []), 3))
	return [b, f, str(s.get("name", ""))]


## Обратно в словарь для `Member.apply`; пустой — пакет испорчен.
static func unpack_member(a: Variant) -> Dictionary:
	if not (a is Array) or a.size() != 3 or not (a[0] is PackedByteArray) or not (a[1] is PackedFloat32Array):
		return {}
	var b: PackedByteArray = a[0]
	var f: PackedFloat32Array = a[1]
	if b.size() != 4 or f.size() != 18:
		return {}
	return {"role": clampi(b[0], 0, 3), "look": clampi(b[1], 0, 1), "seated": b[2] & 1 != 0, "power": b[2] & 2 != 0,
		"vote": b[2] & 4 != 0, "post": POSTS[mini(b[3], POSTS.size() - 1)], "x": f[0], "z": f[1], "yaw": f[2],
		"turn": f[3], "phase": f[4], "swing": f[5], "weld": _from_nan(f.slice(6, 12)),
		"hand_l": _from_nan(f.slice(12, 15)), "hand_r": _from_nan(f.slice(15, 18)), "name": str(a[2])}


static func _nan_pad(a: Array, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		out.append(float(a[i]) if a.size() == n else NAN)
	return out


static func _from_nan(f: PackedFloat32Array) -> Array:
	return [] if is_nan(f[0]) else Array(f)


## Размер кадра в байтах, как он уйдёт по сети.
static func bytes(f: Dictionary) -> int:
	return var_to_bytes(f).size()
