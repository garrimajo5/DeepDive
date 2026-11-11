class_name NameTagView
extends Node3D
## Таблички игроков над фигурами (ART-033, `NameTag`): у каждого члена экипажа, кроме своего, — плашка с кружком
## роли, буквой и именем, повёрнута к камере, размер по расстоянию. Плашка — Sprite3D с текстурой NameTag.plate_image,
## буква и имя — Label3D; флаги как у экрана сканера (без света, двусторонние, без билборда) — новый шейдер не нужен.
## Узел в осях корабля рядом с CrewView, слой корабля. Сквозь стены не видна (проверка глубины).

const DOWN_K := 0.8   ## табличку под плашкой строки опускаем не дальше этой доли LIFT — до макушки не доходит (#387)

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
## без связи (`Member.lost`) — всё приглушено и строка «Нет связи». hidden — члены экипажа без таблички над головой
## (их табличка уже на метке «Занято» у поста, BusyMarkView). plate — плашка строки состояния на экране: задетая
## табличка опускается под неё не дальше DOWN_K·LIFT, иначе скрыта (#387). voice — места в экипаже тех, кто говорит
## по рации ART-041 (`Radio.voice`, только в поле зрения): та же «активность», не вторая табличка.
func show_tags(crew: Array, me: Crew.Member, view: CrewView, cam: Camera3D, own_cam: Camera3D, blocks: Array = [],
		dt: float = 1.0, hidden: Array = [], plate: Rect2 = Rect2(), voice: Array = []) -> void:
	while tags.size() < crew.size():
		_add()
	for i in mini(crew.size(), tags.size()):
		var mm: Crew.Member = crew[i]
		levels[i] = NameTag.glow_step(levels[i], (mm.active() or voice.has(i)) and not mm.lost, dt)
	var shown: Array = []   # [индекс, расстояние, точка над макушкой, высота в мире]
	for i in tags.size():
		var t := tags[i]
		t.visible = false
		if i >= crew.size() or crew[i] == me or hidden.has(crew[i]) or cam == null or cam != own_cam or i >= view.skeletons.size():
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
	shown.sort_custom(func(a, b): return NameTag.before(levels[a[0]] > 0.0, a[1], levels[b[0]] > 0.0, b[1]))
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
	var placed: Array = []   # поставленные таблички на экране
	for k in shown.size():
		var i: int = shown[k][0]
		var d: float = shown[k][1]
		var h: float = shown[k][3]
		if lift[k] == NameTag.HIDDEN:
			continue   # не поместилась над ближней — скрыта (ART-033)
		var r: Rect2 = rects[k]
		r.position.y -= lift[k]
		# под плашку строки состояния — опустить, но не на макушку (#387)
		var down := NameTag.under_plate(r, plate, NameTag.LIFT * DOWN_K * r.size.y / h)
		if down == NameTag.HIDDEN:
			continue
		r.position.y += down
		if down > 0.0 and placed.any(func(q: Rect2) -> bool: return q.intersects(r)):
			continue   # опущенная легла на другую табличку — скрыта, как при разносе (#320)
		if not NameTag.clear_of(r, screen, blocks):
			continue   # за краем экрана или на кнопке и панели (#319)
		placed.append(r)
		var up: float = (lift[k] - down) * h / rects[k].size.y   # пиксели экрана → метры у этой плашки
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
	var parts := TagParts.add(t, "Плашка", 1)   # плашка, буква роли, имя (TagParts)
	var g := TagParts.sprite("Нажимает", 1)
	g.position.z = 0.005
	g.visible = false
	t.add_child(g)
	var st := TagParts.label("Состояние", NameTag.STATUS_EM, 2)
	st.text = NameTag.LOST_TEXT
	st.visible = false
	t.add_child(st)
	t.visible = false
	tags.append(t)
	plates.append(parts[0])
	letters.append(parts[1])
	names.append(parts[2])
	glows.append(g)
	states.append(st)
	levels.append(0.0)
	keys.append("")
	widths.append(NameTag.MIN_W)


## Плашка под роль, имя и связь: текстура по ширине имени, буква в кружке, имя после него; без связи — приглушена,
## имя выше, под ним «Нет связи».
func _build(i: int, m: Crew.Member) -> void:
	var key := TagParts.key(m)
	if keys[i] == key:
		return
	keys[i] = key
	var text := NameTag.label(m.name, m.role)
	var cols := NameTag.colors(m.role, m.lost)
	var tw := TagParts.text_w(text, NameTag.NAME_EM)
	var w := NameTag.width(tw)
	widths[i] = w
	var img := NameTag.plate_image(w, cols[1], cols[0])
	TagParts.fill([plates[i], letters[i], names[i]], m, ImageTexture.create_from_image(img), w, tw, 0.0,
			NameTag.LOST_NAME_Y if m.lost else 0.0)
	glows[i].texture = ImageTexture.create_from_image(NameTag.glow_image(w))
	glows[i].pixel_size = 1.0 / NameTag.TEX_H
	var sw := TagParts.text_w(NameTag.LOST_TEXT, NameTag.STATUS_EM)
	states[i].position = Vector3(-w * 0.5 + NameTag.NAME_X + sw * 0.5, NameTag.LOST_STATUS_Y, 0.01)
	states[i].visible = m.lost
