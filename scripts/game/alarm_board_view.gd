class_name AlarmBoardView
extends Node3D
## Табло тревог над носовым окном мостика (ART-025, AlarmBoard): рама, разделители и кронштейны — один меш
## с цветом вершин (1 вызов отрисовки), лицо — квад с шейдером `shaders/alarm_board.gdshader` (1 вызов). Надписи
## пока рисуются шрифтом игры один раз в текстуру (SubViewport); атлас художника — MOD-019 (#198).
## Слой 2 (LAYER_SHIP): корабль изнутри.

const TEX_SIZE := Vector2i(3072, 64)   ## шире лица в 1,5 раза по x: на табло буквы сжаты, как узкий шрифт ART-025
const FONT_SIZE := 56

var frame: MeshInstance3D
var face: MeshInstance3D
var mat: ShaderMaterial
var levels: Array[Vector2] = []   ## последние уровни полей (AlarmBoard.levels)
var _words: SubViewport
var hint: MeshInstance3D          ## янтарная рамка у поста главной тревоги (AlarmBoard.hint), 1 вызов отрисовки
var hint_mat: StandardMaterial3D
var _hint_key := ""


func _ready() -> void:
	frame = MeshInstance3D.new()
	frame.name = "Табло: рама"
	frame.mesh = build_frame()
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.roughness = 0.75
	fm.metallic = 0.2
	frame.material_override = fm
	frame.layers = OceanView.LAYER_SHIP
	add_child(frame)

	_words = SubViewport.new()
	_words.name = "Табло: надписи"
	_words.size = TEX_SIZE
	_words.transparent_bg = true
	_words.disable_3d = true
	_words.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_words)
	var r: Vector2 = AlarmBoard.face_rect()[1]
	for i in AlarmBoard.WORDS.size():
		var s := AlarmBoard.field_span(i)
		var l := Label.new()
		l.text = AlarmBoard.WORDS[i]
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var x0 := AlarmBoard.u_of(s.x) * TEX_SIZE.x
		var x1 := AlarmBoard.u_of(s.y) * TEX_SIZE.x
		l.position = Vector2(x0, 0)
		l.size = Vector2(x1 - x0, TEX_SIZE.y)
		_words.add_child(l)

	face = MeshInstance3D.new()
	face.name = "Табло: лицо"
	var q := QuadMesh.new()
	q.size = r
	face.mesh = q
	face.position = AlarmBoard.face_rect()[0] + Vector3(0, 0, 0.001)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/alarm_board.gdshader")
	mat.set_shader_parameter("words", _words.get_texture())
	var edges := PackedFloat32Array()
	for i in AlarmBoard.WORDS.size():
		edges.append(AlarmBoard.u_of(AlarmBoard.field_span(i).x))
	edges.append(1.0)
	mat.set_shader_parameter("edges", edges)
	mat.set_shader_parameter("face_size", r)
	mat.set_shader_parameter("back", AlarmBoard.BACK)
	mat.set_shader_parameter("word_off", AlarmBoard.WORD_OFF)
	mat.set_shader_parameter("word_on", AlarmBoard.WORD_ON)
	face.material_override = mat
	face.layers = OceanView.LAYER_SHIP
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(face)

	hint = MeshInstance3D.new()
	hint.name = "Подсказка: рамка у поста"
	hint_mat = StandardMaterial3D.new()
	hint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hint_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	hint_mat.albedo_color = AlarmBoard.WORD_ON
	hint.material_override = hint_mat
	hint.layers = OceanView.LAYER_SHIP
	hint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hint.visible = false
	add_child(hint)
	show_alarms([false, false, false, false, false], 0.0)


## Состояние полей: on — активные тревоги по порядку AlarmBoard.Field, t — время игры (мигание главной).
## breach_spot — открытая пробоина (к ней ведёт рамка, если главная тревога — пробоина).
func show_alarms(on: Array[bool], t: float, breach_spot: Breach.Spot = null) -> void:
	levels = AlarmBoard.levels(on, t)
	if mat:
		var arr := PackedVector2Array()
		for v in levels:
			arr.append(v)
		mat.set_shader_parameter("lv", arr)
	if hint:
		_show_hint(AlarmBoard.hint(AlarmBoard.main_field(on), breach_spot), AlarmBoard.hint_glow(on, t))


func _show_hint(h: AlarmBoard.Hint, glow: float) -> void:
	hint.visible = h != null
	if h == null:
		return
	var key := "%s %s" % [h.size, h.normal]
	if key != _hint_key:
		_hint_key = key
		hint.mesh = build_hint(h.size)
	var z := h.normal
	var up := Vector3.UP
	hint.transform = Transform3D(Basis(up.cross(z).normalized(), up, z), h.center)
	hint_mat.albedo_color = Color(AlarmBoard.WORD_ON * glow, 1.0)


## Рамка подсказки в своих осях: 4 бруска в плоскости XY (лицо +Z, материал без отсечения граней).
static func build_hint(size: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bar in AlarmBoard.hint_bars(size):
		var c: Vector2 = bar[0]
		var hs: Vector2 = bar[1] * 0.5
		var a := Vector3(c.x - hs.x, c.y - hs.y, 0.0)
		var b := Vector3(c.x + hs.x, c.y - hs.y, 0.0)
		var d := Vector3(c.x + hs.x, c.y + hs.y, 0.0)
		var e := Vector3(c.x - hs.x, c.y + hs.y, 0.0)
		for v in [a, d, b, a, e, d]:
			st.add_vertex(v)
	return st.commit()


static func build_frame() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in AlarmBoard.boxes():
		st.set_color(BridgePlan.COLORS[part.paint])
		BridgeView._add_box(st, part)
	st.generate_tangents()
	return st.commit()
