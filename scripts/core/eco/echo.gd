class_name EcoEcho
extends EcoSystem
## Эхоловец (js/echo.js, концепт ART-007 `docs/concept-art/eholovec.md`): засадчик около 3 м с двумя ушами-воронками
## лежит снаружи клетки Костей левиафана между рёбрами (EcoBones; без костей — в +14, +10 м от их центра, как
## в браузере) и почти не двигается. Корабль ближе LISTEN_R — слушает его: каждое ухо отдельно, двумя суставами
## (поворот и наклон), поворачивается на корабль (EAR_TURN рад/с, в пределах EAR_YAW/EAR_PITCH), дальше — уши
## медленно обводят воду. Затаившегося нет ни на сонаре, ни в прицеле сканера. Импульс сонара ближе REVEAL_R
## выдаёт его на REVEAL_T с (Ec.onPing): он виден сонару и сканеру, наблюдение «reveal» — только когда раскрылся.
## Подделка голосов экипажа по связи («fake», «strike», «lure») — следующая задача потока Б вместе со связью
## корабля (ART-040, поток А).

const ID := "echo"
## Слушает корабль ближе LISTEN_R (м), импульс сонара ближе REVEAL_R раскрывает его на REVEAL_T с (js/echo.js).
const LISTEN_R := 60.0
const REVEAL_R := 70.0
const REVEAL_T := 120.0
## Место у костей: между парами рёбер PAIR и PAIR + 1 левого борта клетки, на OUT м снаружи от ног рёбер.
const PAIR := 3
const OUT := 3.2
## Без костей — от их центра (js: b.pos + (14, 10)).
const OFFSET := Vector2(14.0, 10.0)
## Тело над дном (js: + 0,7; на склоне — над самым высоким дном под телом, BED).
const UP := 0.7
## Где мерить дно под телом (в осях тела): середина, голова, хвост, бока.
const BED: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, 1.4), Vector3(0, 0, -1.3), Vector3(0.6, 0, 0),
	Vector3(-0.6, 0, 0)]
## Уши: основание стебля в теле (x вбок, y вверх, z вперёд — голова к +Z), предел поворота от носа и наклона (рад),
## скорость сустава (рад/с). Покой: уши обводят воду ± IDLE_SWEEP за IDLE_PERIOD с, левое и правое — вразнобой.
const EAR_BASE: Array[Vector3] = [Vector3(0.42, 0.45, 0.75), Vector3(-0.42, 0.45, 0.75)]
const EAR_YAW := 2.3
const EAR_PITCH_MIN := -0.35
const EAR_PITCH_MAX := 1.1
const EAR_TURN := 1.2
const IDLE_SWEEP := 0.9
const IDLE_PERIOD := 23.0
const IDLE_PITCH := 0.35
## Цель сонара и сканера — тело, размер TARGET_R (js: r 2).
const TARGET_R := 2.0
## Без дна (тесты без ground) лежит на этой высоте.
const FALLBACK_FLOOR := -46.0


## Сам эхоловец.
class Lurker:
	extends RefCounted
	## Тело (центр, y — над дном на UP) и курс: yaw = 0 — голова к +Z, растёт — поворот влево (как EcoGrot).
	var p := Vector3.ZERO
	var yaw := 0.0
	## Уши: (поворот от носа, наклон вверх) каждого, рад.
	var ears: Array[Vector2] = [Vector2(0.6, IDLE_PITCH), Vector2(-0.6, IDLE_PITCH)]
	## Корабль ближе LISTEN_R — слушает его (Ec.near).
	var near := false
	## Сколько ещё раскрыт (с); ≤ 0 — затаился.
	var revealed := 0.0

	func is_revealed() -> bool:
		return revealed > 0.0

	## Тело → мир.
	func xform() -> Transform3D:
		return Transform3D(Basis(Vector3.UP, yaw), p)

	## Основание уха i в мире.
	func ear_base(i: int) -> Vector3:
		return xform() * EAR_BASE[i]


var echo: Lurker

var _bones: EcoBones
var _ground: Callable
var _t := 0.0


func _init(bones: EcoBones = null) -> void:
	_bones = bones


func reset(world: EcoWorld) -> void:
	_ground = world.ground
	_t = 0.0
	echo = Lurker.new()
	var at := lair()
	echo.yaw = heading()
	echo.p = Vector3(at.x, _bed(at, echo.yaw) + UP, at.y)


## Где лежит (x, z): снаружи клетки костей между парами рёбер PAIR и PAIR + 1; без костей — OFFSET от их центра.
func lair() -> Vector2:
	if _bones == null or _bones.rib_z.size() <= PAIR + 1:
		var c := EcoBones.CENTER + OFFSET
		return c
	var f0 := _bones.rib_point(PAIR * 2, 0)
	var f1 := _bones.rib_point((PAIR + 1) * 2, 0)
	var foot_x := (f0.x + f1.x) * 0.5
	var local := Vector3(foot_x + signf(foot_x) * OUT, 0.0, (_bones.rib_z[PAIR] + _bones.rib_z[PAIR + 1]) * 0.5)
	var w := _bones.to_world(local)
	return Vector2(w.x, w.z)


## Курс тела: голова наружу от клетки (поперёк оси костей); без костей — к +Z.
func heading() -> float:
	if _bones == null or _bones.rib_z.size() <= PAIR + 1:
		return 0.0
	var at := lair()
	var out := Vector3(at.x, 0.0, at.y) - _bones.to_world(Vector3(0, 0, _bones.rib_z[PAIR]))
	out.y = 0.0
	out -= _bones.axis() * out.dot(_bones.axis())
	return atan2(out.x, out.z)


func step(world: EcoWorld, dt: float) -> void:
	_t += dt
	var ec := echo
	if ec == null:
		return
	var s := world.ship.pos
	ec.near = ec.p.distance_to(s) < LISTEN_R
	if ec.revealed > 0.0:
		ec.revealed = maxf(0.0, ec.revealed - dt)
	for i in 2:
		var want := aim(i, s) if ec.near else idle(i, _t)
		var e := ec.ears[i]
		var turn := EAR_TURN * dt
		e.x += clampf(wrapf(want.x - e.x, -PI, PI), -turn, turn)
		e.y += clampf(want.y - e.y, -turn, turn)
		ec.ears[i] = e


## Куда смотрит ухо i, чтобы слушать точку target: поворот от носа и наклон, в пределах суставов.
func aim(i: int, target: Vector3) -> Vector2:
	var d := Basis(Vector3.UP, echo.yaw).inverse() * (target - echo.ear_base(i))
	var yaw := clampf(atan2(d.x, d.z), -EAR_YAW, EAR_YAW)
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), EAR_PITCH_MIN, EAR_PITCH_MAX)
	return Vector2(yaw, pitch)


## Покой: уши обводят воду вразнобой (левое смотрит левее, правое — правее).
static func idle(i: int, t: float) -> Vector2:
	var side := 1.0 if i == 0 else -1.0
	var ph := TAU * t / IDLE_PERIOD + i * 2.1
	return Vector2(side * 0.7 + sin(ph) * IDLE_SWEEP, IDLE_PITCH + 0.15 * sin(ph * 1.7))


## Направление уха i в мире (куда открыта воронка).
func ear_dir(i: int) -> Vector3:
	var e := echo.ears[i]
	var local := Vector3(sin(e.x) * cos(e.y), sin(e.y), cos(e.x) * cos(e.y))
	return Basis(Vector3.UP, echo.yaw) * local


## Импульс сонара (Ec.onPing): ближе REVEAL_R — раскрыт на REVEAL_T с; наблюдение — только когда раскрылся.
func on_ping(world: EcoWorld, pos: Vector3) -> void:
	var ec := echo
	if ec == null or ec.p.distance_to(pos) >= REVEAL_R:
		return
	var was := ec.is_revealed()
	ec.revealed = REVEAL_T
	if not was:
		world.emit(ID, "reveal", ec.p, _reveal_text(world))


## Затаившегося нет ни на сонаре, ни в прицеле (js: hidden и noSonar, пока не раскрыт).
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	if echo:
		var h := not echo.is_revealed()
		out.append(EcoWorld.target(ID, echo.p, TARGET_R, not h, h))


## Дно под телом на склоне: самое высокое под серединой, головой, хвостом и боками — тело не тонет в склоне.
func _bed(at: Vector2, yaw: float) -> float:
	var b := Basis(Vector3.UP, yaw)
	var y := -INF
	for o: Vector3 in BED:
		var q := b * o
		y = maxf(y, _floor(at.x + q.x, at.y + q.z))
	return y


func _floor(x: float, z: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else FALLBACK_FLOOR


## «Импульс сонара выдал засадчика с ушами-воронками: он раскрыт» — название в момент показа; мир — слабой ссылкой.
static func _reveal_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var who := w.nm(ID, Species.Case.ACC) if w else Species.called(ID, Species.Case.ACC)
		return "Импульс сонара выдал %s: он раскрыт" % who
