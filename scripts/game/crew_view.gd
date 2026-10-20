class_name CrewView
extends Node3D
## Фигуры экипажа на корабле (заглушка до модели по ART-014): у каждого члена экипажа — один MultiMesh из капсул,
## один вызов отрисовки. Поза — `Crew.Member.parts()`. Свой игрок рисуется без головы: камера стоит в ней.
## Узел живёт в осях корабля, слой света 2 (только плафоны корабля).

const LAYER_SHIP := 2

var members: Array = []  ## Crew.Member
var local: Crew.Member  ## свой игрок (без головы)
var figures: Array[MultiMeshInstance3D] = []
var torches: Array[Node3D] = []  ## резак MOD-013 у каждой фигуры: виден, пока она варит
var shown: Array = []  ## что нарисовано у каждой фигуры: имя части → Transform3D (для тестов и сети)
var _mesh: CapsuleMesh
var _material: StandardMaterial3D


func _init() -> void:
	name = "Экипаж"
	_mesh = CapsuleMesh.new()
	_mesh.radius = 0.5
	_mesh.height = 1.0
	_mesh.radial_segments = 10
	_mesh.rings = 3
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.75
	_mesh.material = _material


## Список экипажа; local — тот, чьими глазами смотрит камера.
func set_members(list: Array, me: Crew.Member) -> void:
	members = list
	local = me
	while figures.size() < members.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh
		mm.instance_count = Crew.ORDER.size()
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.layers = LAYER_SHIP
		add_child(mi)
		figures.append(mi)
		var t: Node3D = load("res://models/rezak.glb").instantiate()
		t.name = "Резак"
		t.visible = false
		for m in t.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).layers = LAYER_SHIP
		add_child(t)
		torches.append(t)
	for i in figures.size():
		figures[i].visible = i < members.size()
		torches[i].visible = false
		if i < members.size():
			figures[i].name = "Фигура %s" % members[i].name


func apply() -> void:
	for i in members.size():
		var m: Crew.Member = members[i]
		var own: bool = m == local
		var parts := m.parts(own)
		if shown.size() <= i:
			shown.resize(i + 1)
		shown[i] = parts
		torches[i].visible = m.welding()
		if torches[i].visible:
			torches[i].transform = m.torch_xform()
		var mm := figures[i].multimesh
		for n in Crew.ORDER.size():
			var key: String = Crew.ORDER[n]
			if parts.has(key):
				mm.set_instance_transform(n, parts[key])
				mm.set_instance_color(n, Crew.part_color(key, m.role))
			else:
				mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
