class_name GrazerView
extends MultiMeshInstance3D
## Скребуны в сцене: все десять — один MultiMesh (один вызов отрисовки). Форма — EcoGrazerLook, место и курс —
## EcoGrazerLook.basis/origin, поза (фаза шага, ход скребка) — EcoGrazerLook.custom в INSTANCE_CUSTOM. Шейдер двигает
## лапы и скребок так же, как EcoGrazerLook.posed: в UV.x — тройка лапы (±1, у корпуса 0), в UV.y — скребок (1),
## в UV2 — бедро лапы (x, z). Краска — цвет вершины × цвет экземпляра (EcoGrazerLook.tint — свой у особи, Б4);
## размер особи — в basis. Грани плоские (нормаль по производным), своего света нет.
## Муть у дна от скребка и лап (EcoGrazerDust) — дочерний MultiMesh «Муть»: облачка ила лицом к камере, общий
## шейдер EcoShaders.MIST (режим INK), +1 вызов отрисовки. Стоит на слое отмели (OceanView.LAYER_WORLD).

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float swing;
uniform float step_lift;
uniform float rough = 0.7;
uniform float spec = 0.5;
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
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""

## Чисел на скребуна в буфере: transform 3 × 4 по строкам, цвет экземпляра (белый), затем INSTANCE_CUSTOM.
const STRIDE := 20

var grazers: EcoGrazer
## Последний буфер MultiMesh (по нему проверяют тесты: в headless сервер отрисовки буфер не хранит).
var buffer := PackedFloat32Array()
## Муть от скребунов: пул облачков и его MultiMesh; буфер мути — для тестов.
var dust := EcoGrazerDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()
## Чисел на облачко в буфере мути: transform 3 × 4 и цвет.
const DUST_STRIDE := 16


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
	dust_view = build_dust()
	add_child(dust_view)
	sync(0.0)


## MultiMesh мути на pool облачков (общий шейдер EcoShaders.MIST, INK); его же берёт KrabView.
static func build_dust(pool: int = EcoGrazerDust.POOL) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = "Муть"
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = EcoShaders.mist(EcoShaders.Mist.INK)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = pool
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	return mi


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


## Расставить скребунов по миру в момент t (время мира): один буфер MultiMesh за раз. ship — корабль (муть
## дальше EcoGrazerDust.NEAR не поднимается, в луче прожектора светлее), flow — течение мира (уносит муть).
func sync(t: float, ship: EcoLink.ShipState = null, flow: Vector3 = Vector3.ZERO) -> void:
	buffer = pack(grazers, t)
	multimesh.buffer = buffer
	dust.update(grazers, t, ship.pos if ship else Vector3.ZERO)
	_dust.pack(dust, t, flow, ship, EcoGrazerDust.COLOR, EcoGrazerDust.LIT, Seabed.mesh_height)
	if _dust.changed:   # мути нет и не было — буфер тот же, не грузим (issue #133)
		dust_view.multimesh.buffer = _dust.data




## Буфер мути (TRANSFORM_3D + цвет): растаявшие облачка стянуты в точку, в луче прожектора — светлее (от dark к lit;
## у скребунов — EcoGrazerDust.COLOR/LIT, у кольчужника своя бурая муть — EcoKrabDust.COLOR/LIT). floor_at(x, z) —
## высота видимой сетки дна (в сцене Seabed.mesh_height): облачко над ней не ниже EcoGrazerDust.above, иначе сетка
## дна между вершинами выше точного дна мира и прячет нижнюю половину облачка.
static func pack_dust(d: EcoGrazerDust, t: float, flow: Vector3, ship: EcoLink.ShipState = null,
		dark: Color = EcoGrazerDust.COLOR, lit: Color = EcoGrazerDust.LIT, floor_at: Callable = Callable()) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(d.puffs.size() * DUST_STRIDE)
	for n in d.puffs.size():
		var p := d.puffs[n]
		var i := n * DUST_STRIDE
		var a := EcoGrazerDust.fade(p, t)
		var s := EcoGrazerDust.size(p, t) if a > 0.0 else 0.0
		var o := EcoGrazerDust.pos(p, t, flow)
		if s > 0.0 and floor_at.is_valid():
			if p.floor_y == -INF:   # дно под облачком — раз на облачко: течение уносит его на полметра
				p.floor_y = float(floor_at.call(p.at.x, p.at.z))
			o.y = EcoGrazerDust.above(o.y, s, p.floor_y)
		var c := dark.lerp(lit, EcoGrazerDust.light(o, ship))
		out[i] = s; out[i + 3] = o.x
		out[i + 5] = s; out[i + 7] = o.y
		out[i + 10] = s; out[i + 11] = o.z
		out[i + 12] = c.r; out[i + 13] = c.g; out[i + 14] = c.b; out[i + 15] = a
	return out


## Буфер MultiMesh (TRANSFORM_3D + custom data) для всех скребунов в момент t.
static func pack(system: EcoGrazer, t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(system.all.size() * STRIDE)
	for g in system.all:
		var b := EcoGrazerLook.basis(g)
		var o := EcoGrazerLook.origin(g)
		var c := EcoGrazerLook.custom(g, t)
		var tn := EcoGrazerLook.tint(g)
		var row := [b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z,
			tn.r, tn.g, tn.b, 1.0, c.x, c.y, 0.0, 0.0]
		var i := g.index * STRIDE
		for k in STRIDE:
			out[i + k] = row[k]
	return out


## Расстановка скребуна n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))


## Цвет экземпляра скребуна n из буфера (EcoGrazerLook.tint).
static func tint_at(buf: PackedFloat32Array, n: int) -> Color:
	var i := n * STRIDE + 12
	return Color(buf[i], buf[i + 1], buf[i + 2], buf[i + 3])


## Поза скребуна n из буфера (фаза шага, ход скребка).
static func custom_at(buf: PackedFloat32Array, n: int) -> Vector2:
	var i := n * STRIDE + 16
	return Vector2(buf[i], buf[i + 1])
