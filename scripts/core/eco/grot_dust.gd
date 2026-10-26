class_name EcoGrotDust
extends RefCounted
## Муть у дна от гротовика (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): живой остров 6 м бредёт по отмели на шести
## ногах. Идёт (ноги выпущены, EcoGrot.Walker.lift выше WALK_LIFT) — каждые STEP_EVERY с одна нога ставится на дно
## и поднимает облачко у ступни; ноги идут треногой (левая передняя, правая средняя, левая задняя, правая передняя,
## левая средняя, правая задняя — STEP_ORDER). Корабль задел панцирь — гротовик прячет ноги и панцирь оседает на дно:
## кольцом вокруг обода встаёт клуб из SETTLE_N облачков. Испуг прошёл, ноги снова выпущены — у ступней встаёт клуб
## слабее (RISE_N). Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают
## по течению, тают; светлее в луче прожектора) — свой пул на POOL мест, доля размера SCALE, цвет — бурый ил под
## цвет панциря. Мир и его случай не меняются: что делает гротовик — по его состоянию между шагами (moving), место
## и ритм — по времени мира, разброс — хешем EcoVary; у гостя сети мир идёт сам, поэтому и муть та же.
## Рисует GrotView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле (шаги за жизнь облачка и клуб оседания сразу, с запасом).
const POOL := 16
## Доля размера облачка скребуна (0,5 → 1,6 м): у гротовика 0,45 → 1,44 м у ступни; клуб оседания — × BURST_SCALE (0,77 → 2,45 м).
const SCALE := 0.9
const BURST_SCALE := 1.7
## Идёт: ноги выпущены больше WALK_LIFT; облачко раз в STEP_EVERY с (× (1 ± 0,2) хешем), непрозрачность STEP_ALPHA.
const WALK_LIFT := 0.8
const STEP_EVERY := 0.7
const STEP_ALPHA := 0.28
## Ступни на дне в осях гротовика (+Z — голова, +X — левый бок, как у GrotView): x = ± FOOT_X (нога GrotView.LEG_X
## развалена наружу на GrotView.LEG_TILT), z — FOOT_Z (те же, что GrotView.LEG_Z). Разброс места облачка ± SCATTER (м).
const FOOT_X := 2.6
const FOOT_Z: Array[float] = [-1.8, 0.0, 1.8]
const SCATTER := 0.25
## Порядок шагов треногой: (борт −1 / +1, номер ноги в FOOT_Z от хвоста).
const STEP_ORDER: Array[Vector2i] = [
	Vector2i(-1, 2), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(1, 2), Vector2i(-1, 1), Vector2i(1, 0)]
## Панцирь осел (ноги спрятаны): облачков и непрозрачность — кольцом у обода (полуоси в осях гротовика: вбок RING.x,
## вдоль RING.y; панцирь — EcoGrot.SHELL 2,4 × 3,2 м), с разбросом радиуса ± RING_SCATTER (доля).
const SETTLE_N := 6
const SETTLE_ALPHA := 0.8
const RING := Vector2(3.0, 4.0)
const RING_SCATTER := 0.12
## Ноги снова выпущены: облачков у ступней и непрозрачность.
const RISE_N := 3
const RISE_ALPHA := 0.45
## Облачка клуба встают вразнобой за BURST_SPAN с.
const BURST_SPAN := 0.5
## Над дном в начале (м).
const BASE_LIFT := 0.25
const SALT := 131
## Цвет: бурый ил под цвет панциря (#5b5a4a) — бледная муть на светлом песке в луче не видна.
const COLOR := Color(0.20, 0.18, 0.14)
const LIT := Color(0.28, 0.25, 0.19)

var dust := EcoGrazerDust.new(POOL)
var _moving := true
var _step := 0
var _next := 0.0
var _made := 0
var _last := -1e9


## Ступня ноги leg (борт, номер в FOOT_Z) гротовика gr на дне (в мире), облачко n — с разбросом.
static func foot_spot(gr: EcoGrot.Walker, leg: Vector2i, n: int) -> Vector3:
	var local := Vector3(leg.x * FOOT_X, 0.0, FOOT_Z[leg.y])
	local += Vector3((EcoVary.unit(n, SALT) * 2.0 - 1.0) * SCATTER, 0.0, (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * SCATTER)
	var w := Basis(Vector3.UP, gr.yaw) * local
	return Vector3(gr.p.x + w.x, gr.p.y + BASE_LIFT, gr.p.z + w.z)


## Где встаёт облачко n (c-е из count) клуба оседания: по кольцу у обода ровно, с разбросом угла и радиуса.
static func ring_spot(gr: EcoGrot.Walker, n: int, c: int = 0, count: int = 1) -> Vector3:
	var ang := (float(c) / maxi(1, count) + (EcoVary.unit(n, SALT + 2) - 0.5) * 0.3) * TAU
	var k := 1.0 + (EcoVary.unit(n, SALT + 3) * 2.0 - 1.0) * RING_SCATTER
	var w := Basis(Vector3.UP, gr.yaw) * Vector3(cos(ang) * RING.x * k, 0.0, sin(ang) * RING.y * k)
	return Vector3(gr.p.x + w.x, gr.p.y + BASE_LIFT, gr.p.z + w.z)


## Гротовик gr шагает (ноги выпущены, не замер).
static func walking(gr: EcoGrot.Walker) -> bool:
	return gr.moving() and gr.lift > WALK_LIFT


## Шаг мути в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoGrot, t: float, ship: Vector3) -> void:
	if system == null or system.grot == null:
		return
	var gr := system.grot
	if t < _last or _last < -1e8:   # первый шаг или новый забег — запомнить, мути нет
		_moving = gr.moving()
		_next = t + STEP_EVERY
		_last = t
		return
	_last = t
	var was := _moving
	_moving = gr.moving()
	var near := not EcoGrazerDust.lite and gr.p.distance_to(ship) <= EcoGrazerDust.NEAR
	if was and not _moving:
		if near:
			_settle(gr, t)
		return
	if _moving and not was:
		if near:
			_rise(gr, t)
		_next = t + STEP_EVERY
		return
	if not walking(gr):
		_next = maxf(_next, t)
		return
	if t < _next:
		return
	var leg := STEP_ORDER[_step % STEP_ORDER.size()]
	_step += 1
	var key := _made + 1
	_next = t + STEP_EVERY * EcoVary.spread(key, SALT + 4, 0.2)
	if not near:
		return
	_made += 1
	dust.add(foot_spot(gr, leg, key), t, STEP_ALPHA * EcoVary.spread(key, SALT + 5, 0.2), key, SCALE)


## Панцирь осел: SETTLE_N облачков кольцом у обода вразнобой за BURST_SPAN с.
func _settle(gr: EcoGrot.Walker, t: float) -> void:
	for c in SETTLE_N:
		_made += 1
		var key := _made
		var born := t + BURST_SPAN * c / float(SETTLE_N - 1) * EcoVary.unit(key, SALT + 6)
		dust.add(ring_spot(gr, key, c, SETTLE_N), born, SETTLE_ALPHA * EcoVary.spread(key, SALT + 7, 0.2), key,
				SCALE * BURST_SCALE)


## Ноги снова выпущены: RISE_N облачков у ступней (по одному на ногу треноги) вразнобой за BURST_SPAN с.
func _rise(gr: EcoGrot.Walker, t: float) -> void:
	for c in RISE_N:
		_made += 1
		var key := _made
		var leg := STEP_ORDER[(_step + c * 2) % STEP_ORDER.size()]
		var born := t + BURST_SPAN * c / float(RISE_N - 1) * EcoVary.unit(key, SALT + 8)
		dust.add(foot_spot(gr, leg, key), born, RISE_ALPHA * EcoVary.spread(key, SALT + 9, 0.2), key, SCALE)
