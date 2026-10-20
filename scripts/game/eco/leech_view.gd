class_name LeechView
extends Node3D
## Пиявники в сцене (ART-003: плоская лента 0,2 м у жаберной щели, бурая с тёмными кольцами): один MultiMesh
## по экземпляру на серпохвоста, у здорового — нулевой масштаб. Место — EcoLeech.ON_BODY в осях тела хищника,
## лента слегка изгибается (жабры дышат). Стоит на слое отмели (OceanView.LAYER_WORLD).

## Лента: капсула 0,2 м длиной и 0,06 м шириной, сплющена к боку хищника; наклонена вдоль жаберной щели.
const LENGTH := 0.2
const RADIUS := 0.03
const FLAT := 0.3
const TILT := deg_to_rad(5.0)
## Изгиб: ±0,15 рад с частотой 2 рад/с.
const WIGGLE := 0.15
const WIGGLE_RATE := 2.0
const COLOR := Color("7a4636")

var leeches: EcoLeech
var mesh: MultiMeshInstance3D
## Последние места лент (по хищнику; для тестов — сервер отрисовки без экрана экземпляры не хранит).
var placed: Array[Transform3D] = []
var _buffer := PackedFloat32Array()


func _init(system: EcoLeech) -> void:
	leeches = system
	name = "Пиявники"
	mesh = MultiMeshInstance3D.new()
	mesh.name = "Ленты"
	mesh.layers = OceanView.LAYER_WORLD
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = build()
	var ps := leeches.preds()
	mm.instance_count = maxi(1, ps.all.size() if ps else 0)
	mesh.multimesh = mm
	mesh.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mesh)
	sync(0.0)


static func build() -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = RADIUS
	m.height = LENGTH
	m.radial_segments = 6
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.roughness = 0.8
	m.material = mat
	return m


## Где и как стоит лента на хищнике в момент t (нулевой масштаб — паразита нет).
static func place(pr: EcoPred.Pred, t: float) -> Transform3D:
	if not pr.leech or not pr.agent.alive:
		return Transform3D(Basis.from_scale(Vector3.ZERO), pr.agent.p)
	var bend := TILT + sin(t * WIGGLE_RATE + float(pr.index)) * WIGGLE
	var local := Basis(Vector3.RIGHT, bend) * Basis.from_scale(Vector3(FLAT, 1, 1))
	return Transform3D(EcoPredLook.basis(pr) * local, EcoLeech.position_on(pr))


func sync(t: float) -> void:
	var ps := leeches.preds()
	if ps == null:
		return
	var mm := mesh.multimesh
	var n := mini(ps.all.size(), mm.instance_count)
	placed.resize(n)
	_buffer.resize(mm.instance_count * 12)
	for i in n:
		var x := place(ps.all[i], t)
		placed[i] = x
		var b := x.basis
		var o := i * 12
		_buffer[o] = b.x.x; _buffer[o + 1] = b.y.x; _buffer[o + 2] = b.z.x; _buffer[o + 3] = x.origin.x
		_buffer[o + 4] = b.x.y; _buffer[o + 5] = b.y.y; _buffer[o + 6] = b.z.y; _buffer[o + 7] = x.origin.y
		_buffer[o + 8] = b.x.z; _buffer[o + 9] = b.y.z; _buffer[o + 10] = b.z.z; _buffer[o + 11] = x.origin.z
	mm.buffer = _buffer
