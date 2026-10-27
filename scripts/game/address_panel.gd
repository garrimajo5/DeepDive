class_name AddressPanel
extends CanvasLayer
## Экран «Войти по адресу» ART-039 на фоне заставки (`main.address_panel`): заголовок, поле, подпись, последний
## удачный адрес, «Войти» / «Отмена», клавиатура, «Назад». Состояние и места — `AddressScreen`, клавиши —
## `AddressPad.key_rect`, масштаб и обрезка фона — `Splash`. Слой над главным меню (его 90), ниже заставки прогрева
## (100); касания — `Touch.Router.taps` (`Main._address_step`).

var screen: AddressScreen
var draw: Control
var blink := 0.0   ## время для мигания курсора


func _init() -> void:
	name = "Вход по адресу"
	layer = 91
	# экран ввода темнее меню: цифры читаются на любом месте фона
	draw = UiStyle.screen(self, "Клавиши", _draw_screen, MainMenu.DARK, Color(MainMenu.DARK, AddressScreen.DIM))


func show_screen(s: AddressScreen) -> void:
	screen = s
	visible = s != null and s.open
	if visible:
		draw.queue_redraw()


func _process(dt: float) -> void:
	if visible:
		blink += dt
		draw.queue_redraw()


func _draw_screen() -> void:
	if screen == null:
		return
	var size := draw.get_viewport_rect().size
	var s := Splash.scale(size)
	var font := draw.get_theme_default_font()
	var f := screen.field
	var busy := f.connecting
	UiStyle.text(draw, font, AddressScreen.TITLE, Splash.to_screen(AddressScreen.TITLE_AT, size), AddressScreen.TITLE_PX * s, MainMenu.INK)
	_button(font, AddressScreen.screen_rect("back", size), "Назад", AddressScreen.BACK_PX * s, s, "plain")
	UiStyle.text(draw, font, AddressScreen.LABEL, Splash.to_screen(AddressScreen.LABEL_AT, size), AddressScreen.SMALL_PX * s, MainMenu.SOFT)
	# поле: рамка главного цвета, текст или заглушка, курсор
	var fr := AddressScreen.screen_rect("field", size)
	var sb := _box(s, Color(MainMenu.PANEL, 0.92), MainMenu.MAIN)
	draw.draw_style_box(sb, fr)
	var px := AddressScreen.FIELD_PX * s
	var base := fr.position.y + fr.size.y * 0.5 + Splash.CAP_H * px * 0.5
	var x := fr.position.x + AddressScreen.FIELD_PAD * s
	if f.text.is_empty():
		draw.draw_string(font, Vector2(x, base), AddressScreen.PLACEHOLDER, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px), MainMenu.OFF)
	else:
		draw.draw_string(font, Vector2(x, base), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px), MainMenu.INK)
	if not busy and fmod(blink, 1.0) < 0.6:
		var cx := x + font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x + 4.0 * s
		draw.draw_line(Vector2(cx, base - px * 0.85), Vector2(cx, base + px * 0.12), MainMenu.MAIN, maxf(1.0, 3.0 * s))
	var h := screen.hint()
	UiStyle.text(draw, font, h, Splash.to_screen(AddressScreen.HINT_AT, size), AddressScreen.HINT_PX * s,
		MainMenu.INK if h == AddressScreen.EMPTY_TEXT else MainMenu.SOFT)
	if screen.has_last():
		UiStyle.text(draw, font, AddressScreen.LAST_LABEL, Splash.to_screen(AddressScreen.LAST_LABEL_AT, size), AddressScreen.SMALL_PX * s, MainMenu.SOFT)
		_button(font, AddressScreen.screen_rect("last", size), f.last, AddressScreen.LAST_PX * s, s, "off" if busy else "plain")
	var join_on := busy or f.can_join()
	_button(font, AddressScreen.screen_rect("join", size), f.join_text(), AddressScreen.JOIN_PX * s, s, "main" if join_on else "off")
	UiStyle.text(draw, font, AddressScreen.ASK, Splash.to_screen(AddressScreen.ASK_AT, size), AddressScreen.SMALL_PX * s, MainMenu.SOFT)
	for r in AddressPad.KEYS.size():
		for c in AddressPad.KEYS[r].size():
			var k: String = AddressPad.KEYS[r][c]
			var kpx := (AddressScreen.KEY_SMALL_PX if k == "del" else AddressScreen.KEY_PX) * s
			_button(font, AddressPad.key_rect(c, r, size), AddressPad.key_text(k), kpx, s, "off" if busy else "plain")


## Кнопка: kind "main" — главная (бирюзовая, тёмный текст), "plain" — панель с рамкой, "off" — погашенная.
func _button(font: Font, r: Rect2, label: String, px: float, s: float, kind: String) -> void:
	var sb: StyleBoxFlat
	var col := MainMenu.INK
	match kind:
		"main":
			sb = _box(s, MainMenu.MAIN, Color.TRANSPARENT)
			col = MainMenu.DARK
		"off":
			sb = _box(s, Color(MainMenu.PANEL, 0.6), Color(MainMenu.EDGE, 0.6))
			col = MainMenu.OFF
		_:
			sb = _box(s, Color(MainMenu.PANEL, 0.88), MainMenu.EDGE)
	draw.draw_style_box(sb, r)
	UiStyle.label(draw, font, label, r, px, col)


func _box(s: float, fill: Color, edge: Color) -> StyleBoxFlat:
	return UiStyle.box(fill, AddressScreen.RADIUS * s, edge, 2.0 * s if edge.a > 0.0 else 0.0)
