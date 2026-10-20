class_name Run
extends RefCounted
## Маршрут забега (js/run.js): у голостола экипаж выбирает один из трёх маршрутов по местам отмели, на приборах —
## следующая точка и расстояние до неё, на голостоле — отметка точки. Точка пройдена, когда корабль ближе радиуса
## места (по горизонтали); порядок не важен, «следующая» — первая непройденная по списку. Все точки пройдены —
## маршрут закрыт, пора решать: глубже или наверх (голосование — следующая часть этапа «Забег»).
## Места — по карте отмели ART-005 (docs/concept-art/karta-otmeli-mesta.json), радиусы — js/world.js.

## key → [название, (x, z), радиус м]
const PLACES := {
	"flower": ["Каменный цветок", Vector2(40.0, -50.0), 45.0],
	"geyser": ["Чёрный курильщик", Vector2(-126.0, 45.0), 45.0],
	"shell": ["Раковина древних", Vector2(162.0, -36.0), 45.0],
	"bones": ["Кости левиафана", Vector2(-30.0, -148.0), 45.0],
	"well": ["Световой колодец", Vector2(-170.0, -70.0), 50.0],
	"drop": ["Край отмели", Vector2(215.0, 90.0), 55.0],
}
## Маршруты: название, места по порядку, одна строка риска (ART-016, #86).
const ROUTES: Array = [
	{"id": "reef", "name": "Рифовый сад", "places": ["flower", "bones", "well"], "risk": "много серпохвостов"},
	{"id": "vents", "name": "Тёплые трубы", "places": ["geyser", "shell"], "risk": "реактор будет греться"},
	{"id": "edge", "name": "Край отмели", "places": ["well", "drop"], "risk": "оползни: сонарная тьма"},
]

var route := -1           ## индекс в ROUTES, −1 — маршрут не выбран
var visited: Array[String] = []
var done := false


static func place_name(key: String) -> String:
	return PLACES[key][0]


static func place_xz(key: String) -> Vector2:
	return PLACES[key][1]


## Подпись поста у голостола.
func label() -> String:
	return "Маршрут: выбрать" if route < 0 else "Маршрут: сменить"


## Нажатие у голостола: следующий маршрут по кругу, прогресс с нуля. Возвращает сообщение для приборов.
func cycle() -> String:
	return choose((route + 1) % ROUTES.size())


func choose(i: int) -> String:
	route = clampi(i, 0, ROUTES.size() - 1)
	visited.clear()
	done = false
	var r: Dictionary = ROUTES[route]
	var names := PackedStringArray()
	for k in r["places"]:
		names.append(place_name(k))
	return "Маршрут «%s»: %s; %s" % [r["name"], " → ".join(names), r["risk"]]


## Ключ следующей непройденной точки или "".
func next_key() -> String:
	if route < 0:
		return ""
	for k in ROUTES[route]["places"]:
		if not visited.has(k):
			return k
	return ""


## Точка на голостоле: (x, z) следующей точки или Vector2.INF, если её нет.
func waypoint() -> Vector2:
	var k := next_key()
	return place_xz(k) if k != "" else Vector2.INF


## Шаг: корабль в (x, z). Возвращает сообщение, если точка пройдена, иначе "".
func update(x: float, z: float) -> String:
	if route < 0 or done:
		return ""
	var r: Dictionary = ROUTES[route]
	for k in r["places"]:
		if visited.has(k) or Vector2(x, z).distance_to(place_xz(k)) >= float(PLACES[k][2]):
			continue
		visited.append(k)
		var n := next_key()
		if n != "":
			return "Точка маршрута пройдена: %s. Дальше — %s" % [place_name(k), place_name(n)]
		done = true
		return "Маршрут «%s» пройден: глубже или наверх?" % r["name"]
	return ""


## Часть строки состояния: «Рифовый сад 1/3 · Кости левиафана 120 м», пусто без маршрута.
func status(x: float, z: float) -> String:
	if route < 0:
		return ""
	var r: Dictionary = ROUTES[route]
	if done:
		return "маршрут «%s» пройден" % r["name"]
	var n := next_key()
	return "%s %d/%d: %s %d м" % [r["name"], visited.size(), r["places"].size(), place_name(n),
		roundi(Vector2(x, z).distance_to(place_xz(n)))]
