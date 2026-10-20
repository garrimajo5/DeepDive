class_name TouchOverlay
extends Control
## Экранные органы управления: крестовина, кнопка действия, за штурвалом — «Всплыть», «Вниз», «Свет».
## Касания разбирает Touch.Router; на компьютере мышь работает как палец (emulate_touch_from_mouse).

var router := Touch.Router.new()
var light_on := true     ## прожектор горит: кнопка «Свет» янтарная
var action_label := ""   ## подпись на кнопке действия («Штурвал», «Встать»); пусто — кнопка тусклая
var noclip_on := false   ## тестовый режим noclip включён: кнопка подсвечена
## Сколько «точек» экрана (1/160 дюйма) в одном пикселе вьюпорта — для чувствительности свайпа.
var points_per_px := 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _relayout() -> void:
	var vis := get_viewport().get_visible_rect()
	var win := Vector2(DisplayServer.window_get_size())
	var safe := vis
	var k := Vector2.ONE
	if win.x > 0 and win.y > 0:
		k = vis.size / win
		var s := Rect2(DisplayServer.get_display_safe_area())
		if s.size.x > 0 and s.size.y > 0 and OS.has_feature("mobile"):
			safe = Rect2(s.position * k, s.size * k).intersection(vis)
	router.layout.compute(safe)
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = 160.0
	points_per_px = 1.0 / k.y / (dpi / 160.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			router.begin(event.index, event.position)
		else:
			router.end(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		router.moved(event.index, event.position)
		queue_redraw()


## Свайп за кадр в «точках» экрана.
func look_points() -> Vector2:
	return router.look * points_per_px


func set_pilot(on: bool) -> void:
	if router.pilot_buttons != on:
		router.pilot_buttons = on
		router.clear()
		queue_redraw()


func set_light(on: bool) -> void:
	if light_on != on:
		light_on = on
		queue_redraw()


func set_action_label(text: String) -> void:
	if action_label != text:
		action_label = text
		queue_redraw()


func set_noclip(on: bool) -> void:
	if noclip_on != on:
		noclip_on = on
		queue_redraw()


func _draw() -> void:
	var l := router.layout
	var font := get_theme_default_font()
	var line := Color(0.85, 0.95, 1.0, 0.55)
	var fill := Color(0.6, 0.85, 0.95, 0.12)
	# крестовина: круг и стрелки, активное направление ярче
	draw_circle(l.pad.c, l.pad.r, fill)
	draw_arc(l.pad.c, l.pad.r, 0, TAU, 48, line, 2.0)
	for i in 8:
		var a := i * PI / 4.0
		var dir := Vector2(cos(a), -sin(a))
		var on := Vector2i(int(roundf(dir.x)), int(roundf(-dir.y))) == router.move and router.move != Vector2i.ZERO
		var tip := l.pad.c + dir * l.pad.r * 0.78
		var side := dir.orthogonal() * l.pad.r * (0.12 if i % 2 == 0 else 0.08)
		var base := l.pad.c + dir * l.pad.r * (0.55 if i % 2 == 0 else 0.6)
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]),
			Color(1, 1, 1, 0.9) if on else line)
	# кнопка действия
	var act_col := Color(0.4, 0.9, 1.0, 0.35 if router.action_down else 0.18)
	if action_label.is_empty():
		act_col.a = 0.08
	draw_circle(l.action.c, l.action.r, act_col)
	draw_arc(l.action.c, l.action.r, 0, TAU, 40, line, 2.0)
	if not action_label.is_empty():
		_text(font, l.action.c, action_label, l.action.r * 0.32)
	# тестовая кнопка noclip (правый верхний угол): включена — янтарная заливка, иначе тусклое кольцо
	if noclip_on:
		draw_circle(l.noclip.c, l.noclip.r, Color(1.0, 0.75, 0.2, 0.5))
	draw_arc(l.noclip.c, l.noclip.r, 0, TAU, 32, line, 2.0)
	_text(font, l.noclip.c, "noclip", l.noclip.r * 0.42,
		Color(0.1, 0.07, 0.02, 0.95) if noclip_on else Color(1, 1, 1, 0.7))
	if router.pilot_buttons:
		for b in [[l.up, "Всплыть", router.vert() == 1], [l.down, "Вниз", router.vert() == -1]]:
			var c: Touch.Circle = b[0]
			draw_circle(c.c, c.r, Color(0.6, 0.85, 0.95, 0.3 if b[2] else 0.12))
			draw_arc(c.c, c.r, 0, TAU, 32, line, 2.0)
			_text(font, c.c, b[1], c.r * 0.36)
		# «Свет»: горит — полный янтарный круг, погашен — тусклое кольцо
		if light_on:
			draw_circle(l.light.c, l.light.r, Searchlight.BUTTON_ON)
		else:
			draw_arc(l.light.c, l.light.r, 0, TAU, 32, Searchlight.BUTTON_OFF, 3.0)
		_text(font, l.light.c, Searchlight.button_label(light_on), l.light.r * 0.3,
			Color(0.1, 0.07, 0.02, 0.95) if light_on else Color(1, 1, 1, 0.75))


func _text(font: Font, at: Vector2, text: String, px: float, color: Color = Color(1, 1, 1, 0.9)) -> void:
	var fs := int(maxf(px, 10.0))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-w / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
