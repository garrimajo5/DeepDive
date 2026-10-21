class_name GrazerView
extends MultiMeshInstance3D
## Скребуны в сцене: все десять — один MultiMesh (один вызов отрисовки). Форма — EcoGrazerLook, место и курс —
## EcoGrazerLook.basis/origin, поза (фаза шага, ход скребка) — EcoGrazerLook.custom в INSTANCE_CUSTOM. Шейдер двигает
## лапы и скребок так же, как EcoGrazerLook.posed: в UV.x — тройка лапы (±1, у корпуса 0), в UV.y — скребок (1),
## в UV2 — бедро лапы (x, z). Краска — цвет вершины; грани плоские (нормаль по производным), своего света нет.
## Стоит на слое отмели (OceanView.LAYER_WORLD).

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float swing;
uniform float step_lift;
varying vec3 paint;
void vertex() {
	paint = COLOR.rgb;
	float tri = UV.x;
	if (abs(tri) > 0.5) {
		float s = INSTANCE_CUSTOM.r * tri;
		float ang = swing * s;
		vec2 d = VERTEX.xz - UV2;
		float c = cos(ang);
		float sn = sin(ang);
		VERTEX.xz = UV2 + vec2(d.x * c + d.y * sn, -d.x * sn + d.y * c);
		VERTEX.y += step_lift * max(0.0, s);
	}
	VERTEX.y -= UV.y * INSTANCE_CUSTOM.g;
}
void fragment() {
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ALBEDO = paint;
	ROUGHNESS = 0.7;
}
"""

## Чисел на скребуна в буфере: transform 3 × 4 по строкам, цвет экземпляра (белый), затем INSTANCE_CUSTOM.
const STRIDE := 20

var grazers: EcoGrazer
## Последний буфер MultiMesh (по нему проверяют тесты: в headless сервер отрисовки буфер не хранит).
var buffer := PackedFloat32Array()


func _init(system: EcoGrazer) -> void:
	grazers = system
	name = "Скребуны"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true  # белый: без цвета экземпляра Compatibility гасит COLOR вершин
	mm.use_custom_data = true
	mm.mesh = build_mesh()
	mm.instance_count = grazers.all.size()
	multimesh = mm
	sync(0.0)


## Меш одного скребуна по EcoGrazerLook: вершины, краски, тройка лапы и скребок в UV, бедро в UV2.
static func build_mesh() -> ArrayMesh:
	var n := EcoGrazerLook.verts_per_grazer()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	uv.resize(n)
	uv2.resize(n)
	for i in n:
		var pt := EcoGrazerLook.part[i]
		if pt >= 0 and pt < 6:
			var h := EcoGrazerLook.hips[pt]
			uv[i] = Vector2(EcoGrazerLook.tripod(pt), 0)
			uv2[i] = Vector2(h.x, h.z)
		else:
			uv[i] = Vector2(0, 1 if pt == EcoGrazerLook.SCRAPER else 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = EcoGrazerLook.rest
	arrays[Mesh.ARRAY_COLOR] = EcoGrazerLook.paint
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = EcoGrazerLook.tris
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(SHADER)
	mat.set_shader_parameter("swing", EcoGrazerLook.SWING)
	mat.set_shader_parameter("step_lift", EcoGrazerLook.STEP_LIFT)
	mesh.surface_set_material(0, mat)
	# лапы шагают в шейдере: запас к рамке, чтобы скребун не пропадал у края экрана
	mesh.custom_aabb = AABB(Vector3(-1.3, -0.2, -1.3), Vector3(2.6, 1.0, 2.6))
	return mesh


## Расставить скребунов по миру в момент t (время мира): один буфер MultiMesh за раз.
func sync(t: float) -> void:
	buffer = pack(grazers, t)
	multimesh.buffer = buffer


## Буфер MultiMesh (TRANSFORM_3D + custom data) для всех скребунов в момент t.
static func pack(system: EcoGrazer, t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(system.all.size() * STRIDE)
	for g in system.all:
		var b := EcoGrazerLook.basis(g)
		var o := EcoGrazerLook.origin(g)
		var c := EcoGrazerLook.custom(g, t)
		var row := [b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z,
			1.0, 1.0, 1.0, 1.0, c.x, c.y, 0.0, 0.0]
		var i := g.index * STRIDE
		for k in STRIDE:
			out[i + k] = row[k]
	return out


## Расстановка скребуна n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))


## Поза скребуна n из буфера (фаза шага, ход скребка).
static func custom_at(buf: PackedFloat32Array, n: int) -> Vector2:
	var i := n * STRIDE + 16
	return Vector2(buf[i], buf[i + 1])
