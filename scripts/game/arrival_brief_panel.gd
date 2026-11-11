class_name ArrivalBriefPanel
extends Control
## Плашка брифинга прибытия (#827, TXT-001 §1): подпись источника, одна-две строки экрана, номер и «Коснитесь экрана —
## дальше». Состояние, строки и места — `ArrivalBrief`; касания — `Touch.Router.taps` (`OverlayFlow.brief_step`), сам
## узел их не ловит. Палитра ART-028/040: заливка #0B1C24, контур #67DDEB, текст #D5E4E8/#9AD9E8.

const FILL := 1.0   ## заливка глухая: табло тревог ART-025 под плашкой не угадывается (#1429, решение UX 09.11)
const GLYPH_TOP := 0.76   ## от верха видимых глифов до базовой линии, доля кегля (DejaVu Sans)

var brief: ArrivalBrief
var warming := false   ## прогрев (`warm`): кегли панели под шторкой вместо неё


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_brief(b: ArrivalBrief) -> void:
	brief = b
	var vis := b != null and b.shown()
	if vis != visible:
		visible = vis
	if vis:
		queue_redraw()


## Кегль строки px, но не шире width (длинная строка ужимается, а не уходит за плашку).
static func fit_px(font: Font, t: String, px: int, width: float) -> int:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if w <= width or w <= 0.0:
		return px
	return maxi(8, int(floor(px * width / w)))


func _text(font: Font, top: Vector2, t: String, px: int, color: Color) -> void:
	draw_string(font, top + Vector2(0, px * GLYPH_TOP), t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


## Прогрев (WarmRunner, #1350): под шторкой брифинг прибытия рисует буквы `UiStyle.GLYPHS` своими кеглями
## (`warm_sizes`) вместо себя — первый показ не растрирует глифы вне шага (#519, «узлы»). on = false — скрыта до
## своего показа.
func warm(on: bool) -> void:
	warming = on
	visible = on
	queue_redraw()


## Кегли панели, px — из её `_draw`.
func warm_sizes() -> Array[int]:
	return UiStyle.warm_px([ArrivalBrief.SOURCE_PX, ArrivalBrief.LINE_PX, ArrivalBrief.FOOT_PX],
		ArrivalBrief.scale(get_viewport_rect().size))


func _draw() -> void:
	if warming:
		UiStyle.warm_glyphs(self, [get_theme_default_font()], warm_sizes())
		return
	if brief == null or not brief.active():
		return
	var size := get_viewport_rect().size
	var s := ArrivalBrief.scale(size)
	var a := brief.a
	var font := get_theme_default_font()
	var plate := ArrivalBrief.box(size)
	draw_style_box(UiStyle.box(Color(UiStyle.DARK, FILL * a), 14.0 * s, Color(UiStyle.ACCENT, a), 2.0 * s), plate)
	var width := plate.size.x - 2.0 * ArrivalBrief.LINE1_AT.x * s
	_text(font, ArrivalBrief.at(ArrivalBrief.SOURCE_AT, size), ArrivalBrief.SOURCE, int(ArrivalBrief.SOURCE_PX * s),
		Color(UiStyle.DIM, a))
	var l1 := ArrivalBrief.line(brief.screen, 0)
	var l2 := ArrivalBrief.line(brief.screen, 1)
	var px := int(ArrivalBrief.LINE_PX * s)
	px = mini(fit_px(font, l1, px, width), fit_px(font, l2, px, width)) if l2 != "" else fit_px(font, l1, px, width)
	_text(font, ArrivalBrief.at(ArrivalBrief.LINE1_AT, size), l1, px, Color(UiStyle.TEXT, a))
	if l2 != "":
		_text(font, ArrivalBrief.at(ArrivalBrief.LINE2_AT, size), l2, px, Color(UiStyle.TEXT, a))
	_text(font, ArrivalBrief.at(ArrivalBrief.FOOT_AT, size), brief.footer(), int(ArrivalBrief.FOOT_PX * s),
		Color(UiStyle.OFF if brief.t < ArrivalBrief.MIN_SHOW else UiStyle.DIM, a))
