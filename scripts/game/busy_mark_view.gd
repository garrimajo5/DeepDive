class_name BusyMarkView
extends Node3D
## Метки «Занято» над постами, занятыми другим (ART-033, `BusyMark`): подложка с замком (Sprite3D), слово «Занято»
## (Label3D) и табличка занявшего — та же плашка, буква и имя, что у `NameTagView`. Флаги как у табличек (без света,
## двусторонние, без билборда) — новый шейдер не нужен. Узел в осях корабля, слой корабля; плашка параллельна экрану,
## размер по расстоянию как у таблички (`NameTag.world_height`), видна до BusyMark.SHOW_AT м.

const FONT_PX := 64

var roots := {}      ## id поста → Node3D метки
var panels := {}     ## id → Sprite3D подложки
var words := {}      ## id → Label3D «Занято»
var plates := {}     ## id → Sprite3D таблички занявшего
var letters := {}    ## id → Label3D буквы роли
var names := {}      ## id → Label3D имени
var keys := {}       ## id → роль и имя, под которые собрана метка
var layout: Touch.Layout   ## кнопки экрана: метка под них не ложится (#373)
## Собранные текстуры по роли и имени занявшего (#375): подложка и плашка рисуются попиксельно — десятки мс на
## телефоне, поэтому их готовит `prepare` заранее (при сборке экипажа, под шторкой прогрева), а не нажатие «Занято».
var cache := {}
var images_built := 0      ## сколько раз рисовали текстуры (тест: при нажатии — ни разу)


func _ready() -> void:
	for id: String in Crew.BUSY:
		_add(id)


## Поставить метки: crew — экипаж, me — свой игрок (свой пост не помечается), cam — камера, которой смотрим
## (облёт с борта — метки скрыты). Возвращает занявших, чьи метки видны: их табличку над головой не показываем.
func show_marks(crew: Array, me: Crew.Member, cam: Camera3D, own_cam: Camera3D) -> Array:
	var holders: Array = []
	prepare(crew)   # текстуры — заранее, с первого кадра (под шторкой прогрева), а не в кадр нажатия (#375)
	for id: String in roots:
		(roots[id] as Node3D).visible = false
	if cam == null or cam != own_cam:
		return holders
	var bz := cam.global_basis.z
	var ang := atan2(bz.x, bz.z)
	for mk: Array in BusyMark.marks(crew, me):
		var id: String = mk[0]
		var m: Crew.Member = mk[1]
		if not roots.has(id):
			continue
		var root: Node3D = roots[id]
		var base := to_global(BusyMark.ANCHORS[id])
		var d0 := cam.global_position.distance_to(base)
		if not BusyMark.shown(d0):
			continue
		var h0 := NameTag.world_height(d0, cam.fov, -(cam.global_transform.affine_inverse() * base).z)
		var center := base + Vector3.UP * h0 * BusyMark.H * 0.5
		var d := cam.global_position.distance_to(center)
		var depth := -(cam.global_transform.affine_inverse() * center).z
		if depth < NameTag.MIN_DEPTH:
			continue
		var h := NameTag.world_height(d, cam.fov, depth)
		_build(id, m)
		center = _fit(cam, center, depth, h, float(cache[keys[id]]["w"]))
		root.global_transform = Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * h), center)
		var a := BusyMark.alpha(d)
		(panels[id] as Sprite3D).modulate = Color(1, 1, 1, a)
		(plates[id] as Sprite3D).modulate = Color(1, 1, 1, a)
		(words[id] as Label3D).modulate = Color(NameTag.TEXT, a)
		var col: Color = NameTag.colors(m.role, m.lost)[2]
		(letters[id] as Label3D).modulate = Color(col, a)
		(names[id] as Label3D).modulate = Color(col, a)
		root.visible = true
		holders.append(m)
	return holders


## Сдвинуть центр метки (мир) так, чтобы на экране она была целиком и не под кнопками (`BusyMark.fit`, #373).
func _fit(cam: Camera3D, center: Vector3, depth: float, h: float, w: float) -> Vector3:
	var vr := cam.get_viewport().get_visible_rect()
	var m_px := vr.size.y / (2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5))   # px на метр на этой глубине
	var size := Vector2(w, BusyMark.H) * h * m_px
	var c := cam.unproject_position(center)
	var keep: Array = []
	if layout != null:
		for b: Touch.Circle in [layout.noclip, layout.action, layout.light, layout.up, layout.down, layout.pad]:
			if b.r > 0.0:
				keep.append(Rect2(b.c - Vector2.ONE * b.r, Vector2.ONE * b.r * 2.0))
	var off := BusyMark.fit(Rect2(c - size * 0.5, size), vr, keep)
	if off == Vector2.ZERO:
		return center
	return cam.project_position(c + off, depth)


## Собрать текстуры меток для всего экипажа заранее (#375): дёшево, если всё уже собрано.
func prepare(crew: Array) -> void:
	for m: Crew.Member in crew:
		_entry(m)


func _add(id: String) -> void:
	var t := Node3D.new()
	t.name = "Занято %s" % id
	add_child(t)
	var p := _sprite("Подложка", 1)
	t.add_child(p)
	var w := _label("Занято", BusyMark.WORD_EM)
	w.text = BusyMark.WORD
	t.add_child(w)
	var s := _sprite("Табличка", 2)
	s.position.z = 0.005
	t.add_child(s)
	var l := _label("Буква роли", NameTag.LETTER_EM)
	t.add_child(l)
	var n := _label("Имя", NameTag.NAME_EM)
	t.add_child(n)
	t.visible = false
	roots[id] = t
	panels[id] = p
	words[id] = w
	plates[id] = s
	letters[id] = l
	names[id] = n
	keys[id] = ""


func _sprite(nm: String, prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = nm
	_flags(s)
	s.render_priority = prio
	return s


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
	l.render_priority = 3
	return l


## Текстуры и размеры метки под занявшего (из кэша; нет — рисуем и кладём).
func _entry(m: Crew.Member) -> Dictionary:
	var text := NameTag.label(m.name, m.role)
	var key := "%d|%s|%s" % [m.role, text, m.lost]
	if cache.has(key):
		return cache[key]
	var font := ThemeDB.fallback_font
	var ww := font.get_string_size(BusyMark.WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x * BusyMark.WORD_EM / FONT_PX
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x * NameTag.NAME_EM / FONT_PX
	var pw := NameTag.width(tw)
	var w := BusyMark.width(ww, pw)
	var cols := NameTag.colors(m.role, m.lost)
	images_built += 1
	var e := {
		"key": key, "text": text, "ww": ww, "tw": tw, "pw": pw, "w": w,
		"panel": ImageTexture.create_from_image(BusyMark.panel_image(w)),
		"plate": ImageTexture.create_from_image(NameTag.plate_image(pw, cols[1], cols[0])),
	}
	cache[key] = e
	return e


## Метка под занявшего: подложка по ширине слова и таблички, табличка — как у NameTagView.
func _build(id: String, m: Crew.Member) -> void:
	var e := _entry(m)
	if keys[id] == e["key"]:
		return
	keys[id] = e["key"]
	var ww: float = e["ww"]
	var tw: float = e["tw"]
	var pw: float = e["pw"]
	var w: float = e["w"]
	var panel: Sprite3D = panels[id]
	panel.texture = e["panel"]
	panel.pixel_size = BusyMark.H / BusyMark.TEX_H
	(words[id] as Label3D).position = Vector3(BusyMark.from_center(BusyMark.PAD + BusyMark.WORD_X + ww * 0.5, w), 0.0, 0.01)
	var pc := BusyMark.from_center(BusyMark.tag_x(ww) + pw * 0.5, w)   # центр таблички от середины подложки
	var plate: Sprite3D = plates[id]
	plate.texture = e["plate"]
	plate.pixel_size = 1.0 / NameTag.TEX_H
	plate.position = Vector3(pc, 0.0, 0.005)
	(letters[id] as Label3D).text = NameTag.letter(m.role)
	(letters[id] as Label3D).position = Vector3(pc + NameTag.letter_x(pw), 0.0, 0.01)
	(names[id] as Label3D).text = e["text"]
	(names[id] as Label3D).position = Vector3(pc + NameTag.name_x(pw, tw), 0.0, 0.01)
