class_name Briefing
extends RefCounted
## Голограмма брифинга над голостолом (ART-016, docs/concept-art/golostol-brifing.md): пока игрок у поста «Маршрут»,
## сонар над столом сменяет карта всей отмели — неподвижная, нос (−Z) вверх, +X вправо, 700 × 700 м во вписанный
## квадрат 1,13 м. На ней все 11 мест слоя с номерами (#829) и три маршрута `Run.ROUTES`: «Рифовый сад» — сплошная линия,
## «Тёплые трубы» — длинный пунктир, «Край отмели» — точки; выбранный ярче и толще, по нему бежит подсветка.
## Здесь — числа и геометрия без узлов; рисует `SonarView` (шейдер sonar_holo).

const SIDE := 1.13             ## сторона квадрата карты на столе, м
const SCALE := SIDE / 700.0    ## м стола на м мира
const FADE := 0.25             ## переход сонар ↔ брифинг, с
const MAX_SEGS := 8            ## столько отрезков держит шейдер
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

## Карточка выбранного маршрута (ART-016): экранная надпись у каждого игрока своя, привязана к точке над правым
## (от поста «Маршрут») краем карты — сбоку и чуть выше, не закрывает точки. Точка — в осях голограммы (SonarView).
const CARD_ANCHOR := Vector3(0.0, 0.3, -0.62)
const CARD_GAP := 16.0          ## от точки привязки до левого края карточки, px
const CARD_MARGIN := 24.0       ## от краёв экрана, px
const CARD_TOP_FREE := 150.0    ## сверху — строки приборов, px
const CARD_RIGHT_FREE := 240.0  ## справа — кнопка действия, px
const RISK_COLOR := Color("F1A23D")   ## риск — янтарный


## Страница «Связь» карточки (ART-040, кадр 04 `svyaz-sostoyaniya.png`): кодовое слово забега под маршрутом — одно
## на весь экипаж, по нему отличают своих от «чужого голоса в эфире» (`Comms.code`). Видно, пока открыт брифинг,
## даже если маршрут ещё не выбран.
const CODE_TITLE := "Связь · кодовое слово забега"
const CODE_HINT := "Запомните. Спросите код, если сомневаетесь."
const CODE_NOTE := "Один код у всего экипажа"


## Строки страницы «Связь»: заголовок, слово, подсказка, примечание. Слова нет (гость ещё не знает код хоста) — пусто.
static func code_lines(word: String) -> Array[String]:
	var out: Array[String] = []
	if word.strip_edges() == "":
		return out
	out.append_array([CODE_TITLE, word, CODE_HINT, CODE_NOTE])
	return out


static func icon_path(key: String) -> String:
	return "res://textures/places/%s.png" % key


## Яркость иконки по состоянию места (SonarView.place_states): 0 — не на маршруте — тусклая.
static func icon_alpha(state: float) -> float:
	return ICON_DIM if state < 0.5 else 1.0


## Строки карточки маршрута i: название, места по порядку с номерами карты, риск. Маршрут не выбран — пусто.
static func card_lines(i: int) -> Array[String]:
	var out: Array[String] = []
	if i < 0 or i >= Run.ROUTES.size():
		return out
	var r: Dictionary = Run.ROUTES[i]
	out.append(r["name"])
	for k in r["places"]:
		out.append("%d  %s" % [NUMBERS[k], Run.place_name(k)])
	out.append("Риск: " + r["risk"])
	return out


## Где карточка размера size на экране screen, если точка привязки видна в anchor: справа от точки, по её высоте,
## но внутри экрана — ниже строк приборов и левее кнопки действия.
static func card_rect(anchor: Vector2, size: Vector2, screen: Vector2) -> Rect2:
	var x := anchor.x + CARD_GAP
	var y := anchor.y - size.y * 0.5
	x = clampf(x, CARD_MARGIN, maxf(CARD_MARGIN, screen.x - CARD_RIGHT_FREE - size.x))
	y = clampf(y, CARD_TOP_FREE, maxf(CARD_TOP_FREE, screen.y - CARD_MARGIN - size.y))
	return Rect2(Vector2(x, y), size)


## Тип линии маршрута по индексу в Run.ROUTES: 0 — сплошная, 1 — длинный пунктир, 2 — точки.
enum Dash { SOLID, LONG, DOTS }


## Точка мира (x, z) → точка на столе (x, z) от центра голостола, м.
static func table_xz(world: Vector2) -> Vector2:
	return world * SCALE


## Тип линии маршрута i (не меняется при выборе — ART-016).
static func dash(i: int) -> int:
	return [Dash.SOLID, Dash.LONG, Dash.DOTS][i]


## Отрезки всех маршрутов на столе: {"a", "b" — концы (x, z) стола, "route" — индекс, "start" — путь от начала
## маршрута до a по столу, м}. Порядок — как в Run.ROUTES.
static func segments() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in Run.ROUTES.size():
		var keys: Array = Run.ROUTES[i]["places"]
		var s := 0.0
		for j in keys.size() - 1:
			var a := table_xz(Run.place_xz(keys[j]))
			var b := table_xz(Run.place_xz(keys[j + 1]))
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
