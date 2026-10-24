class_name Journal
extends RefCounted
## Экран «Журнал экспедиции» ART-047 (`docs/concept-art/zhurnal-ekspedicii.md`) из главного меню: карта отмели с
## отметками мест, сводка, строки под картой, «Назад». Данные — `Expedition` (история в сохранении), изученные виды и
## груз. Здесь — состояние, раскладка и строки без узлов; рисует `scripts/game/journal_panel.gd` (`main.journal_panel`),
## шаг — `Main._journal_step`. Сетка видов и карточка — следующая часть ART-047.
## Раскладка — макет высотой 1080 (масштаб H/1080, кегли и кнопки не сжимаются), контент 1680 по центру:
## L = (W − 1680)/2, R = L + 780, где W — ширина экрана в px макета.

const CONTENT_W := 1680.0
const RIGHT := 780.0                       ## R − L
const TITLE := "Журнал экспедиции"
const TITLE_AT := Vector2(0, 65)           ## от L; верх глифов
const TITLE_PX := 56.0
const BACK := Rect2(1380, 52, 300, 112)    ## от L
const MAP := Rect2(0, 270, 730, 570)       ## от L
const MAP_NAME := "Подлёдный сад"
const MAP_NAME_TOP := 215.0
const NORTH := "север вверх"
const LABEL_PX := 34.0
const PLACE_BUTTON := 112.0                ## кнопка места на карте
const PLACE_ICON := 80.0
const PX_PER_M := 1.25                     ## 1 px макета = 0,8 м
const MAP_CENTER := Vector2(365, 560)      ## от (L, 0): точка (0, 0) отмели
const SUMMARY_AT := Vector2(64, 219)       ## от (R, 0): верх глифов первой строки
const SUMMARY_STEP := 67.0
const SUMMARY_PX := 36.0
const SUMMARY_ICON := 48.0
const FOOT_AT := Vector2(24, 870)          ## от L: строки под картой
const FOOT_STEP := [0.0, 52.0, 100.0]
const FOOT_PX := [32.0, 32.0, 26.0]
const EMPTY_LINE := "Начните погружение — и журнал оживёт."
const BROKEN_LINE := "Сохранение было повреждено — журнал ведётся заново"
const NO_HISTORY := "История посещений ещё не записана"
const ROUTE_HINT := "Маршрут выбирайте у голостола"
const NO_VALUE := "—"

## Палитра ART-028, красного и янтарного нет.
const INK := Color("#D5E4E8")
const SOFT := Color("#9AD9E8")
const MAIN := Color("#67DDEB")
const DARK := Color("#0B1C24")
const PANEL := Color("#102B37")
const EDGE := Color("#32616D")
const OFF := Color("#6E909A")

var open := false
var picked := ""        ## место, которого коснулись на карте ("" — нет): название под картой


## Масштаб макета на экран size (по высоте).
static func scale(size: Vector2) -> float:
	return size.y / 1080.0


## Левый край контента L в px макета.
static func left(size: Vector2) -> float:
	return (size.x / scale(size) - CONTENT_W) * 0.5


## Прямоугольник макета от (L + dx, 0) на экране.
static func to_screen(r: Rect2, size: Vector2, from_right := false) -> Rect2:
	var s := scale(size)
	var x0 := left(size) + (RIGHT if from_right else 0.0)
	return Rect2((r.position + Vector2(x0, 0.0)) * s, r.size * s)


static func back_rect(size: Vector2) -> Rect2:
	return to_screen(BACK, size)


static func map_rect(size: Vector2) -> Rect2:
	return to_screen(MAP, size)


## Центр места key на экране: u = L + 365 + 1,25·x, v = 560 + 1,25·z (север −Z вверх).
static func place_center(key: String, size: Vector2) -> Vector2:
	var p := Run.place_xz(key)
	var at := MAP_CENTER + p * PX_PER_M
	return (at + Vector2(left(size), 0.0)) * scale(size)


static func place_rect(key: String, size: Vector2) -> Rect2:
	var side := PLACE_BUTTON * scale(size)
	return Rect2(place_center(key, size) - Vector2(side, side) * 0.5, Vector2(side, side))


## Журнал пуст: ни мест, ни забегов, ни видов, ни груза — «Начните погружение».
static func empty(e: Expedition, species_n: int, cargo_n: int) -> bool:
	return e.places.is_empty() and e.runs == 0 and species_n == 0 and cargo_n == 0


## Сводка: [иконка ART-026 или "", строка]. Знаменатель видов — настоящий каталог; образцы — без «из 24», пока
## ёмкость трюма не утверждена. Неизвестная история (старое сохранение) — «—», а не ноль.
static func summary(e: Expedition, species_n: int, cargo_n: int, species_total: int) -> Array:
	var unknown := not e.full
	return [
		[VoteHolo.summary_icon("Виды"), "Видов изучено %d из %d" % [species_n, species_total]],
		[VoteHolo.summary_icon("Образцы"), "Образцов в трюме %d" % cargo_n],
		["", "Забегов %s" % (NO_VALUE if unknown and e.runs == 0 else str(e.runs))],
		["", "Глубже всего %s" % (NO_VALUE if unknown and e.deepest == 0 else "%d м" % e.deepest)],
	]


## Строки под картой: [текст, цвет]. Выбранное место — его название и посещено ли; дальше — «Дальше: <место>» по
## настоящей истории и подсказка про голостол.
func footer(e: Expedition) -> Array:
	var out: Array = []
	if picked != "":
		out.append(["%s · %s" % [Run.place_name(picked), "посещено" if e.visited(picked) else "не посещено"], INK])
	elif not e.full and e.places.is_empty():
		out.append([NO_HISTORY, INK])
	else:
		out.append(["Посещено %d из %d" % [e.places.size(), Run.PLACES.size()], INK])
	var n := e.next_place()
	if n != "":
		out.append(["Дальше: %s" % Run.place_name(n), SOFT])
		out.append([ROUTE_HINT, SOFT])
	return out


func show() -> void:
	open = true
	picked = ""


## Что под касанием: "back", "place:<ключ>" или "".
func hit(p: Vector2, size: Vector2) -> String:
	if not open:
		return ""
	if back_rect(size).has_point(p):
		return "back"
	for k: String in Run.PLACES:
		if place_rect(k, size).has_point(p):
			return "place:" + k
	return ""


## Нажатие: "back" — журнал закрыт, вернуться в меню; место — его название под картой (забег не начинается).
func press(id: String) -> String:
	if not open:
		return ""
	if id == "back":
		return back()
	if id.begins_with("place:"):
		picked = id.substr(6)
		return "place"
	return ""


## Системная «Назад»: закрыть журнал.
func back() -> String:
	open = false
	picked = ""
	return "back"
