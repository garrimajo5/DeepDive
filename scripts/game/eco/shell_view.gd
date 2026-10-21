class_name ShellView
extends MeshInstance3D
## Раковина древних в сцене (js/world.js): витки и кольца знаков — один меш, один вызов отрисовки. Витки —
## многогранные шары #CDBBA1 (к середине спирали темнее), кольца — тонкие торы #C79BFF, светятся сами и загораются
## по очереди от середины наружу (EcoShell.glow — в шейдере по TIME, номер кольца — в UV.x, доля свечения — в альфе
## цвета). Без источника света: OmniLight в Compatibility перерисовал бы дно ещё раз. Слой отмели (OceanView.LAYER_WORLD).

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 ring_glow : source_color;
uniform float glow_low;
uniform float glow_rate;
uniform float glow_wave;
varying float lit;
void vertex() {
	lit = COLOR.a * (glow_low + (1.0 - glow_low) * max(0.0, sin(TIME * glow_rate - UV.x * glow_wave)));
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.6;
	SPECULAR = 0.35;
	EMISSION = ring_glow * lit * 1.6;
}
"""

## Краски: витки #CDBBA1 (в середине спирали темнее), кольца #C79BFF.
const BODY := Color("cdbba1")
const BODY_CORE := Color("6e6152")
const RING_PAINT := Color("5a4478")
const RING_GLOW := Color("c79bff")
## Граней шара по кругу и ярусов; граней тора по кругу и по сечению.
const SIDES := 8
const ROWS := 6
const RING_SEGS := 40
const RING_SIDES := 5

var shell: EcoShell
## Вершины по треугольникам (для тестов) и число треугольников.
var verts := PackedVector3Array()
var normals := PackedVector3Array()
var tris := 0

var _col := PackedColorArray()
var _uv := PackedVector2Array()


func _init(system: EcoShell) -> void:
	shell = system
	name = "Раковина древних"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if shell.coils.is_empty():
		return
	var n := shell.coils.size()
	for i in n:
		_ball(shell.coils[i], shell.coil_r[i], BODY_CORE.lerp(BODY, sqrt(float(i) / (n - 1))))
	for k in shell.ring_c.size():
		_ring(k)
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
	mat.set_shader_parameter("ring_glow", RING_GLOW)
	mat.set_shader_parameter("glow_low", EcoShell.GLOW_LOW)
	mat.set_shader_parameter("glow_rate", EcoShell.GLOW_RATE)
	mat.set_shader_parameter("glow_wave", EcoShell.GLOW_WAVE)
	m.surface_set_material(0, mat)
	mesh = m
	tris = verts.size() / 3


## Шар витка: SIDES по кругу × ROWS ярусов, ось — нормаль лицевой стороны раковины.
func _ball(c: Vector3, r: float, paint: Color) -> void:
	var ax := shell.face()
	var sx := shell.basis * Vector3.RIGHT
	var sy := shell.basis * Vector3.UP
	var rows: Array[PackedVector3Array] = []
	for j in ROWS + 1:
		var lat := PI * float(j) / ROWS - PI * 0.5
		var row := PackedVector3Array()
		for i in SIDES:
			var a := TAU * i / SIDES + (PI / SIDES if j % 2 == 1 else 0.0)
			row.append(c + (sx * cos(a) * cos(lat) + sy * sin(a) * cos(lat) + ax * sin(lat)) * r)
		rows.append(row)
	var p := [paint, paint, paint]
	for j in ROWS:
		for i in SIDES:
			var i2 := (i + 1) % SIDES
			if j > 0:
				_tri(rows[j][i], rows[j][i2], rows[j + 1][i], c, p, 0.0, 0.0)
			if j < ROWS - 1:
				_tri(rows[j][i2], rows[j + 1][i2], rows[j + 1][i], c, p, 0.0, 0.0)


## Кольцо знаков k: тор RING_SEGS × RING_SIDES в плоскости лицевой стороны, светится с номером k.
func _ring(k: int) -> void:
	var c := shell.ring_c[k]
	var big := shell.ring_r[k]
	var tube := EcoShell.RING_TUBE * EcoShell.SCALE
	var ax := shell.face()
	var sx := shell.basis * Vector3.RIGHT
	var sy := shell.basis * Vector3.UP
	var p := [RING_PAINT, RING_PAINT, RING_PAINT]
	for s in RING_SEGS:
		var a0 := TAU * s / RING_SEGS
		var a1 := TAU * (s + 1) / RING_SEGS
		var d0 := sx * cos(a0) + sy * sin(a0)
		var d1 := sx * cos(a1) + sy * sin(a1)
		var m0 := c + d0 * big
		var m1 := c + d1 * big
		for q in RING_SIDES:
			var b0 := TAU * q / RING_SIDES
			var b1 := TAU * (q + 1) / RING_SIDES
			var q00 := m0 + (d0 * cos(b0) + ax * sin(b0)) * tube
			var q01 := m0 + (d0 * cos(b1) + ax * sin(b1)) * tube
			var q10 := m1 + (d1 * cos(b0) + ax * sin(b0)) * tube
			var q11 := m1 + (d1 * cos(b1) + ax * sin(b1)) * tube
			var mid := (m0 + m1) * 0.5
			_tri(q00, q10, q11, mid, p, 1.0, float(k))
			_tri(q00, q11, q01, mid, p, 1.0, float(k))


## Треугольник с плоской нормалью наружу от center. Лицевая сторона — обход по часовой стрелке, если смотреть на неё:
## (b − a) × (c − a) смотрит внутрь (CLAUDE.md); если наоборот — меняем b и c.
func _tri(a: Vector3, b: Vector3, c: Vector3, center: Vector3, paints: Array, glow: float, k: float) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	if cr.dot((a + b + c) / 3.0 - center) > 0.0:
		var t := b
		b = c
		c = t
		cr = -cr
	var n := -cr.normalized()
	var pts := [a, b, c]
	for i in 3:
		verts.append(pts[i])
		normals.append(n)
		# краска — в линейном цвете (вершинный цвет шейдер берёт как есть), альфа — доля свечения
		var col: Color = (paints[i] as Color).srgb_to_linear()
		_col.append(Color(col.r, col.g, col.b, glow))
		_uv.append(Vector2(k, 0.0))
