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


## Створки люков, крышка шлюза и цвет реактора — каждый кадр.
func apply(layout: ShipLayout, r: Reactor, lock: Airlock = null) -> void:
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
