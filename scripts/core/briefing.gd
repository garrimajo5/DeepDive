class_name Briefing
extends RefCounted
## Голограмма брифинга над голостолом (ART-016, docs/concept-art/golostol-brifing.md): пока игрок у поста «Маршрут»,
## сонар над столом сменяет карта всей отмели — неподвижная, нос (−Z) вверх, +X вправо, 700 × 700 м во вписанный
## квадрат 1,13 м; склон к месту 10 за восточным краем — полосой `EAST_*` у ближнего (+X) края, в сжатом масштабе (#829). На ней все 11 мест слоя с номерами (#829) и маршруты `Run.ROUTES`: «Рифовый сад» — сплошная линия,
## «Тёплые трубы» — длинный пунктир, «Край отмели» — точки, маршруты слоя 1 — те же три типа по кругу (`dash`);
## выбранный ярче и толще, по нему бежит подсветка.
## Здесь — числа и геометрия без узлов; рисует `SonarView` (шейдер sonar_holo).

const SIDE := 1.13             ## сторона квадрата карты на столе, м
const SCALE := SIDE / 700.0    ## м стола на м мира
## Склон за восточным краем отмели (`Seabed.EAST`, место 10, #822) — полоса за краем квадрата со стороны поста «Маршрут»:
## x мира от 350 до 700 м — в EAST_DEPTH м стола (втрое мельче отмели, иначе не влезает в диск голограммы), z — как на
## отмели, от EAST_Z.x до EAST_Z.y м мира. Отмель на столе — как была (#829).
const EAST_X0 := 350.0
const EAST_DEPTH := 0.18
const EAST_SCALE := EAST_DEPTH / 350.0
const EAST_Z := Vector2(60.0, 340.0)
const FADE := 0.25             ## переход сонар ↔ брифинг, с
const MAX_SEGS := 16           ## столько отрезков держит шейдер
## Номера мест — по таблице ART-016 и карте слоя 1 #818 (`LayerMap`, #829: все 11 мест, старт — «0»).
const NUMBERS := {"flower": 1, "geyser": 2, "shell": 3, "bones": 4, "well": 5, "drop": 6,
	"start": 0, "gate": 7, "field": 8, "cove": 9, "descent": 10}
## Порядок мест в шейдере (`places`, `place_state`) — как в `Run.PLACES`.
const ORDER: Array[String] = ["flower", "geyser", "shell", "bones", "well", "drop", "start", "gate", "field", "cove",
	"descent"]
## Иконки мест (ART-005, `docs/concept-art/ikonka-*.png`, в игре — `textures/places/<ключ>.png`): билборд стоит
## нижним краем на точке места, высота на столе, м. Места не на выбранном маршруте — тусклее.
const ICON_SIZE := 0.13
const ICON_DIM := 0.6
## Номер места — над иконкой. С поста «Маршрут» (взгляд к −X) «Каменный цветок» стоит прямо за «Раковиной древних»,
## и номера ложились на чужие иконки (#194): «1» сдвинут по экрану влево, «3» — вправо, м (x — вправо, y — вверх).
const NUMBER_SHIFT := {"flower": Vector2(-0.09, 0.0), "shell": Vector2(0.08, 0.0)}


static func number_shift(key: String) -> Vector2:
	return NUMBER_SHIFT.get(key, Vector2.ZERO)


## Дальний ряд мест с поста «Маршрут» (взгляд к −X) мельче ближнего втрое — 5, 8, 2, 9 не читались (#829). Номер
## растёт к дальнему краю стола: у ближнего (+X) — как был, у дальнего — в 1 + NUMBER_GROW раз. Цель — номер на экране
## не ниже NUMBER_MIN_PX (1600 × 720, тест test_scene_far_numbers_readable).
const NUMBER_GROW := 0.7
const NUMBER_MIN_PX := 16
## Крупный номер поднят на полвысоты цифры за каждую долю роста — низ цифры не наезжает на иконку, м.
const NUMBER_LIFT := 0.027


## Множитель кегля номера места в точке стола t (Briefing.table_xz).
static func number_scale(t: Vector2) -> float:
	var h := SIDE * 0.5
	return 1.0 + NUMBER_GROW * clampf((h - t.x) / SIDE, 0.0, 1.0)

## Карточка выбранного маршрута (ART-016): экранная надпись у каждого игрока своя, привязана к точке над правым
## (от поста «Маршрут») краем карты — сбоку и чуть выше, не закрывает точки. Точка — в осях голограммы (SonarView).
const CARD_ANCHOR := Vector3(0.0, 0.3, -0.62)
const CARD_GAP := 16.0          ## от точки привязки до левого края карточки, px
const CARD_MARGIN := 24.0       ## от краёв экрана, px
const CARD_TOP_FREE := 150.0    ## сверху — строки приборов, px
const CARD_RIGHT_FREE := 240.0  ## справа — кнопка действия, px
## Карта на столе с иконками и номерами над ней — в осях голограммы: квадрат SIDE и высота подписей, м. Карточка
## ставится мимо её проекции на экран (`map_points`, `card_rect`): на 09c-route она закрывала места 4, 7, 8 (#913).
const MAP_TOP := 0.24
const RISK_COLOR := Color("F1A23D")   ## риск — янтарный


## Страница «Связь» карточки (ART-040, кадр 04 `svyaz-sostoyaniya.png`): кодовое слово забега под маршрутом — одно
## на весь экипаж, по нему отличают своих от «чужого голоса в эфире» (`Comms.code`). Видно, пока открыт брифинг,
## даже если маршрут ещё не выбран.
const CODE_TITLE := "Связь · кодовое слово забега"
## Подсказка — две строки: одной строкой она была самой широкой и сдвигала карточку на карту (#913).
const CODE_HINT: Array[String] = ["Запомните.", "Спросите код, если сомневаетесь."]
const CODE_NOTE := "Один код у всего экипажа"


## Строки страницы «Связь»: заголовок, слово, подсказка (две строки), примечание. Слова нет (гость ещё не знает код хоста) — пусто.
static func code_lines(word: String) -> Array[String]:
	var out: Array[String] = []
	if word.strip_edges() == "":
		return out
	out.append_array([CODE_TITLE, word, CODE_HINT[0], CODE_HINT[1], CODE_NOTE])
	return out


static func icon_path(key: String) -> String:
	return "res://textures/places/%s.png" % key


## Яркость иконки по состоянию места (SonarView.place_states): 0 — не на маршруте — тусклая.
static func icon_alpha(state: float) -> float:
	return ICON_DIM if state < 0.5 else 1.0


## Строки карточки маршрута i: название, места по порядку с номерами карты, риск. Маршрут не выбран — цели слоя
## (`goal_lines`, кампания #824): у стола сначала путь слоя, маршруты — варианты исследования.
static func card_lines(i: int) -> Array[String]:
	if i < 0:
		return goal_lines()
	var out: Array[String] = []
	if i >= Run.ROUTES.size():
		return out
	var r: Dictionary = Run.ROUTES[i]
	out.append(r["name"])
	for k in r["places"]:
		out.append("%d  %s" % [NUMBERS[k], Run.place_name(k)])
	out.append("Риск: " + r["risk"])
	return out


## Цели слоя на карточке у стола, пока маршрут не выбран (#824, часть 3): рекомендуемый путь `LayerMap.MAIN_ROUTE`
## номерами карты, куда он ведёт, что маршруты у стола — варианты, риск последней строкой (янтарным, как у маршрута).
static func goal_lines() -> Array[String]:
	var ids: Array[String] = []
	for id in LayerMap.MAIN_ROUTE:
		ids.append(str(int(id)))
	var last: String = LayerMap.MAIN_ROUTE[-1]
	return [
		"Цели слоя",
		"Путь: " + " – ".join(ids),
		"%s — у места %d" % [LayerMap.POINTS[last]["name"], int(last)],
		"Маршруты у стола — варианты",
		"Риск: " + Run.ROUTES[Run.MAIN]["risk"],
	]


## Где карточка размера size на экране screen, если точка привязки видна в anchor: справа от точки, по её высоте,
## но внутри экрана — ниже строк приборов и левее кнопки действия. map — прямоугольник карты на экране (`map_points`):
## карточка встаёт правее него, но не дальше правого предела — тогда на карту заходит разве что её ближний нижний
## угол (он шире всего в перспективе, мест там нет). Левее карты не ставим: там крестовина (#913).
static func card_rect(anchor: Vector2, size: Vector2, screen: Vector2, map := Rect2()) -> Rect2:
	var x := anchor.x + CARD_GAP
	var y := anchor.y - size.y * 0.5
	var right := maxf(CARD_MARGIN, screen.x - CARD_RIGHT_FREE - size.x)
	if map.has_area():
		x = maxf(x, map.end.x + CARD_GAP)
	x = clampf(x, CARD_MARGIN, right)
	y = clampf(y, CARD_TOP_FREE, maxf(CARD_TOP_FREE, screen.y - CARD_MARGIN - size.y))
	return Rect2(Vector2(x, y), size)


## Углы карты с подписями в осях голограммы: квадрат на столе и он же на высоте номеров (MAP_TOP).
static func map_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var h := SIDE * 0.5
	for y in [0.0, MAP_TOP]:
		for p in [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]:
			out.append(Vector3(p.x, y, p.y))
	return out


## Тип линии маршрута по индексу в Run.ROUTES: 0 — сплошная, 1 — длинный пунктир, 2 — точки; дальше — по кругу.
enum Dash { SOLID, LONG, DOTS }


## Точка мира (x, z) → точка на столе (x, z) от центра голостола, м. Восточнее EAST_X0 — сжатый масштаб склона.
static func table_xz(world: Vector2) -> Vector2:
	var t := world * SCALE
	if world.x > EAST_X0:
		t.x = EAST_X0 * SCALE + (world.x - EAST_X0) * EAST_SCALE
	return t


## Обратно: точка стола → мир (двойник шейдера sonar_holo, `briefing`).
static func world_xz(t: Vector2) -> Vector2:
	var w := t / SCALE
	if t.x > SIDE * 0.5:
		w.x = EAST_X0 + (t.x - SIDE * 0.5) / EAST_SCALE
	return w


## Полоса склона на столе, м: x от края квадрата на EAST_DEPTH, z по EAST_Z.
static func east_rect() -> Rect2:
	return Rect2(SIDE * 0.5, EAST_Z.x * SCALE, EAST_DEPTH, (EAST_Z.y - EAST_Z.x) * SCALE)


## Не ближе к краю стола, м: место и корабль за краем карты стоят у края квадрата или полосы склона со стороны, где
## они есть, иконка не свешивается со стола.
const EDGE_IN := ICON_SIZE * 0.5


## Точка мира (x, z) → точка на столе, прижатая внутрь карты (`EDGE_IN`). Внутри карты — как `table_xz`.
static func on_table(world: Vector2) -> Vector2:
	var h := SIDE * 0.5 - EDGE_IN
	var t := table_xz(world)
	var e := east_rect()
	if t.x > h and t.y > e.position.y + EDGE_IN and t.y < e.end.y - EDGE_IN:
		return Vector2(minf(t.x, e.end.x - EDGE_IN), t.y)   # в полосе склона
	return Vector2(clampf(t.x, -h, h), clampf(t.y, -h, h))


## Тип линии маршрута i (не меняется при выборе — ART-016).
static func dash(i: int) -> int:
	return [Dash.SOLID, Dash.LONG, Dash.DOTS][posmod(i, 3)]


## Отрезки всех маршрутов на столе: {"a", "b" — концы (x, z) стола, "route" — индекс, "start" — путь от начала
## маршрута до a по столу, м}. Порядок — как в Run.ROUTES.
static func segments() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in Run.ROUTES.size():
		var keys: Array = Run.ROUTES[i]["places"]
		var s := 0.0
		for j in keys.size() - 1:
			var a := on_table(Run.place_xz(keys[j]))
			var b := on_table(Run.place_xz(keys[j + 1]))
			out.append({"a": a, "b": b, "route": i, "start": s})
			s += a.distance_to(b)
	return out


## Длина маршрута i по столу, м (для бегущей подсветки).
static func route_length(i: int) -> float:
	var s := 0.0
	for g in segments():
		if g["route"] == i:
			s += (g["a"] as Vector2).distance_to(g["b"])
	return s


## Показывать ли брифинг: игрок стоит у поста «Маршрут», голосование не открыто, забег не окончен.
static func wanted(post_id: String, at_vote: bool, ended: bool) -> bool:
	return post_id == "route" and not at_vote and not ended


## Плавный переход: k растёт к 1, пока брифинг нужен, и падает к 0, когда нет, за FADE секунд.
class Fade:
	extends RefCounted
	var k := 0.0

	func update(dt: float, on: bool) -> float:
		k = clampf(k + (dt if on else -dt) / Briefing.FADE, 0.0, 1.0)
		return k
