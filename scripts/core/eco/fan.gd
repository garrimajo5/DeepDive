class_name EcoFan
extends EcoSystem
## Веерники (fan в js/creatures.js: initFans, currentUpdate; ART-004): кружевные веера высотой 3 м в 7 м от каждого
## огнецвета и один у старта корабля. Плоскость веера всегда стоит поперёк течения (EcoCurrent) — по нему пилот
## читает, куда сносит корабль; когда течение меняется, веерники медленно разворачиваются следом и не крутятся
## без дела. Заметны сонару и сканеру. Сообщения: «стоит поперёк течения» рядом с кораблём (раз в 150 с),
## «разворачиваются — течение сменилось» (раз в 60 с, если веерник ближе 70 м). У Чёрного курильщика (EcoVent.FANS,
## #835) веера стоят к жерлу — вода у дна тянется к трубам; рядом с ними строка «повёрнут к жерлу» вместо «поперёк».

const ID := "fan"
## Веер в 7 м от подножия огнецвета под углом i · 2,1 + 2,6 и один у старта, чтобы его увидеть сразу (в браузере —
## (−6, 74); здесь на 4 м дальше: ближайшей целью сканера у старта остаётся стая светляков).
const FROM_CORAL := 7.0
const START := Vector2(-6, 70)
## Размер веера (м) и вершина над подножием (top в браузере).
const WIDTH := 2.6
const HEIGHT := 3.0
const TOP := 2.2
## Как быстро плоскость доворачивается к потоку (доля за секунду).
const TURN_RATE := 0.3
## Покачивание в потоке: наклон ±0,05 рад с частотой 0,9 рад/с.
const SWAY := 0.05
const SWAY_RATE := 0.9
const READ_R := 30.0
const READ_CD := 150.0
const TURN_R := 70.0
const TURN_CD := 60.0
## Строка у курильщика — свой отсчёт (не делит READ_CD со строкой «поперёк» у старта) и только после VENT_DWELL с
## у вееров: на входе в 45 м реактор сразу шлёт «Перегрев реактора» (Reactor.start_hot), строка приборов держится
## 4,2 с (Status.MESSAGE_SECONDS) — без задержки она перебивала строку веера (отчёт QA 2026-10-29-1515, #954).
const VENT_CD := 150.0
const VENT_DWELL := 5.0
const VENT_TEXT := "%s у курильщика повёрнут к жерлу — у дна вода тянется к трубам. Обходите сбоку"


## Один веерник.
class Fan:
	extends RefCounted
	var index := 0
	## Подножие на дне (на 5 см утоплено) и вершина.
	var pos := Vector3.ZERO
	var top := Vector3.ZERO
	## Плоскость веера смотрит в (sin yaw, 0, cos yaw) — навстречу потоку.
	var yaw := 0.0
	## Фаза покачивания.
	var phase := 0.0
	## Тяга к жерлу курильщика 0…1 (EcoFan.vent_pull): 1 — плоскость к жерлу, 0 — поперёк течения.
	var pull := 0.0
	## Курс к жерлу (плоскость смотрит на трубы), если pull > 0.
	var to_vent := 0.0


var fans: Array[Fan] = []
var current: EcoCurrent
var read_cd := 0.0
var turn_cd := 0.0
var vent_cd := 0.0
## Сколько секунд корабль подряд стоит у веера курильщика (ближе READ_R).
var vent_near := 0.0

var _spots: Array[Vector2]
var _turns := 0


## current — течение мира (подключено раньше); spots — свои места (для тестов), пусто — у огнецвета и у старта.
func _init(sea: EcoCurrent, spots: Array[Vector2] = []) -> void:
	current = sea
	_spots = spots.duplicate() if not spots.is_empty() else default_spots()


## Места из браузера: у каждого огнецвета и у старта (последний); между ними — два по бокам площадки 08 (EcoField),
## два у сходов с террасы врат 07 (EcoGate) и три у Чёрного курильщика 02 (EcoVent).
static func default_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in EcoCoral.BASES.size():
		var a := i * 2.1 + 2.6
		out.append(EcoCoral.BASES[i] + Vector2(cos(a), sin(a)) * FROM_CORAL)
	out.append_array(EcoField.FANS)
	out.append_array(EcoGate.FANS)
	out.append_array(EcoVent.FANS)
	out.append(START)
	return out


func reset(world: EcoWorld) -> void:
	fans.clear()
	read_cd = 0.0
	turn_cd = 0.0
	vent_cd = 0.0
	vent_near = 0.0
	_turns = current.turns
	for i in _spots.size():
		var f := Fan.new()
		f.index = i
		var xz := _spots[i]
		var y: float = world.ground.call(xz.x, xz.y) if world.ground.is_valid() else -40.0
		f.pos = Vector3(xz.x, y - 0.05, xz.y)
		f.top = f.pos + Vector3(0, TOP, 0)
		f.pull = vent_pull(xz)
		var to := EcoVent.CENTER - xz
		f.to_vent = atan2(to.x, to.y)
		f.yaw = aim(f, current.angle)
		f.phase = i * 1.3
		fans.append(f)


func step(world: EcoWorld, dt: float) -> void:
	var sp := world.ship.pos
	turn_cd -= dt
	read_cd -= dt
	if current.turns != _turns:
		_turns = current.turns
		if turn_cd <= 0.0 and _any_near(sp, TURN_R):
			turn_cd = TURN_CD
			world.emit(ID, "turn", sp, _text(world, "%s разворачивается следом за течением — оно сменилось"))
	for f in fans:
		var dy := wrapf(aim(f, current.angle) - f.yaw, -PI, PI)
		f.yaw += dy * minf(1.0, dt * TURN_RATE)
	vent_cd -= dt
	var near := _nearest(sp) if _any_near(sp, READ_R) else null
	if near and near.pull > 0.5:
		vent_near += dt
		if vent_near >= VENT_DWELL and vent_cd <= 0.0:
			vent_cd = VENT_CD
			world.emit(ID, "vent", sp, _text(world, VENT_TEXT))
		return
	vent_near = 0.0
	if read_cd <= 0.0 and near:
		read_cd = READ_CD
		world.emit(ID, "across", sp, _text(world, "%s стоит поперёк течения — по нему видно, куда несёт"))


## Тяга к жерлу курильщика в точке (x, z): 1 ближе EcoVent.PULL_IN, 0 дальше EcoVent.PULL_OUT, между — плавно.
static func vent_pull(xz: Vector2) -> float:
	var d := xz.distance_to(EcoVent.CENTER)
	return 1.0 - smoothstep(EcoVent.PULL_IN, EcoVent.PULL_OUT, d)


## Курс плоскости веера: течение (angle), а у курильщика — к жерлу по доле pull (плоскость — без знака, ±π одно и то же).
static func aim(f: Fan, angle: float) -> float:
	if f.pull <= 0.0:
		return angle
	var a := angle
	if absf(wrapf(f.to_vent - a, -PI, PI)) > PI / 2.0:   # ближняя из двух сторон плоскости
		a += PI
	return lerp_angle(a, f.to_vent, f.pull)


## Каждый веерник виден сонару и сканеру.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for f in fans:
		out.append(EcoWorld.target(ID, f.top, 1.4))


## Расстановка веера в момент t: поворот к потоку и покачивание (rotation YXZ, как в браузере).
static func basis(f: Fan, t: float) -> Basis:
	return Basis.from_euler(Vector3(sin(t * SWAY_RATE + f.phase) * SWAY, f.yaw, 0.0))


## Куда смотрит плоскость веера (нормаль).
static func facing(f: Fan) -> Vector3:
	return Vector3(sin(f.yaw), 0.0, cos(f.yaw))


func _nearest(p: Vector3) -> Fan:
	var best: Fan = null
	for f in fans:
		if best == null or f.pos.distance_to(p) < best.pos.distance_to(p):
			best = f
	return best


func _any_near(p: Vector3, r: float) -> bool:
	for f in fans:
		if f.pos.distance_to(p) < r:
			return true
	return false


static func _text(world: EcoWorld, fmt: String) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID) if w else Species.called(ID)
		return fmt % Species.cap(name)
