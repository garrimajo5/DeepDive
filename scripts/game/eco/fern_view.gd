class_name FernView
extends Node3D
## Волнолист в сцене: все листья — один MultiMesh из одного листа-пера (12 треугольников, загнут наружу), моллюски
## у подножий — второй MultiMesh из полусферы (initFerns в js/creatures.js). Цвет листа #3D9D91, края и кончик
## светлее (#68E6DC, ART-004) — отражённый свет, своей эмиссии нет; виден с обеих сторон. Стоит на слое отмели
## (OceanView.LAYER_WORLD). Моллюски не двигаются — расставлены один раз.

const LEAF_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 leaf_color : source_color;
uniform vec3 edge_color : source_color;
void fragment() {
	// UV.x поперёк листа (0,5 — жилка), UV.y — от кончика (0) к основанию (1)
	float edge = smoothstep(0.25, 0.5, abs(UV.x - 0.5)) * 0.8 + smoothstep(0.45, 0.0, UV.y) * 0.5;
	float vein = 1.0 - smoothstep(0.0, 0.04, abs(UV.x - 0.5));
	ALBEDO = mix(leaf_color, edge_color, clamp(edge + vein * 0.3, 0.0, 1.0)) * mix(0.55, 1.0, 1.0 - UV.y * 0.6);
	ROUGHNESS = 0.7;
}
"""

const LEAF := Color("3D9D91")
const EDGE := Color("68E6DC")
const SHELL := Color("9a8fb2")
## Отрезков листа по длине и загиб кончика наружу (м при длине 1,4).
const SEGMENTS := 6
const CURL := 0.22
## Чисел на экземпляр в буфере: transform 3 × 4 по строкам.
const STRIDE := 12

var ferns: EcoFern
var leaves: MultiMeshInstance3D
var shells: MultiMeshInstance3D
## Последний буфер листьев (для тестов).
var buffer := PackedFloat32Array()


func _init(system: EcoFern, ground: Callable = Callable()) -> void:
	ferns = system
	name = "Волнолист"
	leaves = _instance("Листья", build_leaf(), ferns.ferns.size() * EcoFern.LEAVES)
	shells = _instance("Моллюски", build_shell(), ferns.ferns.size() * EcoFern.SHELLS)
	var buf := PackedFloat32Array()
	buf.resize(shells.multimesh.instance_count * STRIDE)
	for fe in ferns.ferns:
		for j in EcoFern.SHELLS:
			var p := EcoFern.shell_pos(fe, j, ground)
			var a := float(j) / EcoFern.SHELLS * TAU + fe.yaw
			var b := Basis(Vector3.UP, a).scaled_local(Vector3(1.0, 0.5, 1.3) * fe.scale)
			_put(buf, fe.index * EcoFern.SHELLS + j, Transform3D(b, p))
	shells.multimesh.buffer = buf
	sync(0.0)


func _instance(n: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mi.multimesh = mm
	add_child(mi)
	return mi


## Лист-перо 0,28 × 1,4 м (PlaneGeometry с шириной sin(y/1,4 · π) · 1,2, как в браузере): основание у подножия,
## растёт по +Y, кончик загнут в −Z — туда же лист ложится при раскрытии (EcoFern.leaf_basis).
static func build_leaf() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nr := PackedVector3Array()
	for i in SEGMENTS + 1:
		var k := float(i) / SEGMENTS
		var y := k * EcoFern.LEAF_LEN
		var w := EcoFern.LEAF_W / 2.0 * sin(minf(1.0, k) * PI) * 1.2
		var z := -CURL * k * k
		for s in [-1.0, 1.0]:
			v.append(Vector3(s * w, y, z))
			uv.append(Vector2(0.5 + s * 0.5, 1.0 - k))
			nr.append(Vector3(0, 2.0 * CURL * k / EcoFern.LEAF_LEN, 1).normalized())
	var idx := PackedInt32Array()
	for i in SEGMENTS:
		var a := i * 2
		# лицом к +Z по правилу Godot: (b − a) × (c − a) смотрит в −Z
		idx.append_array([a, a + 3, a + 1, a, a + 2, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nr
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(LEAF_SHADER)
	mat.set_shader_parameter("leaf_color", LEAF)
	mat.set_shader_parameter("edge_color", EDGE)
	mesh.surface_set_material(0, mat)
	return mesh


## Моллюск — полусфера радиусом 0,11 м (сплющена в расстановке).
static func build_shell() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.11
	m.height = 0.11
	m.is_hemisphere = true
	m.radial_segments = 7
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SHELL
	mat.roughness = 0.5
	m.material = mat
	return m


## Расставить листья в момент t (время мира).
func sync(t: float) -> void:
	buffer.resize(leaves.multimesh.instance_count * STRIDE)
	for fe in ferns.ferns:
		for j in EcoFern.LEAVES:
			_put(buffer, fe.index * EcoFern.LEAVES + j, Transform3D(EcoFern.leaf_basis(fe, j, t), fe.pos))
	leaves.multimesh.buffer = buffer


static func _put(buf: PackedFloat32Array, n: int, tr: Transform3D) -> void:
	var b := tr.basis
	var o := tr.origin
	var i := n * STRIDE
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z


## Расстановка экземпляра n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
