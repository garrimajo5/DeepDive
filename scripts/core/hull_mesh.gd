class_name HullMesh
## Меши корпуса «Ковчега-7» снаружи по HullPlan (ART-001): единичные формы (как Shapes.cs в pogrujenie) и сборка
## деталей одной краски в один меш — один вызов отрисовки на краску. Подвижные детали (роторы, рули глубины)
## собираются отдельно, вокруг своего центра, — их крутит сцена по HullMesh.Motion (pogrujenie Core/HullMotion.cs).
## Крышку нижнего шлюза рисует RoomsView (она же видна снаружи), здесь её нет.
## Лицевая сторона треугольника — по часовой стрелке, если смотреть на неё: (b − a) × (c − a) смотрит внутрь.

const SEG := 24
const RINGS := 10
const WINDOW_GLOW := 0.85
const LENS_GLOW := 1.0
const LOCK_GLOW := 0.45


## Детали, которые рисует корпус: все, кроме крышки шлюза.
static func drawn(part: HullPlan.Part) -> bool:
	return part.piece != HullPlan.Piece.AIRLOCK


## Подвижная деталь: своя сетка вокруг центра детали.
static func moving(part: HullPlan.Part) -> bool:
	return part.piece == HullPlan.Piece.ROTOR or part.piece == HullPlan.Piece.RUDDER


static func glow(paint: int) -> float:
	match paint:
		HullPlan.Paint.WINDOW:
			return WINDOW_GLOW
		HullPlan.Paint.LENS:
			return LENS_GLOW
		HullPlan.Paint.LOCK:
			return LOCK_GLOW
	return 0.0


## Накопитель треугольников: вершины с нормалями, порядок обхода выправляется по нормали наружу.
class Builder:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var idx := PackedInt32Array()

	func add(p: Vector3, n: Vector3) -> int:
		pos.append(p)
		nor.append(n.normalized())
		return pos.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		var n := nor[a] + nor[b] + nor[c]
		var g := (pos[b] - pos[a]).cross(pos[c] - pos[a])
		if g.dot(n) > 0.0:   # должно смотреть внутрь
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	## Добавить другой накопитель, переведя его вершины преобразованием xf (нормали — обратной транспонированной).
	func merge(o: Builder, xf: Transform3D) -> void:
		var nb := xf.basis.inverse().transposed()
		var base := pos.size()
		for i in o.pos.size():
			pos.append(xf * o.pos[i])
			nor.append((nb * o.nor[i]).normalized())
		for i in o.idx:
			idx.append(base + i)

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nor
		arr[Mesh.ARRAY_INDEX] = idx
		return arr

	func triangles() -> int:
		return idx.size() / 3


## Единичная форма HullPlan.Form (размеры — в шапке hull_plan.gd).
static func unit(form: int) -> Builder:
	var b := Builder.new()
	match form:
		HullPlan.Form.CUBE:
			_block(b, Vector3.ZERO, Vector3(0.5, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 0, 0.5))
		HullPlan.Form.SPHERE:
			_sphere(b, 0.0, PI, Vector3.ZERO)
		HullPlan.Form.CYLINDER:
			_side(b, 0.5, -1.0, 0.5, 1.0, true)
			_disc(b, 1.0, 0.5, Vector3.UP)
			_disc(b, -1.0, 0.5, Vector3.DOWN)
		HullPlan.Form.CAPSULE:
			_side(b, 0.5, -0.5, 0.5, 0.5, true)
			_sphere(b, 0.0, PI / 2.0, Vector3(0, 0.5, 0))
			_sphere(b, PI / 2.0, PI, Vector3(0, -0.5, 0))
		HullPlan.Form.DOME:   # шар Ø1, срезанный плоскостью y = −0,25 (широта 120°), срез закрыт кругом
			var cut := PI * 2.0 / 3.0
			_sphere(b, 0.0, cut, Vector3.ZERO)
			_disc(b, -0.25, 0.5 * sin(cut), Vector3.DOWN)
		HullPlan.Form.FRUSTUM:
			_side(b, 0.5, -1.0, 0.25, 1.0, true)
			_disc(b, 1.0, 0.25, Vector3.UP)
			_disc(b, -1.0, 0.5, Vector3.DOWN)
		HullPlan.Form.TUBE:   # стенка от 0,42 до 0,5
			_side(b, 0.5, -1.0, 0.5, 1.0, true)
			_side(b, 0.42, -1.0, 0.42, 1.0, false)
			for y in [1.0, -1.0]:
				_ring(b, y, 0.42, 0.5, Vector3(0, y, 0))
		HullPlan.Form.ROTOR:
			_rotor(b, 5)
		HullPlan.Form.WEDGE:
			_wedge(b)
		HullPlan.Form.PLATE:
			var n := Vector3.BACK
			b.quad(b.add(Vector3(-0.5, -0.5, 0), n), b.add(Vector3(0.5, -0.5, 0), n),
				b.add(Vector3(0.5, 0.5, 0), n), b.add(Vector3(-0.5, 0.5, 0), n))
	return b


## Неподвижные детали одной краски одним накопителем в осях корабля.
static func paint_builder(paint: int) -> Builder:
	var b := Builder.new()
	var cache := {}
	for part in HullPlan.parts():
		if part.paint != paint or not drawn(part) or moving(part):
			continue
		if not cache.has(part.form):
			cache[part.form] = unit(part.form)
		b.merge(cache[part.form], part.xform())
	return b


## Подвижная деталь в осях её центра (узел ставится в part.pos с поворотом детали).
static func part_builder(part: HullPlan.Part) -> Builder:
	var b := Builder.new()
	var xf := part.xform()
	b.merge(unit(part.form), Transform3D(xf.basis, Vector3.ZERO))
	return b


## Краски, у которых есть неподвижные детали.
static func paints() -> Array[int]:
	var out: Array[int] = []
	for part in HullPlan.parts():
		if drawn(part) and not moving(part) and not out.has(part.paint):
			out.append(part.paint)
	out.sort()
	return out


## Шаровой пояс от широты lat0 до lat1 (0 — верх, π — низ), радиус 0,5, со сдвигом c.
static func _sphere(b: Builder, lat0: float, lat1: float, c: Vector3) -> void:
	var rows := []
	for i in RINGS + 1:
		var lat := lerpf(lat0, lat1, float(i) / RINGS)
		var row := PackedInt32Array()
		for j in SEG + 1:
			var lon := TAU * j / SEG
			var n := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
			row.append(b.add(c + n * 0.5, n))
		rows.append(row)
	for r in RINGS:
		for j in SEG:
			b.quad(rows[r][j], rows[r][j + 1], rows[r + 1][j + 1], rows[r + 1][j])


static func _disc(b: Builder, y: float, r: float, n: Vector3, seg: int = SEG) -> void:
	var c := b.add(Vector3(0, y, 0), n)
	var ring := PackedInt32Array()
	for j in seg + 1:
		var lon := TAU * j / seg
		ring.append(b.add(Vector3(cos(lon) * r, y, sin(lon) * r), n))
	for j in seg:
		b.tri(c, ring[j], ring[j + 1])


static func _ring(b: Builder, y: float, ri: float, ro: float, n: Vector3) -> void:
	var o := PackedInt32Array()
	var i := PackedInt32Array()
	for j in SEG + 1:
		var lon := TAU * j / SEG
		o.append(b.add(Vector3(cos(lon) * ro, y, sin(lon) * ro), n))
		i.append(b.add(Vector3(cos(lon) * ri, y, sin(lon) * ri), n))
	for j in SEG:
		b.quad(o[j], o[j + 1], i[j + 1], i[j])


## Боковая поверхность вращения от (r0, y0) до (r1, y1); outward = false — лицом к оси.
static func _side(b: Builder, r0: float, y0: float, r1: float, y1: float, outward: bool, seg: int = SEG) -> void:
	var slope := (r0 - r1) / (y1 - y0)
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	for j in seg + 1:
		var lon := TAU * j / seg
		var n := Vector3(cos(lon), slope, sin(lon)) * (1.0 if outward else -1.0)
		lo.append(b.add(Vector3(cos(lon) * r0, y0, sin(lon) * r0), n))
		hi.append(b.add(Vector3(cos(lon) * r1, y1, sin(lon) * r1), n))
	for j in seg:
		b.quad(hi[j], hi[j + 1], lo[j + 1], lo[j])


## Брусок с центром c и полуосями u, v, w.
static func _block(b: Builder, c: Vector3, u: Vector3, v: Vector3, w: Vector3) -> void:
	var axes := [u, v, w]
	for k in 3:
		var a: Vector3 = axes[k]
		var p: Vector3 = axes[(k + 1) % 3]
		var q: Vector3 = axes[(k + 2) % 3]
		for sgn in [1.0, -1.0]:
			var n: Vector3 = a * sgn
			var f: Vector3 = c + a * sgn
			b.quad(b.add(f - p - q, n), b.add(f + p - q, n), b.add(f + p + q, n), b.add(f - p + q, n))


## Ротор в диске радиуса 0,5 толщиной 1 по y: ступица и лопасти, повёрнутые на 25° вокруг своего луча.
static func _rotor(b: Builder, blades: int) -> void:
	_side(b, 0.12, -0.5, 0.12, 0.5, true, 12)
	_disc(b, 0.5, 0.12, Vector3.UP, 12)
	_disc(b, -0.5, 0.12, Vector3.DOWN, 12)
	for k in blades:
		var a := TAU * k / blades
		var radial := Vector3(cos(a), 0, sin(a))
		var tangent := Vector3(-radial.z, 0, radial.x)
		var chord := (tangent * cos(0.44) + Vector3.UP * sin(0.44)) * 0.08
		var thick := radial.cross(chord).normalized() * 0.02
		_block(b, radial * 0.3, radial * 0.19, chord, thick)


## Клин: сечение в плоскости yz — треугольник (−z: y от −0,5 до 0,5; +z: острый край на y = 0).
static func _wedge(b: Builder) -> void:
	for x in [-0.5, 0.5]:
		var n := Vector3(x * 2.0, 0, 0)
		b.tri(b.add(Vector3(x, 0.5, -0.5), n), b.add(Vector3(x, -0.5, -0.5), n), b.add(Vector3(x, 0, 0.5), n))
	var back := Vector3.FORWARD
	b.quad(b.add(Vector3(-0.5, 0.5, -0.5), back), b.add(Vector3(0.5, 0.5, -0.5), back),
		b.add(Vector3(0.5, -0.5, -0.5), back), b.add(Vector3(-0.5, -0.5, -0.5), back))
	for y in [0.5, -0.5]:
		var n := Vector3(0, y * 2.0, 0.5)
		b.quad(b.add(Vector3(-0.5, y, -0.5), n), b.add(Vector3(0.5, y, -0.5), n),
			b.add(Vector3(0.5, 0, 0.5), n), b.add(Vector3(-0.5, 0, 0.5), n))


## Движение корпуса (pogrujenie Core/HullMotion.cs, заметки ART-001): роторы раскручиваются за тягой с запаздыванием,
## рули глубины встают за «Всплыть»/«Вниз». Без узлов.
class Motion:
	const MAX_RPS := 2.5        ## оборотов в секунду на полной тяге
	const SPIN_LAG := 1.5
	const MAX_PITCH := 25.0     ## градусов
	const PITCH_LAG := 3.0

	var spin := 0.0             ## −1…1 доля оборотов
	var rotor_angle := 0.0      ## градусы 0…360
	var pitch := 0.0            ## градусы: + — всплытие, задняя кромка руля поднята

	func reset() -> void:
		spin = 0.0
		rotor_angle = 0.0
		pitch = 0.0

	## thrust, vert — ввод пилота (−1…1), k — доля двигателей реактора.
	func update(dt: float, thrust: float, vert: float, k: float) -> void:
		if dt <= 0.0:
			return
		var target := clampf(thrust, -1.0, 1.0) * maxf(0.0, k)
		spin += (target - spin) * minf(1.0, dt * SPIN_LAG)
		rotor_angle = fposmod(rotor_angle + spin * MAX_RPS * 360.0 * dt, 360.0)
		pitch += (clampf(vert, -1.0, 1.0) * MAX_PITCH - pitch) * minf(1.0, dt * PITCH_LAG)

	## Угол ротора борта sx (−1 — левый): роторы крутятся навстречу друг другу.
	func rotor_angle_of(sx: float) -> float:
		return -rotor_angle if sx < 0.0 else rotor_angle
