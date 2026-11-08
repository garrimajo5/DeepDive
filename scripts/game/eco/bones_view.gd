class_name BonesView
extends MeshInstance3D
## Кости левиафана в сцене по ART-030: 16 гнутых шестигранных рёбер, позвонки поверх вершин и хвост дугой вбок,
## череп на боку с окнами (сквозь окна видна тёмная изнанка), нижняя челюсть — один меш, один материал, один
## вызов отрисовки, плоские грани. Кость матовая: светятся только кустики обрастания #67DDEB — альфа вершинного
## цвета в том же материале; кости — подсветка FILL (выше, чем у раковины: отвесные рёбра в тени от света сверху), чтобы светлый известняк читался в мути отмели.
## Без источников света, слой отмели.
## «Экономно» (Б6, `set_lite`): рёбра и челюсть — пять граней вместо шести, тела позвонков — четыре, отростки —
## трёхгранные пирамидки (LITE_*); меш пересобирается, череп с окнами, обрастание, материал, вызов, мох и силуэт те же.
## Сброс мира уровень не теряет (EcoView.set_lite).

## Подсветка камня, шероховатость и блик — в общем шейдере камня (EcoShaders.STONE).
const FILL := 0.45
const ROUGH := 0.95
const SPEC := 0.15

## Палитра художника (kosti-leviafana.md).
const LIME := Color("b7c4c3")
const HALF := Color("829da2")
const SHADE := Color("58717a")
const CAVITY := Color("2b4856")
const GROWTH := Color("67ddeb")
## Позвонок: длина тела (доля шага), остистый отросток вверх и поперечные вбок (доли радиуса).
const VERT_LEN := 1.1
const SPINOUS := 1.7
const TRANSVERSE := 1.9
## Граней по кругу: тело позвонка, челюсть; на «Экономно» — рёбра, челюсть, тело позвонка.
const VERT_SIDES := 6
const JAW_SIDES := 6
const LITE_RIB_SIDES := 5
const LITE_JAW_SIDES := 5
const LITE_VERT_SIDES := 4

var bones: EcoBones
## Вершины по треугольникам (мир, для тестов), нормали и число треугольников.
var verts := PackedVector3Array()
var normals := PackedVector3Array()
var tris := 0
## Треугольников со светом обрастания; сколько треугольников у рёбер (первые в verts) и у черепа.
var glowing := 0
var rib_tris := 0
var skull_tris := 0

var _col := PackedColorArray()
## Мох у ног рёбер — свой меш пятен (EcoBones.moss), один вызов отрисовки.
var moss_view: MossView
## На «Экономно» — грубее сетка (set_lite).
var lite := false
var _mat: Material


func _init(system: EcoBones, on_lite := false) -> void:
	bones = system
	lite = on_lite
	name = "Кости левиафана"
	layers = OceanView.LAYER_WORLD
	EcoShadows.cast(self)
	if bones.rib_pts.is_empty():
		return
	_mat = EcoShaders.stone(GROWTH, FILL, ROUGH, SPEC)
	_build()
	if bones.moss:
		moss_view = MossView.new(bones.moss, bones.ground, lite)
		moss_view.name = "Мох на костях"
		add_child(moss_view)


## «Экономно» — меш пересобран грубее (тот же материал); назад — полный.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	if moss_view:
		moss_view.set_lite(on)
	if _mat:
		_build()


func _build() -> void:
	verts.clear()
	normals.clear()
	_col.clear()
	glowing = 0
	_ribs()
	rib_tris = verts.size() / 3
	_spine()
	var before := verts.size() / 3
	_skull()
	skull_tris = verts.size() / 3 - before
	_jaw()
	_tufts()
	var m := EcoMM.tris(verts, normals, _col)
	m.surface_set_material(0, _mat)
	mesh = m
	tris = verts.size() / 3


static func _hash(i: int, j: int) -> float:
	return fposmod(sin(float(i * 57 + j * 13) * 78.233) * 43758.5453, 1.0)


## Рёбра: шестигранная трубка по осевой линии, у ноги темнее (тень и ил), к вершине — светлый известняк.
func _ribs() -> void:
	var n := EcoBones.rib_points()
	for r in EcoBones.PAIRS * 2:
		var pts: Array[Vector3] = []
		var rad: Array[float] = []
		var paint: Array[Color] = []
		for i in n:
			pts.append(bones.rib_point(r, i))
			rad.append(bones.rib_radius(r, i))
			var up := float(i) / (n - 1)
			paint.append(SHADE.lerp(HALF, minf(1.0, up * 2.0)).lerp(LIME, maxf(0.0, up * 1.6 - 0.6))
				.lerp(HALF, _hash(r, i) * 0.25))
		_tube(pts, rad, paint, LITE_RIB_SIDES if lite else EcoBones.RIB_SIDES, Vector3(0, 0, 1), false, true)


## Позвонки: тело — шестигранный цилиндр вдоль хребта, остистый отросток вверх и два поперечных — пирамидки.
func _spine() -> void:
	for v in bones.vert_c.size():
		var c := bones.vert_c[v]
		var r := bones.vert_r[v]
		var d := bones.vert_dir[v]
		var step := 1.85 if v < EcoBones.SPINE_N else 1.0
		if v >= EcoBones.SPINE_N:
			var prev := bones.vert_c[0 if v == EcoBones.SPINE_N else v - 1]
			step = c.distance_to(prev)
		var half := minf(step * 0.5 * VERT_LEN, r * 2.2) * 0.5 + r * 0.35
		var paint := LIME.lerp(HALF, 0.15 + _hash(v, 3) * 0.35)
		_tube([c - d * half, c + d * half], [r, r], [paint, paint], LITE_VERT_SIDES if lite else VERT_SIDES, Vector3.UP,
			true, false)
		var up := (Vector3.UP - d * d.dot(Vector3.UP)).normalized()
		var side := d.cross(up).normalized()
		_spike(c + up * r * 0.7, up, r * SPINOUS, r * 0.45, d, paint)
		for s in [-1.0, 1.0]:
			_spike(c + side * s * r * 0.7, side * s - up * 0.25, r * TRANSVERSE, r * 0.35, d, paint.lerp(SHADE, 0.2))


## Череп: наружная оболочка без окон, изнанка (тёмная, лицом внутрь) и срезы по краю окон.
func _skull() -> void:
	var rings := EcoBones.SKULL_RINGS
	var sides := EcoBones.SKULL_SIDES
	var k := EcoBones.SKULL_INNER
	for i in rings - 1:
		var u0 := EcoBones.skull_u(i)
		var u1 := EcoBones.skull_u(i + 1)
		var ax := bones.skull_point((u0 + u1) * 0.5, 0.0, 0.0)
		for j in sides:
			var p0 := TAU * j / sides
			var p1 := TAU * (j + 1) / sides
			var a := bones.skull_point(u0, p0)
			var b := bones.skull_point(u0, p1)
			var c := bones.skull_point(u1, p1)
			var d := bones.skull_point(u1, p0)
			var ia := bones.skull_point(u0, p0, k)
			var ib := bones.skull_point(u0, p1, k)
			var ic := bones.skull_point(u1, p1, k)
			var id := bones.skull_point(u1, p0, k)
			var mid := (a + b + c + d) * 0.25
			if EcoBones.window(i, j):
				# края окна: к соседней целой клетке — срез от наружной оболочки до изнанки
				var edges := [[a, b, ia, ib, i - 1, j], [b, c, ib, ic, i, j + 1], [c, d, ic, id, i + 1, j],
					[d, a, id, ia, i, j - 1]]
				for e in edges:
					var ni: int = e[4]
					var nj: int = posmod(e[5], sides)
					if ni < 0 or ni >= rings - 1 or not EcoBones.window(ni, nj):
						var em: Vector3 = (e[0] + e[1]) * 0.5
						_quad(e[0], e[1], e[3], e[2], mid - em, CAVITY.lerp(SHADE, 0.5), 0.0)
				continue
			var paint := LIME.lerp(HALF, _hash(i, j) * 0.4)
			if sin((p0 + p1) * 0.5) < -0.3:
				paint = paint.lerp(SHADE, 0.5)   # низ черепа в тени у дна
			_quad(a, b, c, d, mid - ax, paint, 0.0)
			_quad(ia, ib, ic, id, ax - mid, CAVITY, 0.0)
	# торцы: затылок и кончик носа
	for end in [0, rings - 1]:
		var u := EcoBones.skull_u(end)
		var ax := bones.skull_point(u, 0.0, 0.0)
		var out := bones.skull * Vector3(1, 0, 0) - bones.skull.origin
		if end == 0:
			out = -out
		for j in sides:
			_tri(ax, bones.skull_point(u, TAU * j / sides), bones.skull_point(u, TAU * (j + 1) / sides), out,
				HALF, 0.0)


## Нижняя челюсть: шестигранная дуга снаружи черепа.
func _jaw() -> void:
	var pts: Array[Vector3] = []
	var rad: Array[float] = []
	var paint: Array[Color] = []
	for q in bones.jaw.size():
		pts.append(bones.jaw[q])
		var t := float(q) / (bones.jaw.size() - 1)
		rad.append(EcoBones.JAW_R * (1.0 - 0.45 * t))
		paint.append(HALF.lerp(LIME, 0.4 + 0.3 * _hash(q, 5)))
	_tube(pts, rad, paint, LITE_JAW_SIDES if lite else JAW_SIDES, Vector3.UP, true, true)


## Обрастание: кустик из трёх тонких лопастей, светится (альфа 1) — единственный свет скелета.
func _tufts() -> void:
	for q in bones.tuft_c.size():
		var c := bones.tuft_c[q]
		var n := bones.tuft_n[q]
		var t1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := n.cross(t1)
		var h := EcoBones.TUFT_H * (0.6 + 0.8 * _hash(q, 7))
		for k in 3:
			var a := TAU * k / 3.0 + _hash(q, 8) * 2.0
			var side := t1 * cos(a) + t2 * sin(a)
			var tip := c + n * h + side * h * 0.35
			var w := (t1 * -sin(a) + t2 * cos(a)) * 0.06
			_tri(c - w, c + w, tip, side, GROWTH, 1.0)
			_tri(c - w, c + w, tip, -side, GROWTH, 1.0)


## Трубка по точкам: сечение sides-угольник (рамка — перенос вдоль линии от ref), грани наружу от оси;
## cap0/cap1 — закрыть начало и конец.
func _tube(pts: Array, rad: Array, paint: Array, sides: int, ref: Vector3, cap0: bool, cap1: bool) -> void:
	var rings: Array = []
	var axis := ref
	for i in pts.size():
		var t: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var u := (axis - t * t.dot(axis))
		if u.length_squared() < 1e-6:
			u = t.cross(Vector3.RIGHT)
		u = u.normalized()
		axis = u
		var v := t.cross(u)
		var ring: Array[Vector3] = []
		for j in sides:
			var a := TAU * (j + 0.5) / sides
			ring.append(pts[i] + (u * cos(a) + v * sin(a)) * float(rad[i]))
		rings.append(ring)
	for i in pts.size() - 1:
		var mid: Vector3 = (pts[i] + pts[i + 1]) * 0.5
		for j in sides:
			var j2 := (j + 1) % sides
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j2]
			var c: Vector3 = rings[i + 1][j2]
			var d: Vector3 = rings[i + 1][j]
			_quad(a, b, c, d, (a + b + c + d) * 0.25 - mid, paint[i], 0.0)
	for e in 2:
		if (e == 0 and not cap0) or (e == 1 and not cap1):
			continue
		var i := 0 if e == 0 else pts.size() - 1
		var out: Vector3 = pts[i] - pts[1 if e == 0 else pts.size() - 2]
		for j in sides - 2:
			_tri(rings[i][0], rings[i][j + 1], rings[i][j + 2], out, paint[i], 0.0)


## Отросток позвонка: пирамидка (четыре грани, на «Экономно» — три) от основания c в сторону dir, длина len, ширина w.
func _spike(c: Vector3, dir: Vector3, len: float, w: float, along: Vector3, paint: Color) -> void:
	dir = dir.normalized()
	var s1 := along.normalized() * w
	var s2 := dir.cross(along).normalized() * w * 0.6
	var tip := c + dir * len
	var base: Array[Vector3] = [c + s1, c + s2, c - s1, c - s2]
	if lite:
		base = [c + s1, c + s2, c - s1 * 0.5 - s2 * 0.6]
	var k := base.size()
	for q in k:
		var p0 := base[q]
		var p1 := base[(q + 1) % k]
		_tri(p0, p1, tip, (p0 + p1) * 0.5 - c, paint, 0.0)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, paint: Color, glow: float) -> void:
	_tri(a, b, c, out, paint, glow)
	_tri(a, c, d, out, paint, glow)


## Треугольник (оси скелета) с плоской нормалью в сторону out, в мир. Лицевая сторона — обход по часовой
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
	var n := bones.basis * (-cr.normalized())
	var col := paint.srgb_to_linear()   # вершинный цвет шейдер берёт как есть
	for p in [a, b, c]:
		verts.append(bones.to_world(p))
		normals.append(n)
		_col.append(Color(col.r, col.g, col.b, glow))
	if glow > 0.0:
		glowing += 1
