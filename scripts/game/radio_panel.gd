class_name RadioPanel
extends Control
## Рация ART-041 (состояние, строки и места — `Radio`): кнопка «Говорить» над «Светом», строка своего состояния,
## список говорящих справа сверху, просьба «Разрешите микрофон» / «В настройки». Касания — через
## `Touch.Router.held_in`/`blocks`/`taps` (`Main._radio_step`), сам узел их не ловит. Палитра ART-028: заливка #0B1C24,
## контур #67DDEB, текст #D5E4E8, неактивное #6E909A; «Вас слышно» — светлая кнопка #67DDEB с тёмной подписью.
## Ничего красного.

const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
const OFF := UiStyle.OFF
const ACCENT := UiStyle.ACCENT
const DARK := UiStyle.DARK
const EDGE := Color("32616D")
const GLYPH_TOP := 0.76   ## от верха видимых глифов до базовой линии, доля кегля (DejaVu Sans)

var radio: Radio
var time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_radio(r: Radio, t: float) -> void:
	radio = r
	time = t
	var vis := r != null and not r.hidden
	if vis != visible:
		visible = vis
	if vis:
		queue_redraw()


func _box(r: Rect2, s: float, fill: Color, border: Color, radius := 12.0) -> void:
	draw_style_box(UiStyle.box(fill, radius * s, border, 2.0 * s), r)


func _text(font: Font, top: Vector2, text: String, px: int, color: Color, width := -1.0) -> void:
	draw_string(font, top + Vector2(0, px * GLYPH_TOP), text, HORIZONTAL_ALIGNMENT_LEFT, width, px, color)


## Значок микрофона: капсула, дуга подставки, ножка; `crossed` — перечёркнут (нет доступа).
func _mic(c: Vector2, s: float, color: Color, crossed: bool) -> void:
	var w := maxf(1.5, 3.0 * s)
	var cap := Rect2(c + Vector2(-9, -26) * s, Vector2(18, 32) * s)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = color
	sb.set_border_width_all(roundi(w))
	sb.set_corner_radius_all(roundi(9.0 * s))
	draw_style_box(sb, cap)
	draw_arc(c + Vector2(0, -6) * s, 16.0 * s, 0.15, PI - 0.15, 16, color, w, true)
	draw_line(c + Vector2(0, 10) * s, c + Vector2(0, 22) * s, color, w, true)
	draw_line(c + Vector2(-10, 22) * s, c + Vector2(10, 22) * s, color, w, true)
	if crossed:
		draw_line(c + Vector2(-18, -26) * s, c + Vector2(18, 24) * s, color, w, true)


func _draw() -> void:
	if radio == null or radio.hidden:
		return
	var size := get_viewport_rect().size
	var s := Radio.scale(size)
	var font := get_theme_default_font()
	# строка состояния
	var st := Radio.state_rect(size)
	_box(st, s, Color(DARK, 0.86), EDGE, 8.0)
	var spx := int(Radio.STATE_PX * s)
	_text(font, st.position + Vector2(14.0 * s, (st.size.y - spx) * 0.5), radio.state_text(), spx,
		TEXT if radio.mic else OFF)
	# кнопка: светлая — только когда голос реально уходит
	var b := Radio.button_rect(size)
	var lit := radio.sending()
	_box(b, s, ACCENT if lit else Color(DARK, 0.9), ACCENT if radio.mic else EDGE, 12.0)
	var ink := DARK if lit else (TEXT if radio.mic else OFF)
	_mic(b.position + Vector2(58.0 * s, b.size.y * 0.5 + 2.0 * s), s, ink, not radio.mic)
	var bpx := int(Radio.BUTTON_PX * s)
	draw_string(font, Vector2(b.position.x + 100.0 * s, b.get_center().y + bpx * 0.36), radio.button_text(),
		HORIZONTAL_ALIGNMENT_LEFT, b.size.x - 110.0 * s, bpx, ink)
	# просьба разрешения
	if radio.ask > 0.0:
		var ar := Radio.ask_rect(size)
		_box(ar, s, Color(DARK, 0.86), EDGE, 12.0)
		_text(font, ar.position + Vector2(20.0 * s, 8.0 * s), Radio.ASK_TEXT, int(Radio.STATE_PX * s), TEXT)
		var ab := Radio.ask_button_rect(size)
		_box(ab, s, Color(DARK, 0.92), ACCENT, 10.0)
		var apx := int(Radio.STATE_PX * s)
		draw_string(font, Vector2(ab.position.x, ab.get_center().y + apx * 0.36), Radio.ASK_BUTTON,
			HORIZONTAL_ALIGNMENT_CENTER, ab.size.x, apx, TEXT)
	# список говорящих
	var rows := radio.rows()
	if rows.is_empty():
		return
	var head_a: float = rows[0].a
	_text(font, Radio.head_at(size), Radio.HEAD, int(Radio.HEAD_PX * s), Color(DIM, head_a))
	for i in rows.size():
		var t: Radio.Talker = rows[i]
		var r := Radio.row_rect(i, size)
		draw_style_box(UiStyle.box(Color(DARK, 0.88 * t.a), 12.0 * s, Color(ACCENT, t.a), 2.0 * s), r)
		var c := r.position + Vector2(40.0 * s, r.size.y * 0.5)
		draw_arc(c, 24.0 * s, 0.0, TAU, 48, Color(TEXT, t.a), maxf(1.5, 2.0 * s), true)
		var lpx := int(Radio.LETTER_PX * s)
		var letter: String = Radio.LETTERS[clampi(t.role, 0, 3)]
		var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
		draw_string(font, c + Vector2(-lw * 0.5, lpx * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx,
			Color(TEXT, t.a))
		var npx := int(Radio.NAME_PX * s)
		var ny := c.y + npx * 0.36 - (12.0 * s if not t.seen else 0.0)
		draw_string(font, Vector2(r.position.x + 80.0 * s, ny), t.name, HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 150.0 * s, npx, Color(TEXT, t.a))
		if not t.seen:   # за стеной — табличку над фигурой не видно, в строке «Вне поля зрения»
			_text(font, Vector2(r.position.x + 80.0 * s, c.y + 10.0 * s), Radio.OUT_OF_VIEW,
				int(Radio.SUB_PX * s), Color(DIM, t.a))
		var hs := Radio.bars(t, time)
		var bw := maxf(1.5, 3.0 * s)
		for k in hs.size():
			var h: float = 34.0 * s * hs[k]
			var x := r.end.x - 48.0 * s + k * 10.0 * s
			draw_line(Vector2(x, c.y - h * 0.5), Vector2(x, c.y + h * 0.5), Color(ACCENT, t.a), bw)
