class_name DescentView
extends CanvasLayer
## Шторка ухода к Кристальному лесу (#828): затемнение и надпись «Кристальный лес — в разработке» по `DescentTrip`.
## Слой виден всегда, прячется `cover` — прогрев показывает его на кадр, и кегли 64/30 растрируются под заставкой,
## а не в кадре «глубже» у 10 (#1095).

var cover: ColorRect
var title: Label
var sub: Label


func _init() -> void:
	layer = 20
	name = "Спуск к лесу"
	cover = ColorRect.new()
	cover.color = Color(0.0, 0.02, 0.04)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	title = _label(DescentTrip.TITLE, 64, Color(0.62, 0.86, 0.92), -60.0)
	sub = _label(DescentTrip.SUB, 30, Color(0.78, 0.84, 0.88), 30.0)
	cover.visible = false


func _label(t: String, px: int, c: Color, dy: float) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_top = dy
	l.offset_bottom = dy
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(l)
	return l


func apply(trip: DescentTrip) -> void:
	cover.visible = trip.active
	if not cover.visible:
		return
	cover.color.a = trip.alpha()
	var k := trip.text_alpha()
	title.modulate.a = k
	sub.modulate.a = k


## Шторка на экране (`cover`); сам слой не прячется.
func shown() -> bool:
	return cover.visible
