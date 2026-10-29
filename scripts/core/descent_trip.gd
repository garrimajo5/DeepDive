class_name DescentTrip
extends RefCounted
## Уход к Кристальному лесу у места 10 (#828, часть 2б): экипаж решил «глубже» у спуска — короткая кат-сцена
## (затемнение `SINK` с), экран «Кристальный лес — в разработке» (`HOLD` с), посреди него корабль возвращается
## в область 10 (`RETURN_SPOT` — на пути к террасе 07), знания «ушли вниз» и «вернулись» и сохранение;
## затем свет обратно (`RISE` с). Корабль и экипаж кат-сцена не меняет, необратимого выбора нет. Слоя 2 ещё нет.
## `main.trip`, рисует `scripts/game/descent_view.gd`.

const SINK := 2.0   ## с: затемнение — корабль уходит вниз
const HOLD := 4.0   ## с: экран «в разработке»
const RISE := 1.5   ## с: свет обратно
const TITLE := "Кристальный лес"
const SUB := "Слой в разработке. «Ковчег» возвращается к спуску"
const START_MSG := "Спуск к Кристальному лесу"
const BACK_MSG := "«Ковчег» у спуска 10. Путь к террасе 07 — на запад"
## Куда корабль возвращается: внутри круга места 10 (новое предупреждение — только после ухода и возвращения),
## на 30 м западнее центра — к террасе 07; высота — `DEPTH_ABOVE` м над дном.
const RETURN_OFFSET := Vector2(-30.0, 0.0)
const DEPTH_ABOVE := 16.0

var active := false
var t := 0.0
var _arrived := false


static func return_spot() -> Vector3:
	var at := Run.place_xz(Run.DESCENT) + RETURN_OFFSET
	return Vector3(at.x, Seabed.height(at.x, at.y) + DEPTH_ABOVE, at.y)


func start() -> void:
	active = true
	t = 0.0
	_arrived = false


## Шаг: "arrive" — один раз посреди экрана (вернуть корабль, знания, сохранение), "done" — конец, иначе "".
func update(dt: float) -> String:
	if not active:
		return ""
	t += dt
	if not _arrived and t >= SINK + HOLD * 0.5:
		_arrived = true
		return "arrive"
	if t >= SINK + HOLD + RISE:
		active = false
		return "done"
	return ""


## Непрозрачность шторки 0…1.
func alpha() -> float:
	if not active:
		return 0.0
	if t < SINK:
		return t / SINK
	if t < SINK + HOLD:
		return 1.0
	return clampf(1.0 - (t - SINK - HOLD) / RISE, 0.0, 1.0)


## Надписи видны, пока шторка закрыта (и полсекунды на появление).
func text_alpha() -> float:
	if not active or t < SINK:
		return 0.0
	return clampf(minf(t - SINK, SINK + HOLD - t) / 0.5, 0.0, 1.0)
