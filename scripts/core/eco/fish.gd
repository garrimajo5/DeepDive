class_name EcoFish
extends EcoSystem
## Светляки-полосники (initFish/updateFish в js/creatures.js, Unity `Core/EcoFish.cs`): шесть стай по 22 рыбки у кораллов
## рифа, ещё две — у кроны Каменного цветка (ART-027) и молодь (14 мелких) в клетке Костей левиафана. Стая бродит у дома, держится вместе (к центру, в ногу,
## не толкаясь), рыбки не опускаются на дно и не поднимаются ко льду. Серпохвост ближе 16 м — тревога: стая уходит к дому в кораллы и там прячется (медленно, ≤ 1 м/с), событие
## «flee» раз в 30 с. Корабль ближе 11 м на ходу быстрее 1,2 м/с пугает без события: рыбки шарахаются, но домой не уходят.
## Хищники берут рыбок через nearest_fish и kill; съеденная появляется у дома через 25–40 с.

const ID := "fish"
## Рыбок в стае.
const PER_SHOAL := 22
## Ближе этого хищник поднимает тревогу (м).
const PRED_ALARM := 16.0
## Ближе этого корабль на ходу пугает стаю (м).
const SHIP_ALARM := 11.0
## Быстрее этого корабль пугает (м/с, вперёд или назад).
const SHIP_FAST := 1.2
## Пауза между сообщениями «стая уходит» (с).
const FLEE_COOLDOWN := 30.0
## Скорости: прячется у дома, в тревоге, спокойно; не медленнее MIN_SPEED.
const HIDE_SPEED := 1.0
const ALARM_SPEED := 6.5
const CALM_SPEED := 2.4
const MIN_SPEED := 0.5
## Запас до корпуса корабля, м (S.pushOut(f.p, 0.3)).
const HULL_GAP := 0.3
## Стая за ледокрылом: цель — в LEAD_BEHIND позади него и LEAD_BELOW ниже (sh.follow в js).
const LEAD_BEHIND := 12.0
const LEAD_BELOW := 3.0
## Стая ближе r + VEIL_PAD к фонарной вуали по горизонтали (центр стаи; рыбки — в пределах 14 м от дома) — рыбки
## обходят купол и могут попасть под щупальца (EcoVeil.fish_push).
const VEIL_PAD := EcoVeil.FISH_PAD + 20.0
## Стая дальше FAR от корабля (в тумане, плотность ≥ 0,0135 — видна на четверть) ходит реже: раз в FAR_EVERY
## шагов мира (при 60 к/с — каждый третий кадр, шагом ≈ FAR_STEP), набирая пропущенное время. Очередь — по счётчику
## шагов и номеру стаи, а не по набранному времени: при неровном кадре время сводило все дальние стаи в один кадр
## (issue #803: мир 51 мс вместо 15). Дальние стаи сдвинуты по фазе, чтобы не считались в одном кадре.
const FAR := 100.0
const FAR_STEP := 0.05
const FAR_EVERY := 3
## Стая дальше MID (но ближе FAR) ходит через шаг — раз в MID_EVERY, набирая пропущенное (issue #133): рыбка
## в 50 м — пара точек на экране, сдвиг на 4 см за кадр не виден.
const MID := 50.0
const MID_EVERY := 2
## Шаг стаи не длиннее LAG_MAX (с), как было до очереди (FAR_STEP + EcoWorld.SLOW_STEP): если ещё кадр ожидания
## сделал бы шаг длиннее, стая на медленных кадрах шагает раньше своей очереди.
const LAG_MAX := FAR_STEP + EcoWorld.SLOW_STEP

## Дома стай: шесть мест кораллов (W.coralSpots), ближайших к (0, 55) и разнесённых больше чем на 35 м, плюс 1,5 м
## вверх — числа браузерной версии (в Unity x со знаком минус). Дом на 3,5 м над дном (Seabed.height).
## Шестую стаю уносит на спине гротовик (EcoGrot.RIDERS): он двигает ей home, ставит range_m = 4 и riding.
const HOMES: Array[Vector3] = [
	Vector3(15.3753, -33.0888, 75.9897),
	Vector3(-26.4205, -40.8460, 24.4689),
	Vector3(-63.3665, -35.1576, 80.4209),
	Vector3(38.0868, -27.2991, 115.9097),
	Vector3(56.1066, -36.3559, 6.1835),
	Vector3(76.8304, -31.1474, 52.3365),
]

## Стаи у кроны Каменного цветка (EcoFlower.CENTER, ART-027) — после шести стай рифа, чтобы номера тех не сдвинулись.
## Кружат вокруг кроны снаружи кольцом CROWN_RING (крона — Ø 26 м, на кольце ветвей нет) на высоте CROWN_LIFT над
## подножием, каждая в свою сторону; в тревоге прячутся в чашу кроны — дом на оси на CROWN_HIDE над подножием
## (ось в чаше свободна, вокруг — светящиеся кончики на 4–11 м от оси, 15–27 м над подножием).
const CROWN_SHOALS := 2
const CROWN_RING := Vector2(15.0, 19.0)
const CROWN_LIFT := Vector2(14.0, 27.0)
const CROWN_HIDE := 20.0
## Подножие цветка без дна в мире (тесты без Seabed), м.
const CROWN_FLOOR := -40.0
## За одну смену цели стая у кроны сдвигается по кругу на столько (рад).
const CROWN_DRIFT := Vector2(0.4, 1.1)

## Молодь в клетке Костей левиафана (EcoBones, ART-030: «между рёбрами прячется молодь») — после стай кроны.
## Мелкие светляки (JUV_SIZE от взрослых, JUV_PER в стае) бродят внутри чистого прохода клетки: цель — в CAGE_X
## от оси и CAGE_Z вдоль неё, на CAGE_LIFT над дном (проход 14 × 7 м, рёбра в 8,45 м от оси — цель их не задевает),
## мягкие стенки (cage_push) не дают уплыть из прохода;
## в тревоге прячутся в середине клетки на CAGE_HIDE над дном. Случай — свой, стаи рифа и кроны не сдвигаются.
const CAGE_SHOALS := 1
const JUV_PER := 14
const JUV_SIZE := 0.55
const CAGE_X := 4.0
const CAGE_Z := 11.0
const CAGE_LIFT := Vector2(1.5, 4.5)
const CAGE_HIDE := 2.5
## Мягкие стенки клетки: дальше CAGE_WALL от оси вбок и CAGE_END вдоль малька тянет обратно в проход (рёбра — в 8,45 м).
const CAGE_WALL := 5.0
const CAGE_END := 12.5
## Дно клетки без дна в мире (тесты без Seabed), м — как EcoBones.floor_y.
const CAGE_FLOOR := -46.0

## Цвет полос стаи: по концепту ART-011 стаи светятся в голубой гамме (#67DDEB, #6FE3FF и близкие оттенки).
## У каждой рыбки своя яркость Fish.bright.
const COLORS: Array[Color] = [
	Color("67DDEB"), Color("6FE3FF"), Color("5EF2D6"), Color("7FE7FF"), Color("8FD0FF"), Color("4FD8E8"),
]


## Стая.
class Shoal:
	extends RefCounted
	var index := 0
	var home := Vector3.ZERO
	var goal := Vector3.ZERO
	var center := Vector3.ZERO
	var velocity := Vector3.ZERO
	## Радиус блуждания вокруг дома (м).
	var range_m := 14.0
	## Стая у кроны цветка: кружит вокруг оси axis (подножие цветка) по кольцу CROWN_RING; turn — сторона (±1).
	var crown := false
	var axis := Vector3.ZERO
	var turn := 1.0
	## Молодь в клетке костей: frame — оси клетки (EcoBones: +Z к голове), начало — центр клетки на высоте 0.
	var cage := false
	var frame := Transform3D.IDENTITY
	## Случай стаи: у стай рифа — общий, у стай кроны — свой (стаи рифа ведут себя как до них).
	var rnd: EcoRandom
	## Секунды тревоги (стая уходит домой или шарахается).
	var alarm := 0.0
	var flee_cd := 0.0
	var goal_timer := 0.0
	## Сколько рыбок живо.
	var alive := 0
	## От чего шарахается сейчас (has_threat — есть ли угроза).
	var has_threat := false
	var threat := Vector3.ZERO
	## Угроза — корабль, а не хищник: домой не уходят.
	var threat_is_ship := false
	var color := Color.WHITE
	## Набранное время дальней стаи (с), ещё не прошагнутое.
	var lag := 0.0
	## Ведёт ледокрыл (EcoRay, sh.follow в js): стая держится в LEAD_BEHIND за ним и LEAD_BELOW ниже, пока lead_t > 0.
	## Ведущий — слабой ссылкой (у него свои поля p и dir).
	var lead_t := 0.0
	var _lead: WeakRef
	## Стая у фонарной вуали (EcoVeil): только у таких рыбки обходят купол и попадают под щупальца.
	var near_veil := false
	## Стая живёт в рифе на спине гротовика (EcoGrot, sh.range в js): держится своего рифа — на споры и моллюсков
	## не слетается, ледокрыл её не уводит.
	var riding := false
	var members: Array = []  ## Array[Fish]
	## Места и жизнь рыбок стаи по Fish.slot на начало шага стаи и расталкивание каждой (sep): пары соседей
	## считаются один раз (22 × 21 / 2), без обхода объектов.
	var pos := PackedVector3Array()
	var live := PackedByteArray()
	var sep := PackedVector3Array()
	## Рамка стаи для поиска добычи (nearest_fish): дальше этого (м) от center живых рыбок нет; −1 — живых нет.
	## Считает шаг стаи после того, как рыбки сдвинулись, и bounds(); INF — не считана (перебираются все).
	var spread := INF

	## Кто ведёт стаю сейчас (объект с полями p и dir) или null.
	func leader() -> Object:
		if lead_t <= 0.0 or _lead == null:
			return null
		return _lead.get_ref()

	## Стаю повёл ведущий на seconds секунд.
	func follow(who: Object, seconds: float) -> void:
		_lead = weakref(who) if who else null
		lead_t = seconds if who else 0.0


## Рыбка: существо мира и её место в стае.
class Fish:
	extends RefCounted
	var agent: EcoAgent
	## Стая — слабая ссылка: стая держит рыбок, рыбка смотрит на стаю (без цикла RefCounted).
	var shoal: Shoal:
		get:
			return _shoal.get_ref() if _shoal else null
		set(value):
			_shoal = weakref(value) if value else null
	## Номер среди всех рыбок (место в MultiMesh).
	var index := 0
	## Номер в стае (Shoal.pos, Shoal.live).
	var slot := 0
	## Фаза покачивания.
	var phase := 0.0
	## Яркость цвета стаи, 0,75–1,15.
	var bright := 1.0
	## Размер от взрослой рыбки: 1 — взрослая, JUV_SIZE — молодь.
	var size := 1.0
	var _shoal: WeakRef


var shoals: Array[Shoal] = []
var all: Array[Fish] = []

## Фонарные вуали: светляки их обходят, под куполом вуаль жалит (null — вуалей нет).
var veils: EcoVeil

var _rnd: EcoRandom
## Живые хищники на этом шаге: один обход мира на все стаи.
var _preds: Array[EcoAgent] = []
## Шаги мира с reset — очередь дальних и средних стай (FAR_EVERY, MID_EVERY).
var _tick := 0


## Всех рыбок: стаи рифа и кроны по PER_SHOAL и молодь в костях по JUV_PER.
static func total() -> int:
	return PER_SHOAL * (HOMES.size() + CROWN_SHOALS) + JUV_PER * CAGE_SHOALS


## Своё зерно стай: от зерна мира, чтобы другой мир был другим, а остальные виды не сдвигались.
static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7001) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	_tick = 0
	var crown_rnd := EcoWorld.seeded_for(seed_for(world.seed_value) ^ 0x5F3C)
	var cage_rnd := EcoWorld.seeded_for(seed_for(world.seed_value) ^ 0x0B0E)
	shoals.clear()
	all.clear()
	var foot := Vector3(EcoFlower.CENTER.x, CROWN_FLOOR, EcoFlower.CENTER.y)
	if world.ground.is_valid():
		foot.y = world.ground.call(foot.x, foot.z)
	var reef_crown := HOMES.size() + CROWN_SHOALS
	for si in reef_crown + CAGE_SHOALS:
		var sh := Shoal.new()
		sh.rnd = _rnd
		var h: Vector3
		var count := PER_SHOAL
		var size := 1.0
		if si < HOMES.size():
			h = HOMES[si]
		elif si < reef_crown:
			sh.crown = true
			sh.rnd = crown_rnd
			sh.axis = foot
			sh.turn = 1.0 if (si - HOMES.size()) % 2 == 0 else -1.0
			h = foot + Vector3(0, CROWN_HIDE, 0)
		else:
			sh.cage = true
			sh.rnd = cage_rnd
			sh.frame = cage_frame()
			h = sh.frame.origin
			h.y = cage_floor(world.ground, h.x, h.z) + CAGE_HIDE
			count = JUV_PER
			size = JUV_SIZE
		sh.index = si
		sh.home = h
		sh.goal = h
		sh.center = h
		if sh.crown:  # стаи у кроны начинают снаружи, на кольце с разных сторон
			var a0 := PI * (si - HOMES.size()) + 0.6
			var r0 := (CROWN_RING.x + CROWN_RING.y) * 0.5
			sh.center = foot + Vector3(cos(a0) * r0, CROWN_HIDE, sin(a0) * r0)
			sh.goal = sh.center
		sh.color = COLORS[si % COLORS.size()]
		shoals.append(sh)
		var spread := 1.5 if sh.cage else 3.0
		for k in count:
			var p := sh.center + Vector3(sh.rnd.range_f(-spread, spread), sh.rnd.range_f(0, spread),
				sh.rnd.range_f(-spread, spread))
			var a := world.spawn(ID, p)
			a.home = h
			a.clearance = 0.4 * size
			a.v = Vector3(sh.rnd.range_f(-1, 1), 0, sh.rnd.range_f(-1, 1))
			var f := Fish.new()
			f.agent = a
			f.shoal = sh
			f.index = all.size()
			f.slot = sh.members.size()
			f.phase = sh.rnd.range_f(0, 6)
			f.bright = sh.rnd.range_f(0.75, 1.15)
			f.size = size
			all.append(f)
			sh.members.append(f)
		sh.alive = count
		sh.pos.resize(count)
		sh.live.resize(count)
		sh.sep.resize(count)


## Оси клетки костей (как EcoBones: +Z — к голове), начало — центр клетки на высоте 0.
static func cage_frame() -> Transform3D:
	return Transform3D(EcoBones.make_basis(EcoBones.CENTER), Vector3(EcoBones.CENTER.x, 0.0, EcoBones.CENTER.y))


## Дно в клетке: Seabed мира, без него — CAGE_FLOOR.
static func cage_floor(ground: Callable, x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else CAGE_FLOOR


## Следующая цель молоди: внутри прохода клетки (в CAGE_X от оси, в CAGE_Z вдоль), на CAGE_LIFT над дном.
static func cage_goal(sh: Shoal, rnd: EcoRandom, ground: Callable) -> Vector3:
	var g := sh.frame * Vector3(rnd.range_f(-CAGE_X, CAGE_X), 0.0, rnd.range_f(-CAGE_Z, CAGE_Z))
	g.y = cage_floor(ground, g.x, g.z) + rnd.range_f(CAGE_LIFT.x, CAGE_LIFT.y)
	return g


## Съесть рыбку: пропадает на 25–40 с, потом появляется у дома стаи.
func kill(f: Fish) -> void:
	if not f.agent.alive:
		return
	f.agent.alive = false
	f.agent.v = Vector3.ZERO
	f.agent.timer = f.shoal.rnd.range_f(25, 40)


## Ближайшая живая рыбка не дальше radius; skip — (Fish) -> bool, кого не видно (в укрытии). null — никого.
## Сначала стая: дальше radius + Shoal.spread от её центра рыбок нет — её не перебираем (issue #848). Дальше —
## квадрат расстояния, и только ближе лучшей найденной зовётся skip (фильтр укрытий дорогой: станции, кельп, риф,
## чернила). Рыбку переставили руками в обход шага — сначала bounds().
func nearest_fish(pos: Vector3, radius: float, skip: Callable = Callable()) -> Fish:
	var best: Fish = null
	var bd2 := radius * radius
	var has_skip := skip.is_valid()
	for sh in shoals:
		if sh.spread < 0.0:
			continue
		var reach := radius + sh.spread
		if sh.center.distance_squared_to(pos) > reach * reach:
			continue
		for f: Fish in sh.members:
			var a := f.agent
			if not a.alive:
				continue
			var d2 := a.p.distance_squared_to(pos)
			if d2 < bd2 and not (has_skip and skip.call(f)):
				bd2 = d2
				best = f
	return best


## Пересчитать рамки стай (Shoal.spread) по нынешним местам рыбок — после того, как рыбок двигали не шагом стаи.
func bounds() -> void:
	for sh in shoals:
		_bound(sh)


static func _bound(sh: Shoal) -> void:
	var c := sh.center
	var r2 := -1.0
	for f: Fish in sh.members:
		var a := f.agent
		if a.alive:
			r2 = maxf(r2, a.p.distance_squared_to(c))
	sh.spread = sqrt(r2) if r2 >= 0.0 else -1.0


## Для сонара и сканера стая — одна отметка в центре, если в ней не меньше трёх живых рыбок (sh.n >= 3).
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for sh in shoals:
		if sh.alive >= 3:
			out.append(EcoWorld.target(ID, sh.center, 2.5))


func step(world: EcoWorld, dt: float) -> void:
	_preds.clear()
	for a in world.agents:
		if a.alive and a.species == "pred":
			_preds.append(a)
	var t := world.time
	# дальше этого (в квадрате) от корабля корпус рыбку не достанет — EcoHull не зовём
	var hull_r2 := (EcoHull.BOUND + HULL_GAP) * (EcoHull.BOUND + HULL_GAP)
	for sh in shoals:
		var h := dt
		var d := sh.center.distance_to(world.ship.pos)
		if d > MID:
			var every := FAR_EVERY if d > FAR else MID_EVERY
			if (_tick + sh.index) % every != 0 and sh.lag + 2.0 * dt <= LAG_MAX + 1e-6:
				sh.lag += dt
				continue
			h += sh.lag
			sh.lag = 0.0
		elif sh.lag > 0.0:
			h += sh.lag  # стая подошла: догоняет набранное
			sh.lag = 0.0
		_step_shoal(world, sh, h)
		_step_members(world, sh, h, t, world.ground, hull_r2)
	_tick += 1


func _step_shoal(world: EcoWorld, sh: Shoal, dt: float) -> void:
	var c := Vector3.ZERO
	var v := Vector3.ZERO
	var n := 0
	for f: Fish in sh.members:
		var a := f.agent
		sh.pos[f.slot] = a.p
		sh.live[f.slot] = 1 if a.alive else 0
		if a.alive:
			c += a.p
			v += a.v
			n += 1
	sh.alive = n
	sh.sep = _separation(sh.pos, sh.live)
	sh.near_veil = veils != null and veils.near_any(sh.center, VEIL_PAD)
	if n > 0:
		sh.center = c / n
		sh.velocity = v / n
	else:
		sh.center = sh.home
		sh.velocity = Vector3.ZERO
	sh.alarm = maxf(0.0, sh.alarm - dt)
	sh.flee_cd -= dt
	sh.goal_timer -= dt
	sh.lead_t = maxf(0.0, sh.lead_t - dt)
	var lead := sh.leader()

	if lead:
		sh.goal = lead.p - lead.dir * LEAD_BEHIND + Vector3(0, -LEAD_BELOW, 0)
	elif sh.goal_timer <= 0.0 and sh.crown:
		sh.goal_timer = sh.rnd.range_f(6, 12)
		sh.goal = crown_goal(sh, sh.rnd)
	elif sh.goal_timer <= 0.0 and sh.cage:
		sh.goal_timer = sh.rnd.range_f(4, 9)
		sh.goal = cage_goal(sh, sh.rnd, world.ground)
	elif sh.goal_timer <= 0.0:
		sh.goal_timer = sh.rnd.range_f(6, 12)
		var r := sh.range_m
		var gx := sh.home.x + sh.rnd.range_f(-r, r)
		var gz := sh.home.z + sh.rnd.range_f(-r, r)
		var lift := sh.rnd.range_f(2, 7)
		var gy: float = world.ground.call(gx, gz) if world.ground.is_valid() else sh.home.y - 3.5
		sh.goal = Vector3(gx, minf(gy + lift, -4.0), gz)

	sh.has_threat = false
	sh.threat_is_ship = false
	var best := PRED_ALARM
	for a in _preds:
		var d := a.p.distance_to(sh.center)
		if d < best:
			best = d
			sh.has_threat = true
			sh.threat = a.p
	if sh.has_threat:
		if sh.alarm <= 0.0 and sh.flee_cd <= 0.0:
			sh.flee_cd = FLEE_COOLDOWN
			world.emit(ID, "flee", sh.center, _flee_text(world))
		sh.alarm = 3.0
	elif world.ship.pos.distance_to(sh.center) < SHIP_ALARM and absf(world.ship.speed) > SHIP_FAST:
		sh.has_threat = true
		sh.threat = world.ship.pos
		sh.threat_is_ship = true
		sh.alarm = maxf(sh.alarm, 1.5)


## Следующая цель стаи у кроны: дальше по кругу от нынешнего центра стаи в свою сторону, на кольце вокруг кроны.
static func crown_goal(sh: Shoal, rnd: EcoRandom) -> Vector3:
	var off := sh.center - sh.axis
	var ang := atan2(off.z, off.x) + sh.turn * rnd.range_f(CROWN_DRIFT.x, CROWN_DRIFT.y)
	var r := rnd.range_f(CROWN_RING.x, CROWN_RING.y)
	var y := minf(sh.axis.y + rnd.range_f(CROWN_LIFT.x, CROWN_LIFT.y), -4.0)
	return Vector3(sh.axis.x + cos(ang) * r, y, sh.axis.z + sin(ang) * r)


## Толчок малька обратно в проход клетки: за CAGE_WALL вбок и за CAGE_END вдоль — пружина 6 м/с² на метр.
static func cage_push(frame: Transform3D, p: Vector3) -> Vector3:
	var off := p - frame.origin
	var bx := frame.basis.x
	var bz := frame.basis.z
	var x := off.dot(bx)
	var z := off.dot(bz)
	var acc := Vector3.ZERO
	if absf(x) > CAGE_WALL:
		acc -= bx * (signf(x) * (absf(x) - CAGE_WALL) * 6.0)
	if absf(z) > CAGE_END:
		acc -= bz * (signf(z) * (absf(z) - CAGE_END) * 6.0)
	return acc


## Текст «стая уходит» собирается в момент показа (вид мог быть уже просканирован). Мир — слабой ссылкой
## и без self: событие лежит в шине мира, сильная ссылка замкнула бы круг и мир не освободился бы.
static func _flee_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID) if w else Species.called(ID)
		return "%s: стая уходит в кораллы — рядом хищник" % Species.cap(name)


## Шаг рыбок стаи sh: всё общее для стаи (центр, цель, тревога, угроза, корабль) — в локальных один раз на стаю,
## место и скорость рыбки — в локальных, обратно в агента один раз (свойство объекта на каждое чтение дороже,
## а Fish.shoal — слабая ссылка; issue #790).
func _step_members(world: EcoWorld, sh: Shoal, dt: float, t: float, ground: Callable, hull_r2: float) -> void:
	var alarm := sh.alarm > 0.0
	var center := sh.center
	var velocity := sh.velocity
	var home := sh.home
	var goal := home if alarm and not sh.threat_is_ship else sh.goal
	var pull := 1.2 if alarm else 0.35
	var sep := sh.sep
	var has_threat := sh.has_threat
	var threat := sh.threat
	var near_veil := sh.near_veil
	var cage := sh.cage
	var frame := sh.frame
	var has_ground := ground.is_valid()
	var ship_pos := world.ship.pos
	var calm_s := ALARM_SPEED if alarm else CALM_SPEED
	var state := EcoAgent.State.FLEE if alarm else EcoAgent.State.GRAZE
	var wave_x := t * 1.7
	var wave_y := t * 1.3
	var wave_z := t * 1.5
	var edge := EcoAgent.EDGE
	var r2 := -1.0  # рамка стаи (Shoal.spread) — заодно с шагом, без второго обхода
	for f: Fish in sh.members:
		var a := f.agent
		if not a.alive:
			if a.timer > 0.0:
				continue
			a.alive = true
			a.p = home + Vector3(sh.rnd.range_f(-2, 2), sh.rnd.range_f(0, 2), sh.rnd.range_f(-2, 2))
			a.v = Vector3(0, 0.2, 0)
		var p := a.p
		var v := a.v
		var acc := (center - p) * 0.5 + (velocity - v) * 0.6
		acc += (goal - p).limit_length(8.0) * pull
		acc += sep[f.slot]
		if has_threat:
			var away := p - threat
			var d := away.length()
			if d < 14.0 and d > 0.01:
				acc += away * ((10.0 * (1.0 - d / 14.0) + 2.0) / d)
		if near_veil:
			var stung := []
			acc += veils.fish_push(world, p, dt, stung)
			if not stung.is_empty():  # вуаль ужалила — рыбка съедена
				kill(f)
				continue
		if cage:
			acc += cage_push(frame, p)
		var ph := f.phase
		acc += Vector3(sin(wave_x + ph) * 0.6, sin(wave_y + ph * 2.0) * 0.3, cos(wave_z + ph) * 0.6)
		var h := a.ground_y(ground) if has_ground else 0.0
		var low := 1.2 * f.size
		if has_ground and p.y < h + low:
			acc.y += (h + low - p.y) * 6.0
		if p.y > -3.0:
			acc.y -= 4.0

		v += acc * dt
		var hide := alarm and p.distance_squared_to(home) < 16.0
		var max_s := HIDE_SPEED if hide else calm_s
		var sp := v.length()
		if sp > max_s:
			v *= max_s / sp
		elif sp < MIN_SPEED:
			v *= MIN_SPEED / (sp + 1e-3)
		p += v * dt
		a.v = v
		if p.distance_squared_to(ship_pos) < hull_r2:  # сквозь корпус не проплывают
			a.p = p
			if world.push_out(a, HULL_GAP):
				p = a.p
		if has_ground and p.y < h + a.clearance:
			p.y = h + a.clearance
		p.x = clampf(p.x, -edge, edge)
		p.z = clampf(p.z, -edge, edge)
		a.p = p
		a.state = EcoAgent.State.HIDE if hide else state
		r2 = maxf(r2, p.distance_squared_to(center))
	sh.spread = sqrt(r2) if r2 >= 0.0 else -1.0


## Не толкаться: живые соседи ближе √0,6 м отталкивают друг друга (сила 1,8 / (d² + 0,05) по разнице мест).
## pos, live — места и жизнь рыбок стаи; возвращает толчок каждой.
static func _separation(pos: PackedVector3Array, live: PackedByteArray) -> PackedVector3Array:
	var n := pos.size()
	var out := PackedVector3Array()
	out.resize(n)
	for i in n:
		if live[i] == 0:
			continue
		var pi := pos[i]
		var ai := out[i]
		for j in range(i + 1, n):
			if live[j] == 0:
				continue
			var dp := pi - pos[j]
			var d2 := dp.length_squared()
			if d2 < 0.6 and d2 > 1e-5:
				var push := dp * (1.8 / (d2 + 0.05))
				ai += push
				out[j] -= push
		out[i] = ai
	return out
