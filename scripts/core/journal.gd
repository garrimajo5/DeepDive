class_name Journal
extends RefCounted
## Экран «Журнал экспедиции» ART-047 (`docs/concept-art/zhurnal-ekspedicii.md`) из главного меню: карта отмели с
## отметками мест, сводка, строки под картой, «Назад». Данные — `Expedition` (история в сохранении), изученные виды и
## груз. Здесь — состояние, раскладка и строки без узлов; рисует `scripts/game/journal_panel.gd` (`main.journal_panel`),
## шаг — `MenuFlow.journal_step`. Сетка видов 3×2 по каталогу (`Species.ids`): изученный — имя и «новое», пока карточка
## не открыта (`Expedition.mark_read`); неизученный — «?» без имени, касание — «Изучите вид сканером». Карточка вида —
## текст `Lab.card_lines`, «Закрыть»; системная «Назад» сначала закрывает её.
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
## Карта — все 11 мест слоя 1 (#829, `LayerMap`, вместе с террасой врат и спуском к лесу у 10): масштаб мельче макета
## (0,95 px/м), кнопки 96 px; близкие (старт 00 и заводь 09) раздвинуты `place_spot` — точки не налезают.
## Склон за восточным краем (место 10, #822) — полоса справа от отмели в сжатом масштабе `EAST_PX`, как на голостоле
## (`Briefing.EAST_X0`): x мира 350…700 м — в 88 px (`east_rect`), отмель сдвинута влево, подпись `SLOPE`.
const PLACE_BUTTON := 96.0                 ## кнопка места на карте (не меньше 96 px — палец)
const PLACE_ICON := 70.0
const PLACE_GAP := 6.0                     ## между кнопками мест, px
const PX_PER_M := 0.95                     ## 1 px макета ≈ 1,05 м (отмель)
const MAP_CENTER := Vector2(290, 555)      ## от (L, 0): точка (0, 0) отмели
const EAST_X0 := Briefing.EAST_X0          ## восточный край отмели, м мира
const EAST_PX := 0.25                      ## склон: px макета на м мира (вчетверо мельче отмели)
const EAST_END := 700.0                    ## дальний край склона, м мира
const SLOPE := "склон"
const SLOPE_PX := 24.0
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
## Сетка видов (от R): заголовок «Виды · 1–6 из N», ячейки 280×160 шагом 300×180, «Ранее» / «Далее», номер страницы.
const GRID_TITLE_TOP := 505.0
const GRID_TITLE_PX := 30.0
const GRID_AT := Vector2(0, 550)
const CELL := Vector2(280, 160)
const CELL_STEP := Vector2(300, 180)
const COLS := 3
const PER_PAGE := 6
const CELL_NAME_PX := 28.0
const CELL_ASK_PX := 52.0                  ## «?»
const CELL_OFF := "Не изучен"
const CELL_HINT := ["Изучите вид", "сканером"]
const NEW_BADGE := Vector2(139, 39)        ## «новое» в правом верхнем углу ячейки
const NEW_TEXT := "новое"
const PREV := Rect2(0, 922, 240, 112)      ## от R
const NEXT := Rect2(660, 922, 240, 112)
const PAGE_CENTER := Vector2(450, 978)     ## от R: номер страницы «1 / 5»
## Карточка вида 1320×715 по центру экрана: картинка слева, текст `Lab.card_lines` справа, «Закрыть».
const CARD := Vector2(1320, 715)
const CARD_PIC := Rect2(48, 190, 500, 230)       ## от угла карточки
const CARD_TEXT := Vector2(600, 196)             ## от угла: первая строка наблюдений
const CARD_TEXT_W := 672.0
const CARD_CLOSE := Rect2(912, 555, 360, 112)    ## от угла
const CARD_LAST := "Последнее наблюдение"

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
var page := 0           ## страница сетки видов, с 0
var card := ""          ## открытая карточка вида ("" — нет)
var asked := ""         ## неизученный вид, которого коснулись: в ячейке «Изучите вид сканером»
var blank := false      ## журнал пуст (`empty`): карты и сетки на экране нет — касания мимо них


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


## Центр места key на экране: точка макета `place_spot` от (L, 0) (север −Z вверх).
static func place_center(key: String, size: Vector2) -> Vector2:
	return (place_spot(key) + Vector2(left(size), 0.0)) * scale(size)


static var _spots := {}


## Точка мира (x, z) → точка карты, px макета от (L, 0): отмель — PX_PER_M, восточнее EAST_X0 — сжатый склон.
static func map_point(xz: Vector2) -> Vector2:
	var p := MAP_CENTER + xz * PX_PER_M
	if xz.x > EAST_X0:
		p.x = MAP_CENTER.x + EAST_X0 * PX_PER_M + (xz.x - EAST_X0) * EAST_PX
	return p


## Полоса склона на экране: от восточного края отмели до EAST_END по x, во всю высоту карты.
static func east_rect(size: Vector2) -> Rect2:
	var x0 := MAP_CENTER.x + EAST_X0 * PX_PER_M
	var x1 := MAP_CENTER.x + EAST_X0 * PX_PER_M + (EAST_END - EAST_X0) * EAST_PX
	return to_screen(Rect2(x0, MAP.position.y, x1 - x0, MAP.size.y), size)


## Центр кнопки места key на карте, px макета от (L, 0): `map_point` (u = 290 + 0,95·x, v = 555 + 0,95·z), затем кнопки, что
## налезают, раздвинуты по оси меньшего перекрытия (поровну) и оставлены внутри карты. Детерминированно, один раз.
static func place_spot(key: String) -> Vector2:
	if _spots.is_empty():
		_spots = _layout()
	return _spots[key]


static func _layout() -> Dictionary:
	var keys: Array = Run.PLACES.keys()
	var at: Array[Vector2] = []
	for k: String in keys:
		at.append(map_point(Run.place_xz(k)))
	var need := PLACE_BUTTON + PLACE_GAP
	var half := PLACE_BUTTON * 0.5 + PLACE_GAP
	for _pass in 40:
		var moved := false
		for i in at.size():
			for j in range(i + 1, at.size()):
				var d := at[j] - at[i]
				var ox := need - absf(d.x)
				var oy := need - absf(d.y)
				if ox <= 0.0 or oy <= 0.0:
					continue
				moved = true
				var push := Vector2(signf(d.x) if d.x != 0.0 else 1.0, 0.0) * ox if ox < oy \
					else Vector2(0.0, signf(d.y) if d.y != 0.0 else 1.0) * oy
				at[i] -= push * 0.5
				at[j] += push * 0.5
		for i in at.size():
			at[i] = at[i].clamp(MAP.position + Vector2(half, half), MAP.end - Vector2(half, half))
		if not moved:
			break
	var out := {}
	for i in keys.size():
		out[keys[i]] = at[i]
	return out


## Подпись «граница» у площадки 08 (#829): тонкая строка под её кнопкой, только когда поле замечено
## (`LayerLore.FIELD08`) — пояс поля на карте не рисуется стеной.
const BORDER := "граница"
const BORDER_PX := 24.0
const BORDER_H := 30.0
const BORDER_W := 140.0


static func border_shown(lore: LayerLore) -> bool:
	return lore != null and lore.knows(LayerLore.FIELD08)


static func border_rect(size: Vector2) -> Rect2:
	var b := place_rect(LayerMap.POINTS["08"]["key"], size)
	var s := scale(size)
	var map := map_rect(size)   # 08 у западного края карты — подпись не вылезает за карту
	var x := clampf(b.get_center().x - BORDER_W * 0.5 * s, map.position.x, map.end.x - BORDER_W * s)
	return Rect2(Vector2(x, b.end.y + 2.0 * s), Vector2(BORDER_W, BORDER_H) * s)


static func place_rect(key: String, size: Vector2) -> Rect2:
	var side := PLACE_BUTTON * scale(size)
	return Rect2(place_center(key, size) - Vector2(side, side) * 0.5, Vector2(side, side))


## Страниц сетки видов: по 6 из каталога.
static func pages() -> int:
	return maxi(1, ceili(Species.count() / float(PER_PAGE)))


## Виды на странице n — порядок каталога.
static func page_ids(n: int) -> Array[String]:
	return Species.ids().slice(n * PER_PAGE, (n + 1) * PER_PAGE)


## Заголовок сетки: «Виды · 1–6 из 26».
static func grid_title(n: int) -> String:
	var ids := page_ids(n)
	var a := n * PER_PAGE + 1
	return "Виды · %d–%d из %d" % [a, a + ids.size() - 1, Species.count()]


static func cell_rect(i: int, size: Vector2) -> Rect2:
	var at := GRID_AT + Vector2(i % COLS, floorf(i / float(COLS))) * CELL_STEP
	return to_screen(Rect2(at, CELL), size, true)


static func prev_rect(size: Vector2) -> Rect2:
	return to_screen(PREV, size, true)


static func next_rect(size: Vector2) -> Rect2:
	return to_screen(NEXT, size, true)


static func page_center(size: Vector2) -> Vector2:
	return to_screen(Rect2(PAGE_CENTER, Vector2.ZERO), size, true).position


## Карточка по центру экрана.
static func card_rect(size: Vector2) -> Rect2:
	var s := scale(size)
	return Rect2(size * 0.5 - CARD * s * 0.5, CARD * s)


## Прямоугольник от угла карточки на экране.
static func in_card(r: Rect2, size: Vector2) -> Rect2:
	var s := scale(size)
	return Rect2(card_rect(size).position + r.position * s, r.size * s)


static func close_rect(size: Vector2) -> Rect2:
	return in_card(CARD_CLOSE, size)


## Номер изученного вида среди изученных (порядок каталога) и их число — для «ЖУРНАЛ · ВИД n ИЗ m».
static func card_index(id: String, scanned: Dictionary) -> Vector2i:
	var n := 0
	var at := 0
	for k in Species.ids():
		if scanned.has(k):
			n += 1
			if k == id:
				at = n
	return Vector2i(at, n)


## Строки карточки: `Lab.card_lines` с номером среди изученных.
static func card_text(sc: Scanner, id: String) -> PackedStringArray:
	var n := card_index(id, sc.scanned)
	return Lab.card_lines(sc, id, n.x, n.y)


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
	page = 0
	card = ""
	asked = ""


## Что под касанием: "back", "place:<ключ>", "species:<вид>", "prev", "next", "close" или "". Открыта карточка —
## ловит только «Закрыть»; пустой журнал — только «Назад».
func hit(p: Vector2, size: Vector2) -> String:
	if not open:
		return ""
	if card != "":
		return "close" if close_rect(size).has_point(p) else ""
	if back_rect(size).has_point(p):
		return "back"
	if blank:
		return ""
	var k := Splash.hit_ids(p, size, Run.PLACES.keys(), place_rect)
	if k != "":
		return "place:" + k
	var ids := page_ids(page)
	for i in ids.size():
		if cell_rect(i, size).has_point(p):
			return "species:" + ids[i]
	if prev_rect(size).has_point(p):
		return "prev"
	if next_rect(size).has_point(p):
		return "next"
	return ""


## Нажатие: "back" — журнал закрыт, вернуться в меню; место — его название под картой (забег не начинается);
## изученный вид — карточка («новое» снято в e), неизученный — подсказка в ячейке; «Ранее» / «Далее» на краях
## неактивны; «Закрыть» — карточка закрыта. scanned — изученные виды (`Scanner.scanned`).
func press(id: String, scanned: Dictionary = {}, e: Expedition = null) -> String:
	if not open:
		return ""
	if id == "back":
		return back()
	if id == "close":
		card = ""
		return "card"
	if id.begins_with("place:"):
		picked = id.substr(6)
		return "place"
	if id.begins_with("species:"):
		var k := id.substr(8)
		if scanned.has(k):
			card = k
			asked = ""
			if e:
				e.mark_read(k)
			return "card"
		asked = k
		return "ask"
	if id == "prev" and page > 0:
		page -= 1
		asked = ""
		return "page"
	if id == "next" and page < pages() - 1:
		page += 1
		asked = ""
		return "page"
	return ""


## Системная «Назад»: сначала карточка, потом журнал.
func back() -> String:
	if card != "":
		card = ""
		return "card"
	open = false
	card = ""
	asked = ""
	picked = ""
	return "back"
