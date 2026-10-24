class_name FpsView
extends CanvasLayer
## Счётчик кадров ART-044 (`grafika-sostoyaniya.png`, «Счётчик в игре»): плашка 300×54 у правого края под кнопкой
## noclip, «58 кадр/с», обновление два раза в секунду (`Graphics.Fps`). Касаний не принимает; виден, когда в
## настройках «Показывать кадры/с» (`Main._apply_settings`). Слой ниже меню, паузы и настроек (90+).

const LAYER := 80

var fps := Graphics.Fps.new()
var draw: Control


func _init() -> void:
	name = "Кадры в секунду"
	layer = LAYER
	visible = false
	draw = Control.new()
	draw.name = "Плашка"
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_counter)
	add_child(draw)


## Настоящее время кадра dt; перерисовка — только когда число обновилось.
func push(dt: float) -> void:
	if fps.push(dt):
		draw.queue_redraw()


func _draw_counter() -> void:
	var size := draw.get_viewport_rect().size
	var r := Graphics.counter_rect(size)
	var s := size.y / Splash.H
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(roundi(8.0 * s))
	sb.anti_aliasing = true
	sb.bg_color = Color(MainMenu.DARK, 0.78)
	sb.set_border_width_all(maxi(1, roundi(2.0 * s)))
	sb.border_color = MainMenu.EDGE
	draw.draw_style_box(sb, r)
	var px := Graphics.COUNTER_PX * s
	var base := r.position.y + r.size.y * 0.5 + Splash.CAP_H * px * 0.5
	draw.draw_string(draw.get_theme_default_font(), Vector2(r.position.x, base), Graphics.counter_text(fps.value),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, roundi(px), MainMenu.INK)
