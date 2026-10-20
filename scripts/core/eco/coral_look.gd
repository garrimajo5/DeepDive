class_name EcoCoralLook
extends RefCounted
## Как выглядит огнецвет (ART-004, `flora-otmeli-vidy.png`): толстый сине-фиолетовый ствол, ветви вилкой в два яруса
## (12–18 ветвей), на концах — 8–12 оранжевых утолщений-кончиков, у подножия — камни. Высота около 4 м. Форма одна
## на все кусты (своё зерно), куст поворачивается и масштабируется по EcoCoral.Bush. Сцена складывает все кусты в один
## меш (CoralView): номер куста — в UV.x, кончик — UV.y = 1 (светится, гаснет по EcoCoral.Bush.glow).
## Грани — по правилу Godot: (b − a) × (c − a) смотрит внутрь части.

const SIDES := 6
## Краски по палитре ART-004: ствол и ветви — сине-фиолетовые, кончики #F6AE55, камни #245B70.
const BODY := Color("3c3f9e")
const BODY_DARK := Color("2a2a74")
const TIP := Color("F6AE55")
const STONE := Color("245B70")
## Своё зерно формы.
const SEED := 4004

## Части вершин.
enum Part { BODY, TIP, STONE }

## Форма одного куста (подножие в нуле, вверх +Y).
static var verts := PackedVector3Array()
static var normals := PackedVector3Array()
static var colors := PackedColorArray()
static var parts := PackedInt32Array()
static var tris := PackedInt32Array()
## Сколько ветвей (со стволом) и кончиков.
static var branch_count := 0
static var tip_count := 0


static func _static_init() -> void:
	_build()


static func _add(p: Vector3, n: Vector3, c: Color, pt: int) -> int:
	verts.append(p)
	normals.append(n)
	colors.append(c)
	parts.append(pt)
	return verts.size() - 1


## Треугольник по правилу Godot: (b − a) × (c − a) смотрит к center.
static func _tri(a: int, b: int, c: int, center: Vector3) -> void:
	var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	var mid := (verts[a] + verts[b] + verts[c]) / 3.0 - center
	if n.dot(mid) > 0.0:
		var s := b
		b = c
		c = s
	tris.append_array([a, b, c])


## Ветвь — усечённый конус от p0 (радиус r0) к p1 (r1) с крышкой сверху; дно уходит в родителя.
static func _branch(p0: Vector3, p1: Vector3, r0: float, r1: float, c0: Color, c1: Color) -> void:
	branch_count += 1
	var axis := (p1 - p0).normalized()
	var side := axis.cross(Vector3(0.3, 0, 1)).normalized()
	var up := side.cross(axis).normalized()
	var a0 := verts.size()
	for k in SIDES:
		var a := TAU * k / SIDES
		var d := side * cos(a) + up * sin(a)
		_add(p0 + d * r0, d, c0, Part.BODY)
		_add(p1 + d * r1, d, c1, Part.BODY)
	for k in SIDES:
		var i := a0 + k * 2
		var j := a0 + ((k + 1) % SIDES) * 2
		var mid := (p0 + p1) * 0.5
		_tri(i, j, i + 1, mid)
		_tri(j, j + 1, i + 1, mid)
	var cap := _add(p1 + axis * r1 * 0.3, axis, c1, Part.BODY)
	for k in SIDES:
		_tri(a0 + k * 2 + 1, a0 + ((k + 1) % SIDES) * 2 + 1, cap, p1 - axis * r1)


## Кончик — сплющенный по оси ветви многогранник (октаэдр, разбитый на 4 × 2 яруса).
static func _blob(c: Vector3, axis: Vector3, r: float, color: Color, pt: int, squash := 1.3) -> void:
	var side := axis.cross(Vector3(0.3, 0, 1)).normalized()
	var up := side.cross(axis).normalized()
	var a0 := verts.size()
	var rings: Array[float] = [-0.7, 0.0, 0.7]
	for y in rings:
		var rr := r * sqrt(1.0 - y * y)
		for k in SIDES:
			var a := TAU * k / SIDES
			var d := (side * cos(a) + up * sin(a)) * rr + axis * y * r * squash
			_add(c + d, d.normalized(), color, pt)
	var bot := _add(c - axis * r * squash, -axis, color, pt)
	var top := _add(c + axis * r * squash, axis, color, pt)
	for ring in 2:
		for k in SIDES:
			var i := a0 + ring * SIDES + k
			var j := a0 + ring * SIDES + (k + 1) % SIDES
			_tri(i, j, i + SIDES, c)
			_tri(j, j + SIDES, i + SIDES, c)
	for k in SIDES:
		_tri(a0 + k, a0 + (k + 1) % SIDES, bot, c)
		_tri(a0 + 2 * SIDES + k, a0 + 2 * SIDES + (k + 1) % SIDES, top, c)


## Направление с наклоном tilt от dir в сторону азимута a.
static func _lean(dir: Vector3, tilt: float, a: float) -> Vector3:
	var side := dir.cross(Vector3(0.3, 0, 1)).normalized()
	var up := side.cross(dir).normalized()
	return (dir * cos(tilt) + (side * cos(a) + up * sin(a)) * sin(tilt)).normalized()


static func _build() -> void:
	verts.clear()
	normals.clear()
	colors.clear()
	parts.clear()
	tris.clear()
	branch_count = 0
	tip_count = 0
	var rnd := EcoRandom.new(SEED)
	# ствол
	var trunk_top := Vector3(0, 1.5, 0)
	_branch(Vector3(0, -0.2, 0), trunk_top, 0.42, 0.3, BODY_DARK, BODY)
	# первый ярус: пять ветвей вилкой
	for k in 5:
		var a := TAU * k / 5.0 + rnd.range_f(-0.25, 0.25)
		var d1 := _lean(Vector3.UP, rnd.range_f(0.5, 0.8), a)
		var e1 := trunk_top + d1 * rnd.range_f(1.2, 1.5)
		_branch(trunk_top - d1 * 0.15, e1, 0.26, 0.17, BODY, BODY)
		# второй ярус: две-три веточки с кончиками
		var n := 3 if k % 3 == 0 else 2
		for j in n:
			var b := a + (j - (n - 1) * 0.5) * 1.4 + rnd.range_f(-0.2, 0.2)
			var d2 := _lean(d1, rnd.range_f(0.3, 0.55), b)
			d2 = (d2 + Vector3.UP * 0.45).normalized()
			var e2 := e1 + d2 * rnd.range_f(0.8, 1.1)
			_branch(e1 - d2 * 0.08, e2, 0.15, 0.1, BODY, BODY)
			_blob(e2 + d2 * 0.14, d2, rnd.range_f(0.22, 0.28), TIP, Part.TIP)
			tip_count += 1
	# камни у подножия
	for k in 5:
		var a := TAU * k / 5.0 + rnd.range_f(-0.3, 0.3)
		var r := rnd.range_f(0.45, 0.75)
		var c := Vector3(cos(a), 0, sin(a)) * rnd.range_f(0.5, 0.9)
		_blob(c, Vector3.UP, r, STONE, Part.STONE, 0.6)


## Расстановка куста в мире.
static func transform(b: EcoCoral.Bush) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, b.yaw).scaled(Vector3.ONE * b.scale), b.base)
