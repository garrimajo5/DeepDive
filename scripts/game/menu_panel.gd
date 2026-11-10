class_name MenuPanel
extends CanvasLayer
## Главное меню ART-037 на фоне заставки (`main.menu_panel`): название, три кнопки, версия. Состояние и места —
## `MainMenu`, масштаб и обрезка фона — `Splash`. Слой ниже заставки прогрева (её 100) и выше крестовины и кнопки;
## касания идут через `Touch.Router.taps` (`MenuFlow.menu_step`). Закрыто — узел скрыт, текстура фона остаётся
## загруженной (меню вернётся из паузы).

var menu: MainMenu
var version := ""
var draw: Control


func _init() -> void:
	name = "Главное меню"
	layer = 90
	draw = UiStyle.screen(self, "Кнопки", _draw_menu, MainMenu.DARK)


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
	UiStyle.text(draw, font, MainMenu.TITLE, Splash.to_screen(MainMenu.TITLE_AT, size), MainMenu.TITLE_PX * s,
		MainMenu.INK)
	for it: Array in menu.items():
		var r := menu.rect(it[0], size)
		var main_btn: bool = it[0] == menu.main_item()
		var on: bool = menu.enabled.get(it[0], false)
		draw.draw_style_box(UiStyle.menu_button(main_btn and on, s, 0.88 if on else 0.6, 1.0 if on else 0.6), r)
		var col := MainMenu.DARK if main_btn and on else (MainMenu.INK if on else MainMenu.OFF)
		var px := MainMenu.BUTTON_PX * s
		UiStyle.label(draw, font, it[1], r, px, col)
	var vp := MainMenu.VERSION_PX * s
	UiStyle.center(draw, font, MainMenu.version_line(version), MainMenu.VERSION_TOP, vp, MainMenu.SOFT, size)
