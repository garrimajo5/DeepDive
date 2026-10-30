class_name EcoDome
extends EcoSystem
## Купольник — рабочий Хранителя у террасы врат 07 (#837, часть 1; концепт ART-081 — `docs/concept-art/kupolnik.md`,
## мир — `docs/world.md`, раздел 5). Не вид бестиария: в сканер и на сонар не попадает, на прожектор не реагирует,
## к кораблю не тянется. Один на слой: ждёт в нише за правой опорой арки (`HOME`), пока корабль не подойдёт к
## террасе (`CALL_R`), — короткий импульс фотофоров (команда Хранителя), подплывает сифонами к первому контактному
## гнезду `GateDiag.nest_pos(NEST)` с подхода (+Z), клип `OpenPetal` (5 с): поднимает створку по направляющей,
## отпускает, разворачивается и уходит обратно в нишу — и больше не выходит. Створка остаётся открытой (`petal`).
## Корабль на пути (ближе `KEEP`) — купольник стоит и ждёт, пока его пропустят. Диагностика от него не зависит
## (`GateDiag`): игрок может купольника пропустить. Здесь — числа и шаг без узлов, детерминированно (случая нет).
## «Створка открыта» — флаг `opened`, `just_opened` на шаг и событие `EcoLink.PETAL` (#837, часть 2). Створка уже
## открыта в кампании (`ShipState.petal_open`) — купольник в нише не ждёт: ушёл, створка поднята, события нет.
## Вид по модели MOD-022 — дальше.

const ID := "dome"
## Ниша (x, z) — смещение от середины террасы `EcoGate.CENTER`: за правой опорой, к северо-востоку, вне прохода.
const HOME_OFF := Vector2(70.0, -40.0)
## Гнездо, которое открывает (номер в `GateDiag.NESTS`), и где встаёт: перед ним с подхода (+Z) на FRONT м,
## на AT_NEST м над дном (купол 1,2 м — захват на уровне гнезда).
const NEST := 0
const FRONT := 1.6
const AT_NEST := 0.9
## Корабль ближе этого к середине террасы (м по горизонтали) — купольник выходит.
const CALL_R := 80.0
## Ход, м/с: к гнезду и обратно; поворот — рад/с (разница клапанов сифонов).
const SWIM := 0.8
const LEAVE := 1.2
const TURN := 0.7
## Разгон и торможение, м/с² (Б3): трогается за ~1,6 с, встаёт перед кораблём за ~0,5 с; ближе SLOW_R м к цели
## сбавляет ход (не меньше доли SLOW_MIN), а не врезается в гнездо или нишу с полного хода.
const ACCEL := 0.5
const BRAKE := 1.6
const SLOW_R := 2.0
const SLOW_MIN := 0.15
## Высота над дном в пути, м; к гнезду опускается на последних DESCEND м.
const CRUISE := 2.5
const DESCEND := 6.0
## Ближе этого (м) — пришёл.
const ARRIVE := 0.3
## Корабль (центр) ближе этого — купольник стоит (корпус 32 м: половина + запас).
const KEEP := 22.0
## Клип OpenPetal: длина, когда створка начинает и кончает подниматься (с от начала).
const OPEN_TIME := 5.0
const LIFT := Vector2(1.2, 3.8)
## Фотофоры: свечение в покое и импульс команды (сила, длина, с).
const GLOW_REST := 0.15
const PULSE := 0.8
const PULSE_TIME := 0.6
## Строка на приборы, когда створка поднята (черновик; финальные строки — сюжет, TXT-001 #853).
const PETAL_TEXT := "Терраса 07: рабочий открыл створку гнезда и ушёл"

enum State { WAIT, GO, OPEN, BACK, GONE }

var state := State.WAIT
var pos := Vector3.ZERO
var yaw := 0.0             ## нос в (−sin yaw, 0, −cos yaw), как у корабля
var speed := 0.0
var petal := 0.0           ## створка 0 — закрыта, 1 — поднята на 1,4 м
var opened := false        ## створка открыта (раз за слой)
var just_opened := false   ## открылась в этот шаг
var glow := GLOW_REST
var t := 0.0               ## время в состоянии, с
var _pulse := -INF         ## время мира начала импульса
var ground: Callable


func reset(world: EcoWorld) -> void:
	ground = world.ground
	state = State.WAIT
	petal = 0.0
	opened = false
	just_opened = false
	t = 0.0
	_pulse = -INF
	speed = 0.0
	var h := home()
	pos = Vector3(h.x, floor_y(h.x, h.y) + AT_NEST, h.y)
	var s := stand()
	yaw = _yaw_to(Vector2(s.x - pos.x, s.z - pos.z))


## Ниша на карте (x, z).
static func home() -> Vector2:
	return EcoGate.CENTER + HOME_OFF


## Где стоит у гнезда: перед ним с подхода, над дном.
func stand() -> Vector3:
	var n := GateDiag.nest_pos(NEST)
	var x := n.x
	var z := n.z + FRONT
	return Vector3(x, floor_y(x, z) + AT_NEST, z)


func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else Seabed.height(x, z)


## Клип для вида: Idle, Swim или OpenPetal.
func clip() -> String:
	match state:
		State.OPEN:
			return "OpenPetal"
		State.GO, State.BACK:
			return "Swim" if speed > 0.05 else "Idle"
	return "Idle"


## Виден ли (в нише после ухода — нет).
func shown() -> bool:
	return state != State.GONE


func step(world: EcoWorld, dt: float) -> void:
	just_opened = false
	t += dt
	var sp := world.ship.pos
	if world.ship.petal_open and state == State.WAIT:
		_done()
	match state:
		State.WAIT:
			if Vector2(sp.x, sp.z).distance_to(EcoGate.CENTER) < CALL_R:
				_go(State.GO, world)
		State.GO:
			if _swim(stand(), SWIM, sp, dt):
				_go(State.OPEN, world)
		State.OPEN:
			speed = 0.0
			petal = maxf(petal, HashNoise.smooth(LIFT.x, LIFT.y, t))
			if t >= LIFT.y and not opened:
				opened = true
				just_opened = true
				world.send(EcoLink.petal(NEST, PETAL_TEXT))
			if t >= OPEN_TIME:
				_go(State.BACK, world)
		State.BACK:
			var h := home()
			if _swim(Vector3(h.x, floor_y(h.x, h.y) + AT_NEST, h.y), LEAVE, sp, dt):
				_go(State.GONE, world)
				speed = 0.0
	var k := (world.time - _pulse) / PULSE_TIME
	glow = GLOW_REST + (PULSE - GLOW_REST) * (sin(PI * k) if k >= 0.0 and k <= 1.0 else 0.0)


## Створка открыта раньше (сохранение кампании): ушёл, створка поднята.
func _done() -> void:
	state = State.GONE
	petal = 1.0
	opened = true
	speed = 0.0
	var h := home()
	pos = Vector3(h.x, floor_y(h.x, h.y) + AT_NEST, h.y)


func _go(s: State, world: EcoWorld) -> void:
	state = s
	t = 0.0
	if s == State.GO:
		_pulse = world.time   # команда Хранителя — выход к гнезду


## Шаг пути к цели: поворот носом к ней, ход только почти носом вперёд, высота — над дном (последние DESCEND м —
## к высоте цели). Корабль
## ближе KEEP — стоит. true — пришёл.
func _swim(goal: Vector3, top: float, ship: Vector3, dt: float) -> bool:
	var d := Vector2(goal.x - pos.x, goal.z - pos.z)
	var dist := d.length()
	if dist < ARRIVE and absf(goal.y - pos.y) < ARRIVE:
		pos = goal
		return true
	var want := _yaw_to(d) if dist > 1e-4 else yaw
	yaw += clampf(wrapf(want - yaw, -PI, PI), -TURN * dt, TURN * dt)
	var face := cos(wrapf(want - yaw, -PI, PI))
	var blocked := pos.distance_to(ship) < KEEP
	var want_v := want_speed(top, face, dist, blocked)
	speed = move_toward(speed, want_v, (ACCEL if want_v > speed else BRAKE) * dt)
	var go := minf(speed * dt, dist)
	if dist > 1e-4:
		pos.x += d.x / dist * go
		pos.z += d.y / dist * go
	var low := goal.y if dist < DESCEND else floor_y(pos.x, pos.z) + CRUISE
	pos.y = move_toward(pos.y, maxf(low, floor_y(pos.x, pos.z) + AT_NEST * 0.5), top * 0.6 * dt if not blocked else 0.0)
	return false


## Ход, к которому тянется: почти носом вперёд (доля cos угла), у цели — тише, корабль на пути — стоп.
static func want_speed(top: float, face: float, dist: float, blocked: bool) -> float:
	if blocked:
		return 0.0
	return top * clampf(face, 0.0, 1.0) * clampf(dist / SLOW_R, SLOW_MIN, 1.0)


## Курс носом по направлению d (x, z) на карте.
static func _yaw_to(d: Vector2) -> float:
	return atan2(-d.x, -d.y)
