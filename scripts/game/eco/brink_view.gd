class_name BrinkView
extends MeshInstance3D
## Кварцевая корка у Спуска 10 в сцене (#832, часть 3; данные — `EcoBrink`): каждая друза — 3…5 шестигранных
## кристаллов с острой верхушкой, наклонённых от общего корня, низ утоплен в дно. Один меш, один материал (общий
## шейдер камня `EcoShaders.STONE` — нового шейдера нет), один вызов отрисовки, рамка — по друзам (вдали от 10
## отсекается). Бледный камень; кончики светятся холодным светом в альфе вершинного цвета, к востоку ярче.
## Без источников света, слой отмели, без тени.
## «Экономно» (`set_lite`, Б6): в друзе не больше LITE_CRYSTALS кристаллов (самый высокий и первые наклонные —
## расклад тот же), грани — LITE_SIDES; треугольников вдвое меньше, меш пересобирается, вызов тот же; сброс мира
## уровень не теряет.

const FILL := 0.45
const ROUGH := 0.35
const SPEC := 0.5
## Кварц у основания и у кончика, свечение кончиков.
const QUARTZ := Color("5f7488")
const TIP := Color("b9cde0")
const LIGHT := Color("9fbcff")
## Кристаллов в друзе, граней кристалла; толщина (доля размера); наибольший наклон от вертикали, рад; насколько
## утоплен низ, м; доля длины под верхушку.
const CRYSTALS := Vector2i(3, 5)
const SIDES := 6
const THICK := Vector2(0.12, 0.22)
const LEAN := 0.6
const SINK := 0.3
const POINT := 0.28
## «Экономно»: кристаллов в друзе не больше, граней кристалла.
const LITE_CRYSTALS := 3
const LITE_SIDES := 4

var brink: EcoBrink
## Вершины по треугольникам (мир), нормали, число треугольников, сколько вершин светится.
var verts := PackedVector3Array()
var normals := PackedVector3Array()
var tris := 0
var glowing := 0
## «Экономно» (set_lite).
var lite := false

var _col := PackedColorArray()


func _init(system: EcoBrink, lite_on := false) -> void:
	brink = system
	name = "Граница у спуска"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lite = lite_on
	_build()


## «Экономно»: меньше кристаллов и граней; назад — полная корка.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	_build()


func _build() -> void:
	verts.clear()
	normals.clear()
	_col.clear()
	glowing = 0
	var roots := PackedVector3Array()
	for d in brink.druses.size():
		_druse(d)
		var v := brink.druses[d]
		roots.append(Vector3(v.x, v.y, v.z))
	tris = verts.size() / 3
	if tris == 0:
		mesh = null
		return
	var m := EcoMM.tris(verts, normals, _col)
	m.surface_set_material(0, EcoShaders.stone(LIGHT, FILL, ROUGH, SPEC))
	mesh = m
	custom_aabb = EcoMM.frame(roots, EcoBrink.MAX_H + 2.0)


## Друза d: кристаллы от общего корня.
func _druse(d: int) -> void:
	var v := brink.druses[d]
	var s := brink.shares[d]
	var r := v.w
	var rnd := EcoRandom.new(9100 + d * 7)
	var n := CRYSTALS.x + rnd.index(CRYSTALS.y - CRYSTALS.x + 1)
	var root := Vector3(v.x, v.y - SINK, v.z)
	var keep := mini(n, LITE_CRYSTALS) if lite else n
	for c in n:
		# первый — самый высокий и почти прямой, остальные ниже и наклонены в стороны
		var lean := (0.15 if c == 0 else rnd.range_f(0.25, 1.0)) * LEAN
		var turn := rnd.range_f(0.0, TAU)
		var dir := Vector3(sin(lean) * cos(turn), cos(lean), sin(lean) * sin(turn))
		var length := r * EcoBrink.TALL * (1.0 if c == 0 else rnd.range_f(0.45, 0.85))
		var off := Vector3(cos(turn), 0.0, sin(turn)) * r * rnd.range_f(0.0, 0.35)
		var thick := r * rnd.range_f(THICK.x, THICK.y)
		var spin := rnd.range_f(0.0, TAU)
		if c < keep:   # случайные числа тянем и за пропущенные — расклад тот же
			_crystal(root + off, dir, length, thick, spin, EcoBrink.glow(s))


## Кристалл: шестигранная призма от base вдоль dir (длина с верхушкой — length + SINK), верхушка — пирамида.
func _crystal(base: Vector3, dir: Vector3, length: float, w: float, spin: float, glow: float) -> void:
	var side := dir.cross(Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP).normalized()
	side = side.rotated(dir, spin)
	var other := dir.cross(side)
	var full := length + SINK
	var shoulder := base + dir * full * (1.0 - POINT)
	var tip := base + dir * full
	var low := PackedVector3Array()
	var high := PackedVector3Array()
	var sides := LITE_SIDES if lite else SIDES
	for i in sides:
		var a := TAU * i / sides
		var o := (side * cos(a) + other * sin(a)) * w
		low.append(base + o)
		high.append(shoulder + o)
	var mid := base + dir * full * 0.5
	for i in sides:
		var j := (i + 1) % sides
		_tri(low[i], low[j], high[j], mid, QUARTZ, TIP, 0.0, 0.0, full, base, dir)
		_tri(low[i], high[j], high[i], mid, QUARTZ, TIP, 0.0, 0.0, full, base, dir)
		_tri(high[i], high[j], tip, shoulder, QUARTZ, TIP, glow * 0.3, glow, full, base, dir)


## Треугольник лицом от точки inside; цвет и свечение — по высоте вдоль кристалла (от 0 у основания к 1 у кончика).
func _tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, low_col: Color, high_col: Color, low_glow: float,
		high_glow: float, full: float, base: Vector3, dir: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	# лицевая сторона — обход по часовой стрелке (CLAUDE.md): (b − a) × (c − a) смотрит внутрь
	if cr.dot((a + b + c) / 3.0 - inside) > 0.0:
		var t := b
		b = c
		c = t
		cr = -cr
	var nrm := -cr.normalized()
	for p in [a, b, c]:
		var h := clampf((p - base).dot(dir) / full, 0.0, 1.0)
		var col := low_col.lerp(high_col, h).srgb_to_linear()
		var g := lerpf(low_glow, high_glow, clampf((h - 1.0 + POINT) / POINT, 0.0, 1.0))
		if g > 0.0:
			glowing += 1
		verts.append(p)
		normals.append(nrm)
		_col.append(Color(col.r, col.g, col.b, g))
