class_name EcoFringe
extends EcoSystem
## Инеевая бахрома у Светового колодца 05 (#836, часть 5; концепт ART-080 — `docs/concept-art/inevaya-bahroma-i-mol.md`):
## мягкие нити свисают со льда (y = 0) тремя группами по 16 с просветами, центр трещины открыт. Нить качается от
## корня (0) к концу (0,3–0,6 м, период 7–11 с, своя фаза, мелкая волна ≤ 0,08 м). Корпус, задевший нить, оставляет
## на ней светящийся след — только на задетом участке: подъём 0,3 с, ровно до 10 с, затухание к 60 с («светится ещё
## минуту после касания», `docs/bestiary.md`); новое касание обновляет участок. Задетую нить корпус отводит в сторону,
## она возвращается за 3–5 с. Касание — не препятствие и не урон: мир считает его по `EcoLink.ShipState` и корпусу
## `EcoHull`, событий кораблю нет.
## Здесь — числа и шаг без узлов (`Curtain`), детерминированно от своего зерна (случай мира не трогает). Шагает, только
## пока корабль ближе ACTIVE к колодцу. «Экономно» — первые COUNT_LITE нитей (по группам поровну — группа нити i — i % 3).
## Данные следа на нить для шейдера — `Curtain.custom(i)` (время касания, середина и полуширина участка по длине).
## Вид (MultiMesh пряди ART-083, #922) — следующая часть.

const ID := "fringe"
## Середина колодца (x, z) — та же, что у моли (`LayerMap.xz("05")`).
const WELL := EcoMoth.WELL
## Нитей: 48 тремя группами, «Экономно» — 24.
const COUNT := 48
const COUNT_LITE := 24
const GROUPS := 3
## Группа — дуга вокруг середины: середина группы g под углом GROUP_ANGLE + g · TAU/3, разброс ±GROUP_SPREAD рад,
## радиус от RING.x до RING.y м (ближе RING.x — открытая трещина).
const GROUP_ANGLE := 0.4
const GROUP_SPREAD := 0.55
const RING := Vector2(7.0, 15.0)
## Длина нити, м: обычно LEN_USUAL, каждая LONG_EVERY-я — длинная, до LEN_MAX; короче LEN_MIN не бывает.
const LEN_MIN := 8.0
const LEN_USUAL := Vector2(10.0, 16.0)
const LEN_MAX := 20.0
const LONG_EVERY := 4
## Качание: размах конца (м), период (с), мелкая волна (м, длина волны WAVE_LEN доли длины).
const SWAY := Vector2(0.3, 0.6)
const PERIOD := Vector2(7.0, 11.0)
const WAVE := 0.08
const WAVE_LEN := 0.3
## След: подъём RISE с, держится до HOLD с, гаснет к FADE с от касания. Края участка мягкие на EDGE доли длины.
const RISE := 0.3
const HOLD := 10.0
const FADE := 60.0
const EDGE := 0.04
## Точек проверки касания на нить (корень — 0, конец — SAMPLES − 1), запас к корпусу, м.
const SAMPLES := 17
const TOUCH_R := 0.1
## Отвод задетой нити корпусом: конец сдвигается на PUSH м от корабля, возвращается с постоянной RETURN с
## (за 3 · RETURN ≈ 4 с почти на месте).
const PUSH := 1.2
const RETURN := 1.3
## Дальше этого от середины колодца (м по горизонтали) нити стоят и не рисуются.
const ACTIVE := 110.0

## Занавес модуля мира и уровень «Экономно».
var curtain: Curtain
var lite := false


func reset(_world: EcoWorld) -> void:
	curtain = Curtain.new()
	curtain.set_lite(lite)


func step(world: EcoWorld, dt: float) -> void:
	if near(world.ship):
		curtain.step(world.ship, world.time, dt)


func set_lite(on: bool) -> void:
	lite = on
	if curtain:
		curtain.set_lite(on)


## Корабль у колодца: ближе ACTIVE по горизонтали.
static func near(ship: EcoLink.ShipState) -> bool:
	return Vector2(ship.pos.x, ship.pos.z).distance_to(WELL) <= ACTIVE


## Яркость следа через t с после касания: 0 → 1 за RISE, 1 до HOLD, плавно к 0 к FADE; до касания и после — 0.
static func envelope(t: float) -> float:
	if t < 0.0 or t >= FADE:
		return 0.0
	if t < RISE:
		return t / RISE
	if t <= HOLD:
		return 1.0
	var k := 1.0 - (t - HOLD) / (FADE - HOLD)
	return k * k * (3.0 - 2.0 * k)


## Доля участка в точке v (0 — корень, 1 — конец): 1 внутри [mid − half, mid + half], мягко к 0 за EDGE.
static func band(v: float, mid: float, half: float) -> float:
	var d := absf(v - mid) - half
	if d <= 0.0:
		return 1.0
	return clampf(1.0 - d / EDGE, 0.0, 1.0)


## Нити у колодца: корень на льду, длина, качание, след касания, отвод.
class Curtain:
	extends RefCounted
	var root := PackedVector3Array()
	var length := PackedFloat32Array()
	var sway := PackedFloat32Array()
	var rate := PackedFloat32Array()      ## рад/с качания
	var phase := PackedFloat32Array()
	var sway_dir := PackedVector3Array()  ## плоскость качания (по горизонтали)
	## След: время мира касания (−INF — не задета), середина и полуширина участка (доли длины).
	var touched := PackedFloat32Array()
	var mid := PackedFloat32Array()
	var half := PackedFloat32Array()
	## Отвод конца корпусом (м, по горизонтали).
	var push := PackedVector3Array()
	## Сколько первых нитей живёт и рисуется; время мира последнего шага; касаний всего (для теста).
	var active := 0
	var time := 0.0
	var touches := 0

	func _init(lite := false, seed_value := 8361) -> void:
		var rng := EcoRandom.new(seed_value)
		var n := COUNT
		length.resize(n)
		sway.resize(n)
		rate.resize(n)
		phase.resize(n)
		touched.resize(n)
		mid.resize(n)
		half.resize(n)
		root.resize(n)
		sway_dir.resize(n)
		push.resize(n)
		for i in n:
			var g := i % GROUPS
			var a := GROUP_ANGLE + g * TAU / GROUPS + rng.range_f(-GROUP_SPREAD, GROUP_SPREAD)
			var r := rng.range_f(RING.x, RING.y)
			root[i] = Vector3(WELL.x + cos(a) * r, 0.0, WELL.y + sin(a) * r)
			var l := rng.range_f(LEN_USUAL.x, LEN_USUAL.y)
			if i % LONG_EVERY == LONG_EVERY - 1:
				l = rng.range_f(LEN_USUAL.y, LEN_MAX)
			length[i] = clampf(l, LEN_MIN, LEN_MAX)
			sway[i] = rng.range_f(SWAY.x, SWAY.y)
			rate[i] = TAU / rng.range_f(PERIOD.x, PERIOD.y)
			phase[i] = rng.range_f(0.0, TAU)
			var d := rng.range_f(0.0, TAU)
			sway_dir[i] = Vector3(cos(d), 0.0, sin(d))
			touched[i] = -INF
		active = COUNT_LITE if lite else n

	func set_lite(on: bool) -> void:
		active = COUNT_LITE if on else root.size()

	## Точка нити i на доле длины v (0 — корень на льду, 1 — конец) в момент t: качание растёт к концу как v²,
	## мелкая волна бежит вниз, отвод корпусом — тоже к концу.
	func point(i: int, v: float, t: float) -> Vector3:
		var bend := v * v
		var s := sin(rate[i] * t + phase[i]) * sway[i] * bend
		var w := sin(rate[i] * 3.1 * t - v / WAVE_LEN * TAU + phase[i]) * WAVE * v
		var side := Vector3(-sway_dir[i].z, 0.0, sway_dir[i].x)
		return root[i] + Vector3(0.0, -length[i] * v, 0.0) + sway_dir[i] * s + side * w + push[i] * bend

	## Сила следа нити i на доле длины v сейчас (0…1).
	func glow(i: int, v: float) -> float:
		return EcoFringe.envelope(time - touched[i]) * EcoFringe.band(v, mid[i], half[i])

	## Сколько нитей светится сейчас (след ярче 0,01).
	func lit_count() -> int:
		var n := 0
		for i in active:
			if EcoFringe.envelope(time - touched[i]) > 0.01:
				n += 1
		return n

	## Данные следа для INSTANCE_CUSTOM: секунд от касания (FADE и больше — не светится), середина, полуширина, длина.
	func custom(i: int) -> Color:
		return Color(minf(time - touched[i], FADE), mid[i], half[i], length[i])

	## Шаг в момент мира t: отвод возвращается, корпус проверяет касание по SAMPLES точкам каждой нити рядом.
	func step(ship: EcoLink.ShipState, t: float, dt: float) -> void:
		time = t
		var back := exp(-dt / RETURN)
		var reach := EcoHull.BOUND + TOUCH_R
		for i in active:
			push[i] *= back
			var flat := Vector2(root[i].x - ship.pos.x, root[i].z - ship.pos.z)
			if flat.length() > reach + SWAY.y + PUSH:
				continue
			if ship.pos.y - reach > 0.0 or ship.pos.y + reach < -length[i]:
				continue
			var lo := 2.0
			var hi := -1.0
			for k in SAMPLES:
				var v := float(k) / (SAMPLES - 1)
				if EcoHull.touches(point(i, v, t), ship.pos, ship.yaw, TOUCH_R):
					lo = minf(lo, v)
					hi = maxf(hi, v)
			if hi < 0.0:
				continue
			_touch(i, lo, hi, ship, t)

	func _touch(i: int, lo: float, hi: float, ship: EcoLink.ShipState, t: float) -> void:
		var step_v := 1.0 / (SAMPLES - 1)
		lo = maxf(lo - step_v * 0.5, 0.0)
		hi = minf(hi + step_v * 0.5, 1.0)
		if EcoFringe.envelope(t - touched[i]) > 0.0:
			# прежний след ещё светится — участок растёт, а не перескакивает
			lo = minf(lo, mid[i] - half[i])
			hi = maxf(hi, mid[i] + half[i])
		else:
			touches += 1
		mid[i] = (lo + hi) * 0.5
		half[i] = (hi - lo) * 0.5
		# подъём уже идёт — не начинать его заново, иначе след под корпусом мигал бы на нуле
		var since := t - touched[i]
		if since >= RISE:
			touched[i] = t - RISE if since < FADE else t
		var away := Vector3(root[i].x - ship.pos.x, 0.0, root[i].z - ship.pos.z)
		if away.length() > 1e-3:
			push[i] = away.normalized() * PUSH
