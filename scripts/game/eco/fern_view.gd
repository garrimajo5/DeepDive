class_name FernView
extends Node3D
## Волнолист в сцене: все листья — один MultiMesh из одного листа-пера (12 треугольников, загнут наружу), моллюски
## у подножий — второй MultiMesh из полусферы (initFerns в js/creatures.js). Цвет листа #3D9D91, края и кончик
## светлее (#68E6DC, ART-004) — отражённый свет, своей эмиссии нет; виден с обеих сторон;
## лист — общий шейдер растений (EcoShaders.PLANT). Стоит на слое отмели (OceanView.LAYER_WORLD). Моллюски не двигаются — расставлены один раз.
## Муть (EcoFernDust) — третий MultiMesh «Муть» на общем шейдере EcoShaders.MIST.

const LEAF := Color("3D9D91")
const EDGE := Color("68E6DC")
const SHELL := Color("9a8fb2")
## Колыхание листа в течении (EcoCurrent.sway, в шейдере): крен, волна вверх, поперёк — доли длины листа.
const BEND := Vector3(0.1, 0.06, 0.04)
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
## Муть (EcoFernDust: раскрываясь, листья стряхивают ил; рыбы клюют моллюсков) — дочерний MultiMesh «Муть» на общем
## шейдере EcoShaders.MIST, +1 вызов; буфер — для тестов.
var dust := EcoFernDust.new()
var dust_view: MultiMeshInstance3D
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()
var _ground := Callable()


func _init(system: EcoFern, ground: Callable = Callable()) -> void:
	ferns = system
	_ground = ground
	name = "Волнолист"
	leaves = EcoMM.instance(self, "Листья", build_leaf(), ferns.ferns.size() * EcoFern.LEAVES, false, false, false)
	shells = EcoMM.instance(self, "Моллюски", build_shell(), ferns.ferns.size() * EcoFern.SHELLS, false, false, false)
	var buf := PackedFloat32Array()
	buf.resize(shells.multimesh.instance_count * STRIDE)
	for fe in ferns.ferns:
		for j in EcoFern.SHELLS:
			var p := EcoFern.shell_pos(fe, j, ground)
			var a := float(j) / EcoFern.SHELLS * TAU + fe.yaw
			var b := Basis(Vector3.UP, a).scaled_local(Vector3(1.0, 0.5, 1.3) * fe.scale)
			EcoMM.put(buf, (fe.index * EcoFern.SHELLS + j) * STRIDE, Transform3D(b, p))
	shells.multimesh.buffer = buf
	dust_view = GrazerView.build_dust(EcoFernDust.POOL)
	add_child(dust_view)
	sync(0.0)


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
	mesh.surface_set_material(0, EcoShaders.plant(EcoShaders.Plant.LEAF, {"paint": LEAF, "edge": EDGE, "rough": 0.7,
		"bend": BEND, "reach": EcoFern.LEAF_LEN}))
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


## Расставить листья в момент t (время мира). info — корабль (муть дальше 80 м не встаёт, светлее в луче),
## flow — течение мира (уносит муть); без корабля мути нет.
func sync(t: float, info: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	if info != null:
		dust.update(ferns, t, info.pos, _ground)
		_dust.pack(dust.dust, t, flow, info, EcoFernDust.COLOR, EcoFernDust.LIT, Seabed.mesh_height)
		_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)
	buffer.resize(leaves.multimesh.instance_count * STRIDE)
	for fe in ferns.ferns:
		for j in EcoFern.LEAVES:
			EcoMM.put(buffer, (fe.index * EcoFern.LEAVES + j) * STRIDE, Transform3D(EcoFern.leaf_basis(fe, j, t), fe.pos))
	leaves.multimesh.buffer = buffer


## Расстановка экземпляра n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
