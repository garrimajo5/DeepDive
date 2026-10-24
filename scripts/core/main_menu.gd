class_name MainMenu
extends RefCounted
## Главное меню после заставки прогрева по ART-037 (`docs/concept-art/menyu.md`): «Погружение», «Погрузиться» (одиночный
## забег), «Экипаж» (пока нет сбора ART-028 — экран гостя «Войти по адресу» ART-039, `AddressScreen`), «Журнал экспедиции»
## (ART-047, `Journal`), «Настройки» (`Settings`, возврат в меню), внизу версия
## из `project.godot`. Здесь — состояние, кнопки и раскладка без узлов; рисует `scripts/game/menu_panel.gd`
## (`main.menu_panel`), шаг — `Main._menu_step`. Макет 2400×1080 на фоне заставки: масштаб и обрезка боков — `Splash`.
## Места текста — левый край и верх видимых глифов, как в заметке художника.

const TITLE := "Погружение"
const TITLE_AT := Vector2(360, 230)
const TITLE_PX := 104.0
const BUTTON := Rect2(360, 420, 680, 112)   ## первая кнопка; следующие ниже на STEP
const STEP := 144.0
const BUTTON_PX := 38.0
const RADIUS := 12.0
const VERSION_TOP := 1000.0   ## верх глифов строки версии, по центру макета
const VERSION_PX := 26.0

## Палитра ART-028, красного нет (#129).
const INK := Color("#D5E4E8")        ## текст
const SOFT := Color("#9AD9E8")       ## вторичный: версия
const MAIN := Color("#67DDEB")       ## главное действие (текст на нём тёмный)
const DARK := Color("#0B1C24")
const PANEL := Color("#102B37")
const EDGE := Color("#32616D")
const OFF := Color("#6E909A")        ## неактивное

## Кнопки сверху вниз: id, подпись.
const ITEMS := [["dive", "Погрузиться"], ["crew", "Экипаж"], ["journal", "Журнал экспедиции"], ["settings", "Настройки"]]
const MAIN_ITEM := "dive"

var open := false
## Какие кнопки работают.
var enabled := {"dive": true, "crew": true, "journal": true, "settings": true}


## Прямоугольник i-й кнопки в макете.
static func button_rect(i: int) -> Rect2:
	return Rect2(BUTTON.position + Vector2(0.0, STEP * i), BUTTON.size)


## Прямоугольник кнопки id на экране size.
static func screen_rect(id: String, size: Vector2) -> Rect2:
	for i in ITEMS.size():
		if ITEMS[i][0] == id:
			return Splash.rect_to_screen(button_rect(i), size)
	return Rect2()


## Строка версии: «Версия 0.1».
static func version_line(v: String) -> String:
	return "Версия %s" % v


## Какая доступная кнопка под касанием p ("" — никакая).
func hit(p: Vector2, size: Vector2) -> String:
	if not open:
		return ""
	for it: Array in ITEMS:
		if enabled.get(it[0], false) and screen_rect(it[0], size).has_point(p):
			return it[0]
	return ""


## Нажатие кнопки id. Возвращает, что сделать игре: "dive" — одиночный забег (меню закрыто), "crew" — экран
## «Войти по адресу» поверх меню (меню остаётся открытым: «Назад» вернёт к нему), "journal" — «Журнал экспедиции»
## ART-047 поверх меню (так же), "settings" — настройки поверх меню (так же), "" — ничего.
func press(id: String) -> String:
	if not open or not enabled.get(id, false):
		return ""
	match id:
		"dive":
			open = false
			return "dive"
		"crew":
			return "crew"
		"journal":
			return "journal"
		"settings":
			return "settings"
	return ""
