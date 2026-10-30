class_name GateArch
extends RefCounted
## Временная арка террасы врат 07 (#826, часть 2) — до модели MOD-023 (#999). Габариты — схема ART-079
## (`docs/concept-art/terrasa-vrat.md`, `terrasa-vrat-gabarity.png`): ширина X 120 м, глубина Z 23 м, проход вдоль Z
## X −30…+30 и Y 0…36 м от пола — пустой; подход с +Z. Середина — `EcoGate.CENTER`, пол — дно там (`floor_y`).
## Полной высоты 58 м на нашей террасе нет: пол на ≈ 48 м, до льда меньше — верх ограничен `TOP_DEPTH`.
## Форма — простые блоки (две опоры с уступами, перемычка, три лопасти сверху) и три чаши гнёзд `GateDiag.NESTS`.
## Корабль сквозь опоры не проходит: `hits` (корпус — три точки по длине с запасом) → `Helm.Ship.solid`.
## Рисует `scripts/game/gate_view.gd` (`main.gate_view`, слой отмели). При сдаче MOD-023 — заменить модель, `BOXES`
## оставить как коллизию или снять с неё.

const HALF_DEPTH := 11.5        ## полглубины арки по Z, м
const BASE_HALF_DEPTH := 8.0   ## опоры у пола тоньше: лицевая ниша, гнёзда `GateDiag.NESTS` (z +9,5…13) перед ней
const PASS_HALF := 30.0         ## полуширина прохода, м
const PASS_TOP := 36.0          ## высота прохода от пола, м
const TOP_DEPTH := 8.0          ## верх лопастей не выше этой глубины, м (лёд и потолок хода `Helm.Ship.CEILING`)
const SINK := 8.0               ## опоры уходят в дно — пол под ними неровный
const SHIP_HALF_LEN := 13.0     ## точки корпуса для `hits`: середина и ± это вдоль носа, м
const SHIP_R := 5.5             ## запас вокруг точки корпуса по горизонтали, м
const SHIP_H := 3.0             ## запас по вертикали, м

const MINERAL := Color("#395361")
const NEST_COLOR := Color("#82999D")
const NEST_R := 0.8             ## чаша гнезда Ø 1,6 м
const NEST_H := 0.35


static var _floor := NAN
static var _boxes: Array[AABB] = []


## Пол террасы — дно в середине (рельеф неизменен — считается раз).
static func floor_y() -> float:
	if is_nan(_floor):
		_floor = Seabed.height(EcoGate.CENTER.x, EcoGate.CENTER.y)
	return _floor


## Высота арки над полом (верх лопастей): не выше `TOP_DEPTH`.
static func height() -> float:
	return -TOP_DEPTH - floor_y()


## Блоки арки в осях места (x, y от пола, z): [центр, полуразмер]. Опоры — три уступа, сужаются кверху; над проходом —
## перемычка; три лопасти — над опорами и над серединой (трёхлопастный силуэт).
static func boxes() -> Array[AABB]:
	if _boxes.is_empty():
		_boxes = _make_boxes()
	return _boxes


static func _make_boxes() -> Array[AABB]:
	var top := height()
	var out: Array[AABB] = []
	for s in [-1.0, 1.0]:
		var inner: float = PASS_HALF * s
		var outer: float = 60.0 * s
		out.append(_box(inner, outer - 3.0 * s, -SINK, 14.0, BASE_HALF_DEPTH))   # ниша у пола: гнёзда перед ней
		out.append(_box(inner, outer, 14.0, 26.0, HALF_DEPTH))                    # нависающий уступ
		out.append(_box(inner, outer - 9.0 * s, 26.0, PASS_TOP + 2.0, HALF_DEPTH - 2.5))
		out.append(_box(inner + 2.0 * s, outer - 14.0 * s, PASS_TOP + 2.0, top, HALF_DEPTH - 4.0))
	out.append(_box(-PASS_HALF - 1.0, PASS_HALF + 1.0, PASS_TOP, PASS_TOP + 4.0, HALF_DEPTH - 3.0))
	out.append(_box(-9.0, 9.0, PASS_TOP + 4.0, top - 1.5, HALF_DEPTH - 4.5))
	return out


static func _box(x0: float, x1: float, y0: float, y1: float, hz: float) -> AABB:
	var lo := Vector3(minf(x0, x1), minf(y0, y1), -hz)
	return AABB(lo, Vector3(absf(x1 - x0), absf(y1 - y0), hz * 2.0))


## Мир → оси места.
static func local(p: Vector3) -> Vector3:
	return Vector3(p.x - EcoGate.CENTER.x, p.y - floor_y(), p.z - EcoGate.CENTER.y)


## Точка (мир) внутри арки с запасом `r` по горизонтали и `h` по вертикали.
static func inside(p: Vector3, r := 0.0, h := 0.0) -> bool:
	var q := local(p)
	if absf(q.x) > 60.0 + r or absf(q.z) > HALF_DEPTH + r:
		return false
	for b: AABB in boxes():
		if q.x > b.position.x - r and q.x < b.end.x + r and q.y > b.position.y - h and q.y < b.end.y + h \
				and q.z > b.position.z - r and q.z < b.end.z + r:
			return true
	return false


## Корпус в `pos` с курсом `yaw` задевает арку: середина и нос/корма (`SHIP_HALF_LEN`) с запасом.
static func hits(pos: Vector3, yaw: float) -> bool:
	if absf(pos.x - EcoGate.CENTER.x) > 90.0 or absf(pos.z - EcoGate.CENTER.y) > 40.0:
		return false   # далеко от арки — без счёта
	var nose := Vector3(-sin(yaw), 0.0, -cos(yaw)) * SHIP_HALF_LEN
	for p in [pos, pos + nose, pos - nose]:
		if inside(p, SHIP_R, SHIP_H):
			return true
	return false


## Меш: блоки арки (поверхность 0) и чаши гнёзд (поверхность 1) в мировых координатах. Лицевая сторона — по часовой.
static func mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := Vector3(EcoGate.CENTER.x, floor_y(), EcoGate.CENTER.y)
	for b: AABB in boxes():
		_cube(st, b, base)
	st.commit(m)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in GateDiag.NESTS.size():
		_bowl(st, GateDiag.nest_pos(i))
	st.commit(m)
	return m


static func _quad(st: SurfaceTool, n: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# a b c d — по часовой, если смотреть снаружи
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


static func _cube(st: SurfaceTool, b: AABB, o: Vector3) -> void:
	var p := b.position + o
	var e := b.end + o
	var c := [Vector3(p.x, p.y, p.z), Vector3(e.x, p.y, p.z), Vector3(e.x, p.y, e.z), Vector3(p.x, p.y, e.z),
		Vector3(p.x, e.y, p.z), Vector3(e.x, e.y, p.z), Vector3(e.x, e.y, e.z), Vector3(p.x, e.y, e.z)]
	_quad(st, Vector3.UP, c[4], c[5], c[6], c[7])
	_quad(st, Vector3.DOWN, c[0], c[3], c[2], c[1])
	_quad(st, Vector3.BACK, c[3], c[7], c[6], c[2])
	_quad(st, Vector3.FORWARD, c[1], c[5], c[4], c[0])
	_quad(st, Vector3.RIGHT, c[2], c[6], c[5], c[1])
	_quad(st, Vector3.LEFT, c[0], c[4], c[7], c[3])


## Чаша гнезда: низкий восьмигранник на дне.
static func _bowl(st: SurfaceTool, at: Vector3) -> void:
	var n := 8
	var y0 := at.y - 0.2
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
