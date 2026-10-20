class_name OgnevkaView
extends Node3D
## Огнёвки в сцене (js/creatures.js initStations: капсулы 0,06 × 0,2 м, MeshBasicMaterial #FFA040 — светятся сами):
## один MultiMesh на всех рачков всех станций, капсула вытянута по ходу. Стоит на слое отмели (OceanView.LAYER_WORLD).

const RADIUS := 0.06
const LENGTH := 0.2
const COLOR := Color("ffa040")

var ognevka: EcoOgnevka
var mesh: MultiMeshInstance3D
## Последние места рачков (для тестов — сервер отрисовки без экрана экземпляры не хранит).
var placed: Array[Transform3D] = []
var _buffer := PackedFloat32Array()


func _init(system: EcoOgnevka) -> void:
	ognevka = system
	name = "Огнёвки"
	mesh = MultiMeshInstance3D.new()
	mesh.name = "Рачки"
	mesh.layers = OceanView.LAYER_WORLD
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = build()
	mm.instance_count = maxi(1, ognevka.leeches.stations.size() * EcoOgnevka.PER_STATION)
	mesh.multimesh = mm
	mesh.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mesh)
	sync(true)


static func build() -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = RADIUS
	m.height = LENGTH + RADIUS * 2.0
	m.radial_segments = 5
	m.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COLOR
	m.material = mat
	return m


## Капсула вдоль хода рачка: ось капсулы (Y меша) — по направлению dir.
static func place(s: EcoOgnevka.Shrimp) -> Transform3D:
	var y := s.dir
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y)), s.p)


## Переписывает только рачков, шагнувших в этом шаге мира (EcoOgnevka шагает их половинами); all — всех.
func sync(all := false) -> void:
	var mm := mesh.multimesh
	var n := mini(ognevka.shrimp.size(), mm.instance_count)
	if placed.size() != n or _buffer.size() != mm.instance_count * 12:
		placed.resize(n)
		_buffer.resize(mm.instance_count * 12)
		_buffer.fill(0.0)
		all = true
	var from := 0 if all else ognevka.moved_half()
	var stride := 1 if all else 2
	for i in range(from, n, stride):
		var x := place(ognevka.shrimp[i])
		placed[i] = x
		var b := x.basis
		var o := i * 12
		_buffer[o] = b.x.x; _buffer[o + 1] = b.y.x; _buffer[o + 2] = b.z.x; _buffer[o + 3] = x.origin.x
		_buffer[o + 4] = b.x.y; _buffer[o + 5] = b.y.y; _buffer[o + 6] = b.z.y; _buffer[o + 7] = x.origin.y
		_buffer[o + 8] = b.x.z; _buffer[o + 9] = b.y.z; _buffer[o + 10] = b.z.z; _buffer[o + 11] = x.origin.z
	mm.buffer = _buffer
