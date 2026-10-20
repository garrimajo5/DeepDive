class_name VoteView
extends Node3D
## Голосование «глубже или наверх» на голограмме над голостолом (ART-016): два поля — диск с лучом к столу, стрелка
## и подпись, под диском метки голосов ролей (кружок цвета роли с буквой) и счёт. Раскладка и числа — VoteHolo;
## узел — дочерний у SonarView (оси голограммы). Показывает show_vote(k, votes), k — доля перехода 0…1.

var fields := {}          ## choice → {"disc", "beam", "arrow", "word", "count", "marks": [[Sprite3D, Label3D]…]}
var _mats: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
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
	visible = false


## k — доля перехода (Briefing.Fade), votes — VoteHolo.votes(Run.opinions(...)).
func show_vote(k: float, votes: Dictionary) -> void:
	visible = k > 0.0
	if not visible:
		return
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
