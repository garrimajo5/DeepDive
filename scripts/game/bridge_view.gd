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
var zap_lever: Node3D      ## рычаг разряда на левом борту (MOD-014), pivot на оси Z
var zap_panel: Node3D      ## щиток разряда (MOD-014)
var zap_scale_mat: BaseMaterial3D   ## материал щитка со шкалой готовности (свечение гаснет на откат)
var hatch_wheel: Node3D
var lamps: Array[OmniLight3D] = []  ## огни мостика B1, B2 по ART-064 (set_cabin)
var _lamp_data: Array[CabinLight.Lamp] = []
var plafond_mat: StandardMaterial3D   ## рассеиватели плафонов ART-064 (set_cabin)
const PLAFOND_TEX := preload("res://textures/svet/plafon.png")
const GLINT_MASK := preload("res://textures/bridge/bliki-maska.png")   ## ART-067, L8 512², бесшовная
var screens_mat: ShaderMaterial    ## экраны пульта пилота (помехи — set_screens)
const SCANNER_TEXT := Color("67DDEB")
var scanner_text: Label3D          ## экран сканера биолога (Scanner.screen_lines)


func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Оболочка"
	mesh_instance.mesh = build_mesh(BridgePlan.parts(), KITS)
	mesh_instance.layers = OceanView.LAYER_SHIP
	add_child(mesh_instance)
	plafond_mat = plafond_material(mesh_instance.mesh)
	for m in surface_materials():   # блики воды ART-067: маска в потолке и полу, сила — set_glints
		m.set_shader_parameter("glint_mask", GLINT_MASK)
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
	_add_zap_lever()
	_add_scanner_screen()
	hatch_door = _add_model(BridgeProps.Prop.new(BridgeProps.HATCH_DOOR, "Створка люка", BridgeProps.HATCH_DOOR_OFFSET),
		props[BridgeProps.HATCH_FRAME])
	hatch_wheel = _add_model(BridgeProps.Prop.new(BridgeProps.HATCH_WHEEL, "Колесо люка", BridgeProps.HATCH_WHEEL_OFFSET),
		hatch_door)
	for name in props:
		if TextureGlow.MODELS.has(name):
			light_texture(props[name])
	for l in CabinLight.of(true):   # B1, B2 по ART-064
		var o := cabin_light(l)
		add_child(o)
		lamps.append(o)
		_lamp_data.append(l)


## Огни мостика по ART-064 (CabinLight): breach_room — отсек открытой пробоины (−1 — нет), t — часы ритма,
## k — мигание Vitals.lamp_k поверх огибающей.
func set_cabin(breach_room: int, t: float, k: float) -> void:
	for i in lamps.size():
		lamps[i].light_color = CabinLight.color(_lamp_data[i], breach_room)
		lamps[i].light_energy = CabinLight.energy(_lamp_data[i], breach_room, t, k)
	set_plafond(plafond_mat, breach_room, t, k)


## Блики воды ART-067 (WaterGlints): сила k (0 — маска не читается), оттенок воды, часы течения t, с.
func set_glints(k: float, tint: Color, t: float) -> void:
	for m in surface_materials():
		m.set_shader_parameter("glint_k", k)
		m.set_shader_parameter("glint_tint", tint)
		m.set_shader_parameter("glint_time", t)


## Материалы оболочки с картами ART-054 (шейдер ship_surface): пол, стены, потолок.
func surface_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for i in mesh_instance.mesh.get_surface_count():
		var m := mesh_instance.mesh.surface_get_material(i) as ShaderMaterial
		if m:
			out.append(m)
	return out


## Плафоны мостика × k без аварии (мигание, Vitals.lamp_k).
func set_lamps(k: float) -> void:
	set_cabin(-1, 0.0, k)


## Огонь по таблице ART-064: слой корабля, без теней; позиция — в осях корабля (родитель у корабля в нуле).
static func cabin_light(l: CabinLight.Lamp) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.name = "Свет " + l.id
	o.position = l.pos
	o.light_color = l.color
	o.light_energy = l.energy
	o.omni_range = l.range
	o.omni_attenuation = l.attenuation
	o.shadow_enabled = false
	o.light_cull_mask = OceanView.LAYER_SHIP
	return o


## Ползунок i пульта энергии на долю share 0…1 (паз наклонён: ползунок идёт по лицу пульта).
func set_slider(i: int, share: float) -> void:
	var y := BridgeProps.slider_y(share)
	sliders[i].position = Vector3(BridgeProps.SLIDER_X[i], y, BridgeProps.slider_z(y))


## Створка люка в коридор отъезжает вбок на offset м; колесо крутится, пока створка не тронулась.
func set_hatch(offset: float) -> void:
	hatch_door.position.x = BridgeProps.HATCH_DOOR_OFFSET.x + offset
	hatch_wheel.rotation_degrees.z = -offset / ShipLayout.Door.SLIDE * 540.0


## Рычаг разряда: щиток на борту, ось и рукоять с голубым набалдашником (своей модели нет — простые формы).
## Щиток и рычаг разряда — модели MOD-014 (razryad.md): щиток на стене левого борта, рычаг на своей оси Z.
## Шкала готовности — маска свечения материала щитка: гаснет на откат (энергия свечения 0, без смены шейдера).
func _add_zap_lever() -> void:
	zap_panel = _add_model(BridgeProps.Prop.new("razryad-shchitok", "Щиток разряда", Zap.PANEL_POS), self)
	for mi in zap_panel.find_children("*", "MeshInstance3D", true, false):
		var src := (mi as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		if src and src.emission_enabled:
			zap_scale_mat = src.duplicate() as BaseMaterial3D
			(mi as MeshInstance3D).material_override = zap_scale_mat
	zap_lever = _add_model(BridgeProps.Prop.new("razryad-rychag", "Рычаг разряда", Zap.LEVER_POS), self)
	set_zap_lever(Zap.LEVER_UP, true)


## Рычаг на угол deg (rotation.z: +25° взведён, −25° разряд); ready — шкала готовности горит.
func set_zap_lever(deg: float, ready: bool) -> void:
	zap_lever.rotation_degrees.z = deg
	if zap_scale_mat:
		zap_scale_mat.emission_energy_multiplier = 1.0 if ready else 0.0


## Поворот колеса вслед за штурвалом: turn −1…1 (вправо — по часовой, если смотреть из кресла).
func set_wheel_turn(turn: float) -> void:
	if wheel:
		wheel.rotation_degrees.z = -turn * BridgeProps.WHEEL_TURN_DEG


## Текст на экране сканера: лицом в −X (к мостику), текст вправо — к +Z.
func _add_scanner_screen() -> void:
	scanner_text = Label3D.new()
	scanner_text.name = "Экран сканера"
	scanner_text.layers = OceanView.LAYER_SHIP
	scanner_text.font_size = 34
	scanner_text.outline_size = 0
	scanner_text.pixel_size = 0.0014
	scanner_text.modulate = SCANNER_TEXT
	scanner_text.shaded = false
	scanner_text.double_sided = true   # материал общий с подписями голограммы (issue #159)
	scanner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scanner_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	scanner_text.width = BridgeProps.SCANNER_SCREEN_SIZE.x / scanner_text.pixel_size - 30.0
	scanner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var top := BridgeProps.SCANNER_SCREEN + Vector3(-0.005, BridgeProps.SCANNER_SCREEN_SIZE.y / 2.0 - 0.12, 0.0)
	scanner_text.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), top)
	props[BridgeProps.SCANNER].add_child(scanner_text)


## Строки экрана сканера; меняет текст, только если он другой.
func set_scanner_screen(lines: PackedStringArray) -> void:
	var text := "\n".join(lines)
	if scanner_text.text != text:
		scanner_text.text = text


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


## Экраны пульта светятся ровным голубым (пока на них ничего не рисуем); три экрана — своя яркость у каждого
## (`shaders/console_screens.gdshader`, помехи — `set_screens`).
func _light_screens(n: Node3D) -> void:
	screens_mat = ShaderMaterial.new()
	screens_mat.shader = load("res://shaders/console_screens.gdshader")
	screens_mat.set_shader_parameter("glow", BridgeProps.SCREEN_GLOW)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = screens_mat


## Яркость экранов при помехах (Vitals.screen_k): три экрана пульта пилота слева направо и экран сканера.
func set_screens(helm: Vector3, scanner: float) -> void:
	screens_mat.set_shader_parameter("k", helm)
	scanner_text.modulate = Color(SCANNER_TEXT.r * scanner, SCANNER_TEXT.g * scanner, SCANNER_TEXT.b * scanner)


## Стекло носовых окон по ART-057 (`steklo-okon.md`): один квад на три окна, маска мути/капель/царапин и нормали
## толстого стекла (`textures/bridge/steklo-*.png`, шейдер `window_glass.gdshader`); центр окна почти чистый.
const GLASS_SHADER := preload("res://shaders/window_glass.gdshader")
const GLASS_TINT := Color(0.6, 0.85, 0.9)
var glass_mat: ShaderMaterial


func _add_glass() -> void:
	var g := MeshInstance3D.new()
	g.name = "Стекло окна"
	var q := QuadMesh.new()
	q.size = Vector2(2 * BridgePlan.WINDOW_HALF, BridgePlan.WINDOW_TOP - BridgePlan.WINDOW_BOTTOM)
	g.mesh = q
	glass_mat = glass_material()
	g.material_override = glass_mat
	g.position = Vector3(0, (BridgePlan.WINDOW_TOP + BridgePlan.WINDOW_BOTTOM) / 2.0, BridgePlan.NOSE_INNER - 0.05)
	g.layers = OceanView.LAYER_SHIP
	add_child(g)


static func glass_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLASS_SHADER
	m.set_shader_parameter("tint", GLASS_TINT)
	m.set_shader_parameter("mask", load(KIT_DIR + "steklo-maska.png"))
	m.set_shader_parameter("normal_map", load(KIT_DIR + "steklo-normali.png"))
	m.set_shader_parameter("split", glass_split())
	m.set_shader_parameter("relief", true)
	return m


## Границы окон по u квада (стойки `BridgePlan.MULLIONS`): 0,328947 и 0,671053.
static func glass_split() -> Vector2:
	var w := 2.0 * BridgePlan.WINDOW_HALF
	return Vector2((BridgePlan.MULLIONS[0] + BridgePlan.WINDOW_HALF) / w, (BridgePlan.MULLIONS[1] + BridgePlan.WINDOW_HALF) / w)


## UV квада → UV карты окна (x, y) и знаки нормали (z — по U, w — по V), как в `window_glass.gdshader`:
## левое окно как есть, среднее отражено по U, правое — по V (муть у рамы каждого окна, центр чистый).
static func glass_uv(uv: Vector2) -> Vector4:
	var s := glass_split()
	if uv.x < s.x:
		return Vector4(uv.x / s.x, uv.y, 1, 1)
	if uv.x < s.y:
		return Vector4(1.0 - (uv.x - s.x) / (s.y - s.x), uv.y, -1, 1)
	return Vector4((uv.x - s.y) / (1.0 - s.y), 1.0 - uv.y, 1, -1)


## Материалы мостика ART-054 (`mostik-materialy.md`): какой комплект карт `textures/bridge/<имя>-*.png` на какой
## краске. side — грани не вниз, down — смотрящие вниз (потолок, скос в METAL), aft — грани не вниз дальше по
## кораблю (отсеки, `RoomsView.KITS`); запись — [имя, сила нормалей, шероховатость и металл «Экономно», z от, z до]
## (без z — весь корабль); "skip_up" — грани вверх заливкой. Подложки плафонов (SEAM, грани вбок) остаются заливкой.
const KIT_DIR := "res://textures/bridge/"
const KITS := {
	BridgePlan.Paint.DECK: {"side": ["pol", 0.6, 0.72, 0.4]},
	BridgePlan.Paint.METAL: {"side": ["stena", 0.8, 0.8, 0.15], "down": ["potolok", 0.7, 0.78, 0.2]},
	BridgePlan.Paint.SEAM: {"down": ["potolok", 0.7, 0.78, 0.2]},
}
const SURFACE_SHADER := preload("res://shaders/ship_surface.gdshader")


## Метровые планарные UV грани (1 UV = 1 м) по главной оси нормали: пол и потолок — (x, z), короба потолка
## вдоль корабля; стены — по горизонтали вдоль стены и v вниз (−y), рисунок стоит вертикально.
static func planar_uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z)
	if a.x >= a.z:
		return Vector2(p.z, -p.y)
	return Vector2(p.x, -p.y)


## Материал поверхности с картами ART-054/055 (шейдер ship_surface); null — у краски комплекта нет.
static func kit_material(paint: int, kits: Dictionary = KITS, dir: String = KIT_DIR) -> ShaderMaterial:
	if not kits.has(paint):
		return null
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter("base_color", BridgePlan.COLORS[paint])
	m.set_shader_parameter("base_rough", 0.75)
	m.set_shader_parameter("base_metal", 0.25 if paint == BridgePlan.Paint.METAL else 0.0)
	var kit: Dictionary = kits[paint]
	m.set_shader_parameter("skip_up", kit.get("skip_up", false))
	for side in ["side", "aft", "down"]:
		m.set_shader_parameter(side + "_kit", kit.has(side))
		if not kit.has(side):
			continue
		var k: Array = kit[side]
		m.set_shader_parameter(side + "_albedo", load(dir + k[0] + "-tsvet.png"))
		m.set_shader_parameter(side + "_normal", load(dir + k[0] + "-normali.png"))
		m.set_shader_parameter(side + "_orm", load(dir + k[0] + "-orm.png"))
		m.set_shader_parameter(side + "_depth", k[1])
		m.set_shader_parameter(side + "_rough", k[2])
		m.set_shader_parameter(side + "_metal", k[3])
		m.set_shader_parameter(side + "_z", Vector2(k[4], k[5]) if k.size() >= 6 else Vector2(-1e6, 1e6))
	m.set_shader_parameter("relief", true)
	return m


## «Экономно» (ART-044): false — карты нормалей и ORM не читаются, цвет остаётся (ключ снимка relief=0); стекло окон — без нормалей.
func set_relief(on: bool) -> void:
	glass_mat.set_shader_parameter("relief", on)
	for i in mesh_instance.mesh.get_surface_count():
		var m := mesh_instance.mesh.surface_get_material(i) as ShaderMaterial
		if m:
			m.set_shader_parameter("relief", on)


## kits — комплекты карт по краскам (KITS мостика, RoomsView.KITS отсеков) из папки dir; пусто — заливка.
static func build_mesh(parts: Array[BridgePlan.Part] = BridgePlan.parts(), kits: Dictionary = {}, dir: String = KIT_DIR) -> ArrayMesh:
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
		var km := kit_material(paint, kits, dir) if not kits.is_empty() else null
		mesh.surface_set_material(mesh.get_surface_count() - 1, km if km else material(paint))
	return mesh


static func material(paint: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = BridgePlan.COLORS[paint]
	m.roughness = 0.75
	m.metallic = 0.25 if paint == BridgePlan.Paint.METAL else 0.0
	if paint == BridgePlan.Paint.PLAFOND:   # рассеиватель ART-064: текстура (цвет × альфа) — и цвет, и свечение
		m.albedo_color = Color.WHITE
		m.albedo_texture = PLAFOND_TEX
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_texture = PLAFOND_TEX
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # оттенок × рисунок (шейдер — как у экипажа)
		m.emission_energy_multiplier = CabinLight.PLAFOND_E
	return m


## Сколько раз рисунок плафона ложится на грань lu × lv м: модуль 0,4 м, не меньше одного (панель мостика 0,4 × 0,28 —
## один рисунок, полоса отсека 0,15 × 5,4 — 14 по длине).
static func plafond_tiles(lu: float, lv: float) -> Vector2:
	return Vector2(maxf(1.0, roundf(lu / CabinLight.PLAFOND_MODULE)), maxf(1.0, roundf(lv / CabinLight.PLAFOND_MODULE)))


## Материал плафонов в меше (краска PLAFOND), null — плафонов нет.
static func plafond_material(mesh: Mesh) -> StandardMaterial3D:
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m is StandardMaterial3D and (m as StandardMaterial3D).emission_texture == PLAFOND_TEX:
			return m as StandardMaterial3D
	return null


## Плафоны светятся по огням ART-064: обычный — белый × 0,75, авария — янтарь 0,22 + 0,48·p; × lamp_k.
static func set_plafond(m: StandardMaterial3D, breach_room: int, t: float, k: float) -> void:
	if m == null:
		return
	m.emission = CabinLight.plafond_tint(breach_room)
	m.emission_energy_multiplier = CabinLight.plafond_energy(breach_room, t, k)


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
		var tiles := plafond_tiles(du.length() * 2.0, dv.length() * 2.0)
		var quv := [Vector2(0, 0), Vector2(0, tiles.y), tiles, Vector2(tiles.x, 0)]
		# порядок a, b, c такой, что (b − a) × (c − a) смотрит внутрь — лицевая сторона наружу
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nn)
			var pv: Vector3 = t * q[i]
			# плафон ART-064: рисунок по грани — панель мостика целиком, полоса отсека — модулем 0,4 м
			st.set_uv(quv[i] if part.paint == BridgePlan.Paint.PLAFOND else planar_uv(pv, nn))
			st.add_vertex(pv)
