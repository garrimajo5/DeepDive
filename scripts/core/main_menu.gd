class_name MainMenu
extends RefCounted
## Главное меню после заставки прогрева по ART-037 (`docs/concept-art/menyu.md`): «Погружение», «Погрузиться» (одиночный
## забег), «Экипаж» (пока нет сбора ART-028 — экран гостя «Войти по адресу» ART-039, `AddressScreen`), «Журнал экспедиции»
## (ART-047, `Journal`), «Настройки» (`Settings`, возврат в меню), внизу версия
## из `project.godot`. Здесь — состояние, кнопки и раскладка без узлов; рисует `scripts/game/menu_panel.gd`
## (`main.menu_panel`), шаг — `MenuFlow.menu_step`. Макет 2400×1080 на фоне заставки: масштаб и обрезка боков — `Splash`.
## Места текста — левый край и верх видимых глифов, как в заметке художника.
## Кампания слоя 1 (#823): есть сохранённый корабль (`SaveGame.ship`) — сверху «Продолжить» (главная кнопка, `can_continue`),
## кнопок пять, они плотнее (`BUTTON_5`, `STEP_5`), чтобы низ остался над строкой версии.

const TITLE := "Погружение"
const TITLE_AT := Vector2(360, 230)
const TITLE_PX := 104.0
const BUTTON := Rect2(360, 420, 680, 112)   ## первая кнопка; следующие ниже на STEP
const STEP := 144.0
const BUTTON_5 := Rect2(360, 380, 680, 104)   ## пять кнопок (с «Продолжить»): первая
const STEP_5 := 124.0
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
const CONTINUE := ["continue", "Продолжить"]   ## над «Погрузиться», если есть сохранённый корабль (#823)

var open := false
## Есть сохранённый корабль: сверху «Продолжить», главная кнопка — она.
var can_continue := false
## Какие кнопки работают.
var enabled := {"continue": true, "dive": true, "crew": true, "journal": true, "settings": true}


## Кнопки сверху вниз: с «Продолжить» (cont) или без.
static func items_of(cont: bool) -> Array:
	return [CONTINUE] + ITEMS if cont else ITEMS


func items() -> Array:
	return items_of(can_continue)


## Главная (выделенная) кнопка: «Продолжить», если она есть, иначе «Погрузиться».
func main_item() -> String:
	return CONTINUE[0] if can_continue else MAIN_ITEM


## Прямоугольник i-й из n кнопок в макете.
static func button_rect(i: int, n: int = ITEMS.size()) -> Rect2:
	if n > ITEMS.size():
		return Rect2(BUTTON_5.position + Vector2(0.0, STEP_5 * i), BUTTON_5.size)
	return Rect2(BUTTON.position + Vector2(0.0, STEP * i), BUTTON.size)


## Прямоугольник кнопки id на экране size (cont — с «Продолжить»).
static func screen_rect(id: String, size: Vector2, cont: bool = false) -> Rect2:
	var list := items_of(cont)
	for i in list.size():
		if list[i][0] == id:
			return Splash.rect_to_screen(button_rect(i, list.size()), size)
	return Rect2()


## Прямоугольник кнопки id в текущем меню.
func rect(id: String, size: Vector2) -> Rect2:
	return screen_rect(id, size, can_continue)


## Строка версии: «Версия 0.1».
static func version_line(v: String) -> String:
	return "Версия %s" % v


## Какая доступная кнопка под касанием p ("" — никакая).
func hit(p: Vector2, size: Vector2) -> String:
	if not open:
		return ""
	return Splash.hit_ids(p, size, items().map(func(it: Array) -> String: return it[0]), rect,
			func(id: String) -> bool: return enabled.get(id, false))


## Нажатие кнопки id. Возвращает, что сделать игре: "continue" — забег с сохранённого места (меню закрыто, только
## при `can_continue`), "dive" — одиночный забег (меню закрыто), "crew" — экран
## «Войти по адресу» поверх меню (меню остаётся открытым: «Назад» вернёт к нему), "journal" — «Журнал экспедиции»
## ART-047 поверх меню (так же), "settings" — настройки поверх меню (так же), "" — ничего.
func press(id: String) -> String:
	if not open or not enabled.get(id, false):
		return ""
	match id:
		"continue":
			if not can_continue:
				return ""
			open = false
			return "continue"
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
