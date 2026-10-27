class_name JournalPanel
extends CanvasLayer
## «Журнал экспедиции» ART-047 на фоне заставки (`main.journal_panel`): заголовок, «Назад», карта отмели с иконками
## мест (посещённое — контур #67DDEB и галочка), сводка, строки под картой, сетка видов 3×2 с «?» и «новое», «Ранее» /
## «Далее», карточка вида поверх; пустой журнал — одна строка. Рисунков видов пока нет — в карточке на месте картинки
## описание вида (`Species.Info.desc`). Состояние и
## места — `Journal`, история — `Expedition`. Слой над главным меню (его 90), ниже заставки прогрева (100); касания —
## `Touch.Router.taps` (`Main._journal_step`).

const DIM := 0.7   ## затемнение фона: текст читается на любом месте

var journal: Journal
var expedition: Expedition
var species_n := 0
var scanner: Scanner
var species_total := 0
var cargo_n := 0
var broken := false
var draw: Control
var _icons := {}


func _init() -> void:
	name = "Журнал экспедиции"
	layer = 91
	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.color = Journal.DARK
	add_child(dark)
	var bg := TextureRect.new()
	bg.name = "Фон"
	bg.texture = load(Splash.BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(Journal.DARK, DIM)
	add_child(dim)
	draw = Control.new()
	draw.name = "Страница"
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_page)
	add_child(draw)


func show_journal(j: Journal, e: Expedition, sc: Scanner, total: int, cargo: int, was_broken: bool) -> void:
	journal = j
	expedition = e
	scanner = sc
	species_n = sc.scanned.size() if sc else 0
	species_total = total
	cargo_n = cargo
	broken = was_broken
	visible = j != null and j.open
	if visible:
		draw.queue_redraw()


func _icon(path: String) -> Texture2D:
	if path == "":
		return null
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path]


func _box(r: Rect2, s: float, edge: Color, width: float, fill := Color(Journal.PANEL, 0.92)) -> void:
	draw.draw_style_box(UiStyle.box(fill, 12.0 * s, edge, width * s), r)


## Строка: at — левый край и верх видимых глифов на экране.
func _text(font: Font, text: String, at: Vector2, px: float, color: Color, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw.draw_string(font, at + Vector2(0.0, Splash.CAP_H * px), text, align, width, roundi(px), color)


func _draw_page() -> void:
	if journal == null or expedition == null:
		return
	var size := draw.get_viewport_rect().size
	var s := Journal.scale(size)
	var l := Journal.left(size) * s
	var font := draw.get_theme_default_font()
	_text(font, Journal.TITLE, Vector2(l, Journal.TITLE_AT.y * s), Journal.TITLE_PX * s, Journal.INK)
	var back := Journal.back_rect(size)
	_box(back, s, Journal.EDGE, 2.0)
	var bpx := Journal.LABEL_PX * s
	_text(font, "Назад", Vector2(back.position.x, back.get_center().y - Splash.CAP_H * bpx * 0.5), bpx, Journal.INK,
		back.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if broken:
		_text(font, Journal.BROKEN_LINE, Vector2(l, 150.0 * s), 28.0 * s, Journal.SOFT)
	if Journal.empty(expedition, species_n, cargo_n):
		_text(font, Journal.EMPTY_LINE, Vector2(0.0, 480.0 * s), 38.0 * s, Journal.INK, size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		return
	_draw_map(font, size, s, l)
	var r := l + Journal.RIGHT * s
	var rows := Journal.summary(expedition, species_n, cargo_n, species_total)
	for i in rows.size():
		var top := (Journal.SUMMARY_AT.y + Journal.SUMMARY_STEP * i) * s
		var tex := _icon(rows[i][0])
		var px := Journal.SUMMARY_PX * s
		if tex:
			var side := Journal.SUMMARY_ICON * s
			draw.draw_texture_rect(tex, Rect2(r, top + Splash.CAP_H * px * 0.5 - side * 0.5, side, side), false)
		_text(font, rows[i][1], Vector2(r + Journal.SUMMARY_AT.x * s, top), px, Journal.INK)
	var foot := journal.footer(expedition)
	for i in foot.size():
		_text(font, foot[i][0], Vector2(l + Journal.FOOT_AT.x * s, (Journal.FOOT_AT.y + Journal.FOOT_STEP[i]) * s),
			Journal.FOOT_PX[i] * s, foot[i][1])
	_draw_grid(font, size, s, r)
	if journal.card != "" and scanner:
		_draw_card(font, size, s)


## Кнопка с подписью по центру; off — погашена (на краю страниц).
func _button(font: Font, rect: Rect2, s: float, label: String, off := false) -> void:
	_box(rect, s, Color(Journal.EDGE, 0.5) if off else Journal.EDGE, 2.0,
		Color(Journal.PANEL, 0.5 if off else 0.92))
	var px := Journal.LABEL_PX * s
	_text(font, label, Vector2(rect.position.x, rect.get_center().y - Splash.CAP_H * px * 0.5), px,
		Journal.OFF if off else Journal.INK, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Строка по центру прямоугольника по ширине, верх глифов — top; длинная сжимается до ширины.
func _fit(font: Font, text: String, rect: Rect2, top: float, px: float, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x
	var pad := rect.size.x * 0.06
	if w > rect.size.x - pad * 2.0:
		px *= (rect.size.x - pad * 2.0) / w
	_text(font, text, Vector2(rect.position.x, top), px, color, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_grid(font: Font, size: Vector2, s: float, r: float) -> void:
	_text(font, Journal.grid_title(journal.page), Vector2(r, Journal.GRID_TITLE_TOP * s), Journal.GRID_TITLE_PX * s,
		Journal.SOFT)
	var scanned: Dictionary = scanner.scanned if scanner else {}
	var ids := Journal.page_ids(journal.page)
	for i in ids.size():
		var id: String = ids[i]
		var c := Journal.cell_rect(i, size)
		var known := scanned.has(id)
		_box(c, s, Journal.MAIN if known else Journal.EDGE, 3.0 if known else 2.0)
		if known:
			var info := Species.info(id)
			_fit(font, info.name, c, c.get_center().y - Splash.CAP_H * Journal.CELL_NAME_PX * s * 0.5 + 10.0 * s,
				Journal.CELL_NAME_PX * s, Journal.INK)
			if expedition.is_new(id, scanned.keys()):
				var b := Rect2(c.end.x - (Journal.NEW_BADGE.x + 8.0) * s, c.position.y + 8.0 * s,
					Journal.NEW_BADGE.x * s, Journal.NEW_BADGE.y * s)
				_box(b, s, Journal.MAIN, 1.0, Journal.MAIN)
				var bpx := 24.0 * s
				_text(font, Journal.NEW_TEXT, Vector2(b.position.x, b.get_center().y - Splash.CAP_H * bpx * 0.5), bpx,
					Journal.DARK, b.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		elif journal.asked == id:
			_fit(font, Journal.CELL_HINT[0], c, c.position.y + 46.0 * s, Journal.CELL_NAME_PX * s, Journal.SOFT)
			_fit(font, Journal.CELL_HINT[1], c, c.position.y + 90.0 * s, Journal.CELL_NAME_PX * s, Journal.SOFT)
		else:
			_text(font, "?", Vector2(c.position.x, c.position.y + 30.0 * s), Journal.CELL_ASK_PX * s, Journal.OFF,
				c.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_fit(font, Journal.CELL_OFF, c, c.end.y - 48.0 * s, Journal.CELL_NAME_PX * s, Journal.OFF)
	_button(font, Journal.prev_rect(size), s, "Ранее", journal.page <= 0)
	_button(font, Journal.next_rect(size), s, "Далее", journal.page >= Journal.pages() - 1)
	var pc := Journal.page_center(size)
	var px := Journal.LABEL_PX * s
	_text(font, "%d / %d" % [journal.page + 1, Journal.pages()], Vector2(pc.x - 120.0 * s, pc.y - Splash.CAP_H * px * 0.5),
		px, Journal.INK, 240.0 * s, HORIZONTAL_ALIGNMENT_CENTER)


## Текст с переносом по словам; at — верх глифов первой строки. Возвращает верх следующего абзаца.
func _wrap(font: Font, text: String, at: Vector2, width: float, px: float, color: Color, gap: float) -> float:
	var para := TextParagraph.new()
	para.width = width
	para.add_string(text, font, roundi(px))
	var top := at.y
	for i in para.get_line_count():
		_text(font, text.substr(para.get_line_range(i).x, para.get_line_range(i).y - para.get_line_range(i).x).strip_edges(),
			Vector2(at.x, top), px, color)
		top += px * 1.35
	return top + gap


## Карточка вида поверх затемнённой страницы: строки `Lab.card_lines` — номер, имя, счёт наблюдений, последнее.
func _draw_card(font: Font, size: Vector2, s: float) -> void:
	draw.draw_rect(Rect2(Vector2.ZERO, size), Color(Journal.DARK, 0.6))
	var rect := Journal.card_rect(size)
	_box(rect, s, Journal.EDGE, 2.0, Color(Journal.PANEL, 0.98))
	var lines := Journal.card_text(scanner, journal.card)
	var o := rect.position
	_text(font, lines[0], o + Vector2(48, 48) * s, 24.0 * s, Journal.SOFT)
	_text(font, lines[1], o + Vector2(48, 100) * s, 44.0 * s, Journal.INK)
	var pic := Journal.in_card(Journal.CARD_PIC, size)   # рисунков видов нет — на месте картинки описание вида
	_wrap(font, Species.info(journal.card).desc, Vector2(pic.position.x, pic.position.y), pic.size.x, 28.0 * s,
		Journal.SOFT, 10.0 * s)
	var tx := o.x + Journal.CARD_TEXT.x * s
	var top := o.y + Journal.CARD_TEXT.y * s
	_text(font, lines[2], Vector2(tx, top), 32.0 * s, Journal.INK)
	top += 64.0 * s
	var notes := lines.slice(3)
	if not notes.is_empty() and not notes[0].begins_with("Наблюдения пишутся"):
		_text(font, Journal.CARD_LAST, Vector2(tx, top), 24.0 * s, Journal.SOFT)
		top += 44.0 * s
	for line in notes:
		top = _wrap(font, line, Vector2(tx, top), Journal.CARD_TEXT_W * s, 30.0 * s, Journal.INK, 12.0 * s)
	_button(font, Journal.close_rect(size), s, "Закрыть")


func _draw_map(font: Font, size: Vector2, s: float, l: float) -> void:
	var px := Journal.LABEL_PX * s
	_text(font, Journal.MAP_NAME, Vector2(l, Journal.MAP_NAME_TOP * s), px, Journal.INK)
	var map := Journal.map_rect(size)
	_text(font, Journal.NORTH, Vector2(map.position.x, Journal.MAP_NAME_TOP * s), 26.0 * s, Journal.SOFT,
		map.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	_box(map, s, Journal.EDGE, 2.0, Color(Journal.PANEL, 0.85))
	var grid := Color(Journal.EDGE, 0.35)   # сетка карты: 6 × 5 клеток
	for i in range(1, 6):
		var x := map.position.x + map.size.x * i / 6.0
		draw.draw_line(Vector2(x, map.position.y + 12.0 * s), Vector2(x, map.end.y - 12.0 * s), grid, maxf(1.0, 1.5 * s))
	for i in range(1, 5):
		var y := map.position.y + map.size.y * i / 5.0
		draw.draw_line(Vector2(map.position.x + 12.0 * s, y), Vector2(map.end.x - 12.0 * s, y), grid, maxf(1.0, 1.5 * s))
	for k: String in Run.PLACES:
		var b := Journal.place_rect(k, size)
		var seen := expedition.visited(k)
		var picked := journal.picked == k
		_box(b, s, Journal.MAIN if seen or picked else Journal.EDGE, 3.0 if seen or picked else 2.0,
			Color(Journal.DARK, 0.9))
		var tex := _icon(Briefing.icon_path(k))
		if tex:
			var side := Journal.PLACE_ICON * s
			draw.draw_texture_rect(tex, Rect2(b.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)), false,
				Color(1, 1, 1, 1.0 if seen else 0.55))
		if seen:   # галочка в правом нижнем углу кнопки
			var c := b.end - Vector2(18.0, 18.0) * s
			draw.draw_polyline(PackedVector2Array([c + Vector2(-8, 0) * s, c + Vector2(-3, 5) * s, c + Vector2(7, -6) * s]),
				Journal.MAIN, maxf(1.5, 2.5 * s), true)
