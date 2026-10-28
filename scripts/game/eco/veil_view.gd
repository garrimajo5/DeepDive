class_name VeilView
extends Node3D
## Фонарные вуали в сцене (initVeils/veilUpdate в js/creatures.js): все вуали — три вызова отрисовки на всех (#849,
## раньше по три на каждую). Купола — один MultiMesh из полусферы: у каждой вуали наружный голубой купол 6 м (#7ff5ff,
## 0,22), розовое ядро 0,6 r (#ff8ae0, 0,28) и девять колокольчиков по кругу (#bff8ff, 0,35); все пульсируют, кромка
## купола ярче (по краю прозрачности). Кромка — MultiMesh колец по 48 огоньков-точек лицом к камере (#cffcff), экземпляр
## на вуаль, мерцание — альфа цвета экземпляра. Щупальца — MultiMesh, экземпляр на вуаль, в меше нити всех вуалей
## (40 по 10 звеньев линиями, #ff9ae6, 0,6), номер вуали — UV2.x: экземпляр рисует только свои (в INSTANCE_CUSTOM —
## пульс, фаза, номер вуали), прочие сжимаются в точку. Колышутся в шейдере по той же формуле, что
## EcoVeil.tentacle_point, — пульс купола бежит по ним волной вниз, течение (`EcoShaders.follow`, поток мира) сносит
## кончики; «Экономно» — только колыхание браузера (`sway_k` = 0, `EcoShaders.set_sway_lite`). Купола и щупальца —
## общий шейдер прозрачного (EcoShaders.MIST). Всё без света, прозрачное, без записи глубины, на слое отмели
## (OceanView.LAYER_WORLD). Дальше FAR от корабля вуаль не видна в мути — не рисуется и не пересчитывается: видимые
## вуали идут первыми, `visible_instance_count` отрезает прочие; рамка видимости — по видимым вуалям.
## Выдох купола и слизь ужаливания (EcoVeilDust: на сокращении купола из-под кромки — облачка, ужалила светляка —
## клуб у рыбки) — дочерний MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.

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
	ALPHA = tint.a * COLOR.a * a;
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
## Чисел на экземпляр щупалец: transform 3 × 4 и INSTANCE_CUSTOM (пульс, фаза, номер вуали, 0).
const TENT_STRIDE := 16
## Рамки видимости вокруг купола вуали: купола с колокольчиками и щупальца (с пульсом и сносом течением).
const BELL_BOX := AABB(Vector3(-10, -6, -10), Vector3(20, 14, 20))
const TENT_BOX := AABB(Vector3(-8, -EcoVeil.LEN - 2, -8), Vector3(16, EcoVeil.LEN + 3, 16))

var veils: EcoVeil
## Купола (MultiMesh), кромки (MultiMesh колец) и щупальца (MultiMesh нитей) всех вуалей.
var bells: MultiMeshInstance3D
var rims: MultiMeshInstance3D
var tentacles: MultiMeshInstance3D
## Видна ли вуаль (по EcoVeil.Veil.index) и сколько видно.
var shown: Array[bool] = []
var shown_count := 0
## Последние буферы куполов, кромок и щупалец (для тестов): видимые вуали — по порядку.
var bell_buffer := PackedFloat32Array()
var rim_buffer := PackedFloat32Array()
var tent_buffer := PackedFloat32Array()
## Выдох купола и слизь ужаливания (EcoVeilDust); буфер — для тестов.
var dust := EcoVeilDust.new()
var dust_view: MultiMeshInstance3D
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()


func _init(system: EcoVeil) -> void:
	veils = system
	name = "Вуали"
	var n := veils.veils.size()
	shown.resize(n)
	bells = _multi("Купола", build_bell(), n * BELLS, true, false)
	rims = _multi("Кромка", build_rim(), n, true, false)
	rims.material_override = _material(RIM_SHADER, {"tint": RIM, "size": RIM_SIZE})
	tentacles = _multi("Щупальца", build_tentacles_all(veils.veils), n, false, true)
	tentacles.material_override = EcoShaders.follow(EcoShaders.mist(EcoShaders.Mist.TENTACLE, tentacle_params()))
	bell_buffer.resize(n * BELLS * STRIDE)
	rim_buffer.resize(n * STRIDE)
	tent_buffer.resize(n * TENT_STRIDE)
	dust_view = GrazerView.build_dust(EcoVeilDust.POOL)
	add_child(dust_view)
	sync(0.0, Vector3.ZERO)


func _multi(title: String, mesh: Mesh, count: int, colors: bool, custom: bool) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = title
	_layer(mi)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	mi.multimesh = mm
	add_child(mi)
	return mi


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


## Щупальца вуали — отрезки линий: точка j без пульса и колыхания (x0, −j · шаг, z0), в UV — (k, j), в UV2 —
## (номер вуали vi, 0).
static func build_tentacles(vl: EcoVeil.Veil, vi := 0) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, _tentacle_arrays([vl], vi))
	return m


## Нити всех вуалей одним мешем: у вуали i в UV2.x — i (экземпляр щупалец рисует только свои).
static func build_tentacles_all(list: Array[EcoVeil.Veil]) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, _tentacle_arrays(list, 0))
	m.custom_aabb = TENT_BOX
	return m


static func _tentacle_arrays(list: Array, first: int) -> Array:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for i in list.size():
		var vl: EcoVeil.Veil = list[i]
		for k in EcoVeil.TENTACLES:
			var x0 := cos(vl.tent_a[k]) * vl.tent_r[k]
			var z0 := sin(vl.tent_a[k]) * vl.tent_r[k]
			var step_len := vl.tent_len[k] / EcoVeil.SEGMENTS
			for j in EcoVeil.SEGMENTS:
				for jj in [j, j + 1]:
					v.append(Vector3(x0, -0.1 if jj == 0 else -jj * step_len, z0))
					uv.append(Vector2(k, jj))
					uv2.append(Vector2(first + i, 0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	return arr


## Числа щупалец для шейдера: цвет, волна пульса вниз (EcoVeil.WAVE_*), снос течением TRAIL. Фаза в wave.z — фаза
## вуали vl (для shader_point); у общего материала она 0 — фазу каждой вуали шейдер прибавляет из INSTANCE_CUSTOM.g.
static func tentacle_params(vl: EcoVeil.Veil = null) -> Dictionary:
	return {"tint": TENTACLE, "wave": Vector4(EcoVeil.PULSE, EcoVeil.PULSE_W, vl.ph if vl else 0.0, EcoVeil.WAVE_LAG),
		"grow": EcoVeil.WAVE_GROW, "seg": float(EcoVeil.SEGMENTS), "trail": EcoVeil.TRAIL}


## Точка j щупальца k из меша по формуле шейдера (для тестов: совпадает с EcoVeil.tentacle_point); m — материал
## щупалец (его волна и снос), flow — поток, sway_k — 0 на «Экономно».
static func shader_point(rest: Vector3, k: int, j: int, t: float, pulse: float, m: Dictionary = {},
		flow := Vector3.ZERO, sway_k := 0.0) -> Vector3:
	var p := Vector3(rest.x * pulse, rest.y, rest.z * pulse)
	if j > 0:
		var h := j / float(m.get("seg", 10.0))
		var wave: Vector4 = m.get("wave", Vector4.ZERO)
		var sj := lerpf(pulse, 1.0 + sin(t * wave.y + wave.z - j * wave.w) * wave.x
			* (1.0 + float(m.get("grow", 0.0)) * h), sway_k)
		p.x = rest.x * sj + sin(t * 0.9 + (j - 1) * 0.45 + k) * j * 0.12
		p.z = rest.z * sj + cos(t * 0.7 + (j - 1) * 0.4 + k * 1.3) * j * 0.12
		var depth := -rest.y
		var off := flow / 0.3 * (float(m.get("trail", 0.0)) * (0.85 + 0.15 * sin(t * 0.4 + wave.z)) * h * depth) * sway_k
		off.y = off.length_squared() / (2.0 * maxf(depth / maxf(h, 0.01), 0.1))
		p += off
	return p


## Вершина меша щупалец в экземпляре по формуле шейдера (двойник ветки TENTACLE в EcoShaders.MIST, для тестов):
## rest — VERTEX, kj — UV, vi — UV2.x, custom — INSTANCE_CUSTOM (пульс, фаза, номер вуали), at — место экземпляра.
## Нить чужой вуали сжимается в точку экземпляра.
static func instance_point(rest: Vector3, kj: Vector2, vi: float, custom: Color, at: Vector3, t: float,
		m: Dictionary, flow := Vector3.ZERO, sway_k := 1.0) -> Vector3:
	if absf(vi - custom.b) > 0.5:
		return at
	var mm := m.duplicate()
	var w: Vector4 = mm.get("wave", Vector4.ZERO)
	w.z += custom.g
	mm["wave"] = w
	return at + shader_point(rest, int(kj.x), int(kj.y), t, custom.r, mm, flow, sway_k)


## Расставить вуали в момент t (время мира); ship — где корабль (дальние вуали не рисуются).
func sync(t: float, ship: Vector3) -> void:
	var n := 0
	var bell_box := AABB()
	var tent_box := AABB()
	for vl in veils.veils:
		var show := vl.p.distance_to(ship) < FAR
		shown[vl.index] = show
		if not show:
			continue
		var s := EcoVeil.pulse(vl, t)
		var b0 := n * BELLS
		_put(bell_buffer, b0, Basis.from_scale(Vector3(s.x, 1.0 / s.x, s.x) * EcoVeil.R), vl.p, BELL)
		_put(bell_buffer, b0 + 1, Basis.from_scale(Vector3(s.y, 1.0 / s.y, s.y) * EcoVeil.R * CORE_K), vl.p, CORE)
		for k in EcoVeil.SMALL:
			var a := k / float(EcoVeil.SMALL) * TAU
			var q := 1.0 + sin(t * 2.0 + vl.small_ph[k]) * 0.15
			var at := Vector3(cos(a) * (EcoVeil.R + SMALL_RING), vl.small_y[k], sin(a) * (EcoVeil.R + SMALL_RING))
			_put(bell_buffer, b0 + 2 + k, Basis.from_scale(Vector3(q, 1.0 / q, q) * vl.small_size[k]), vl.p + at, SMALL)
		_put(rim_buffer, n, Basis.from_scale(Vector3(s.x, 1.0, s.x)), vl.p,
			Color(1.0, 1.0, 1.0, EcoVeil.rim_glow(vl, t)))
		_put(tent_buffer, n, Basis.IDENTITY, vl.p, Color(s.x, vl.ph, vl.index, 0.0))
		if n == 0:
			bell_box = AABB(vl.p + BELL_BOX.position, BELL_BOX.size)
			tent_box = AABB(vl.p + TENT_BOX.position, TENT_BOX.size)
		else:
			bell_box = bell_box.merge(AABB(vl.p + BELL_BOX.position, BELL_BOX.size))
			tent_box = tent_box.merge(AABB(vl.p + TENT_BOX.position, TENT_BOX.size))
		n += 1
	shown_count = n
	for mi: MultiMeshInstance3D in [bells, rims, tentacles]:
		mi.visible = n > 0
	if n == 0:
		return
	EcoMM.send(bells, bell_buffer)
	bells.multimesh.visible_instance_count = n * BELLS
	bells.custom_aabb = bell_box
	EcoMM.send(rims, rim_buffer)
	rims.multimesh.visible_instance_count = n
	rims.custom_aabb = bell_box
	EcoMM.send(tentacles, tent_buffer)
	tentacles.multimesh.visible_instance_count = n
	tentacles.custom_aabb = tent_box
	(tentacles.material_override as ShaderMaterial).set_shader_parameter("t", t)


## Облачка выдоха и слизи в момент t (время мира): ship — корабль (дальность и луч), flow — течение мира.
func sync_dust(t: float, ship: EcoLink.ShipState, flow := Vector3.ZERO) -> void:
	dust.update(veils, t, ship.pos if ship != null else Vector3.ZERO)
	_dust.pack(dust.dust, t, flow, ship, EcoVeilDust.COLOR, EcoVeilDust.LIT)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


static func _put(buf: PackedFloat32Array, n: int, b: Basis, o: Vector3, c: Color) -> void:
	var i := n * STRIDE
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z
	buf[i + 12] = c.r; buf[i + 13] = c.g; buf[i + 14] = c.b; buf[i + 15] = c.a
