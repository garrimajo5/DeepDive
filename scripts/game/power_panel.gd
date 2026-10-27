class_name PowerPanel
extends Control
## Пульт энергии на экране по ART-050 (`PowerScreen`: место, строки, состояния): пять систем с долями 0…60,
## выбранная — рамкой, полосой слева и жирным именем, внизу резерв, перегрев янтарём или аварийный сброс.
## Открыт, пока игрок у пульта энергии (Main.at_power). Строки не сенсорные: управление — крестовина и «Закрыть».

var reactor: Reactor
var panel: Reactor.Console
## Раскладка кнопок (Touch.Layout): панель встаёт ниже кнопки noclip и выше кнопки действия (#349). null — без неё.
var layout: Touch.Layout
var bold: FontVariation


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_for(r: Reactor, p: Reactor.Console) -> void:
	reactor = r
	panel = p
	visible = true
	queue_redraw()


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


## Прямоугольник панели на экране (`PowerScreen.box`).
func box() -> Rect2:
	return PowerScreen.box(get_viewport_rect().size, layout)


func _draw() -> void:
	if reactor == null:
		return
	var font := get_theme_default_font()
	if bold == null:
		bold = FontVariation.new()
		bold.base_font = font
		bold.variation_embolden = 0.7
	var b := box()
	var s := PowerScreen.k(b)
	var o := b.position
	var acc := PowerScreen.accent(reactor)
	draw_style_box(UiStyle.box(PowerScreen.BG, PowerScreen.RADIUS * s, acc if reactor.hot else PowerScreen.FRAME,
		2.0 * s), b)
	# шапка: значок инженера (белый круг «И» — профессия, не тревога), название, роль или перегрев
	var mark := o + Vector2(36.0, 30.0) * s
	draw_arc(mark, 15.0 * s, 0.0, TAU, 32, PowerScreen.INK, maxf(1.0, 2.0 * s), true)
	_text(bold, PowerScreen.MARK, mark + Vector2(0.0, -11.0) * s, 20.0 * s, PowerScreen.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_text(bold, PowerScreen.TITLE, o + Vector2(65.0, 12.0) * s, 30.0 * s, PowerScreen.INK)
	_text(bold, PowerScreen.head_right(reactor), o + Vector2(PowerScreen.VALUE_X, 17.0) * s, 23.0 * s,
		PowerScreen.HOT if reactor.hot else PowerScreen.SECOND, HORIZONTAL_ALIGNMENT_RIGHT)
	_line(o, PowerScreen.HEAD_LINE, s)
	for i in Reactor.Sys.size():
		_row(i, o, s, acc)
	_line(o, PowerScreen.FOOT_LINE, s)
	var f: Array = PowerScreen.foot(reactor)
	for j in 2:
		var l: Array = f[j]
		_text(bold if l[2] else font, l[0], o + Vector2(20.0, PowerScreen.FOOT_Y[j]) * s, l[1] * s, l[3])
	if f[2] != "":
		_text(font, f[2], o + Vector2(PowerScreen.STEP_X, PowerScreen.FOOT_Y[0] + 3.0) * s, 23.0 * s, PowerScreen.SECOND)


func _row(i: int, o: Vector2, s: float, acc: Color) -> void:
	var font := get_theme_default_font()
	var on := i == panel.sel
	var top := o.y + PowerScreen.row_top(i) * s
	var c := PowerScreen.row_colors(reactor, on)
	if on:
		draw_style_box(UiStyle.box(PowerScreen.SEL_FILL, 4.0 * s, acc, 2.0 * s), Rect2(o.x + 9.0 * s, top, (PowerScreen.W - 18.0) * s, PowerScreen.ROW_H * s))
		draw_rect(Rect2(o.x + 9.0 * s, top, 6.0 * s, PowerScreen.ROW_H * s), acc)
	var v := reactor.share[i]
	_text(bold if on else font, Reactor.NAMES[i], Vector2(o.x + 31.0 * s, top + 2.0 * s), 30.0 * s, c[0])
	_text(font, Reactor.HINTS[i], Vector2(o.x + 32.0 * s, top + 32.0 * s), 23.0 * s, c[1])
	_text(bold, str(v), Vector2(o.x + PowerScreen.VALUE_X * s, top + 1.0 * s), 34.0 * s, c[2], HORIZONTAL_ALIGNMENT_RIGHT)
	var w := PowerScreen.word(v)
	if w != "":
		_text(bold, w, Vector2(o.x + PowerScreen.WORD_X * s, top + 6.0 * s), 21.0 * s, c[1])
	var x0 := o.x + PowerScreen.BAR_X.x * s
	var span := (PowerScreen.BAR_X.y - PowerScreen.BAR_X.x) * s
	var y0 := top + PowerScreen.BAR_Y.x * s
	var h := (PowerScreen.BAR_Y.y - PowerScreen.BAR_Y.x) * s
	var gap := 3.0 * s
	for seg in PowerScreen.segments(v):
		var a := x0 + seg.x * span + (gap if seg.x > 0.0 else 0.0)
		var e := x0 + seg.y * span
		draw_rect(Rect2(a, y0, e - a, h), c[4])
		var f := x0 + seg.z * span
		if f > a:
			draw_rect(Rect2(a, y0, f - a, h), c[3])


func _line(o: Vector2, y: float, s: float) -> void:
	draw_line(o + Vector2(16.0, y) * s, o + Vector2(PowerScreen.W - 16.0, y) * s, PowerScreen.FRAME, maxf(1.0, s))


## Текст по верху строки (как в макете), кегль px; выравнивание — от точки at по x.
func _text(font: Font, t: String, at: Vector2, px: float, c: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var size := maxi(8, roundi(px))
	var x := at.x
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	draw_string(font, Vector2(x, at.y + font.get_ascent(size)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
