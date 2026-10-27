class_name RouteCard
extends Control
## Карточка выбранного маршрута над голостолом (ART-016): экранная надпись поверх 3D, привязанная к точке над краем
## карты брифинга (Briefing.CARD_ANCHOR). Название, места по порядку, риск янтарным. Кегль не уменьшается вместе
## со сценой: заголовок 26 px, строки 20 px; тёмная почти непрозрачная подложка, контур голограммы.
## Под маршрутом — страница «Связь» (ART-040): кодовое слово забега крупно, подсказка (`Briefing.code_lines`);
## маршрут не выбран — карточка только со словом.

const TEXT := UiStyle.TEXT
const DIM := UiStyle.DIM
const EDGE := Color("67DDEB")
const BACK := Color("0B1C24")
const TITLE_PX := 26
const LINE_PX := 20
const PAD := Vector2(18, 12)
const ROW := 28.0
## Страница «Связь»: заголовок, слово, подсказка, примечание — кегль и высота строки, px.
const CODE_PX: Array[int] = [20, 36, 20, 18]
const CODE_ROW: Array[float] = [28.0, 46.0, 28.0, 26.0]
const CODE_GAP := 14.0       ## от маршрута до черты и от черты до страницы «Связь», px

var lines: Array[String] = []   ## маршрут (Briefing.card_lines)
var code: Array[String] = []    ## страница «Связь» (Briefing.code_lines)
var alpha := 0.0
var rect := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## k — доля перехода брифинга (Briefing.Fade), route — Run.route, anchor — точка привязки в мире,
## word — кодовое слово забега (`Comms.code`; пусто — без страницы «Связь»).
func show_card(k: float, route: int, cam: Camera3D, anchor: Vector3, word := "") -> void:
	var l := Briefing.card_lines(route)
	var c := Briefing.code_lines(word)
	var on := k > 0.0 and not (l.is_empty() and c.is_empty()) and cam != null and not cam.is_position_behind(anchor)
	if not on:
		visible = false
		return
	var r := Briefing.card_rect(cam.unproject_position(anchor), card_size(l, c), get_viewport_rect().size)
	if visible and l == lines and c == code and r == rect and is_equal_approx(k, alpha):
		return
	lines = l
	code = c
	rect = r
	alpha = k
	visible = true
	queue_redraw()


## Высота строк маршрута, px (без полей).
func _route_h(l: Array[String]) -> float:
	return ROW * (l.size() + 0.4) if not l.is_empty() else 0.0


## Высота страницы «Связь» с чертой над ней (если есть маршрут), px.
func _code_h(c: Array[String], with_route: bool) -> float:
	if c.is_empty():
		return 0.0
	var h := CODE_GAP * 2.0 if with_route else 0.0
	for i in c.size():
		h += CODE_ROW[i]
	return h


## Размер подложки под строки: ширина — по самой длинной строке.
func card_size(l: Array[String], c: Array[String] = []) -> Vector2:
	var font := get_theme_default_font()
	var w := 0.0
	for i in l.size():
		w = maxf(w, font.get_string_size(l[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX if i == 0 else LINE_PX).x)
	for i in c.size():
		w = maxf(w, font.get_string_size(c[i], HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_PX[i]).x)
	return Vector2(w, _route_h(l) + _code_h(c, not l.is_empty())) + PAD * 2.0


func _draw() -> void:
	if lines.is_empty() and code.is_empty():
		return
	var font := get_theme_default_font()
	draw_rect(rect, Color(BACK, 0.9 * alpha))
	draw_rect(rect, Color(EDGE, 0.7 * alpha), false, 2.0)
	var x := rect.position.x + PAD.x
	var y := rect.position.y + PAD.y + TITLE_PX
	for i in lines.size():
		var c := TEXT if i == 0 else Briefing.RISK_COLOR if i == lines.size() - 1 else DIM
		if i == 1:
			y += ROW * 0.4   # отступ после названия
		draw_string(font, Vector2(x, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX if i == 0 else LINE_PX,
			Color(c, alpha))
		y += ROW
	if code.is_empty():
		return
	# Страница «Связь»: базовая линия каждой строки — низ её ряда минус четверть ряда.
	var top := rect.position.y + PAD.y
	if not lines.is_empty():
		top += _route_h(lines) + CODE_GAP
		draw_line(Vector2(x, top), Vector2(rect.end.x - PAD.x, top), Color(EDGE, 0.35 * alpha), 1.0)
		top += CODE_GAP
	for i in code.size():
		top += CODE_ROW[i]
		var col := EDGE if i == 1 else TEXT if i == 2 else DIM
		draw_string(font, Vector2(x, top - CODE_ROW[i] * 0.25), code[i], HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_PX[i],
			Color(col, alpha))
