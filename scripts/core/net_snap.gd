class_name NetSnap
## Снимки для сетевого забега (без сокетов): хост считает `Main.step` и раз в SEND_DT шлёт клиентам кадр — корабль,
## реактор, корпус и заряд, свет, экипаж (`Crew.Member.snapshot`); клиент шлёт хосту свой ввод (`Crew.Pad.snapshot`).
## Кадр — словарь из чисел, строк и массивов: `var_to_bytes` без объектов, размер — `bytes`.

const SEND_DT := 0.05          ## хост шлёт кадр 20 раз в секунду
const MAX_BYTES := 1200        ## кадр с четырьмя членами экипажа влезает в один UDP-пакет (MTU 1280 с запасом)
const VERSION := 15            ## формат кадра и ввода; клиент другой версии не подключается (15 — канал голоса `NetLink.CH_VOICE`)
const NEWS_TIME := 1.0         ## сообщение события едет в кадрах столько секунд (20 кадров — потеря всех почти исключена)


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
## События — `events(...)` (пробоина, ил, сообщение), пустой словарь — без событий.
static func frame(seq: int, time: float, helm: Helm.Ship, r: Reactor, v: Vitals, light_on: bool, crew: Array,
		ev: Dictionary = {}) -> Dictionary:
	var members: Array = []
	for m: Crew.Member in crew:
		members.append(pack_member(m.snapshot()))
	var f := {"v": VERSION, "seq": seq, "t": time, "ship": ship(helm), "reactor": reactor(r), "vitals": vitals(v),
		"light": light_on, "crew": members}
	if not ev.is_empty():
		f["ev"] = ev
	return f


## События корабля в кадре: пробоина (места — номерами `Breach.all`), облака ила, свежее сообщение события
## `news` = [номер, текст] (пустой — нет). welding — варит ли кто-то из экипажа (у хоста `breach.welding`
## к отправке уже сброшен `end_step`). t — время хоста: помехи сонара едут возрастом, а не моментом.
static func events(b: Breach, s: Silt, t: float, welding: bool, news: Array = []) -> Dictionary:
	var bf := PackedFloat32Array([b.all.find(b.active), b.all.find(b.last), b.all.find(b.water_spot), b.count,
		b.weld, b.water, b.seam_heat, 1.0 if welding else 0.0])
	var sf := PackedFloat32Array([s.k, minf(t - s.jam_t, 99.0), s.clouds.find(s.inside)])
	for cl in s.clouds:
		sf.append_array([cl.c.x, cl.c.y, cl.c.z, cl.r, cl.life, cl.max_life])
	var ev := {"b": bf, "s": sf}
	if news.size() == 2:
		ev["n"] = news
	return ev


## Клиент ставит события кадра в свои пробоину и ил (t — своё время: помехи сонара — от него). Возвращает
## сообщение события [номер, текст] или пустой массив.
static func apply_events(ev: Dictionary, b: Breach, s: Silt, t: float) -> Array:
	var bf: Variant = ev.get("b")
	if bf is PackedFloat32Array and bf.size() == 8:
		b.active = _spot(b, bf[0])
		b.last = _spot(b, bf[1])
		b.water_spot = _spot(b, bf[2])
		b.count = int(bf[3])
		b.weld = clampf(bf[4], 0.0, 1.0)
		b.water = clampf(bf[5], 0.0, Breach.WATER_MAX)
		b.seam_heat = clampf(bf[6], 0.0, 1.0)
		b.welding = bf[7] > 0.5 and b.active != null
	var sf: Variant = ev.get("s")
	if sf is PackedFloat32Array and sf.size() >= 3 and (sf.size() - 3) % 6 == 0:
		s.clouds.clear()
		for i in range(3, sf.size(), 6):
			var cl := Silt.Cloud.new()
			cl.c = Vector3(sf[i], sf[i + 1], sf[i + 2])
			cl.r = sf[i + 3]
			cl.life = sf[i + 4]
			cl.max_life = sf[i + 5]
			s.clouds.append(cl)
		s.k = clampf(sf[0], 0.0, 1.0)
		s.jam_t = t - sf[1]
		var ins := int(sf[2])
		s.inside = s.clouds[ins] if ins >= 0 and ins < s.clouds.size() else null
	var n: Variant = ev.get("n")
	if n is Array and n.size() == 2:
		return [int(n[0]), str(n[1])]
	return []


## Следы разрядов на дне (`Seabed.Scorch`) для гостя: [разрядов за забег, затем по следу x, z, поворот, размер,
## сила, ячейка, возраст]. Возраст, а не момент: часы гостя свои. Кладётся в события: `events(...)["z"]`.
static func scorch(sc: Seabed.Scorch, t: float) -> PackedFloat32Array:
	var f := PackedFloat32Array([sc.count])
	for s: Dictionary in sc.all:
		f.append_array([s.at.x, s.at.y, s.rot, s.size, s.k, s.index, t - float(s.t)])
	return f


## Гость ставит следы хоста (t — своё время). Меняет только при новом разряде или новом забеге (счёт другой) —
## между ними след стареет своими часами. Возвращает, поменялись ли следы (нужно обновить материал дна).
static func apply_scorch(v: Variant, sc: Seabed.Scorch, t: float) -> bool:
	if not v is PackedFloat32Array:
		return false
	var f: PackedFloat32Array = v
	if f.size() < 1 or (f.size() - 1) % 7 != 0:
		return false
	var n := int(f[0])
	var marks := (f.size() - 1) / 7
	if n == sc.count and marks == sc.all.size():
		return false
	sc.all.clear()
	for i in range(1, f.size(), 7):
		sc.all.append({"at": Vector2(f[i], f[i + 1]), "rot": f[i + 2], "size": f[i + 3], "k": f[i + 4],
			"index": int(f[i + 5]), "t": t - f[i + 6]})
	while sc.all.size() > Seabed.Scorch.MAX:
		sc.all.pop_front()
	sc.count = n
	return true


## Сонар хоста для гостей (кладётся в события: `events(...)["so"]`): [числа — импульсов за игру `Sonar.count`, возраст
## импульса, возраст отметок, дальность, завяз ли; байты — отметки по 9 байт: x, y, z в дециметрах (int16) и цвет RGB].
## Отметки едут только NEWS_TIME после импульса (20 кадров — потеря всех почти исключена; гость берёт их один раз, по
## новому счёту), дальше — пять чисел. Возраст, а не момент: часы гостя свои.
static func sonar(so: Sonar, t: float) -> Array:
	var b := PackedByteArray()
	if t - so.ping_time < NEWS_TIME and so.blip_alpha(t) > 0.0:
		b.resize(so.blips.size() * 9)
		for i in so.blips.size():
			var p: Vector3 = so.blips[i]["pos"]
			var c: Color = so.blips[i]["color"]
			b.encode_s16(i * 9, clampi(roundi(p.x * 10.0), -32768, 32767))
			b.encode_s16(i * 9 + 2, clampi(roundi(p.y * 10.0), -32768, 32767))
			b.encode_s16(i * 9 + 4, clampi(roundi(p.z * 10.0), -32768, 32767))
			b[i * 9 + 6] = c.r8
			b[i * 9 + 7] = c.g8
			b[i * 9 + 8] = c.b8
	return [PackedFloat32Array([so.count, minf(t - so.ping_time, 99.0), minf(t - so.blip_time, 99.0), so.range_m,
		1.0 if so.jammed else 0.0]), b]


## Гость ставит сонар хоста (t — своё время). Меняет только при новом импульсе хоста (другой счёт — и при входе в
## забег): между импульсами волна и отметки гаснут своими часами. true — пришёл новый импульс.
static func apply_sonar(v: Variant, so: Sonar, t: float) -> bool:
	if not (v is Array and v.size() == 2 and v[0] is PackedFloat32Array and v[1] is PackedByteArray):
		return false
	var f: PackedFloat32Array = v[0]
	var b: PackedByteArray = v[1]
	if f.size() != 5 or b.size() % 9 != 0 or b.size() / 9 > Sonar.MAX_BLIPS:
		return false
	if int(f[0]) == so.count:
		return false
	so.count = int(f[0])
	so.ping_time = t - f[1]
	so.blip_time = t - f[2]
	so.range_m = f[3]
	so.jammed = f[4] > 0.5
	so.blips.clear()
	for i in range(0, b.size(), 9):
		so.blips.append({"pos": Vector3(b.decode_s16(i), b.decode_s16(i + 2), b.decode_s16(i + 4)) * 0.1,
			"species": "", "color": Color8(b[i + 6], b[i + 7], b[i + 8])})
	return true


## Маршрут, голосование и итог для клиента (кладётся в события: `events(...)["r"]`). marks — метки голограммы
## {"deep": [роль…], "up": [роль…]} (`Main.vote_marks`), secs/frac — таймер кооп-голосования (−1 — не идёт), tally —
## строка счёта панели; ops — мнения ролей (`Run.opinions`, пока решают), rows — итог на голограмме (`Run.summary`),
## detail — итог на панели (`Run.detail`) — только после «наверх».
static func run_state(run: Run, marks: Dictionary, secs: int, frac: float, tally: String, ops: Array, rows: Array,
		detail: Array) -> Dictionary:
	var keys := Run.PLACES.keys()   # места — номерами по порядку Run.PLACES
	var vis := PackedByteArray()
	for k in run.visited:
		vis.append(keys.find(k))
	var seen := PackedByteArray()
	for k in run.seen:
		seen.append(keys.find(k))
	var r := {"ru": PackedInt32Array([run.route, 1 if run.done else 0, run.depth, run.routes, 1 if run.ended else 0,
		run.score, secs]), "rf": frac, "rv": vis, "rs": seen,
		"vm": [PackedByteArray(marks.get("deep", [])), PackedByteArray(marks.get("up", []))]}
	if tally != "":
		r["ta"] = tally
	if run.done and not run.ended:
		r["op"] = ops
	if run.ended:
		r["rr"] = rows
		r["rd"] = detail
	return r


## Клиент ставит маршрут хоста в свой Run и возвращает остальное для показа: {"marks", "secs", "frac", "tally",
## "ops", "rows", "detail"}. Испорченные данные — пустой словарь, Run не тронут.
static func apply_run(r: Variant, run: Run) -> Dictionary:
	if not r is Dictionary:
		return {}
	var ru: Variant = r.get("ru")
	var vm: Variant = r.get("vm")
	if not (ru is PackedInt32Array and ru.size() == 7 and r.get("rv") is PackedByteArray
			and r.get("rs") is PackedByteArray and vm is Array and vm.size() == 2
			and vm[0] is PackedByteArray and vm[1] is PackedByteArray):
		return {}
	run.route = ru[0] if ru[0] >= 0 and ru[0] < Run.ROUTES.size() else -1
	run.done = ru[1] == 1
	run.depth = maxi(0, ru[2])
	run.routes = maxi(0, ru[3])
	run.ended = ru[4] == 1
	run.score = ru[5]
	run.visited.assign(_keys(r["rv"]))
	run.seen.assign(_keys(r["rs"]))
	var marks := {"deep": _roles(vm[0]), "up": _roles(vm[1])}
	return {"marks": marks, "secs": ru[6], "frac": float(r.get("rf", -1.0)), "tally": str(r.get("ta", "")),
		"ops": _rows(r.get("op"), 3), "rows": _rows(r.get("rr"), 2), "detail": _rows(r.get("rd"), 2)}


static func _keys(a: PackedByteArray) -> Array:
	var keys := Run.PLACES.keys()
	var out := []
	for i in a:
		if i < keys.size():
			out.append(keys[i])
	return out


static func _roles(a: PackedByteArray) -> Array:
	var out := []
	for i in a:
		if i < Crew.ROLE_NAMES.size():
			out.append(int(i))
	return out


## Строки из пакета: массив массивов длины n, иначе пусто.
static func _rows(a: Variant, n: int) -> Array:
	if not a is Array:
		return []
	for row: Variant in a:
		if not (row is Array and row.size() == n):
			return []
	return a


static func _spot(b: Breach, i: float) -> Breach.Spot:
	var k := int(i)
	return b.all[k] if k >= 0 and k < b.all.size() else null


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
	var flags := (1 if s.get("seated", false) else 0) | (2 if s.get("power", false) else 0) | (4 if s.get("vote", false) else 0) \
		| (8 if s.get("act", false) else 0) | (16 if s.get("lost", false) else 0)
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
		"vote": b[2] & 4 != 0, "act": b[2] & 8 != 0, "lost": b[2] & 16 != 0, "post": POSTS[mini(b[3], POSTS.size() - 1)], "x": f[0], "z": f[1], "yaw": f[2],
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
