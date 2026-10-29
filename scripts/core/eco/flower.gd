class_name EcoFlower
extends EcoSystem
## Каменный цветок — место 1 карты отмели (karta-otmeli-mesta.json, js/world.js «Каменный цветок»): коралл-исполин
## по концепту ART-027 (`docs/concept-art/kamennyy-tsvetok.md`). Чаша, как иконка места: из каменного цоколя
## (Ø 8 м, 1,5 м, 10 трубочек) поднимается ствол Ø 3,5 м, от него три главные ветви, каждая четыре раза делится
## вилкой надвое (3 → 6 → 12 → 24 → 48): внутренняя ветвь вилки идёт круче вверх, наружная — шире и ниже, поэтому
## середина кроны выше краёв, а края загнуты вверх. На концах — 48 вытянутых светящихся кончиков. Своё зерно (форма
## одна при любом зерне мира), высота подгоняется ровно к 28 м, крона — не шире Ø 26 м (рядом логово стеклоуста
## и огнецвет). Кончики мерцают волной снизу вверх: период 6 с, от нижних к верхним за 2 с, яркость 15…100 % (одна
## формула здесь и в шейдере FlowerView). Громкий импульс сонара рядом гасит все кончики (`light`), подержав темноту,
## цветок разгорается снова (#834, «читаемая встреча» у 01). Столкновение корабля — `solid`, подключить — поток А.

const ID := "flower"
## Подножие на карте отмели (karta-otmeli-mesta.json, место 1) — та же точка, что Run.PLACES["flower"].
const CENTER := Vector2(40.0, -50.0)
## Высота до верхнего кончика вместе с цоколем, м (ART-027; js: obstacle top = p.y + 28).
const HEIGHT := 28.0
## Крона не шире этого радиуса от оси, м (ART-027: Ø 26 м).
const SPREAD := 13.0
## Ствол уходит в дно, м (чтобы не висел на склоне).
const SINK := 1.0
## Ствол: радиус у дна (Ø 3,5 м) и у первой вилки, высота первой вилки до подгонки, м.
const TRUNK_R := 1.75
const TRUNK_R1 := 1.25
const TRUNK_H := 6.5
## Главных ветвей и уровней вилок (ART-027: 3 ветви × 4 вилки = 48 кончиков).
const BOUGHS := 3
const FORKS := 4
## Главная ветвь: длина и радиус в начале; у каждой следующей — длина × LEN_K, радиус × RAD_K.
const BOUGH_LEN := 6.0
const BOUGH_R := 1.3
const LEN_K := 0.8
const RAD_K := 0.78
## Наклон главной ветви от вертикали; в вилке внутренняя отходит к оси на FORK_IN, наружная — от оси на FORK_OUT
## (рад); ветви загибаются вверх тем сильнее, чем выше ярус (CURL на последнем).
const BOUGH_TILT := 0.8
const FORK_IN := 0.25
const FORK_OUT := 0.7
const CURL := 0.3
## Ветвь поднимается не положе этого (синус угла к горизонту).
const MIN_UP := 0.25
## Кончик — вытянутый многогранник: половина длины и толщина к ней. По пропорциям листа ART-027 (кончик с треть
## шага вилки): в заметке 0,45–0,8 м — с 100 м такой не виден.
const TIP_HALF := 1.3
const TIP_WIDTH := 0.6
## Цоколь: радиус, высота, камней; трубочки у цоколя (ART-027: 8–12 грубых выступов).
const PLINTH_R := 4.0
const PLINTH_H := 1.5
const STONES := 9
const TUBES := 10
## Своё зерно формы.
const SEED := 1295
## Мерцание кончиков (ART-027): период 6 с — скорость (рад/с), волна от нижних к верхним за 2 с — сдвиг фазы
## на всю высоту кроны, яркость 15…100 % — середина и размах.
const GLOW_RATE := TAU / 6.0
const GLOW_WAVE := GLOW_RATE * 2.0
const GLOW_MID := 0.575
const GLOW_AMP := 0.425
## Импульс сонара ближе PING_R к середине кроны (на HEIGHT/2 над подножием) гасит кончики до DARK_LIGHT; темнота
## держится DARK_HOLD с, потом свет возвращается за RELIGHT_TIME с (#834). Сообщение — не чаще MSG_CD с.
const PING_R := 60.0
const DARK_LIGHT := 0.1
const DARK_HOLD := 4.0
const RELIGHT_TIME := 20.0
const MSG_CD := 60.0
const MSG_DARK := "Каменный цветок гасит огни после импульса сонара — в тишине разгорится снова"


## Ветвь — усечённый конус от p0 (радиус r0) к p1 (r1); depth — ярус (0 — ствол).
class Branch:
	extends RefCounted
	var p0 := Vector3.ZERO
	var p1 := Vector3.ZERO
	var r0 := 0.0
	var r1 := 0.0
	var depth := 0


## Камень цоколя — шестигранная призма: низ в c, радиус r, высота h, поворот turn.
class Stone:
	extends RefCounted
	var c := Vector3.ZERO
	var r := 0.0
	var h := 0.0
	var turn := 0.0


## Ствол (depth 0) и ветви (depth 1 — главные … FORKS + 1 — последние, с кончиками).
var branches: Array[Branch] = []
## Кончики: центр, направление (вдоль ветви, к концу), половина длины, фаза мерцания.
var tips := PackedVector3Array()
var tip_dir := PackedVector3Array()
var tip_r := PackedFloat32Array()
var tip_phase := PackedFloat32Array()
## Цоколь: камни и трубочки (depth −1).
var stones: Array[Stone] = []
var tubes: Array[Branch] = []
## Подножие на дне.
var base := Vector3.ZERO
## Высота дна (мир передаёт при сбросе; без дна — ровно −40 м).
var ground: Callable
## Зерно формы (SEED; своё — для подбора формы).
var shape_seed := SEED
## Доля света кончиков: 1 — горят (мерцают по glow), DARK_LIGHT — погасли после импульса.
var light := 1.0
## Секунд темноты до того, как свет начнёт возвращаться.
var dark_t := 0.0
## Секунд до следующего сообщения.
var msg_cd := 0.0

var _center: Vector2


## center — своё место (для тестов), по умолчанию — с карты отмели.
func _init(center: Vector2 = CENTER) -> void:
	_center = center


func reset(world: EcoWorld) -> void:
	ground = world.ground
	base = Vector3(_center.x, floor_y(_center.x, _center.y), _center.y)
	light = 1.0
	dark_t = 0.0
	msg_cd = 0.0
	_grow()


## Середина кроны — от неё меряется громкость импульса.
func heart() -> Vector3:
	return base + Vector3(0, HEIGHT * 0.5, 0)


func on_ping(world: EcoWorld, pos: Vector3) -> void:
	if pos.distance_to(heart()) >= PING_R:
		return
	var was := light
	light = DARK_LIGHT
	dark_t = DARK_HOLD
	if was > 0.5 and msg_cd <= 0.0:
		msg_cd = MSG_CD
		world.send(EcoLink.message(MSG_DARK))


func step(_world: EcoWorld, dt: float) -> void:
	msg_cd -= dt
	if dark_t > 0.0:
		dark_t -= dt
		return
	light = minf(1.0, light + dt * (1.0 - DARK_LIGHT) / RELIGHT_TIME)


## Дно под (x, z): мир передаёт Seabed.height; без него — −40 м.
func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else -40.0


## Конец кончика i (дальний от ветви).
func tip_end(i: int) -> Vector3:
	return tips[i] + tip_dir[i] * tip_r[i]


## Верхний кончик (для проверок и камеры).
func top() -> Vector3:
	var best := base
	for i in tips.size():
		if tip_end(i).y > best.y:
			best = tip_end(i)
	return best


func _grow() -> void:
	branches.clear()
	tips.clear()
	tip_dir.clear()
	tip_r.clear()
	tip_phase.clear()
	stones.clear()
	tubes.clear()
	var rnd := EcoRandom.new(shape_seed)
	var trunk := Branch.new()
	trunk.p1 = Vector3(0, TRUNK_H, 0)
	trunk.r0 = TRUNK_R
	trunk.r1 = TRUNK_R1
	branches.append(trunk)
	var az0 := rnd.range_f(0.0, TAU)
	for i in BOUGHS:
		var az := az0 + TAU * i / BOUGHS + rnd.range_f(-0.15, 0.15)
		var out := Vector3(cos(az), 0, sin(az))
		var dir := Vector3.UP * cos(BOUGH_TILT) + out * sin(BOUGH_TILT)
		_bough(rnd, trunk.p1 - Vector3(0, TRUNK_R1 * 0.5, 0) + out * TRUNK_R1 * 0.4, dir, BOUGH_LEN, BOUGH_R, 1)
	# подгонка: верхний конец кончика ровно на HEIGHT над дном (ствол заглублён на SINK), крона — ровно в SPREAD
	var hi := 0.0
	for i in tips.size():
		hi = maxf(hi, tip_end(i).y)
	var k := (HEIGHT + SINK) / hi
	# раздвинуть или сжать вбок: даль от оси × k × kx + толщина × k ≤ SPREAD для каждого кончика и конца ветви
	var kx := INF
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
	branches[0].r0 = TRUNK_R   # ствол у дна — ровно Ø 3,5 м при любой подгонке
	var y_lo := INF
	var y_hi := -INF
	for i in tips.size():
		tips[i] = base + lift + _fit(tips[i], k, kx)
		tip_r[i] *= k
		y_lo = minf(y_lo, tips[i].y)
		y_hi = maxf(y_hi, tips[i].y)
	# волна мерцания идёт снизу вверх: верхние кончики отстают на GLOW_WAVE (2 с), плюс свой сдвиг
	for i in tips.size():
		tip_phase[i] = -(tips[i].y - y_lo) / maxf(y_hi - y_lo, 1e-3) * GLOW_WAVE + rnd.range_f(-0.15, 0.15)
	_plinth(rnd)


static func _squeeze(dist: float, r: float, k: float) -> float:
	return INF if dist < 1e-6 else (SPREAD - r * k) / (dist * k)


static func _fit(p: Vector3, k: float, kx: float) -> Vector3:
	return Vector3(p.x * k * kx, p.y * k, p.z * k * kx)


## Ветвь от from по dir; на конце — вилка надвое (пока есть уровни) или кончик. В вилке внутренняя ветвь отходит
## к оси цветка (круче вверх), наружная — от оси (шире и ниже); обе повёрнуты вокруг родителя на свой угол
## и загнуты вверх — середина кроны выше краёв, края чаши смотрят вверх.
func _bough(rnd: EcoRandom, from: Vector3, dir: Vector3, length: float, rad: float, level: int) -> void:
	var b := Branch.new()
	b.p0 = from
	b.p1 = from + dir * length
	b.r0 = rad
	b.r1 = rad * RAD_K
	b.depth = level
	branches.append(b)
	if level > FORKS:
		var t := dir.lerp(Vector3.UP, 0.3).normalized()
		tips.append(b.p1 + t * TIP_HALF * 0.75)
		tip_dir.append(t)
		tip_r.append(TIP_HALF)
		tip_phase.append(0.0)
		return
	var out := Vector3(b.p1.x, 0, b.p1.z)
	if out.length_squared() < 1e-6:
		out = Vector3(dir.x, 0, dir.z)
	var ax := dir.cross(out.normalized())
	if ax.length_squared() < 1e-6:
		ax = dir.cross(Vector3.RIGHT)
	ax = ax.normalized()
	var twist := rnd.range_f(-0.45, 0.45)
	var kids := [dir.rotated(ax, -FORK_IN * rnd.range_f(0.8, 1.2)), dir.rotated(ax, FORK_OUT * rnd.range_f(0.8, 1.2))]
	for v: Vector3 in kids:
		var nd := v.rotated(dir, twist).lerp(Vector3.UP, CURL * level / FORKS).normalized()
		if nd.y < MIN_UP:   # не ниже MIN_UP: ветви не свисают, края чаши смотрят вверх
			nd = Vector3(nd.x, 0, nd.z).normalized() * sqrt(1.0 - MIN_UP * MIN_UP) + Vector3.UP * MIN_UP
		_bough(rnd, b.p1, nd, length * LEN_K * rnd.range_f(0.9, 1.1), b.r1, level + 1)


## Цоколь вокруг ствола: камни-призмы и трубочки, низ уходит в дно (после подгонки — в метрах как есть).
func _plinth(rnd: EcoRandom) -> void:
	for i in STONES:
		var st := Stone.new()
		var a := TAU * i / STONES + rnd.range_f(-0.25, 0.25)
		st.r = rnd.range_f(0.9, 1.4)
		var d := rnd.range_f(1.4, PLINTH_R - st.r)
		st.c = Vector3(base.x + cos(a) * d, 0, base.z + sin(a) * d)
		st.c.y = floor_y(st.c.x, st.c.z) - 0.5
		st.h = rnd.range_f(PLINTH_H * 0.6, PLINTH_H) + 0.5
		st.turn = rnd.range_f(0.0, TAU)
		stones.append(st)
	for i in TUBES:
		var t := Branch.new()
		var a := TAU * (i + 0.5) / TUBES + rnd.range_f(-0.2, 0.2)
		var d := rnd.range_f(2.2, PLINTH_R - 0.4)
		t.p0 = Vector3(base.x + cos(a) * d, 0, base.z + sin(a) * d)
		t.p0.y = floor_y(t.p0.x, t.p0.z) - 0.3
		var lean := Vector3(cos(a), 0, sin(a)) * rnd.range_f(0.0, 0.25)
		t.p1 = t.p0 + (Vector3.UP + lean).normalized() * rnd.range_f(1.4, 3.0)
		t.r0 = rnd.range_f(0.22, 0.36)
		t.r1 = t.r0 * 0.9
		t.depth = -1
		tubes.append(t)


## Свет кончика с фазой ph в момент t (GLOW_MID ± GLOW_AMP, 15…100 %) — та же формула в шейдере FlowerView.
static func glow(ph: float, t: float) -> float:
	return GLOW_MID + GLOW_AMP * sin(t * GLOW_RATE + ph)


static func _in_cone(p: Vector3, b: Branch) -> bool:
	var ab := b.p1 - b.p0
	var t := clampf((p - b.p0).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(b.p0 + ab * t) < lerpf(b.r0, b.r1, t)


## Точка (в мире) внутри ствола, ветви, кончика или цоколя — для существ и столкновения корабля (подключает поток А).
func solid(p: Vector3) -> bool:
	if p.y < base.y - SINK or p.y > base.y + HEIGHT + 2.0:
		return false
	if Vector2(p.x - base.x, p.z - base.z).length() > SPREAD + 2.0:
		return false
	for b in branches:
		if _in_cone(p, b):
			return true
	for i in tips.size():
		var ax := tip_dir[i] * tip_r[i]
		var t := clampf((p - tips[i]).dot(ax) / ax.length_squared(), -1.0, 1.0)
		if p.distance_to(tips[i] + ax * t) < tip_r[i] * TIP_WIDTH * (1.0 - absf(t) * 0.5):
			return true
	for t in tubes:
		if _in_cone(p, t):
			return true
	for st in stones:
		if p.y >= st.c.y and p.y <= st.c.y + st.h and Vector2(p.x - st.c.x, p.z - st.c.z).length() < st.r:
			return true
	return false
