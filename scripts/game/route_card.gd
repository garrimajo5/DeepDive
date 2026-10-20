class_name RouteCard
extends Control
## Карточка выбранного маршрута над голостолом (ART-016): экранная надпись поверх 3D, привязанная к точке над краем
## карты брифинга (Briefing.CARD_ANCHOR). Название, места по порядку, риск янтарным. Кегль не уменьшается вместе
## со сценой: заголовок 26 px, строки 20 px; тёмная почти непрозрачная подложка, контур голограммы.

const TEXT := Color("D5E4E8")
const DIM := Color("9AD9E8")
const EDGE := Color("67DDEB")
const BACK := Color("0B1C24")
const TITLE_PX := 26
const LINE_PX := 20
const PAD := Vector2(18, 12)
const ROW := 28.0

var lines: Array[String] = []
var alpha := 0.0
var rect := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## k — доля перехода брифинга (Briefing.Fade), route — Run.route, anchor — точка привязки в мире.
func show_card(k: float, route: int, cam: Camera3D, anchor: Vector3) -> void:
	var on := k > 0.0 and route >= 0 and cam != null and not cam.is_position_behind(anchor)
	if not on:
		visible = false
		return
	var l := Briefing.card_lines(route)
	var r := Briefing.card_rect(cam.unproject_position(anchor), card_size(l), get_viewport_rect().size)
	if visible and l == lines and r == rect and is_equal_approx(k, alpha):
		return
	lines = l
	rect = r
	alpha = k
	visible = true
	queue_redraw()


## Размер подложки под строки: ширина — по самой длинной строке.
func card_size(l: Array[String]) -> Vector2:
	var font := get_theme_default_font()
	var w := 0.0
	for i in l.size():
		w = maxf(w, font.get_string_size(l[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_PX if i == 0 else LINE_PX).x)
	return Vector2(w, ROW * (l.size() + 0.4)) + PAD * 2.0


func _draw() -> void:
	if lines.is_empty():
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
