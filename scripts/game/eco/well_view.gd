class_name WellView
extends Node3D
## Световой колодец в сцене по ART-031: трещина-маска прямо под льдом (рваный светлый эллипс 12 × 3 м и ореол,
## лицом вниз), столб света — одна открытая наклонная оболочка от трещины до дна без торцов, мягкая альфа по краю
## (по углу к взгляду) и к низу, тёплая сердцевина #F4E9CF у льда переходит в #9AD9E8 у дна; пятно мха — свой
## MossView. Три вызова отрисовки, без источников света и объёмного тумана; яркость дышит ± 5 % за 10 с в шейдере.
## Слой отмели.

const CRACK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform float pulse;
uniform float period;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float k = 1.0 + pulse * sin(TAU * TIME / period);
	// маска медленно дрейфует: светлые полосы ползут вдоль трещины
	float drift = 0.94 + 0.06 * sin(TIME * 0.35 + dot(wp.xz, vec2(0.45, 0.2)));
	ALBEDO = COLOR.rgb * k * drift;
	ALPHA = clamp(COLOR.a, 0.0, 1.0);
}
"""

const COLUMN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float pulse;
uniform float period;
uniform float strength;
void fragment() {
	float k = 1.0 + pulse * sin(TAU * TIME / period);
	// мягкий край: грань под острым углом к взгляду почти прозрачна, без яркого контура
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = COLOR.rgb * k;
	ALPHA = clamp(COLOR.a * face * face * strength * k, 0.0, 1.0);
}
"""

## Палитра художника (svetovoy-kolodets.md).
const CORE := Color("f4e9cf")
const SCATTER := Color("9ad9e8")
const ICE := Color("86bccb")
## Непрозрачность столба у льда и у дна; общий множитель.
const ALPHA_TOP := 1.0
const ALPHA_LOW := 0.3
const STRENGTH := 0.45

var well: EcoWell
var crack: MeshInstance3D
var column: MeshInstance3D
## Мох колодца — свой меш пятен (EcoWell.moss), один вызов отрисовки.
var moss_view: MossView
## Вершины по треугольникам (для тестов) и число треугольников.
var crack_verts := PackedVector3Array()
var column_verts := PackedVector3Array()
var tris := 0


func _init(system: EcoWell) -> void:
	well = system
	name = "Световой колодец"
	if well.moss == null:
		return
	crack = _instance("Трещина во льду", _crack_mesh(), CRACK_SHADER)
	column = _instance("Столб света", _column_mesh(), COLUMN_SHADER)
	(column.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("strength", STRENGTH)
	tris = (crack_verts.size() + column_verts.size()) / 3
	moss_view = MossView.new(well.moss, well.ground)
	moss_view.name = "Мох колодца"
	add_child(moss_view)


func _instance(title: String, m: ArrayMesh, code: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = title
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = code
	mat.shader = sh
	mat.set_shader_parameter("pulse", EcoWell.PULSE)
	mat.set_shader_parameter("period", EcoWell.PERIOD)
	m.surface_set_material(0, mat)
	mi.mesh = m
	add_child(mi)
	return mi


static func _mesh(verts: PackedVector3Array, cols: PackedColorArray,
		norms := PackedVector3Array()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	if not norms.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = norms
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Треугольник лицом вниз (смотрим снизу): обход по часовой стрелке, если смотреть снизу.
func _down(out: PackedVector3Array, cols: PackedColorArray, a: Vector3, b: Vector3, c: Vector3,
		ca: Color, cb: Color, cc: Color) -> void:
	# (b − a) × (c − a) должно смотреть внутрь — вверх, от зрителя под льдом
	if (b - a).cross(c - a).y < 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
	out.append_array([a, b, c])
	cols.append_array([ca, cb, cc])


## Трещина: веер от середины до рваного края (светлая сердцевина) и кольцо ореола, гаснущее наружу.
func _crack_mesh() -> ArrayMesh:
	var cols := PackedColorArray()
	var mid := Color(CORE, 1.0)
	var rim := Color(CORE.lerp(SCATTER, 0.35), 0.85)
	var halo := Color(ICE, 0.0)
	var n := EcoWell.CRACK_PTS
	for i in n:
		var j := (i + 1) % n
		var a := well.crack_point(i)
		var b := well.crack_point(j)
		_down(crack_verts, cols, well.top, a, b, mid, rim, rim)
		var ha := well.crack_point(i, EcoWell.HALO)
		var hb := well.crack_point(j, EcoWell.HALO)
		_down(crack_verts, cols, a, ha, hb, rim, halo, halo)
		_down(crack_verts, cols, a, hb, b, rim, halo, rim)
	return _mesh(crack_verts, cols)


## Столб: кольца от трещины до дна, между соседними — по два треугольника на сторону; торцов нет. Нормали —
## гладкие, от оси наружу: по ним край тает плавно, без видимых граней.
func _column_mesh() -> ArrayMesh:
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var rings := EcoWell.RINGS
	for k in rings - 1:
		var s0 := float(k) / float(rings - 1)
		var s1 := float(k + 1) / float(rings - 1)
		var c0 := Color(CORE.lerp(SCATTER, s0), lerpf(ALPHA_TOP, ALPHA_LOW, s0))
		var c1 := Color(CORE.lerp(SCATTER, s1), lerpf(ALPHA_TOP, ALPHA_LOW, s1))
		for j in EcoWell.SIDES:
			var j1 := (j + 1) % EcoWell.SIDES
			var a := well.column_point(k, j)
			var b := well.column_point(k, j1)
			var c := well.column_point(k + 1, j)
			var d := well.column_point(k + 1, j1)
			# лицом наружу: (b − a) × (c − a) смотрит внутрь, к оси столба
			column_verts.append_array([a, c, b, b, c, d])
			cols.append_array([c0, c1, c0, c0, c1, c1])
			var na := _radial(k, j)
			var nb := _radial(k, j1)
			var nc := _radial(k + 1, j)
			var nd := _radial(k + 1, j1)
			norms.append_array([na, nc, nb, nb, nc, nd])
	return _mesh(column_verts, cols, norms)


## Нормаль оболочки в точке кольца k, стороны j: горизонтально от оси столба.
func _radial(k: int, j: int) -> Vector3:
	var s := float(k) / float(EcoWell.RINGS - 1)
	var r := well.column_point(k, j) - well.top.lerp(well.base, s)
	r.y = 0.0
	return r.normalized()
