class_name SettingsPanel
extends CanvasLayer
## Настройки ART-037 поверх затемнённой сцены (`main.settings_panel`, `menyu-nastrojki.png`): заголовок, «Назад»,
## ползунки громкости и свайпа со значениями, страницы «Графика», «Звук» (шины `SoundPage`) и «Голос», «Камера с борта в начале забега» Вкл/Выкл, «Сбросить сохранение» и его
## подтверждение с выделенным «Нет». Состояние и места — `Settings`, масштаб — `Splash`, палитра — `MainMenu`.
## Слой выше главного меню и паузы (их 90), ниже заставки прогрева (100). Касания — `Main._settings_step`.

const LAYER := 91

var settings: Settings
var draw: Control


func _init() -> void:
	name = "Настройки"
	layer = LAYER
	visible = false
	draw = UiStyle.canvas(self, "Поля", _draw_settings)


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
	if settings.page == "golos":
		_draw_voice(font, s, size)
		return
	if settings.page == "zvuk":
		_draw_sound(font, s, size)
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
	_button(font, Settings.screen_rect("zvuk", size), Settings.ZVUK_LABEL, false, k, s)
	_button(font, Settings.screen_rect("golos", size), Settings.GOLOS_LABEL, false, k, s)
	_button(font, Settings.screen_rect("reset", size), Settings.RESET_LABEL, false, k, s)
	if not settings.ask:
		return
	draw.draw_rect(Rect2(Vector2.ZERO, size), Color(MainMenu.DARK, 0.45))
	draw.draw_style_box(UiStyle.dialog(s), Splash.rect_to_screen(Pause.BOX, size))
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


## Страница «Настройки · Голос» ART-041 (кадр 08 `raciya-sostoyaniya.png`): громкость товарищей, статус микрофона,
## режим (выбранный — главная кнопка) с подписью, переключатели приёма и микрофона.
func _draw_voice(font: Font, s: float, size: Vector2) -> void:
	_text(font, VoicePage.TITLE, Graphics.TITLE_AT, Graphics.TITLE_PX * s, MainMenu.INK, size)
	_button(font, VoicePage.screen_rect("back", size), "Назад", false, 1.0, s)
	var px := VoicePage.LABEL_PX * s
	var x := VoicePage.LABEL_X
	_text(font, VoicePage.MATES_LABEL, Vector2(x, VoicePage.MATES_TOP), px, MainMenu.INK, size)
	_value_at(font, settings.value_text("mates"), VoicePage.VALUE_RIGHT, VoicePage.MATES_TOP, px, MainMenu.SOFT, size)
	_slider(VoicePage.TRACK_Y, settings.fraction("mates"), settings.grab == "mates", 1.0, s, size, VoicePage.TRACK_X)
	_text(font, VoicePage.MIC_LABEL, Vector2(x, VoicePage.label_top(VoicePage.STATE)), px, MainMenu.INK, size)
	_button(font, VoicePage.screen_rect("v_state", size), VoicePage.state_text(settings.mic_ok), false, 1.0, s)
	_text(font, VoicePage.MODE_LABEL, Vector2(x, VoicePage.label_top(VoicePage.HOLD)), px, MainMenu.INK, size)
	var voice := settings.voice_mode == Radio.Mode.VOICE
	_button(font, VoicePage.screen_rect("v_hold", size), "Нажать и держать", not voice, 1.0, s)
	_button(font, VoicePage.screen_rect("v_voice", size), "По голосу", voice, 1.0, s)
	_text(font, VoicePage.note(settings.voice_mode), Vector2(x, VoicePage.NOTE_TOP), VoicePage.NOTE_PX * s,
		MainMenu.SOFT, size)
	_button(font, VoicePage.screen_rect("v_hear", size), VoicePage.hear_text(settings.hear), false, 1.0, s)
	_button(font, VoicePage.screen_rect("v_mic", size), VoicePage.mic_text(settings.mic_on), false, 1.0, s)


## Страница «Настройки · Звук»: шесть ползунков шин (`SoundPage`) в две колонки, подпись про общую громкость.
func _draw_sound(font: Font, s: float, size: Vector2) -> void:
	_text(font, SoundPage.TITLE, Graphics.TITLE_AT, Graphics.TITLE_PX * s, MainMenu.INK, size)
	_button(font, SoundPage.screen_rect("back", size), "Назад", false, 1.0, s)
	var px := SoundPage.LABEL_PX * s
	for i in SoundPage.count():
		var id := SoundPage.id_of(i)
		var c := SoundPage.column(i)
		var top := SoundPage.label_top(i)
		_text(font, SoundPage.label(i), Vector2(c.x, top), px, MainMenu.INK, size)
		_value_at(font, settings.value_text(id), c.y, top, px, MainMenu.SOFT, size)
		_slider(SoundPage.track_y(i), settings.fraction(id), settings.grab == id, 1.0, s, size, SoundPage.track_x(i))
	_text(font, SoundPage.NOTE, Vector2(SoundPage.COLUMNS[0].x, SoundPage.NOTE_TOP), SoundPage.NOTE_PX * s,
		MainMenu.SOFT, size)


## Дорожка на высоте y макета (от и до — track): залитая часть до доли f, ручка.
func _slider(y: float, f: float, held: bool, k: float, s: float, size: Vector2,
		track := Settings.TRACK_X) -> void:
	var a := Splash.to_screen(Vector2(track.x, y), size)
	var b := Splash.to_screen(Vector2(track.y, y), size)
	var h := maxf(2.0, Settings.TRACK_H * s)
	var at := a.lerp(b, f)
	draw.draw_line(a, b, Color(MainMenu.EDGE, k), h, true)
	draw.draw_line(a, at, Color(MainMenu.MAIN, k), h, true)
	var r := Settings.KNOB_R * s * (1.15 if held else 1.0)
	draw.draw_circle(at, r, Color(MainMenu.INK, k), true, -1.0, true)
	if held:
		draw.draw_circle(at, r, Color(MainMenu.MAIN, k), false, maxf(1.0, 3.0 * s), true)


func _button(font: Font, r: Rect2, text: String, main_btn: bool, k: float, s: float) -> void:
	draw.draw_style_box(UiStyle.menu_button(main_btn, s, 0.92, 1.0, k), r)
	var col := MainMenu.DARK if main_btn else MainMenu.INK
	var px := Settings.BUTTON_PX * s
	UiStyle.label(draw, font, text, r, px, Color(col, k))


## Строка от левого края at.x макета, at.y — верх видимых глифов.
func _text(font: Font, text: String, at: Vector2, px: float, color: Color, size: Vector2) -> void:
	UiStyle.text(draw, font, text, Splash.to_screen(at, size), px, color)


## Значение ползунка: правый край — `Settings.VALUE_RIGHT`.
func _value(font: Font, text: String, top: float, px: float, color: Color, size: Vector2) -> void:
	_value_at(font, text, Settings.VALUE_RIGHT, top, px, color, size)


## Строка с правым краем right макета.
func _value_at(font: Font, text: String, right: float, top: float, px: float, color: Color, size: Vector2) -> void:
	var p := Splash.to_screen(Vector2(right, top), size)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x
	UiStyle.text(draw, font, text, Vector2(p.x - w, p.y), px, color)


func _center(font: Font, text: String, top: float, px: float, color: Color, size: Vector2) -> void:
	var y := Splash.to_screen(Vector2(0.0, top), size).y
	UiStyle.center(draw, font, text, 0.0, y, size.x, px, color)
