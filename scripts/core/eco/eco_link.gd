class_name EcoLink
## Связь живого мира отмели (поток Б) с кораблём (поток А). Единственное место, где потоки договариваются:
## корабль каждый шаг отдаёт миру ShipState, мир возвращает события (словари ниже). Корабль решает, что событие
## с ним делает (урон, сообщение, тревога); мир не трогает узлы и состояние корабля напрямую.
## Меняется только по согласию потоков: новое поле или событие — в той же PR оба конца и тест в tests/test_eco_link.gd.


## Что мир знает о корабле в этот шаг. Оси мира Godot: нос −Z, +X — восток.
class ShipState:
	var pos := Vector3.ZERO      ## центр корабля в мире
	var yaw := 0.0               ## курс: нос в (−sin yaw, 0, −cos yaw)
	var speed := 0.0             ## м/с вдоль носа
	var light_on := false        ## прожектор светит (включён и есть энергия)
	var light_range := 0.0       ## дальность луча, м
	var sonar_ping := false      ## в этот шаг был импульс сонара
	var sonar_range := 0.0       ## дальность импульса, м
	var zap := false             ## в этот шаг был разряд по корпусу
	var zap_radius := 0.0        ## радиус разряда, м
	var hull_noise := 0.0        ## шум корабля 0…1 (ход, двигатели) — существа слышат
	var scan_range := 0.0        ## сканер биолога включён: дальность прицела, м (80 как в браузере); 0 — выключен
	var dive := 0                ## спуск забега: 0 — первый, +1 за каждое решение «глубже» (Run.depth)
	var claw := Vector3.ZERO     ## захват лебёдки трюма в мире (крепление троса; в покое — в трюме над шлюзом)
	var claw_state := CLAW_IDLE  ## CLAW_IDLE — покой, CLAW_REACH — тянется к образцу, CLAW_BACK — поднимает его
	var claw_target := Vector3.ZERO  ## где лежит (лежал) образец-цель захвата; при CLAW_IDLE — ноль
	var claw_sample := -1        ## номер образца-цели (Samples.all), −1 — цели нет

	## Чутьё хищников на этом спуске (js/run.js R.predK): 1 + 0,15 за спуск. Мир множит на него дальность,
	## с которой хищник замечает корабль (EcoPred.REACH).
	func pred_k() -> float:
		return 1.0 + dive * PRED_PER_DIVE

	## Нос корабля в мире.
	func nose() -> Vector3:
		return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Состояние захвата лебёдки (ShipState.claw_state, как Samples.State; js/manip.js M.state idle/reach/back).
const CLAW_IDLE := 0
const CLAW_REACH := 1
const CLAW_BACK := 2


## Насколько острее чутьё хищников с каждым спуском (+15 %, js/run.js R.predK).
const PRED_PER_DIVE := 0.15


## ---- События мира → корабль ----
## {"type": HIT, "by": "Серпохвост", "damage": 0…1, "at": Vector3}         — удар по корпусу: доля прочности
##     (0,12 — укус серпохвоста, как −12 % в браузере; 0,03 — щипок)
## {"type": DRAIN, "by": "Стеклоуст", "units": float}                      — тянет заряд корабля, ед./с, пока
##     событие приходит каждый шаг (батарея 0…100, восполняется 1,1 ед./с; стеклоуст — 3,2)
## {"type": DRAG, "by": "Присоска", "count": n, "k": float}                — существа на корпусе тормозят корабль:
##     k — добавка к сопротивлению воды (Helm.Ship.DRAG 0,45 + k; присоска — 0,025 каждая, js/ship.js), count — сколько
##     их на корпусе. Пока событие приходит каждый шаг; нет события — тормоза нет.
## {"type": NEAR, "species": "pred", "name": "серпохвост", "dist": м, "pos": Vector3, "r": м, "sonar": bool, "scan": bool}
##     — заметное существо рядом (E.scanTargets). species — ключ вида из Species, name — Species.called (настоящее
##     имя, если вид просканирован), dist — до центра корабля, r — размер цели для прицела сканера (м).
##     Сонар: в шаг с ShipState.sonar_ping мир шлёт NEAR для каждого заметного сонару существа ближе sonar_range
##     по горизонтали, у них "sonar": true — это отметки (цвет — Sonar.color_of). Кого сонар не видит (глазун,
##     присоска, скальник в маске), приходит только сканеру.
##     Сканер: пока ShipState.scan_range > 0, мир каждый шаг шлёт NEAR для каждого существа ближе scan_range,
##     кроме спрятавшихся, — у них "scan": true; события идут ближние первыми. Одно существо — одно событие,
##     даже если оно и для сонара, и для сканера; сонар берёт только "sonar": true.
## {"type": MESSAGE, "text": "…"}                                         — строка на приборы как есть
## {"type": OBSERVE, "species": "fish", "note": "flee", "text": "…"}      — наблюдение для журнала (handleEvents
##     в js/game.js): событие шины EcoBus с заметкой вида (Species.is_observation) не дальше EcoBus.HEARING от корабля.
##     text — строка на приборы ("" — без текста); корабль показывает её сам, как MESSAGE, а у нового наблюдения
##     без текста — «Новое наблюдение: …». Отдельный MESSAGE для того же события мир не шлёт.
## {"type": STEAL, "by": "Скальник", "sample": n}                         — образец n сорван с захвата (M.steal):
##     корабль принимает, только пока ShipState.claw_state == CLAW_BACK и claw_sample == n; захват пустеет, образец
##     не ложится в груз и считается унесённым (на дне его нет). Сообщение «Образец украден» пишет корабль.
## {"type": DROP, "sample": n, "at": Vector3}                              — унесённый образец n брошен (M.drop):
##     снова лежит на дне в точке at (x, z; высоту над дном ставит корабль), его можно поднять заново. Не унесённый
##     образец корабль не трогает. Текст на приборы («бросил образец») мир шлёт своим MESSAGE/OBSERVE.
const HIT := "hit"
const DRAIN := "drain"
const NEAR := "near"
const DRAG := "drag"
const MESSAGE := "message"
const OBSERVE := "observe"
const STEAL := "steal"
const DROP := "drop"


static func hit(by: String, damage: float, at: Vector3) -> Dictionary:
	return {"type": HIT, "by": by, "damage": clampf(damage, 0.0, 1.0), "at": at}


static func drain(by: String, units: float) -> Dictionary:
	return {"type": DRAIN, "by": by, "units": maxf(units, 0.0)}


static func drag(by: String, count: int, k: float) -> Dictionary:
	return {"type": DRAG, "by": by, "count": maxi(count, 0), "k": maxf(k, 0.0)}


static func near(species: String, name: String, pos: Vector3, ship_pos: Vector3, r: float = 1.0,
		sonar: bool = true, scan: bool = false) -> Dictionary:
	return {"type": NEAR, "species": species, "name": name, "pos": pos, "dist": pos.distance_to(ship_pos), "r": r,
		"sonar": sonar, "scan": scan}


static func message(text: String) -> Dictionary:
	return {"type": MESSAGE, "text": text}


static func observe(species: String, note: String, text: String = "") -> Dictionary:
	return {"type": OBSERVE, "species": species, "note": note, "text": text}


static func steal(by: String, sample: int) -> Dictionary:
	return {"type": STEAL, "by": by, "sample": sample}


static func drop(sample: int, at: Vector3) -> Dictionary:
	return {"type": DROP, "sample": sample, "at": at}


## Существа рядом для гостя сетевого забега (кадр хоста): мир у гостя идёт сам, а подвижные существа (`EcoWorld.agents`)
## ближе NET_R к кораблю хост шлёт как есть — гость ставит их на место (`apply_near`). Порядок `agents` одинаков
## у хоста и гостя: существа создаются при сбросе мира по зерну. На существо NET_STRIDE чисел: номер в `agents`,
## код (вид `Species.index_of` × 16 + состояние `EcoAgent.State` + 8, если неживое), место, скорость.
## Ближние первыми, не больше NET_MAX — пакет ~0,8 КБ.
const NET_R := 70.0
const NET_MAX := 24
const NET_STRIDE := 8


static func pack_near(agents: Array[EcoAgent], center: Vector3, radius: float = NET_R,
		limit: int = NET_MAX) -> PackedFloat32Array:
	var near: Array = []
	for i in agents.size():
		var d := agents[i].p.distance_squared_to(center)
		if d <= radius * radius:
			near.append([d, i])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var out := PackedFloat32Array()
	for k in mini(near.size(), limit):
		var i: int = near[k][1]
		var a := agents[i]
		var code := Species.index_of(a.species) * 16 + int(a.state) + (0 if a.alive else 8)
		out.append_array([i, code, a.p.x, a.p.y, a.p.z, a.v.x, a.v.y, a.v.z])
	return out


## Поставить существ гостя по кадру хоста (`pack_near`). Существо с другим видом на этом номере (миры разошлись)
## и номер за концом списка пропускаются. Возвращает, сколько существ поставлено.
static func apply_near(agents: Array[EcoAgent], data: PackedFloat32Array) -> int:
	var n := 0
	for k in range(0, data.size() - NET_STRIDE + 1, NET_STRIDE):
		var i := int(data[k])
		if i < 0:   # дальше — мох и стаи (`pack_world`)
			break
		var code := int(data[k + 1])
		if i < 0 or i >= agents.size():
			continue
		var a := agents[i]
		if Species.index_of(a.species) != code >> 4:
			continue
		a.state = (code & 7) as EcoAgent.State
		a.alive = code & 8 == 0
		a.p = Vector3(data[k + 2], data[k + 3], data[k + 4])
		a.v = Vector3(data[k + 5], data[k + 6], data[k + 7])
		n += 1
	return n


## Мох у гостя (`EcoMoss`): скребуны и монетки гостя едят по-своему, поэтому еда пятен рядом с кораблём едет с
## существами — после них метка NET_MOSS и по NET_MOSS_STRIDE чисел на пятно: сквозной номер пятна (`mosses`)
## и его еда 0…1. Яркость пятна у гостя — от этой еды (`EcoMoss.glow_of`).
const NET_MOSS := -1
const NET_MOSS_STRIDE := 2


## Все пятна мха мира по порядку: системы `EcoMoss` из списка и мох внутри мест (`bones.moss`, `well.moss`) — без
## повторов (у скребунов и монеток `moss` — ссылка на общий). Порядок у хоста и гостя один: системы те же.
static func mosses(systems: Array) -> Array[EcoMoss]:
	var out: Array[EcoMoss] = []
	for s in systems:
		var m: EcoMoss = null
		if s is EcoMoss:
			m = s
		elif s is Object and "moss" in s and s.moss is EcoMoss:
			m = s.moss
		if m != null and not out.has(m):
			out.append(m)
	return out


## Стаи светляков у гостя (`EcoFish`): рыбок больше, чем NET_MAX, и цель стаи гость выбирает своим случаем, поэтому
## стая рядом едет целиком — после мха метка NET_SHOAL и по NET_SHOAL_STRIDE чисел на стаю ближе radius: номер
## (`EcoFish.shoals`), центр, скорость, цель, секунды до новой цели, секунды тревоги. Гость сдвигает не пришедших
## поштучно рыбок стаи так, чтобы центр стаи стал хостовым, — стая не уплывает в сторону между кадрами.
const NET_SHOAL := -2
const NET_SHOAL_STRIDE := 12


## Система светляков из списка систем мира или null.
static func fish_of(systems: Array) -> EcoFish:
	for s in systems:
		if s is EcoFish:
			return s
	return null


## Пакет «существа рядом» вместе с мхом и стаями: `pack_near`, затем NET_MOSS и пятна мха ближе radius
## (по горизонтали), затем NET_SHOAL и стаи светляков, центр которых ближе radius, затем NET_COINS и стайки
## монетников ближе radius.
static func pack_world(agents: Array[EcoAgent], systems: Array, center: Vector3,
		radius: float = NET_R) -> PackedFloat32Array:
	var out := pack_near(agents, center, radius)
	var moss := PackedFloat32Array()
	var i := 0
	for m in mosses(systems):
		for p in m.patches:
			if Vector2(p.pos.x - center.x, p.pos.z - center.z).length() <= radius:
				moss.append_array([i, p.food])
			i += 1
	if not moss.is_empty():
		out.append(NET_MOSS)
		out.append_array(moss)
	var fish := fish_of(systems)
	var sh_out := PackedFloat32Array()
	if fish != null:
		for sh in fish.shoals:
			if sh.alive > 0 and sh.center.distance_to(center) <= radius:
				sh_out.append_array([sh.index, sh.center.x, sh.center.y, sh.center.z,
					sh.velocity.x, sh.velocity.y, sh.velocity.z, sh.goal.x, sh.goal.y, sh.goal.z,
					sh.goal_timer, sh.alarm])
	if not sh_out.is_empty():
		out.append(NET_SHOAL)
		out.append_array(sh_out)
	var coins := coins_of(systems)
	var cn_out := PackedFloat32Array()
	if coins != null:
		for sc in coins.schools:
			if sc.center.distance_to(center) <= radius:
				cn_out.append_array(pack_school(sc))
	if not cn_out.is_empty():
		out.append(NET_COINS)
		out.append_array(cn_out)
	return out


## Поставить гостю существ, мох и стаи по пакету `pack_world` (старый пакет без мха и стай — только существа).
## Возвращает, сколько пятен мха поставлено; стаи — `apply_shoals`.
static func apply_world(agents: Array[EcoAgent], systems: Array, data: PackedFloat32Array) -> int:
	apply_near(agents, data)
	var moss := _section(data, NET_MOSS)
	var n := 0
	if not moss.is_empty():
		var all: Array[EcoMoss.Patch] = []
		for m in mosses(systems):
			all.append_array(m.patches)
		for k in range(0, moss.size() - NET_MOSS_STRIDE + 1, NET_MOSS_STRIDE):
			var i := int(moss[k])
			if i < 0 or i >= all.size():
				continue
			all[i].food = clampf(moss[k + 1], 0.0, 1.0)
			n += 1
	apply_shoals(agents, systems, data)
	apply_coins(systems, data)
	return n


## Стаи из пакета `pack_world`: цель, таймер и тревога — как у хоста; рыбки стаи, не пришедшие поштучно в пакете
## существ, сдвигаются одним смещением, чтобы центр живых стал хостовым; скорость стаи — хостовая. Возвращает,
## сколько стай поставлено.
static func apply_shoals(agents: Array[EcoAgent], systems: Array, data: PackedFloat32Array) -> int:
	var part := _section(data, NET_SHOAL)
	var fish := fish_of(systems)
	if part.is_empty() or fish == null:
		return 0
	var sent := {}   # существа, поставленные поштучно
	for k in range(0, data.size() - NET_STRIDE + 1, NET_STRIDE):
		var i := int(data[k])
		if i < 0:
			break
		if i < agents.size():
			sent[agents[i]] = true
	var n := 0
	for k in range(0, part.size() - NET_SHOAL_STRIDE + 1, NET_SHOAL_STRIDE):
		var si := int(part[k])
		if si < 0 or si >= fish.shoals.size():
			continue
		var sh: EcoFish.Shoal = fish.shoals[si]
		var c := Vector3(part[k + 1], part[k + 2], part[k + 3])
		var sum := Vector3.ZERO
		var live := 0
		var free: Array[EcoAgent] = []
		for f: EcoFish.Fish in sh.members:
			if not f.agent.alive:
				continue
			live += 1
			sum += f.agent.p
			if not sent.has(f.agent):
				free.append(f.agent)
		if not free.is_empty():
			var shift := (c * live - sum) / free.size()
			for a in free:
				a.p += shift
		sh.center = c
		sh.velocity = Vector3(part[k + 4], part[k + 5], part[k + 6])
		sh.goal = Vector3(part[k + 7], part[k + 8], part[k + 9])
		sh.goal_timer = part[k + 10]
		sh.alarm = maxf(part[k + 11], 0.0)
		n += 1
	return n


## Монетники у гостя (`EcoCoins`): рыбки не в `agents`, цели и бегство гость считал бы своим случаем, а глазун
## у гостя ел бы других рыбок — стайка ближе radius едет целиком после стай: метка NET_COINS и по NET_COINS_STRIDE
## чисел на стайку — номер, секунды бегства, от чего бежит, бросок и ожидание глазуна, затем на каждого из PER
## монетников NET_COIN_STRIDE чисел: −1 у живого или секунды до появления у съеденного, место, скорость, цель,
## секунды до новой цели.
const NET_COINS := -3
const NET_COIN_STRIDE := 11
const NET_COINS_STRIDE := 7 + EcoCoins.PER * NET_COIN_STRIDE


## Монетники из списка систем мира или null.
static func coins_of(systems: Array) -> EcoCoins:
	for s in systems:
		if s is EcoCoins:
			return s
	return null


## Запись стайки монетников для пакета (NET_COINS_STRIDE чисел).
static func pack_school(sc: EcoCoins.School) -> PackedFloat32Array:
	var gz := sc.glazun
	var out := PackedFloat32Array([sc.index, sc.scatter, sc.from.x, sc.from.y, sc.from.z,
		gz.lunge if gz else 0.0, gz.cd if gz else 0.0])
	for k in EcoCoins.PER:
		if k >= sc.members.size():
			out.append_array([-1.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
			continue
		var c := sc.members[k]
		out.append_array([-1.0 if c.alive else maxf(c.respawn, 0.0), c.pos.x, c.pos.y, c.pos.z,
			c.vel.x, c.vel.y, c.vel.z, c.goal.x, c.goal.y, c.goal.z, c.goal_t])
	return out


## Стайки монетников из пакета `pack_world`: бегство, глазун и каждый монетник — как у хоста. Возвращает, сколько
## стаек поставлено.
static func apply_coins(systems: Array, data: PackedFloat32Array) -> int:
	var part := _section(data, NET_COINS)
	var coins := coins_of(systems)
	if part.is_empty() or coins == null:
		return 0
	var n := 0
	for k in range(0, part.size() - NET_COINS_STRIDE + 1, NET_COINS_STRIDE):
		var si := int(part[k])
		if si < 0 or si >= coins.schools.size():
			continue
		var sc: EcoCoins.School = coins.schools[si]
		sc.scatter = part[k + 1]
		sc.from = Vector3(part[k + 2], part[k + 3], part[k + 4])
		if sc.glazun:
			sc.glazun.lunge = part[k + 5]
			sc.glazun.cd = part[k + 6]
		for j in mini(EcoCoins.PER, sc.members.size()):
			var b := k + 7 + j * NET_COIN_STRIDE
			var c := sc.members[j]
			c.alive = part[b] < 0.0
			c.respawn = 0.0 if c.alive else part[b]
			c.pos = Vector3(part[b + 1], part[b + 2], part[b + 3])
			c.vel = Vector3(part[b + 4], part[b + 5], part[b + 6])
			c.goal = Vector3(part[b + 7], part[b + 8], part[b + 9])
			c.goal_t = part[b + 10]
		n += 1
	return n


## Часть пакета `pack_world` после метки marker (без неё) до следующей метки: метки стоят на месте номера записи,
## номера записей не меньше нуля. Нет такой части — пусто.
static func _section(data: PackedFloat32Array, marker: int) -> PackedFloat32Array:
	var k := 0
	while k + NET_STRIDE <= data.size() and int(data[k]) >= 0:
		k += NET_STRIDE
	while k < data.size():
		var m := int(data[k])
		var step := _stride(m)
		if step <= 0:
			break
		var start := k + 1
		k = start
		while k + step <= data.size() and int(data[k]) >= 0:
			k += step
		if m == marker:
			return data.slice(start, k)
	return PackedFloat32Array()


## Чисел на запись в части пакета после метки marker; 0 — метка незнакомая.
static func _stride(marker: int) -> int:
	match marker:
		NET_MOSS:
			return NET_MOSS_STRIDE
		NET_SHOAL:
			return NET_SHOAL_STRIDE
		NET_COINS:
			return NET_COINS_STRIDE
	return 0
