class_name GateArch
extends RefCounted
## Арка террасы врат 07 — числа и коллизия под модель MOD-023 (`models/terrasa-vrat.glb`, встройка #1757; до неё
## здесь были временные блоки, #826). Заметка модели — `docs/concept-art/terrasa-vrat.md`, «Модель MOD-023»: габарит
## 120 × 58 × 23,5 м, pivot — центр прохода на полу, подход с +Z; проход вдоль Z X −24…+24 и Y 0…22 м от пола пуст
## (`test_gate_model.test_passage_empty`), выше него плечи опор выступают внутрь, свод проёма ≈ 41 м.
## Середина — `EcoGate.CENTER`, пол — дно жёлоба там (`floor_y`, ≈ 66 м), верх на ≈ 8 м.
## Коллизия — блоки по силуэту модели (`boxes`, замер LOD0 сеткой 4 × 2 м; `test_gate_arch.test_boxes_follow_model`).
## Корабль сквозь опоры и плечи не проходит: `hits` (три точки по длине корпуса, запас по высоте — по `HullPlan`)
## → `Helm.Ship.solid`. Модель рисует `scripts/game/gate_view.gd` (`main.gate_view`, слой отмели).
## Чаши гнёзд `nests_mesh` — временные, пока гнёзда `GateDiag.NESTS` не встали на места гнёзд модели (#1757).

const MODEL := "res://models/terrasa-vrat.glb"
const HEIGHT := 58.1            ## рост модели от пола, м
const HALF_DEPTH := 11.5        ## полглубины арки по Z, м
const PASS_HALF := 24.0         ## полуширина прохода, м (было 30 у временной арки)
const PASS_TOP := 22.0          ## высота прохода от пола, м (было 36)
const TOP_DEPTH := 8.0          ## верх арки не выше этой глубины, м (лёд и потолок хода `Helm.Ship.CEILING`)
const SINK := 8.0               ## блоки опор уходят в дно — склоны жёлоба под ними неровные
const SHIP_HALF_LEN := 13.0     ## точки корпуса для `hits`: середина и ± это вдоль носа, м
const SHIP_R := 5.5             ## запас вокруг точки корпуса по горизонтали, м
const SHIP_UP := 4.8            ## корпус над центром корабля, м (`HullPlan`, рубка)
const SHIP_DOWN := 1.6          ## корпус под центром, м

## LOD модели по расстоянию от камеры до сетки (`visibility_range_*`), м: [конец LOD0, конец LOD1]; дальше — LOD2.
## «Экономно» — без LOD0 (41 тыс. треуг.): вблизи LOD1. Один LOD за раз: `ranges` делит расстояние без щелей.
const LOD_FULL: Array[float] = [160.0, 320.0]
const LOD_LITE: Array[float] = [0.0, 160.0]
## Гистерезиса (`visibility_range_*_margin`) нет намеренно: в его полосе движок держит прежнее состояние, а после
## прыжка камеры (загрузка сохранения у 07, снимок) прежнего нет — оба LOD скрыты, арки нет в кадре.

const NEST_COLOR := Color("#82999D")
const NEST_R := 0.8             ## чаша гнезда Ø 1,6 м
const NEST_H := 0.35

## Блоки по силуэту модели в осях места: x0, x1, y0, y1 (от пола), полуглубина по Z. Левая опора (−X) у прохода
## отвесная, правая выше 4 м отступает до x 36; плечи с 22 м идут внутрь до −12 и +20, выше 28 м — до −9 и +15;
## перемычка с 41 м, над ней гребень.
const SHAPE: Array[float] = [
	-60.0, -27.0, -8.0, 4.0, 11.5,
	-52.0, -27.0, 4.0, 22.0, 8.0,
	-36.0, -12.0, 22.0, 28.0, 4.5,
	-28.0, -9.0, 28.0, 41.0, 3.5,
	28.0, 60.0, -8.0, 4.0, 11.5,
	35.0, 58.0, 4.0, 22.0, 8.0,
	20.0, 46.0, 22.0, 28.0, 4.5,
	15.0, 38.0, 28.0, 41.0, 3.5,
	-22.0, 30.0, 41.0, 46.0, 3.0,
	-12.0, 20.0, 46.0, 50.0, 2.5,
	-2.0, 14.0, 50.0, 58.1, 2.0,
]


static var _floor := NAN
static var _boxes: Array[AABB] = []


## Пол террасы — дно в середине (рельеф неизменен — считается раз).
static func floor_y() -> float:
	if is_nan(_floor):
		_floor = Seabed.height(EcoGate.CENTER.x, EcoGate.CENTER.y)
	return _floor


## Блоки арки в осях места (x, y от пола, z) — `SHAPE`.
static func boxes() -> Array[AABB]:
	if _boxes.is_empty():
		_boxes = _make_boxes()
	return _boxes


static func _make_boxes() -> Array[AABB]:
	var out: Array[AABB] = []
	for i in range(0, SHAPE.size(), 5):
		out.append(_box(SHAPE[i], SHAPE[i + 1], SHAPE[i + 2], SHAPE[i + 3], SHAPE[i + 4]))
	return out


static func _box(x0: float, x1: float, y0: float, y1: float, hz: float) -> AABB:
	var lo := Vector3(minf(x0, x1), minf(y0, y1), -hz)
	return AABB(lo, Vector3(absf(x1 - x0), absf(y1 - y0), hz * 2.0))


## Мир → оси места.
static func local(p: Vector3) -> Vector3:
	return Vector3(p.x - EcoGate.CENTER.x, p.y - floor_y(), p.z - EcoGate.CENTER.y)


## Точка (мир) внутри арки с запасом `r` по горизонтали и по вертикали: `up` — вверх от точки, `down` — вниз.
static func inside(p: Vector3, r := 0.0, up := 0.0, down := 0.0) -> bool:
	var q := local(p)
	if absf(q.x) > 60.0 + r or absf(q.z) > HALF_DEPTH + r:
		return false
	for b: AABB in boxes():
		if q.x > b.position.x - r and q.x < b.end.x + r and q.y > b.position.y - up and q.y < b.end.y + down \
				and q.z > b.position.z - r and q.z < b.end.z + r:
			return true
	return false


## Корпус в `pos` с курсом `yaw` задевает арку: середина и нос/корма (`SHIP_HALF_LEN`) с запасом `SHIP_R`
## в стороны, по высоте — корпус от −`SHIP_DOWN` до +`SHIP_UP` от центра.
static func hits(pos: Vector3, yaw: float) -> bool:
	if absf(pos.x - EcoGate.CENTER.x) > 90.0 or absf(pos.z - EcoGate.CENTER.y) > 40.0:
		return false   # далеко от арки — без счёта
	var nose := Vector3(-sin(yaw), 0.0, -cos(yaw)) * SHIP_HALF_LEN
	for p in [pos, pos + nose, pos - nose]:
		if inside(p, SHIP_R, SHIP_UP, SHIP_DOWN):
			return true
	return false


## Меш чаш гнёзд в мировых координатах (временные, до гнёзд модели). Лицевая сторона — по часовой.
static func nests_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in GateDiag.NESTS.size():
		_bowl(st, GateDiag.nest_pos(i))
	st.commit(m)
	return m


## Отрезок расстояний LOD i (0…2): Vector2(начало, конец), конец 0 — без предела; начало = конец = −1 — LOD скрыт.
static func ranges(i: int, lite: bool) -> Vector2:
	var ends := LOD_LITE if lite else LOD_FULL
	var from := 0.0 if i == 0 else ends[i - 1]
	var to := 0.0 if i == 2 else ends[i]
	if i < 2 and to <= from:
		return Vector2(-1.0, -1.0)
	return Vector2(from, to)


static func _quad(st: SurfaceTool, n: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# a b c d — по часовой, если смотреть снаружи
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


## Чаша гнезда: низкий восьмигранник на дне.
static func _bowl(st: SurfaceTool, at: Vector3) -> void:
	var n := 8
	var y0 := at.y - 1.0   # юбка в дно: на склоне жёлоба (#1757) нижний край чаши не висит над грунтом
	var y1 := at.y + NEST_H
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(at.x + cos(a0) * NEST_R, 0.0, at.z + sin(a0) * NEST_R)
		var p1 := Vector3(at.x + cos(a1) * NEST_R, 0.0, at.z + sin(a1) * NEST_R)
		var side := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		_quad(st, side, Vector3(p1.x, y0, p1.z), Vector3(p1.x, y1, p1.z), Vector3(p0.x, y1, p0.z),
			Vector3(p0.x, y0, p0.z))
		var mid := Vector3(at.x, y1 - 0.15, at.z)   # чаша — чуть вогнутый верх
		for v in [Vector3(p1.x, y1, p1.z), mid, Vector3(p0.x, y1, p0.z)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
