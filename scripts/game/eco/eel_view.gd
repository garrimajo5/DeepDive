class_name EelView
extends Node3D
## Стеклоусты в сцене (initEels/eelRender в js/creatures.js; ART-006, `docs/concept-art/stekloust-skrebun.md`): пять
## MultiMesh на всех — камни логов (бурые, гранёные), прозрачная оболочка (#9AD9E8, звенья тела и голова), внутренности
## (#607F89, без своего света), два красных глаза (#E34D50, светятся сами — единственный свет вида) и кольцо присоски
## у пасти (на стекле расплющено). Стоит на слое отмели (OceanView.LAYER_WORLD).

const SHELL := Color(0.604, 0.851, 0.91, 0.3)   ## #9AD9E8, прозрачный край
const SHELL_GLOW := Color("16323a")
const ORGANS := Color("607f89")
const EYE := Color("e34d50")
const RING := Color("e8b8a8")
const ROCK := Color("5f586c")
## Звено k: радиус 0,34 · (1 − 0,7 k / SEGS) (в браузере 0,28), вытянуто вдоль тела в 2,6 раза; голова крупнее, чем
## в браузере (0,3 × (1; 0,8; 1,6)) — по концепту ART-006 пасть-присоска шире тела: 0,46 × 0,4 × 0,6 м.
const SEG_R := 0.34
const SEG_STRETCH := 2.6
const HEAD := Vector3(0.46, 0.4, 0.6)
## Внутренности — 0,45 звена, чуть ниже оси; глаза — по бокам головы сверху; кольцо — у пасти.
const ORGAN_K := 0.45
const EYE_R := 0.07
const EYES: Array[Vector3] = [Vector3(-0.24, 0.2, 0.3), Vector3(0.24, 0.2, 0.3)]
const RING_AT := Vector3(0, 0, 0.56)
const RING_FLAT := Vector3(1.35, 1.35, 0.5)
## На ходу тело виляет: смещение вбок sin(10t − 0,9k) · 0,05k.
const WAG := 0.05
const STRIDE := 12

var eels: EcoEel
var rocks: MultiMeshInstance3D
var shell: MultiMeshInstance3D
var organs: MultiMeshInstance3D
var eyes: MultiMeshInstance3D
var rings: MultiMeshInstance3D
## Последние буферы (для тестов).
var shell_buffer := PackedFloat32Array()
var ring_buffer := PackedFloat32Array()

var _organ_buffer := PackedFloat32Array()
var _eye_buffer := PackedFloat32Array()


func _init(system: EcoEel) -> void:
	eels = system
	name = "Стеклоусты"
	var n := eels.eels.size()
	rocks = _instance("Камни логов", build_rock(), n * EcoEel.ROCKS.size())
	shell = _instance("Оболочка", _sphere(10, 6, _shell_material()), n * EcoEel.SEGS)
	organs = _instance("Внутренности", _sphere(6, 4, _flat(ORGANS, false)), n * (EcoEel.SEGS - 1))
	eyes = _instance("Глаза", _sphere(6, 4, _flat(EYE, true), EYE_R), n * EYES.size())
	rings = _instance("Присоска", _ring(), n)
	_place_rocks()
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
	mi.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mi)
	return mi


static func _sphere(radial: int, rings_n: int, mat: Material, r: float = 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = radial
	m.rings = rings_n
	m.material = mat
	return m


static func _shell_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SHELL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.emission_enabled = true
	mat.emission = SHELL_GLOW
	mat.roughness = 0.2
	return mat


static func _flat(c: Color, glow: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mat.roughness = 0.8
	return mat


## Кольцо присоски: тор 0,24…0,34 м, ось — вперёд (+Z).
static func _ring() -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = 0.24
	m.outer_radius = 0.34
	m.rings = 16
	m.ring_segments = 6
	m.material = _flat(RING, false)
	return m


## Камень логова: гранёный шар радиуса 1 (додекаэдр с неровностями 0,18, как G.jitter в js/world.js) — вершины
## сдвинуты по направлению от середины на ±18 % по хешу направления, грани плоские.
static func build_rock() -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radial_segments = 7
	sm.rings = 4
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in idx.size():
		var p := v[idx[i]]
		var h := sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453
		st.add_vertex(p * (1.0 + (h - floor(h) - 0.5) * 0.36))
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROCK
	mat.roughness = 1.0
	m.surface_set_material(0, mat)
	return m


func _place_rocks() -> void:
	var buf := PackedFloat32Array()
	buf.resize(rocks.multimesh.instance_count * STRIDE)
	var n := 0
	for e in eels.eels:
		for r in e.rocks:
			var b := Basis.from_euler(Vector3(n * 1.7, n * 2.3, 0.0)).scaled(Vector3.ONE * r.w)
			_put(buf, n * STRIDE, Transform3D(b, Vector3(r.x, r.y, r.z)))
			n += 1
	rocks.multimesh.buffer = buf


## Расставить тела в момент t (время мира).
func sync(t: float) -> void:
	var n := eels.eels.size()
	shell_buffer.resize(n * EcoEel.SEGS * STRIDE)
	_organ_buffer.resize(n * (EcoEel.SEGS - 1) * STRIDE)
	_eye_buffer.resize(n * EYES.size() * STRIDE)
	ring_buffer.resize(n * STRIDE)
	for e in eels.eels:
		var segs := e.segs
		var wag := e.moving()
		for k in range(1, EcoEel.SEGS):
			var dir := segs[k - 1] - segs[k]
			if dir.length_squared() < 1e-6:
				dir = e.face
			dir = dir.normalized()
			var side := Vector3(dir.z, 0.0, -dir.x)
			side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
			var pos := segs[k] + side * (sin(t * 10.0 - k * 0.9) * WAG * k if wag else 0.0)
			var r := SEG_R * (1.0 - float(k) / EcoEel.SEGS * 0.7)
			var b := _look(dir)
			_put(shell_buffer, (e.index * EcoEel.SEGS + k) * STRIDE,
				Transform3D(b.scaled_local(Vector3(r, r * 0.85, r * SEG_STRETCH)), pos))
			_put(_organ_buffer, (e.index * (EcoEel.SEGS - 1) + k - 1) * STRIDE,
				Transform3D(b.scaled_local(Vector3(r, r * 0.8, r * SEG_STRETCH) * ORGAN_K), pos - Vector3(0, r * 0.15, 0)))
		var hb := _look(e.face)
		var head := Transform3D(hb, segs[0])
		_put(shell_buffer, e.index * EcoEel.SEGS * STRIDE, Transform3D(hb.scaled_local(HEAD), segs[0]))
		for j in EYES.size():
			_put(_eye_buffer, (e.index * EYES.size() + j) * STRIDE, Transform3D(hb, head * EYES[j]))
		var rb := hb * Basis(Vector3.RIGHT, PI / 2.0)
		if e.latched():
			rb = hb.scaled_local(RING_FLAT) * Basis(Vector3.RIGHT, PI / 2.0)
		_put(ring_buffer, e.index * STRIDE, Transform3D(rb, head * RING_AT))
	shell.multimesh.buffer = shell_buffer
	organs.multimesh.buffer = _organ_buffer
	eyes.multimesh.buffer = _eye_buffer
	rings.multimesh.buffer = ring_buffer


## Поворот, у которого +Z смотрит вдоль dir (голова — пастью вперёд).
static func _look(dir: Vector3) -> Basis:
	var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(dir, up, true)


static func _put(buf: PackedFloat32Array, i: int, tr: Transform3D) -> void:
	var b := tr.basis
	var o := tr.origin
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z


## Расстановка экземпляра n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
