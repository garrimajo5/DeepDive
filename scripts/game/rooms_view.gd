class_name RoomsView
extends Node3D
## Отсеки за мостиком (ShipLayout): коридор, лаборатория, машинное с реактором (MOD-008), трюм; створки люков.
## Всё на слое корабля, свет — лампы отсеков; стержень реактора светится цветом состояния.

var mesh_instance: MeshInstance3D
var doors: Array[Node3D] = []      ## створки люков 2…4 (у первого — модель MOD-006 на мостике)
var reactor_rod: MeshInstance3D
var _rod_mat: StandardMaterial3D
var reactor_light: OmniLight3D
var lamps: Array[OmniLight3D] = []  ## плафоны отсеков (мигают — set_lamps)
const LAMP_ENERGY := 0.8
var airlock_cover: Node3D          ## крышка нижнего шлюза: узел в центре крышки (Airlock.cover_pose), модель MOD-010 внутри
var winch_drum: Node3D             ## барабан лебёдки (MOD-010), крутится по x
var winch_hook: Node3D             ## захват на тросе, pivot — крепление троса
var winch_cable: MeshInstance3D    ## трос от барабана до захвата
var winch_carry: MeshInstance3D    ## образец под захватом при подъёме
var _carry_mat: StandardMaterial3D
var valve_wheel: Node3D            ## маховик вентиля сброса пара (MOD-009), крутится по x
var panel_lid: Node3D              ## крышка щитка «Аварийный сброс» (MOD-009), откидывается по z
var steam: CPUParticles3D          ## пар из вентиля
var _button_mat: StandardMaterial3D
var lab_samples: Array[MeshInstance3D] = []   ## образцы в колбах (Lab.contents), светятся цветом вида
const JOURNAL_TEXT := Color("67DDEB")
var lab_ring: Node3D               ## кольцо-светильник на потолке лаборатории (MOD-020), вставка мигает с плафонами
var _ring_mats: Array[BaseMaterial3D] = []
var journal_text: Label3D          ## экран стойки журнала (Lab.journal_lines)
var _lab_kinds: Array[int] = []
## Полки трюма (MOD-017, HoldShelves): банки — металл и стекло — и образцы в них, по MultiMesh на всё (3 вызова).
var shelf_jars: MultiMeshInstance3D
var shelf_glass: MultiMeshInstance3D
var shelf_samples: MultiMeshInstance3D
var _shelf_kinds: Array[int] = []


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
		l.light_energy = LAMP_ENERGY
		l.omni_range = maxf(float(a[1]) - float(a[0]), float(a[2]) * 2.0) * 0.9
		l.position = Vector3(0, float(a[3]) - 0.4, (float(a[0]) + float(a[1])) / 2.0)
		l.light_cull_mask = OceanView.LAYER_SHIP
		add_child(l)
		lamps.append(l)
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
	airlock_cover = Node3D.new()
	airlock_cover.name = "Крышка шлюза"
	add_child(airlock_cover)
	var lid := _model("lyuk-tryuma-kryshka", Vector3(0, 0, -Airlock.RADIUS), airlock_cover)   # pivot модели — на петле
	_set_layers(lid, OceanView.LAYER_SHIP | OceanView.LAYER_WORLD)
	_add_winch()
	_add_shelves()
	_add_lab()


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


## Плафоны отсеков × k (мигание, Vitals.lamp_k). Свет реактора и тревоги пробоины не мигают.
## Яркость экрана журнала при помехах (Vitals.screen_k).
func set_journal_k(k: float) -> void:
	journal_text.modulate = Color(JOURNAL_TEXT.r * k, JOURNAL_TEXT.g * k, JOURNAL_TEXT.b * k)


func set_lamps(k: float) -> void:
	for l in lamps:
		l.light_energy = LAMP_ENERGY * k
	for m in _ring_mats:   # голубая вставка кольца гаснет и мигает вместе с плафонами
		m.emission_energy_multiplier = k


func _model(file: String, pos: Vector3, parent: Node3D = null) -> Node3D:
	var n: Node3D = load("res://models/%s.glb" % file).instantiate()
	n.name = file
	n.position = pos
	(parent if parent else self).add_child(n)
	_set_layers(n, OceanView.LAYER_SHIP)
	return n


static func _set_layers(n: Node3D, layers: int) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = layers


## Лебёдка трюма (MOD-010, tryum.md): опора у кормовой кромки проёма, барабан над центром проёма, трос и захват.
## Захват и трос уходят за борт — видны и снаружи (слои корабля и отмели).
func _add_winch() -> void:
	_model("lebedka-opora", Samples.BASE)
	winch_drum = _model("lebedka-baraban", Samples.DRUM)
	winch_hook = _model("lebedka-zahvat", Samples.REST)
	_set_layers(winch_hook, OceanView.LAYER_SHIP | OceanView.LAYER_WORLD)
	winch_cable = MeshInstance3D.new()
	winch_cable.name = "Трос лебёдки"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	winch_cable.mesh = cm
	winch_cable.material_override = BridgeView.material(BridgePlan.Paint.SHADOW)
	winch_cable.layers = OceanView.LAYER_SHIP | OceanView.LAYER_WORLD
	add_child(winch_cable)
	winch_carry = MeshInstance3D.new()
	winch_carry.name = "Образец в захвате"
	winch_carry.mesh = SamplesView.gem_mesh(0.2)
	_carry_mat = StandardMaterial3D.new()
	_carry_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	winch_carry.material_override = _carry_mat
	winch_carry.layers = OceanView.LAYER_SHIP | OceanView.LAYER_WORLD
	winch_carry.visible = false
	add_child(winch_carry)
	set_winch(Samples.REST, false, Color.WHITE)


## Захват в точке hook (оси корабля); carrying — под ним висит образец цвета c.
func set_winch(hook: Vector3, carrying: bool, c: Color) -> void:
	winch_hook.position = hook
	var top := Samples.DRUM + Vector3(0, -Samples.DRUM_R, 0)
	var d := hook - top
	var len := maxf(d.length(), 0.01)
	winch_cable.position = top + d / 2.0
	winch_cable.basis = Basis(_turn_to(d / len)).scaled(Vector3(1, len, 1))
	winch_drum.rotation.x = len / Samples.DRUM_R
	winch_carry.visible = carrying
	winch_carry.position = hook + Vector3(0, -0.85, 0)
	_carry_mat.albedo_color = c


## Поворот оси цилиндра (y) вдоль dir; трос всегда идёт вниз, поэтому считаем от −y (цилиндр симметричен).
static func _turn_to(dir: Vector3) -> Quaternion:
	if dir.is_equal_approx(Vector3.DOWN):
		return Quaternion.IDENTITY
	return Quaternion(Vector3.DOWN, dir)


## Полки трюма (MOD-017, tryum.md): стеллаж у каждого борта; банки с образцами груза — в ячейках HoldShelves.cells().
func _add_shelves() -> void:
	for side in HoldShelves.RACKS.size():
		var rack := _model("stellazh-tryuma", HoldShelves.RACKS[side])
		rack.name = "Стеллаж %s" % ["левый", "правый"][side]
		rack.rotation.y = HoldShelves.rack_yaw(side)
	shelf_jars = _multi("banka-obraztsa", "Банки на полках")
	shelf_glass = _multi("banka-steklo", "Стекло банок")
	var cm := CylinderMesh.new()
	cm.top_radius = HoldShelves.SAMPLE_R
	cm.bottom_radius = HoldShelves.SAMPLE_R
	cm.height = HoldShelves.SAMPLE_Y1 - HoldShelves.SAMPLE_Y0
	cm.radial_segments = 10
	cm.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # образец светится цветом вида, как в колбах
	mat.vertex_color_use_as_albedo = true
	cm.material = mat
	shelf_samples = _multi_mesh(cm, "Образцы на полках", true)
	var cells := HoldShelves.cells()
	for mm in [shelf_jars, shelf_glass, shelf_samples]:
		for i in HoldShelves.CAPACITY:
			var lift := (HoldShelves.SAMPLE_Y0 + HoldShelves.SAMPLE_Y1) / 2.0 if mm == shelf_samples else 0.0
			mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cells[i] + Vector3(0, lift, 0)))
	set_shelves([])


## MultiMesh на CAPACITY ячеек из первой сетки модели file (материалы модели).
func _multi(file: String, label: String) -> MultiMeshInstance3D:
	var n: Node3D = load("res://models/%s.glb" % file).instantiate()
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var mm := _multi_mesh(mi.mesh, label, false)
	n.free()
	return mm


func _multi_mesh(mesh: Mesh, label: String, colors: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = HoldShelves.CAPACITY
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.layers = OceanView.LAYER_SHIP
	add_child(node)
	return node


## Банки на полках: виды по ячейкам (HoldShelves.contents), заполнены первые — пустые ячейки пустые.
func set_shelves(kinds: Array[int]) -> void:
	if kinds == _shelf_kinds:
		return
	_shelf_kinds = kinds.duplicate()
	var n := 0
	for i in kinds.size():
		if kinds[i] < 0:
			break
		shelf_samples.multimesh.set_instance_color(i, Samples.COLORS[kinds[i]])
		n += 1
	for mm in [shelf_jars, shelf_glass, shelf_samples]:
		# пусто — узел скрыт со всеми банками: прогрев шейдеров (Main._warm_show) покажет его на кадр целиком
		mm.multimesh.visible_instance_count = n if n > 0 else -1
		mm.visible = n > 0


## Что стоит на полках: вид в каждой ячейке HoldShelves.cells() (−1 — пусто).
func shown_shelves() -> Array[int]:
	return _shelf_kinds


## Лаборатория (MOD-015, laboratoriya.md): три тумбы со стеклом, в колбах — образцы груза; стойка журнала с экраном.
func _add_lab() -> void:
	for i in Lab.FLASKS.size():
		var f: Vector2 = Lab.FLASKS[i]
		var base := _model("kolba-tumba", Vector3(f.x, 0.0, f.y))
		base.name = "Колба %d" % (i + 1)
		_model("kolba-steklo", Vector3(0.0, Lab.GLASS_Y, 0.0), base)
		var orb := MeshInstance3D.new()
		orb.name = "Образец в колбе %d" % (i + 1)
		orb.mesh = SamplesView.gem_mesh(0.16)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # образец светится своим цветом
		orb.material_override = m
		orb.layers = OceanView.LAYER_SHIP
		orb.position = Vector3(f.x, Lab.SAMPLE_Y, f.y)
		orb.visible = false
		add_child(orb)
		lab_samples.append(orb)
	lab_ring = _model("kolco-svetilnik", Lab.RING)
	lab_ring.name = "Кольцо-светильник"
	for mi: MeshInstance3D in lab_ring.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.mesh.surface_get_material(0)
		if mat is BaseMaterial3D:   # своя копия: яркость вставки — по плафонам (set_lamps)
			var own := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			mi.material_override = own
			_ring_mats.append(own)
	var stand := _model("zhurnal-stoyka", Vector3(Lab.JOURNAL.x, 0.0, Lab.JOURNAL.y))
	var screen := _model("zhurnal-ekran", Vector3.ZERO, stand)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color("071820")
	for mi in screen.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = sm
	journal_text = Label3D.new()
	journal_text.name = "Экран журнала"
	journal_text.layers = OceanView.LAYER_SHIP
	journal_text.font_size = 26   # 8 строк сводки и карточка вида с заметкой помещаются на экран
	journal_text.outline_size = 0
	journal_text.pixel_size = 0.0016
	journal_text.modulate = JOURNAL_TEXT
	journal_text.shaded = false
	journal_text.double_sided = true   # материал общий с подписями (issue #159)
	journal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	journal_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	journal_text.width = Lab.SCREEN_SIZE.x / journal_text.pixel_size - 40.0
	journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# экран смотрит к −X и вверх: текст вправо — к +Z, вверх — к верхней кромке экрана
	var n := Lab.SCREEN_NORMAL
	var right := Vector3(0, 0, 1)
	var up := n.cross(right)
	var top_left := Lab.SCREEN_CENTER - right * (Lab.SCREEN_SIZE.x / 2.0 - 0.03) + up * (Lab.SCREEN_SIZE.y / 2.0 - 0.03)
	journal_text.transform = Transform3D(Basis(right, up, n), top_left + n * 0.004)
	stand.add_child(journal_text)
	set_lab([-1, -1, -1], PackedStringArray(), 0.0)


## Образцы в колбах (виды или −1) и текст журнала; t — время для покачивания.
func set_lab(kinds: Array, lines: PackedStringArray, t: float) -> void:
	for i in lab_samples.size():
		var k: int = kinds[i] if i < kinds.size() else -1
		var orb := lab_samples[i]
		orb.visible = k >= 0
		if k >= 0:
			var c: Color = Samples.COLORS[k]
			var m := orb.material_override as StandardMaterial3D
			m.albedo_color = c
			var f: Vector2 = Lab.FLASKS[i]
			orb.position = Vector3(f.x, Lab.SAMPLE_Y + Lab.bob(t, i), f.y)
			orb.rotation.y = t * 0.4 + float(i)
	var text := "\n".join(lines)
	if journal_text.text != text:
		journal_text.text = text


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
