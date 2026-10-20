class_name EcoFlower
extends EcoSystem
## Каменный цветок — место 1 карты отмели (js/world.js «Каменный цветок», karta-otmeli-mesta.json): коралл-исполин
## высотой с девятиэтажный дом (28 м) — ветвистый ствол, на концах ветвей светящиеся кончики, видные издалека.
## Форма — js branchCoral(4, 2,2, 0,55) × 3,1: ветвь делится на две-три (45 % — три), каждая короче в 0,62…0,82 раза
## и тоньше в 0,7, отклоняется вбок до ±0,9 и вверх на 0,1…0,6; на концах четвёртого яруса — кончики радиусом 1,6
## толщины ветви. Своё зерно (форма одна при любом зерне мира), высота подгоняется ровно к 28 м, крона — не шире
## SPREAD (рядом логово стеклоуста и огнецвет). Кончики мерцают волной снизу вверх (одна формула здесь и в шейдере
## FlowerView). Концепта художника пока нет — форма из браузера. Столкновение корабля — `solid`, подключить — поток А.

const ID := "flower"
## Подножие на карте отмели (karta-otmeli-mesta.json, место 1) — та же точка, что Run.PLACES["flower"].
const CENTER := Vector2(40.0, -50.0)
## Высота до верхнего кончика, м (js: obstacle top = p.y + 28).
const HEIGHT := 28.0
## Крона не шире этого радиуса от оси, м.
const SPREAD := 14.0
## Ствол уходит в дно, м (чтобы не висел на склоне).
const SINK := 1.0
## Ветвление из браузера: ярусов, длина и толщина ствола до подгонки, масштаб группы.
const DEPTH := 4
const LEN0 := 2.2
const RAD0 := 0.55
const SCALE := 3.1
## Своё зерно формы.
const SEED := 1295
## Мерцание кончиков: середина, размах, скорость (рад/с), сдвиг фазы на метр высоты (волна идёт вверх).
const GLOW_MID := 0.78
const GLOW_AMP := 0.22
const GLOW_RATE := 0.9
const GLOW_WAVE := 0.18


## Ветвь — усечённый конус от p0 (радиус r0) к p1 (r1); depth — ярус (0 — ствол).
class Branch:
	extends RefCounted
	var p0 := Vector3.ZERO
	var p1 := Vector3.ZERO
	var r0 := 0.0
	var r1 := 0.0
	var depth := 0


var branches: Array[Branch] = []
## Кончики: центр, радиус, фаза мерцания.
var tips := PackedVector3Array()
var tip_r := PackedFloat32Array()
var tip_phase := PackedFloat32Array()
## Подножие на дне.
var base := Vector3.ZERO
## Высота дна (мир передаёт при сбросе; без дна — ровно −40 м).
var ground: Callable
## Зерно формы (SEED; своё — для подбора формы).
var shape_seed := SEED

var _center: Vector2


## center — своё место (для тестов), по умолчанию — с карты отмели.
func _init(center: Vector2 = CENTER) -> void:
	_center = center


func reset(world: EcoWorld) -> void:
	ground = world.ground
	base = Vector3(_center.x, floor_y(_center.x, _center.y), _center.y)
	_grow()


## Дно под (x, z): мир передаёт Seabed.height; без него — −40 м.
func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else -40.0


## Верхний кончик (для проверок и камеры).
func top() -> Vector3:
	var best := base
	for i in tips.size():
		if tips[i].y + tip_r[i] > best.y:
			best = tips[i] + Vector3(0, tip_r[i], 0)
	return best


func _grow() -> void:
	branches.clear()
	tips.clear()
	tip_r.clear()
	tip_phase.clear()
	var rnd := EcoRandom.new(shape_seed)
	_branch(rnd, Vector3.ZERO, Vector3.UP, LEN0 * SCALE, RAD0 * SCALE, DEPTH, 0)
	# подгонка: верхний кончик ровно на HEIGHT над дном (ствол заглублён на SINK), крона не шире SPREAD
	var hi := 0.0
	for i in tips.size():
		hi = maxf(hi, tips[i].y + tip_r[i])
	var k := (HEIGHT + SINK) / hi
	# сжатие кроны вбок: даль от оси × k × kx + толщина × k ≤ SPREAD для каждого кончика и конца ветви
	var kx := 1.0
	for i in tips.size():
		kx = minf(kx, _squeeze(Vector2(tips[i].x, tips[i].z).length(), tip_r[i], k))
	for b in branches:
		kx = minf(kx, _squeeze(Vector2(b.p1.x, b.p1.z).length(), b.r1, k))
	var lift := Vector3(0, -SINK, 0)
	for b in branches:
		b.p0 = base + lift + _fit(b.p0, k, kx)
		b.p1 = base + lift + _fit(b.p1, k, kx)
		b.r0 *= k
		b.r1 *= k
	for i in tips.size():
		tips[i] = base + lift + _fit(tips[i], k, kx)
		tip_r[i] *= k
	# волна мерцания идёт снизу вверх: фаза — от высоты кончика и своего сдвига
	for i in tips.size():
		tip_phase[i] = -(tips[i].y - base.y) * GLOW_WAVE + rnd.range_f(-0.4, 0.4)


static func _squeeze(dist: float, r: float, k: float) -> float:
	return 1.0 if dist < 1e-6 else (SPREAD - r * k) / (dist * k)


static func _fit(p: Vector3, k: float, kx: float) -> Vector3:
	return Vector3(p.x * k * kx, p.y * k, p.z * k * kx)


## js branchCoral: ветвь от base по dir, на конце — две-три дочерних или кончик.
func _branch(rnd: EcoRandom, from: Vector3, dir: Vector3, length: float, rad: float, d: int, level: int) -> void:
	var b := Branch.new()
	b.p0 = from
	b.p1 = from + dir * length
	b.r0 = rad
	b.r1 = rad * 0.68
	b.depth = level
	branches.append(b)
	if d > 0:
		var n := 2 + (1 if rnd.next() < 0.45 else 0)
		for i in n:
			var nd := (dir + Vector3(rnd.range_f(-0.9, 0.9), rnd.range_f(0.1, 0.6), rnd.range_f(-0.9, 0.9))).normalized()
			_branch(rnd, b.p1, nd, length * rnd.range_f(0.62, 0.82), rad * 0.7, d - 1, level + 1)
	else:
		tips.append(b.p1)
		tip_r.append(rad * 1.6)
		tip_phase.append(0.0)


## Свет кончика с фазой ph в момент t (GLOW_MID ± GLOW_AMP) — та же формула в шейдере FlowerView.
static func glow(ph: float, t: float) -> float:
	return GLOW_MID + GLOW_AMP * sin(t * GLOW_RATE + ph)


## Точка (в мире) внутри ствола, ветви или кончика — для существ и столкновения корабля (подключает поток А).
func solid(p: Vector3) -> bool:
	if p.y < base.y - SINK or p.y > base.y + HEIGHT + 2.0:
		return false
	if Vector2(p.x - base.x, p.z - base.z).length() > SPREAD + 2.0:
		return false
	for b in branches:
		var ab := b.p1 - b.p0
		var t := clampf((p - b.p0).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(b.p0 + ab * t) < lerpf(b.r0, b.r1, t):
			return true
	for i in tips.size():
		if p.distance_to(tips[i]) < tip_r[i]:
			return true
	return false
