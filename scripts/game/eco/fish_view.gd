class_name FishView
extends MultiMeshInstance3D
## Светляки-полосники в сцене: все 132 рыбки — один MultiMesh (один вызов отрисовки). Форма — EcoFishLook, место
## и курс каждой рыбки — EcoFishLook.basis, цвет полос — EcoFishLook.stripe в INSTANCE_CUSTOM. Краска вершины лежит
## в цвете вершины (r: 0 — тело, 1 — полоса, FIN_GLOW — конец хвоста): тело тёмное и освещается, полосы светятся сами.
## Стоит на слое отмели (OceanView.LAYER_WORLD).

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 body_color : source_color;
varying vec3 glow;
varying float paint;
void vertex() {
	glow = INSTANCE_CUSTOM.rgb;
	paint = COLOR.r;
}
void fragment() {
	// полоса — узкая середина кольца, конец хвоста — канал g
	float p = smoothstep(0.55, 0.95, paint) + COLOR.g;
	ALBEDO = mix(body_color, glow * 0.3, clamp(p, 0.0, 1.0));
	ROUGHNESS = 0.6;
	EMISSION = glow * p * 1.8;
}
"""

var fish: EcoFish


func _init(system: EcoFish) -> void:
	fish = system
	name = "Светляки"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true  # белый: без цвета экземпляра Compatibility гасит COLOR вершин
	mm.use_custom_data = true
	mm.mesh = build_mesh()
	mm.instance_count = fish.all.size()
	multimesh = mm
	sync(0.0)


## Меш одной рыбки по EcoFishLook: вершины, нормали, краска в цвете вершины.
static func build_mesh() -> ArrayMesh:
	var colors := PackedColorArray()
	for p in EcoFishLook.paints:
		match p:
			EcoFishLook.Paint.STRIPE:
				colors.append(Color(1, 0, 0))
			EcoFishLook.Paint.FIN:
				colors.append(Color(0, EcoFishLook.FIN_GLOW, 0))
			_:
				colors.append(Color(0, 0, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = EcoFishLook.shape
	arrays[Mesh.ARRAY_NORMAL] = EcoFishLook.normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = EcoFishLook.tris
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("body_color", EcoFishLook.BODY_COLOR)
	mesh.surface_set_material(0, mat)
	return mesh


## Расставить рыбок по миру в момент t (время мира): один буфер MultiMesh за раз.
func sync(t: float) -> void:
	buffer = pack(fish, t)
	multimesh.buffer = buffer


## Последний буфер MultiMesh (по нему проверяют тесты: в headless сервер отрисовки буфер не хранит).
var buffer := PackedFloat32Array()

## Чисел на рыбку в буфере: transform 3 × 4 по строкам, цвет экземпляра (белый), затем INSTANCE_CUSTOM.
const STRIDE := 20


## Буфер MultiMesh (TRANSFORM_3D + custom data) для всех рыбок в момент t.
static func pack(system: EcoFish, t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(system.all.size() * STRIDE)
	for f in system.all:
		var b := EcoFishLook.basis(f, t)
		var o := f.agent.p
		var c := EcoFishLook.stripe(f)
		var i := f.index * STRIDE
		var row := [b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, 1.0, 1.0, 1.0, 1.0, c.r, c.g, c.b, 1.0]
		for k in STRIDE:
			out[i + k] = row[k]
	return out


## Расстановка рыбки n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))


## Цвет полос рыбки n из буфера.
static func stripe_at(buf: PackedFloat32Array, n: int) -> Color:
	var i := n * STRIDE + 16
	return Color(buf[i], buf[i + 1], buf[i + 2], buf[i + 3])
