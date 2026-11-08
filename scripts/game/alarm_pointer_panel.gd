class_name AlarmPointerPanel
extends Control
## Подпись и стрелка у края указателя на цель тревоги в соло (#1361, часть B; `AlarmWay.pointer`): цель вне кадра —
## янтарная стрелка `HintPointer.ARROW_CELL` у края и одно слово под ней («Пробоина»), в кадре — плашка
## «Пробоина · машинное» над кольцом мирового указателя (`HintPointerView.symbol`). Касания не перехватывает.

var atlas: Texture2D   ## белый атлас указателя (`HintPointerView.amber`)
var arrow: Array = []  ## [ячейка на экране, зеркалить] или []
var symbol := Rect2()  ## мировой символ на экране или пусто
var text := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Показать: p — указатель тревоги (null — скрыть), edge — стрелка у края от `HintPointerView.show_at`, sym — символ
## в мире, tex — белый атлас.
func show_way(p: AlarmWay.Pointer, edge: Array, sym: Rect2, tex: Texture2D) -> void:
	var vis := p != null and (edge.size() == 2 or sym.has_area())
	if vis != visible:
		visible = vis
	if not vis:
		return
	atlas = tex
	arrow = edge
	symbol = sym
	text = p.word if edge.size() == 2 else p.label()
	queue_redraw()


## Плашка подписи на экране (тесты, таблички).
func box() -> Rect2:
	if not visible:
		return Rect2()
	var size := get_viewport_rect().size
	var px := roundi(AlarmWay.LABEL_PX * size.y / HintPointer.REF_H)
	var w := get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if arrow.size() == 2:
		var r: Rect2 = arrow[0]
		if arrow[1]:
			r = Rect2(r.position.x + r.size.x, r.position.y, -r.size.x, r.size.y)
		return AlarmWay.label_rect(w, r, true, size)
	return AlarmWay.label_rect(w, symbol, false, size)


func _draw() -> void:
	var size := get_viewport_rect().size
	var s := size.y / HintPointer.REF_H
	if arrow.size() == 2 and atlas != null:
		var r: Rect2 = arrow[0]
		if arrow[1]:
			r = Rect2(r.position.x + r.size.x, r.position.y, -r.size.x, r.size.y)
		draw_texture_rect_region(atlas, r, HintPointer.ARROW_CELL, AlarmBoard.WORD_ON)
	var b := box()
	draw_style_box(UiStyle.box(Color(AlarmBoard.BACK, 0.92), 10.0 * s, AlarmBoard.WORD_ON, 2.0 * s), b)
	UiStyle.label(self, get_theme_default_font(), text, b, AlarmWay.LABEL_PX * s, AlarmBoard.WORD_ON)
