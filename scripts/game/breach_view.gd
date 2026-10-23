class_name BreachView
extends Node3D
## Пробоина изнутри (Breach, ART-013, модели MOD-013): обшивка с отверстием в борту, заплатка растёт со сваркой,
## шов светится #F18A3D и остывает, вода — одна плоскость на пол отсека, янтарная лампа тревоги пульсирует в отсеке.
## Струя, брызги и искры сварки по ART-072 — пулы `BreachSpray` (`parts`), три MultiMesh с общим материалом
## (`shaders/breach_spray.gdshader`, атлас `textures/proboina/atlas.png`). Всё на слое корабля.

const WATER_COLOR := Color(0.525, 0.737, 0.796, 0.55)   ## #86BCCB
const ALARM_COLOR := Color("ffb259")
const SEAM_COLOR := Color("f18a3d")
const SPARK_COLOR := Color("d5e4e8")
const HOLE_COLOR := Color("0b1c24")
const SIREN_DB := -16.0      ## сирена тише струи: слышно, но не оглушает (js/audio.js: 0,05 при общей 0,7)
const JET_DB := -4.0
const LIFT := BreachSpray.LIFT   ## обшивка чуть над поверхностью борта, чтобы не мерцала с ним

var breach: Breach
var spot_node: Node3D        ## в точке пробоины, +Z — нормаль внутрь отсека
var plate: Node3D            ## обшивка с отверстием
var patch: Node3D            ## заплатка
var seam: Node3D             ## шов
var _seam_mat: StandardMaterial3D
var parts := BreachSpray.new()   ## частицы ART-072: струя, брызги, искры
var spray_mat: ShaderMaterial    ## общий материал трёх MultiMesh
var jet_mm: MultiMeshInstance3D      ## струя
var splash_mm: MultiMeshInstance3D   ## брызги там, где струя бьёт в воду
var spark_mm: MultiMeshInstance3D    ## искры сварки и вспышка электрода
var lamp_k := 1.0                ## свет отсеков (Vitals.lamp_k × шторка): вода в темноте не светится
var weld_light: OmniLight3D
var water: MeshInstance3D
var alarm: OmniLight3D
var siren: AudioStreamPlayer       ## сирена на весь корабль, пока пробоина открыта (Synth.siren)
var jet_sound: AudioStreamPlayer3D ## шум струи из отверстия (Synth.jet)
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
	spray_mat = ShaderMaterial.new()
	spray_mat.shader = load("res://shaders/breach_spray.gdshader")
	spray_mat.set_shader_parameter("atlas", load(BreachSpray.ATLAS))
	spray_mat.set_shader_parameter("glow", BreachSpray.GLOW)
	jet_mm = _spray_node("Струя", BreachSpray.JET_LIMIT)
	splash_mm = _spray_node("Брызги", BreachSpray.SPLASH_LIMIT)
	spark_mm = _spray_node("Искры сварки", BreachSpray.SPARK_LIMIT + 1)
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
	siren = AudioStreamPlayer.new()
	siren.name = "Сирена"
	siren.stream = Synth.siren()
	siren.volume_db = SIREN_DB
	add_child(siren)
	jet_sound = AudioStreamPlayer3D.new()
	jet_sound.name = "Шум струи"
	jet_sound.stream = Synth.jet()
	jet_sound.volume_db = JET_DB
	jet_sound.unit_size = 2.5
	jet_sound.max_distance = 18.0
	jet_sound.position = Vector3(0, 0, 0.1)
	spot_node.add_child(jet_sound)
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


## MultiMesh частиц ART-072 в осях узла пробоины: квадрат 1×1, общий материал, данные кадра в custom.
## Пусто — одна прозрачная карточка (прогрев покажет её на кадр), узел скрыт.
func _spray_node(nm: String, cap: int) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = spray_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = cap
	mm.custom_aabb = AABB(Vector3(-2.0, -1.6, -0.2), Vector3(4.0, 3.2, 5.0))   # отсек перед пробоиной
	var n := MultiMeshInstance3D.new()
	n.name = nm
	n.multimesh = mm
	n.layers = OceanView.LAYER_SHIP
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill(n, [])
	spot_node.add_child(n)
	return n


## Карточки: [центр, ширина, вектор длины, custom] в осях пробоины.
static func _fill(n: MultiMeshInstance3D, cards: Array) -> void:
	var mm := n.multimesh
	var c := mini(cards.size(), mm.instance_count)
	for i in c:
		var d: Array = cards[i]
		var along: Vector3 = d[2]
		var wv := Vector3.RIGHT * float(d[1])
		mm.set_instance_transform(i, Transform3D(Basis(wv, along, Vector3.BACK), d[0]))
		mm.set_instance_custom_data(i, d[3])
	if c == 0:
		mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(0.1, 0.1, 1.0)), Vector3.ZERO))
		mm.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
	mm.visible_instance_count = maxi(c, 1)
	n.visible = c > 0


## Нарисовать пулы BreachSpray: струя по скорости, брызги стоя, искры по скорости и электрод.
func draw_parts() -> void:
	var jets := []
	for p in parts.jet:
		var a := p.age / p.life
		var sz := BreachSpray.jet_size(a, parts.lite)
		jets.append([BreachSpray.jet_pos(p.age, p.angle), sz.x, BreachSpray.jet_vel(p.age).normalized() * sz.y,
			Color(BreachSpray.frame(a, BreachSpray.JET_FRAMES), BreachSpray.jet_alpha(a), BreachSpray.JET_FRAMES.y, 0.0)])
	_fill(jet_mm, jets)
	var spl := []
	var s := breach.last
	if s:
		var c := BreachSpray.splash_at(s, breach.water)
		for p in parts.splash:
			var a := p.age / p.life
			var sz := BreachSpray.splash_size(a)
			spl.append([BreachSpray.splash_pos(c, p.age, p.angle, p.k) + Vector3(0.0, sz.y * 0.5, 0.0), sz.x,
				Vector3.UP * sz.y, Color(BreachSpray.frame(a, BreachSpray.SPLASH_FRAMES), BreachSpray.splash_alpha(a),
				BreachSpray.SPLASH_FRAMES.y, 0.0)])
	_fill(splash_mm, spl)
	var spk := []
	for p in parts.sparks:
		var a := p.age / BreachSpray.SPARK_LIFE
		var v := BreachSpray.spark_vel(p.v, p.age, p.floor_y)
		var sz := BreachSpray.spark_size(v)
		spk.append([BreachSpray.spark_pos(p.v, p.age, p.floor_y) - v.normalized() * sz.y * 0.5, sz.x,
			v.normalized() * sz.y, Color(BreachSpray.frame(a, BreachSpray.SPARK_FRAMES), BreachSpray.spark_alpha(a),
			BreachSpray.SPARK_FRAMES.y, 1.0 + BreachSpray.S(0.05, 0.70, a))])
	if parts.flash:
		var f := 0.2 * (0.85 + 0.15 * sin(breach.time * 53.0))
		spk.append([BreachSpray.SPARK_FROM, f, Vector3.UP * f,
			Color(BreachSpray.FLASH_FRAME, 0.9, BreachSpray.FLASH_FRAME, 1.0)])
	_fill(spark_mm, spk)
	var k := maxf(lamp_k, BreachSpray.DARK)
	spray_mat.set_shader_parameter("water", Color(BreachSpray.WATER.r * k, BreachSpray.WATER.g * k, BreachSpray.WATER.b * k))


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


## Включить или выключить петлю, не перезапуская уже играющую.
static func _play(p: Node, on: bool) -> void:
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()


## Брызги в осях узла пробоины (+Z — внутрь отсека): где струя падает на воду, высота — уровень воды.
static func splash_local(s: Breach.Spot, water_h: float) -> Vector3:
	return BreachSpray.splash_at(s, water_h) - Vector3(0.0, 0.012, 0.0)


## Расставить по состоянию Breach (каждый шаг); dt — сколько прожили частицы (0 — только перерисовать).
func apply(dt: float = 0.0) -> void:
	if dt > 0.0:
		parts.update(dt, breach)
	draw_parts()
	var s := breach.last
	spot_node.visible = s != null
	_play(siren, breach.active != null)
	_play(jet_sound, breach.active != null)
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
		alarm.light_energy = 0.0   # ART-064: аварию ведут огни корабля (CabinLight), узел остаётся
