class_name SettingsPanel
extends CanvasLayer
## Настройки ART-037 поверх затемнённой сцены (`main.settings_panel`, `menyu-nastrojki.png`): заголовок, «Назад»,
## ползунки громкости и свайпа со значениями, «Камера с борта в начале забега» Вкл/Выкл, «Сбросить сохранение» и его
## подтверждение с выделенным «Нет». Состояние и места — `Settings`, масштаб — `Splash`, палитра — `MainMenu`.
## Слой выше главного меню и паузы (их 90), ниже заставки прогрева (100). Касания — `Main._settings_step`.

const LAYER := 91

var settings: Settings
var draw: Control


func _init() -> void:
	name = "Настройки"
	layer = LAYER
	visible = false
	draw = Control.new()
	draw.name = "Поля"
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_settings)
	add_child(draw)


func show_settings(s: Settings) -> void:
	settings = s
	visible = s != null and s.open
	if visible:
		draw.queue_redraw()


func _draw_settings() -> void:
	if settings == null:
		return
	var size := draw.get_viewport_rect().size
	var s := Splash.scale(size)
	var font := draw.get_theme_default_font()
	draw.draw_rect(Rect2(Vector2.ZERO, size), Color(MainMenu.DARK, Pause.DIM))
	if settings.page == "grafika":
		_draw_graphics(font, s, size)
		return
	var k := 0.35 if settings.ask else 1.0
	_text(font, Settings.TITLE, Settings.TITLE_AT, Settings.TITLE_PX * s, Color(MainMenu.INK, k), size)
	_button(font, Settings.screen_rect("back", size), "Назад", false, k, s)
	for sl: Array in Settings.SLIDERS:
		_text(font, sl[1], Vector2(Settings.LABEL_X, sl[2]), Settings.LABEL_PX * s, Color(MainMenu.INK, k), size)
		_value(font, settings.value_text(sl[0]), sl[2], Settings.VALUE_PX * s, Color(MainMenu.SOFT, k), size)
		_slider(sl[3], settings.fraction(sl[0]), sl[0] == settings.grab, k, s, size)
	_text(font, Settings.INTRO_LABEL, Vector2(Settings.LABEL_X, Settings.INTRO_TOP), Settings.BUTTON_PX * s,
		Color(MainMenu.INK, k), size)
	_button(font, Settings.screen_rect("intro", size), "Вкл" if settings.intro else "Выкл", settings.intro, k, s)
	_button(font, Settings.screen_rect("graphics", size), Settings.GRAPHICS_LABEL, false, k, s)
	_button(font, Settings.screen_rect("reset", size), Settings.RESET_LABEL, false, k, s)
	if not settings.ask:
		return
	draw.draw_rect(Rect2(Vector2.ZERO, size), Color(MainMenu.DARK, 0.45))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(roundi(MainMenu.RADIUS * s))
	sb.anti_aliasing = true
	sb.bg_color = Color(MainMenu.PANEL, 0.97)
	sb.set_border_width_all(maxi(1, roundi(2.0 * s)))
	sb.border_color = MainMenu.EDGE
	draw.draw_style_box(sb, Splash.rect_to_screen(Pause.BOX, size))
	for i in Settings.ASK.size():
		if i == 0:
			_center(font, Settings.ASK[0], Pause.ASK_TOP, Pause.ASK_PX * s, MainMenu.INK, size)
		else:
			_center(font, Settings.ASK[i], Pause.LINE_TOP + Pause.LINE_STEP * (i - 1), Pause.LINE_PX * s,
				MainMenu.SOFT, size)
	_button(font, Settings.screen_rect("yes", size), "Да", false, 1.0, s)
	_button(font, Settings.screen_rect("no", size), "Нет", true, 1.0, s)   # выделено «Нет»


## Страница «Настройки · Графика» ART-044: три уровня (выбранный — главная кнопка), четыре строки словами,
## «Показывать кадры/с» Вкл./Выкл., подпись про чёткий интерфейс.
func _draw_graphics(font: Font, s: float, size: Vector2) -> void:
	_text(font, Graphics.TITLE, Graphics.TITLE_AT, Graphics.TITLE_PX * s, MainMenu.INK, size)
	_button(font, Graphics.screen_rect("back", size), "Назад", false, 1.0, s)
	for i in Graphics.NAMES.size():
		_button(font, Graphics.screen_rect("g%d" % i, size), Graphics.NAMES[i], i == settings.graphics, 1.0, s)
	var rows := Graphics.rows(settings.graphics)
	for i in rows.size():
		var top := Graphics.ROW_TOP + Graphics.ROW_STEP * i
		_text(font, rows[i][0], Vector2(Graphics.ROW_X, top), Graphics.ROW_PX * s, MainMenu.INK, size)
		_value_at(font, rows[i][1], Graphics.VALUE_RIGHT, top, Graphics.ROW_PX * s, MainMenu.MAIN, size)
	var fr := Graphics.FPS
	var fps_top := fr.position.y + (fr.size.y - Graphics.ROW_PX * Splash.CAP_H) * 0.5
	_text(font, Graphics.FPS_LABEL, Vector2(Graphics.ROW_X, fps_top), Graphics.ROW_PX * s, MainMenu.INK, size)
	_button(font, Graphics.screen_rect("fps", size), "Вкл." if settings.fps else "Выкл.", settings.fps, 1.0, s)
	_text(font, Graphics.NOTE, Vector2(Graphics.ROW_X, Graphics.NOTE_TOP), Graphics.NOTE_PX * s, MainMenu.SOFT, size)


## Дорожка на высоте y макета: залитая часть до доли f, ручка.
func _slider(y: float, f: float, held: bool, k: float, s: float, size: Vector2) -> void:
	var a := Splash.to_screen(Vector2(Settings.TRACK_X.x, y), size)
	var b := Splash.to_screen(Vector2(Settings.TRACK_X.y, y), size)
	var h := maxf(2.0, Settings.TRACK_H * s)
	var at := a.lerp(b, f)
	draw.draw_line(a, b, Color(MainMenu.EDGE, k), h, true)
	draw.draw_line(a, at, Color(MainMenu.MAIN, k), h, true)
	var r := Settings.KNOB_R * s * (1.15 if held else 1.0)
	draw.draw_circle(at, r, Color(MainMenu.INK, k), true, -1.0, true)
	if held:
		draw.draw_circle(at, r, Color(MainMenu.MAIN, k), false, maxf(1.0, 3.0 * s), true)


func _button(font: Font, r: Rect2, text: String, main_btn: bool, k: float, s: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(roundi(MainMenu.RADIUS * s))
	sb.anti_aliasing = true
	if main_btn:
		sb.bg_color = Color(MainMenu.MAIN, k)
	else:
		sb.bg_color = Color(MainMenu.PANEL, 0.92 * k)
		sb.set_border_width_all(maxi(1, roundi(2.0 * s)))
		sb.border_color = Color(MainMenu.EDGE, k)
	draw.draw_style_box(sb, r)
	var col := MainMenu.DARK if main_btn else MainMenu.INK
	var px := Settings.BUTTON_PX * s
	var base := r.position.y + r.size.y * 0.5 + Splash.CAP_H * px * 0.5
	draw.draw_string(font, Vector2(r.position.x, base), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, roundi(px),
		Color(col, k))


## Строка от левого края at.x макета, at.y — верх видимых глифов.
func _text(font: Font, text: String, at: Vector2, px: float, color: Color, size: Vector2) -> void:
	var p := Splash.to_screen(at, size)
	draw.draw_string(font, Vector2(p.x, p.y + Splash.CAP_H * px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px), color)


## Значение ползунка: правый край — `Settings.VALUE_RIGHT`.
func _value(font: Font, text: String, top: float, px: float, color: Color, size: Vector2) -> void:
	_value_at(font, text, Settings.VALUE_RIGHT, top, px, color, size)


## Строка с правым краем right макета.
func _value_at(font: Font, text: String, right: float, top: float, px: float, color: Color, size: Vector2) -> void:
	var p := Splash.to_screen(Vector2(right, top), size)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x
	draw.draw_string(font, Vector2(p.x - w, p.y + Splash.CAP_H * px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px),
		color)


func _center(font: Font, text: String, top: float, px: float, color: Color, size: Vector2) -> void:
	var y := Splash.to_screen(Vector2(0.0, top), size).y
	draw.draw_string(font, Vector2(0.0, y + Splash.CAP_H * px), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, roundi(px),
		color)
