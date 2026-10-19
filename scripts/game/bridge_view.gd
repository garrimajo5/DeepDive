class_name BridgeView
extends Node3D
## Рисует мостик: оболочку из BridgePlan (бруски одной краски — одна поверхность меша, на всю оболочку
## один MeshInstance3D), стекло носового окна и модели художника из BridgeProps (GLB прямо из models/).
## Всё на слое корабля: свет сквозь лёд его не освещает, только плафоны.

var mesh_instance: MeshInstance3D
var props := {}        ## имя модели → узел
var wheel_mount: Node3D  ## узел штурвала (наклон к пилоту), колесо — его дочерняя модель
var wheel: Node3D


func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Оболочка"
	mesh_instance.mesh = build_mesh()
	mesh_instance.layers = OceanView.LAYER_SHIP
	add_child(mesh_instance)
	_add_glass()
	for p in BridgeProps.fixed():
		props[p.model] = _add_model(p, self)
	wheel_mount = Node3D.new()
	wheel_mount.name = "Штурвал"
	wheel_mount.position = BridgeProps.wheel().pos
	wheel_mount.rotation_degrees.x = BridgeProps.WHEEL_TILT
	add_child(wheel_mount)
	var wp := BridgeProps.wheel()
	wp.pos = Vector3.ZERO
	wheel = _add_model(wp, wheel_mount)
	props[BridgeProps.WHEEL] = wheel
	_light_screens(props[BridgeProps.SCREENS])
	# тёплый свет плафонов: две лампы под потолком вдоль мостика
	for z in [-3.5, 0.0]:
		var l := OmniLight3D.new()
		l.light_color = BridgePlan.COLORS[BridgePlan.Paint.PLAFOND]
		l.light_energy = 0.9
		l.omni_range = 7.5
		l.position = Vector3(0, 2.8, z)
		l.light_cull_mask = OceanView.LAYER_SHIP
		add_child(l)


## Поворот колеса вслед за штурвалом: turn −1…1 (вправо — по часовой, если смотреть из кресла).
func set_wheel_turn(turn: float) -> void:
	if wheel:
		wheel.rotation_degrees.z = -turn * BridgeProps.WHEEL_TURN_DEG


func _add_model(p: BridgeProps.Prop, parent: Node3D) -> Node3D:
	var scene: PackedScene = load(p.path())
	var n: Node3D = scene.instantiate()
	n.name = p.label
	n.position = p.pos
	n.scale = p.scale
	parent.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = OceanView.LAYER_SHIP
	return n


## Экраны пульта светятся ровным голубым (пока на них ничего не рисуем).
func _light_screens(n: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = BridgeProps.SCREEN_GLOW
	m.emission_enabled = true
	m.emission = BridgeProps.SCREEN_GLOW
	m.emission_energy_multiplier = 1.1
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


## Стекло носового окна: едва заметный бирюзовый отлив, чтобы было видно, что окно застеклено.
func _add_glass() -> void:
	var g := MeshInstance3D.new()
	g.name = "Стекло окна"
	var q := QuadMesh.new()
	q.size = Vector2(2 * BridgePlan.WINDOW_HALF, BridgePlan.WINDOW_TOP - BridgePlan.WINDOW_BOTTOM)
	g.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.85, 0.9, 0.07)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	g.material_override = m
	g.position = Vector3(0, (BridgePlan.WINDOW_TOP + BridgePlan.WINDOW_BOTTOM) / 2.0, BridgePlan.NOSE_INNER - 0.05)
	g.layers = OceanView.LAYER_SHIP
	add_child(g)


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
