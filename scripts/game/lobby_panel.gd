class_name LobbyPanel
extends CanvasLayer
## Экран сбора экипажа ART-028 (`Lobby`) поверх затемнённой сцены мостика: заголовок, подзаголовок, «Создать забег»
## и «Подключиться» (в комнате погашены), четыре строки ролей, строка ожидания, «Готов» / «Отменить готовность»,
## «Начать погружение» (у гостя — «Ждём начала от хоста»), «Назад к списку» при занятой роли. Состояние и места —
## `Lobby`; слой как у экрана адреса (91), под заставкой прогрева (100). Статус не только цветом: галочка, кольцо,
## прочерк, замок. У хоста по ART-039 — «Назад» вверху и плашка «Ваш адрес» над ролями (строки ниже на `Lobby.dy`).

var lobby: Lobby
var draw: Control
var bold: FontVariation   ## полужирный шрифта игры: заголовок, роли, кнопки, буквы


func _init() -> void:
	name = "Сбор экипажа"
	layer = 91
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Lobby.DIM
	add_child(dim)
	draw = Control.new()
	draw.name = "Строки"
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_screen)
	add_child(draw)
	visible = false


func show_lobby(l: Lobby) -> void:
	lobby = l
	visible = l != null and l.open
	if visible:
		draw.queue_redraw()


func _draw_screen() -> void:
	if lobby == null:
		return
	var size := draw.get_viewport_rect().size
	var s := Lobby.scale(size)
	var font := draw.get_theme_default_font()
	if bold == null:
		bold = FontVariation.new()
		bold.base_font = font
		bold.variation_embolden = 0.7
	if lobby.shows_address():
		_host_top(font, size, s)
	else:
		_text(bold, Lobby.TITLE, Lobby.to_screen(Lobby.TITLE_AT, size), Lobby.TITLE_PX * s, MainMenu.INK)
		_text(font, lobby.subtitle(), Lobby.to_screen(Lobby.SUB_AT, size), Lobby.SUB_PX * s, MainMenu.SOFT)
		draw.draw_line(Lobby.to_screen(Vector2(Lobby.TITLE_AT.x, Lobby.RULE_Y), size),
			Lobby.to_screen(Vector2(Lobby.SEARCH.end.x, Lobby.RULE_Y), size), Color(MainMenu.EDGE, 0.8), maxf(1.0, 2.0 * s))
		_button(bold, Lobby.screen_rect("create", size), "Создать забег", s, "off")
		_button(bold, Lobby.screen_rect("search", size), "Подключиться", s, "off")
		_text(font, lobby.head(), Lobby.to_screen(Lobby.HEAD_AT, size), Lobby.SMALL_PX * s, MainMenu.SOFT)
	for i in Lobby.SEATS:
		_row(font, i, size, s)
	var nr := lobby.rect("note", size)
	draw.draw_rect(nr, Color(MainMenu.DARK, 0.78))
	var npx := Lobby.SMALL_PX * s
	draw.draw_string(font, Vector2(nr.position.x + 16.0 * s, nr.get_center().y + Splash.CAP_H * npx * 0.5),
		lobby.note(), HORIZONTAL_ALIGNMENT_LEFT, nr.size.x - 32.0 * s, roundi(npx), MainMenu.INK)
	if lobby.shows_back():
		_button(bold, lobby.rect("back", size), "Назад к списку", s, "plain")
		return
	var m := lobby.mine()
	var ready_on := lobby.enabled("ready")
	var start_on := lobby.enabled("start")
	_button(bold, lobby.rect("ready", size), lobby.ready_text(), s,
		"off" if not ready_on else ("plain" if m.ready else "main"))
	if lobby.is_host():
		_button(bold, lobby.rect("start", size), lobby.start_text(), s, "main" if start_on else "off")
	else:
		var r := lobby.rect("start", size)
		var px := Lobby.SMALL_PX * s
		draw.draw_string(font, Vector2(r.position.x, r.get_center().y + Splash.CAP_H * px * 0.5), lobby.start_text(),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, roundi(px), MainMenu.SOFT)


## Верх хоста по ART-039: заголовок, «Назад», плашка «Ваш адрес: 192.168.43.17 · Скажите его товарищам».
func _host_top(font: Font, size: Vector2, s: float) -> void:
	_text(bold, Lobby.TITLE, Lobby.to_screen(Lobby.HOST_TITLE_AT, size), Lobby.TITLE_PX * s, MainMenu.INK)
	_button(bold, lobby.rect("leave", size), "Назад", s, "plain")
	draw.draw_style_box(_box(s, MainMenu.PANEL, MainMenu.EDGE), Lobby.rect_to_screen(Lobby.ADDR, size))
	_text(font, "Ваш адрес:", Lobby.to_screen(Lobby.ADDR_LABEL_AT, size), Lobby.ADDR_LABEL_PX * s, MainMenu.SOFT)
	var has := lobby.address != ""
	_text(font, lobby.address_text(), Lobby.to_screen(Lobby.ADDR_AT, size), Lobby.ADDR_PX * s,
		MainMenu.MAIN if has else MainMenu.INK)
	_text(font, lobby.address_hint(), Lobby.to_screen(Lobby.ADDR_HINT_AT, size), Lobby.ADDR_HINT_PX * s, MainMenu.SOFT)


## Строка роли: кружок с буквой, название и кто, состояние справа; своя — толще контур акцентом.
func _row(font: Font, i: int, size: Vector2, s: float) -> void:
	var r := Lobby.rect_to_screen(Lobby.row_rect(i, lobby.dy()), size)
	var h := lobby.holder(i)
	var own := h != null and h.id == lobby.me
	var free := h == null
	var sb := _box(s, MainMenu.DARK if free else MainMenu.PANEL, MainMenu.MAIN if own else MainMenu.EDGE,
		3.0 if own else 2.0)
	draw.draw_style_box(sb, r)
	var cy := r.get_center().y
	var c := Vector2(r.position.x + Lobby.CIRCLE_X * s, cy)
	draw.draw_arc(c, Lobby.CIRCLE_R * s, 0.0, TAU, 48, Lobby.RING[i], maxf(1.5, 3.5 * s), true)
	var lpx := Lobby.LETTER_PX * s
	draw.draw_string(bold, Vector2(c.x - Lobby.CIRCLE_R * s, cy + Splash.CAP_H * lpx * 0.5), Lobby.LETTERS[i],
		HORIZONTAL_ALIGNMENT_CENTER, Lobby.CIRCLE_R * 2.0 * s, roundi(lpx), Lobby.RING[i])
	var x := r.position.x + Lobby.NAME_X * s
	var rpx := Lobby.ROLE_PX * s
	var ppx := Lobby.PNAME_PX * s
	draw.draw_string(bold, Vector2(x, r.position.y + 18.0 * s + Splash.CAP_H * rpx), Crew.ROLE_NAMES[i],
		HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(rpx), MainMenu.INK)
	draw.draw_string(font, Vector2(x, r.position.y + 64.0 * s + Splash.CAP_H * ppx), lobby.who(i),
		HORIZONTAL_ALIGNMENT_LEFT, (Lobby.STATE_X - Lobby.NAME_X - 40.0) * s, roundi(ppx),
		MainMenu.OFF if free else MainMenu.SOFT)
	var sx := r.position.x + Lobby.STATE_X * s
	var tx := sx + 50.0 * s
	var w := maxf(1.5, 4.0 * s)
	match lobby.look(i):
		Lobby.Look.FREE:
			draw.draw_line(Vector2(r.position.x + 640.0 * s, cy), Vector2(r.position.x + 860.0 * s, cy), MainMenu.EDGE,
				maxf(1.0, 2.0 * s))
			var pr := lobby.rect("pick%d" % i, size)
			if lobby.enabled("pick%d" % i):
				_button(bold, pr, "Выбрать роль", s, "plain", MainMenu.MAIN)
		Lobby.Look.READY:
			var a := Vector2(sx - 16.0 * s, cy)
			draw.draw_polyline(PackedVector2Array([a, a + Vector2(14, 14) * s, a + Vector2(44, -18) * s]), MainMenu.MAIN, w, true)
			_state(bold, "Готов", tx, cy, s, MainMenu.MAIN)
		Lobby.Look.WAIT:
			draw.draw_arc(Vector2(sx, cy), 14.0 * s, 0.0, TAU, 32, MainMenu.INK, maxf(1.0, 3.0 * s), true)
			_state(bold, "Ждём", tx, cy, s, MainMenu.INK)
		Lobby.Look.TAKEN:   # замок: дужка и корпус
			var b := Rect2(sx - 12.0 * s, cy - 4.0 * s, 24.0 * s, 20.0 * s)
			draw.draw_arc(Vector2(sx, cy - 4.0 * s), 8.0 * s, PI, TAU, 16, MainMenu.INK, maxf(1.0, 3.0 * s), true)
			draw.draw_rect(b, MainMenu.INK, false, maxf(1.0, 3.0 * s))
			_state(bold, "Занято", tx, cy, s, MainMenu.INK)


func _state(font: Font, t: String, x: float, cy: float, s: float, col: Color) -> void:
	var px := Lobby.ROLE_PX * s
	draw.draw_string(font, Vector2(x, cy + Splash.CAP_H * px * 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px), col)


## Кнопка: kind "main" — главная (бирюзовая, тёмный текст), "plain" — панель с рамкой, "off" — погашенная.
func _button(font: Font, r: Rect2, label: String, s: float, kind: String, edge := MainMenu.EDGE) -> void:
	var sb: StyleBoxFlat
	var col := MainMenu.INK
	match kind:
		"main":
			sb = _box(s, MainMenu.MAIN, Color.TRANSPARENT)
			col = MainMenu.DARK
		"off":
			sb = _box(s, Color(MainMenu.PANEL, 0.6), Color(MainMenu.EDGE, 0.6))
			col = MainMenu.OFF
		_:
			sb = _box(s, Color(MainMenu.PANEL, 0.92), edge)
	draw.draw_style_box(sb, r)
	var px := Lobby.BUTTON_PX * s
	draw.draw_string(font, Vector2(r.position.x, r.get_center().y + Splash.CAP_H * px * 0.5), label,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, roundi(px), col)


func _box(s: float, fill: Color, edge: Color, border := 2.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(roundi(Lobby.RADIUS * s))
	sb.anti_aliasing = true
	sb.bg_color = fill
	if edge.a > 0.0:
		sb.set_border_width_all(maxi(1, roundi(border * s)))
		sb.border_color = edge
	return sb


## Строка: at — левый край и верх видимых глифов на экране.
func _text(font: Font, text: String, at: Vector2, px: float, color: Color) -> void:
	draw.draw_string(font, at + Vector2(0.0, Splash.CAP_H * px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px), color)
