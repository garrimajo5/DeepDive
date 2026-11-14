class_name EcoHull
## Существа не проходят сквозь корабль (S.pushOut и S.hullDist в js/ship.js): форма корпуса — HullPlan потока А
## (корпус, носовая оболочка, кормовой переход по ART-001), раздутая на запас r. Точку внутри выталкиваем наружу
## по нормали той детали, в которой она сидит, а скорость внутрь корпуса гасим. Без узлов, оси мира Godot.

## Центр основного объёма в осях корабля (корпус от z = −11 до 29) и радиус, дальше которого корпус не достать.
const CENTER := Vector3(0, HullPlan.CENTER_Y, 9)
const REACH := 22.0
## Сколько раз выталкивать подряд: на стыке деталей точка может попасть из одной в другую (как в js — 4).
const TRIES := 4
## Дальше этого от точки корабля корпус не достать ни при каком курсе (REACH + |CENTER|).
const BOUND := REACH + 9.5

static var _inflated := {}
static var _shapes := {}
## Сколько раз проверяли «внутри ли деталь» — для теста цены выталкивания (issue #653).
static var checks := 0


## Деталь корпуса, готовая к частым проверкам: повороты и размер детали собраны в одну матрицу (HullPlan.Part
## каждый раз считает синусы трёх поворотов — на рыбке у корпуса это тысячи раз за шаг, issue #653).
class Shape:
	var part: HullPlan.Part
	var form := 0
	var pos := Vector3.ZERO
	var to_unit := Basis.IDENTITY    ## оси корабля (от pos) → единичная форма: unrotate, потом / size
	var to_ship := Basis.IDENTITY    ## градиент единичной формы → оси корабля: / size, потом rotate

	func _init(p: HullPlan.Part) -> void:
		part = p
		form = p.form
		pos = p.pos
		to_unit = Basis(p.unrotate(Vector3.RIGHT) / p.size, p.unrotate(Vector3.UP) / p.size,
				p.unrotate(Vector3.BACK) / p.size)
		to_ship = Basis(p.rotate(Vector3.RIGHT / p.size), p.rotate(Vector3.UP / p.size), p.rotate(Vector3.BACK / p.size))

	## То же, что HullPlan.Part.contains для сплошных форм корпуса.
	func contains(l: Vector3) -> bool:
		var u := to_unit * (l - pos)
		var rr := u.x * u.x + u.z * u.z
		match form:
			HullPlan.Form.CUBE:
				return absf(u.x) <= 0.5 and absf(u.y) <= 0.5 and absf(u.z) <= 0.5
			HullPlan.Form.SPHERE:
				return rr + u.y * u.y <= 0.25
			HullPlan.Form.DOME:
				return u.y >= -0.25 and rr + u.y * u.y <= 0.25
			HullPlan.Form.CYLINDER:
				return absf(u.y) <= 1.0 and rr <= 0.25
			HullPlan.Form.CAPSULE:
				var dy := u.y - clampf(u.y, -0.5, 0.5)
				return rr + dy * dy <= 0.25
			HullPlan.Form.FRUSTUM:
				if absf(u.y) > 1.0:
					return false
				var r := HullPlan.frustum_radius(u.y)
				return rr <= r * r
		return false


## Детали основного объёма, раздутые на r метров (кэш по r). Капсула и конус — Ø1 высотой 2: по оси y +r, поперёк +2r.
static func parts(r: float) -> Array:
	var key := snappedf(r, 0.001)
	if _inflated.has(key):
		return _inflated[key]
	var out: Array = []
	for part: HullPlan.Part in HullPlan.parts():
		if part.piece != HullPlan.Piece.BODY and part.piece != HullPlan.Piece.NOSE and part.piece != HullPlan.Piece.STERN:
			continue
		out.append(_grown(part, key))
	_inflated[key] = out
	return out


## Деталь part, раздутая на r: капсула и конус — Ø1 высотой 2, по оси y +r, поперёк +2r.
static func _grown(part: HullPlan.Part, r: float) -> HullPlan.Part:
	var grow := Vector3(2 * r, 2 * r, 2 * r)
	if part.form == HullPlan.Form.CAPSULE or part.form == HullPlan.Form.FRUSTUM or part.form == HullPlan.Form.CYLINDER:
		grow.y = r
	return HullPlan.Part.new(part.name, part.piece, part.form, part.paint, part.pos, part.size + grow, part.rot)


## Выступы корпуса — детали HullPlan вне основного объёма parts(r): двигатели в кожухах по бортам кормы (|x| до 6,7 м,
## а кормовой переход там — 3,6 м), рули глубины, стабилизаторы, крепления; манипулятор и прожектор под носом (до
## z −8,9, основной объём — от −7,2), шлюз, крышки. Кожух (труба) — сплошным цилиндром, клин — бруском; окна-пластины
## лежат на обшивке — без них. Мелким существам хватает основного объёма; твёрдое крупное (гротовик) проверяет
## корабль целиком — touches_whole (#1835: у арки 07 корма с двигателями тоже шла мимо проверки).
const EXTRA_FORM := {HullPlan.Form.TUBE: HullPlan.Form.CYLINDER, HullPlan.Form.ROTOR: HullPlan.Form.CYLINDER,
		HullPlan.Form.WEDGE: HullPlan.Form.CUBE}
static var _extra := {}
static var _extra_boxes := {}
static func extra_shapes(r: float) -> Array:
	var key := snappedf(r, 0.001)
	if _extra.has(key):
		return _extra[key]
	var out: Array = []
	for part: HullPlan.Part in HullPlan.parts():
		if part.piece == HullPlan.Piece.BODY or part.piece == HullPlan.Piece.NOSE or part.piece == HullPlan.Piece.STERN \
				or part.form == HullPlan.Form.PLATE:
			continue
		var f: int = EXTRA_FORM.get(part.form, part.form)
		var solid := HullPlan.Part.new(part.name, part.piece, f, part.paint, part.pos, part.size, part.rot)
		out.append(Shape.new(_grown(solid, key)))
	_extra[key] = out
	return out


## Касается ли точка p (мир) корабля целиком — основного объёма и выступов extra_shapes, раздутых на r.
static func touches_whole(p: Vector3, ship_pos: Vector3, yaw: float, r: float = 0.0) -> bool:
	var l := to_ship(p, ship_pos, yaw)
	if l.distance_to(CENTER) > REACH + r:
		return false
	if touches_local(l, r):
		return true
	var key := snappedf(r, 0.001)
	if not _extra_boxes.has(key):
		_extra_boxes[key] = _box_of(extra_shapes(key))
	return (_extra_boxes[key] as AABB).has_point(l) and _shape_at(l, extra_shapes(key)) != null


## Точка мира → оси корабля, стоящего в ship_pos с курсом yaw.
static func to_ship(p: Vector3, ship_pos: Vector3, yaw: float) -> Vector3:
	return (p - ship_pos).rotated(Vector3.UP, -yaw)


## Детали parts(r), готовые к проверкам (кэш по r).
static func shapes(r: float) -> Array:
	var key := snappedf(r, 0.001)
	if _shapes.has(key):
		return _shapes[key]
	var out: Array = []
	for part: HullPlan.Part in parts(key):
		out.append(Shape.new(part))
	_shapes[key] = out
	return out


## Коробка в осях корабля, в которой лежат все детали shapes(r) (кэш по r): единичная форма каждой детали —
## не больше x, z ∈ [−0,5; 0,5], y ∈ [−1; 1]; её углы в осях корабля. Точка вне коробки корпуса не касается —
## проверка дешевле, чем обход деталей (бахрома у колодца 05, issue #1174).
static var _boxes := {}
static func box(r: float) -> AABB:
	var key := snappedf(r, 0.001)
	if _boxes.has(key):
		return _boxes[key]
	_boxes[key] = _box_of(shapes(key))
	return _boxes[key]


## Коробка в осях корабля вокруг деталей list (Shape).
static func _box_of(list: Array) -> AABB:
	var out := AABB()
	var first := true
	for sh: Shape in list:
		var back := sh.to_unit.inverse()
		for k in 8:
			var u := Vector3(0.5 if k & 1 else -0.5, 1.0 if k & 2 else -1.0, 0.5 if k & 4 else -0.5)
			var l := sh.pos + back * u
			if first:
				out = AABB(l, Vector3.ZERO)
				first = false
			else:
				out = out.expand(l)
	return out


## Касается ли корпуса (раздутого на r) точка l в осях корабля: сначала коробка box(r), потом детали.
static func touches_local(l: Vector3, r: float) -> bool:
	return box(r).has_point(l) and _shape_at(l, shapes(r)) != null


static func _shape_at(l: Vector3, list: Array) -> Shape:
	for sh: Shape in list:  # Shape.contains без вызова метода — его цена здесь заметна
		checks += 1
		var u := sh.to_unit * (l - sh.pos)
		var rr := u.x * u.x + u.z * u.z
		var inside := false
		match sh.form:
			HullPlan.Form.CUBE:
				inside = absf(u.x) <= 0.5 and absf(u.y) <= 0.5 and absf(u.z) <= 0.5
			HullPlan.Form.CAPSULE:
				var dy := u.y - clampf(u.y, -0.5, 0.5)
				inside = rr + dy * dy <= 0.25
			HullPlan.Form.FRUSTUM:
				if absf(u.y) <= 1.0:
					var r := 0.5 - 0.125 * (u.y + 1.0)  # HullPlan.frustum_radius
					inside = rr <= r * r
			_:
				inside = sh.contains(l)
		if inside:
			return sh
	return null


## Ближе ли точка мира к корпусу, чем r (r = 0 — внутри корпуса). Кусает, когда дотянулся (hullDist < 1,2).
static func touches(p: Vector3, ship_pos: Vector3, yaw: float, r: float = 0.0) -> bool:
	var l := to_ship(p, ship_pos, yaw)
	if l.distance_to(CENTER) > REACH + r:
		return false
	return touches_local(l, r)


## Обход корпуса (S.detour в js/ship.js): путь от p к goal (мир) проходит сквозь корпус, раздутый на r, — вернуть
## промежуточную точку сбоку от корабля (со стороны p, на 6 м вперёд или назад к цели, не дальше её); иначе goal.
## Последние 2 м пути не проверяются: цель может лежать у самой обшивки (нос у стекла).
static func detour(p: Vector3, goal: Vector3, ship_pos: Vector3, yaw: float, r: float) -> Vector3:
	if p.distance_squared_to(ship_pos) > DETOUR_NEAR * DETOUR_NEAR:
		return goal
	var a := to_ship(p, ship_pos, yaw)
	var b := to_ship(goal, ship_pos, yaw)
	if not segment_hits(a, b, r):
		return goal
	var side := -1.0 if a.x < 0.0 else 1.0
	var fwd := b.z < a.z
	var z := a.z + (-6.0 if fwd else 6.0)
	if (z < b.z) if fwd else (z > b.z):
		z = b.z + (-1.0 if fwd else 1.0)
	return Vector3(side * (DETOUR_SIDE + r), a.y, z).rotated(Vector3.UP, yaw) + ship_pos


## Дальше этого от точки корабля (м) обход не нужен; сбоку обходим на DETOUR_SIDE + r от оси (нос 13,6 м шириной + 0,6).
const DETOUR_NEAR := 40.0
const DETOUR_SIDE := HullPlan.NOSE_W / 2.0 + 0.6


## Задевает ли отрезок a → b (оси корабля) корпус, раздутый на r: точки через 0,5 м, без последних 2 м.
static func segment_hits(a: Vector3, b: Vector3, r: float) -> bool:
	var d := b - a
	var reach := d.length() - 2.0
	if reach <= 0.0:
		return false
	var dir := d.normalized()
	var list := shapes(r)
	var s := 0.0
	while s <= reach:
		var l := a + dir * s
		if l.distance_to(CENTER) <= REACH + r and _shape_at(l, list) != null:
			return true
		s += 0.5
	return false


## Наружу из детали в осях корабля: градиент её единичной формы, повёрнутый обратно (по осям — делённый на размер).
static func _normal(sh: Shape, l: Vector3) -> Vector3:
	var u := sh.to_unit * (l - sh.pos)
	var g := u
	match sh.form:
		HullPlan.Form.CAPSULE:
			g = Vector3(u.x, u.y - clampf(u.y, -0.5, 0.5), u.z)
		HullPlan.Form.FRUSTUM:
			g = Vector3(u.x, 0.0, u.z)
	if g.length_squared() < 1e-8:
		return Vector3.UP
	var n := sh.to_ship * g
	return n.normalized() if n.length_squared() > 1e-12 else Vector3.UP


## Оси корабля — запасные пути наружу: нормаль единичной формы не метрическая (корпус сплюснут, капсула длинная),
## поэтому из глубины берём кратчайший из выходов по нормали и по шести осям.
const AXES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
## Выходы по семи путям сравниваем с точностью COARSE (м), точно (FINE) досчитываем только лучший — прежде каждый
## путь делили пополам 14 раз, и рыбка внутри корпуса стоила ~0,25 мс на ПК (issue #653).
const COARSE := 0.05
const FINE := 0.001


## Где по пути l + n·t кончается корпус (детали list): [внутри, снаружи] — сначала удваиваем шаг, потом делим
## отрезок пополам, пока он длиннее tol. Не дальше limit: путь, что заведомо длиннее, — INF.
static func _bracket(l: Vector3, n: Vector3, list: Array, limit: float, tol: float) -> Vector2:
	var lo := 0.0
	var hi := 0.5
	while _shape_at(l + n * hi, list) != null:
		lo = hi
		hi *= 2.0
		if lo >= limit:
			return Vector2(INF, INF)
	return _narrow(l, n, list, Vector2(lo, hi), limit, tol)


static func _narrow(l: Vector3, n: Vector3, list: Array, at: Vector2, limit: float, tol: float) -> Vector2:
	var lo := at.x
	var hi := at.y
	while hi - lo > tol:
		var mid := (lo + hi) * 0.5
		if _shape_at(l + n * mid, list) != null:
			lo = mid
			if lo >= limit:
				return Vector2(INF, INF)
		else:
			hi = mid
	return Vector2(lo, hi)


## Вытолкнуть точку (оси корабля) из корпуса с запасом r. Пусто — точка снаружи; иначе [новая точка, нормаль].
## Путь наружу — кратчайший из выходов по нормали детали и по шести осям.
static func push_local(l: Vector3, r: float) -> Array:
	if l.distance_to(CENTER) > REACH + r:
		return []
	var list := shapes(r)
	var n := Vector3.ZERO
	var moved := false
	for i in TRIES:
		var sh := _shape_at(l, list)
		if sh == null:
			break
		var best := _normal(sh, l)
		var best_at := _bracket(l, best, list, 64.0, COARSE)
		for ax in AXES:
			var at := _bracket(l, ax, list, best_at.y, COARSE)
			if at.y < best_at.y:
				best_at = at
				best = ax
		var t := _narrow(l, best, list, best_at, INF, FINE).y if best_at.y < INF else best_at.y
		n = best
		l += n * (t + 0.01)
		moved = true
	return [l, n] if moved else []


## Вытолкнуть точку мира p из корпуса корабля с запасом r (S.pushOut). Пусто — точка снаружи, ничего не делали;
## иначе [новая точка мира, нормаль корпуса в мире].
static func push_out(p: Vector3, ship_pos: Vector3, yaw: float, r: float) -> Array:
	var far := BOUND + r
	if p.distance_squared_to(ship_pos) > far * far:
		return [] # дальше корпуса при любом курсе — без поворота в оси корабля
	var res := push_local(to_ship(p, ship_pos, yaw), r)
	if res.is_empty():
		return res
	return [(res[0] as Vector3).rotated(Vector3.UP, yaw) + ship_pos, (res[1] as Vector3).rotated(Vector3.UP, yaw)]


## Вытолкнуть существо: место наружу, часть скорости внутрь корпуса гасится. true — было внутри.
static func push_agent(a: EcoAgent, ship_pos: Vector3, yaw: float, r: float, kill_velocity := true) -> bool:
	var res := push_out(a.p, ship_pos, yaw, r)
	if res.is_empty():
		return false
	a.p = res[0]
	if kill_velocity:
		var n: Vector3 = res[1]
		var vn := a.v.dot(n)
		if vn < 0.0:
			a.v -= n * vn
	return true
