class_name FringeView
extends Node3D
## Инеевая бахрома у Светового колодца 05 в сцене (#836, часть 6; ART-080 — `docs/concept-art/inevaya-bahroma-i-mol.md`):
## все нити — один MultiMesh одной пряди: две скрещённые полосы по SEGMENTS сегментов (32 треуг.), «Экономно» —
## одна полоса (лист ART-080: 1536 / 384 треуг., один вызов). Корень — на льду, качание, мелкая волна и отвод корпусом
## считает вершинный шейдер теми же формулами, что `EcoFringe.Curtain.point` (двойник — `strand_point`): постоянные
## нити (ритм, фаза, размах, плоскость качания) — uniform-массивы, отвод конца — третий столбец базиса экземпляра
## (полоса плоская, он свободен), длина — второй, ширина нити и тон тела — первый (x, y; свои у каждой нити,
## `strand_width`/`strand_shade`). След касания — `Curtain.custom` в INSTANCE_CUSTOM: фрагментный
## шейдер гасит его по `EcoFringe.envelope` и `band` (двойник — `glow_at`) и светит `#67DDEB` по узлам и щели.
## Тело освещается (прожектор, свет сквозь лёд), полупрозрачное, без теней; свечение — общий приём `eco_bio`.
## Рисунок пряди — процедурный (щель посередине, узлы-утолщения по NODES, конец тоньше): лист ART-080 разрешает
## сделать текстуру при встройке; карты ART-083 (#922) лягут на те же UV (u — поперёк, v — от корня к концу).
## Корабль дальше `EcoFringe.ACTIVE` от колодца — узел скрыт и ничего не пишет.

## Ширина нити у корня, м (лист: 0,08–0,15, узлы-ромбы до 0,20); к концу — TIP доли.
const WIDTH := 0.14
const TIP := 0.35
## Сегментов по длине одной полосы.
const SEGMENTS := 8
## Узлы-утолщения по длине (доли от корня), полуширина узла по v и насколько он шире нити.
const NODES: Array[float] = [0.11, 0.24, 0.36, 0.5, 0.63, 0.77, 0.9]
const NODE_HALF := 0.025
const NODE_WIDE := 0.45
## Цвета листа ART-080: тело, холодный край, свечение следа; сила следа и тлеющий фон незадетой нити.
const BODY := Color("86bccb")
const EDGE_TINT := Color("9ad9e8")
const GLOW := Color("67ddeb")
const GLOW_K := 1.6
const IDLE := 0.03
const ALPHA := 0.6
## Нити не клоны (Б4): у нити своя ширина и свой тон тела — по её номеру (`EcoVary`), разброс ±.
const WIDTH_SPREAD := 0.15
const SHADE_SPREAD := 0.12
## Чисел на экземпляр: transform 3 × 4 и INSTANCE_CUSTOM (4).
const STRIDE := 16
const CUSTOM := 12

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;
#define COUNT %d
uniform vec4 motion[COUNT];
uniform float world_t = 0.0;
uniform float wave_amp = 0.08;
uniform float wave_len = 0.3;
uniform float tip = 0.35;
uniform vec3 body : source_color;
uniform vec3 edge_tint : source_color;
uniform vec3 glow : source_color;
uniform float glow_k = 1.6;
uniform float idle = 0.03;
uniform float alpha_k = 0.6;
uniform float rise = 0.3;
uniform float hold = 10.0;
uniform float fade = 60.0;
uniform float edge = 0.04;
uniform float nodes[7];
uniform float node_half = 0.025;
uniform float node_wide = 0.45;
uniform float rough = 0.55;
uniform float spec = 0.35;
%s
varying vec4 trail;
varying float shade;
float node_at(float v) {
	float n = 0.0;
	for (int k = 0; k < 7; k++) {
		n = max(n, 1.0 - smoothstep(0.0, node_half, abs(v - nodes[k])));
	}
	return n;
}
void vertex() {
	// UV.x — поперёк (0…1), UV.y — доля длины от корня; UV2 — ось полосы по горизонтали (x, z)
	vec4 m = motion[INSTANCE_ID];
	vec3 root = MODEL_MATRIX[3].xyz;
	float len = MODEL_MATRIX[1].y;
	float width = MODEL_MATRIX[0].x;
	shade = MODEL_MATRIX[0].y;
	vec3 push = MODEL_MATRIX[2].xyz;
	float v = UV.y;
	float bend = v * v;
	vec3 dir = vec3(cos(m.w), 0.0, sin(m.w));
	vec3 side = vec3(-dir.z, 0.0, dir.x);
	float s = sin(m.x * world_t + m.y) * m.z * bend;
	float w = sin(m.x * 3.1 * world_t - v / wave_len * 6.2831853 + m.y) * wave_amp * v;
	vec3 c = root + vec3(0.0, -len * v, 0.0) + dir * s + side * w + push * bend;
	float wide = width * mix(1.0, tip, v) * (1.0 + node_wide * node_at(v));
	vec3 across = vec3(UV2.x, 0.0, UV2.y);
	VERTEX = c + across * (UV.x - 0.5) * wide;
	NORMAL = vec3(UV2.y, 0.0, -UV2.x);
	TANGENT = across;
	BINORMAL = vec3(0.0, 1.0, 0.0);
	// вершина уже в мире: модельной матрицы (у экземпляра в ней данные нити) не применять
	MODELVIEW_MATRIX = VIEW_MATRIX;
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX);
	trail = INSTANCE_CUSTOM;
}
void fragment() {
	float u = abs(UV.x - 0.5) * 2.0;
	float v = UV.y;
	float slit = 1.0 - smoothstep(0.04, 0.14, u);
	float node = node_at(v);
	// след: подъём, ровно, затухание (EcoFringe.envelope) на задетом участке с мягкими краями (EcoFringe.band)
	float t = trail.x;
	float env = 0.0;
	if (t >= 0.0 && t < fade) {
		if (t < rise) {
			env = t / rise;
		} else if (t <= hold) {
			env = 1.0;
		} else {
			float k = 1.0 - (t - hold) / (fade - hold);
			env = k * k * (3.0 - 2.0 * k);
		}
	}
	float d = abs(v - trail.y) - trail.z;
	float band = d <= 0.0 ? 1.0 : clamp(1.0 - d / edge, 0.0, 1.0);
	float mask = 0.3 + 0.7 * max(node, slit);
	ALBEDO = mix(body, edge_tint, smoothstep(0.5, 1.0, u)) * (1.0 - 0.35 * slit) * shade;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = eco_bio(glow * (glow_k * env * band + idle) * mask);
	// края мягкие, конец разлохмачен: прядь тает к самому концу
	ALPHA = alpha_k * (1.0 - smoothstep(0.7, 1.0, u)) * (1.0 - smoothstep(0.9, 1.0, v)) * (0.75 + 0.25 * node);
}
"""

var fringe: EcoFringe
var strands: MultiMeshInstance3D
var material: ShaderMaterial
var mesh_full: ArrayMesh
var mesh_lite: ArrayMesh
var lite := false
## Последний буфер (для тестов) и сколько раз его писали.
var buffer := PackedFloat32Array()
var writes := 0
## Занавес, чьи постоянные нити сейчас в uniform `motion` (сброс мира — новый занавес).
var _motion_of: EcoFringe.Curtain


## Рамка у колодца: кольцо нитей с запасом на качание и отвод, от льда до самого длинного конца.
const BOX := AABB(Vector3(EcoFringe.WELL.x - EcoFringe.RING.y - EcoFringe.SIDE - 1.0, -EcoFringe.LEN_MAX - 1.0,
		EcoFringe.WELL.y - EcoFringe.RING.y - EcoFringe.SIDE - 1.0),
		Vector3((EcoFringe.RING.y + EcoFringe.SIDE + 1.0) * 2.0, EcoFringe.LEN_MAX + 2.0,
		(EcoFringe.RING.y + EcoFringe.SIDE + 1.0) * 2.0))


func _init(system: EcoFringe, is_lite := false) -> void:
	fringe = system
	name = "Инеевая бахрома"
	strands = MultiMeshInstance3D.new()
	strands.name = "Нити бахромы"
	strands.layers = OceanView.LAYER_WORLD
	strands.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = EcoShaders.material(shader_code(), {"world_t": 0.0, "wave_amp": EcoFringe.WAVE,
			"wave_len": EcoFringe.WAVE_LEN, "tip": TIP, "body": BODY, "edge_tint": EDGE_TINT, "glow": GLOW,
			"glow_k": GLOW_K, "idle": IDLE, "alpha_k": ALPHA, "rise": EcoFringe.RISE, "hold": EcoFringe.HOLD,
			"fade": EcoFringe.FADE, "edge": EcoFringe.EDGE, "nodes": PackedFloat32Array(NODES),
			"node_half": NODE_HALF, "node_wide": NODE_WIDE})
	mesh_full = build_mesh(2)
	mesh_lite = build_mesh(1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh_full
	mm.instance_count = EcoFringe.COUNT
	strands.multimesh = mm
	strands.material_override = material
	strands.custom_aabb = BOX
	add_child(strands)
	buffer.resize(EcoFringe.COUNT * STRIDE)
	visible = false
	set_lite(is_lite)


static func shader_code() -> String:
	return SHADER % [EcoFringe.COUNT, EcoGlow.GLSL]


## Прядь: `strips` полос (1 — вдоль x, 2 — ещё и вдоль z) по SEGMENTS сегментов; UV.y — доля длины, UV2 — ось полосы.
static func build_mesh(strips: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for s in strips:
		var axis := Vector2(1.0, 0.0) if s == 0 else Vector2(0.0, 1.0)
		var base := verts.size()
		for k in SEGMENTS + 1:
			var v := float(k) / SEGMENTS
			for side in 2:
				verts.append(Vector3(axis.x * (side - 0.5), -v, axis.y * (side - 0.5)))
				uv.append(Vector2(side, v))
				uv2.append(axis)
		for k in SEGMENTS:
			var a := base + k * 2
			idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Ширина нити i у корня, м: WIDTH ± WIDTH_SPREAD по номеру нити (основание и узлы — с ней).
static func strand_width(i: int) -> float:
	return WIDTH * EcoVary.spread(i, EcoVary.WIDTH, WIDTH_SPREAD)


## Тон тела нити i: множитель цвета тела и края, 1 ± SHADE_SPREAD (свечение следа — общее).
static func strand_shade(i: int) -> float:
	return EcoVary.spread(i, EcoVary.SHADE, SHADE_SPREAD)


## «Экономно»: одна полоса вместо двух (нитей — сколько живёт в мире, `Curtain.active`).
func set_lite(on: bool) -> void:
	lite = on
	strands.multimesh.mesh = mesh_lite if on else mesh_full


## Нити у колодца — в буфер; корабль далеко — узел скрыт. t — время мира (качание и волна в шейдере).
func sync(ship: EcoLink.ShipState, t: float) -> void:
	var c := fringe.curtain
	if c == null or not EcoFringe.near(ship):
		visible = false
		return
	if _motion_of != c:
		_put_motion(c)
	visible = true
	material.set_shader_parameter("world_t", t)
	for i in c.active:
		var b := i * STRIDE
		buffer[b] = strand_width(i)
		buffer[b + 4] = strand_shade(i)
		buffer[b + 5] = c.length[i]
		var p: Vector3 = c.push[i]
		buffer[b + 2] = p.x
		buffer[b + 6] = p.y
		buffer[b + 10] = p.z
		buffer[b + 3] = c.root[i].x
		buffer[b + 7] = c.root[i].y
		buffer[b + 11] = c.root[i].z
		var e := c.custom(i)
		buffer[b + CUSTOM] = e.r
		buffer[b + CUSTOM + 1] = e.g
		buffer[b + CUSTOM + 2] = e.b
		buffer[b + CUSTOM + 3] = e.a
	var mm := strands.multimesh
	mm.buffer = buffer
	mm.visible_instance_count = c.active
	writes += 1


## Постоянные нити в uniform: ритм, фаза, размах и угол плоскости качания (мир их не меняет после сброса).
func _put_motion(c: EcoFringe.Curtain) -> void:
	var arr := PackedVector4Array()
	arr.resize(EcoFringe.COUNT)
	for i in mini(c.root.size(), EcoFringe.COUNT):
		arr[i] = Vector4(c.rate[i], c.phase[i], c.sway[i], atan2(c.sway_dir[i].z, c.sway_dir[i].x))
	material.set_shader_parameter("motion", arr)
	_motion_of = c


## Двойник вершинного шейдера: середина нити n на доле длины v в момент t — из буфера и uniform `motion`.
func strand_point(n: int, v: float, t: float) -> Vector3:
	var b := n * STRIDE
	var m: Vector4 = (material.get_shader_parameter("motion") as PackedVector4Array)[n]
	var root := Vector3(buffer[b + 3], buffer[b + 7], buffer[b + 11])
	var push := Vector3(buffer[b + 2], buffer[b + 6], buffer[b + 10])
	var bend := v * v
	var dir := Vector3(cos(m.w), 0.0, sin(m.w))
	var side := Vector3(-dir.z, 0.0, dir.x)
	var s := sin(m.x * t + m.y) * m.z * bend
	var w := sin(m.x * 3.1 * t - v / EcoFringe.WAVE_LEN * TAU + m.y) * EcoFringe.WAVE * v
	return root + Vector3(0.0, -buffer[b + 5] * v, 0.0) + dir * s + side * w + push * bend


## Двойник фрагментного шейдера: сила следа нити n на доле длины v (без узлов и щели).
func glow_at(n: int, v: float) -> float:
	var b := n * STRIDE + CUSTOM
	return EcoFringe.envelope(buffer[b]) * EcoFringe.band(v, buffer[b + 1], buffer[b + 2])
