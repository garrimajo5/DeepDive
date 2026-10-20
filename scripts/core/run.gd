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
var seen: Array[String] = []   ## места, пройденные за забег (без повторов) — строка «Места» итога
var done := false
var depth := 0            ## сколько раз экипаж решил «глубже»: 0 — первый спуск
var routes := 0           ## маршрутов пройдено за забег
var ended := false        ## решили «наверх»: забег окончен, на экране итог
var score := 0
var start := {}           ## счётчики в начале забега: t, груз, виды, пробоины
var _vote_held := true    ## голосование ждёт, пока отпустят крестовину


static func place_name(key: String) -> String:
	return PLACES[key][0]


static func place_xz(key: String) -> Vector2:
	return PLACES[key][1]


## Новый забег: маршрута нет, первый спуск, счётчики с нуля (t — время игры, остальное — как у Run.tally).
func begin(t: float, cargo_n: int, species_n: int, breaches_n: int) -> void:
	route = -1
	visited.clear()
	seen.clear()
	done = false
	depth = 0
	routes = 0
	ended = false
	score = 0
	start = {"t": t, "cargo": cargo_n, "species": species_n, "breaches": breaches_n}


## Подпись поста у голостола.
func label() -> String:
	if done:
		return "Глубже или наверх?"
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
		if not seen.has(k):
			seen.append(k)
		var n := next_key()
		if n != "":
			return "Точка маршрута пройдена: %s. Дальше — %s" % [place_name(k), place_name(n)]
		done = true
		routes += 1
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


## Мнения ролей перед решением (js/run.js R.opinions): [кто, наверх?, почему]. Решает игрок, мнения — подсказка.
static func opinions(hull: float, energy: float, hot: bool, in_silt: bool, cargo_n: int) -> Array:
	return [
		["Пилот", hull < 50.0, "корпус %d%% — второй такой удар не выдержим" % roundi(hull) if hull < 50.0
			else "корабль слушается, можно идти дальше"],
		["Инженер", energy < 40.0 or hot, "реактор перегрет" if hot
			else "энергии %d — не хватит на обратный путь" % floori(energy) if energy < 40.0 else "реактор в норме"],
		["Сонарщик", in_silt, "вокруг ил, мы слепые" if in_silt else "сонар чистый"],
		["Биолог", cargo_n >= 4, "в трюме %d образцов — пора их довезти" % cargo_n if cargo_n >= 4
			else "образцов мало, внизу их больше"],
	]


## Открыть голосование: первое нажатие крестовины после того, как её отпустят.
func open_vote() -> void:
	_vote_held = true


## Крестовина в голосовании (m.y = 1 — вверх): "up", "deep" или "".
func vote_nav(m: Vector2i) -> String:
	if m.y == 0:
		_vote_held = false
		return ""
	if _vote_held:
		return ""
	_vote_held = true
	return "up" if m.y > 0 else "deep"


## «Глубже»: следующий спуск, маршрут выбирать заново. Возвращает сообщение.
func go_deeper() -> String:
	depth += 1
	route = -1
	visited.clear()
	done = false
	return "Глубже: %d-й спуск, хищники чутче на %d %%. Маршрут — у голостола" % [depth + 1,
		roundi(depth * EcoLink.PRED_PER_DIVE * 100.0)]


## «Наверх»: забег окончен, считаем очки (js/run.js R.finish). Строки итога — results().
func finish(t: float, cargo_n: int, species_n: int, breaches_n: int, hull: float) -> Array:
	ended = true
	var rows := results(t, cargo_n, species_n, breaches_n, hull)
	score = maxi(0, species_n - int(start.get("species", 0))) * 10 + maxi(0, cargo_n - int(start.get("cargo", 0))) * 5 \
		+ routes * 20 + depth * 25 + roundi(hull / 10.0)
	return rows


## Итог на голограмме (ART-016): четыре строки [название, значение] — Образцы / Виды / Места / Пробоины за забег.
func summary(cargo_n: int, species_n: int, breaches_n: int) -> Array:
	return [
		["Образцы", str(maxi(0, cargo_n - int(start.get("cargo", 0))))],
		["Виды", str(maxi(0, species_n - int(start.get("species", 0))))],
		["Места", str(seen.size())],
		["Пробоины", str(maxi(0, breaches_n - int(start.get("breaches", 0))))],
	]


## Подробный итог на панели — results() без строк, что уже есть на голограмме (summary): время, спуски, маршруты,
## корпус.
static func detail(rows: Array) -> Array:
	var out := []
	for r in rows:
		if not (r[0] in ["Новых видов в журнале", "Образцов поднято", "Пробоин"]):
			out.append(r)
	return out


## Итог забега: [название, значение].
func results(t: float, cargo_n: int, species_n: int, breaches_n: int, hull: float) -> Array:
	return [
		["Время под водой", "%d мин" % maxi(0, roundi((t - float(start.get("t", 0.0))) / 60.0))],
		["Спусков", str(depth + 1)],
		["Маршрутов пройдено", str(routes)],
		["Новых видов в журнале", str(maxi(0, species_n - int(start.get("species", 0))))],
		["Образцов поднято", str(maxi(0, cargo_n - int(start.get("cargo", 0))))],
		["Пробоин", str(maxi(0, breaches_n - int(start.get("breaches", 0))))],
		["Корпус на финише", "%d%%" % roundi(hull)],
	]
