class_name BridgeView
extends Node3D
## Рисует мостик: оболочку из BridgePlan (бруски одной краски — одна поверхность меша, на всю оболочку
## один MeshInstance3D), стекло носового окна и модели художника из BridgeProps (GLB прямо из models/).
## Всё на слое корабля: свет сквозь лёд его не освещает, только плафоны.

var mesh_instance: MeshInstance3D
var props := {}        ## имя модели → узел
var wheel_mount: Node3D  ## узел штурвала (наклон к пилоту), колесо — его дочерняя модель
var wheel: Node3D
var sliders: Array[Node3D] = []   ## ползунки пульта энергии: двигатели, сонар, жизнь, разряд, прожектор
var hatch_door: Node3D
var hatch_wheel: Node3D


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
	for p in BridgeProps.side_props():
		props[p.model] = _add_model(p, self)
	var panel: Node3D = props[BridgeProps.ENERGY]
	for i in BridgeProps.SLIDER_X.size():
		var s := _add_model(BridgeProps.Prop.new(BridgeProps.SLIDER, "Ползунок %d" % (i + 1), Vector3.ZERO), panel)
		sliders.append(s)
		light_texture(s)
		set_slider(i, 0.5)
	hatch_door = _add_model(BridgeProps.Prop.new(BridgeProps.HATCH_DOOR, "Створка люка", BridgeProps.HATCH_DOOR_OFFSET),
		props[BridgeProps.HATCH_FRAME])
	hatch_wheel = _add_model(BridgeProps.Prop.new(BridgeProps.HATCH_WHEEL, "Колесо люка", BridgeProps.HATCH_WHEEL_OFFSET),
		hatch_door)
	for name in props:
		if TextureGlow.MODELS.has(name):
			light_texture(props[name])
	# тёплый свет плафонов: две лампы под потолком вдоль мостика
	for z in [-3.5, 0.0]:
		var l := OmniLight3D.new()
		l.light_color = BridgePlan.COLORS[BridgePlan.Paint.PLAFOND]
		l.light_energy = 0.9
		l.omni_range = 7.5
		l.position = Vector3(0, 2.8, z)
		l.light_cull_mask = OceanView.LAYER_SHIP
		add_child(l)


## Ползунок i пульта энергии на долю share 0…1 (паз наклонён: ползунок идёт по лицу пульта).
func set_slider(i: int, share: float) -> void:
	var y := BridgeProps.slider_y(share)
	sliders[i].position = Vector3(BridgeProps.SLIDER_X[i], y, BridgeProps.slider_z(y))


## Створка люка в коридор отъезжает вбок на offset м; колесо крутится, пока створка не тронулась.
func set_hatch(offset: float) -> void:
	hatch_door.position.x = BridgeProps.HATCH_DOOR_OFFSET.x + offset
	hatch_wheel.rotation_degrees.z = -offset / ShipLayout.Door.SLIDE * 540.0


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
	n.rotation_degrees.y = p.rot_y
	parent.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = OceanView.LAYER_SHIP
	return n


const GLOW_SHADER := preload("res://shaders/tex_glow.gdshader")


## Голубые места текстуры модели светятся (TextureGlow): материал из GLB заменяется шейдером с той же текстурой.
static func light_texture(n: Node3D) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var src := m.get_active_material(0) as BaseMaterial3D
		if src == null or src.albedo_texture == null:
			continue
		var sm := ShaderMaterial.new()
		sm.shader = GLOW_SHADER
		sm.set_shader_parameter("albedo_tex", src.albedo_texture)
		sm.set_shader_parameter("mask_tex", src.albedo_texture)
		sm.set_shader_parameter("roughness", src.roughness)
		sm.set_shader_parameter("metallic", src.metallic)
		m.material_override = sm


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


static func build_mesh(parts: Array[BridgePlan.Part] = BridgePlan.parts()) -> ArrayMesh:
	var by_paint := {}
	for part in parts:
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
