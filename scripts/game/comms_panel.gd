class_name CommsPanel
extends Control
## Плашка внутренней связи ART-040 внизу по центру (состояние, строки и места — `Comms`). Касания идут через
## `Touch.Router.taps`/`blocks` (`Main._comms_step`), сам узел их не ловит. Палитра ART-028/040: заливка #0B1C24,
## контур #67DDEB, текст #D5E4E8/#9AD9E8, неактивное #6E909A, кнопка #102B37 с контуром #32616D. Красного и янтаря нет.

const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
const OFF := UiStyle.OFF
const ACCENT := UiStyle.ACCENT
const DARK := UiStyle.DARK
const BUTTON := Color("102B37")
const BUTTON_EDGE := Color("32616D")
const GLYPH_TOP := 0.76   ## от верха видимых глифов до базовой линии, доля кегля (DejaVu Sans)

var comms: Comms
var time := 0.0
var area := Rect2()  ## безопасная область экрана (`Main.comms_area`): места `Comms` считаются от неё (#603)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_comms(c: Comms, t: float, at: Rect2 = Rect2()) -> void:
	comms = c
	time = t
	area = at
	var vis := c != null and c.cur != null and c.a > 0.0
	if vis != visible:
		visible = vis
	if vis:
		queue_redraw()


func _box(r: Rect2, s: float, a: float, fill: Color, border: Color, radius := 12.0) -> void:
	draw_style_box(UiStyle.box(Color(fill, fill.a * a), radius * s, Color(border, border.a * a), 2.0 * s), r)


## Строка от верха видимых глифов.
func _text(font: Font, top: Vector2, text: String, px: int, color: Color, width := -1.0) -> void:
	draw_string(font, top + Vector2(0, px * GLYPH_TOP), text, HORIZONTAL_ALIGNMENT_LEFT, width, px, color)


func _draw() -> void:
	if comms == null or comms.cur == null:
		return
	var size := area.size if area.has_area() else get_viewport_rect().size
	draw_set_transform(area.position if area.has_area() else Vector2.ZERO)
	var s := Comms.scale(size)
	var a := comms.a
	var font := get_theme_default_font()
	var plate := Comms.plate_rect(size)
	_box(plate, s, a, DARK, ACCENT)
	# кружок роли с буквой: цвет роли сам ничего не значит, буква и название обязательны
	var c := Comms.at(Comms.CIRCLE, size)
	var ring: Color = Comms.ROLE_RING[comms.cur.role]
	draw_arc(c, Comms.CIRCLE_D * 0.5 * s, 0.0, TAU, 64, Color(ring, a), maxf(1.5, 2.5 * s), true)
	var lpx := int(Comms.LETTER_PX * s)
	var letter: String = Comms.LETTERS[comms.cur.role]
	var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
	draw_string(font, c + Vector2(-lw * 0.5, lpx * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, Color(TEXT, a))
	var title_px := int(Comms.ROLE_PX * s)
	_text(font, Comms.at(Comms.ROLE_AT, size), comms.title(), title_px, Color(TEXT, a))
	if comms.sub_wanted(size):
		var tw := font.get_string_size(comms.title(), HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x
		var sub := Comms.at(Comms.SUB_AT, size)
		sub.x = maxf(sub.x, Comms.at(Comms.ROLE_AT, size).x + tw + 24.0 * s)
		_text(font, sub, Comms.SUB, int(Comms.SUB_PX * s), Color(DIM, a))
	# команда: не шире места до индикатора и кнопки (длинную реплику сокращает редактор, кегль не меньше)
	var tx := Comms.at(Comms.TEXT_AT, size)
	_text(font, tx, comms.line(), int(Comms.TEXT_PX * s), Color(TEXT, a), plate.end.x - tx.x - 30.0 * s)
	# индикатор речи: 11 штрихов по центру строки
	var bars := Comms.bars_rect(size)
	var hs := comms.bars(time)
	var step := bars.size.x / float(hs.size())
	var bw := maxf(1.5, 3.0 * s)
	for i in hs.size():
		var h: float = bars.size.y * hs[i]
		var x := bars.position.x + step * (i + 0.5)
		var cy := bars.get_center().y
		draw_line(Vector2(x, cy - h * 0.5), Vector2(x, cy + h * 0.5), Color(DIM, a), bw)
	# нижняя строка: код / ход проверки; «Код совпал» — с галочкой под строкой
	var code_px := int(Comms.CODE_PX * s)
	var cp := Comms.code_at(size)
	var line_color := OFF if comms.state == Comms.Ask.WAIT else DIM
	_text(font, cp, comms.code_line(), code_px, Color(line_color, a))
	if comms.state == Comms.Ask.MATCH:
		var o := cp + Vector2(4.0 * s, code_px * 1.25)
		draw_polyline(PackedVector2Array([o, o + Vector2(10, 10) * s, o + Vector2(28, -10) * s]), Color(ACCENT, a),
			maxf(2.0, 3.0 * s), true)
	# кнопка: «Спросить код», «Проверяем», «Проверено», «Код не совпал» — тёмная; «Понятно» — акцент
	var b := Comms.button_rect(size)
	var bpx := int(Comms.BUTTON_PX * s)
	var label := comms.button_text()
	var label_color := TEXT
	if comms.state == Comms.Ask.EXPOSED:
		_box(b, s, a, ACCENT, ACCENT, 10.0)
		label_color = DARK
	else:
		_box(b, s, a, BUTTON, BUTTON_EDGE, 10.0)
		if not comms.button_live():
			label_color = OFF
	draw_string(font, Vector2(b.position.x, b.get_center().y + bpx * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER,
		b.size.x, bpx, Color(label_color, a))
