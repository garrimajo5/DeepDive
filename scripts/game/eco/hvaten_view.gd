class_name HvatenView
extends Node3D
## Хватни и пестрянки в сцене (initAnemones в js/creatures.js): три MultiMesh — тела (столб 0,45 → 0,32 м высотой
## 0,8 м и розовый диск щупалец, своё слабое свечение #2a0a24), щупальца (тонкие конусы 1 м с цветом по длине:
## лиловые у диска, светлее к кончикам, светятся сами) и пестрянки (вытянутые капли 7 × 10 × 24 см, оранжевые
## и белая). Стоят на слое отмели (OceanView.LAYER_WORLD).

## Цвета пестрянок по порядку (pc в браузере).
const PESTR_COLORS: Array[Color] = [Color("ff7a2a"), Color("fff1d0"), Color("ff9a4a")]
const BODY_GLOW := Color("2a0a24")
const PESTR_SIZE := Vector3(0.035, 0.05, 0.12)
## Чисел на экземпляр: transform 3 × 4, у пестрянок ещё цвет (4).
const STRIDE := 12
const STRIDE_C := 16

var hvaten: EcoHvaten
var bodies: MultiMeshInstance3D
var tents: MultiMeshInstance3D
var pestr: MultiMeshInstance3D
## Последние буферы щупалец и пестрянок (для тестов — сервер отрисовки без экрана экземпляры не хранит).
var tent_buffer := PackedFloat32Array()
var pestr_buffer := PackedFloat32Array()


func _init(system: EcoHvaten) -> void:
	hvaten = system
	name = "Хватни"
	var n := hvaten.anemones.size()
	bodies = _instance("Тела", build_body(), n, false)
	tents = _instance("Щупальца", build_tentacle(), n * EcoHvaten.TENT, false)
	pestr = _instance("Пестрянки", build_pestr(), n * EcoHvaten.PESTR_N, true)
	var buf := PackedFloat32Array()
	buf.resize(n * STRIDE)
	for hv in hvaten.anemones:
		_put(buf, hv.index * STRIDE, Transform3D(Basis(Vector3.UP, hv.yaw), hv.base))
	bodies.multimesh.buffer = buf
	tent_buffer.resize(n * EcoHvaten.TENT * STRIDE)
	pestr_buffer.resize(n * EcoHvaten.PESTR_N * STRIDE_C)
	for hv in hvaten.anemones:
		for k in EcoHvaten.PESTR_N:
			var c := PESTR_COLORS[k % PESTR_COLORS.size()]
			var i := (hv.index * EcoHvaten.PESTR_N + k) * STRIDE_C
			pestr_buffer[i + 12] = c.r; pestr_buffer[i + 13] = c.g; pestr_buffer[i + 14] = c.b; pestr_buffer[i + 15] = 1.0
	sync(0.0)


func _instance(n: String, mesh: Mesh, count: int, colors: bool) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mi)
	return mi


## Тело: столб (0,32 сверху, 0,45 снизу, 0,8 м) цвета (0,48, 0,22, 0,42) и диск (0,4 → 0,32, 0,08 м) на 0,82 м —
## (0,95, 0,55, 0,75). Девять граней, как в браузере.
static func build_body() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st, 0.32, 0.45, 0.8, 0.4, Color(0.48, 0.22, 0.42), 9, 1, true)
	_add_cylinder(st, 0.4, 0.32, 0.08, 0.82, Color(0.95, 0.55, 0.75), 9, 1, true)
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = BODY_GLOW
	m.surface_set_material(0, mat)
	return m


## Щупальце: конус 0,05 → 0,015 м длиной 1 м от основания вверх, четыре грани, цвет по высоте k:
## (0,55 + 0,45k, 0,25 + 0,6k, 0,6 + 0,35k); светится само (MeshBasicMaterial).
static func build_tentacle() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st, 0.015, 0.05, 1.0, 0.5, Color.WHITE, 4, 3, false)
	var m := st.commit()
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var col := PackedColorArray()
	for p in v:
		var k := clampf(p.y, 0.0, 1.0)
		col.append(Color(0.55 + k * 0.45, 0.25 + k * 0.6, 0.6 + k * 0.35))
	arr[Mesh.ARRAY_COLOR] = col
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	out.surface_set_material(0, mat)
	return out


## Пестрянка: сплюснутая сфера 6 × 4, вытянута вдоль +Z (нос по ходу); цвет — у экземпляра, светится сама.
static func build_pestr() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 6
	m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	return m


## Цилиндр CylinderMesh в SurfaceTool: середина на высоте mid, цвет вершин c; caps — с крышками.
static func _add_cylinder(st: SurfaceTool, top: float, bottom: float, h: float, mid: float, c: Color, seg: int,
		rings: int, caps: bool) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = seg
	cm.rings = rings
	cm.cap_top = caps
	cm.cap_bottom = caps
	var arr := cm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_color(c)
		st.set_normal(nr[i])
		st.add_vertex(v[i] + Vector3(0, mid, 0))


## Расставить щупальца и пестрянок в момент t (время мира).
func sync(t: float) -> void:
	for hv in hvaten.anemones:
		for k in EcoHvaten.TENT:
			_put(tent_buffer, (hv.index * EcoHvaten.TENT + k) * STRIDE, EcoHvaten.tentacle(hv, k, t))
		for k in EcoHvaten.PESTR_N:
			var tr := EcoHvaten.pestr_pose(hv, k, t)
			tr.basis = tr.basis * Basis.from_scale(PESTR_SIZE)
			_put(pestr_buffer, (hv.index * EcoHvaten.PESTR_N + k) * STRIDE_C, tr)
	tents.multimesh.buffer = tent_buffer
	pestr.multimesh.buffer = pestr_buffer


static func _put(buf: PackedFloat32Array, i: int, tr: Transform3D) -> void:
	var b := tr.basis
	var o := tr.origin
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z


## Расстановка экземпляра n из буфера с шагом stride.
static func transform_at(buf: PackedFloat32Array, n: int, stride: int = STRIDE) -> Transform3D:
	var i := n * stride
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
