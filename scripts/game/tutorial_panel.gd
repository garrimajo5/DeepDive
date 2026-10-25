class_name TutorialPanel
extends Control
## Плашка подсказки первого забега ART-038 и обводка нужного управления поверх кнопок (`Touch.Layout`); касания
## не перехватывает. Шаги, тексты, место — `Tutorial`. Палитра ART-038, красного нет.

const TEXT := Color("D5E4E8")
const DIM := Color("9AD9E8")
const ACCENT := Color("67DDEB")
const BACK := Color(0.043, 0.11, 0.141, 244.0 / 255.0)   ## #0B1C24, альфа 244
const MAP_BACK := Color("102B37")   ## кнопка «Схема»

var tut: Tutorial
var layout: Touch.Layout
var line := ""        ## текст действия этого кадра
var ring := ""        ## что обвести: Tutorial.highlight
var status := Rect2() ## строка приборов на экране — плашка на неё не ложится
var avoid := Rect2()  ## открытая панель (пульт энергии) — плашка уходит от неё
var arrow: Array = [] ## стрелка у края к посту вне кадра: [ячейка на экране, зеркалить] (`HintPointer.edge`)
var atlas: Texture2D  ## атлас указателя ART-038
var map := false      ## шаг «найдите пост»: на плашке кнопка «Схема» ART-042 (`Tutorial.map_wanted`)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	atlas = load(HintPointer.PATH)


func show_tutorial(t: Tutorial, text: String, highlight: String, status_rect: Rect2, panel := Rect2(),
		edge: Array = [], find := false) -> void:
	tut = t
	var vis := t != null and t.shown()
	if vis != visible:
		visible = vis
	map = vis and find
	if not vis:
		return
	line = text
	ring = highlight
	status = status_rect
	avoid = panel
	arrow = edge
	queue_redraw()


## Плашка на экране (для табличек и меток: на неё не ложатся).
func box() -> Rect2:
	return Tutorial.box(get_viewport_rect().size, status, avoid, Tutorial.box_h(map, _text_w(), _box_w()))


## Кнопка «Схема» на экране; пустой — кнопки нет.
func map_rect() -> Rect2:
	if not visible or not map:
		return Rect2()
	return Tutorial.map_rect(box(), get_viewport_rect().size.y, not Tutorial.fits_beside(_text_w(), _box_w()))


## Ширина строки действия при H = 1080 и ширина плашки в px макета.
func _text_w() -> float:
	return get_theme_default_font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(Tutorial.TEXT_PX)).x


func _box_w() -> float:
	var size := get_viewport_rect().size
	return minf(Tutorial.BOX.x, (size.x - 32.0) * Tutorial.REF_H / size.y)


func _draw() -> void:
	if tut == null:
		return
	var size := get_viewport_rect().size
	var s := size.y / Tutorial.REF_H
	var a := tut.a
	var font := get_theme_default_font()
	var b := box()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BACK, BACK.a * a)
	sb.border_color = Color(ACCENT, a)
	sb.set_border_width_all(maxi(1, roundi(2.0 * s)))
	sb.set_corner_radius_all(roundi(12.0 * s))
	draw_style_box(sb, b)
	draw_string(font, b.position + Tutorial.STEP_AT * s, tut.step_line(map), HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(Tutorial.STEP_PX * s), Color(DIM, a))
	var px := int(Tutorial.TEXT_PX * s)
	var base := b.position + Tutorial.TEXT_AT * s
	if line == Tutorial.DONE:   # галочка кодом, за ней «Выполнено»
		var h := px * 0.8
		var p0 := base + Vector2(0.0, -h * 0.45)
		draw_polyline(PackedVector2Array([p0, p0 + Vector2(h * 0.35, h * 0.35), p0 + Vector2(h, -h * 0.4)]),
			Color(ACCENT, a), maxf(2.0, 5.0 * s), true)
		base.x += h + 16.0 * s
	var btn := map_rect()
	var end := btn.position.x if btn.has_area() and btn.position.y < base.y else b.end.x
	draw_string(font, base, line, HORIZONTAL_ALIGNMENT_LEFT, end - base.x - 24.0 * s, px,
		Color(ACCENT if line == Tutorial.DONE else TEXT, a))
	if btn.has_area():   # «Схема» ART-042: контур акцентом, подпись по центру
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(MAP_BACK, a)
		bs.border_color = Color(ACCENT, a)
		bs.set_border_width_all(maxi(1, roundi(2.0 * s)))
		bs.set_corner_radius_all(roundi(10.0 * s))
		draw_style_box(bs, btn)
		var mpx := int(Tutorial.MAP_PX * s)
		var tw := font.get_string_size(Tutorial.MAP_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, mpx)
		draw_string(font, Vector2(btn.get_center().x - tw.x * 0.5, btn.get_center().y + mpx * 0.35),
			Tutorial.MAP_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, mpx, Color(TEXT, a))
	if layout != null and ring != "":
		var c := Tutorial.ring_of(ring, layout)
		if c != null:
			var w := maxf(2.0, Tutorial.RING * s)
			draw_arc(c.c, c.r + w * 0.5, 0.0, TAU, 64, Color(ACCENT, a), w, true)
	if arrow.size() == 2 and atlas != null:   # пост вне кадра — стрелка у края (у правого — зеркально)
		var r: Rect2 = arrow[0]
		if arrow[1]:
			r = Rect2(r.position.x + r.size.x, r.position.y, -r.size.x, r.size.y)
		draw_texture_rect_region(atlas, r, HintPointer.ARROW_CELL, Color(1, 1, 1, a))
