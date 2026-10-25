class_name EcoHvaten
extends EcoSystem
## Хватень и пестрянки (hvaten, pestr в js/creatures.js: initAnemones, anemoneUpdate; бестиарий): анемон-засадчик
## высотой около метра у стай светляков 0…3, в 5 м от дома стаи. В темноте раскрывает 22 щупальца, в луче прожектора
## (EcoWorld.in_beam) быстро прячет их и раскрывает снова только в темноте. Три пестрянки живут среди щупалец:
## раз в 25–45 с выплывают к ближайшей спокойной стае (ближе 30 м, от трёх рыбок) и 14 с ведут её к хозяину.
## Раскрытые щупальца в темноте ловят светляка у рта (ближе 1,9 м), хватень переваривает 35 с (щупальца наполовину),
## через 3 с пестрянки доедают остатки. Наблюдения: «hide» хватня и «immune» пестрянки (вспышка луча, раз в 30 с),
## «lure», «catch», «leftovers» (с текстом — одна история у хватня за 90 с). Хватень и пестрянки заметны сонару и сканеру.

const ID := "hvaten"
const PESTR := "pestr"
## Хватней — у первых четырёх стай светляков (Math.min(4, E.shoals.length)).
const MAX_N := 4
## Щупалец на хватня и пестрянок у него (HV_TENT, HV_PESTR).
const TENT := 22
const PESTR_N := 3
## Хватень в 5 м от дома стаи под углом i · 2,1 + 0,7; макушка — на 0,85 м над дном, рот — ещё на 0,7 м выше.
const OFFSET := 5.0
const TOP_UP := 0.85
const MOUTH_UP := 0.7
## Щупальца ловят ближе 1,9 м ко рту × раскрытие (HV_REACH), с вероятностью 1,5 в секунду на рыбку.
const REACH := 1.9
const CATCH_RATE := 1.5
## Ловит, раскрывшись больше чем на 0,7; пестрянки выплывают к стае — больше чем на 0,85.
const CATCH_OPEN := 0.7
const LURE_OPEN := 0.85
## Прячет щупальца со скоростью 2,5 в секунду, раскрывает — 0,35; переваривая, держит раскрытыми наполовину.
const CLOSE_RATE := 2.5
const OPEN_RATE := 0.35
const DIGEST_OPEN := 0.5
## Переваривает 35 с; пестрянки доедают остатки через 3 с после поимки.
const DIGEST := 35.0
const LEFTOVERS := 3.0
## Пестрянки зовут стаю ближе 30 м и ведут её 14 с к точке на 1,1 м над макушкой; снова — через 25–45 с
## (первый раз — через 4–12 с).
const LURE_R := 30.0
const LURE_T := 14.0
const LURE_UP := 1.1
const LURE_CD_MIN := 25.0
const LURE_CD_MAX := 45.0
## Наблюдения «hide»/«immune» — не чаще раза в 30 с; после «leftovers» тексты молчат 90 с (одна история за раз).
const HIDE_CD := 30.0
const MSG_CD := 90.0
## «hide» — если луч застал щупальца раскрытыми больше чем наполовину.
const HIDE_OPEN := 0.5
## В начале забега хватни сыты (переваривают DIGEST с, щупальца наполовину): в браузере первый светляк попадался
## в первые же кадры у стаи на старте, и лента сообщений начиналась с хватня. Здесь первая поимка и подманивание —
## не раньше чем через 35 с.
const START_FED := DIGEST
## Ловить не пробует, если стая дальше этого от рта (вся стая — в 14 м от своего центра).
const SHOAL_NEAR := 20.0


## Щупальце: угол вокруг диска, наклон наружу, длина, фаза покачивания.
class Tentacle:
	extends RefCounted
	var a := 0.0
	var tilt := 0.0
	var length := 1.0
	var phase := 0.0


## Пестрянка: фаза хоровода, радиус у щупалец, где плывёт и где была шаг назад (курс для отрисовки).
class Pestr:
	extends RefCounted
	var phase := 0.0
	var r := 0.4
	var p := Vector3.ZERO
	var prev := Vector3.ZERO


## Хватень.
class Anemone:
	extends RefCounted
	var index := 0
	## Поворот тела вокруг вертикали.
	var yaw := 0.0
	## Основание на дне, макушка (диск щупалец), рот (там ловит).
	var base := Vector3.ZERO
	var top := Vector3.ZERO
	var mouth := Vector3.ZERO
	## Раскрытие щупалец 0…1; в луче в этот шаг.
	var open := DIGEST_OPEN
	var lit := false
	## Секунды: переваривает; ведут стаю; до следующего подманивания; до «leftovers»; паузы «hide» и текстов.
	var digest := 0.0
	var lure_t := 0.0
	var lure_cd := 0.0
	var left_t := 0.0
	var hide_cd := 0.0
	var msg_cd := 0.0
	## Стая, которую ведут пестрянки (null — никого не ведут).
	var lure: EcoFish.Shoal
	var tents: Array[Tentacle] = []
	var pestr: Array[Pestr] = []
	## Середина пестрянок (цель сканера).
	var pc := Vector3.ZERO


var anemones: Array[Anemone] = []
## Светляки (подключены раньше): у их стай сидят хватни, их ловят и подманивают.
var fish: EcoFish

var _rnd: EcoRandom
var _spots: Array[Vector3]


## prey_fish — светляки мира; spots — свои места хватней (для тестов), пусто — у стай 0…3.
func _init(prey_fish: EcoFish = null, spots: Array[Vector3] = []) -> void:
	fish = prey_fish
	_spots = spots.duplicate()


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 8513) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	anemones.clear()
	var places: Array[Vector3] = []
	var yaws: Array[float] = []
	if not _spots.is_empty():
		for i in _spots.size():
			places.append(_spots[i])
			yaws.append(i * 2.1 + 0.7)
	elif fish:
		for i in mini(MAX_N, fish.shoals.size()):
			var sh := fish.shoals[i]
			var a := i * 2.1 + 0.7
			places.append(sh.home + Vector3(cos(a) * OFFSET, 0.0, sin(a) * OFFSET))
			yaws.append(a)
	for i in places.size():
		var p := places[i]
		var hv := Anemone.new()
		hv.index = i
		hv.yaw = yaws[i]
		hv.base = Vector3(p.x, float(world.ground.call(p.x, p.z)) if world.ground.is_valid() else p.y, p.z)
		hv.top = hv.base + Vector3(0, TOP_UP, 0)
		hv.mouth = hv.top + Vector3(0, MOUTH_UP, 0)
		hv.lure_cd = _rnd.range_f(4, 12)
		hv.digest = START_FED
		hv.open = DIGEST_OPEN
		for k in TENT:
			var tn := Tentacle.new()
			tn.a = float(k) / TENT * TAU + _rnd.range_f(-0.1, 0.1)
			tn.tilt = _rnd.range_f(0.35, 1.0)
			tn.length = _rnd.range_f(0.9, 1.4)
			tn.phase = _rnd.range_f(0, 6)
			hv.tents.append(tn)
		for k in PESTR_N:
			var pe := Pestr.new()
			pe.phase = float(k) / PESTR_N * TAU
			pe.r = _rnd.range_f(0.3, 0.6)
			pe.p = hv.top
			pe.prev = hv.top
			hv.pestr.append(pe)
		hv.pc = hv.top
		anemones.append(hv)


func step(world: EcoWorld, dt: float) -> void:
	for hv in anemones:
		_step_anemone(world, hv, dt)


func _step_anemone(world: EcoWorld, hv: Anemone, dt: float) -> void:
	hv.digest -= dt
	hv.lure_cd -= dt
	hv.hide_cd -= dt
	hv.msg_cd -= dt
	var was_lit := hv.lit
	hv.lit = world.in_beam(hv.top)
	# щупальца: в луче быстро прячутся, в темноте медленно раскрываются
	var want := 0.0 if hv.lit else (DIGEST_OPEN if hv.digest > 0.0 else 1.0)
	if want < hv.open:
		hv.open = maxf(want, hv.open - dt * CLOSE_RATE)
	else:
		hv.open = minf(want, hv.open + dt * OPEN_RATE)
	if hv.lit and not was_lit and hv.open > HIDE_OPEN and hv.hide_cd <= 0.0:
		hv.hide_cd = HIDE_CD
		world.emit(ID, "hide", hv.top, _text(world, "%s прячет щупальца от прожектора", [[ID, Species.Case.NOM]]))
		world.emit(PESTR, "immune", hv.top, _text(world, "%s ныряет в сжатые щупальца %s",
			[[PESTR, Species.Case.NOM], [ID, Species.Case.GEN]]))
	if hv.lit:
		hv.lure = null
	if fish:
		_lure(world, hv, dt)
		_catch(world, hv, dt)
	if hv.left_t > 0.0:
		hv.left_t -= dt
		if hv.left_t <= 0.0:
			world.emit(PESTR, "leftovers", hv.mouth, _say(world, hv, "%s доедает остатки добычи %s",
				[[PESTR, Species.Case.NOM], [ID, Species.Case.GEN]]))
			hv.msg_cd = MSG_CD
	_swim_pestr(world, hv, dt)


## Пестрянки подманивают ближайшую спокойную стаю и ведут её к щупальцам, пока стая не встревожится.
func _lure(world: EcoWorld, hv: Anemone, dt: float) -> void:
	if hv.lure == null and hv.open > LURE_OPEN and hv.digest <= 0.0 and hv.lure_cd <= 0.0:
		var best: EcoFish.Shoal = null
		var bd := LURE_R
		for sh in fish.shoals:
			var d := sh.center.distance_to(hv.top)
			if sh.alive >= 3 and sh.alarm <= 0.0 and not sh.leader() and d < bd:
				bd = d
				best = sh
		hv.lure_cd = _rnd.range_f(LURE_CD_MIN, LURE_CD_MAX)
		if best:
			hv.lure = best
			hv.lure_t = LURE_T
			world.emit(PESTR, "lure", hv.top, _say(world, hv, "%s выманивает %s к щупальцам",
				[[PESTR, Species.Case.NOM], [EcoFish.ID, Species.Case.ACC]]))
	if hv.lure:
		hv.lure_t -= dt
		if hv.lure_t <= 0.0 or hv.lure.alarm > 0.0 or hv.lure.leader():
			hv.lure = null
		else:
			hv.lure.goal = hv.top + Vector3(0, LURE_UP, 0)
			hv.lure.goal_timer = maxf(hv.lure.goal_timer, 0.5)


## Ловля: только раскрытые щупальца и только сытый хватень; рыбка ближе REACH · open ко рту.
func _catch(world: EcoWorld, hv: Anemone, dt: float) -> void:
	if hv.open <= CATCH_OPEN or hv.digest > 0.0:
		return
	var reach := REACH * hv.open
	for sh in fish.shoals:
		if sh.alive == 0 or sh.center.distance_to(hv.mouth) > SHOAL_NEAR:
			continue
		for f: EcoFish.Fish in sh.members:
			if not f.agent.alive or f.agent.p.distance_to(hv.mouth) >= reach:
				continue
			if _rnd.next() < dt * CATCH_RATE:
				fish.kill(f)
				hv.digest = DIGEST
				hv.lure = null
				hv.left_t = LEFTOVERS
				world.emit(ID, "catch", hv.mouth, _say(world, hv, "%s поймал %s щупальцами",
					[[ID, Species.Case.NOM], [EcoFish.ID, Species.Case.ACC]]))
				return


## Пестрянки: хоровод среди щупалец, при подманивании — у стаи, на полпути от хозяина.
func _swim_pestr(world: EcoWorld, hv: Anemone, dt: float) -> void:
	var t := world.time
	var o := hv.open
	var c := Vector3.ZERO
	for pe in hv.pestr:
		var a := t * (1.6 if hv.lure else 0.9) + pe.phase
		var to: Vector3
		if hv.lure:
			to = hv.top.lerp(hv.lure.center, 0.45 + sin(t * 2.0 + pe.phase) * 0.2) + Vector3(cos(a) * 0.6, 0.3, sin(a) * 0.6)
		else:
			var rr := pe.r * (0.4 + 0.6 * o)
			to = Vector3(hv.top.x + cos(a) * rr, hv.top.y + 0.25 + 0.35 * o + sin(t * 2.3 + pe.phase) * 0.08,
				hv.top.z + sin(a) * rr)
		pe.prev = pe.p
		pe.p = pe.p.lerp(to, minf(1.0, dt * 2.5))
		c += pe.p
	hv.pc = c / PESTR_N


## Хватень и его пестрянки видны сонару и сканеру: хватень — по макушке, пестрянки — по их середине.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for hv in anemones:
		out.append(EcoWorld.target(ID, hv.top, 1.2))
		out.append(EcoWorld.target(PESTR, hv.pc, 0.6))


## Дыхание тела (план реализма Б3): столб и диск медленно раздуваются и опадают — ±BREATH_AMP по ширине за BREATH_T с,
## у каждого хватня своя фаза; спрятавший щупальца сжимается до CLOSED_W ширины. Высота не меняется — диск на месте.
const BREATH_T := 5.5
const BREATH_AMP := 0.05
const CLOSED_W := 0.88
## Основание щупальца на диске — в TENT_R м от оси (при ширине 1).
const TENT_R := 0.3


## Ширина тела хватня в момент t (доля от исходной): сжатие по open и дыхание; live = false — без дыхания
## («Экономно»: тело не колышется, только сжимается).
static func breath(hv: Anemone, t: float, live := true) -> float:
	var w := lerpf(CLOSED_W, 1.0, hv.open)
	if live:
		w *= 1.0 + BREATH_AMP * sin(t * TAU / BREATH_T + hv.index * 2.1 + hv.yaw)
	return w


## Расстановка щупальца k хватня в момент t (anemoneUpdate): основание на диске в 0,3 м от оси (× ширина тела
## `breath`), наклон наружу tilt · (0,25 + 0,75 · open) с покачиванием, длина × (0,12 + 0,88 · open), сжатое — вдвое толще.
static func tentacle(hv: Anemone, k: int, t: float, live := true) -> Transform3D:
	var tn := hv.tents[k]
	var o := hv.open
	var sway := sin(t * 1.4 + tn.phase) * 0.18 * o
	var b := Basis(Vector3.UP, -tn.a) * Basis(Vector3.BACK, -(tn.tilt * (0.25 + 0.75 * o) + sway))
	var w := 1.0 + (1.0 - o)
	b = b * Basis.from_scale(Vector3(w, tn.length * (0.12 + 0.88 * o), w))
	var r := TENT_R * breath(hv, t, live)
	return Transform3D(b, hv.top + Vector3(cos(tn.a) * r, 0.0, sin(tn.a) * r))


## Расстановка тела хватня в момент t: поворот yaw у подножия, ширина — `breath`.
static func body(hv: Anemone, t: float, live := true) -> Transform3D:
	var w := breath(hv, t, live)
	return Transform3D(Basis(Vector3.UP, hv.yaw) * Basis.from_scale(Vector3(w, 1.0, w)), hv.base)


## Расстановка пестрянки: носом по ходу (по кругу хоровода, если стоит), виляет хвостом.
static func pestr_pose(hv: Anemone, k: int, t: float) -> Transform3D:
	var pe := hv.pestr[k]
	var dir := pe.p - pe.prev
	if dir.length_squared() < 1e-8:
		var a := t * 0.9 + pe.phase
		dir = Vector3(-sin(a), 0.0, cos(a))
	var b := Basis.looking_at(dir.normalized(), Vector3.UP, true) * Basis(Vector3.BACK, sin(t * 9.0 + pe.phase) * 0.2)
	return Transform3D(b, pe.p)


## Текст с текстом-паузой: у одного хватня — одна история за раз (say в js); в паузе наблюдение без текста.
static func _say(world: EcoWorld, hv: Anemone, fmt: String, names: Array) -> Callable:
	return Callable() if hv.msg_cd > 0.0 else _text(world, fmt, names)


## Текст собирается в момент показа (вид мог быть уже просканирован); names — [вид, падеж] по порядку, первое имя
## с заглавной. Мир — слабой ссылкой (событие лежит в шине мира).
static func _text(world: EcoWorld, fmt: String, names: Array) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var args: Array = []
		for n in names:
			var s: String = w.nm(n[0], n[1]) if w else Species.called(n[0], n[1])
			args.append(Species.cap(s) if args.is_empty() else s)
		return fmt % args
