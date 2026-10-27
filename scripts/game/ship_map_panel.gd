class_name ShipMapPanel
extends CanvasLayer
## Схема корабля ART-042 поверх затемнённой живой сцены (`main.ship_map_panel`): отсеки, люки, значки постов,
## отметки экипажа, тревога янтарём, легенда и линейка. Раскладка и состояние — `ShipMap`, палитра — `MainMenu`.
## Слой как у паузы (её кнопки под схемой скрыты). Данные кадра ставит `Main._map_show` — `show_map`.

const LAYER := 90

var map: ShipMap
var marks: Array = []          ## [x, z, буква] каждого члена экипажа
var own := -1                  ## индекс своего в marks
var doors: Array[bool] = []    ## проходим ли люк i
var alarm: ShipMap.Alarm
var draw: Control
var atlas: Texture2D


func _init() -> void:
	name = "Схема корабля"
	layer = LAYER
	visible = false
	atlas = load(ShipMap.ATLAS)
	draw = Control.new()
	draw.name = "План"
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_map)
	add_child(draw)


func show_map(m: ShipMap, crew_marks: Array, own_index: int, door_open: Array[bool], a: ShipMap.Alarm) -> void:
	map = m
	marks = crew_marks
	own = own_index
	doors = door_open
	alarm = a
	visible = m != null and m.open
	if visible:
		draw.queue_redraw()


func _draw_map() -> void:
	if map == null:
		return
	var size := draw.get_viewport_rect().size
	var kk := ShipMap.k(size)
	var font := draw.get_theme_default_font()
	var x0 := ShipMap.plan_x0(size)
	var x1 := x0 + ShipMap.PLAN_M * ShipMap.plan_s(size)
	draw.draw_rect(Rect2(Vector2.ZERO, size), Color(MainMenu.DARK, ShipMap.DIM))
	_text(font, ShipMap.TITLE, Vector2(x0 + ShipMap.TITLE_AT.x, ShipMap.TITLE_AT.y) * kk, ShipMap.TITLE_PX * kk,
		MainMenu.INK, HORIZONTAL_ALIGNMENT_LEFT)
	_button(font, ShipMap.back_rect(size), ShipMap.BACK_TEXT, kk)
	# «← Нос · вид сверху» и «Корма →»: стрелки линиями.
	var ay := (ShipMap.ENDS_TOP + ShipMap.ENDS_PX * Splash.CAP_H * 0.5) * kk
	var nose_x := (x0 + ShipMap.TITLE_AT.x) * kk
	var stern_x := (x1 - ShipMap.TITLE_AT.x) * kk
	var aw := ShipMap.ARROW * kk
	_arrow(Vector2(nose_x + aw, ay), Vector2(nose_x, ay), kk)
	_arrow(Vector2(stern_x - aw, ay), Vector2(stern_x, ay), kk)
	_text(font, ShipMap.NOSE, Vector2(nose_x + aw + 10.0 * kk, ShipMap.ENDS_TOP * kk), ShipMap.ENDS_PX * kk,
		MainMenu.SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	_text(font, ShipMap.STERN, Vector2(stern_x - aw - 10.0 * kk, ShipMap.ENDS_TOP * kk), ShipMap.ENDS_PX * kk,
		MainMenu.SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	# Отсеки: заливка, контур, название над планом.
	for room in ShipMap.NAMES.size():
		var r := ShipMap.room_rect(room, size)
		draw.draw_rect(r, Color(MainMenu.PANEL, 0.92))
		draw.draw_rect(r, MainMenu.EDGE, false, maxf(1.0, ShipMap.EDGE * kk))
	for room in ShipMap.NAMES.size():
		var r := ShipMap.room_rect(room, size)
		var hot := alarm != null and alarm.room == room
		_text(font, ShipMap.NAMES[room], Vector2(r.get_center().x, ShipMap.NAMES_TOP * kk), ShipMap.NAMES_PX * kk,
			ShipMap.AMBER if hot else MainMenu.INK, HORIZONTAL_ALIGNMENT_CENTER)
	if alarm != null:
		draw.draw_rect(ShipMap.room_rect(alarm.room, size), ShipMap.AMBER, false, ShipMap.ALARM_EDGE * kk)
	# Люки: разрыв в переборке, голубые торцы; закрытый — светлая створка и «Люк закрыт».
	var tick := ShipMap.DOOR_TICK * 0.5 * ShipMap.plan_s(size) * kk
	var lw := maxf(1.0, 3.0 * kk)
	for i in ShipLayout.DOOR_Z.size():
		var d := ShipMap.door_rect(i, size)
		draw.draw_rect(d, MainMenu.DARK)
		var cx := d.get_center().x
		for y in [d.position.y, d.end.y]:
			draw.draw_line(Vector2(cx - tick, y), Vector2(cx + tick, y), ShipMap.ACCENT, lw)
		var open: bool = doors[i] if i < doors.size() else true
		if not open:
			draw.draw_line(Vector2(cx, d.position.y), Vector2(cx, d.end.y), MainMenu.INK, lw * 1.6)
	# Значки постов.
	for p: Array in ShipMap.posts():
		draw.draw_texture_rect_region(atlas, ShipMap.icon_rect(p[1], size), ShipMap.cell(p[0]), ShipMap.ICON_COLOR)
	# Тревога: рамка у места ремонта со значком, выноска и две строки янтарём.
	if alarm != null:
		var box := ShipMap.alarm_box(alarm, size)
		draw.draw_rect(box, Color(MainMenu.DARK, 0.85))
		draw.draw_rect(box, ShipMap.AMBER, false, lw)
		draw.draw_texture_rect_region(atlas, box.grow(-box.size.x * 0.15), ShipMap.cell(alarm.icon), ShipMap.AMBER)
		var at := ShipMap.alarm_label(alarm, size)
		var left := ShipMap.alarm_left(alarm)
		var align := HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_CENTER
		if left:
			draw.draw_line(Vector2(box.position.x, box.get_center().y), Vector2(at.x + 8.0 * kk, box.get_center().y),
				ShipMap.AMBER, lw * 0.7)
		else:
			draw.draw_line(Vector2(box.get_center().x, box.end.y), Vector2(at.x, at.y - 8.0 * kk), ShipMap.AMBER,
				lw * 0.7)
		for j in alarm.lines.size():
			var top := at.y + (0.0 if j == 0 else ShipMap.ALARM_STEP * kk)
			_text(font, alarm.lines[j], Vector2(at.x, top), ShipMap.ALARM_PX[mini(j, 1)] * kk, ShipMap.AMBER, align)
	# Подписи закрытых люков — поверх выноски тревоги, на тёмной плашке.
	for i in ShipLayout.DOOR_Z.size():
		if i < doors.size() and not doors[i]:
			var at := ShipMap.door_label(i, size)
			var px := ShipMap.DOOR_PX * kk
			var w := font.get_string_size(ShipMap.DOOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x + 16.0 * kk
			draw.draw_rect(Rect2(at.x - w * 0.5, at.y - 6.0 * kk, w, px + 6.0 * kk), MainMenu.DARK)
			_text(font, ShipMap.DOOR_TEXT, at, px, MainMenu.INK, HORIZONTAL_ALIGNMENT_CENTER)
	# Линейка 5 м под мостиком.
	var ru := ShipMap.ruler(size)
	draw.draw_line(ru[0], ru[1], ShipMap.ACCENT, lw * 0.7)
	for e: Vector2 in ru:
		draw.draw_line(e + Vector2(0, -8 * kk), e + Vector2(0, 8 * kk), ShipMap.ACCENT, lw * 0.7)
	_text(font, "5 м", (ru[0] + ru[1]) * 0.5 - Vector2(0, (ShipMap.RULER_PX + 10.0) * kk), ShipMap.RULER_PX * kk,
		MainMenu.SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	# Отметки экипажа: свой залит акцентом с «Вы здесь», товарищи тёмные с контуром.
	var pts: Array = []
	var letters: Array = []
	for m: Array in marks:
		pts.append(Vector2(m[0], m[1]))
		letters.append(m[2])
	var r0 := ShipMap.MARK * 0.5 * kk
	var ms := ShipMap.marks(pts, letters, own, size)
	if not ms.is_empty() and ms[0].own:
		ms.push_back(ms.pop_front())   # свой — поверх всех (#575)
	for m: ShipMap.Mark in ms:
		if m.pos != m.at:
			draw.draw_line(m.at, m.pos, MainMenu.SOFT, lw * 0.5)
			draw.draw_circle(m.at, 3.0 * kk, MainMenu.SOFT)
		if m.own:
			draw.draw_line(m.pos + Vector2(0, r0), m.pos + Vector2(0, r0 + ShipMap.HERE_LINE * kk), ShipMap.ACCENT, lw * 0.7)
			_text(font, ShipMap.HERE, m.pos + Vector2(0, r0 + (ShipMap.HERE_LINE + 12.0) * kk), ShipMap.HERE_PX * kk,
				ShipMap.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
			draw.draw_circle(m.pos, r0, ShipMap.ACCENT)
		else:
			draw.draw_circle(m.pos, r0, MainMenu.DARK)
			draw.draw_arc(m.pos, r0, 0.0, TAU, 40, MainMenu.INK, lw * 0.8, true)
		var px := ShipMap.MARK_PX * kk
		_text(font, m.letter, m.pos - Vector2(0, Splash.CAP_H * px * 0.5), px,
			MainMenu.DARK if m.own else MainMenu.INK, HORIZONTAL_ALIGNMENT_CENTER)
	# Легенда: две строки по четыре значка.
	for i in ShipMap.LEGEND.size():
		var c := ShipMap.legend_at(i, size)
		var w := ShipMap.ICON * kk
		draw.draw_texture_rect_region(atlas, Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)),
			ShipMap.cell(ShipMap.LEGEND[i][0]), ShipMap.ICON_COLOR)
		var px := ShipMap.LEGEND_PX * kk
		_text(font, ShipMap.LEGEND[i][1], c + Vector2(w * 0.5 + 18.0 * kk, -Splash.CAP_H * px * 0.5), px, MainMenu.INK,
			HORIZONTAL_ALIGNMENT_LEFT)


## Стрелка от a к b цветом подписей.
func _arrow(a: Vector2, b: Vector2, kk: float) -> void:
	var w := maxf(1.0, 2.5 * kk)
	var d := (b - a).normalized() * 9.0 * kk
	draw.draw_line(a, b, MainMenu.SOFT, w, true)
	draw.draw_line(b, b - d + d.orthogonal(), MainMenu.SOFT, w, true)
	draw.draw_line(b, b - d - d.orthogonal(), MainMenu.SOFT, w, true)


## Строка: p — точка выравнивания по x и верх видимых глифов по y.
func _text(font: Font, text: String, p: Vector2, px: float, color: Color, align: HorizontalAlignment) -> void:
	var w := 2000.0
	var x := p.x
	match align:
		HORIZONTAL_ALIGNMENT_CENTER:
			x -= w * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x -= w
	draw.draw_string(font, Vector2(x, p.y + Splash.CAP_H * px), text, align, w, roundi(px), color)


func _button(font: Font, r: Rect2, text: String, kk: float) -> void:
	draw.draw_style_box(UiStyle.menu_button(false, kk), r)
	var px := ShipMap.BACK_PX * kk
	var base := r.position.y + r.size.y * 0.5 + Splash.CAP_H * px * 0.5
	draw.draw_string(font, Vector2(r.position.x, base), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, roundi(px),
		MainMenu.INK)
