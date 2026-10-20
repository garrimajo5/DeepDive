class_name FlowerView
extends MeshInstance3D
## Каменный цветок в сцене (js/world.js): весь коралл — один меш, один вызов отрисовки. Ветви — шестигранные
## усечённые конусы (снизу темнее, к кончикам светлее, #D06A94 с тёплым подсветом #200810, как в браузере),
## кончики — многогранники #FFD6EC, светятся сами и мерцают волной снизу вверх (EcoFlower.glow — в шейдере по TIME,
## фаза кончика — в UV.x, доля свечения — в альфе цвета). Без источника света: OmniLight в Compatibility
## перерисовал бы дно ещё раз. Слой отмели (OceanView.LAYER_WORLD).

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 tip_glow : source_color;
uniform vec3 body_glow : source_color;
uniform float glow_mid;
uniform float glow_amp;
uniform float glow_rate;
varying float lit;
void vertex() {
	lit = COLOR.a * (glow_mid + glow_amp * sin(TIME * glow_rate + UV.x));
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	EMISSION = tip_glow * lit * 1.4 + body_glow;
}
"""

## Краски: ветви #D06A94 (у подножия темнее), кончики #FFD6EC; при ярком свете сквозь лёд светлые краски выгорают
## в белый — кончик гуще, свечение розовое.
const BODY := Color("d06a94")
const BODY_LOW := Color("5a2a48")
const TIP_PAINT := Color("e7a2c4")
const TIP_GLOW := Color("ff9fd0")
const BODY_GLOW := Color("200810")
## Граней у ветви, у кончика — граней по кругу и ярусов.
const SIDES := 6
const TIP_SIDES := 6
const TIP_RINGS := 4

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
		_branch(b)
	for i in flower.tips.size():
		_tip(flower.tips[i], flower.tip_r[i], flower.tip_phase[i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = _col
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("tip_glow", TIP_GLOW)
	mat.set_shader_parameter("body_glow", BODY_GLOW)
	mat.set_shader_parameter("glow_mid", EcoFlower.GLOW_MID)
	mat.set_shader_parameter("glow_amp", EcoFlower.GLOW_AMP)
	mat.set_shader_parameter("glow_rate", EcoFlower.GLOW_RATE)
	m.surface_set_material(0, mat)
	mesh = m
	tris = verts.size() / 3


## Краска ветви на высоте y: у дна темнее, к кроне — #D06A94.
func _paint(y: float) -> Color:
	return BODY_LOW.lerp(BODY, clampf((y - flower.base.y) / (EcoFlower.HEIGHT * 0.6), 0.0, 1.0))


## Ветвь: шестигранная боковая стенка от p0 к p1 и крышка сверху (низ уходит в родителя или в дно).
func _branch(b: EcoFlower.Branch) -> void:
	var axis := (b.p1 - b.p0).normalized()
	var side := axis.cross(Vector3(0.3, 0.1, 1.0)).normalized()
	var up := side.cross(axis).normalized()
	var mid := (b.p0 + b.p1) * 0.5
	var c0 := _paint(b.p0.y)
	var c1 := _paint(b.p1.y)
	for k in SIDES:
		var a0 := TAU * k / SIDES
		var a1 := TAU * (k + 1) / SIDES
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var q0 := b.p0 + d0 * b.r0
		var q1 := b.p0 + d1 * b.r0
		var w0 := b.p1 + d0 * b.r1
		var w1 := b.p1 + d1 * b.r1
		_tri(q0, q1, w1, mid, [c0, c0, c1], 0.0, 0.0)
		_tri(q0, w1, w0, mid, [c0, c1, c1], 0.0, 0.0)
		_tri(w0, w1, b.p1 + axis * b.r1 * 0.3, b.p1 - axis * b.r1, [c1, c1, c1], 0.0, 0.0)


## Кончик: многогранник (TIP_SIDES по кругу × TIP_RINGS ярусов), светится с фазой ph.
func _tip(c: Vector3, r: float, ph: float) -> void:
	var rings: Array[PackedVector3Array] = []
	for j in TIP_RINGS + 1:
		var lat := PI * float(j) / TIP_RINGS - PI * 0.5
		var row := PackedVector3Array()
		for i in TIP_SIDES:
			var a := TAU * i / TIP_SIDES + (0.5 if j % 2 == 1 else 0.0)
			row.append(c + Vector3(cos(lat) * cos(a), sin(lat), cos(lat) * sin(a)) * r)
		rings.append(row)
	var paint := [TIP_PAINT, TIP_PAINT, TIP_PAINT]
	for j in TIP_RINGS:
		for i in TIP_SIDES:
			var i2 := (i + 1) % TIP_SIDES
			if j > 0:
				_tri(rings[j][i], rings[j][i2], rings[j + 1][i], c, paint, 1.0, ph)
			if j < TIP_RINGS - 1:
				_tri(rings[j][i2], rings[j + 1][i2], rings[j + 1][i], c, paint, 1.0, ph)


## Треугольник с плоской нормалью наружу от center. Лицевая сторона — обход по часовой стрелке, если смотреть на неё:
## (b − a) × (c − a) смотрит внутрь (CLAUDE.md); если наоборот — меняем b и c.
func _tri(a: Vector3, b: Vector3, c: Vector3, center: Vector3, paints: Array, glow: float, ph: float) -> void:
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
		_uv.append(Vector2(ph, 0.0))
