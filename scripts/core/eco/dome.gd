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
## Путь ниша → гнездо (смещения от `EcoGate.CENTER`, #1757): гнёзда на полу кармана перед правой опорой
## (`Seabed.Layer.nest_pocket`), прямая из ниши шла сквозь опору (`GateArch.SHAPE`) и восточную рощу `EcoGate.KELP`.
## Обход: с запада от рощи, вдоль восточного края основания опоры (x 60) — вниз по северному склону кармана, к гнезду
## по полу с подхода (+Z). Точку пути проходит, не останавливаясь, ближе WAY_R; назад — тем же путём в обратном
## порядке. Последняя точка — перед лицом опоры: гнездо на любом месте лица (dz +11,5…13) достижимо по полу. После
## неё — подход к месту у гнезда с +Z (`APPROACH` м перед ним): к гнезду не сбоку по склону, а прямо, на уровне.
const WAY: Array[Vector2] = [Vector2(52.0, -28.0), Vector2(63.0, -4.0), Vector2(63.0, 20.0)]
const WAY_R := 3.0
const APPROACH := 10.0
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
## Поворот с инерцией (Б3): скорость поворота меняется не быстрее TURN_ACCEL рад/с² (клапаны сифонов не
## перекладываются за миг), у курса — не больше TURN_GAIN × остаток и того, с какой можно встать вполсилы торможения,
## — доворачивает без перелёта и не трогается рывком на полные TURN рад/с.
const TURN_ACCEL := 0.6
const TURN_GAIN := 3.0
## Разгон и торможение, м/с² (Б3): трогается за ~1,6 с, встаёт перед кораблём за ~0,5 с; ближе SLOW_R м к цели
## сбавляет ход (не меньше доли SLOW_MIN), а не врезается в гнездо или нишу с полного хода.
const ACCEL := 0.5
const BRAKE := 1.6
const SLOW_R := 2.0
const SLOW_MIN := 0.15
## Высота над дном в пути, м; к гнезду опускается на последних DESCEND м.
const CRUISE := 2.5
const DESCEND := 6.0
## Ближе этого (м) — пришёл; остаток до места у гнезда доходит в OPEN ходом SETTLE м/с (≈ 1 с, до подъёма
## створки LIFT.x), а не переставляется разом (Б3: раньше прыжок до 0,3 м за шаг).
const ARRIVE := 0.3
const SETTLE := 0.25
## Корабль (центр) ближе этого — купольник стоит (корпус 32 м: половина + запас).
const KEEP := 22.0
## Корпус не проходит сквозь купольника (Б3): KEEP меряет от центра корабля, а корма — до 29 м от него, и корабль,
## прошедший над ним в пути (днище ниже купола на CRUISE), шёл сквозь тело. Обшивка, раздутая на HULL_R м (купол
## 1,2 м), отодвигает его (`_clear_hull`) — не ниже половины AT_NEST над дном; корабль ушёл — продолжает своё дело.
const HULL_R := 0.6
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
var turn_v := 0.0          ## скорость поворота, рад/с (+ — влево)
var petal := 0.0           ## створка 0 — закрыта, 1 — поднята на 1,4 м
var opened := false        ## створка открыта (раз за слой)
var just_opened := false   ## открылась в этот шаг
var glow := GLOW_REST
var t := 0.0               ## время в состоянии, с
var leg := 0               ## следующая точка пути `point` (к гнезду — вверх по номеру, назад — вниз)
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
	turn_v = 0.0
	leg = 0
	var h := home()
	pos = Vector3(h.x, floor_y(h.x, h.y) + AT_NEST, h.y)
	var w := way(0)
	yaw = _yaw_to(Vector2(w.x - pos.x, w.y - pos.z))


## Ниша на карте (x, z).
static func home() -> Vector2:
	return EcoGate.CENTER + HOME_OFF


## Точка пути i на карте (x, z).
static func way(i: int) -> Vector2:
	return EcoGate.CENTER + WAY[i]


## Точка пути i (x, z): 0…WAY.size() − 1 — `WAY`, WAY.size() — подход к гнезду.
func point(i: int) -> Vector2:
	if i < WAY.size():
		return way(i)
	var s := stand()
	return Vector2(s.x, s.z + APPROACH)


## Весь путь на карте: ниша, точки пути, место у гнезда (x, z).
func route() -> Array[Vector2]:
	var out: Array[Vector2] = [home()]
	for i in WAY.size() + 1:
		out.append(point(i))
	var s := stand()
	out.append(Vector2(s.x, s.z))
	return out


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
			if leg <= WAY.size():
				if _pass(leg, SWIM, sp, dt):
					leg += 1
			elif _swim(stand(), SWIM, sp, dt):
				_go(State.OPEN, world)
		State.OPEN:
			speed = 0.0
			turn_v = 0.0
			pos = pos.move_toward(stand(), SETTLE * dt)
			petal = maxf(petal, HashNoise.smooth(LIFT.x, LIFT.y, t))
			if t >= LIFT.y and not opened:
				opened = true
				just_opened = true
				world.send(EcoLink.petal(NEST, PETAL_TEXT))
			if t >= OPEN_TIME:
				_go(State.BACK, world)
		State.BACK:
			var h := home()
			if leg >= 0:
				if _pass(leg, LEAVE, sp, dt):
					leg -= 1
			elif _swim(Vector3(h.x, floor_y(h.x, h.y) + AT_NEST, h.y), LEAVE, sp, dt):
				_go(State.GONE, world)
				speed = 0.0
	if state != State.GONE:
		_clear_hull(world)
	var k := (world.time - _pulse) / PULSE_TIME
	glow = GLOW_REST + (PULSE - GLOW_REST) * (sin(PI * k) if k >= 0.0 and k <= 1.0 else 0.0)


## Тело внутри обшивки (раздутой на HULL_R) — наружу по горизонтали, на той же высоте: в сторону нормали обшивки
## (`EcoHull.push_out`) без её вертикали — нос толкает вперёд, борт вбок; под днищем (нормаль вниз) — вбок от оси
## корабля. До первого места снаружи шагом SIDE_STEP, уточнение пополам; ход гаснет — толкнули. Раньше `push_out` как
## есть вёз тело по обводу носа поверх корпуса — на 10 м вверх со скоростью 10 м/с: купол «ехал» на палубе.
const SLIP := 0.6
const SIDE_STEP := 0.25
const SIDE_MAX := 16.0


func _clear_hull(world: EcoWorld) -> void:
	var sp := world.ship.pos
	var yaw_s := world.ship.yaw
	var res := EcoHull.push_out(pos, sp, yaw_s, HULL_R)
	if res.is_empty():
		return
	var dir: Vector3 = res[0] - pos
	dir.y = 0.0
	if dir.length_squared() > 1e-6:
		dir = dir.normalized()
	var l := EcoHull.to_ship(pos, sp, yaw_s)
	dir = (dir + Vector3(1.0 if l.x >= 0.0 else -1.0, 0.0, 0.0).rotated(Vector3.UP, yaw_s) * SLIP).normalized()
	var inn := 0.0
	var out := 0.0
	while out < SIDE_MAX:
		out += SIDE_STEP
		if not EcoHull.touches(pos + dir * out, sp, yaw_s, HULL_R):
			break
		inn = out
	for i in 5:
		var mid := (inn + out) * 0.5
		if EcoHull.touches(pos + dir * mid, sp, yaw_s, HULL_R):
			inn = mid
		else:
			out = mid
	pos += dir * out
	pos.y = maxf(pos.y, floor_y(pos.x, pos.z) + AT_NEST * 0.5)
	speed = 0.0


## Сценарий тестера (шаг «dome», #1350): купольник уже у гнезда, клип OpenPetal идёт t с (0…OPEN_TIME) — створка
## поднята по LIFT на это время; дальше шаг сам доводит подъём, событие PETAL и уход в нишу. Раньше в прогоне он
## выходил на шаге у террасы 32f и открывал створку, пока корабль был у других мест, — клипов в отчёте не было.
func stage(t_open: float) -> void:
	state = State.OPEN
	t = clampf(t_open, 0.0, OPEN_TIME)
	opened = t >= LIFT.y
	just_opened = false
	petal = HashNoise.smooth(LIFT.x, LIFT.y, t)
	speed = 0.0
	turn_v = 0.0
	pos = stand()
	var n := GateDiag.nest_pos(NEST)
	yaw = _yaw_to(Vector2(n.x - pos.x, n.z - pos.z))


## Створка открыта раньше (сохранение кампании): ушёл, створка поднята.
func _done() -> void:
	state = State.GONE
	petal = 1.0
	opened = true
	speed = 0.0
	turn_v = 0.0
	var h := home()
	pos = Vector3(h.x, floor_y(h.x, h.y) + AT_NEST, h.y)


func _go(s: State, world: EcoWorld) -> void:
	state = s
	t = 0.0
	leg = WAY.size() if s == State.BACK else 0
	if s == State.GO:
		_pulse = world.time   # команда Хранителя — выход к гнезду


## Шаг к точке пути i — на высоте хода над дном; true — прошёл (ближе WAY_R по горизонтали).
func _pass(i: int, top: float, ship: Vector3, dt: float) -> bool:
	var w := point(i)
	if Vector2(pos.x, pos.z).distance_to(w) < WAY_R:
		return true
	_swim(Vector3(w.x, floor_y(w.x, w.y) + CRUISE, w.y), top, ship, dt)
	return false


## Дно впереди по ходу, м: высоту пути держит над самым высоким из них — подъём по склону кармана (0,95 м/м)
## начинает заранее, вертикаль (0,6 хода) успевает без упора в дно (#1757).
const LOOK: Array[float] = [3.0, 6.0, 9.0]


## Шаг пути к цели: поворот носом к ней, ход только почти носом вперёд, высота — над дном впереди (`LOOK`; последние
## DESCEND м — к высоте цели), не ниже AT_NEST/2 над дном. Корабль
## ближе KEEP — стоит. true — пришёл.
func _swim(goal: Vector3, top: float, ship: Vector3, dt: float) -> bool:
	var d := Vector2(goal.x - pos.x, goal.z - pos.z)
	var dist := d.length()
	if dist < ARRIVE and absf(goal.y - pos.y) < ARRIVE:
		turn_v = 0.0
		return true
	var want := _yaw_to(d) if dist > 1e-4 else yaw
	var r := turn(yaw, turn_v, want, dt)
	yaw = wrapf(r.x, -PI, PI)
	turn_v = r.y
	var face := cos(wrapf(want - yaw, -PI, PI))
	var blocked := pos.distance_to(ship) < KEEP
	var want_v := want_speed(top, face, dist, blocked)
	speed = move_toward(speed, want_v, (ACCEL if want_v > speed else BRAKE) * dt)
	var go := minf(speed * dt, dist)
	if dist > 1e-4:
		pos.x += d.x / dist * go
		pos.z += d.y / dist * go
	var low := goal.y
	if dist >= DESCEND:
		var top_floor := floor_y(pos.x, pos.z)
		for k in LOOK:
			if k < dist:
				top_floor = maxf(top_floor, floor_y(pos.x + d.x / dist * k, pos.z + d.y / dist * k))
		low = top_floor + CRUISE
	var bottom := floor_y(pos.x, pos.z) + AT_NEST * 0.5
	pos.y = maxf(move_toward(pos.y, maxf(low, bottom), top * 0.6 * dt if not blocked else 0.0), bottom)
	return false


## Шаг поворота: курс yaw со скоростью v догоняет want (по кругу, коротким путём) за dt → (новый курс, новая
## скорость). Скорость к курсу — не больше TURN, TURN_GAIN × остаток и √(TURN_ACCEL · остаток); меняется не быстрее
## TURN_ACCEL. Шаг, что перелетел бы курс, кончается в нём.
static func turn(yaw_now: float, v: float, want: float, dt: float) -> Vector2:
	var err := wrapf(want - yaw_now, -PI, PI)
	var reach := minf(TURN, minf(absf(err) * TURN_GAIN, sqrt(TURN_ACCEL * absf(err))))
	v = move_toward(v, signf(err) * reach, TURN_ACCEL * dt)
	var go := v * dt
	if err != 0.0 and signf(go) == signf(err) and absf(go) > absf(err):
		return Vector2(yaw_now + err, err / dt)
	return Vector2(yaw_now + go, v)


## Ход, к которому тянется: почти носом вперёд (доля cos угла), у цели — тише, корабль на пути — стоп.
static func want_speed(top: float, face: float, dist: float, blocked: bool) -> float:
	if blocked:
		return 0.0
	return top * clampf(face, 0.0, 1.0) * clampf(dist / SLOW_R, SLOW_MIN, 1.0)


## Курс носом по направлению d (x, z) на карте.
static func _yaw_to(d: Vector2) -> float:
	return atan2(-d.x, -d.y)
