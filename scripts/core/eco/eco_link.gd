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
	var petal_open := false      ## створка гнезда 07 уже открыта (`LayerLore.PETAL07`, кампания): купольник не выходит

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
##     Сканер: пока ShipState.scan_range > 0, мир каждый шаг шлёт NEAR с "scan": true для ближнего существа каждого
##     вида ближе scan_range, кроме спрятавшихся (дальние того же вида сканеру не нужны, #738); события идут ближние
##     первыми. Одно существо — одно событие, даже если оно и для сонара, и для сканера; сонар берёт только
##     "sonar": true.
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
## {"type": VOICE, "role": 2, "text": "Сбросьте ход, перегрев", "fake": true, "ask": "ping", "silent": false}
##     — голос во внутренней связи ART-040: корабль показывает его на плашке связи (`Comms`, `Main.on_eco_event`).
##     role — заявленная роль (Crew.Role: 0 пилот, 1 сонарщик, 2 инженер, 3 биолог), text — команда одной-двумя
##     короткими строками. fake — подделка (эхоловец): на плашке «Код: …» вместо кодового слова забега, на «Спросить
##     код» отвечает чужим словом («Код не совпал» → «Это был не наш»), а с "silent": true — молчит («Нет ответа»,
##     не разоблачение). ask — о чём просит голос: "ping" — импульс сонара, "light" — свет, "" — ни о чём. Корабль
##     просьбу не исполняет сам; за исполненную просьбу подделки наказывает мир (по ShipState.sonar_ping / light_on).
## {"type": FIELD, "period": 2.4, "text": "…"}                            — импульс сонара с площадки 08 поймал ритм
##     пограничного поля (`EcoField.rhythm`, #833): period — с между ударами, text — строка на приборы. Корабль
##     ставит знание «поле 08 замечено» (`LayerLore.FIELD08`) и показывает строку. Приходит только в шаг импульса
##     у 08 — в других местах отмели не приходит.
## {"type": SHELL, "text": "…"}                                          — Раковина древних 03 осмотрена (#835): сканер
##     биолога видел контактные гнёзда и импульс сонара — рельеф спирали, в любом порядке (`EcoShell`). Корабль ставит
##     знание «осмотр 03» (`LayerLore.SHELL03`) и показывает строку. Один раз за забег.
## {"type": PETAL, "nest": 0, "text": "…"}                              — купольник у террасы врат 07 поднял
##     створку контактного гнезда nest (`GateDiag.NESTS`, #837). Корабль ставит знание «створка 07 открыта»
##     (`LayerLore.PETAL07`, в сохранении) и показывает строку; дальше шлёт ShipState.petal_open — купольник больше
##     не выходит. Один раз. Диагностика от створки не зависит.
const HIT := "hit"
const DRAIN := "drain"
const NEAR := "near"
const DRAG := "drag"
const MESSAGE := "message"
const OBSERVE := "observe"
const STEAL := "steal"
const DROP := "drop"
const VOICE := "voice"
const FIELD := "field"
const SHELL := "shell"
const PETAL := "petal"


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


static func voice(role: int, text: String, fake := false, ask := "", silent := false) -> Dictionary:
	return {"type": VOICE, "role": clampi(role, 0, 3), "text": text, "fake": fake, "ask": ask, "silent": silent}


static func shell(text: String) -> Dictionary:
	return {"type": SHELL, "text": text}


static func petal(nest: int, text: String) -> Dictionary:
	return {"type": PETAL, "nest": nest, "text": text}


static func field(period: float, text: String) -> Dictionary:
	return {"type": FIELD, "period": maxf(period, 0.0), "text": text}


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
## монетников ближе radius, затем NET_KELP и рощи ленточника с шипоежами ближе radius (по горизонтали), затем
## NET_RADUZH и стаи радужников ближе radius, NET_PLANKTON и облака планктона ближе radius, которые ещё светятся,
## и NET_TIME — время мира хоста (time ≥ 0; по нему у гостя дрейфуют стаи, облака и клетки в шейдере).
static func pack_world(agents: Array[EcoAgent], systems: Array, center: Vector3,
		radius: float = NET_R, time: float = -1.0) -> PackedFloat32Array:
	var out := pack_near(agents, center, radius)
	# части пишутся прямо в out: метка, затем записи; без записей метка снимается (`_close`)
	var mark := _open(out, NET_MOSS)
	var i := 0
	for m in mosses(systems):
		for p in m.patches:
			if Vector2(p.pos.x - center.x, p.pos.z - center.z).length() <= radius:
				out.append(i)
				out.append(p.food)
			i += 1
	_close(out, mark)
	var fish := fish_of(systems)
	if fish != null:
		mark = _open(out, NET_SHOAL)
		for sh in fish.shoals:
			if sh.alive > 0 and sh.center.distance_to(center) <= radius:
				out.append_array([sh.index, sh.center.x, sh.center.y, sh.center.z,
					sh.velocity.x, sh.velocity.y, sh.velocity.z, sh.goal.x, sh.goal.y, sh.goal.z,
					sh.goal_timer, sh.alarm])
		_close(out, mark)
	var coins := coins_of(systems)
	if coins != null:
		mark = _open(out, NET_COINS)
		for sc in coins.schools:
			if sc.center.distance_to(center) <= radius:
				_put_school(out, sc)
		_close(out, mark)
	var kelp := kelp_of(systems)
	if kelp != null:
		mark = _open(out, NET_KELP)
		for gr in kelp.groves:
			if Vector2(gr.center.x - center.x, gr.center.z - center.z).length() <= radius:
				_put_grove(out, kelp, gr)
		_close(out, mark)
	var rd := raduzh_of(systems)
	if rd != null:
		mark = _open(out, NET_RADUZH)
		for sw in rd.swarms:
			if sw.c.distance_to(center) <= radius:
				out.append_array([sw.index, sw.glow, 1.0 if sw.lit else 0.0])
		_close(out, mark)
	var pl := plankton_of(systems)
	if pl != null and time >= 0.0:
		mark = _open(out, NET_PLANKTON)
		for cl in pl.clouds:
			if cl.c.distance_to(center) <= radius + EcoPlankton.R and time - cl.cut_at < PLANKTON_FADE:
				_put_cloud(out, cl, time)
		_close(out, mark)
	if time >= 0.0:
		out.append(NET_TIME)
		out.append(time)
	return out


## Начать часть пакета: метка marker в конец out. Возвращает, где она стоит (для `_close`).
static func _open(out: PackedFloat32Array, marker: int) -> int:
	out.append(marker)
	return out.size() - 1


## Закончить часть пакета, начатую `_open` на месте mark: ни одной записи — метка снимается.
static func _close(out: PackedFloat32Array, mark: int) -> void:
	if out.size() == mark + 1:
		out.resize(mark)


## Поставить гостю существ, мох и стаи по пакету `pack_world` (старый пакет без мха и стай — только существа).
## Возвращает, сколько пятен мха поставлено; стаи — `apply_shoals`. world — мир гостя: его время подтягивается
## к хостовому (`synced_time`) до вспышек, иначе вспышки ставятся по времени из пакета. Пакет размечается один раз
## (`parts`), части читаются прямо из data — без копий.
static func apply_world(agents: Array[EcoAgent], systems: Array, data: PackedFloat32Array,
		world: EcoWorld = null) -> int:
	var at := parts(data)
	var host_t := net_time(data, at)
	var now := host_t
	if world != null:
		world.time = synced_time(world.time, host_t)
		now = world.time
	apply_near(agents, data)
	var n := _apply_moss(systems, data, at)
	apply_shoals(agents, systems, data, at)
	var fish := fish_of(systems)
	if fish:  # рыбок поставили мимо шага стаи — рамки для поиска добычи (EcoFish.nearest_fish) заново
		fish.bounds()
	apply_coins(systems, data, at)
	apply_kelp(systems, data, at)
	apply_raduzh(systems, data, now, at)
	if now >= 0.0:
		apply_plankton(systems, data, now, at)
	return n


## Пятна мха из пакета: номера сквозные по `mosses` и идут по возрастанию — список мха проходится один раз.
static func _apply_moss(systems: Array, data: PackedFloat32Array, at: PackedInt32Array) -> int:
	var from := at[_slot(NET_MOSS)]
	if from < 0:
		return 0
	var to := at[_slot(NET_MOSS) + 1]
	var all := mosses(systems)
	var mi := 0
	var base := 0
	var n := 0
	for k in range(from, to - NET_MOSS_STRIDE + 1, NET_MOSS_STRIDE):
		var i := int(data[k])
		if i < base:   # номера не по порядку — с начала списка
			mi = 0
			base = 0
		while mi < all.size() and i >= base + all[mi].patches.size():
			base += all[mi].patches.size()
			mi += 1
		if i < 0 or mi >= all.size():
			continue
		all[mi].patches[i - base].food = clampf(data[k + 1], 0.0, 1.0)
		n += 1
	return n


## Стаи из пакета `pack_world`: цель, таймер и тревога — как у хоста; рыбки стаи, не пришедшие поштучно в пакете
## существ, сдвигаются одним смещением, чтобы центр живых стал хостовым; скорость стаи — хостовая. Возвращает,
## сколько стай поставлено.
static func apply_shoals(agents: Array[EcoAgent], systems: Array, data: PackedFloat32Array,
		at := PackedInt32Array()) -> int:
	if at.is_empty():
		at = parts(data)
	var from := at[_slot(NET_SHOAL)]
	var to := at[_slot(NET_SHOAL) + 1]
	var fish := fish_of(systems)
	if from < 0 or fish == null:
		return 0
	var sent := {}   # существа, поставленные поштучно
	for k in range(0, data.size() - NET_STRIDE + 1, NET_STRIDE):
		var i := int(data[k])
		if i < 0:
			break
		if i < agents.size():
			sent[agents[i]] = true
	var n := 0
	for k in range(from, to - NET_SHOAL_STRIDE + 1, NET_SHOAL_STRIDE):
		var si := int(data[k])
		if si < 0 or si >= fish.shoals.size():
			continue
		var sh: EcoFish.Shoal = fish.shoals[si]
		var c := Vector3(data[k + 1], data[k + 2], data[k + 3])
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
		sh.velocity = Vector3(data[k + 4], data[k + 5], data[k + 6])
		sh.goal = Vector3(data[k + 7], data[k + 8], data[k + 9])
		sh.goal_timer = data[k + 10]
		sh.alarm = maxf(data[k + 11], 0.0)
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
	var out := PackedFloat32Array()
	_put_school(out, sc)
	return out


## Дописать запись стайки в конец out.
static func _put_school(out: PackedFloat32Array, sc: EcoCoins.School) -> void:
	var gz := sc.glazun
	out.append_array([sc.index, sc.scatter, sc.from.x, sc.from.y, sc.from.z,
		gz.lunge if gz else 0.0, gz.cd if gz else 0.0])
	for k in EcoCoins.PER:
		if k >= sc.members.size():
			out.append_array([-1.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
			continue
		var c := sc.members[k]
		out.append_array([-1.0 if c.alive else maxf(c.respawn, 0.0), c.pos.x, c.pos.y, c.pos.z,
			c.vel.x, c.vel.y, c.vel.z, c.goal.x, c.goal.y, c.goal.z, c.goal_t])


## Стайки монетников из пакета `pack_world`: бегство, глазун и каждый монетник — как у хоста. Возвращает, сколько
## стаек поставлено.
static func apply_coins(systems: Array, data: PackedFloat32Array, at := PackedInt32Array()) -> int:
	if at.is_empty():
		at = parts(data)
	var from := at[_slot(NET_COINS)]
	var to := at[_slot(NET_COINS) + 1]
	var coins := coins_of(systems)
	if from < 0 or coins == null:
		return 0
	var n := 0
	for k in range(from, to - NET_COINS_STRIDE + 1, NET_COINS_STRIDE):
		var si := int(data[k])
		if si < 0 or si >= coins.schools.size():
			continue
		var sc: EcoCoins.School = coins.schools[si]
		sc.scatter = data[k + 1]
		sc.from = Vector3(data[k + 2], data[k + 3], data[k + 4])
		if sc.glazun:
			sc.glazun.lunge = data[k + 5]
			sc.glazun.cd = data[k + 6]
		for j in mini(EcoCoins.PER, sc.members.size()):
			var b := k + 7 + j * NET_COIN_STRIDE
			var c := sc.members[j]
			c.alive = data[b] < 0.0
			c.respawn = 0.0 if c.alive else data[b]
			c.pos = Vector3(data[b + 1], data[b + 2], data[b + 3])
			c.vel = Vector3(data[b + 4], data[b + 5], data[b + 6])
			c.goal = Vector3(data[b + 7], data[b + 8], data[b + 9])
			c.goal_t = data[b + 10]
		n += 1
	return n


## Ленточник и шипоежи у гостя (`EcoKelp`): ежи не в `agents`, цель и блуждание гость выбирал бы своим случаем,
## и ленты объедал бы другие — роща ближе radius (по горизонтали) едет целиком после монетников: метка NET_KELP и
## по NET_KELP_STRIDE чисел на рощу — номер, густота каждой из KELP_N лент, затем на каждого из URCH_N ежей рощи
## NET_URCHIN_STRIDE чисел: −1 у живого или секунды до появления у съеденного, место, лента-цель (−1 — бродит),
## точка блуждания (x, z) и секунды до новой, пауза наблюдения «graze». Кто ест ленту — по целям ежей.
const NET_KELP := -4
const NET_URCHIN_STRIDE := 9
const NET_KELP_STRIDE := 1 + EcoKelp.KELP_N + EcoKelp.URCH_N * NET_URCHIN_STRIDE


## Ленточник из списка систем мира или null.
static func kelp_of(systems: Array) -> EcoKelp:
	for s in systems:
		if s is EcoKelp:
			return s
	return null


## Ежи рощи gi по порядку.
static func _grove_urchins(kelp: EcoKelp, gi: int) -> Array[EcoKelp.Urchin]:
	var out: Array[EcoKelp.Urchin] = []
	for u in kelp.urchins:
		if u.grove == gi:
			out.append(u)
	return out


## Запись рощи для пакета (NET_KELP_STRIDE чисел).
static func pack_grove(kelp: EcoKelp, gr: EcoKelp.Grove) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	_put_grove(out, kelp, gr)
	return out


## Дописать запись рощи в конец out.
static func _put_grove(out: PackedFloat32Array, kelp: EcoKelp, gr: EcoKelp.Grove) -> void:
	out.append(gr.index)
	for k in EcoKelp.KELP_N:
		out.append(gr.stalks[k].f if k < gr.stalks.size() else 1.0)
	var us := _grove_urchins(kelp, gr.index)
	for k in EcoKelp.URCH_N:
		if k >= us.size():
			out.append_array([-1.0, 0, 0, 0, -1, 0, 0, 0, 0])
			continue
		var u := us[k]
		out.append_array([-1.0 if u.alive else maxf(u.respawn, 0.0), u.pos.x, u.pos.y, u.pos.z, u.goal,
			u.wander.x, u.wander.z, u.wander_t, u.graze_cd])


## Рощи из пакета `pack_world`: густота лент и каждый ёж — как у хоста, кто ест ленту — по целям ежей. Возвращает,
## сколько рощ поставлено.
static func apply_kelp(systems: Array, data: PackedFloat32Array, at := PackedInt32Array()) -> int:
	if at.is_empty():
		at = parts(data)
	var from := at[_slot(NET_KELP)]
	var to := at[_slot(NET_KELP) + 1]
	var kelp := kelp_of(systems)
	if from < 0 or kelp == null:
		return 0
	var n := 0
	for k in range(from, to - NET_KELP_STRIDE + 1, NET_KELP_STRIDE):
		var gi := int(data[k])
		if gi < 0 or gi >= kelp.groves.size():
			continue
		var gr: EcoKelp.Grove = kelp.groves[gi]
		for j in mini(EcoKelp.KELP_N, gr.stalks.size()):
			gr.stalks[j].f = clampf(data[k + 1 + j], EcoKelp.F_MIN, 1.0)
			gr.stalks[j].eater = -1
		var us := _grove_urchins(kelp, gi)
		for j in mini(EcoKelp.URCH_N, us.size()):
			var b := k + 1 + EcoKelp.KELP_N + j * NET_URCHIN_STRIDE
			var u := us[j]
			u.alive = data[b] < 0.0
			u.respawn = 0.0 if u.alive else data[b]
			u.pos = Vector3(data[b + 1], data[b + 2], data[b + 3])
			var goal := int(data[b + 4])
			u.goal = goal if u.alive and goal >= 0 and goal < gr.stalks.size() else -1
			if u.goal >= 0:
				gr.stalks[u.goal].eater = u.index
			u.wander = Vector3(data[b + 5], 0.0, data[b + 6])
			u.wander_t = data[b + 7]
			u.graze_cd = data[b + 8]
		n += 1
	return n


## Вспышки у гостя. Радужники (`EcoRaduzh`) вспыхивают в луче, а луч и время у гостя чуть свои — стая ближе
## radius едет после рощ: метка NET_RADUZH и по NET_RADUZH_STRIDE чисел — номер, вспышка 0…1, задевает ли луч (1/0).
## Планктон (`EcoPlankton`) зажигают корабль, серпохвосты и ледокрылы, а 360 клеток облака гость зажёг бы своим
## расчётом — облако ближе radius (+R), которое режут или которое ещё светится (PLANKTON_FADE после последнего
## разреза), едет целиком: метка NET_PLANKTON и по NET_PLANKTON_STRIDE чисел — номер, секунды с последнего разреза,
## след корабля, клеток серпохвоста, затем по три клетки в числе: байт клетки — возраст вспышки шагами NET_AGE_Q
## (0…62; 63 — не светится) + 64 × кто зажёг (`EcoPlankton.By`). Время мира хоста — метка NET_TIME и одно число:
## дрейф стай и облаков считается по времени, и без него у гостя они плыли бы в другом месте.
const NET_RADUZH := -5
const NET_RADUZH_STRIDE := 3
const NET_PLANKTON := -6
const NET_PLANKTON_STRIDE := 4 + EcoPlankton.PER_CLOUD / 3
const NET_TIME := -7
const NET_AGE_Q := 0.05
const NET_AGE_NONE := 63
## Облако светится столько секунд после последней вспышки клетки (яркость гаснет до нуля).
const PLANKTON_FADE := 1.0 / EcoPlankton.GLOW_DOWN
## Время гостя тянется к хостовому: разница больше TIME_SNAP — сразу, меньше — на долю TIME_EASE за пакет
## (без рывков назад на каждом кадре).
const TIME_SNAP := 1.0
const TIME_EASE := 0.25


## Радужники из списка систем мира или null.
static func raduzh_of(systems: Array) -> EcoRaduzh:
	for s in systems:
		if s is EcoRaduzh:
			return s
	return null


## Планктон из списка систем мира или null.
static func plankton_of(systems: Array) -> EcoPlankton:
	for s in systems:
		if s is EcoPlankton:
			return s
	return null


## Время мира хоста из пакета `pack_world`; нет — −1.
static func net_time(data: PackedFloat32Array, at := PackedInt32Array()) -> float:
	if at.is_empty():
		at = parts(data)
	var from := at[_slot(NET_TIME)]
	return data[from] if from >= 0 and from < at[_slot(NET_TIME) + 1] else -1.0


## Время гостя после пакета с временем хоста host (−1 — пакета без времени: своё).
static func synced_time(local: float, host: float) -> float:
	if host < 0.0:
		return local
	var d := host - local
	return host if absf(d) > TIME_SNAP else local + d * TIME_EASE


## Запись облака для пакета (NET_PLANKTON_STRIDE чисел) в момент мира t.
static func pack_cloud(cl: EcoPlankton.Cloud, t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	_put_cloud(out, cl, t)
	return out


## Дописать запись облака в конец out.
static func _put_cloud(out: PackedFloat32Array, cl: EcoPlankton.Cloud, t: float) -> void:
	out.append_array([cl.index, maxf(t - cl.cut_at, 0.0), cl.ship, cl.pred_lit])
	for k in range(0, EcoPlankton.PER_CLOUD, 3):
		var v := 0
		for j in 3:
			v += _cell_byte(cl, k + j, t) << (8 * j)
		out.append(v)


static func _cell_byte(cl: EcoPlankton.Cloud, k: int, t: float) -> int:
	var age := t - cl.lit_at[k]   # lit_at хранится в float32 — вспышка этого шага бывает чуть «в будущем»
	if age < -NET_AGE_Q or age >= PLANKTON_FADE:
		return NET_AGE_NONE
	return clampi(roundi(age / NET_AGE_Q), 0, NET_AGE_NONE - 1) + 64 * (cl.by[k] & 3)


## Стаи радужников из пакета `pack_world`: вспышка и луч как у хоста, центр — по времени гостя. Возвращает, сколько
## стай поставлено.
static func apply_raduzh(systems: Array, data: PackedFloat32Array, now: float = -1.0,
		at := PackedInt32Array()) -> int:
	if at.is_empty():
		at = parts(data)
	var from := at[_slot(NET_RADUZH)]
	var to := at[_slot(NET_RADUZH) + 1]
	var rd := raduzh_of(systems)
	if from < 0 or rd == null:
		return 0
	var n := 0
	for k in range(from, to - NET_RADUZH_STRIDE + 1, NET_RADUZH_STRIDE):
		var i := int(data[k])
		if i < 0 or i >= rd.swarms.size():
			continue
		var sw: EcoRaduzh.Swarm = rd.swarms[i]
		sw.glow = clampf(data[k + 1], 0.0, 1.0)
		sw.lit = data[k + 2] > 0.5
		if now >= 0.0:
			sw.c = EcoRaduzh.center(sw, now)
		n += 1
	rd.flare = 0.0
	rd.flare_swarm = null
	for sw in rd.swarms:
		if sw.glow > rd.flare:
			rd.flare = sw.glow
			rd.flare_swarm = sw
	return n


## Облака планктона из пакета `pack_world` в момент мира гостя now: вспышка каждой клетки и кто её зажёг, след
## корабля — как у хоста; вид переписывает буфер (`version`). Возвращает, сколько облаков поставлено.
static func apply_plankton(systems: Array, data: PackedFloat32Array, now: float,
		at := PackedInt32Array()) -> int:
	if at.is_empty():
		at = parts(data)
	var from := at[_slot(NET_PLANKTON)]
	var to := at[_slot(NET_PLANKTON) + 1]
	var pl := plankton_of(systems)
	if from < 0 or pl == null:
		return 0
	var n := 0
	for k in range(from, to - NET_PLANKTON_STRIDE + 1, NET_PLANKTON_STRIDE):
		var i := int(data[k])
		if i < 0 or i >= pl.clouds.size():
			continue
		var cl: EcoPlankton.Cloud = pl.clouds[i]
		cl.cut_at = now - data[k + 1]
		cl.ship = clampf(data[k + 2], 0.0, 1.0)
		cl.pred_lit = int(data[k + 3])
		cl.c = EcoPlankton.center(cl, now)
		for j in range(0, EcoPlankton.PER_CLOUD, 3):
			var v := int(data[k + 4 + j / 3])
			for b in 3:
				var byte := (v >> (8 * b)) & 0xFF
				var q := byte & 63
				if q >= NET_AGE_NONE:
					cl.lit_at[j + b] = -99.0
					cl.by[j + b] = EcoPlankton.By.NONE
				else:
					cl.lit_at[j + b] = now - q * NET_AGE_Q
					cl.by[j + b] = byte >> 6
		cl.version += 1
		n += 1
	pl.wake = 0.0
	for cl in pl.clouds:
		pl.wake = maxf(pl.wake, cl.ship)
	return n


## Сколько раз пакет размечен (`parts`) — для теста: `apply_world` размечает пакет один раз.
static var scans := 0


## Разметка пакета `pack_world` за один проход: на каждую метку два числа (`_slot`) — где начинается её часть
## (сразу за меткой) и где кончается; части нет — −1, −1. Метки стоят на месте номера записи, номера записей не
## меньше нуля. Незнакомая метка обрывает разбор: дальше — не наше.
static func parts(data: PackedFloat32Array) -> PackedInt32Array:
	scans += 1
	var at := PackedInt32Array()
	at.resize(_slot(NET_TIME) + 2)
	at.fill(-1)
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
		if at[_slot(m)] < 0:
			at[_slot(m)] = start
			at[_slot(m) + 1] = k
	return at


## Место метки marker (−1…−7) в разметке `parts`.
static func _slot(marker: int) -> int:
	return -2 * marker


## Чисел на запись в части пакета после метки marker; 0 — метка незнакомая.
static func _stride(marker: int) -> int:
	match marker:
		NET_MOSS:
			return NET_MOSS_STRIDE
		NET_SHOAL:
			return NET_SHOAL_STRIDE
		NET_COINS:
			return NET_COINS_STRIDE
		NET_KELP:
			return NET_KELP_STRIDE
		NET_RADUZH:
			return NET_RADUZH_STRIDE
		NET_PLANKTON:
			return NET_PLANKTON_STRIDE
		NET_TIME:
			return 1
	return 0
