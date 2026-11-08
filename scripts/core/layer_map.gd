class_name LayerMap
extends RefCounted
## Слой 1 «Подлёдный сад» — один источник мест и маршрутов (#821, карта и спецификация — #818,
## `docs/concept-art/karta-sloj1-mesta.json`). Отсюда берут координаты `Run.PLACES` (а через него брифинг и журнал).
## Глубина точки — уровень корабля у ориентира, **не высота дна**. Шесть ориентиров ART-005 и старт не двигаются.

## id → место: ключ в `Run.PLACES` (все 11 — на голостоле и в журнале, #829), название, x, глубина ориентира м, z, принято
## (false — «предложение» карты #818, место ещё строится).
const POINTS := {
	"00": {"key": "start", "name": "Старт «Ковчега-7»", "x": 0.0, "depth": 30.0, "z": 95.0, "accepted": true},
	"01": {"key": "flower", "name": "Каменный цветок", "x": 40.0, "depth": 42.0, "z": -50.0, "accepted": true},
	"02": {"key": "geyser", "name": "Чёрный курильщик", "x": -126.0, "depth": 40.0, "z": 45.0, "accepted": true},
	"03": {"key": "shell", "name": "Раковина древних", "x": 162.0, "depth": 44.0, "z": -36.0, "accepted": true},
	"04": {"key": "bones", "name": "Кости левиафана", "x": -30.0, "depth": 46.0, "z": -148.0, "accepted": true},
	"05": {"key": "well", "name": "Световой колодец", "x": -170.0, "depth": 20.0, "z": -70.0, "accepted": true},
	"06": {"key": "drop", "name": "Край отмели", "x": 215.0, "depth": 60.0, "z": 90.0, "accepted": true},
	"07": {"key": "gate", "name": "Терраса врат", "x": -100.0, "depth": 35.0, "z": -240.0, "accepted": false},
	"08": {"key": "field", "name": "Наблюдение поля", "x": -250.0, "depth": 35.0, "z": -210.0, "accepted": false},
	"09": {"key": "cove", "name": "Тихая заводь", "x": -80.0, "depth": 32.0, "z": 160.0, "accepted": false},
	"10": {"key": "descent", "name": "Спуск к лесу", "x": 560.0, "depth": 290.0, "z": 200.0, "accepted": false},
}
## Места, сдвинутые после карты #818 (`karta-sloj1-mesta.json` — как сдал художник), id → (x, z) на карте #818.
## 10 — на дно склона за восточным краем (#822, решение владельца 27.10 — склон расширением карты): у (260, 245)
## дно ~60 м, до 290 м там не спуститься; у (560, 200) дно ~306 м, корабль на 290 м — в котловине склона.
const MOVED := {"10": Vector2(260.0, 245.0)}
## Основной маршрут слоя (по порядку).
const MAIN_ROUTE: Array[String] = ["00", "01", "07", "03", "06", "10"]
## Петли и ответвления (по порядку).
const LINKS: Array = [["00", "09", "02", "05", "04", "07"], ["07", "08"], ["01", "03"]]
## Границы карты по x и z, м.
const BOUNDS := Vector2(-350.0, 350.0)


## (x, z) места id.
static func xz(id: String) -> Vector2:
	var p: Dictionary = POINTS[id]
	return Vector2(p["x"], p["z"])


## Точка ориентира в мире: глубина — уровень корабля (y = −глубина).
static func at(id: String) -> Vector3:
	var p: Dictionary = POINTS[id]
	return Vector3(p["x"], -float(p["depth"]), p["z"])


## id места по ключу `Run.PLACES`; "" — нет такого.
static func id_of(key: String) -> String:
	for id: String in POINTS:
		if POINTS[id]["key"] == key:
			return id
	return ""


## Все отрезки маршрутов слоя [id, id] без повторов: основной, петли, ответвления.
static func segments() -> Array:
	var out: Array = []
	for path: Array in [MAIN_ROUTE] + LINKS:
		for i in path.size() - 1:
			var s := [path[i], path[i + 1]]
			if not out.has(s) and not out.has([s[1], s[0]]):
				out.append(s)
	return out
