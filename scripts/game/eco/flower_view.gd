class_name FlowerView
extends MeshInstance3D
## Каменный цветок в сцене по ART-027 (`docs/concept-art/kamennyy-tsvetok.md`): весь коралл с цоколем — один меш,
## один вызов отрисовки. Ствол и ветви — шестигранные усечённые конусы (нижние ярусы шире и сплюснуты), снизу
## #63465C, в кроне #D06A94, поры — пятнами в шейдере (без дыр в сетке и без текстуры); кончики — вытянутые
## многогранники #FFD6EC, светятся только они и мерцают волной снизу вверх (EcoFlower.glow — в шейдере по TIME,
## фаза кончика — в UV.x, доля свечения — в альфе цвета). Цоколь — камни #245B70 и трубочки, матовые, без пор
## (UV.y = 1). Без источника света: OmniLight в Compatibility перерисовал бы дно ещё раз. Слой отмели.

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 tip_glow : source_color;
uniform vec3 body_glow : source_color;
uniform float glow_mid;
uniform float glow_amp;
uniform float glow_rate;
varying float lit;
varying vec3 wp;
void vertex() {
	lit = COLOR.a * (glow_mid + glow_amp * sin(TIME * glow_rate + UV.x));
	wp = VERTEX;
}
void fragment() {
	vec3 p = wp;
	float s = sin(p.x * 4.1 + 1.3 * sin(p.y * 2.3)) * sin(p.y * 3.7 + 1.1 * sin(p.z * 2.9))
		* sin(p.z * 4.3 + 1.2 * sin(p.x * 1.9));
	float pore = smoothstep(0.4, 0.55, s) * (1.0 - step(0.5, COLOR.a)) * (1.0 - UV.y);
	ALBEDO = COLOR.rgb * (1.0 - 0.45 * pore);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	EMISSION = tip_glow * lit * 1.8 + body_glow * (1.0 - UV.y);
}
"""

## Краски (ART-027): ветви #D06A94, у подножия #63465C, кончики #FFD6EC, камень цоколя #245B70 (верх светлее); при ярком свете
## сквозь лёд светлые краски выгорают в белый — кончик гуще, свечение розовое.
const BODY := Color("d06a94")
const BODY_LOW := Color("63465c")
const TIP_PAINT := Color("e7a2c4")
const TIP_GLOW := Color("ff9fd0")
const BODY_GLOW := Color("200810")
const STONE := Color("245b70")
## Верх камня светлее — так цоколь читается на тёмном дне.
const STONE_TOP := Color("3a7088")
## Граней у ветви и у кончика по кругу; ярусы ветвей до этого сплюснуты (шире вбок в FLAT раз, тоньше в 1/FLAT).
const SIDES := 6
const TIP_SIDES := 6
const FLAT_DEPTH := 2
const FLAT := 1.3
## Кончик вдоль оси: кольца (доля половины длины, доля толщины).
const TIP_RINGS := [Vector2(-0.55, 0.6), Vector2(0.1, 1.0), Vector2(0.6, 0.7)]

var flower: EcoFlower
## Вершины по треугольникам (для тестов) и число треугольников.
var verts := PackedVector3Array()
var normals := PackedVector3Array()
var tris := 0

var _col := PackedColorArray()
var _uv := PackedVector2Array()


func _init(system: EcoFlower) -> void:
	flower = system
	name = "Каменный цветок"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if flower.branches.is_empty():
		return
	for b in flower.branches:
		_branch(b, _paint(b.p0.y), _paint(b.p1.y), 0.0)
	for t in flower.tubes:
		_branch(t, BODY_LOW, BODY_LOW.lerp(BODY, 0.3), 1.0)
	for st in flower.stones:
		_stone(st)
	for i in flower.tips.size():
		_tip(flower.tips[i], flower.tip_dir[i], flower.tip_r[i], flower.tip_phase[i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = _col
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(SHADER)
	mat.set_shader_parameter("tip_glow", TIP_GLOW)
	mat.set_shader_parameter("body_glow", BODY_GLOW)
	mat.set_shader_parameter("glow_mid", EcoFlower.GLOW_MID)
	mat.set_shader_parameter("glow_amp", EcoFlower.GLOW_AMP)
	mat.set_shader_parameter("glow_rate", EcoFlower.GLOW_RATE)
	m.surface_set_material(0, mat)
	mesh = m
	tris = verts.size() / 3


## Краска ветви на высоте y: у дна #63465C, к кроне — #D06A94.
func _paint(y: float) -> Color:
	return BODY_LOW.lerp(BODY, clampf((y - flower.base.y) / (EcoFlower.HEIGHT * 0.6), 0.0, 1.0))


## Ветвь: шестигранная боковая стенка от p0 к p1 и крышка сверху (низ уходит в родителя или в дно). Нижние ярусы
## (1…FLAT_DEPTH) сплюснуты: шире поперёк, тоньше вдоль вилки. stone — 1: без пор (цоколь).
func _branch(b: EcoFlower.Branch, c0: Color, c1: Color, stone: float) -> void:
	var axis := (b.p1 - b.p0).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 1e-4:
		side = axis.cross(Vector3(0.3, 0.1, 1.0))
	side = side.normalized()
	var up := side.cross(axis).normalized()
	var wide := FLAT if b.depth >= 1 and b.depth <= FLAT_DEPTH else 1.0
	var mid := (b.p0 + b.p1) * 0.5
	for k in SIDES:
		var a0 := TAU * k / SIDES
		var a1 := TAU * (k + 1) / SIDES
		var d0 := side * cos(a0) * wide + up * sin(a0) / wide
		var d1 := side * cos(a1) * wide + up * sin(a1) / wide
		var q0 := b.p0 + d0 * b.r0
		var q1 := b.p0 + d1 * b.r0
		var w0 := b.p1 + d0 * b.r1
		var w1 := b.p1 + d1 * b.r1
		_tri(q0, q1, w1, mid, [c0, c0, c1], 0.0, 0.0, stone)
		_tri(q0, w1, w0, mid, [c0, c1, c1], 0.0, 0.0, stone)
		_tri(w0, w1, b.p1 + axis * b.r1 * 0.3, b.p1 - axis * b.r1, [c1, c1, c1], 0.0, 0.0, stone)


## Камень цоколя: шестигранная призма (стенки и верх; низ в дне).
func _stone(st: EcoFlower.Stone) -> void:
	var mid := st.c + Vector3(0, st.h * 0.5, 0)
	var top := st.c + Vector3(0, st.h, 0)
	var lo := STONE.darkened(0.25)
	var paints := [lo, lo, STONE_TOP]
	for k in 6:
		var a0 := st.turn + TAU * k / 6.0
		var a1 := st.turn + TAU * (k + 1) / 6.0
		var d0 := Vector3(cos(a0), 0, sin(a0)) * st.r
		var d1 := Vector3(cos(a1), 0, sin(a1)) * st.r
		_tri(st.c + d0, st.c + d1, top + d1 * 0.8, mid, paints, 0.0, 0.0, 1.0)
		_tri(st.c + d0, top + d1 * 0.8, top + d0 * 0.8, mid, [lo, STONE_TOP, STONE_TOP], 0.0, 0.0, 1.0)
		_tri(top + d0 * 0.8, top + d1 * 0.8, top, mid, [STONE_TOP, STONE_TOP, STONE_TOP], 0.0, 0.0, 1.0)


## Кончик: вытянутый многогранник вдоль dir (острия на концах, три кольца по TIP_SIDES), светится с фазой ph.
func _tip(c: Vector3, dir: Vector3, half: float, ph: float) -> void:
	var side := dir.cross(Vector3(0.3, 0.1, 1.0)).normalized()
	var up := side.cross(dir).normalized()
	var w := half * EcoFlower.TIP_WIDTH
	var rings: Array[PackedVector3Array] = []
	for j in TIP_RINGS.size():
		var rg: Vector2 = TIP_RINGS[j]
		var row := PackedVector3Array()
		for i in TIP_SIDES:
			var a := TAU * i / TIP_SIDES + (0.5 if j % 2 == 1 else 0.0)
			row.append(c + dir * rg.x * half + (side * cos(a) + up * sin(a)) * rg.y * w)
		rings.append(row)
	var lo := c - dir * half
	var hi := c + dir * half
	var paint := [TIP_PAINT, TIP_PAINT, TIP_PAINT]
	var last := TIP_RINGS.size() - 1
	for i in TIP_SIDES:
		var i2 := (i + 1) % TIP_SIDES
		_tri(lo, rings[0][i], rings[0][i2], c, paint, 1.0, ph, 0.0)
		_tri(hi, rings[last][i], rings[last][i2], c, paint, 1.0, ph, 0.0)
		for j in last:
			_tri(rings[j][i], rings[j][i2], rings[j + 1][i], c, paint, 1.0, ph, 0.0)
			_tri(rings[j][i2], rings[j + 1][i2], rings[j + 1][i], c, paint, 1.0, ph, 0.0)


## Треугольник с плоской нормалью наружу от center. Лицевая сторона — обход по часовой стрелке, если смотреть на неё:
## (b − a) × (c − a) смотрит внутрь (CLAUDE.md); если наоборот — меняем b и c.
func _tri(a: Vector3, b: Vector3, c: Vector3, center: Vector3, paints: Array, glow: float, ph: float, stone: float) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	if cr.dot((a + b + c) / 3.0 - center) > 0.0:
		var t := b
		b = c
		c = t
		var tp: Color = paints[1]
		paints = [paints[0], paints[2], tp]
		cr = -cr
	var n := -cr.normalized()
	var pts := [a, b, c]
	for k in 3:
		verts.append(pts[k])
		normals.append(n)
		# краска — в линейном цвете (вершинный цвет шейдер берёт как есть), альфа — доля свечения
		var p: Color = (paints[k] as Color).srgb_to_linear()
		_col.append(Color(p.r, p.g, p.b, glow))
		_uv.append(Vector2(ph, stone))
