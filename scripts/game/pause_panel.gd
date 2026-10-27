class_name PausePanel
extends CanvasLayer
## Пауза ART-037 поверх затемнённой живой сцены (`main.pause_panel`): «Пауза» (кооп — «Меню забега» с подписью), кнопки, подтверждение с
## выделенным «Нет». Состояние и места — `Pause`, масштаб — `Splash`, палитра — `MainMenu`. Слой как у главного
## меню: выше крестовины и кнопки, ниже заставки прогрева. Касания — `Touch.Router.taps` (`Main._pause_step`).

const LAYER := 90

var pause: Pause
var draw: Control


func _init() -> void:
	name = "Пауза"
	layer = LAYER
	visible = false
	draw = UiStyle.canvas(self, "Кнопки", _draw_pause)


func show_pause(p: Pause) -> void:
	pause = p
	visible = p != null and p.open
	if visible:
		draw.queue_redraw()


func _draw_pause() -> void:
	if pause == null:
		return
	var size := draw.get_viewport_rect().size
	var s := Splash.scale(size)
	var font := draw.get_theme_default_font()
	draw.draw_rect(Rect2(Vector2.ZERO, size), Color(MainMenu.DARK, Pause.DIM))
	var faded := pause.ask != ""   # под подтверждением пауза приглушена
	var k := 0.35 if faded else 1.0
	_center(font, pause.title(), Pause.TITLE_TOP, Pause.TITLE_PX * s, Color(MainMenu.INK, k), size)
	if pause.subtitle() != "":   # кооп: «Вы — гость · забег продолжается»
		_center(font, pause.subtitle(), Pause.SUB_TOP, Pause.SUB_PX * s, Color(MainMenu.SOFT, k), size)
	for it: Array in pause.items():
		var on: bool = pause.enabled.get(it[0], false)
		_button(font, pause.rect(it[0], size), it[1], it[0] == Pause.MAIN_ITEM and on, on, k, s)
	if not faded:
		return
	draw.draw_rect(Rect2(Vector2.ZERO, size), Color(MainMenu.DARK, 0.45))
	var box := Splash.rect_to_screen(Pause.BOX, size)
	draw.draw_style_box(UiStyle.dialog(s), box)
	var lines: Array = pause.ask_lines()
	for i in lines.size():
		if i == 0:
			_center(font, lines[0], Pause.ASK_TOP, Pause.ASK_PX * s, MainMenu.INK, size)
		else:
			_center(font, lines[i], Pause.LINE_TOP + Pause.LINE_STEP * (i - 1), Pause.LINE_PX * s, MainMenu.SOFT, size)
	_button(font, Pause.screen_rect("yes", size), "Да", false, true, 1.0, s)
	_button(font, Pause.screen_rect("no", size), "Нет", true, true, 1.0, s)   # выделено «Нет»


func _button(font: Font, r: Rect2, text: String, main_btn: bool, on: bool, k: float, s: float) -> void:
	draw.draw_style_box(UiStyle.menu_button(main_btn, s, 0.92 if on else 0.6, 1.0 if on else 0.6, k), r)
	var col := MainMenu.DARK if main_btn else (MainMenu.INK if on else MainMenu.OFF)
	var px := Pause.BUTTON_PX * s
	UiStyle.label(draw, font, text, r, px, Color(col, k))


## Строка по центру экрана: top — верх видимых глифов в макете.
func _center(font: Font, text: String, top: float, px: float, color: Color, size: Vector2) -> void:
	var y := Splash.to_screen(Vector2(0.0, top), size).y
	UiStyle.center(draw, font, text, 0.0, y, size.x, px, color)
