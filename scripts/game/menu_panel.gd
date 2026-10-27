class_name MenuPanel
extends CanvasLayer
## Главное меню ART-037 на фоне заставки (`main.menu_panel`): название, три кнопки, версия. Состояние и места —
## `MainMenu`, масштаб и обрезка фона — `Splash`. Слой ниже заставки прогрева (её 100) и выше крестовины и кнопки;
## касания идут через `Touch.Router.taps` (`Main._menu_step`). Закрыто — узел скрыт, текстура фона остаётся
## загруженной (меню вернётся из паузы).

var menu: MainMenu
var version := ""
var draw: Control


func _init() -> void:
	name = "Главное меню"
	layer = 90
	var dark := ColorRect.new()   # под фоном: если текстура не загрузилась, сцена всё равно закрыта
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.color = MainMenu.DARK
	add_child(dark)
	var bg := TextureRect.new()
	bg.name = "Фон"
	bg.texture = load(Splash.BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	draw = Control.new()
	draw.name = "Кнопки"
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_menu)
	add_child(draw)


func show_menu(m: MainMenu) -> void:
	menu = m
	visible = m != null and m.open
	if visible:
		draw.queue_redraw()


func _draw_menu() -> void:
	if menu == null:
		return
	var size := draw.get_viewport_rect().size
	var s := Splash.scale(size)
	var font := draw.get_theme_default_font()
	_text(font, MainMenu.TITLE, Splash.to_screen(MainMenu.TITLE_AT, size), MainMenu.TITLE_PX * s, MainMenu.INK)
	for it: Array in MainMenu.ITEMS:
		var r := MainMenu.screen_rect(it[0], size)
		var main_btn: bool = it[0] == MainMenu.MAIN_ITEM
		var on: bool = menu.enabled.get(it[0], false)
		draw.draw_style_box(UiStyle.menu_button(main_btn and on, s, 0.88 if on else 0.6, 1.0 if on else 0.6), r)
		var col := MainMenu.DARK if main_btn and on else (MainMenu.INK if on else MainMenu.OFF)
		var px := MainMenu.BUTTON_PX * s
		var base := r.position.y + r.size.y * 0.5 + Splash.CAP_H * px * 0.5
		draw.draw_string(font, Vector2(r.position.x, base), it[1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
			roundi(px), col)
	var vp := MainMenu.VERSION_PX * s
	var top := Splash.to_screen(Vector2(0.0, MainMenu.VERSION_TOP), size).y
	draw.draw_string(font, Vector2(0.0, top + Splash.CAP_H * vp), MainMenu.version_line(version),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, roundi(vp), MainMenu.SOFT)


## Строка: at — левый край и верх видимых глифов на экране.
func _text(font: Font, text: String, at: Vector2, px: float, color: Color) -> void:
	draw.draw_string(font, at + Vector2(0.0, Splash.CAP_H * px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px), color)
