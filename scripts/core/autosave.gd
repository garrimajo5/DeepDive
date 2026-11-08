class_name Autosave
extends RefCounted
## Автосохранение кампании слоя 1 (#823): корабль вошёл в круг места-стоянки `POINTS` (старт 00, терраса врат 07,
## тихая заводь 09, спуск к лесу 10) — записать сохранение сразу (`Main.save_now`), на приборах «Сохранено: …».
## Срабатывает на входе: в начале забега (и после «Продолжить») место под кораблём не считается — сначала надо выйти
## дальше `LEAVE`. Ставит `Main._ship` после `Expedition.visit`, `main.autosave`; сброс — `Main._begin_run`.
## Переход в 10 (#828) — пока на входе в круг места 10.

const POINTS: Array[String] = ["00", "07", "09", "10"]
const RADIUS := 30.0   ## м по (x, z): вход в круг места
const LEAVE := 45.0    ## м: дальше — место снова сработает при входе

var inside := ""        ## место, в круге которого корабль ("" — ни в каком)
var primed := false     ## первое положение забега учтено


## Место из POINTS, в круге которого точка (x, z) ("" — нет).
static func spot_at(x: float, z: float) -> String:
	for id: String in POINTS:
		if Vector2(x, z).distance_to(LayerMap.xz(id)) < RADIUS:
			return id
	return ""


## Строка на приборах после записи.
static func message(id: String) -> String:
	return "Сохранено: %s" % LayerMap.POINTS[id]["name"]


## Корабль в (x, z): место, где пора сохранить (вошёл в круг), или "".
func update(x: float, z: float) -> String:
	var hit := spot_at(x, z)
	if not primed:
		primed = true
		inside = hit
		return ""
	if inside != "" and Vector2(x, z).distance_to(LayerMap.xz(inside)) > LEAVE:
		inside = ""
	if inside == "" and hit != "":
		inside = hit
		return hit
	return ""


## Новый забег или «Продолжить»: место под кораблём не сработает, пока он не выйдет.
func reset() -> void:
	primed = false
	inside = ""
