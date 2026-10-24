class_name HullView
extends Node3D
## «Ковчег-7» снаружи (HullPlan по ART-001, меши — HullMesh): неподвижные детали одним мешем, по поверхности на краску;
## роторы и рули глубины — свои узлы, их ставит apply() по HullMesh.Motion. Окна, линза прожектора светятся сами.
## Слой отмели (1): корпус освещают лёд и прожектор. Изнутри корпус не виден — лицевые стороны смотрят наружу.

var body: MeshInstance3D
var rotors: Array[MeshInstance3D] = []
var rudders: Array[MeshInstance3D] = []
var _rotor_parts: Array = []
var _rudder_parts: Array = []
var _mats := {}
var zap_cards: MeshInstance3D   ## дуги у окна и у дна ART-068 (Zap.card_strips), видны только в разряде
var _cards_lite := false
var _cards_contact := Vector3.INF
var _rim_lite := false   ## «Экономно» ART-044: ободок ART-076 слабее, без примыканий


func _ready() -> void:
	body = MeshInstance3D.new()
	body.name = "Корпус снаружи"
	var mesh := ArrayMesh.new()
	for paint in HullMesh.paints():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, HullMesh.paint_builder(paint).arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, body_material(paint))
	body.mesh = mesh
	_setup(body)
	add_child(body)
	_make_zap_cards()
	for part in HullPlan.parts():
		if not HullMesh.drawn(part) or not HullMesh.moving(part):
			continue
		var mi := MeshInstance3D.new()
		mi.name = part.name
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, HullMesh.part_builder(part).arrays())
		m.surface_set_material(0, material(part.paint))
		mi.mesh = m
		mi.position = part.pos
		_setup(mi)
		add_child(mi)
		if part.piece == HullPlan.Piece.ROTOR:
			rotors.append(mi)
			_rotor_parts.append(part)
		else:
			rudders.append(mi)
			_rudder_parts.append(part)


func _make_zap_cards() -> void:
	zap_cards = MeshInstance3D.new()
	zap_cards.name = "Дуги у окна и дна"
	zap_cards.mesh = ArrayMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/zap_cards.gdshader")
	m.set_shader_parameter("arc_tex", load(Zap.ARC_TEX))
	m.set_shader_parameter("zap_dur", Zap.FLICKER)
	m.set_shader_parameter("zap_fps", Zap.ARC_FPS)
	m.set_shader_parameter("zap_flow", Zap.ARC_FLOW)
	m.set_shader_parameter("window_gone", Zap.WINDOW_GONE)
	m.set_shader_parameter("core_color", Zap.ARC_CORE_COLOR)
	m.set_shader_parameter("halo_color", Zap.ARC_HALO_COLOR)
	m.set_shader_parameter("core", Zap.ARC_CORE)
	zap_cards.material_override = m
	_cards_mesh(Vector3.INF)
	_setup(zap_cards)
	zap_cards.extra_cull_margin = 4.0   # дуга у окна сдвигается в шейдере
	zap_cards.visible = false
	add_child(zap_cards)


func _cards_mesh(contact: Vector3) -> void:
	_cards_contact = contact
	var mesh: ArrayMesh = zap_cards.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Zap.card_arrays(Zap.card_strips(contact)))


func _setup(mi: MeshInstance3D) -> void:
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Металл неподвижного корпуса — обшивка ART-024 (шейдер `hull_plating`): плитка в осях корабля, обрастание по высоте,
## следы ART-049 и рельеф ART-053.
## Роторы и рули (свои оси, без обрастания) и прочие краски — однотонные.
static func plating() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/hull_plating.gdshader")
	m.set_shader_parameter("color_tex", load(HullMesh.PLATE_TEX % "tsvet"))
	m.set_shader_parameter("mask_tex", load(HullMesh.PLATE_TEX % "maska"))
	m.set_shader_parameter("growth_tex", load(HullMesh.PLATE_TEX % "obrastanie"))
	m.set_shader_parameter("tile", HullMesh.PLATE_TILE)
	m.set_shader_parameter("seam_dark", HullMesh.SEAM_DARK)
	m.set_shader_parameter("stain_dark", HullMesh.STAIN_DARK)
	m.set_shader_parameter("keel_y", HullMesh.KEEL_Y)
	m.set_shader_parameter("hull_h", HullMesh.HULL_H)
	m.set_shader_parameter("growth_max", HullMesh.GROWTH_MAX)
	m.set_shader_parameter("growth_from", HullMesh.GROWTH_FROM)
	m.set_shader_parameter("growth_to", HullMesh.GROWTH_TO)
	m.set_shader_parameter("damage_tex", load(HullMesh.DAMAGE_TEX % "povrezhdeniya"))
	m.set_shader_parameter("damage_lvl", load(HullMesh.DAMAGE_TEX % "povrezhdeniya-uroven"))
	m.set_shader_parameter("damage_seam", HullMesh.DAMAGE_SEAM)
	m.set_shader_parameter("alt_scale", HullMesh.DAMAGE_ALT_SCALE)
	m.set_shader_parameter("alt_shift", HullMesh.DAMAGE_ALT_SHIFT)
	m.set_shader_parameter("gate_cell", HullMesh.DAMAGE_CELL)
	m.set_shader_parameter("gate_edge", HullMesh.DAMAGE_GATE)
	m.set_shader_parameter("normal_tex", load(HullMesh.PLATE_TEX % "normali"))
	m.set_shader_parameter("rough_tex", load(HullMesh.PLATE_TEX % "sheroh"))
	m.set_shader_parameter("damage_nrm", load(HullMesh.DAMAGE_TEX % "povrezhdeniya-normali"))
	m.set_shader_parameter("normal_depth", HullMesh.NORMAL_DEPTH)
	m.set_shader_parameter("damage_depth", HullMesh.DAMAGE_DEPTH)
	m.set_shader_parameter("relief", true)
	m.set_shader_parameter("wear", 0.0)
	m.set_shader_parameter("arc_tex", load(Zap.ARC_TEX))   # разряд ART-068
	m.set_shader_parameter("zap_t", -1.0)
	m.set_shader_parameter("zap_dur", Zap.FLICKER)
	m.set_shader_parameter("zap_from", Zap.ARC_FROM)
	m.set_shader_parameter("zap_speed", Zap.ARC_SPEED)
	m.set_shader_parameter("zap_width", Zap.ARC_WIDTH)
	m.set_shader_parameter("zap_fps", Zap.ARC_FPS)
	m.set_shader_parameter("zap_tile", Zap.ARC_TILE)
	m.set_shader_parameter("zap_flow", Zap.ARC_FLOW)
	m.set_shader_parameter("zap_core_color", Zap.ARC_CORE_COLOR)
	m.set_shader_parameter("zap_halo_color", Zap.ARC_HALO_COLOR)
	m.set_shader_parameter("zap_core", Zap.ARC_CORE)
	m.set_shader_parameter("zap_seam", Zap.ARC_SEAM)
	m.set_shader_parameter("rim_tex", load(HullMesh.RIM_TEX))   # ободок и щели ART-076
	m.set_shader_parameter("rim_row", 0.0)
	m.set_shader_parameter("rim_k", 1.0)
	m.set_shader_parameter("rim_contact", HullMesh.RIM_CONTACT)
	m.set_shader_parameter("rim_zap", HullMesh.RIM_ZAP)
	m.set_shader_parameter("ao_contacts", true)
	m.set_shader_parameter("ao_seam", HullMesh.AO_SEAM)
	m.set_shader_parameter("ao_contact", HullMesh.AO_CONTACT)
	m.set_shader_parameter("ao_min", HullMesh.AO_MIN)
	m.set_shader_parameter("ao_albedo", HullMesh.AO_ALBEDO)
	m.set_shader_parameter("ao_light", HullMesh.AO_LIGHT)
	m.set_shader_parameter("ao_protect", HullMesh.AO_PROTECT)
	m.set_shader_parameter("ao_mount", HullMesh.AO_MOUNT)
	m.set_shader_parameter("ao_mount_half", HullMesh.AO_MOUNT_HALF)
	m.set_shader_parameter("ao_mount_feather", HullMesh.AO_MOUNT_FEATHER)
	m.set_shader_parameter("ao_recess", HullMesh.AO_RECESS)
	m.set_shader_parameter("ao_recess_r", HullMesh.AO_RECESS_R)
	m.set_shader_parameter("ao_recess_z", HullMesh.AO_RECESS_Z)
	m.set_shader_parameter("ao_rudder", HullMesh.AO_RUDDER)
	m.set_shader_parameter("ao_rudder_r", HullMesh.AO_RUDDER_R)
	m.set_shader_parameter("ao_stab_up", HullMesh.AO_STAB_UP)
	m.set_shader_parameter("ao_stab_up_r", HullMesh.AO_STAB_UP_R)
	m.set_shader_parameter("ao_stab_down", HullMesh.AO_STAB_DOWN)
	m.set_shader_parameter("ao_stab_down_r", HullMesh.AO_STAB_DOWN_R)
	return m


## Рельеф обшивки ART-053 (нормали и шероховатость из карт). Выкл — «Экономно» (ART-044): без выборок рельефа,
## шероховатость прежними константами, цвет и следы остаются.
func set_relief(on: bool) -> void:
	var m: ShaderMaterial = _mats.get(-1)
	if m != null:
		m.set_shader_parameter("relief", on)
		m.set_shader_parameter("zap_lite", not on)   # «Экономно»: дуги одним кадром
		m.set_shader_parameter("ao_contacts", on)    # и щели ART-076 только по шву
	_rim_lite = not on   # и ободок ART-076 слабее
	_cards_lite = not on   # и без карточек у окна и дна


## Разряд ART-068 по обшивке: t — время с начала разряда (Zap.arc_time), −1 — нет.
func set_zap(t: float) -> void:
	var m: ShaderMaterial = _mats.get(-1)
	if m == null:
		return
	if not is_equal_approx(float(m.get_shader_parameter("zap_t")), t):
		m.set_shader_parameter("zap_t", t)


## Карточки разряда ART-068 у окна и у дна: t — Zap.arc_time (−1 — нет), contact — Zap.ground_contact (INF — дно
## далеко, только дуга у окна). Вне разряда и на «Экономно» скрыты (+1 вызов только во время разряда).
func set_zap_cards(t: float, contact: Vector3) -> void:
	if zap_cards == null:
		return
	var on := t >= 0.0 and t < Zap.FLICKER and not _cards_lite
	zap_cards.visible = on
	if not on:
		return
	if contact != _cards_contact:
		_cards_mesh(contact)
	(zap_cards.material_override as ShaderMaterial).set_shader_parameter("zap_t", t)


## Ободок и затенение щелей ART-076: строка LUT по глубине корабля (м), ил `Silt.k` гасит кромку, alive —
## `HullMesh.rim_alive(wreck.t)` (шторка «Корпус разрушен»). Две uniform на материал обшивки, без новых вызовов.
func set_rim(depth: float, silt_k: float, alive: float) -> void:
	var m: ShaderMaterial = _mats.get(-1)
	if m == null:
		return
	var row := HullMesh.rim_row(depth)
	var k := HullMesh.rim_k(alive, silt_k, _rim_lite)
	if not is_equal_approx(float(m.get_shader_parameter("rim_row")), row):
		m.set_shader_parameter("rim_row", row)
	if not is_equal_approx(float(m.get_shader_parameter("rim_k")), k):
		m.set_shader_parameter("rim_k", k)


## Следы повреждений ART-049 по прочности корпуса (`Vitals.hull`, %): одна uniform на материал обшивки.
func set_hull(hull_pct: float) -> void:
	var m: ShaderMaterial = _mats.get(-1)
	if m == null:
		return
	var w := HullMesh.wear(hull_pct)
	if not is_equal_approx(float(m.get_shader_parameter("wear")), w):
		m.set_shader_parameter("wear", w)


func body_material(paint: int) -> Material:
	if HullMesh.plated(paint):
		if not _mats.has(-1):
			_mats[-1] = plating()
		return _mats[-1]
	return material(paint)


func material(paint: int) -> StandardMaterial3D:
	if _mats.has(paint):
		return _mats[paint]
	var c: Color = HullPlan.COLORS[paint]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75 if paint == HullPlan.Paint.METAL else 0.6
	m.metallic = 0.3 if paint == HullPlan.Paint.METAL or paint == HullPlan.Paint.SEAM else 0.0
	if HullPlan.glows(paint):
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = HullMesh.glow(paint)
	_mats[paint] = m
	return m


## Роторы крутятся вокруг своей оси (вдоль корабля), рули глубины — вокруг поперечной оси: при всплытии
## задняя кромка поднята.
func apply(motion: HullMesh.Motion) -> void:
	for i in rotors.size():
		var part: HullPlan.Part = _rotor_parts[i]
		var axis := part.rotate(Vector3.UP).normalized()
		rotors[i].basis = Basis(axis, deg_to_rad(motion.rotor_angle_of(signf(part.pos.x))))
	for r in rudders:
		r.basis = Basis(Vector3.RIGHT, -deg_to_rad(motion.pitch))
