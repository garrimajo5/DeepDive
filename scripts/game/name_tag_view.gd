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
var glows: Array[Sprite3D] = []   ## слой «нажимает» поверх плашки (NameTag.glow_image)
var states: Array[Label3D] = []   ## строка «Нет связи» под именем
var levels: Array[float] = []     ## яркость «нажимает» 0…1 (NameTag.glow_step)
var widths: Array[float] = []  ## ширина плашки в высотах
var keys: Array[String] = []     ## роль и имя, под которые собрана плашка


## Поставить таблички: crew — весь экипаж, me — свой (без таблички), cam — камера, которой смотрим
## (не камера мостика — облёт с борта, таблички скрыты). Размер — по глубине взгляда (#319), плашка параллельна
## экрану; рядом стоящие разнесены вверх, ближняя на месте, не поместилась — скрыта (#320); вылезла за край экрана
## или легла на кнопку или панель (blocks — прямоугольники экрана) — скрыта (#319). Состояния ART-033: нажал
## кнопку (`Member.active`) — контур ярче и три штриха, вход и выход за NameTag.FADE_T (dt — шаг; без dt — сразу);
## без связи (`Member.lost`) — всё приглушено и строка «Нет связи».
func show_tags(crew: Array, me: Crew.Member, view: CrewView, cam: Camera3D, own_cam: Camera3D, blocks: Array = [],
		dt: float = 1.0) -> void:
	while tags.size() < crew.size():
		_add()
	for i in mini(crew.size(), tags.size()):
		var mm: Crew.Member = crew[i]
		levels[i] = NameTag.glow_step(levels[i], mm.active() and not mm.lost, dt)
	var shown: Array = []   # [индекс, расстояние, точка над макушкой, высота в мире]
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
		var depth := -(cam.global_transform.affine_inverse() * anchor).z
		if not NameTag.visible_at(d, depth):
			continue
		_build(i, m)
		shown.append([i, d, anchor, NameTag.world_height(d, cam.fov, depth)])
	shown.sort_custom(func(a, b): return a[1] < b[1])
	var bz := cam.global_basis.z
	var ang := atan2(bz.x, bz.z)   # плашка параллельна экрану (поворот только вокруг вертикали)
	var screen := cam.get_viewport().get_visible_rect()
	var vp_h := screen.size.y
	var rects: Array = []
	for s in shown:
		var hp: float = NameTag.px(s[1]) * vp_h / NameTag.REF_H
		var c := cam.unproject_position(s[2] + Vector3.UP * s[3] * 0.5)
		var w: float = widths[s[0]] * hp
		rects.append(Rect2(c.x - w * 0.5, c.y - hp * 0.5, w, hp))
	var lift := NameTag.spread(rects)
	for k in shown.size():
		var i: int = shown[k][0]
		var d: float = shown[k][1]
		var h: float = shown[k][3]
		if lift[k] == NameTag.HIDDEN:
			continue   # не поместилась над ближней — скрыта (ART-033)
		var r: Rect2 = rects[k]
		r.position.y -= lift[k]
		if not NameTag.clear_of(r, screen, blocks):
			continue   # за краем экрана или на кнопке и панели (#319)
		var up: float = lift[k] * h / rects[k].size.y   # пиксели экрана → метры у этой плашки
		var t := tags[i]
		t.global_transform = Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * h),
				shown[k][2] + Vector3.UP * (h * 0.5 + up))
		var a := NameTag.alpha(d)
		var col: Color = NameTag.colors((crew[i] as Crew.Member).role, (crew[i] as Crew.Member).lost)[2]
		plates[i].modulate = Color(1, 1, 1, a)
		glows[i].modulate = Color(1, 1, 1, a * levels[i])
		glows[i].visible = levels[i] > 0.0
		letters[i].modulate = Color(col, a)
		names[i].modulate = Color(col, a)
		states[i].modulate = Color(col, a)
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
	var g := Sprite3D.new()
	g.name = "Нажимает"
	_flags(g)
	g.render_priority = 1
	g.position.z = 0.005
	g.visible = false
	t.add_child(g)
	var st := _label("Состояние", NameTag.STATUS_EM)
	st.text = NameTag.LOST_TEXT
	st.visible = false
	t.add_child(st)
	t.visible = false
	tags.append(t)
	plates.append(s)
	letters.append(l)
	names.append(n)
	glows.append(g)
	states.append(st)
	levels.append(0.0)
	keys.append("")
	widths.append(NameTag.MIN_W)


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


## Плашка под роль, имя и связь: текстура по ширине имени, буква в кружке, имя после него; без связи — приглушена,
## имя выше, под ним «Нет связи».
func _build(i: int, m: Crew.Member) -> void:
	var text := NameTag.label(m.name, m.role)
	var key := "%d|%s|%s" % [m.role, text, m.lost]
	if keys[i] == key:
		return
	keys[i] = key
	var cols := NameTag.colors(m.role, m.lost)
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x * NameTag.NAME_EM / FONT_PX
	var w := NameTag.width(tw)
	widths[i] = w
	var img := NameTag.plate_image(w, cols[1], cols[0])
	plates[i].texture = ImageTexture.create_from_image(img)
	plates[i].pixel_size = 1.0 / NameTag.TEX_H
	glows[i].texture = ImageTexture.create_from_image(NameTag.glow_image(w))
	glows[i].pixel_size = 1.0 / NameTag.TEX_H
	letters[i].text = NameTag.letter(m.role)
	letters[i].position = Vector3(NameTag.letter_x(w), 0.0, 0.01)
	names[i].text = text
	names[i].position = Vector3(NameTag.name_x(w, tw), NameTag.LOST_NAME_Y if m.lost else 0.0, 0.01)
	var sw := font.get_string_size(NameTag.LOST_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x * NameTag.STATUS_EM / FONT_PX
	states[i].position = Vector3(-w * 0.5 + NameTag.NAME_X + sw * 0.5, NameTag.LOST_STATUS_Y, 0.01)
	states[i].visible = m.lost
