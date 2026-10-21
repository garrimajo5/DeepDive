class_name PowerPanel
extends Control
## Пульт энергии на экране (js/power.js, панель #power): пять систем с полосками долей, выбранная подсвечена,
## внизу резерв или перегрев. Открыт, пока игрок у пульта энергии (Main.at_power).

## Подсказка внизу словами: стрелок ▲▼◀▶ нет в шрифте игры — их искал бы системный шрифт телефона (рывок, #217).
const FOOT := "крестовина: вверх-вниз — система, вбок — −/+5 · кнопка — закрыть"

var reactor: Reactor
var panel: Reactor.Console
## Раскладка кнопок (Touch.Layout): панель встаёт ниже кнопки noclip и выше кнопки действия (#349). null — без неё.
var layout: Touch.Layout


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


## Прямоугольник панели: справа над кнопкой действия, чтобы сам пульт с ползунками было видно в центре.
func box() -> Rect2:
	var vis := get_viewport_rect().size
	var w := minf(560.0, vis.x * 0.36)
	var h := minf(400.0, vis.y * 0.5)
	var top := vis.y * 0.13
	if layout:
		var gap := vis.y * 0.012
		top = maxf(top, layout.noclip.c.y + layout.noclip.r + gap)
		h = minf(h, layout.action.c.y - layout.action.r - gap - top)
	return Rect2(vis.x - w - vis.y * 0.04, top, w, h)


func _draw() -> void:
	if reactor == null:
		return
	var font := get_theme_default_font()
	var b := box()
	draw_rect(b, Color(0.03, 0.09, 0.11, 0.86))
	var hot := reactor.hot or reactor.scram > 0.0
	draw_rect(b, Color(1.0, 0.7, 0.3, 0.9) if hot else Color(0.4, 0.86, 0.92, 0.6), false, 2.0)
	var pad := b.size.x * 0.05
	var y := b.position.y + 38.0
	_text(font, Vector2(b.position.x + pad, y), "Пульт энергии", 26, Color(0.75, 0.95, 1.0))
	var row_h := (b.size.y - 104.0) / Reactor.Sys.size()
	for i in Reactor.Sys.size():
		var top := b.position.y + 50.0 + row_h * i
		var on := i == panel.sel
		if on:
			draw_rect(Rect2(b.position.x + 6, top, b.size.x - 12, row_h - 4), Color(0.4, 0.86, 0.92, 0.16))
		var v := reactor.share[i]
		var col := Color(0.55, 0.62, 0.65) if v == 0 else Color(0.9, 0.97, 1.0)
		_text(font, Vector2(b.position.x + pad, top + row_h * 0.42), Reactor.NAMES[i], 21, col)
		_text(font, Vector2(b.position.x + pad, top + row_h * 0.84), Reactor.HINTS[i], 15, Color(0.6, 0.75, 0.8))
		var bar := Rect2(b.position.x + b.size.x * 0.5, top + row_h * 0.35, b.size.x * 0.32, row_h * 0.3)
		draw_rect(bar, Color(0.1, 0.2, 0.24))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * v / float(Reactor.MAX), bar.size.y)), Color("67DDEB"))
		_text(font, Vector2(bar.end.x + 12, top + row_h * 0.6), str(v), 21, col)
	var foot := "Резерв: %d из %d" % [reactor.free_units(), Reactor.TOTAL]
	if reactor.scram > 0.0:
		foot = "Аварийный сброс: %d с" % ceili(reactor.scram)
	elif reactor.hot:
		foot = "Перегрев %d° · безопасно %d, сейчас %d" % [roundi(reactor.heat), Reactor.SAFE, reactor.used()]
	_text(font, Vector2(b.position.x + pad, b.end.y - 34), foot, 19, Color(1.0, 0.74, 0.32) if hot else Color(0.75, 0.95, 1.0))
	_text(font, Vector2(b.position.x + pad, b.end.y - 10), FOOT, 14, Color(0.6, 0.75, 0.8))


func _text(font: Font, at: Vector2, t: String, size_px: int, c: Color) -> void:
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, c)
