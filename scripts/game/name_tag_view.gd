class_name NameTagView
extends Node3D
## Таблички игроков над фигурами (ART-033, `NameTag`): у каждого члена экипажа, кроме своего, — плашка с кружком
## роли, буквой и именем, повёрнута к камере, размер по расстоянию. Плашка — Sprite3D с текстурой NameTag.plate_image,
## буква и имя — Label3D; флаги как у экрана сканера (без света, двусторонние, без билборда) — новый шейдер не нужен.
## Узел в осях корабля рядом с CrewView, слой корабля. Сквозь стены не видна (проверка глубины).

const FONT_PX := 64

var tags: Array[Node3D] = []    ## корень таблички на каждого члена экипажа (по индексу в crew)
var plates: Array[Sprite3D] = []
var letters: Array[Label3D] = []
var names: Array[Label3D] = []
var keys: Array[String] = []     ## роль и имя, под которые собрана плашка


## Поставить таблички: crew — весь экипаж, me — свой (без таблички), cam — камера, которой смотрим
## (не камера мостика — облёт с борта, таблички скрыты).
func show_tags(crew: Array, me: Crew.Member, view: CrewView, cam: Camera3D, own_cam: Camera3D) -> void:
	while tags.size() < crew.size():
		_add()
	for i in tags.size():
		var t := tags[i]
		t.visible = false
		if i >= crew.size() or crew[i] == me or cam == null or cam != own_cam or i >= view.skeletons.size():
			continue
		var m: Crew.Member = crew[i]
		var sk := view.skeletons[i]
		if sk == null or not sk.is_inside_tree():
			continue
		var top := sk.find_bone("head_end")
		var head: Vector3 = sk.global_transform * (sk.get_bone_global_pose(top).origin if top >= 0 else Vector3(0, 1.8, 0))
		var anchor := head + Vector3.UP * NameTag.LIFT
		var d := cam.global_position.distance_to(anchor)
		if not NameTag.shown(d):
			continue
		_build(i, m)
		var h := NameTag.world_height(d, cam.fov)
		var to_cam := cam.global_position - anchor
		var ang := atan2(to_cam.x, to_cam.z)
		t.global_transform = Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * h), anchor + Vector3.UP * h * 0.5)
		var a := NameTag.alpha(d)
		plates[i].modulate = Color(1, 1, 1, a)
		letters[i].modulate = Color(NameTag.TEXT, a)
		names[i].modulate = Color(NameTag.TEXT, a)
		t.visible = true


## Высота плашки i в мире (м) и текст — для тестов.
func tag_height(i: int) -> float:
	return tags[i].global_basis.get_scale().y


func _add() -> void:
	var i := tags.size()
	var t := Node3D.new()
	t.name = "Табличка %d" % i
	add_child(t)
	var s := Sprite3D.new()
	s.name = "Плашка"
	_flags(s)
	s.render_priority = 1
	t.add_child(s)
	var l := _label("Буква роли", NameTag.LETTER_EM)
	t.add_child(l)
	var n := _label("Имя", NameTag.NAME_EM)
	t.add_child(n)
	t.visible = false
	tags.append(t)
	plates.append(s)
	letters.append(l)
	names.append(n)
	keys.append("")


func _flags(g: GeometryInstance3D) -> void:
	g.set("shaded", false)
	g.set("double_sided", true)
	g.set("alpha_cut", SpriteBase3D.ALPHA_CUT_DISABLED)
	g.set("billboard", BaseMaterial3D.BILLBOARD_DISABLED)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.layers = OceanView.LAYER_SHIP


func _label(nm: String, em: float) -> Label3D:
	var l := Label3D.new()
	l.name = nm
	_flags(l)
	l.font_size = FONT_PX
	l.outline_size = 0
	l.pixel_size = em / FONT_PX
	l.render_priority = 2
	return l


## Плашка под роль и имя: текстура по ширине имени, буква в кружке, имя после него.
func _build(i: int, m: Crew.Member) -> void:
	var text := NameTag.label(m.name, m.role)
	var key := "%d|%s" % [m.role, text]
	if keys[i] == key:
		return
	keys[i] = key
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x * NameTag.NAME_EM / FONT_PX
	var w := NameTag.width(tw)
	var img := NameTag.plate_image(w, NameTag.ring_color(m.role))
	plates[i].texture = ImageTexture.create_from_image(img)
	plates[i].pixel_size = 1.0 / NameTag.TEX_H
	letters[i].text = NameTag.letter(m.role)
	letters[i].position = Vector3(NameTag.letter_x(w), 0.0, 0.01)
	names[i].text = text
	names[i].position = Vector3(NameTag.name_x(w, tw), 0.0, 0.01)
