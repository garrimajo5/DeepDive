class_name EcoShell
extends EcoSystem
## Раковина древних — место 3 карты отмели (js/world.js «Раковина древних», karta-otmeli-mesta.json): спиральная
## постройка Складчатых из незнакомого материала, на витках светятся кольца знаков (docs/world.md — выращенные
## раковины). Форма из браузера: 70 шаров вдоль логарифмической спирали (угол i·0,28, радиус 0,35·e^(0,085·угол),
## центр на 2,2 радиуса от оси), спираль стоит торцом; на лицевой стороне — 5 колец знаков (радиус 1,2 + 1,1·k,
## чуть впереди витков), они загораются по очереди от середины наружу: 0,25 + 0,75·max(0, sin(1,5·t − 0,8·k)) — одна
## формула здесь и в шейдере ShellView. Группа × 1,4, поднята на 3 м и наклонена (0,35; поворот; 0,2) — нижние витки
## уходят в дно. Поворот свой (не случайный, как в браузере): кольца смотрят на старт забега (0; 0), откуда приходит
## корабль. Концепта художника пока нет. Столкновение корабля — `solid`, подключить — поток А.

const ID := "shell"
## Точка на карте отмели (karta-otmeli-mesta.json, место 3) — та же, что Run.PLACES["shell"].
const CENTER := Vector2(162.0, -36.0)
## Спираль из браузера: шаров, шаг угла, радиус и рост, вынос от оси, раздутие шара, дрожь по толщине.
const COILS := 70
const STEP := 0.28
const R0 := 0.35
const GROW := 0.085
const ARM := 2.2
const PUFF := 1.05
const WOBBLE := 0.05
## Кольца знаков: число, радиус первого и шаг, толщина, вынос вперёд первого и шаг.
const RINGS := 5
const RING_R0 := 1.2
const RING_STEP := 1.1
const RING_TUBE := 0.05
const RING_Z0 := 1.2
const RING_ZSTEP := 0.15
## Свет колец: 0,25 + 0,75·max(0, sin(RATE·t − WAVE·k)).
const GLOW_LOW := 0.25
const GLOW_RATE := 1.5
const GLOW_WAVE := 0.8
## Масштаб группы, подъём над дном, наклон вокруг X и Z (js grp.rotation.set(0,35, …, 0,2)).
const SCALE := 1.4
const LIFT := 3.0
const TILT_X := 0.35
const TILT_Z := 0.2
## Препятствие браузера: радиус и высота над дном, м (js W.obstacles r 9, top p.y + 12).
const OBSTACLE_R := 9.0
const OBSTACLE_TOP := 12.0
## Куда смотрят кольца (старт забега).
const FACE := Vector2(0.0, 0.0)

## Шары спирали в мире: центр и радиус; шаг i — от середины спирали наружу.
var coils := PackedVector3Array()
var coil_r := PackedFloat32Array()
## Кольца знаков в мире: центр, ось (нормаль лицевой стороны) и радиус; толщина — RING_TUBE · SCALE.
var ring_c := PackedVector3Array()
var ring_r := PackedFloat32Array()
## Подножие на дне и поворот группы (локальная +Z — лицевая сторона с кольцами).
var base := Vector3.ZERO
var basis := Basis.IDENTITY
## Высота дна (мир передаёт при сбросе; без дна — ровно −40 м).
var ground: Callable

var _center: Vector2


## center — своё место (для тестов), по умолчанию — с карты отмели.
func _init(center: Vector2 = CENTER) -> void:
	_center = center


func reset(world: EcoWorld) -> void:
	ground = world.ground
	base = Vector3(_center.x, floor_y(_center.x, _center.y), _center.y)
	_build()


## Дно под (x, z): мир передаёт Seabed.height; без него — −40 м.
func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else -40.0


## Поворот группы: js Euler XYZ (матрица Rx · Ry · Rz), поворот вокруг Y — лицом к FACE.
static func make_basis(center: Vector2) -> Basis:
	var to := FACE - center
	var yaw := atan2(to.x, to.y)   # локальная +Z после поворота Y смотрит в (sin yaw; cos yaw)
	return Basis(Vector3.RIGHT, TILT_X) * Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, TILT_Z)


## Точка группы (в осях раковины до масштаба) в мир.
func to_world(local: Vector3) -> Vector3:
	return base + Vector3(0, LIFT, 0) + basis * (local * SCALE)


## Точка мира в оси раковины (до масштаба).
func to_local(p: Vector3) -> Vector3:
	return (basis.inverse() * (p - base - Vector3(0, LIFT, 0))) / SCALE


## Ось колец в мире (нормаль лицевой стороны).
func face() -> Vector3:
	return basis * Vector3.BACK


func _build() -> void:
	basis = make_basis(_center)
	coils.clear()
	coil_r.clear()
	for i in COILS:
		var a := i * STEP
		var r := R0 * exp(GROW * a)
		coils.append(to_world(Vector3(cos(a) * r * ARM, sin(a) * r * ARM, sin(i * 0.5) * WOBBLE)))
		coil_r.append(r * PUFF * SCALE)
	ring_c.clear()
	ring_r.clear()
	for k in RINGS:
		ring_c.append(to_world(Vector3(0, 0, RING_Z0 + k * RING_ZSTEP)))
		ring_r.append((RING_R0 + k * RING_STEP) * SCALE)


## Свет кольца k в момент t (GLOW_LOW…1) — та же формула в шейдере ShellView.
static func glow(k: int, t: float) -> float:
	return GLOW_LOW + (1.0 - GLOW_LOW) * maxf(0.0, sin(t * GLOW_RATE - k * GLOW_WAVE))


## Верхняя точка витков (для проверок и камеры).
func top() -> Vector3:
	var best := base
	for i in coils.size():
		if coils[i].y + coil_r[i] > best.y:
			best = coils[i] + Vector3(0, coil_r[i], 0)
	return best


## Точка (в мире) внутри витков — для существ и столкновения корабля (подключает поток А).
func solid(p: Vector3) -> bool:
	if p.y < base.y - 8.0 or p.y > base.y + OBSTACLE_TOP + 2.0:
		return false
	if Vector2(p.x - base.x, p.z - base.z).length() > OBSTACLE_R + 2.0:
		return false
	for i in coils.size():
		if p.distance_to(coils[i]) < coil_r[i]:
			return true
	return false
