class_name OceanView
extends Node3D
## Отмель за бортом: дно (один меш с цветом вершин), лёд над головой, свет сквозь лёд, морской снег
## и вода по глубине (туман и рассеянный свет, как updateEnv в js/game.js). Мир неподвижен, движется корабль.

const LAYER_WORLD := 1   ## слой отмели: её освещает свет сквозь лёд
const LAYER_SHIP := 2    ## слой корабля изнутри: только свои лампы

var seabed: MeshInstance3D
var seabed_mat: ShaderMaterial   # материал дна: каустики и свет по глубине задаём отсюда
var ice: MeshInstance3D
var ice_mat: ShaderMaterial   # лёд ART-056: свечение, контраст и нормали по глубине — из apply_water
var ice_relief := true         # «Экономно» — без нормалей льда (set_relief)
var sun: DirectionalLight3D
var snow: CPUParticles3D
var snow_mat: ShaderMaterial   # взвесь ART-058: атлас, доли кадров, вращение
var shafts: MultiMeshInstance3D   # лучи сквозь трещины льда (ART-052)
var shafts_mat: ShaderMaterial
var shaft_list: Array[LightShafts.Shaft] = []


func _ready() -> void:
	seabed = MeshInstance3D.new()
	seabed.name = "Дно"
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Seabed.build_arrays())
	var m := ShaderMaterial.new()   # цвет вершин + процедурная детализация дна (shaders/seabed.gdshader)
	m.shader = load("res://shaders/seabed.gdshader")
	m.set_shader_parameter("caustic", 0.6)   # каустики включены; уровень «Экономно» выключит (ART-044)
	m.set_shader_parameter("crack_tex", load(IceSheet.CRACK_MASK))   # каустики под трещинами льда (ART-056)
	m.set_shader_parameter("ice_tile", IceSheet.TILE)
	m.set_shader_parameter("ice_y", Seabed.ICE_Y)
	m.set_shader_parameter("gate_scale", IceSheet.GATE_SCALE)
	m.set_shader_parameter("gate_edge", IceSheet.GATE_EDGE)
	m.set_shader_parameter("crack_caustic", IceSheet.CAUSTIC)
	m.set_shader_parameter("crack_depth", IceSheet.CAUSTIC_DEPTH)
	seabed_mat = m
	mesh.surface_set_material(0, m)
	seabed.mesh = mesh
	seabed.layers = LAYER_WORLD
	add_child(seabed)

	# лёд: плоскость на y = 0 лицом вниз; карты, трещины и свечение по ART-056 (IceSheet, shaders/ice.gdshader)
	ice = MeshInstance3D.new()
	ice.name = "Лёд"
	var q := PlaneMesh.new()
	q.size = Vector2(Seabed.SIZE, Seabed.SIZE)
	q.flip_faces = true
	ice.mesh = q
	var im := ShaderMaterial.new()
	im.shader = load("res://shaders/ice.gdshader")
	im.set_shader_parameter("color_tex", load("res://textures/ice/tsvet.png"))
	im.set_shader_parameter("normal_tex", load("res://textures/ice/normali.png"))
	im.set_shader_parameter("crack_tex", load("res://textures/ice/treshchiny.png"))
	im.set_shader_parameter("glow_color", IceSheet.GLOW_COLOR)
	im.set_shader_parameter("tile", IceSheet.TILE)
	im.set_shader_parameter("glow_base", IceSheet.GLOW_BASE)
	im.set_shader_parameter("glow_crack", IceSheet.GLOW_CRACK)
	im.set_shader_parameter("roughness", IceSheet.ROUGHNESS)
	im.set_shader_parameter("gate_scale", IceSheet.GATE_SCALE)
	im.set_shader_parameter("gate_edge", IceSheet.GATE_EDGE)
	ice_mat = im
	ice.material_override = im
	ice.position.y = Seabed.ICE_Y
	ice.layers = LAYER_WORLD
	add_child(ice)

	sun = DirectionalLight3D.new()
	sun.name = "Свет сквозь лёд"
	sun.rotation_degrees = Vector3(-70, 20, 0)
	sun.light_color = Color("9AD9E8")
	sun.light_cull_mask = LAYER_WORLD
	# Тени на отмели (Forward Mobile): существа и флора ложатся тенью на дно — глубина и вес.
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS   # 2 каскада — дешевле для телефона
	sun.directional_shadow_max_distance = 110.0   # за туманом тени не нужны
	sun.light_angular_distance = 1.5              # мягкие края — рассеянный свет сквозь лёд
	sun.shadow_blur = 1.3
	add_child(sun)

	shafts = _make_shafts()
	add_child(shafts)

	snow = _make_snow()
	add_child(snow)
	get_viewport().size_changed.connect(_fit_snow)
	_fit_snow()


## Высота кадра для взвеси: мельче 1,6 px карточка не становится — бледнеет (`marine_snow.gdshader`).
func _fit_snow() -> void:
	snow_mat.set_shader_parameter("screen_h", float(get_viewport().get_visible_rect().size.y))


## Лучи сквозь трещины льда (ART-052): все шахты отмели одним MultiMesh — один вызов отрисовки.
## Дальние шейдер сжимает в точку; рисуются раньше прочего прозрачного (снег — поверх).
func _make_shafts() -> MultiMeshInstance3D:
	shaft_list = LightShafts.layout()
	var cone := ArrayMesh.new()
	cone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, LightShafts.cone_arrays())
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/light_shafts.gdshader")
	m.set_shader_parameter("mask_tex", load("res://textures/luchi/maska.png"))
	m.set_shader_parameter("noise_tex", load("res://textures/luchi/shum.png"))
	m.set_shader_parameter("ice_y", Seabed.ICE_Y)
	m.set_shader_parameter("depth_scale", LightShafts.DEPTH_SCALE)
	m.set_shader_parameter("gain", LightShafts.GAIN)
	m.set_shader_parameter("far_fade", LightShafts.FAR)
	m.set_shader_parameter("near_fade", LightShafts.NEAR)
	m.set_shader_parameter("floor_fade", LightShafts.FLOOR_FADE)
	m.set_shader_parameter("ship_center_y", HullPlan.CENTER_Y)
	m.set_shader_parameter("ship_shape", LightShafts.SHIP)
	m.set_shader_parameter("ship_inv", Projection(Transform3D.IDENTITY))
	m.render_priority = -1
	shafts_mat = m
	cone.surface_set_material(0, m)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = cone
	mm.instance_count = shaft_list.size()
	for i in shaft_list.size():
		var s := shaft_list[i]
		mm.set_instance_transform(i, LightShafts.instance_xform(s))
		mm.set_instance_custom_data(i, LightShafts.instance_custom(s))
		mm.set_instance_color(i, LightShafts.instance_color(s))
	var node := MultiMeshInstance3D.new()
	node.name = "Лучи сквозь лёд"
	node.multimesh = mm
	node.layers = LAYER_WORLD
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# размеры конусов задаёт шейдер — границы на всю отмель, иначе отсечение по кадру спрячет шахты
	node.custom_aabb = AABB(Vector3(-Seabed.SIZE / 2.0, -80.0, -Seabed.SIZE / 2.0), Vector3(Seabed.SIZE, 81.0, Seabed.SIZE))
	return node


## Где корабль: внутри корпуса шахты не светят и взвеси нет (вид с мостика и из отсеков).
func set_ship(pos: Vector3, yaw: float) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), pos)
	shafts_mat.set_shader_parameter("ship_inv", Projection(t.affine_inverse()))
	snow_mat.set_shader_parameter("ship_inv", Projection(t.affine_inverse()))


## Морской снег — взвесь по ART-058 (`MarineSnow`): хлопья, нити, пыль и пузыри из атласа 4×4 одним узлом и материалом.
## Частицы в мировых координатах, поэтому при ходе корабль проплывает сквозь них — так видно движение. Движение,
## размер и кадр считает шейдер из случайного смещения анимации; сам CPUParticles3D только рождает в объёме.
func _make_snow() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Морской снег"
	p.amount = MarineSnow.AMOUNT
	p.lifetime = MarineSnow.LIFETIME
	p.preprocess = MarineSnow.LIFETIME
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = MarineSnow.EXTENTS
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.anim_offset_min = 0.0   # случайное r 0…1 → INSTANCE_CUSTOM.z: кадр, размер, скорость (шейдер)
	p.anim_offset_max = 1.0
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/marine_snow.gdshader")
	m.set_shader_parameter("atlas", load(MarineSnow.ATLAS))
	m.set_shader_parameter("tint", MarineSnow.COLOR)
	m.set_shader_parameter("cdf", MarineSnow.cdf())
	m.set_shader_parameter("lifetime", MarineSnow.LIFETIME)
	m.set_shader_parameter("near_fade", MarineSnow.NEAR)
	m.set_shader_parameter("ship_center_y", HullPlan.CENTER_Y)
	m.set_shader_parameter("ship_shape", LightShafts.SHIP)
	m.set_shader_parameter("ship_inv", Projection(Transform3D.IDENTITY))
	snow_mat = m
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1, 1)   # размер карточки задаёт шейдер по семье
	mesh.material = m
	p.mesh = mesh
	p.layers = LAYER_WORLD
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# карточки двигает шейдер (до 4 м за жизнь) — границы с запасом, иначе отсечение по кадру спрячет края
	p.visibility_aabb = AABB(-MarineSnow.EXTENTS - Vector3.ONE * 5.0, (MarineSnow.EXTENTS + Vector3.ONE * 5.0) * 2.0)
	return p


## «Экономно» (ART-044): взвесь реже (180) и без вращения.
func set_snow_lite(lite: bool) -> void:
	snow.amount = MarineSnow.amount(lite)
	snow_mat.set_shader_parameter("spin_k", 0.0 if lite else 1.0)


## Вода по глубине: цвет и плотность тумана, рассеянный свет, свет сквозь лёд. around — где корабль.
## silt — корабль в облаке ила 0…1 (Silt.k): вода бурая и мутная.
func apply_water(env: Environment, depth: float, around: Vector3, silt: float = 0.0) -> void:
	var fog := Seabed.Water.fog_color(depth).lerp(Silt.FAR_COLOR, 0.75 * silt)   # серо-зелёная муть (ART-048)
	env.background_color = fog
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = fog
	env.fog_light_energy = 1.0
	# ART-059: конечные значения таблицы `Seabed.Water` — без прежних множителей 0,9 / 0,7 / 1,2
	env.fog_density = Seabed.Water.fog_density(depth) + 0.03 * silt
	shafts_mat.set_shader_parameter("fog_density", env.fog_density)
	env.fog_sky_affect = 0.0
	env.ambient_light_color = Color(0.55, 0.75, 0.8)
	env.ambient_light_energy = Seabed.Water.ambient(depth)
	env.tonemap_exposure = Seabed.Water.exposure(depth)
	sun.light_energy = Seabed.Water.sun(depth)
	# Каустики на дне гаснут по глубине (меньше света сквозь лёд) и в облаке ила (свет рассеивается).
	seabed_mat.set_shader_parameter("light", clampf(Seabed.Water.caustic(depth) * (1.0 - 0.85 * silt), 0.0, 1.0))
	snow.position = around
	ice_mat.set_shader_parameter("water", fog)
	ice_mat.set_shader_parameter("glow_k", exp(-maxf(depth, 0.0) / IceSheet.GLOW_DEPTH))
	ice_mat.set_shader_parameter("contrast", IceSheet.contrast(depth))
	ice_mat.set_shader_parameter("relief", IceSheet.relief(depth) if ice_relief else 0.0)


## «Экономно» (ART-044): лёд без выборки нормалей, цвет и маска трещин остаются.
func set_relief(on: bool) -> void:
	ice_relief = on
	if not on:
		ice_mat.set_shader_parameter("relief", 0.0)
