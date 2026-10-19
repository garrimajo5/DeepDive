class_name BridgeView
extends Node3D
## Рисует оболочку мостика из BridgePlan: все бруски одной краски — одна поверхность меша,
## на весь мостик один MeshInstance3D (5 поверхностей, 5 вызовов отрисовки). Плафоны светятся.

var mesh_instance: MeshInstance3D


func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Оболочка"
	mesh_instance.mesh = build_mesh()
	add_child(mesh_instance)
	# тёплый свет плафонов: две лампы под потолком вдоль мостика
	for z in [-3.5, 0.0]:
		var l := OmniLight3D.new()
		l.light_color = BridgePlan.COLORS[BridgePlan.Paint.PLAFOND]
		l.light_energy = 0.9
		l.omni_range = 7.5
		l.position = Vector3(0, 2.8, z)
		add_child(l)


static func build_mesh() -> ArrayMesh:
	var by_paint := {}
	for part in BridgePlan.parts():
		if not by_paint.has(part.paint):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			by_paint[part.paint] = st
		_add_box(by_paint[part.paint], part)
	var mesh := ArrayMesh.new()
	for paint in by_paint:
		var st: SurfaceTool = by_paint[paint]
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(paint))
	return mesh


static func material(paint: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = BridgePlan.COLORS[paint]
	m.roughness = 0.75
	m.metallic = 0.25 if paint == BridgePlan.Paint.METAL else 0.0
	if paint == BridgePlan.Paint.PLAFOND:
		m.emission_enabled = true
		m.emission = BridgePlan.COLORS[paint]
		m.emission_energy_multiplier = 1.4
	return m


## Брусок: 6 граней по 2 треугольника, нормали наружу, обход для лицевой стороны Godot.
static func _add_box(st: SurfaceTool, part: BridgePlan.Part) -> void:
	var t := part.xform()
	var h := part.size / 2.0
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := n * h
		var du := u * h
		var dv := v * h
		var q := [c - du - dv, c - du + dv, c + du + dv, c + du - dv]
		var nn := (t.basis * n).normalized()
		# порядок a, b, c такой, что (b − a) × (c − a) смотрит внутрь — лицевая сторона наружу
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nn)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(t * q[i])
