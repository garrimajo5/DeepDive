class_name Splash
extends RefCounted
## Заставка на время прогрева шейдеров по ART-034 (`docs/concept-art/zastavka.md`): фон `textures/splash/zastavka-fon.jpg`,
## название, строка состояния, проценты и полоса по доле `Warmup.progress()`, подсказка по кругу раз в HINT_EVERY с.
## Здесь — числа и раскладка без узлов; рисует `scripts/game/warm_splash.gd` (`main.curtain`).
## Макет 2400×1080; места — верх видимых глифов (y) и левый край (x), как в заметке художника.

const BG := "res://textures/splash/zastavka-fon.jpg"
const W := 2400.0
const H := 1080.0

const INK := Color("#D5E4E8")     ## название, проценты, подсказка
const SOFT := Color("#9AD9E8")    ## строка состояния
const FILL := Color("#67DDEB")    ## заполнение полосы
const TRACK := Color("#244955")   ## трек полосы

## Кегли макета, px при высоте 1080.
const TITLE_PX := 104.0
const LINE_PX := 34.0
const HINT_PX := 40.0

const TITLE_AT := Vector2(360, 416)
const STATUS_AT := Vector2(364, 574)
const PERCENT_RIGHT := Vector2(1020, 574)    ## правый край и верх глифов
const BAR := Rect2(360, 636, 660, 12)
const BAR_RADIUS := 6.0
const HINT_TOP := 944.0
const HINT_X := Vector2(560, 1840)           ## подсказка по центру этого отрезка

const HINTS := [
	"Свайп — оглядеться",
	"Крестовина — идти",
	"Кнопка — действие у поста",
	"Голосуйте у голостола: глубже или наверх",
]
const HINT_EVERY := 8.0

## Высота заглавных в долях кегля (шрифт игры): верх глифов ниже верха строки на ascent − CAP_H·кегль.
const CAP_H := 0.72


## Масштаб макета на экран size: фон закрывает экран целиком, лишнее обрезано поровну с двух сторон.
## Телефон уже 2400/1080 — подгонка по высоте, бока обрезаны (19,5:9 — по 30 px макета, 16:9 — по 240 px).
static func scale(size: Vector2) -> float:
	return maxf(size.x / W, size.y / H)


## Сдвиг макета: (размер макета × масштаб − экран) / 2 обрезано с каждой стороны.
static func offset(size: Vector2) -> Vector2:
	var s := scale(size)
	return (Vector2(W, H) * s - size) * 0.5


## Точка макета на экране.
static func to_screen(p: Vector2, size: Vector2) -> Vector2:
	return p * scale(size) - offset(size)


static func rect_to_screen(r: Rect2, size: Vector2) -> Rect2:
	return Rect2(to_screen(r.position, size), r.size * scale(size))


## Кнопка экрана под касанием p — первая из ids, чей прямоугольник rect_of(id, size) содержит p ("" — никакая).
## ok(id) -> bool — работает ли кнопка (пусто — все работают). Общий поиск для экранов меню (#766).
static func hit_ids(p: Vector2, size: Vector2, ids: Array, rect_of: Callable, ok := Callable()) -> String:
	for id: String in ids:
		if (not ok.is_valid() or ok.call(id)) and rect_of.call(id, size).has_point(p):
			return id
	return ""


## Строка состояния: при 100 % — «Готово к погружению».
static func status(p: float) -> String:
	return "Готово к погружению" if p >= 1.0 else "Подготовка погружения"


static func percent(p: float) -> String:
	return "%d %%" % roundi(clampf(p, 0.0, 1.0) * 100.0)


## Подсказка через t с после начала заставки: по кругу раз в HINT_EVERY.
static func hint(t: float) -> String:
	return HINTS[int(floorf(maxf(t, 0.0) / HINT_EVERY)) % HINTS.size()]
