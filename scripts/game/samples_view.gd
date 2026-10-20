class_name SamplesView
extends Node3D
## Образцы на дне (Samples): светящиеся камешки цвета вида, все одним MultiMesh (один вызов отрисовки), слой отмели.
## Поднятые прячутся.

var samples: Samples
var mm: MultiMeshInstance3D
var _version := -1


func _init(s: Samples) -> void:
	samples = s


func _ready() -> void:
	mm = MultiMeshInstance3D.new()
	mm.name = "Образцы на дне"
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	m.mesh = gem_mesh(0.22)
	m.instance_count = samples.all.size()
	mm.multimesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mm.material_override = mat
	mm.layers = OceanView.LAYER_WORLD
	add_child(mm)
	refresh()


## Перерисовать, если что-то изменилось на дне (зовёт шаг игры).
func sync() -> void:
	if samples.version != _version:
		refresh()


func refresh() -> void:
	_version = samples.version
	var m := mm.multimesh
	for s in samples.all:
		m.set_instance_transform(s.i, instance_xform(s))
		m.set_instance_color(s.i, Samples.COLORS[s.kind])


## Камешек на дне: свой поворот у каждого, поднятый сжат в точку.
static func instance_xform(s: Samples.Sample) -> Transform3D:
	var b := Basis(Vector3.UP, float(s.i)) * Basis(Vector3.BACK, 0.4)
	var sc := Vector3(0.001, 0.001, 0.001) if s.taken else Vector3(1.0, 1.3, 1.0)
	return Transform3D(b.scaled(sc), s.pos)


## Октаэдр радиуса r (как OctahedronGeometry в js/manip.js): лицевые стороны наружу.
static func gem_mesh(r: float) -> ArrayMesh:
	var v := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	var faces := [[2, 4, 0], [2, 0, 5], [2, 5, 1], [2, 1, 4], [3, 0, 4], [3, 5, 0], [3, 1, 5], [3, 4, 1]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var c: Vector3 = v[f[2]]
		# обход по часовой, если смотреть снаружи: (b − a) × (c − a) — внутрь
		if (b - a).cross(c - a).dot(a + b + c) > 0.0:
			var t := b
			b = c
			c = t
		var n := (a + b + c).normalized()
		for p in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(p)
	return st.commit()
