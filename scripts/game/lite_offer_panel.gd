class_name LiteOfferPanel
extends CanvasLayer
## Диалог «Телефон не справляется — включить «Экономно»?» ART-044 поверх затемнённой живой сцены
## (`main.lite_offer_panel`): три строки, «Да» — главная (голубая), «Нет». Состояние и места — `LiteOffer`,
## масштаб — `Splash`, палитра — `MainMenu`. Слой ниже паузы и меню (90), выше счётчика кадров (80).

const LAYER := 86

var offer: LiteOffer
var draw: Control


func _init() -> void:
	name = "Предложение Экономно"
	layer = LAYER
	visible = false
	draw = Control.new()
	draw.name = "Диалог"
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_offer)
	add_child(draw)


func show_offer(o: LiteOffer) -> void:
	var was := visible
	offer = o
	visible = o != null and o.open
	if visible and not was:
		draw.queue_redraw()


func _draw_offer() -> void:
	if offer == null:
		return
	var size := draw.get_viewport_rect().size
	var s := Splash.scale(size)
	var font := draw.get_theme_default_font()
	draw.draw_rect(Rect2(Vector2.ZERO, size), Color(MainMenu.DARK, LiteOffer.DIM))
	draw.draw_style_box(UiStyle.dialog(s), LiteOffer.screen_rect("box", size))
	for i in LiteOffer.LINES.size():
		var px: float = LiteOffer.LINE_PX[i] * s
		var y := Splash.to_screen(Vector2(0.0, LiteOffer.LINE_TOP[i]), size).y
		draw.draw_string(font, Vector2(0.0, y + Splash.CAP_H * px), LiteOffer.LINES[i], HORIZONTAL_ALIGNMENT_CENTER,
			size.x, roundi(px), MainMenu.INK if i == 0 else MainMenu.SOFT)
	_button(font, LiteOffer.screen_rect("yes", size), "Да", true, s)
	_button(font, LiteOffer.screen_rect("no", size), "Нет", false, s)


func _button(font: Font, r: Rect2, text: String, main_btn: bool, s: float) -> void:
	draw.draw_style_box(UiStyle.menu_button(main_btn, s), r)
	var px := LiteOffer.BUTTON_PX * s
	var base := r.position.y + r.size.y * 0.5 + Splash.CAP_H * px * 0.5
	draw.draw_string(font, Vector2(r.position.x, base), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, roundi(px),
		MainMenu.DARK if main_btn else MainMenu.INK)
