class_name ShellView
extends MeshInstance3D
## Раковина древних в сцене по ART-029: трубка спирали с бороздами, разлом внешней губы с рваным краем и тёмной
## изнанкой, пластина колец с линией родства и прямой «канон», контактные гнёзда по три, осыпь у подножия —
## один меш, один материал, один вызов отрисовки, плоские грани (камень). Архив матовый: светятся только
## кустики обрастания #67DDEB в бороздах и у дна — альфа вершинного цвета в том же материале; камню —
## слабая подсветка FILL, чтобы светлый минерал читался в мути отмели. Без источников света, слой отмели.

## Подсветка камня, шероховатость и блик — в общем шейдере камня (EcoShaders.STONE).
const FILL := 0.3
const ROUGH := 0.92
const SPEC := 0.2

## Палитра художника (rakovina-drevnih.md).
const MINERAL := Color("82979c")
const MASS := Color("425c68")
const FURROW := Color("263e4c")
const RELIEF_PAINT := Color("a8b5ad")
const GROWTH := Color("67ddeb")
const DEEP := Color("0b1c24")
## Рельеф пластины: ширина дуги колец и линии родства, почки; лунки гнёзд — шестиугольники.
const RING_W := 0.12
const KIN_W := 0.2
const KIN_H := 0.16
const BUD := 0.2
const NEST_SIDES := 6

var shell: EcoShell
## Вершины по треугольникам (мир, для тестов), нормали и число треугольников.
var verts := PackedVector3Array()
var normals := PackedVector3Array()
var tris := 0
## Треугольников со светом обрастания.
var glowing := 0
## Сколько треугольников у трубки (первые в verts) и ряд каждого — для проверки граней наружу.
var tube_tris := 0
var tube_row := PackedInt32Array()

var _col := PackedColorArray()


func _init(system: EcoShell) -> void:
	shell = system
	name = "Раковина древних"
	layers = OceanView.LAYER_WORLD
	EcoShadows.cast(self)
	if shell.ring.is_empty():
		return
	_tube()
	tube_tris = verts.size() / 3
	_lip()
	_plate()
	_caps()
	_nests()
	_rocks()
	_tufts()
	var m := EcoMM.tris(verts, normals, _col)
	m.surface_set_material(0, EcoShaders.stone(GROWTH, FILL, ROUGH, SPEC))
	mesh = m
	tris = verts.size() / 3


static func _hash(i: int, j: int) -> float:
	return fposmod(sin(float(i * 57 + j * 13) * 78.233) * 43758.5453, 1.0)


## Трубка: SECTIONS − 1 рядов × SIDES граней, кроме снятых разломом; грань наружу от оси трубки.
func _tube() -> void:
	var n := EcoShell.SECTIONS
	for i in n - 1:
		var axis := shell.surface((shell.theta[i] + shell.theta[i + 1]) * 0.5, 0.0, 0.0)
		var depth := sqrt(float(i) / (n - 2))
		for j in EcoShell.SIDES:
			if shell.broken(i, j):
				continue
			var j2 := (j + 1) % EcoShell.SIDES
			var a := shell.vertex(i, j)
			var b := shell.vertex(i, j2)
			var c := shell.vertex(i + 1, j2)
			var d := shell.vertex(i + 1, j)
			var paint := MASS.lerp(MINERAL, 0.55 + 0.45 * depth).lerp(RELIEF_PAINT, _hash(i, j) * 0.45)
			if EcoShell.groove(i):
				paint = MASS.lerp(FURROW, 0.5 + 0.3 * _hash(j, i))
			var out := (a + b + c + d) * 0.25 - axis
			_quad(a, b, c, d, out, paint, 0.0)
			while tube_row.size() < verts.size() / 3:
				tube_row.append(i)


## Изнанка рваного края: у оставшейся передней стенки разлома — тёмная внутренняя сторона.
func _lip() -> void:
	for i in range(shell.break_from, shell.break_to):
		var axis := shell.surface((shell.theta[i] + shell.theta[i + 1]) * 0.5, 0.0, 0.0)
		for j in EcoShell.SIDES:
			var m := (j + 0.5) * TAU / EcoShell.SIDES
			if sin(m) <= 0.0 or shell.broken(i, j):
				continue
			var j2 := (j + 1) % EcoShell.SIDES
			var a := shell.vertex(i, j)
			var b := shell.vertex(i, j2)
			var c := shell.vertex(i + 1, j2)
			var d := shell.vertex(i + 1, j)
			_quad(a, b, c, d, axis - (a + b + c + d) * 0.25, DEEP.lerp(FURROW, 0.5), 0.0)


## Пластина колец в разломе: полосы к лицу, дуги колец, линия родства с почками и прямая «канон».
func _plate() -> void:
	var h := EcoShell.plate_half()
	var rows := shell.break_to - shell.break_from
	for r in rows:
		var s0 := float(r) / rows
		var s1 := float(r + 1) / rows
		for q in 2:
			var u0 := lerpf(-h, h, q * 0.5)
			var u1 := lerpf(-h, h, (q + 1) * 0.5)
			_quad(shell.plate_point(s0, u0), shell.plate_point(s0, u1), shell.plate_point(s1, u1),
				shell.plate_point(s1, u0), Vector3.BACK, MASS.lerp(MINERAL, 0.35 - 0.2 * q), 0.0)
		for u in EcoShell.PLATE_RINGS:
			_ridge(shell.plate_point(s0, u * h), shell.plate_point(s1, u * h), RING_W, EcoShell.RELIEF,
				MINERAL.lerp(MASS, 0.3))
	for k in EcoShell.KIN:
		var a := shell.plate_point(k.x, k.y)
		var b := shell.plate_point(k.z, k.w)
		_ridge(a, b, KIN_W, KIN_H, RELIEF_PAINT)
		if absf(k.w) > 0.15 or k.z >= 0.7:
			_bud(shell.plate_point(k.z, k.w, KIN_H * 0.5))
	_ridge(shell.plate_point(EcoShell.CANON_S, -0.85 * h), shell.plate_point(EcoShell.CANON_S, 0.85 * h),
		KIN_W * 0.7, KIN_H, RELIEF_PAINT)


## Торцы: края разлома (половина сечения над пластиной), конец трубки и середина спирали.
func _caps() -> void:
	var h := EcoShell.plate_half()
	for side in 2:
		var i := shell.break_from if side == 0 else shell.break_to
		var s := 0.0 if side == 0 else 1.0
		var th := shell.theta[i]
		var along := shell.surface(th + 0.05, 0.0, 0.0) - shell.surface(th - 0.05, 0.0, 0.0)
		var into := along if side == 0 else -along
		var pts: Array[Vector3] = [shell.plate_point(s, h)]
		for j in range(1, EcoShell.SIDES / 2):
			pts.append(shell.vertex(i, j))
		pts.append(shell.plate_point(s, -h))
		var mid := shell.plate_point(s, 0.0)
		for q in pts.size() - 1:
			_tri(mid, pts[q], pts[q + 1], into, DEEP.lerp(FURROW, 0.4), 0.0)
	for end in [0, EcoShell.SECTIONS - 1]:
		var th: float = shell.theta[end]
		var along := shell.surface(th + 0.05, 0.0, 0.0) - shell.surface(th - 0.05, 0.0, 0.0)
		var out := along if end > 0 else -along
		var mid := shell.surface(th, 0.0, 0.0)
		for j in EcoShell.SIDES:
			_tri(mid, shell.vertex(end, j), shell.vertex(end, (j + 1) % EcoShell.SIDES), out, FURROW, 0.0)


## Контактные гнёзда: тёмные шестиугольные лунки, чуть над поверхностью.
func _nests() -> void:
	for q in shell.nest_c.size():
		var n := shell.nest_n[q]
		var c := shell.nest_c[q] + n * 0.03
		var t1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := n.cross(t1)
		for s in NEST_SIDES:
			var a0 := TAU * s / NEST_SIDES
			var a1 := TAU * (s + 1) / NEST_SIDES
			_tri(c, c + (t1 * cos(a0) + t2 * sin(a0)) * EcoShell.NEST_R,
				c + (t1 * cos(a1) + t2 * sin(a1)) * EcoShell.NEST_R, n, DEEP, 0.0)


## Осыпь: октаэдры с дрожью (мир → оси раковины, весь меш строится в осях раковины).
func _rocks() -> void:
	for q in shell.rock_c.size():
		var c := shell.to_local(shell.rock_c[q])
		var r := shell.rock_r[q]
		var k := [Vector3(r * (0.9 + _hash(q, 1) * 0.5), 0, 0), Vector3(0, r * (0.6 + _hash(q, 2) * 0.3), 0),
			Vector3(0, 0, r * (0.8 + _hash(q, 3) * 0.5))]
		var paint := MINERAL.lerp(FURROW, 0.3 + 0.5 * _hash(q, 4))
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var a: Vector3 = c + k[0] * sx
					var b: Vector3 = c + k[1] * sy
					var d: Vector3 = c + k[2] * sz
					_tri(a, b, d, (a + b + d) / 3.0 - c, paint, 0.0)


## Обрастание: кустик из трёх тонких лопастей, светится (альфа 1) — единственный свет архива.
func _tufts() -> void:
	for q in shell.tuft_c.size():
		var c := shell.tuft_c[q]
		var n := shell.tuft_n[q]
		var t1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := n.cross(t1)
		var h := EcoShell.TUFT_H * (0.6 + 0.8 * _hash(q, 7))
		for k in 3:
			var a := TAU * k / 3.0 + _hash(q, 8) * 2.0
			var side := t1 * cos(a) + t2 * sin(a)
			var tip := c + n * h + side * h * 0.35
			var w := (t1 * -sin(a) + t2 * cos(a)) * 0.05
			_tri(c - w, c + w, tip, side, GROWTH, 1.0)
			_tri(c - w, c + w, tip, -side, GROWTH, 1.0)


## Валик рельефа a → b на пластине: две наклонные грани, ширина w, высота h (к лицу).
func _ridge(a: Vector3, b: Vector3, w: float, h: float, paint: Color) -> void:
	var side := (b - a).cross(Vector3.BACK).normalized() * w * 0.5
	var up := Vector3.BACK * h
	_quad(a - side, b - side, b + up, a + up, -side + up * 0.5, paint, 0.0)
	_quad(a + side, b + side, b + up, a + up, side + up * 0.5, paint, 0.0)


## Почка на конце ветви: четырёхгранная пирамидка.
func _bud(c: Vector3) -> void:
	var top := c + Vector3.BACK * BUD
	for s in 4:
		var a0 := TAU * s / 4.0 + PI / 4.0
		var a1 := TAU * (s + 1) / 4.0 + PI / 4.0
		var p0 := c + Vector3(cos(a0), sin(a0), 0.0) * BUD
		var p1 := c + Vector3(cos(a1), sin(a1), 0.0) * BUD
		_tri(p0, p1, top, (p0 + p1) * 0.5 - c + Vector3.BACK * BUD * 0.3, RELIEF_PAINT, 0.0)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, paint: Color, glow: float) -> void:
	_tri(a, b, c, out, paint, glow)
	_tri(a, c, d, out, paint, glow)


## Треугольник (оси раковины) с плоской нормалью в сторону out, в мир. Лицевая сторона — обход по часовой
## стрелке, если смотреть на неё: (b − a) × (c − a) смотрит внутрь (CLAUDE.md); если наоборот — меняем b и c.
func _tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, paint: Color, glow: float) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	if cr.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		cr = -cr
	var n := shell.basis * (-cr.normalized())
	var col := paint.srgb_to_linear()   # вершинный цвет шейдер берёт как есть
	for p in [a, b, c]:
		verts.append(shell.to_world(p))
		normals.append(n)
		_col.append(Color(col.r, col.g, col.b, glow))
	if glow > 0.0:
		glowing += 1
