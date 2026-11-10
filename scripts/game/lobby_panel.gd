class_name LobbyPanel
extends CanvasLayer
## Экран сбора экипажа ART-028 (`Lobby`) поверх затемнённой сцены мостика: вход — поиск забегов (строки найденных,
## «Создать забег», «По адресу», «Обновить список»); комната — заголовок, подзаголовок, «Создать забег»
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
	UiStyle.cover(self, Lobby.DIM)
	draw = UiStyle.canvas(self, "Строки", _draw_screen)
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
	if lobby.entry:
		_entry(font, size, s)
		return
	if lobby.shows_address():
		_host_top(font, size, s)
	else:
		UiStyle.text(draw, bold, Lobby.TITLE, Lobby.to_screen(Lobby.TITLE_AT, size), Lobby.TITLE_PX * s, MainMenu.INK)
		UiStyle.text(draw, font, lobby.subtitle(), Lobby.to_screen(Lobby.SUB_AT, size), Lobby.SUB_PX * s, MainMenu.SOFT)
		draw.draw_line(Lobby.to_screen(Vector2(Lobby.TITLE_AT.x, Lobby.RULE_Y), size),
			Lobby.to_screen(Vector2(Lobby.SEARCH.end.x, Lobby.RULE_Y), size), Color(MainMenu.EDGE, 0.8), maxf(1.0, 2.0 * s))
		_button(bold, Lobby.screen_rect("create", size), "Создать забег", s, "off")
		_button(bold, Lobby.screen_rect("search", size), "Подключиться", s, "off")
		if lobby.lost:
			_lost(font, size, s)
			return
		UiStyle.text(draw, font, lobby.head(), Lobby.to_screen(Lobby.HEAD_AT, size), Lobby.SMALL_PX * s, MainMenu.SOFT)
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
		UiStyle.label(draw, font, lobby.start_text(), r, px, MainMenu.SOFT)


## Карточка «Связь потеряна» (лист ART-028 «05»): заголовок, «Проверьте Wi-Fi…», «Готовность будет сброшена»,
## «Повторить» (главная; во время попытки — «Подключаемся…», погашена) и «К списку забегов».
func _lost(font: Font, size: Vector2, s: float) -> void:
	draw.draw_style_box(_box(s, MainMenu.DARK, MainMenu.SOFT, 3.0), Lobby.rect_to_screen(Lobby.LOST_BOX, size))
	UiStyle.text(draw, bold, Lobby.LOST_TITLE, Lobby.to_screen(Lobby.LOST_TITLE_AT, size), Lobby.LOST_TITLE_PX * s,
		MainMenu.INK)
	var lines := lobby.lost_lines()
	for i in lines.size():
		UiStyle.text(draw, font, lines[i], Lobby.to_screen(Lobby.LOST_LINE_AT + Vector2(0.0, Lobby.LOST_LINE_STEP * i),
			size), Lobby.LOST_LINE_PX * s, MainMenu.INK)
	_button(bold, lobby.rect("retry", size), lobby.retry_text(), s, "main" if lobby.enabled("retry") else "off")
	_button(bold, lobby.rect("tolist", size), "К списку забегов", s, "plain")


## Вход по «Экипаж» — поиск забегов (лист ART-028): найденные забеги строками с «Подключиться», пусто — «Ищем
## забеги…» / «Никого нет» с пояснением; внизу «Создать забег», «По адресу», «Обновить список».
func _entry(font: Font, size: Vector2, s: float) -> void:
	UiStyle.text(draw, bold, Lobby.TITLE, Lobby.to_screen(Lobby.TITLE_AT, size), Lobby.TITLE_PX * s, MainMenu.INK)
	UiStyle.text(draw, font, lobby.entry_sub(), Lobby.to_screen(Lobby.SUB_AT, size), Lobby.SUB_PX * s, MainMenu.SOFT)
	draw.draw_line(Lobby.to_screen(Vector2(Lobby.TITLE_AT.x, Lobby.RULE_Y), size),
		Lobby.to_screen(Vector2(Lobby.SEARCH.end.x, Lobby.RULE_Y), size), Color(MainMenu.EDGE, 0.8), maxf(1.0, 2.0 * s))
	var busy := lobby.joining >= 0
	_button(bold, lobby.rect("create", size), "Создать забег", s, "off" if busy else "plain")
	_button(bold, lobby.rect("search", size), "Подключиться", s, "off" if busy else "main")
	var n := lobby.shown_runs()
	if n == 0:
		_centered(bold, lobby.entry_head(), Lobby.ENTRY_HEAD_Y, Lobby.TITLE_PX * s, MainMenu.INK, size)
		for i in Lobby.ENTRY_LINES.size():
			_centered(font, Lobby.ENTRY_LINES[i], Lobby.ENTRY_LINE_Y + Lobby.ENTRY_LINE_STEP * i, 32.0 * s, MainMenu.INK,
				size)
	else:
		var hr := Lobby.rect_to_screen(Rect2(Lobby.RUN_ROW.position.x, Lobby.LIST_HEAD_AT.y - 14.0, 760.0, 62.0), size)
		draw.draw_rect(hr, Color(MainMenu.DARK, 0.78))   # заголовок не теряется на табло тревог за окном
		UiStyle.text(draw, bold, lobby.entry_head(), Lobby.to_screen(Lobby.LIST_HEAD_AT, size), Lobby.ROLE_PX * s,
			MainMenu.INK)
		for i in n:
			_run_row(font, i, size, s)
		if n < Lobby.RUN_ROWS:
			var y := Lobby.run_rect(n).position.y + 30.0
			UiStyle.text(draw, font, Lobby.LIST_NOTE, Lobby.to_screen(Vector2(Lobby.LIST_HEAD_AT.x, y), size), 30.0 * s,
				MainMenu.SOFT)
	# пока список пуст, главное действие — создать свой забег
	_button(bold, lobby.rect("new", size), "Создать забег", s, "off" if busy else ("main" if n == 0 else "plain"))
	_button(bold, lobby.rect("address", size), "По адресу", s, "off" if busy else "plain")
	_button(bold, lobby.rect("refresh", size), "Обновить список", s, "off" if busy else "plain")


## Строка найденного забега: «Забег «Лена»», под ним «2 / 4 · свободны И / Б», справа «Подключиться».
func _run_row(font: Font, i: int, size: Vector2, s: float) -> void:
	var run: RunBeacon.Found = lobby.runs[i]
	var r := Lobby.rect_to_screen(Lobby.run_rect(i), size)
	var own := i == lobby.joining
	draw.draw_style_box(_box(s, MainMenu.PANEL, MainMenu.MAIN if own else MainMenu.EDGE, 3.0 if own else 2.0), r)
	var x := r.position.x + 40.0 * s
	var tpx := Lobby.RUN_TITLE_PX * s
	var lpx := Lobby.RUN_LINE_PX * s
	var w := (Lobby.JOIN.position.x - Lobby.RUN_ROW.position.x - 80.0) * s
	draw.draw_string(bold, Vector2(x, r.position.y + 22.0 * s + Splash.CAP_H * tpx), run.title(),
		HORIZONTAL_ALIGNMENT_LEFT, w, roundi(tpx), MainMenu.INK)
	draw.draw_string(font, Vector2(x, r.position.y + 74.0 * s + Splash.CAP_H * lpx), run.line(),
		HORIZONTAL_ALIGNMENT_LEFT, w, roundi(lpx), MainMenu.SOFT)
	var id := "join%d" % i
	var on := lobby.enabled(id)
	_button(bold, lobby.rect(id, size), lobby.join_text(i), s, "plain" if on else ("main" if own else "off"),
		MainMenu.MAIN)


## Строка по оси входа `Lobby.ENTRY_CX`, cy — центр строки в макете.
func _centered(font: Font, t: String, cy: float, px: float, col: Color, size: Vector2) -> void:
	var c := Lobby.to_screen(Vector2(Lobby.ENTRY_CX, cy), size)
	var w := 1600.0 * Lobby.scale(size)
	draw.draw_string(font, Vector2(c.x - w * 0.5, c.y + Splash.CAP_H * px * 0.5), t, HORIZONTAL_ALIGNMENT_CENTER, w,
		roundi(px), col)


## Верх хоста по ART-039: заголовок, «Назад», плашка «Ваш адрес: 192.168.43.17 · Скажите его товарищам».
func _host_top(font: Font, size: Vector2, s: float) -> void:
	UiStyle.text(draw, bold, Lobby.TITLE, Lobby.to_screen(Lobby.HOST_TITLE_AT, size), Lobby.TITLE_PX * s, MainMenu.INK)
	_button(bold, lobby.rect("leave", size), "Назад", s, "plain")
	draw.draw_style_box(_box(s, MainMenu.PANEL, MainMenu.EDGE), Lobby.rect_to_screen(Lobby.ADDR, size))
	UiStyle.text(draw, font, "Ваш адрес:", Lobby.to_screen(Lobby.ADDR_LABEL_AT, size), Lobby.ADDR_LABEL_PX * s,
		MainMenu.SOFT)
	var has := lobby.address != ""
	UiStyle.text(draw, font, lobby.address_text(), Lobby.to_screen(Lobby.ADDR_AT, size), Lobby.ADDR_PX * s,
		MainMenu.MAIN if has else MainMenu.INK)
	UiStyle.text(draw, font, lobby.address_hint(), Lobby.to_screen(Lobby.ADDR_HINT_AT, size), Lobby.ADDR_HINT_PX * s,
		MainMenu.SOFT)


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
	UiStyle.label(draw, font, label, r, px, col)


func _box(s: float, fill: Color, edge: Color, border := 2.0) -> StyleBoxFlat:
	return UiStyle.box(fill, Lobby.RADIUS * s, edge, border * s if edge.a > 0.0 else 0.0)
