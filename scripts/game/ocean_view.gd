class_name OceanView
extends Node3D
## Отмель за бортом: дно (один меш с цветом вершин), лёд над головой, свет сквозь лёд, морской снег
## и вода по глубине (туман и рассеянный свет, как updateEnv в js/game.js). Мир неподвижен, движется корабль.

const LAYER_WORLD := 1   ## слой отмели: её освещает свет сквозь лёд
const LAYER_SHIP := 2    ## слой корабля изнутри: только свои лампы

var seabed: MeshInstance3D
var seabed_mat: ShaderMaterial   # материал дна: каустики и свет по глубине задаём отсюда
var ice: MeshInstance3D
## Радиус дальней воды, м: меньше дальности камер (400) и дальше, чем туман оставляет что-то видимым.
const FAR_WALL := 380.0
var far_wall: MeshInstance3D   # дальняя вода: сфера цвета тумана вокруг камеры (issue #456)
var far_mat: ShaderMaterial
var ice_mat: ShaderMaterial   # лёд ART-056: свечение, контраст и нормали по глубине — из apply_water
var ice_relief := true         # «Экономно» — без нормалей льда (set_relief)
var sun: DirectionalLight3D
var snow: CPUParticles3D
var snow_mat: ShaderMaterial   # взвесь ART-058: атлас, доли кадров, вращение
var shafts: MultiMeshInstance3D   # лучи сквозь трещины льда (ART-052)
var shafts_mat: ShaderMaterial
var shaft_list: Array[LightShafts.Shaft] = []
var stones: StonesView   ## камни на дне вокруг корабля (`SeabedStones`, один MultiMesh)
## Слои воды ART-069 (`WaterLayers`) в материалах дна, льда и дальней воды: сила по уровню ART-044 и по илу.
var layers_level := WaterLayers.GAIN_NORMAL
var layers_silt := 0.0
## #847: вода, туман и лёд по глубине пишутся, только когда глубина или ил сдвинулись больше порога —
## иначе ≈20 свойств окружения и ≈25 значений шейдеров уходили каждый кадр, хотя корабль стоит.
const WATER_EPS_DEPTH := 0.005   ## м
const WATER_EPS_SILT := 0.0005
var water_writes := 0                          ## сколько раз вода записана (тесты)
var _water_at := Vector2(INF, INF)             ## глубина и ил последней записи
var _layers_cam := Vector3(INF, INF, INF)      ## камера последней записи придонной пыли
var _ship_at := Transform3D(Basis(), Vector3(INF, INF, INF))   ## корабль последней записи лучей и взвеси


func _ready() -> void:
	stones = StonesView.new()
	add_child(stones)
	seabed = MeshInstance3D.new()
	seabed.name = "Дно"
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Seabed.map_arrays())   # отмель и склон за краем (#822)
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
	m.set_shader_parameter("crack_net", IceSheet.CAUSTIC_NET)
	m.set_shader_parameter("crack_widen", IceSheet.CAUSTIC_WIDEN)
	_set_ground(m)   # грунты ART-060: песок, ил, галька
	_set_decals(m)   # декали ART-066: следы, вмятины, ил, ракушечник, мох
	seabed_mat = m
	mesh.surface_set_material(0, m)
	seabed.mesh = mesh
	seabed.layers = LAYER_WORLD
	# тень не отбрасывает (#842): сетка ≈39 тыс. треуг. в каскадах солнца и тени прожектора, а солнце под −70° —
	# самозатенения дна почти не видно; тени существ, камней и корабля дно по-прежнему принимает
	seabed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seabed)

	# лёд: плоскость на y = 0 лицом вниз; карты, трещины и свечение по ART-056 (IceSheet, shaders/ice.gdshader)
	ice = MeshInstance3D.new()
	ice.name = "Лёд"
	var q := PlaneMesh.new()
	q.size = Vector2(Seabed.SIZE + Seabed.EAST.size.x, Seabed.SIZE)   # и над склоном за восточным краем (#822)
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
	im.set_shader_parameter("reflect_lut", load(IceSheet.REFLECT_LUT))   # окно Снелля и отражение ART-075
	im.set_shader_parameter("smooth_tex", load(IceSheet.SMOOTH_MASK))
	im.set_shader_parameter("crit_cos", IceSheet.CRIT_COS)
	im.set_shader_parameter("open_edge", IceSheet.OPEN_EDGE)
	im.set_shader_parameter("reflect_lite", 0.0)
	ice_mat = im
	ice.material_override = im
	ice.position = Vector3(Seabed.EAST.size.x / 2.0, Seabed.ICE_Y, 0.0)
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
	sun.shadow_caster_mask = LAYER_WORLD   # мостик и отсеки изнутри (слой 2) тень на дно не кладут (отчёт #945)
	add_child(sun)

	far_wall = _make_far_wall()
	add_child(far_wall)
	_init_layers()

	shafts = _make_shafts()
	add_child(shafts)

	snow = _make_snow()
	add_child(snow)
	get_viewport().size_changed.connect(_fit_snow)
	_fit_snow()


## Дальняя вода (issue #456): сфера цвета тумана вокруг камеры закрывает щель между краем льда и дна — фон
## `BG_COLOR` в кадр не попадает. Один вызов, теней нет.
func _make_far_wall() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Дальняя вода"
	var sphere := SphereMesh.new()
	sphere.radius = FAR_WALL
	sphere.height = FAR_WALL * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	mi.mesh = sphere
	far_mat = ShaderMaterial.new()
	far_mat.shader = load("res://shaders/far_water.gdshader")
	mi.material_override = far_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = LAYER_WORLD
	mi.extra_cull_margin = FAR_WALL
	return mi


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var at := cam.global_position
		if not at.is_equal_approx(_layers_cam):   # камера стоит — дальняя вода и пыль на месте (#847)
			far_wall.global_position = at
			set_layers_camera(at)


## Материалы со слоями воды ART-069 (`shaders/water_layers.gdshaderinc`).
func layer_mats() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = [seabed_mat, ice_mat, far_mat]
	out.append_array(extra_layer_mats)
	return out


## Материалы на дне со своим шейдером (арка врат 07 `GateView`): туман — слоями воды ART-069, как у дна. Со штатным
## туманом остаётся только база ART-059 — вдали она темнее воды со слоями вокруг, и предмет проступает силуэтом.
var extra_layer_mats: Array[ShaderMaterial] = []
const LAYER_PARAMS: Array[String] = ["layer_base", "layer_density", "layer_gain", "layer_cam_above", "layer_floor_y",
	"layer_ice_color", "layer_thermo_color", "layer_dust_color"]


## Подключить материал к слоям воды: числа сразу как у дна (вода по глубине пишется только при её смене, #847).
func add_layer_mat(m: ShaderMaterial) -> void:
	if extra_layer_mats.has(m):
		return
	extra_layer_mats.append(m)
	for p in LAYER_PARAMS:
		var v: Variant = seabed_mat.get_shader_parameter(p)
		if v != null:
			m.set_shader_parameter(p, v)


## Цвета слоёв — один раз при сборке.
func _init_layers() -> void:
	for m in layer_mats():
		m.set_shader_parameter("layer_ice_color", _lin(WaterLayers.ICE.color))
		m.set_shader_parameter("layer_thermo_color", _lin(WaterLayers.THERMO.color))
		m.set_shader_parameter("layer_dust_color", _lin(WaterLayers.DUST.color))
	_apply_layers_gain()


## Цвет в линейный vec3 для шейдера слоёв.
static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


## Высота камеры над дном — для придонной пыли (дно под камерой считаем ровным).
func set_layers_camera(cam: Vector3) -> void:
	_layers_cam = cam
	var floor_y := Seabed.mesh_height(cam.x, cam.z)
	for m in layer_mats():
		m.set_shader_parameter("layer_cam_above", maxf(cam.y - floor_y, 0.0))
		m.set_shader_parameter("layer_floor_y", floor_y)


func _apply_layers_gain() -> void:
	var g := WaterLayers.gain(layers_level, layers_silt)
	for m in layer_mats():
		m.set_shader_parameter("layer_gain", g)


## «Экономно» (ART-044): слои воды выключены — в шейдере остаётся только база тумана ART-059.
func set_layers_lite(lite: bool) -> void:
	set_layers_level(WaterLayers.GAIN_LITE if lite else WaterLayers.GAIN_NORMAL)


## Радиус дальней воды по уровню графики ART-044 (`Graphics.LEVELS` "wall"; камера видит чуть дальше).
func set_far(radius: float) -> void:
	far_wall.scale = Vector3.ONE * (radius / FAR_WALL)


## Тени света сквозь лёд по уровню графики ART-044: 0 — выключены, 2 / 4 — каскадов.
func set_shadows(splits: int) -> void:
	sun.shadow_enabled = splits > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if splits >= 4 \
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


## Сила слоёв по уровню графики: 0 / 0,6 / 0,9 (`WaterLayers.GAIN_*`).
func set_layers_level(level: float) -> void:
	layers_level = level
	_apply_layers_gain()


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
	m.shader = SHAFTS_SHADER
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
	stones.follow(pos)   # камни досчитываются и стоя: клетки радиуса — по нескольку за шаг
	var t := Transform3D(Basis(Vector3.UP, yaw), pos)
	if t.is_equal_approx(_ship_at):   # корабль стоит — матрицы в лучах и взвеси те же (#847)
		return
	_ship_at = t
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


## «Экономно» (#852): лучи сквозь лёд без чтения глубины кадра (`light_shafts_lite.gdshader`) — движку не нужна
## копия буфера глубины каждый кадр; край шахты у дна и корпуса резче. Параметры материала остаются.
const SHAFTS_SHADER := preload("res://shaders/light_shafts.gdshader")
const SHAFTS_LITE := preload("res://shaders/light_shafts_lite.gdshader")


func set_shafts_lite(lite: bool) -> void:
	shafts_mat.shader = SHAFTS_LITE if lite else SHAFTS_SHADER


## Вода по глубине: цвет и плотность тумана, рассеянный свет, свет сквозь лёд. around — где корабль.
## silt — корабль в облаке ила 0…1 (Silt.k): вода бурая и мутная.
func apply_water(env: Environment, depth: float, around: Vector3, silt: float = 0.0) -> void:
	snow.position = around
	if absf(depth - _water_at.x) < WATER_EPS_DEPTH and absf(silt - _water_at.y) < WATER_EPS_SILT:
		return   # глубина и ил те же — всё ниже уже записано (#847)
	_water_at = Vector2(depth, silt)
	water_writes += 1
	var fog := Seabed.Water.fog_color(depth).lerp(Silt.FAR_COLOR, 0.75 * silt)   # серо-зелёная муть (ART-048)
	env.background_color = fog
	far_mat.set_shader_parameter("water", fog)   # дальняя вода — того же цвета, туман её доведёт до фона (#456)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = fog
	env.fog_light_energy = 1.0
	# ART-059: конечные значения таблицы `Seabed.Water` — без прежних множителей 0,9 / 0,7 / 1,2
	env.fog_density = Seabed.Water.fog_density(depth) + 0.03 * silt
	shafts_mat.set_shader_parameter("fog_density", env.fog_density)
	for m in layer_mats():   # FOG в шейдере заменяет штатный туман — база ART-059 туда же (ART-069)
		m.set_shader_parameter("layer_base", _lin(fog))
		m.set_shader_parameter("layer_density", env.fog_density)
	layers_silt = silt
	_apply_layers_gain()
	env.fog_sky_affect = 0.0
	env.ambient_light_color = Color(0.55, 0.75, 0.8)
	env.ambient_light_energy = Seabed.Water.ambient(depth)
	env.tonemap_exposure = Seabed.Water.exposure(depth)
	sun.light_energy = Seabed.Water.sun(depth)
	# Каустики на дне гаснут по глубине (меньше света сквозь лёд) и в облаке ила (свет рассеивается).
	seabed_mat.set_shader_parameter("light", clampf(Seabed.Water.caustic(depth) * (1.0 - 0.85 * silt), 0.0, 1.0))
	ice_mat.set_shader_parameter("water", fog)
	ice_mat.set_shader_parameter("glow_k", exp(-maxf(depth, 0.0) / IceSheet.GLOW_DEPTH))
	ice_mat.set_shader_parameter("contrast", IceSheet.contrast(depth))
	ice_mat.set_shader_parameter("relief", IceSheet.relief(depth) if ice_relief else 0.0)
	ice_mat.set_shader_parameter("reflect_row", IceSheet.row(depth))   # ART-075: строка LUT по глубине корабля
	ice_mat.set_shader_parameter("silt_k", silt)                       # ил главнее — отражения нет


## Грунты дна по ART-060 (`Seabed.Ground`): девять карт и числа в материал дна, без новых вызовов.
static func _set_ground(m: ShaderMaterial) -> void:
	const NAMES := ["sand", "silt", "pebble"]
	for kind in 3:
		for map in 3:
			m.set_shader_parameter("%s_%s" % [NAMES[kind], Seabed.Ground.MAPS[map]], load(Seabed.Ground.path(kind, map)))
	m.set_shader_parameter("ground", 1.0)
	m.set_shader_parameter("relief", 1.0)
	m.set_shader_parameter("tile", Seabed.Ground.TILE)
	m.set_shader_parameter("off_silt", Seabed.Ground.OFFSET[1])
	m.set_shader_parameter("off_pebble", Seabed.Ground.OFFSET[2])
	m.set_shader_parameter("normal_k", Vector3(Seabed.Ground.NORMAL_K[0], Seabed.Ground.NORMAL_K[1], Seabed.Ground.NORMAL_K[2]))
	m.set_shader_parameter("normal_fade", Seabed.Ground.NORMAL_FADE)
	m.set_shader_parameter("color_fade", Seabed.Ground.COLOR_FADE)
	m.set_shader_parameter("bump", Seabed.Ground.BUMP)
	m.set_shader_parameter("silt_scale", Seabed.Ground.SILT_SCALE)
	m.set_shader_parameter("silt_edge", Seabed.Ground.SILT_EDGE)
	m.set_shader_parameter("pebble_scale", Seabed.Ground.PEBBLE_SCALE)
	m.set_shader_parameter("pebble_edge", Seabed.Ground.PEBBLE_EDGE)
	m.set_shader_parameter("steep", Seabed.Ground.STEEP)


## «Экономно» (ART-044): лёд без выборки нормалей, цвет и маска трещин остаются; дно — только цвет грунтов.
## Декали дна по ART-066 (`Seabed.Marks`): атлас и числа в материал дна, без новых вызовов.
static func _set_decals(m: ShaderMaterial) -> void:
	const D := Seabed.Marks
	m.set_shader_parameter("decal_atlas", load(D.ATLAS))
	m.set_shader_parameter("decals", 1.0)
	m.set_shader_parameter("decal_cell", D.CELL)
	m.set_shader_parameter("decal_size", D.SIZE)
	m.set_shader_parameter("decal_jitter", D.JITTER)
	m.set_shader_parameter("decal_k", D.STRENGTH)
	m.set_shader_parameter("decal_slope", D.SLOPE)
	m.set_shader_parameter("decal_track_ny", D.TRACK_NY)
	m.set_shader_parameter("decal_moss", D.MOSS_EDGE)
	m.set_shader_parameter("decal_edge", D.EDGE)
	_decals_level(m, false)


static func _decals_level(m: ShaderMaterial, lite: bool) -> void:
	const D := Seabed.Marks
	m.set_shader_parameter("decal_layers", 1.0 if lite else float(D.LAYERS))
	m.set_shader_parameter("decal_accept", D.LITE_ACCEPT if lite else D.ACCEPT)
	m.set_shader_parameter("decal_fade", D.LITE_FADE if lite else D.FADE)


## «Экономно» (ART-044): декали дна реже (один слой, 0,36) и ближе (6…25 м).
func set_decals_lite(lite: bool) -> void:
	_decals_level(seabed_mat, lite)


## «Экономно» (ART-044): камни на дне ближе (`SeabedStones.LITE_RADIUS`).
func set_stones_lite(lite: bool) -> void:
	stones.set_lite(lite)


## Следы разрядов на дне (`Seabed.Scorch.uniforms`): [где, сила] по MAX — в тот же материал дна.
func set_scorch(u: Array) -> void:
	seabed_mat.set_shader_parameter("scorch_at", u[0])
	seabed_mat.set_shader_parameter("scorch_k", u[1])


func set_relief(on: bool) -> void:
	ice_relief = on
	_water_at = Vector2(INF, INF)   # рельеф льда — из apply_water: записать заново на следующем шаге
	ice_mat.set_shader_parameter("reflect_lite", 0.0 if on else 1.0)   # «Экономно» ART-075: без маски, × 0,55
	seabed_mat.set_shader_parameter("relief", 1.0 if on else 0.0)
	if not on:
		ice_mat.set_shader_parameter("relief", 0.0)
