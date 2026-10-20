class_name VentView
extends Node3D
## Чёрный курильщик в сцене (ART-012, docs/concept-art/kurilshchik.md): три вызова отрисовки.
## «Порода» — один меш: главная и малые трубы (усечённые конусы с неровной стенкой, плоские грани), внутренняя стенка
## и тёмное дно просвета, цоколь и две наплывные пластины; на склонах главной трубы — две минеральные ленты #C5BFA7.
## Кромки жерл и верх просвета светятся #FF8A3C с мерцанием (EcoVent.flicker — в шейдере по TIME), порода #3A2A2E
## не светится. «Пузыри» — MultiMesh квадратов лицом к камере, движутся в шейдере по формуле EcoVent.bubble_pos
## (процессор их не трогает). «Марево» — три вертикальные полупрозрачные полосы с бегущим вверх шумом над главным
## жерлом. Без источника света: OmniLight в Compatibility перерисовал бы дно ещё раз. Слой отмели (LAYER_WORLD).

const ROCK_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 heat : source_color;
void fragment() {
	float f = 0.8 + 0.1 * sin(TIME * 2.3) + 0.06 * sin(TIME * 5.7 + 1.3) + 0.04 * sin(TIME * 13.1 + 0.4);
	ALBEDO = COLOR.rgb * (1.0 - COLOR.a);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	EMISSION = heat * COLOR.a * f * 1.6;
}
"""

const BUBBLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 tint : source_color;
uniform float drift;
uniform float size_low;
uniform float size_high;
varying float alpha;
void vertex() {
	// EcoVent.bubble_pos: скорость, фаза, высота столба, своё число — в INSTANCE_CUSTOM, точка выхода — в экземпляре
	float h = INSTANCE_CUSTOM.b;
	float f = fract(INSTANCE_CUSTOM.g + TIME * INSTANCE_CUSTOM.r / h);
	float s = INSTANCE_CUSTOM.a * 6.2831853;
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 p = vec3(o.x + sin(TIME * 0.9 + s) * drift * f, o.y + f * h, o.z + cos(TIME * 0.7 + s) * drift * f);
	float size = mix(size_low, size_high, f);
	alpha = 0.85 * (1.0 - 0.6 * f) * smoothstep(0.0, 0.03, f) * (1.0 - smoothstep(0.9, 1.0, f));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size,
		INV_VIEW_MATRIX[2] * size, vec4(p, 1.0));
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	// пузырь: светлый ободок и прозрачная середина
	float ring = (1.0 - smoothstep(0.8, 1.0, d)) * (0.35 + 0.65 * smoothstep(0.45, 0.9, d));
	ALBEDO = tint;
	ALPHA = alpha * ring;
}
"""

const HAZE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 water : source_color;
uniform vec3 heat : source_color;
void fragment() {
	// мягкая взвесь: шум из синусов бежит вверх, слабеет вверх и к краям полосы
	float v = 1.0 - UV.y;
	float n = 0.5 + 0.25 * sin(UV.x * 9.0 + UV.y * 23.0 - TIME * 1.3) + 0.25 * sin(UV.x * 17.0 - UV.y * 41.0 - TIME * 2.1);
	float edge = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	ALBEDO = mix(water, heat, 0.35 * (1.0 - v));
	ALPHA = 0.11 * n * edge * pow(1.0 - v, 1.4) * smoothstep(0.0, 0.04, v);
}
"""

const ROCK := Color("3a2a2e")
const MINERAL := Color("c5bfa7")
const HEAT := Color("ff8a3c")
const BUBBLE := Color("d5e4e8")
const WATER := Color("86bccb")
## Дно просвета — почти чёрное.
const BORE_FLOOR := Color("120c0e")
## Минеральные ленты при ярком свете сквозь лёд выгорают — краска гуще.
const MINERAL_K := 0.6
## Граней у главной трубы, у малых, рядов по высоте главной (16–20 сегментов по ART-012).
const SIDES := 18
const SMALL_SIDES := 14
const ROWS := 6
const SMALL_ROWS := 3
## Неровность стенки (js: G.jitter 0,35), м; кромка и низ у дна ровные.
const JITTER := 0.3
## Марево: три полосы шириной 5 м на 16 м вверх от жерла.
const HAZE_W := 5.0
const HAZE_H := 16.0
const HAZE_STRIPS := 3
## Пузыри и марево дальше этого не рисуем (в воде их всё равно не видно).
const FAR := 160.0
## Чисел на пузырь: transform 3 × 4 и свои числа (4).
const STRIDE := 16

var vent: EcoVent
var rock: MeshInstance3D
var bubbles: MultiMeshInstance3D
var haze: MeshInstance3D
## Вершины и нормали породы по треугольникам (для тестов), число треугольников.
var verts := PackedVector3Array()
var normals := PackedVector3Array()
var tris := 0
## Буфер пузырей (для тестов).
var bubble_buffer := PackedFloat32Array()

var _col := PackedColorArray()


func _init(system: EcoVent) -> void:
	vent = system
	name = "Чёрный курильщик"
	if vent.tubes.is_empty():
		return
	_build_rock()
	_build_bubbles()
	_build_haze()


# ---------- Порода ----------

func _build_rock() -> void:
	var c0 := vent.center()
	for k in vent.tubes.size():
		var tb := vent.tubes[k]
		var main := k == 0
		_tube(tb, SIDES if main else SMALL_SIDES, ROWS if main else SMALL_ROWS, main)
	# цоколь вокруг главной трубы и пластины под малыми
	_skirt(Vector2(c0.x, c0.z), EcoVent.PLINTH[0], EcoVent.PLINTH[1], EcoVent.PLINTH[2], SIDES, 1)
	for i in EcoVent.PLATES.size():
		var tb := vent.tubes[i + 1]
		_skirt(Vector2(tb.floor_c.x, tb.floor_c.z), EcoVent.PLATES[i][0], tb.base_r * 0.9, EcoVent.PLATES[i][1],
			SMALL_SIDES, 2 + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = _col
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, _material(ROCK_SHADER, {"heat": HEAT}))
	rock = MeshInstance3D.new()
	rock.name = "Порода"
	rock.mesh = m
	_setup(rock)
	tris = verts.size() / 3


## Труба: неровная стенка от дна (уходит в него на SINK) до кромки, плоская кромка, внутренняя стенка вниз
## на глубину просвета и тёмное дно. Кромка светится; верх внутренней стенки — тоже, к низу гаснет.
func _tube(tb: EcoVent.Tube, sides: int, rows: int, main: bool) -> void:
	var cx := tb.floor_c.x
	var cz := tb.floor_c.z
	var base_y := tb.mouth.y - tb.height
	var ring: Array[PackedVector3Array] = []
	for j in rows + 1:
		var h := float(j) / rows
		var row := PackedVector3Array()
		for i in sides:
			var a := TAU * i / sides
			var r := lerpf(tb.base_r, tb.top_r, h)
			if j > 0 and j < rows:
				r += JITTER * (_hash(i * 7 + j * 131 + int(tb.height * 13.0)) - 0.5) * 2.0 * (tb.base_r / 4.0 + 0.3)
			var x := cx + cos(a) * r
			var z := cz + sin(a) * r
			var y := lerpf(base_y, tb.mouth.y, h)
			if j == 0:
				y = vent.floor_y(x, z) - EcoVent.SINK   # низ стенки — по дну, чтобы не висел на склоне
			row.append(Vector3(x, y, z))
		ring.append(row)
	for j in rows:
		for i in sides:
			var i2 := (i + 1) % sides
			var a := ring[j][i]
			var b := ring[j][i2]
			var c := ring[j + 1][i2]
			var d := ring[j + 1][i]
			var mid := (a + b + c + d) * 0.25
			var out := Vector3(mid.x - cx, 0.0, mid.z - cz).normalized()
			var paint := ROCK
			if main and _band(TAU * (i + 0.5) / sides, (j + 0.5) / rows):
				paint = MINERAL * MINERAL_K
			_quad(a, b, c, d, out, paint, 0.0)
	# кромка: кольцо от края трубы до просвета, светится
	var y_top := tb.mouth.y
	var bore_floor := y_top - tb.bore_depth
	for i in sides:
		var i2 := (i + 1) % sides
		var a0 := TAU * i / sides
		var a1 := TAU * i2 / sides
		var o0 := Vector3(cx + cos(a0) * tb.top_r, y_top, cz + sin(a0) * tb.top_r)
		var o1 := Vector3(cx + cos(a1) * tb.top_r, y_top, cz + sin(a1) * tb.top_r)
		var n0 := Vector3(cx + cos(a0) * tb.bore_r, y_top, cz + sin(a0) * tb.bore_r)
		var n1 := Vector3(cx + cos(a1) * tb.bore_r, y_top, cz + sin(a1) * tb.bore_r)
		_quad(o0, o1, n1, n0, Vector3.UP, HEAT, 1.0)
		# внутренняя стенка: лицом к оси, верх светится, ниже — темнеет
		var d0 := Vector3(n0.x, bore_floor, n0.z)
		var d1 := Vector3(n1.x, bore_floor, n1.z)
		var inward := Vector3(cx - (n0.x + n1.x) * 0.5, 0.0, cz - (n0.z + n1.z) * 0.5).normalized()
		_tri4(n0, n1, d1, d0, inward, [HEAT, HEAT, BORE_FLOOR, BORE_FLOOR], [0.8, 0.8, 0.0, 0.0])
		# тёмное дно просвета
		_tri(Vector3(cx, bore_floor, cz), d0, d1, Vector3.UP, BORE_FLOOR, 0.0)


## Наплыв у дна: низкий усечённый конус от радиуса r0 по дну до r1 на высоте h над дном (каждая вершина — по дну).
func _skirt(c: Vector2, r0: float, r1: float, h: float, sides: int, salt: int) -> void:
	for i in sides:
		var i2 := (i + 1) % sides
		var pts: Array[Vector3] = []
		for k: int in [i, i2]:
			var a := TAU * k / sides
			var w := 1.0 + 0.12 * (_hash(k * 13 + salt * 101) - 0.5)
			var lo := Vector2(c.x + cos(a) * r0 * w, c.y + sin(a) * r0 * w)
			var hi := Vector2(c.x + cos(a) * r1, c.y + sin(a) * r1)
			pts.append(Vector3(lo.x, vent.floor_y(lo.x, lo.y) - 0.3, lo.y))
			pts.append(Vector3(hi.x, vent.floor_y(hi.x, hi.y) + h, hi.y))
		var mid := (pts[0] + pts[2]) * 0.5
		var out := (Vector3(mid.x - c.x, 0.0, mid.z - c.y).normalized() + Vector3.UP * 0.6).normalized()
		_quad(pts[0], pts[2], pts[3], pts[1], out, ROCK, 0.0)
		# верх наплыва — к середине (прячется под трубой)
		var top_c := Vector3(c.x, vent.floor_y(c.x, c.y) + h, c.y)
		_tri(pts[1], pts[3], top_c, Vector3.UP, ROCK, 0.0)


## Две минеральные ленты наискосок по склону главной трубы (ART-012: «две крупные минеральные ленты на склонах»).
static func _band(a: float, h: float) -> bool:
	for k in 2:
		var u := fposmod(a / TAU + h * 0.3 + k * 0.5, 1.0)
		if absf(u - 0.2) < 0.06:
			return true
	return false


## Число 0…1 из целого — неровность стенки без случая мира.
static func _hash(n: int) -> float:
	var x := sin(float(n) * 12.9898) * 43758.5453
	return x - floor(x)


## Четырёхугольник a-b-c-d (по кругу) лицом в сторону out: два треугольника.
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, paint: Color, glow: float) -> void:
	_tri(a, b, c, out, paint, glow)
	_tri(a, c, d, out, paint, glow)


func _tri4(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, paints: Array, glows: Array) -> void:
	_tri_c(a, b, c, out, [paints[0], paints[1], paints[2]], [glows[0], glows[1], glows[2]])
	_tri_c(a, c, d, out, [paints[0], paints[2], paints[3]], [glows[0], glows[2], glows[3]])


func _tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, paint: Color, glow: float) -> void:
	_tri_c(a, b, c, out, [paint, paint, paint], [glow, glow, glow])


## Треугольник лицом в сторону out (плоская грань). Лицевая сторона — обход по часовой стрелке, если смотреть
## на неё: (b − a) × (c − a) смотрит внутрь (CLAUDE.md); если наоборот — меняем b и c.
func _tri_c(a: Vector3, b: Vector3, c: Vector3, out: Vector3, paints: Array, glows: Array) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	if cr.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		var tp: Color = paints[1]
		paints[1] = paints[2]
		paints[2] = tp
		var tg: float = glows[1]
		glows[1] = glows[2]
		glows[2] = tg
		cr = -cr
	var n := -cr.normalized()
	var pts := [a, b, c]
	for k in 3:
		verts.append(pts[k])
		normals.append(n)
		# краска — в линейном цвете (вершинный цвет шейдер берёт как есть, иначе порода выходит светлой)
		var p: Color = (paints[k] as Color).srgb_to_linear()
		# альфа цвета — доля свечения (шейдер: краска × (1 − a), жар × a)
		_col.append(Color(p.r, p.g, p.b, glows[k]))


# ---------- Пузыри ----------

func _build_bubbles() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _material(BUBBLE_SHADER, {"tint": BUBBLE, "drift": EcoVent.DRIFT,
		"size_low": EcoVent.SIZE_LOW, "size_high": EcoVent.SIZE_HIGH})
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = EcoVent.BUBBLES
	bubble_buffer.resize(EcoVent.BUBBLES * STRIDE)
	for i in EcoVent.BUBBLES:
		var o := vent.b_origin[i]
		var k := i * STRIDE
		var tr := [1.0, 0.0, 0.0, o.x, 0.0, 1.0, 0.0, o.y, 0.0, 0.0, 1.0, o.z,
			vent.b_speed[i], vent.b_phase[i], vent.b_height[i], vent.b_seed[i]]
		for q in STRIDE:
			bubble_buffer[k + q] = tr[q]
	mm.buffer = bubble_buffer
	bubbles = MultiMeshInstance3D.new()
	bubbles.name = "Пузыри"
	bubbles.multimesh = mm
	_setup(bubbles)
	# пузыри движутся в шейдере — рамка на весь столб до льда
	var m := vent.tubes[0].mouth
	bubbles.custom_aabb = AABB(Vector3(m.x - 12.0, m.y - 2.0, m.z - 12.0), Vector3(24.0, EcoVent.ICE_Y - m.y + 4.0, 24.0))
	bubbles.visibility_range_end = FAR


# ---------- Марево ----------

func _build_haze() -> void:
	var m := vent.tubes[0].mouth
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for s in HAZE_STRIPS:
		var a := PI * s / HAZE_STRIPS
		var d := Vector3(cos(a), 0.0, sin(a)) * HAZE_W * 0.5
		var v0 := v.size()
		v.append_array([m - d, m + d, m + d + Vector3.UP * HAZE_H, m - d + Vector3.UP * HAZE_H])
		uv.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		idx.append_array([v0, v0 + 1, v0 + 2, v0, v0 + 2, v0 + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material(HAZE_SHADER, {"water": WATER, "heat": HEAT}))
	haze = MeshInstance3D.new()
	haze.name = "Марево"
	haze.mesh = mesh
	_setup(haze)
	haze.visibility_range_end = FAR


func _setup(g: GeometryInstance3D) -> void:
	g.layers = OceanView.LAYER_WORLD
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)


static func _material(code: String, params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = code
	mat.shader = sh
	for k in params:
		mat.set_shader_parameter(k, params[k])
	return mat
