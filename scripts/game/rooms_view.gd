class_name RoomsView
extends Node3D
## Отсеки за мостиком (ShipLayout): коридор, лаборатория, машинное с реактором (MOD-008), трюм; створки люков.
## Всё на слое корабля, свет — лампы отсеков; стержень реактора светится цветом состояния.

var mesh_instance: MeshInstance3D
var doors: Array[Node3D] = []      ## створки люков 2…4 (у первого — модель MOD-006 на мостике)
var reactor_rod: MeshInstance3D
var _rod_mat: StandardMaterial3D
var reactor_light: OmniLight3D
var airlock_cover: MeshInstance3D   ## крышка нижнего шлюза (пока диск; модель — MOD-010, issue #20)
var valve_wheel: Node3D            ## маховик вентиля сброса пара (MOD-009), крутится по x
var panel_lid: Node3D              ## крышка щитка «Аварийный сброс» (MOD-009), откидывается по z
var steam: CPUParticles3D          ## пар из вентиля
var _button_mat: StandardMaterial3D


func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Отсеки"
	mesh_instance.mesh = BridgeView.build_mesh(ShipLayout.parts())
	mesh_instance.layers = OceanView.LAYER_SHIP
	add_child(mesh_instance)
	for room in ShipLayout.ROOMS:
		var a: Array = ShipLayout.ROOMS[room]
		var l := OmniLight3D.new()
		l.name = "Свет: " + ShipLayout.ROOM_NAMES[room]
		l.light_color = BridgePlan.COLORS[BridgePlan.Paint.PLAFOND]
		l.light_energy = 0.8
		l.omni_range = maxf(float(a[1]) - float(a[0]), float(a[2]) * 2.0) * 0.9
		l.position = Vector3(0, float(a[3]) - 0.4, (float(a[0]) + float(a[1])) / 2.0)
		l.light_cull_mask = OceanView.LAYER_SHIP
		add_child(l)
	var door_mat := BridgeView.material(BridgePlan.Paint.SEAM)
	for i in range(1, ShipLayout.DOOR_Z.size()):
		var d := MeshInstance3D.new()
		d.name = "Створка люка %d" % (i + 1)
		var bm := BoxMesh.new()
		bm.size = Vector3(2 * ShipLayout.DOOR_HALF + 0.1, ShipLayout.DOOR_H + 0.05, 0.08)
		d.mesh = bm
		d.material_override = door_mat
		d.layers = OceanView.LAYER_SHIP
		d.position = Vector3(0, ShipLayout.DOOR_H / 2.0, ShipLayout.DOOR_Z[i] + 0.15)
		add_child(d)
		doors.append(d)
	_add_reactor()
	_add_engine_room()
	airlock_cover = MeshInstance3D.new()
	airlock_cover.name = "Крышка шлюза"
	var cm := CylinderMesh.new()
	cm.top_radius = Airlock.RADIUS
	cm.bottom_radius = Airlock.RADIUS
	cm.height = Airlock.THICK
	airlock_cover.mesh = cm
	var lm := BridgeView.material(BridgePlan.Paint.METAL)
	airlock_cover.material_override = lm
	airlock_cover.layers = OceanView.LAYER_SHIP | OceanView.LAYER_WORLD
	add_child(airlock_cover)


func _add_reactor() -> void:
	var root := Node3D.new()
	root.name = "Реактор"
	root.position = ShipLayout.REACTOR_POS
	add_child(root)
	for m in ["reaktor-osnova", "reaktor-kozhuh", "reaktor-sterzhen"]:
		var n: Node3D = load("res://models/%s.glb" % m).instantiate()
		n.name = m
		root.add_child(n)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).layers = OceanView.LAYER_SHIP
			if m == "reaktor-sterzhen":
				reactor_rod = mi
	_rod_mat = (reactor_rod.get_active_material(0) as StandardMaterial3D).duplicate()
	_rod_mat.emission_enabled = true
	reactor_rod.material_override = _rod_mat
	reactor_light = OmniLight3D.new()
	reactor_light.name = "Свет реактора"
	reactor_light.position = Vector3(0, 1.6, 0)
	reactor_light.omni_range = 4.5
	reactor_light.light_cull_mask = OceanView.LAYER_SHIP
	root.add_child(reactor_light)


func _model(file: String, pos: Vector3) -> Node3D:
	var n: Node3D = load("res://models/%s.glb" % file).instantiate()
	n.name = file
	n.position = pos
	add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = OceanView.LAYER_SHIP
	return n


## Машинное (MOD-009): вентиль на левой стене, щиток на правой; пар — частицы у маховика.
func _add_engine_room() -> void:
	_model("ventil-truba", EngineRoom.VALVE_POS)
	valve_wheel = _model("ventil-koleso", EngineRoom.VALVE_WHEEL)
	var panel := _model("shchitok", EngineRoom.PANEL_POS)
	panel_lid = _model("shchitok-kryshka", EngineRoom.LID_POS)
	var bmi: MeshInstance3D = panel.find_children("*", "MeshInstance3D", true, false)[0]
	_button_mat = (bmi.get_active_material(0) as StandardMaterial3D).duplicate()
	bmi.material_override = _button_mat
	steam = CPUParticles3D.new()
	steam.name = "Пар вентиля"
	steam.position = EngineRoom.VALVE_POS + Vector3(0.18, 0.12, 0.0)
	steam.layers = OceanView.LAYER_SHIP
	steam.emitting = false
	steam.amount = 48
	steam.lifetime = 1.4
	steam.direction = Vector3(1.0, 0.8, 0.0)
	steam.spread = 22.0
	steam.initial_velocity_min = 1.2
	steam.initial_velocity_max = 1.8
	steam.gravity = Vector3(0, 0.6, 0)
	steam.damping_min = 1.0
	steam.damping_max = 1.6
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.25))
	grow.add_point(Vector2(1, 1.6))
	steam.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.84, 0.89, 0.91, 0.4))
	fade.set_color(1, Color(0.84, 0.89, 0.91, 0.0))
	steam.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.billboard_keep_scale = true
	sm.albedo_texture = _puff()
	q.material = sm
	steam.mesh = q
	add_child(steam)


## Мягкое круглое пятно пара 32×32.
static func _puff() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
	return ImageTexture.create_from_image(img)


## Створки люков, крышка шлюза и цвет реактора — каждый кадр.
func apply(layout: ShipLayout, r: Reactor, lock: Airlock = null, engine: EngineRoom = null) -> void:
	if engine:
		valve_wheel.rotation_degrees.x = engine.wheel_deg
		panel_lid.rotation_degrees.z = EngineRoom.LID_OPEN_DEG * engine.lid
		steam.emitting = engine.venting
		_button_mat.emission_energy_multiplier = 1.0 + 0.8 * minf(engine.pressed, 1.0)
	if lock:
		airlock_cover.transform = lock.cover_pose()
	for i in doors.size():
		doors[i].position.x = layout.doors[i + 1].offset()
	var c := ShipLayout.rod_color(r)
	_rod_mat.albedo_color = c
	_rod_mat.emission = c
	_rod_mat.emission_energy_multiplier = 0.0 if r.scram > 0.0 else 1.4
	reactor_light.light_color = c
	reactor_light.light_energy = 0.0 if r.scram > 0.0 else 1.2
