class_name BreachView
extends Node3D
## Пробоина изнутри (Breach, ART-013, модели MOD-013): обшивка с отверстием в борту, заплатка растёт со сваркой,
## шов светится #F18A3D и остывает, струя и искры — CPUParticles3D, вода — одна плоскость на пол отсека,
## янтарная лампа тревоги пульсирует в отсеке. Всё на слое корабля.

const WATER_COLOR := Color(0.525, 0.737, 0.796, 0.55)   ## #86BCCB
const ALARM_COLOR := Color("ffb259")
const SEAM_COLOR := Color("f18a3d")
const SPARK_COLOR := Color("d5e4e8")
const ALARM_ENERGY := 1.6
const HOLE_COLOR := Color("0b1c24")
const LIFT := 0.012          ## обшивка чуть над поверхностью борта, чтобы не мерцала с ним

var breach: Breach
var spot_node: Node3D        ## в точке пробоины, +Z — нормаль внутрь отсека
var plate: Node3D            ## обшивка с отверстием
var patch: Node3D            ## заплатка
var seam: Node3D             ## шов
var _seam_mat: StandardMaterial3D
var spray: CPUParticles3D
var sparks: CPUParticles3D
var splash: CPUParticles3D   ## брызги там, где струя бьёт в воду
var weld_light: OmniLight3D
var water: MeshInstance3D
var alarm: OmniLight3D
var _shown: Breach.Spot = null


func _init(b: Breach) -> void:
	breach = b
	name = "Пробоина"


func _ready() -> void:
	spot_node = Node3D.new()
	spot_node.name = "Место пробоины"
	spot_node.visible = false
	add_child(spot_node)
	var hole := MeshInstance3D.new()   # глухой борт за отверстием перекрашен в темноту за обшивкой
	hole.name = "Тьма за отверстием"
	var hq := QuadMesh.new()
	hq.size = Vector2(0.44, 0.29)
	hole.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = HOLE_COLOR
	hole.material_override = hm
	hole.position = Vector3(0, 0, -0.005)   # между бортом (−LIFT) и лицом обшивки
	hole.layers = OceanView.LAYER_SHIP
	spot_node.add_child(hole)
	plate = _model("proboina-obshivka")
	patch = _model("proboina-zaplatka")
	seam = _model("proboina-shov")
	var smi: MeshInstance3D = seam.find_children("*", "MeshInstance3D", true, false)[0]
	_seam_mat = (smi.get_active_material(0) as StandardMaterial3D).duplicate()
	_seam_mat.emission_enabled = true
	_seam_mat.emission = SEAM_COLOR
	_seam_mat.emission_energy_multiplier = 0.0
	smi.material_override = _seam_mat
	spray = CPUParticles3D.new()
	spray.name = "Струя"
	spray.layers = OceanView.LAYER_SHIP
	spray.emitting = false
	spray.amount = 96
	spray.lifetime = 0.9
	spray.position = Vector3(0, 0, 0.05)
	spray.direction = Vector3(0, Breach.JET_UP, 1)
	spray.spread = 12.0
	spray.initial_velocity_min = Breach.JET_V - 0.6
	spray.initial_velocity_max = Breach.JET_V + 0.6
	spray.gravity = Vector3(0, -Breach.JET_G, 0)
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.emission_box_extents = Vector3(0.15, 0.06, 0.0)
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 1.0
	spray.mesh = _dot_mesh(0.03, Color(0.62, 0.9, 0.94, 0.85), false)
	spot_node.add_child(spray)
	splash = CPUParticles3D.new()
	splash.name = "Брызги"
	splash.layers = OceanView.LAYER_SHIP
	splash.emitting = false
	splash.amount = 48
	splash.lifetime = 0.5
	splash.direction = Vector3(0, 1, 0)
	splash.spread = 40.0
	splash.initial_velocity_min = 0.8
	splash.initial_velocity_max = 1.8
	splash.gravity = Vector3(0, -9.0, 0)
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splash.emission_box_extents = Vector3(0.25, 0.0, 0.2)
	splash.scale_amount_min = 0.6
	splash.scale_amount_max = 1.2
	splash.mesh = _dot_mesh(0.035, Color(0.835, 0.894, 0.91, 0.8), false)   # пена #D5E4E8
	spot_node.add_child(splash)
	sparks = CPUParticles3D.new()
	sparks.name = "Искры сварки"
	sparks.layers = OceanView.LAYER_SHIP
	sparks.emitting = false
	sparks.amount = 40
	sparks.lifetime = 0.35
	sparks.position = Vector3(0, 0, 0.08)
	sparks.direction = Vector3(0, 0, 1)
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 3.0
	sparks.gravity = Vector3(0, -9.0, 0)
	sparks.mesh = _dot_mesh(0.025, Color("ffd08a"), true)
	spot_node.add_child(sparks)
	weld_light = OmniLight3D.new()
	weld_light.name = "Свет сварки"
	weld_light.light_color = SPARK_COLOR
	weld_light.light_cull_mask = OceanView.LAYER_SHIP
	weld_light.omni_range = 3.0
	weld_light.position = Vector3(0, 0, 0.3)
	weld_light.visible = false
	spot_node.add_child(weld_light)
	water = MeshInstance3D.new()
	water.name = "Вода на полу"
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = WATER_COLOR
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.15
	wm.metallic_specular = 0.8
	water.material_override = wm
	water.layers = OceanView.LAYER_SHIP
	water.visible = false
	add_child(water)
	alarm = OmniLight3D.new()
	alarm.name = "Тревога"
	alarm.light_color = ALARM_COLOR
	alarm.light_cull_mask = OceanView.LAYER_SHIP
	alarm.light_energy = 0.0
	alarm.visible = false
	add_child(alarm)


func _model(file: String) -> Node3D:
	var n: Node3D = load("res://models/%s.glb" % file).instantiate()
	n.name = file
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = OceanView.LAYER_SHIP
	spot_node.add_child(n)
	return n


static func _dot_mesh(size: float, c: Color, glow: bool) -> Mesh:
	var m := SphereMesh.new()
	m.radius = size / 2.0
	m.height = size
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	if c.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		mat.emission_enabled = true
		mat.emission = c
	m.material = mat
	return m


## Узел пробоины в осях корабля: начало — точка на борту, +Z — нормаль внутрь отсека.
static func spot_xform(s: Breach.Spot) -> Transform3D:
	return Transform3D(Basis.looking_at(-s.n, Vector3.UP), s.p + s.n * LIFT)


## Масштаб заплатки: растёт от центра со сваркой (0,05 → 1), после сварки — целая.
static func patch_scale(b: Breach) -> float:
	if b.active:
		return maxf(0.001, b.weld)
	return 1.0


## Свечение шва: во время сварки — по прогрессу, после — остывает.
static func seam_glow(b: Breach) -> float:
	return 1.6 * (b.weld if b.active else b.seam_heat)


## Брызги в осях узла пробоины (+Z — внутрь отсека): где струя падает на воду, высота — уровень воды.
static func splash_local(s: Breach.Spot, water_h: float) -> Vector3:
	return Vector3(0.0, water_h - s.p.y, Breach.jet_reach(s, water_h) - LIFT)


## Расставить по состоянию Breach (каждый шаг).
func apply() -> void:
	var s := breach.last
	spot_node.visible = s != null
	if s == null:
		water.visible = false
		alarm.visible = false
		return
	if s != _shown:
		_shown = s
		spot_node.transform = spot_xform(s)
	var k := patch_scale(breach)
	patch.scale = Vector3(k, k, 1.0)
	patch.visible = breach.active == null or breach.weld > 0.0
	seam.visible = patch.visible
	_seam_mat.emission_energy_multiplier = seam_glow(breach)
	spray.emitting = breach.active != null
	splash.emitting = spray.emitting
	if splash.emitting:
		splash.position = splash_local(s, breach.water)
	sparks.emitting = breach.welding
	weld_light.visible = breach.welding
	weld_light.light_energy = 1.5 + 0.8 * sin(breach.time * 53.0)
	var ws := breach.water_spot
	water.visible = ws != null and breach.water > 0.005
	if water.visible:
		var f := ws.floor
		water.position = Vector3(f.position.x + f.size.x / 2.0, breach.water, f.position.y + f.size.y / 2.0)
		water.scale = Vector3(f.size.x, 1.0, f.size.y)
	alarm.visible = breach.active != null
	if alarm.visible:
		var a := breach.active
		var top := BridgePlan.CEILING if a.room == ShipLayout.Room.BRIDGE else float(ShipLayout.ROOMS[a.room][3])
		alarm.position = Vector3(a.floor.position.x + a.floor.size.x / 2.0, top - 0.3, a.floor.position.y + a.floor.size.y / 2.0)
		alarm.omni_range = maxf(a.floor.size.x, a.floor.size.y) * 0.9
		alarm.light_energy = ALARM_ENERGY * breach.alarm()
