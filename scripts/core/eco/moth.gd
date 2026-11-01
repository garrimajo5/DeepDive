class_name EcoMoth
extends EcoSystem
## Ледяная моль у Светового колодца 05 (#836, часть 1; концепт ART-080 — `docs/concept-art/inevaya-bahroma-i-mol.md`):
## рачки 5 мм без своего свечения облаками под трещиной льда. Ход 0,03–0,10 м/с с рывками; прожектор их тянет —
## моль в луче (ближе дальности света и в конусе `CONE` от носа) плывёт к его оси, без света — обратно к своему облаку.
## Здесь — числа и шаг роя без узлов (`Swarm`), детерминированно от своего зерна (случай мира не трогает). Модуль мира
## (#836, часть 2): рой шагает, только пока корабль ближе ACTIVE к колодцу; «Экономно» — первые COUNT_LITE рачков
## (`set_lite`). Вид — `MothView` (один MultiMesh атласа `models/ledyanaya-mol-atlas.png`).
## Моль на стекле (#836, часть 4): рачки из луча садятся на наружное панорамное стекло корабля (точка — в осях корабля
## по `HullPlan`, как у стеклоуста, новое поле `EcoLink` не нужно): чем больше моли в луче, тем чаще; гуще у краёв
## окна, центр почти чист (мутность ART-080: ≈ 10 % в середине, до 25 % у краёв). Сидят STAY с и ползают; без света
## или на быстром ходу слетают быстрее; корабль ушёл от колодца — стекло чистое.

const ID := "moth"
## Середина колодца (x, z) — `LayerMap.xz("05")`.
const WELL := Vector2(-170.0, -70.0)
## Облака под трещиной: смещение (x, z) от середины, радиус облака R, высота — от CEIL_LOW до CEIL_HIGH (лёд y = 0).
const CLOUDS: Array[Vector2] = [Vector2(-9.0, -4.0), Vector2(7.0, 5.0), Vector2(2.0, -11.0)]
const R := 4.5
const CEIL_HIGH := -2.5
const CEIL_LOW := -9.0
## В воде: «Обычно» и «Красиво» — 240, «Экономно» — 80; на стекле — до GLASS (60), «Экономно» — GLASS_LITE (16).
const COUNT := 240
const COUNT_LITE := 80
## Скорость рачка, м/с: ровный ход и рывок; рывок каждые DASH_EVERY с (случайно в пределах), длится DASH_TIME с.
const SLOW := 0.03
const FAST := 0.10
const DASH_EVERY := Vector2(1.2, 3.5)
const DASH_TIME := 0.4
## Конус луча от носа: половина угла (рад); прожектор стоит в носу — NOSE м от центра корабля (корпус 32 м).
const CONE := 0.42
const NOSE := 16.0
## Стекло в осях корабля (HullPlan: «Панорамное стекло» 9 × 2 м на срезе носа z = NOSE_CUT, середина на 1,75 м):
## рачок сидит снаружи на GLASS_OUT м, в пределах ±GLASS_HALF по x и GLASS_Y по высоте (не на раме).
const GLASS := 60
const GLASS_LITE := 16
const GLASS_HALF := 4.2
const GLASS_Y := Vector2(0.9, 2.6)
const GLASS_OUT := 0.06
## Сколько садится в секунду на каждого рачка в луче (полный луч ≈ 50 рачков — ≈ 2 в секунду), не больше LAND_MAX.
const LAND_PER := 0.04
const LAND_MAX := 3.0
## Сколько секунд сидит (случайно в пределах); без света время идёт DARK_K раз быстрее, на ходу быстрее WASH м/с —
## WASH_K раз. Ползает со скоростью CRAWL м/с.
const STAY := Vector2(25.0, 45.0)
const DARK_K := 6.0
const WASH := 1.5
const WASH_K := 4.0
const CRAWL := 0.02
## Сдвиг к краям окна: x = ±GLASS_HALF · |u|^EDGE_POW (u — равномерно в −1…1): меньше 1 — гуще у стоек.
const EDGE_POW := 0.55
## Дальше этого от середины колодца (м по горизонтали) рой стоит и не рисуется; моль на стекле тогда не пропадает
## разом, а слетает, как без света (время сидения — DARK_K раз быстрее).
const ACTIVE := 110.0
## Садится и слетает без щелчка: карточка растёт за LAND_RISE с после посадки и тает за последние LEAVE с сидения
## (`glass_k`; без света и на ходу эти секунды идут быстрее — слетает быстрее).
const LAND_RISE := 0.4
const LEAVE := 2.0

## Рой модуля мира и уровень «Экономно».
var swarm: Swarm
var lite := false


func reset(_world: EcoWorld) -> void:
	swarm = Swarm.new()
	swarm.set_lite(lite)


func step(world: EcoWorld, dt: float) -> void:
	if near(world.ship):
		swarm.step(world.ship, dt)
	elif swarm.on_glass > 0:
		swarm.step_glass(world.ship, dt, 0, true)


## «Экономно»: шагают и рисуются первые COUNT_LITE рачков (по облакам поровну — облако рачка i — i % 3).
func set_lite(on: bool) -> void:
	lite = on
	if swarm:
		swarm.set_lite(on)


## Корабль у колодца: ближе ACTIVE по горизонтали.
static func near(ship: EcoLink.ShipState) -> bool:
	return Vector2(ship.pos.x, ship.pos.z).distance_to(WELL) <= ACTIVE


## Рой у колодца: положения рачков, их облако и таймер рывка.
class Swarm:
	extends RefCounted
	var pos := PackedVector3Array()
	var home := PackedInt32Array()
	var dash_in := PackedFloat32Array()
	var dash_t := PackedFloat32Array()
	var rng: EcoRandom
	## Сколько первых рачков живёт и рисуется (все, «Экономно» — COUNT_LITE).
	var active := 0
	## Моль на стекле: место в осях корабля и сколько ещё сидеть (0 — место свободно); мест — GLASS, занимать можно
	## первые glass_max; на стекле сейчас — on_glass; land — накопленная доля следующей посадки.
	var glass := PackedVector3Array()
	var glass_life := PackedFloat32Array()
	## Сколько секунд рачок k уже сидит (для `glass_k`).
	var glass_age := PackedFloat32Array()
	var glass_max := GLASS
	var on_glass := 0
	var land := 0.0

	func _init(lite := false, seed_value := 836) -> void:
		rng = EcoRandom.new(seed_value)
		var n := COUNT_LITE if lite else COUNT
		pos.resize(n)
		home.resize(n)
		dash_in.resize(n)
		dash_t.resize(n)
		for i in n:
			var c := i % CLOUDS.size()
			home[i] = c
			var a := rng.range_f(0.0, TAU)
			var r := R * sqrt(rng.next())
			var o := EcoMoth.cloud_center(c)
			pos[i] = Vector3(o.x + cos(a) * r, rng.range_f(CEIL_LOW, CEIL_HIGH), o.z + sin(a) * r)
			dash_in[i] = rng.range_f(0.0, DASH_EVERY.y)
		active = n
		glass.resize(GLASS)
		glass_life.resize(GLASS)
		glass_age.resize(GLASS)
		glass_max = GLASS_LITE if lite else GLASS

	func set_lite(on: bool) -> void:
		active = mini(COUNT_LITE, pos.size()) if on else pos.size()
		glass_max = GLASS_LITE if on else GLASS
		for k in range(glass_max, GLASS):
			if glass_life[k] > 0.0:
				glass_life[k] = 0.0
				on_glass -= 1

	## Шаг на dt с: к оси луча, если рачок в нём, иначе к своему облаку; скорость SLOW, во время рывка FAST.
	func step(ship: EcoLink.ShipState, dt: float) -> void:
		var lit_n := 0
		for i in active:
			dash_in[i] -= dt
			if dash_in[i] <= 0.0:
				dash_t[i] = DASH_TIME
				dash_in[i] = rng.range_f(DASH_EVERY.x, DASH_EVERY.y)
			var fast := dash_t[i] > 0.0
			dash_t[i] = maxf(dash_t[i] - dt, 0.0)
			var p := pos[i]
			var goal := EcoMoth.beam_point(ship, p)
			if goal == p:
				goal = EcoMoth.home_point(home[i], p)
			else:
				lit_n += 1
			var d := goal - p
			var len := d.length()
			var v := (FAST if fast else SLOW) * dt
			if len < 1e-4:
				if not fast:
					continue
				# в облаке без света — рывок в случайную сторону, облако не покидает
				var a := rng.range_f(0.0, TAU)
				p = EcoMoth.home_point(home[i], p + Vector3(cos(a), rng.range_f(-0.5, 0.5), sin(a)) * v)
				pos[i] = p
				continue
			p += d / len * minf(v, len)
			p.y = minf(p.y, CEIL_HIGH)
			pos[i] = p
		step_glass(ship, dt, lit_n)

	## Стекло на dt с: сидящие ползают и стареют (без света, на ходу и вдали от колодца `away` — быстрее), из луча
	## садятся новые.
	func step_glass(ship: EcoLink.ShipState, dt: float, lit_n: int, away := false) -> void:
		var age := dt
		if not ship.light_on or away:
			age *= DARK_K
		if absf(ship.speed) > WASH:
			age *= WASH_K
		for k in glass_max:
			if glass_life[k] <= 0.0:
				continue
			glass_life[k] -= age
			glass_age[k] += dt
			if glass_life[k] <= 0.0:
				glass_life[k] = 0.0
				on_glass -= 1
				continue
			var a := rng.range_f(0.0, TAU)
			var g := glass[k] + Vector3(cos(a), sin(a), 0.0) * CRAWL * dt
			glass[k] = Vector3(clampf(g.x, -GLASS_HALF, GLASS_HALF), clampf(g.y, GLASS_Y.x, GLASS_Y.y), g.z)
		if not ship.light_on or lit_n == 0 or away:
			land = 0.0
			return
		land += minf(lit_n * LAND_PER, LAND_MAX) * dt
		while land >= 1.0 and on_glass < glass_max:
			land -= 1.0
			for k in glass_max:
				if glass_life[k] <= 0.0:
					glass[k] = EcoMoth.glass_spot(rng.range_f(-1.0, 1.0), rng.next())
					glass_life[k] = rng.range_f(STAY.x, STAY.y)
					glass_age[k] = 0.0
					on_glass += 1
					break
		land = minf(land, 1.0)

	## Доля размера рачка k на стекле: 0 → 1 за LAND_RISE с после посадки, 1 → 0 за последние LEAVE с сидения.
	func glass_k(k: int) -> float:
		if glass_life[k] <= 0.0:
			return 0.0
		return smoothstep(0.0, LAND_RISE, glass_age[k]) * smoothstep(0.0, LEAVE, glass_life[k])

	## Рачок на стекле k — в мире.
	func glass_world(ship: EcoLink.ShipState, k: int) -> Vector3:
		return ship.pos + glass[k].rotated(Vector3.UP, ship.yaw)

	## Сколько рачков в луче прожектора.
	func in_beam(ship: EcoLink.ShipState) -> int:
		var n := 0
		for i in active:
			if EcoMoth.lit(ship, pos[i]):
				n += 1
		return n


## Место на стекле в осях корабля: u — −1…1 поперёк окна (сдвиг к стойкам EDGE_POW), v — 0…1 по высоте.
static func glass_spot(u: float, v: float) -> Vector3:
	var x := signf(u) * GLASS_HALF * pow(absf(u), EDGE_POW)
	return Vector3(x, lerpf(GLASS_Y.x, GLASS_Y.y, v), HullPlan.NOSE_CUT - GLASS_OUT)


static func cloud_center(c: int) -> Vector3:
	var o := WELL + CLOUDS[c]
	return Vector3(o.x, (CEIL_LOW + CEIL_HIGH) * 0.5, o.y)


static func nose_dir(ship: EcoLink.ShipState) -> Vector3:
	return Vector3(-sin(ship.yaw), 0.0, -cos(ship.yaw))


## Рачок в луче: свет есть, ближе дальности света к носу и в конусе CONE.
static func lit(ship: EcoLink.ShipState, p: Vector3) -> bool:
	if not ship.light_on or ship.light_range <= 0.0:
		return false
	var dir := nose_dir(ship)
	var d := p - (ship.pos + dir * NOSE)
	var along := d.dot(dir)
	if along <= 0.0 or along > ship.light_range:
		return false
	return (d - dir * along).length() <= along * tan(CONE)


## Куда тянет свет: ближайшая точка оси луча; не в луче — та же точка p.
static func beam_point(ship: EcoLink.ShipState, p: Vector3) -> Vector3:
	if not lit(ship, p):
		return p
	var dir := nose_dir(ship)
	var o := ship.pos + dir * NOSE
	return o + dir * (p - o).dot(dir)


## Куда плыть без света: внутри облака — стоять на месте (ход задают рывки к краю), снаружи — к ближней точке облака.
static func home_point(c: int, p: Vector3) -> Vector3:
	var o := cloud_center(c)
	var flat := Vector2(p.x - o.x, p.z - o.z)
	var y := clampf(p.y, CEIL_LOW, CEIL_HIGH)
	if flat.length() <= R:
		return Vector3(p.x, y, p.z)
	var e := flat.normalized() * R
	return Vector3(o.x + e.x, y, o.z + e.y)
