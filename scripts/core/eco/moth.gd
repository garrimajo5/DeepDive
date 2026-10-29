class_name EcoMoth
extends RefCounted
## Ледяная моль у Светового колодца 05 (#836, часть 1; концепт ART-080 — `docs/concept-art/inevaya-bahroma-i-mol.md`):
## рачки 5 мм без своего свечения облаками под трещиной льда. Ход 0,03–0,10 м/с с рывками; прожектор их тянет —
## моль в луче (ближе дальности света и в конусе `CONE` от носа) плывёт к его оси, без света — обратно к своему облаку.
## Здесь — числа и шаг роя без узлов (`Swarm`), детерминированно от зерна; вид одним MultiMesh атласа
## `ledyanaya-mol-atlas.png`, запуск в мире и моль на стекле — следующие части #836.

const ID := "moth"
## Середина колодца (x, z) — `LayerMap.xz("05")`.
const WELL := Vector2(-170.0, -70.0)
## Облака под трещиной: смещение (x, z) от середины, радиус облака R, высота — от CEIL_LOW до CEIL_HIGH (лёд y = 0).
const CLOUDS: Array[Vector2] = [Vector2(-9.0, -4.0), Vector2(7.0, 5.0), Vector2(2.0, -11.0)]
const R := 4.5
const CEIL_HIGH := -2.5
const CEIL_LOW := -9.0
## В воде: «Обычно» и «Красиво» — 240, «Экономно» — 80 (60 и 16 на стекле — отдельной частью).
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


## Рой у колодца: положения рачков, их облако и таймер рывка.
class Swarm:
	extends RefCounted
	var pos := PackedVector3Array()
	var home := PackedInt32Array()
	var dash_in := PackedFloat32Array()
	var dash_t := PackedFloat32Array()
	var rng: EcoRandom

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

	## Шаг на dt с: к оси луча, если рачок в нём, иначе к своему облаку; скорость SLOW, во время рывка FAST.
	func step(ship: EcoLink.ShipState, dt: float) -> void:
		for i in pos.size():
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

	## Сколько рачков в луче прожектора.
	func in_beam(ship: EcoLink.ShipState) -> int:
		var n := 0
		for p in pos:
			if EcoMoth.lit(ship, p):
				n += 1
		return n


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
