class_name SonarView
extends MeshInstance3D
## Голограмма сонара над голостолом: круг Ø 2,04 м на столе (шейдер shaders/sonar_holo.gdshader),
## карта рельефа — Sonar.bathymetry() один раз при запуске. У поста «Маршрут» сонар сменяет карта брифинга
## (Briefing, ART-016): места с номерами (Label3D над столом) и линии маршрутов — show_briefing.

const TOP_Y := 0.93   ## над краем корпуса голостола (0,9 м)

var mat: ShaderMaterial
var numbers: Array[Label3D] = []   ## номера мест брифинга, порядок — Briefing.ORDER
var icons: Array[Sprite3D] = []    ## иконки мест брифинга (textures/places), порядок — Briefing.ORDER
static var _map: ImageTexture


func _ready() -> void:
	name = "Голограмма сонара"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.04, 2.04)
	mesh = pm
	position = Vector3(0, TOP_Y, BridgeProps.TABLE_Z)
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/sonar_holo.gdshader")
	if _map == null:   # карта одна на все запуски сцены: считать её ~1 с
		_map = ImageTexture.create_from_image(Sonar.bathymetry())
	mat.set_shader_parameter("map_tex", _map)
	mat.set_shader_parameter("map_size", Sonar.MAP_SIZE)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = OceanView.LAYER_SHIP
	var segs := Briefing.segments()
	var a := PackedVector4Array()
	var info := PackedVector2Array()
	for g in segs:
		a.append(Vector4(g["a"].x, g["a"].y, g["b"].x, g["b"].y))
		info.append(Vector2(g["route"], g["start"]))
	a.resize(Briefing.MAX_SEGS)
	info.resize(Briefing.MAX_SEGS)
	mat.set_shader_parameter("segs", a)
	mat.set_shader_parameter("seg_info", info)
	mat.set_shader_parameter("seg_count", segs.size())
	mat.set_shader_parameter("brief_scale", Briefing.SCALE)
	mat.set_shader_parameter("brief_side", Briefing.SIDE)
	var pts := PackedVector2Array()
	for k in Briefing.ORDER:
		var t := Briefing.table_xz(Run.place_xz(k))
		pts.append(t)
		var l := Label3D.new()
		l.name = "Место %d" % Briefing.NUMBERS[k]
		l.text = str(Briefing.NUMBERS[k])
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.shaded = false
		l.double_sided = true
		l.font_size = 48
		l.outline_size = 10
		l.pixel_size = 0.0016
		l.modulate = Color("#D5E4E8")
		l.outline_modulate = Color("#0B1C24")
		l.position = Vector3(t.x, Briefing.ICON_SIZE * 1.12, t.y)
		l.layers = OceanView.LAYER_SHIP
		l.visible = false
		add_child(l)
		numbers.append(l)
		var ic := Sprite3D.new()
		ic.name = "Иконка %d" % Briefing.NUMBERS[k]
		ic.texture = load(Briefing.icon_path(k))
		ic.pixel_size = Briefing.ICON_SIZE / float(ic.texture.get_height())
		ic.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		ic.shaded = false
		ic.double_sided = true
		ic.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		ic.centered = true
		ic.position = Vector3(t.x, Briefing.ICON_SIZE * 0.5 + 0.004, t.y)
		ic.layers = OceanView.LAYER_SHIP
		ic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ic.visible = false
		add_child(ic)
		icons.append(ic)
	mat.set_shader_parameter("places", pts)


## Каждый кадр: где корабль, сколько прошло с импульса, отметки.
## noise — помехи 0…1 (сонарная тьма, Silt.noise).
func show_state(s: Sonar, ship_pos: Vector3, yaw: float, t: float, powered: bool, noise: float = 0.0) -> void:
	mat.set_shader_parameter("noise", noise)
	mat.set_shader_parameter("time", t)
	mat.set_shader_parameter("ship_xz", Vector2(ship_pos.x, ship_pos.z))
	mat.set_shader_parameter("ship_yaw", yaw)
	mat.set_shader_parameter("range_m", s.range_m)
	mat.set_shader_parameter("ping_age", t - s.ping_time)
	mat.set_shader_parameter("brightness", 1.0 if powered else 0.25)
	var a := s.blip_alpha(t)
	var data := PackedVector4Array()
	var cols := PackedVector3Array()
	for b in s.blips:
		var p: Vector3 = b["pos"]
		var c: Color = b["color"]
		data.append(Vector4(p.x, p.z, 0.035, a))
		cols.append(Vector3(c.r, c.g, c.b))
	data.resize(Sonar.MAX_BLIPS)
	cols.resize(Sonar.MAX_BLIPS)
	mat.set_shader_parameter("blip_count", s.blips.size())
	mat.set_shader_parameter("blips", data)
	mat.set_shader_parameter("blip_cols", cols)


## Точка маршрута (Run.waypoint): кольцо на карте, за краем дальности — на краю круга в её сторону.
## Vector2.INF — точки нет.
func show_waypoint(xz: Vector2) -> void:
	var on := xz.is_finite()
	mat.set_shader_parameter("wp_on", 1.0 if on else 0.0)
	if on:
		mat.set_shader_parameter("wp_xz", xz)


## Брифинг: k — доля перехода 0…1 (Briefing.Fade), маршрут и пройденные точки — из Run, корабль — где он сейчас.
func show_briefing(k: float, run: Run, ship_pos: Vector3) -> void:
	mat.set_shader_parameter("brief_k", k)
	var st := place_states(run)
	for i in numbers.size():
		numbers[i].visible = k > 0.0
		numbers[i].modulate.a = k
		numbers[i].outline_modulate.a = k
		icons[i].visible = k > 0.0
		icons[i].modulate = Color(1, 1, 1, k * Briefing.icon_alpha(st[i]))
	if k <= 0.0:
		return
	mat.set_shader_parameter("sel_route", run.route)
	mat.set_shader_parameter("route_len", maxf(Briefing.route_length(run.route), 0.01) if run.route >= 0 else 1.0)
	mat.set_shader_parameter("ship_t", Briefing.table_xz(Vector2(ship_pos.x, ship_pos.z)))
	mat.set_shader_parameter("place_state", st)


## Состояние мест для шейдера, порядок — Briefing.ORDER: 0 — не на маршруте, 1 — на маршруте, 2 — пройдено,
## 3 — следующая точка.
static func place_states(run: Run) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var on: Array = Run.ROUTES[run.route]["places"] if run.route >= 0 else []
	var next := run.next_key()
	for k in Briefing.ORDER:
		out.append(3.0 if k == next else 2.0 if run.visited.has(k) else 1.0 if on.has(k) else 0.0)
	return out
