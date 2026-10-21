class_name VeilView
extends Node3D
## Фонарные вуали в сцене (initVeils/veilUpdate в js/creatures.js): у каждой вуали — узел на месте купола и в нём три
## вызова отрисовки. Купола — MultiMesh из полусферы: наружный голубой купол 6 м (#7ff5ff, 0,22), розовое ядро 0,6 r
## (#ff8ae0, 0,28) и девять колокольчиков по кругу (#bff8ff, 0,35); все пульсируют, кромка купола ярче (по краю
## прозрачности). Кромка — 48 огоньков-точек лицом к камере (#cffcff), мерцают. Щупальца — 40 нитей по 10 звеньев
## одним мешем линий (#ff9ae6, 0,6): колышутся в шейдере по той же формуле, что EcoVeil.tentacle_point. Купола и щупальца — общий
## шейдер прозрачного (EcoShaders.MIST). Всё без света,
## прозрачное, без записи глубины, на слое отмели (OceanView.LAYER_WORLD). Дальше FAR от корабля вуаль не видна в мути —
## узел прячется и не пересчитывается.

const RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform vec4 tint : source_color = vec4(0.81, 0.99, 1.0, 0.9);
uniform float size = 0.5;
void vertex() {
	// огонёк лицом к камере: все четыре вершины — в середине, угол — из UV
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3((UV - vec2(0.5)) * size, 0.0);
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = clamp(1.0 - d, 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * a;
}
"""

const BELL := Color("7ff5ff38")  # 0,22
const CORE := Color("ff8ae047")  # 0,28
const SMALL := Color("bff8ff59")  # 0,35
const RIM := Color("cffcff")
const TENTACLE := Color(1.0, 0.604, 0.902, 0.6)
## Ядро — 0,6 r; колокольчики — по кругу r + 1,2.
const CORE_K := 0.6
const SMALL_RING := 1.2
## Огоньков на кромке, их размер (м).
const RIM_N := 48
const RIM_SIZE := 0.5
## Полусфера купола.
const SEGMENTS := 24
const RINGS := 8
## Дальше этого от корабля (м) вуаль прячется.
const FAR := 170.0
## Экземпляров куполов на вуаль: наружный, ядро и колокольчики; чисел на экземпляр — transform 3 × 4 и цвет.
const BELLS := 2 + EcoVeil.SMALL
const STRIDE := 16

var veils: EcoVeil
## Узлы вуалей по EcoVeil.Veil.index и их части.
var groups: Array[Node3D] = []
var bells: Array[MultiMeshInstance3D] = []
var rims: Array[MeshInstance3D] = []
var tentacles: Array[MeshInstance3D] = []
## Последний буфер куполов каждой вуали (для тестов).
var bell_buffers: Array[PackedFloat32Array] = []


func _init(system: EcoVeil) -> void:
	veils = system
	name = "Вуали"
	var bell_mesh := build_bell()
	var rim_mesh := build_rim()
	for vl in veils.veils:
		var g := Node3D.new()
		g.name = "Вуаль%d" % vl.index
		add_child(g)
		groups.append(g)
		var mi := MultiMeshInstance3D.new()
		mi.name = "Купола"
		_layer(mi)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = bell_mesh
		mm.instance_count = BELLS
		mi.multimesh = mm
		mi.custom_aabb = AABB(Vector3(-10, -6, -10), Vector3(20, 14, 20))
		g.add_child(mi)
		bells.append(mi)
		var buf := PackedFloat32Array()
		buf.resize(BELLS * STRIDE)
		bell_buffers.append(buf)
		var rim := MeshInstance3D.new()
		rim.name = "Кромка"
		_layer(rim)
		rim.mesh = rim_mesh
		rim.material_override = _material(RIM_SHADER, {"tint": RIM, "size": RIM_SIZE})
		g.add_child(rim)
		rims.append(rim)
		var tm := MeshInstance3D.new()
		tm.name = "Щупальца"
		_layer(tm)
		tm.mesh = build_tentacles(vl)
		tm.material_override = EcoShaders.mist(EcoShaders.Mist.TENTACLE, {"tint": TENTACLE})
		tm.custom_aabb = AABB(Vector3(-8, -EcoVeil.LEN - 2, -8), Vector3(16, EcoVeil.LEN + 3, 16))
		g.add_child(tm)
		tentacles.append(tm)
	sync(0.0, Vector3.ZERO)


func _layer(gi: GeometryInstance3D) -> void:
	gi.layers = OceanView.LAYER_WORLD
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _material(code: String, params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(code)
	for k in params:
		mat.set_shader_parameter(k, params[k])
	return mat


## Полусфера радиуса 1 (верх купола), прозрачная по своему шейдеру; цвет — у экземпляра.
static func build_bell() -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.0
	sm.is_hemisphere = true
	sm.radial_segments = SEGMENTS
	sm.rings = RINGS
	var arr := sm.get_mesh_arrays()
	arr[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, EcoShaders.mist(EcoShaders.Mist.BELL))
	return m


## Кромка: RIM_N огоньков по кругу радиуса r на высоте 0 — по четыре вершины в одной точке, угол — в UV.
static func build_rim() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for k in RIM_N:
		var a := k / float(RIM_N) * TAU
		var c := Vector3(cos(a) * EcoVeil.R, 0.0, sin(a) * EcoVeil.R)
		var b := v.size()
		for q: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			v.append(c)
			uv.append(q)
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Щупальца вуали — отрезки линий: точка j без пульса и колыхания (x0, −j · шаг, z0), в UV — (k, j).
static func build_tentacles(vl: EcoVeil.Veil) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	for k in EcoVeil.TENTACLES:
		var x0 := cos(vl.tent_a[k]) * vl.tent_r[k]
		var z0 := sin(vl.tent_a[k]) * vl.tent_r[k]
		var step_len := vl.tent_len[k] / EcoVeil.SEGMENTS
		for j in EcoVeil.SEGMENTS:
			for jj in [j, j + 1]:
				v.append(Vector3(x0, -0.1 if jj == 0 else -jj * step_len, z0))
				uv.append(Vector2(k, jj))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	return m


## Точка j щупальца k из меша по формуле шейдера (для тестов: совпадает с EcoVeil.tentacle_point).
static func shader_point(rest: Vector3, k: int, j: int, t: float, pulse: float) -> Vector3:
	var p := Vector3(rest.x * pulse, rest.y, rest.z * pulse)
	if j > 0:
		p.x += sin(t * 0.9 + (j - 1) * 0.45 + k) * j * 0.12
		p.z += cos(t * 0.7 + (j - 1) * 0.4 + k * 1.3) * j * 0.12
	return p


## Расставить вуали в момент t (время мира); ship — где корабль (дальние вуали прячутся).
func sync(t: float, ship: Vector3) -> void:
	for vl in veils.veils:
		var g := groups[vl.index]
		var show := vl.p.distance_to(ship) < FAR
		g.visible = show
		if not show:
			continue
		g.position = vl.p
		var s := EcoVeil.pulse(vl, t)
		var buf := bell_buffers[vl.index]
		_put(buf, 0, Basis.from_scale(Vector3(s.x, 1.0 / s.x, s.x) * EcoVeil.R), Vector3.ZERO, BELL)
		_put(buf, 1, Basis.from_scale(Vector3(s.y, 1.0 / s.y, s.y) * EcoVeil.R * CORE_K), Vector3.ZERO, CORE)
		for k in EcoVeil.SMALL:
			var a := k / float(EcoVeil.SMALL) * TAU
			var q := 1.0 + sin(t * 2.0 + vl.small_ph[k]) * 0.15
			var at := Vector3(cos(a) * (EcoVeil.R + SMALL_RING), vl.small_y[k], sin(a) * (EcoVeil.R + SMALL_RING))
			_put(buf, 2 + k, Basis.from_scale(Vector3(q, 1.0 / q, q) * vl.small_size[k]), at, SMALL)
		bells[vl.index].multimesh.buffer = buf
		rims[vl.index].scale = Vector3(s.x, 1.0, s.x)
		var rm := rims[vl.index].material_override as ShaderMaterial
		rm.set_shader_parameter("tint", Color(RIM.r, RIM.g, RIM.b, EcoVeil.rim_glow(vl, t)))
		var tmat := tentacles[vl.index].material_override as ShaderMaterial
		tmat.set_shader_parameter("t", t)
		tmat.set_shader_parameter("swell", s.x)


static func _put(buf: PackedFloat32Array, n: int, b: Basis, o: Vector3, c: Color) -> void:
	var i := n * STRIDE
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z
	buf[i + 12] = c.r; buf[i + 13] = c.g; buf[i + 14] = c.b; buf[i + 15] = c.a
