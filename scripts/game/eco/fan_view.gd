class_name FanView
extends MultiMeshInstance3D
## Веерники в сцене: все — один MultiMesh из одного прямоугольника 2,6 × 3 м (два треугольника), кружево ветвей
## рисует шейдер (как fanTex в js/creatures.js: ствол, 13 лучей веером и дуги между ними; остальное отброшено).
## Своего света нет: светлые края — отражённый свет (ART-004, #68E6DC). Плоскость повёрнута навстречу потоку
## (EcoFan.basis), видна с обеих сторон. Стоит на слое отмели (OceanView.LAYER_WORLD).

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 rib_color : source_color;
uniform vec3 edge_color : source_color;
uniform vec2 size;
void fragment() {
	// метры от подножия: x вправо, y вверх; лучи расходятся из точки на высоте 0,35 м
	vec2 p = vec2((UV.x - 0.5) * size.x, (1.0 - UV.y) * size.y);
	vec2 o = vec2(0.0, 0.35);
	vec2 d = p - o;
	float r = length(d);
	float a = atan(d.x, max(d.y, 1e-4));
	float w = 0.0;
	// ствол
	if (p.y < o.y + 0.05) {
		w = step(abs(p.x), 0.09);
	}
	// лучи: 13 от −1,25 до 1,25 рад, тоньше к краю
	float k = (a + 1.25) / 2.5 * 12.0;
	float ray = abs(k - round(k)) * 2.5 / 12.0 * r;
	if (d.y > 0.0 && abs(a) < 1.3) {
		w = max(w, step(ray, 0.05 - r * 0.008));
		// дуги-эллипсы между лучами
		float e = length(vec2(d.x / 0.55, d.y / 0.95));
		float ring = abs(fract(e / 0.22) - 0.5) * 0.22;
		w = max(w, step(ring, 0.024) * step(0.3, e));
		// край веера — эллипс
		w *= step(e, 2.6);
	}
	if (w < 0.5) {
		discard;
	}
	float edge = smoothstep(1.6, 2.6, length(vec2(d.x / 0.55, d.y / 0.95)));
	ALBEDO = mix(rib_color, edge_color, edge);
	ROUGHNESS = 0.6;
}
"""

const RIB := Color("1f8796")
const EDGE := Color("68E6DC")
## Чисел на веер в буфере: transform 3 × 4 по строкам.
const STRIDE := 12

var fans: EcoFan
## Последний буфер MultiMesh (для тестов).
var buffer := PackedFloat32Array()


func _init(system: EcoFan) -> void:
	fans = system
	name = "Веерники"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = build_mesh()
	mm.instance_count = fans.fans.size()
	multimesh = mm
	sync(0.0)


## Прямоугольник веера: низ у подножия, плоскость XY, нормаль +Z.
static func build_mesh() -> ArrayMesh:
	var w := EcoFan.WIDTH / 2.0
	var h := EcoFan.HEIGHT
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, h, 0), Vector3(-w, h, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	# лицом к +Z по правилу Godot: (b − a) × (c − a) смотрит в −Z
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("rib_color", RIB)
	mat.set_shader_parameter("edge_color", EDGE)
	mat.set_shader_parameter("size", Vector2(EcoFan.WIDTH, EcoFan.HEIGHT))
	mesh.surface_set_material(0, mat)
	return mesh


## Расставить веера в момент t (время мира).
func sync(t: float) -> void:
	buffer.resize(fans.fans.size() * STRIDE)
	for f in fans.fans:
		var b := EcoFan.basis(f, t)
		var o := f.pos
		var i := f.index * STRIDE
		var row := [b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z]
		for k in STRIDE:
			buffer[i + k] = row[k]
	multimesh.buffer = buffer


## Расстановка веера n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
