class_name UiStyle
extends RefCounted
## Общее для экранных панелей: цвета надписей на приборах и скруглённая плашка. Раньше каждая панель объявляла
## эти цвета сама и собирала StyleBoxFlat вручную (одни и те же 5–7 строк в 15 файлах).

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
