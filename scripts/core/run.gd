class_name Run
extends RefCounted
## Маршрут забега (js/run.js): у голостола экипаж выбирает один из трёх маршрутов по местам отмели, на приборах —
## следующая точка и расстояние до неё, на голостоле — отметка точки. Точка пройдена, когда корабль ближе радиуса
## места (по горизонтали); порядок не важен, «следующая» — первая непройденная по списку. Все точки пройдены —
## маршрут закрыт — можно выбрать следующий. В кампании слоя (#824) пройденный маршрут голосования не открывает:
## «глубже или наверх» — механика решений (`open_vote`), её открывает переход у 10 (`descent`, #828).
## Места — из карты слоя `LayerMap` (#821; ориентиры ART-005 там же), радиусы — js/world.js.

## key → [название, (x, z), радиус м]
const PLACES := {
	"flower": [LayerMap.POINTS["01"]["name"], Vector2(LayerMap.POINTS["01"]["x"], LayerMap.POINTS["01"]["z"]), 45.0],
	"geyser": [LayerMap.POINTS["02"]["name"], Vector2(LayerMap.POINTS["02"]["x"], LayerMap.POINTS["02"]["z"]), 45.0],
	"shell": [LayerMap.POINTS["03"]["name"], Vector2(LayerMap.POINTS["03"]["x"], LayerMap.POINTS["03"]["z"]), 45.0],
	"bones": [LayerMap.POINTS["04"]["name"], Vector2(LayerMap.POINTS["04"]["x"], LayerMap.POINTS["04"]["z"]), 45.0],
	"well": [LayerMap.POINTS["05"]["name"], Vector2(LayerMap.POINTS["05"]["x"], LayerMap.POINTS["05"]["z"]), 50.0],
	"drop": [LayerMap.POINTS["06"]["name"], Vector2(LayerMap.POINTS["06"]["x"], LayerMap.POINTS["06"]["z"]), 55.0],
	# места слоя 1 (#829) — после шести ART-005: порядок ключей — номера мест в сети (NetSnap.run_state)
	"start": [LayerMap.POINTS["00"]["name"], Vector2(LayerMap.POINTS["00"]["x"], LayerMap.POINTS["00"]["z"]), 40.0],
	"gate": [LayerMap.POINTS["07"]["name"], Vector2(LayerMap.POINTS["07"]["x"], LayerMap.POINTS["07"]["z"]), 50.0],
	"field": [LayerMap.POINTS["08"]["name"], Vector2(LayerMap.POINTS["08"]["x"], LayerMap.POINTS["08"]["z"]), 45.0],
	"cove": [LayerMap.POINTS["09"]["name"], Vector2(LayerMap.POINTS["09"]["x"], LayerMap.POINTS["09"]["z"]), 40.0],
	"descent": [LayerMap.POINTS["10"]["name"], Vector2(LayerMap.POINTS["10"]["x"], LayerMap.POINTS["10"]["z"]), 55.0],
}
## Маршруты: название, места по порядку, одна строка риска (ART-016, #86; слой 1 — #829).
const ROUTES: Array = [
	{"id": "reef", "name": "Рифовый сад", "places": ["flower", "bones", "well"], "risk": "много серпохвостов"},
	{"id": "vents", "name": "Тёплые трубы", "places": ["geyser", "shell"], "risk": "реактор будет греться"},
	{"id": "edge", "name": "Край отмели", "places": ["well", "drop"], "risk": "оползни: сонарная тьма"},
	# слой 1 (#829, docs/sloj1-sad.md «Маршруты и связность»): основной путь, петля и ветка к полю — так у мест
	# 07–10 есть точка цели на сонаре. Новые — после трёх ART-016: индексы старых в сети и в тестах не сдвигаются.
	{"id": "main", "name": "Путь к спуску", "places": ["flower", "gate", "shell", "drop", "descent"],
		"risk": "за краем — склон до 290 м"},
	{"id": "loop", "name": "Петля к террасе", "places": ["cove", "geyser", "well", "bones", "gate"],
		"risk": "долгий путь: заряд и реактор"},
	{"id": "field", "name": "Поле у врат", "places": ["gate", "field"], "risk": "дальше поля не идти"},
]

## Индекс маршрута «Путь к спуску» — основной путь слоя (`LayerMap.MAIN_ROUTE`, цели у стола — `Briefing.goal_lines`).
const MAIN := 3

## Сообщение о выборе маршрута — не длиннее строки приборов слева от карточки у стола (#938).
const LINE_MAX := 64

var route := -1           ## индекс в ROUTES, −1 — маршрут не выбран
var visited: Array[String] = []
var seen: Array[String] = []   ## места, пройденные за забег (без повторов) — строка «Места» итога
var done := false
var voting := false       ## открыто голосование у стола (`open_vote`): маршрут им больше не кончается (#824)
var depth := 0            ## сколько раз экипаж решил «глубже»: 0 — первый спуск
var routes := 0           ## маршрутов пройдено за забег
var ended := false        ## решили «наверх»: забег окончен, на экране итог
var score := 0
var start := {}           ## счётчики в начале забега: t, груз, виды, пробоины
var _vote_held := true    ## голосование ждёт, пока отпустят крестовину
var _at_descent := false  ## корабль в круге спуска 10 (`descent`): предупреждение — один раз на вход

## Переход к Кристальному лесу у места 10 (#828, часть 1): корабль вошёл в круг места — предупреждение и голосование
## «глубже или наверх» у голостола (`voting`); ушёл дальше DESCENT_LEAVE — голосование закрыто, если не решили.
const DESCENT := "descent"   ## ключ места 10 в PLACES
const DESCENT_LEAVE := 1.5     ## доля радиуса места 10: дальше — корабль ушёл от спуска
const DESCENT_MSG := "Впереди более глубокий слой. Решение — у голостола"
const DESCENT_OFF_MSG := "Спуск позади: голосование закрыто"


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
	voting = false
	_at_descent = false
	depth = 0
	routes = 0
	ended = false
	score = 0
	start = {"t": t, "cargo": cargo_n, "species": species_n, "breaches": breaches_n}


## Подпись поста у голостола.
func label() -> String:
	if voting:
		return "Глубже или наверх?"
	return "Маршрут: выбрать" if route < 0 or done else "Маршрут: сменить"


## Нажатие у голостола: следующий маршрут по кругу, прогресс с нуля. Возвращает сообщение для приборов.
func cycle() -> String:
	return choose((route + 1) % ROUTES.size())


func choose(i: int) -> String:
	route = clampi(i, 0, ROUTES.size() - 1)
	visited.clear()
	done = false
	var r: Dictionary = ROUTES[route]
	var n: int = r["places"].size()
	# места и риск — в карточке у стола; полный список в строке приборов шёл на две строки и ложился
	# на номера мест голостола (#938) — здесь только число мест и риск
	var msg := "Маршрут «%s»: %d %s; %s" % [r["name"], n, places_word(n), r["risk"]]
	return msg if msg.length() <= LINE_MAX else "Маршрут «%s»: %d %s" % [r["name"], n, places_word(n)]


## «место», «места», «мест» по числу.
static func places_word(n: int) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return "место"
	if n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
		return "места"
	return "мест"


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
		return "Маршрут «%s» пройден. Следующий — у голостола" % r["name"]
	return ""


## Шаг перехода у 10: корабль в (x, z). Вход в круг места 10 — голосование открыто, `DESCENT_MSG`; уход дальше
## `DESCENT_LEAVE` радиусов — нерешённое голосование закрыто, `DESCENT_OFF_MSG`. Иначе "". После «глубже» корабль
## ещё в круге — повторного предупреждения нет, пока он не выйдет и не вернётся.
func descent(x: float, z: float) -> String:
	if ended:
		return ""
	var d := Vector2(x, z).distance_to(place_xz(DESCENT))
	var r := float(PLACES[DESCENT][2])
	if not _at_descent and d < r:
		_at_descent = true
		if not seen.has(DESCENT):
			seen.append(DESCENT)
		if voting:
			return ""
		open_vote()
		return DESCENT_MSG
	if _at_descent and d > r * DESCENT_LEAVE:
		_at_descent = false
		if voting:
			voting = false
			return DESCENT_OFF_MSG
	return ""


## Корабль в круге места 10 (вход в него открыл голосование спуска): «глубже» здесь — уход к Кристальному лесу.
func at_descent() -> bool:
	return _at_descent


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
	voting = true
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
	voting = false
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
