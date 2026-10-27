class_name UiStyle
extends RefCounted
## Общее для экранных панелей: цвета надписей на приборах, скруглённая плашка, строки текста `text`/`center`.
## Раньше каждая панель объявляла эти цвета сама и собирала StyleBoxFlat вручную (одни и те же 5–7 строк в 15 файлах).

const TEXT := Color("D5E4E8")     ## основной текст
const DIM := Color("9AD9E8")      ## второстепенный
const OFF := Color("6E909A")      ## погашенное
const ACCENT := Color("67DDEB")   ## голубой акцент (как огни моделей)
const DARK := Color("0B1C24")     ## тёмная подложка


## Плашка: заливка fill, скругление radius (px), рамка edge толщиной width (px, не тоньше 1; 0 — без рамки).
## Размеры уже в пикселях экрана — множитель раскладки умножает вызывающий.
static func box(fill: Color, radius: float, edge := Color(0, 0, 0, 0), width := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(roundi(radius))
	if width > 0.0:
		sb.set_border_width_all(maxi(1, roundi(width)))
		sb.border_color = edge
	return sb


## Кнопка меню, паузы и настроек (ART-037): главная — голубая заливка без рамки; прочие — тёмная панель с рамкой.
## fill_a, edge_a — непрозрачность панели и рамки (погашенная кнопка тусклее), k — общее затухание экрана.
static func menu_button(main: bool, s: float, fill_a := 0.92, edge_a := 1.0, k := 1.0) -> StyleBoxFlat:
	if main:
		return box(Color(MainMenu.MAIN, k), MainMenu.RADIUS * s)
	return box(Color(MainMenu.PANEL, fill_a * k), MainMenu.RADIUS * s, Color(MainMenu.EDGE, edge_a * k), 2.0 * s)


## Окно подтверждения поверх затемнения (пауза, настройки, «Экономно»).
static func dialog(s: float) -> StyleBoxFlat:
	return box(Color(MainMenu.PANEL, 0.97), MainMenu.RADIUS * s, MainMenu.EDGE, 2.0 * s)


## Полноэкранная заливка color в parent, мимо касаний (тёмная подложка под фоном, затемнение поверх).
static func cover(parent: Node, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = color
	parent.add_child(r)
	return r


## Фон заставки ART-034 (`Splash.BG`) на весь экран, обрезан по сторонам (`KEEP_ASPECT_COVERED`), мимо касаний.
static func backdrop(parent: Node) -> TextureRect:
	var bg := TextureRect.new()
	bg.name = "Фон"
	bg.texture = load(Splash.BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	return bg


## Холст панели: Control на весь экран, мимо касаний, рисует draw_fn.
static func canvas(parent: Node, nm: String, draw_fn: Callable) -> Control:
	var c := Control.new()
	c.name = nm
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(draw_fn)
	parent.add_child(c)
	return c


## Полноэкранный экран меню: тёмная подложка dark (если текстура не загрузилась, сцена всё равно закрыта), фон
## заставки, затемнение dim (прозрачное — без него) и холст nm, который рисует draw_fn.
static func screen(parent: Node, nm: String, draw_fn: Callable, dark: Color, dim := Color(0, 0, 0, 0)) -> Control:
	cover(parent, dark)
	backdrop(parent)
	if dim.a > 0.0:
		cover(parent, dim)
	return canvas(parent, nm, draw_fn)


## Строка от верха видимых глифов: at — левый верх заглавных (как в макетах), кегль px (округляется), ширина width
## и выравнивание align — как у draw_string. Раньше у каждой панели была своя копия (`_text`).
static func text(canvas: CanvasItem, font: Font, t: String, at: Vector2, px: float, color: Color, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	canvas.draw_string(font, at + Vector2(0.0, Splash.CAP_H * px), t, align, width, roundi(px), color)


## Строка по центру экрана шириной size.x, верх заглавных — top в осях макета `Splash` (пауза, настройки).
static func center(canvas: CanvasItem, font: Font, t: String, top: float, px: float, color: Color,
		size: Vector2) -> void:
	text(canvas, font, t, Vector2(0.0, Splash.to_screen(Vector2(0.0, top), size).y), px, color, size.x,
		HORIZONTAL_ALIGNMENT_CENTER)
