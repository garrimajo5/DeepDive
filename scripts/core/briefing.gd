class_name Briefing
extends RefCounted
## Голограмма брифинга над голостолом (ART-016, docs/concept-art/golostol-brifing.md): пока игрок у поста «Маршрут»,
## сонар над столом сменяет карта всей отмели — неподвижная, нос (−Z) вверх, +X вправо, 700 × 700 м во вписанный
## квадрат 1,13 м. На ней шесть мест с номерами и три маршрута `Run.ROUTES`: «Рифовый сад» — сплошная линия,
## «Тёплые трубы» — длинный пунктир, «Край отмели» — точки; выбранный ярче и толще, по нему бежит подсветка.
## Здесь — числа и геометрия без узлов; рисует `SonarView` (шейдер sonar_holo).

const SIDE := 1.13             ## сторона квадрата карты на столе, м
const SCALE := SIDE / 700.0    ## м стола на м мира
const FADE := 0.25             ## переход сонар ↔ брифинг, с
const MAX_SEGS := 8            ## столько отрезков держит шейдер
## Номера мест — по таблице ART-016.
const NUMBERS := {"flower": 1, "geyser": 2, "shell": 3, "bones": 4, "well": 5, "drop": 6}
const ORDER: Array[String] = ["flower", "geyser", "shell", "bones", "well", "drop"]
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
