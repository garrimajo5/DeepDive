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

## «Экономно» (Б6): ветви и кончики — четыре грани вместо шести, камни у подножия — пять граней одним поясом
## (двойная пирамидка: низ всё равно в грунте). Расклад, размеры, краски и части те же — случайные числа не зависят
## от граней.
const LITE_SIDES := 4
const LITE_STONE_SIDES := 5

## Части вершин.
enum Part { BODY, TIP, STONE }


## Сетка одного куста (подножие в нуле, вверх +Y).
class Form:
	extends RefCounted
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var parts := PackedInt32Array()
	var tris := PackedInt32Array()
	var branch_count := 0
	var tip_count := 0


## Полная форма куста (поля — её копии, для мира и тестов) и грубая для «Экономно».
static var full: Form
static var lite: Form
static var verts := PackedVector3Array()
static var normals := PackedVector3Array()
static var colors := PackedColorArray()
static var parts := PackedInt32Array()
static var tris := PackedInt32Array()
## Сколько ветвей (со стволом) и кончиков.
static var branch_count := 0
static var tip_count := 0

## Форма, которую сейчас собираем, и её грани.
static var _f: Form
static var _sides := SIDES


static func _static_init() -> void:
	full = _build(SIDES, SIDES, SIDES, false)
	lite = _build(LITE_SIDES, LITE_SIDES, LITE_STONE_SIDES, true)
	verts = full.verts
	normals = full.normals
	colors = full.colors
	parts = full.parts
	tris = full.tris
	branch_count = full.branch_count
	tip_count = full.tip_count


## Форма для уровня графики: на «Экономно» — грубая.
static func form(on_lite: bool) -> Form:
	return lite if on_lite else full


static func _add(p: Vector3, n: Vector3, c: Color, pt: int) -> int:
	_f.verts.append(p)
	_f.normals.append(n)
	_f.colors.append(c)
	_f.parts.append(pt)
	return _f.verts.size() - 1


## Треугольник по правилу Godot: (b − a) × (c − a) смотрит к center.
static func _tri(a: int, b: int, c: int, center: Vector3) -> void:
	var v := _f.verts
	var n := (v[b] - v[a]).cross(v[c] - v[a])
	var mid := (v[a] + v[b] + v[c]) / 3.0 - center
	if n.dot(mid) > 0.0:
		var s := b
		b = c
		c = s
	_f.tris.append_array([a, b, c])


## Ветвь — усечённый конус от p0 (радиус r0) к p1 (r1) с крышкой сверху; дно уходит в родителя.
static func _branch(p0: Vector3, p1: Vector3, r0: float, r1: float, c0: Color, c1: Color) -> void:
	_f.branch_count += 1
	var n := _sides
	var axis := (p1 - p0).normalized()
	var side := axis.cross(Vector3(0.3, 0, 1)).normalized()
	var up := side.cross(axis).normalized()
	var a0 := _f.verts.size()
	for k in n:
		var a := TAU * k / n
		var d := side * cos(a) + up * sin(a)
		_add(p0 + d * r0, d, c0, Part.BODY)
		_add(p1 + d * r1, d, c1, Part.BODY)
	for k in n:
		var i := a0 + k * 2
		var j := a0 + ((k + 1) % n) * 2
		var mid := (p0 + p1) * 0.5
		_tri(i, j, i + 1, mid)
		_tri(j, j + 1, i + 1, mid)
	var cap := _add(p1 + axis * r1 * 0.3, axis, c1, Part.BODY)
	for k in n:
		_tri(a0 + k * 2 + 1, a0 + ((k + 1) % n) * 2 + 1, cap, p1 - axis * r1)


## Кончик или камень — сплющенный по оси многогранник: пояса rings (доли радиуса вдоль оси) по sides граней и
## две вершины-полюса.
static func _blob(c: Vector3, axis: Vector3, r: float, color: Color, pt: int, squash: float, sides: int,
		rings: Array[float]) -> void:
	var side := axis.cross(Vector3(0.3, 0, 1)).normalized()
	var up := side.cross(axis).normalized()
	var a0 := _f.verts.size()
	for y in rings:
		var rr := r * sqrt(1.0 - y * y)
		for k in sides:
			var a := TAU * k / sides
			var d := (side * cos(a) + up * sin(a)) * rr + axis * y * r * squash
			_add(c + d, d.normalized(), color, pt)
	var bot := _add(c - axis * r * squash, -axis, color, pt)
	var top := _add(c + axis * r * squash, axis, color, pt)
	for ring in rings.size() - 1:
		for k in sides:
			var i := a0 + ring * sides + k
			var j := a0 + ring * sides + (k + 1) % sides
			_tri(i, j, i + sides, c)
			_tri(j, j + sides, i + sides, c)
	var last := a0 + (rings.size() - 1) * sides
	for k in sides:
		_tri(a0 + k, a0 + (k + 1) % sides, bot, c)
		_tri(last + k, last + (k + 1) % sides, top, c)


## Направление с наклоном tilt от dir в сторону азимута a.
static func _lean(dir: Vector3, tilt: float, a: float) -> Vector3:
	var side := dir.cross(Vector3(0.3, 0, 1)).normalized()
	var up := side.cross(dir).normalized()
	return (dir * cos(tilt) + (side * cos(a) + up * sin(a)) * sin(tilt)).normalized()


## Собрать куст: грани ветвей, кончиков и камней; flat_stones — камни одним поясом.
static func _build(sides: int, tip_sides: int, stone_sides: int, flat_stones: bool) -> Form:
	_f = Form.new()
	_sides = sides
	var three: Array[float] = [-0.7, 0.0, 0.7]
	var one: Array[float] = [0.0]
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
			_blob(e2 + d2 * 0.14, d2, rnd.range_f(0.22, 0.28), TIP, Part.TIP, 1.3, tip_sides, three)
			_f.tip_count += 1
	# камни у подножия
	for k in 5:
		var a := TAU * k / 5.0 + rnd.range_f(-0.3, 0.3)
		var r := rnd.range_f(0.45, 0.75)
		var c := Vector3(cos(a), 0, sin(a)) * rnd.range_f(0.5, 0.9)
		_blob(c, Vector3.UP, r, STONE, Part.STONE, 0.6, stone_sides, one if flat_stones else three)
	var f := _f
	_f = null
	return f


## Расстановка куста в мире.
static func transform(b: EcoCoral.Bush) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, b.yaw).scaled(Vector3.ONE * b.scale), b.base)
