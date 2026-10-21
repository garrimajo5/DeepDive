class_name VoteView
extends Node3D
## Голосование «глубже или наверх» на голограмме над голостолом (ART-016): два поля — диск с лучом к столу, стрелка
## и подпись, под диском метки голосов ролей (кружок цвета роли с буквой) и счёт. Раскладка и числа — VoteHolo;
## узел — дочерний у SonarView (оси голограммы). Показывает show_vote(k, votes), k — доля перехода 0…1.
## После «наверх» — итог: подложка с заголовком и четырьмя строками лицом к смотрящему (show_result).

var fields := {}          ## choice → {"disc", "beam", "arrow", "word", "count", "marks": [[Sprite3D, Label3D]…]}
var board: Node3D        ## итог забега над столом (VoteHolo.BOARD_*)
var board_rows: Array = []   ## [[Label3D название, Label3D значение, Sprite3D иконка ART-026]…]
var _mats: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
var _board_mats: Array[StandardMaterial3D] = []
var _board_labels: Array[Label3D] = []
static var _ring: ImageTexture


func _ready() -> void:
	name = "Голосование на голограмме"
	if _ring == null:
		_ring = ImageTexture.create_from_image(VoteHolo.ring_image())
	for choice in VoteHolo.CHOICES:
		var f := {}
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = VoteHolo.DISC_R
		dm.bottom_radius = VoteHolo.DISC_R
		dm.height = 0.006
		dm.radial_segments = 40
		dm.rings = 1
		disc.mesh = dm
		disc.material_override = _holo_mat(0.3)
		disc.position = VoteHolo.field_pos(choice)
		f["disc"] = _add(disc, "Поле " + VoteHolo.WORDS[choice])
		var beam := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = VoteHolo.DISC_R
		bm.bottom_radius = 0.05
		bm.height = VoteHolo.DISC_Y
		bm.radial_segments = 32
		bm.rings = 1
		bm.cap_top = false
		bm.cap_bottom = false
		beam.mesh = bm
		beam.material_override = _holo_mat(0.07)
		beam.position = VoteHolo.field_pos(choice, VoteHolo.DISC_Y * 0.5)
		f["beam"] = _add(beam, "Луч " + VoteHolo.WORDS[choice])
		var arrow := MeshInstance3D.new()
		arrow.mesh = _arrow_mesh(choice == "deep")
		var am := _holo_mat(0.9)
		am.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		arrow.material_override = am
		arrow.position = VoteHolo.field_pos(choice, VoteHolo.ARROW_Y)
		f["arrow"] = _add(arrow, "Стрелка " + VoteHolo.WORDS[choice])
		f["word"] = _add(_label(VoteHolo.WORDS[choice], 56, VoteHolo.field_pos(choice, VoteHolo.WORD_Y)),
			"Подпись " + VoteHolo.WORDS[choice])
		f["count"] = _add(_label("0", 64, VoteHolo.field_pos(choice, VoteHolo.COUNT_Y)), "Счёт " + VoteHolo.WORDS[choice])
		var marks: Array = []
		for i in Crew.ROLE_NAMES.size():
			var s := Sprite3D.new()
			s.texture = _ring
			s.pixel_size = VoteHolo.MARK_SIZE / float(_ring.get_height())
			s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			s.shaded = false
			s.double_sided = true
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			s.render_priority = 1
			_add(s, "Метка %s %d" % [VoteHolo.WORDS[choice], i])
			var l := _label("", 44, Vector3.ZERO)
			l.outline_size = 0
			l.render_priority = 2
			l.pixel_size = 0.0014
			s.add_child(l)
			marks.append([s, l])
		f["marks"] = marks
		fields[choice] = f
	_build_board()
	visible = false


func _build_board() -> void:
	var mats_before := _mats.size()
	var labels_before := _labels.size()
	board = Node3D.new()
	board.name = "Итог забега"
	board.position = Vector3(0, VoteHolo.BOARD_Y, 0)
	add_child(board)
	var back := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(VoteHolo.BOARD_W, VoteHolo.BOARD_H)
	back.mesh = qm
	var bm := _holo_mat(0.94)
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	bm.albedo_color = Color(VoteHolo.BACK, 0.94)
	back.material_override = bm
	_put(board, back, "Подложка итога")
	var lines := MeshInstance3D.new()
	lines.mesh = _lines_mesh(VoteHolo.board_lines(4))
	var lm := _holo_mat(0.7)
	lm.render_priority = 1
	lines.material_override = lm
	_put(board, lines, "Рамка итога")
	var title := _label(VoteHolo.TITLE, 46, Vector3(0, VoteHolo.TITLE_DY, 0.002))
	title.modulate = VoteHolo.HOLO
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	title.render_priority = 2
	_put(board, title, "Заголовок итога")
	var x := VoteHolo.BOARD_W * 0.5 - VoteHolo.BOARD_PAD
	for i in 4:
		var n := _label("", 40, Vector3(VoteHolo.name_x(), VoteHolo.row_y(i), 0.002))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var v := _label("", 52, Vector3(x, VoteHolo.row_y(i), 0.002))
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for l: Label3D in [n, v]:
			l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			l.render_priority = 2
		var ic := Sprite3D.new()   # иконка строки ART-026: текстура по названию строки (show_result)
		ic.pixel_size = VoteHolo.ICON_SIZE / 256.0
		ic.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		ic.shaded = false
		ic.double_sided = true
		ic.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		ic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ic.render_priority = 2
		ic.layers = OceanView.LAYER_SHIP
		ic.position = Vector3(VoteHolo.icon_x(), VoteHolo.row_y(i), 0.002)
		var row: String = VoteHolo.SUMMARY_ICONS.keys()[i]   # заранее — прогрев шейдеров видит иконку с текстурой
		ic.texture = load(VoteHolo.summary_icon(row))
		ic.set_meta("path", VoteHolo.summary_icon(row))
		_put(board, n, "Строка итога %d" % i)
		_put(board, v, "Число итога %d" % i)
		_put(board, ic, "Иконка итога %d" % i)
		board_rows.append([n, v, ic])
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = VoteHolo.BOARD_W * 0.35
	cm.bottom_radius = 0.06
	cm.height = VoteHolo.BOARD_Y - VoteHolo.BOARD_H * 0.5
	cm.radial_segments = 32
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	beam.material_override = _holo_mat(0.06)
	beam.position = Vector3(0, cm.height * 0.5, 0)
	_add(beam, "Луч итога")
	# свои списки: голосование и итог гаснут и загораются отдельно
	for i in range(mats_before, _mats.size()):
		_board_mats.append(_mats[i])
	for i in range(labels_before, _labels.size()):
		_board_labels.append(_labels[i])
	_mats.resize(mats_before)
	_labels.resize(labels_before)
	beam.reparent(board)   # луч — часть итога: гаснет вместе с подложкой
	beam.position = Vector3(0, cm.height * 0.5 - VoteHolo.BOARD_Y, 0)
	board.visible = false


## Итог: k — доля перехода 0…1, rows — Run.summary (четыре строки), eye — глаз смотрящего в осях голограммы.
func show_result(k: float, rows: Array, eye: Vector3) -> void:
	board.visible = k > 0.0
	if not board.visible:
		return
	visible = true
	for f: Dictionary in fields.values():   # поля голосования прячет итог
		for key in ["disc", "beam", "arrow", "word", "count"]:
			(f[key] as Node3D).visible = false
		for m: Array in f["marks"]:
			(m[0] as Sprite3D).visible = false
	board.rotation.y = VoteHolo.board_yaw(eye)
	for m in _board_mats:
		m.albedo_color.a = m.get_meta("a") * k
	for l in _board_labels:
		l.modulate.a = k
		l.outline_modulate.a = k
	for i in board_rows.size():
		var r: Array = rows[i] if i < rows.size() else ["", ""]
		(board_rows[i][0] as Label3D).text = str(r[0])
		(board_rows[i][1] as Label3D).text = str(r[1])
		var ic: Sprite3D = board_rows[i][2]
		var path := VoteHolo.summary_icon(str(r[0]))
		if ic.get_meta("path", "") != path:
			ic.texture = load(path) if path != "" else null
			ic.set_meta("path", path)
		ic.modulate = Color(1, 1, 1, k)   # цвет — в самой текстуре (#67DDEB), гаснет с подложкой


## k — доля перехода (Briefing.Fade), votes — VoteHolo.votes(Run.opinions(...)).
func show_vote(k: float, votes: Dictionary) -> void:
	visible = k > 0.0 or board.visible
	if k <= 0.0:
		return
	for f: Dictionary in fields.values():
		for key in ["disc", "beam", "arrow", "word", "count"]:
			(f[key] as Node3D).visible = true
	for m in _mats:
		m.albedo_color.a = m.get_meta("a") * k
	for l in _labels:
		l.modulate.a = k
		l.outline_modulate.a = k
	for choice in VoteHolo.CHOICES:
		var f: Dictionary = fields[choice]
		var roles: Array = votes.get(choice, [])
		(f["count"] as Label3D).text = str(roles.size())
		var marks: Array = f["marks"]
		for i in marks.size():
			var s: Sprite3D = marks[i][0]
			var l: Label3D = marks[i][1]
			s.visible = i < roles.size()
			if not s.visible:
				continue
			var c := Crew.role_color(roles[i])
			s.position = VoteHolo.mark_pos(choice, i, roles.size())
			s.modulate = Color(c.r, c.g, c.b, k)
			l.text = VoteHolo.letter(roles[i])
			l.modulate = Color(c.r, c.g, c.b, k)


func _add(n: Node3D, nm: String) -> Node3D:
	n.name = nm
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = OceanView.LAYER_SHIP
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n


func _put(parent: Node3D, n: Node3D, nm: String) -> void:
	n.name = nm
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = OceanView.LAYER_SHIP
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)


func _holo_mat(a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_fog = true
	m.albedo_color = Color(VoteHolo.HOLO, a)
	m.set_meta("a", a)
	_mats.append(m)
	return m


func _label(t: String, px: int, at: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.shaded = false
	l.double_sided = true
	l.font_size = px
	l.outline_size = 12
	l.pixel_size = 0.0016
	l.modulate = VoteHolo.TEXT
	l.outline_modulate = VoteHolo.BACK
	l.position = at
	l.layers = OceanView.LAYER_SHIP
	_labels.append(l)
	return l


## Плоская стрелка из VoteHolo.arrow_outline в плоскости XY (билборд поворачивает её к камере).
static func _arrow_mesh(down: bool) -> ArrayMesh:
	var pts := VoteHolo.arrow_outline(VoteHolo.ARROW_H, down)
	var idx := Geometry2D.triangulate_polygon(pts)
	var v := PackedVector3Array()
	for i in idx:
		v.append(Vector3(pts[i].x, pts[i].y, 0.0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Рамка и разделители итога одним мешем: прямоугольники VoteHolo.board_lines в плоскости XY, чуть перед подложкой.
static func _lines_mesh(rects: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	for r in rects:
		var c: Vector2 = r[0]
		var h: Vector2 = r[1] * 0.5
		var a := Vector3(c.x - h.x, c.y - h.y, 0.001)
		var b := Vector3(c.x + h.x, c.y - h.y, 0.001)
		var d := Vector3(c.x + h.x, c.y + h.y, 0.001)
		var e := Vector3(c.x - h.x, c.y + h.y, 0.001)
		v.append_array([a, e, d, a, d, b])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
