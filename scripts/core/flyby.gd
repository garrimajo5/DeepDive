class_name Flyby
extends RefCounted
## Камера с борта (вид корабля снаружи): облёт в начале забега и подъём при всплытии. Без узлов: путь камеры в осях
## корабля по трём ключевым точкам, взгляд — на середину корпуса (`HullPlan`). Камеру ставит `Main` (`main.flyby`,
## узел «Камера с борта»); касание экрана в начале забега пропускает облёт.

enum Kind { NONE, START, SURFACE }

## Облёт в начале забега, с: от носа слева вдоль борта к корме, затем — глаза игрока на мостике.
const START_S := 6.0
## Ключевые точки облёта (оси корабля, м): нос слева впереди → левый борт → корма слева сверху. Корпус ~37 м.
const START_PATH := [Vector3(-26.0, 4.0, -30.0), Vector3(-32.0, 7.0, 6.0), Vector3(-20.0, 11.0, 38.0)]
## Всплытие: камера под левым бортом поднимается вместе с кораблём к свету льда, стоит в последней точке SURFACE_HOLD
## и кончается сама — глаза на мостике, итог на голограмме над голостолом (issue #209). Кнопка действия пропускает.
const SURFACE_S := 6.0
const SURFACE_HOLD := 1.5
const SURFACE_PATH := [Vector3(-24.0, -10.0, 20.0), Vector3(-28.0, -4.0, 6.0), Vector3(-30.0, 2.0, -6.0)]
## Куда смотрит камера: середина корпуса; при всплытии — выше, к кораблю на фоне льда.
const LOOK_AT := Vector3(0.0, HullPlan.CENTER_Y, HullPlan.BODY_Z)
const SURFACE_LOOK_UP := 6.0
## Подпись на приборах во время облёта.
const START_MSG := "Ковчег-7 у начала спуска · коснитесь экрана"

var kind := Kind.NONE
var t := 0.0  ## секунды с начала облёта


func start(k: Kind) -> void:
	kind = k
	t = 0.0


func stop() -> void:
	kind = Kind.NONE
	t = 0.0


func active() -> bool:
	return kind != Kind.NONE


## Длина облёта, с.
func length() -> float:
	return START_S if kind == Kind.START else SURFACE_S


## Сколько всего длится вид, с: облёт в начале — путь, всплытие — путь и стоянка в последней точке.
func duration() -> float:
	return START_S if kind == Kind.START else SURFACE_S + SURFACE_HOLD


## Шаг: облёт кончается сам — в начале забега после пути, при всплытии после стоянки в последней точке.
func update(dt: float) -> void:
	if not active():
		return
	t += dt
	if t >= duration():
		stop()


## Доля пройденного пути 0…1, плавно на концах.
func progress() -> float:
	var u := clampf(t / length(), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Камера в осях корабля: место и взгляд на корпус (−Z камеры — на LOOK_AT).
func pose() -> Transform3D:
	var path: Array = START_PATH if kind == Kind.START else SURFACE_PATH
	var p := _along(path, progress())
	var look := LOOK_AT + (Vector3.UP * SURFACE_LOOK_UP if kind == Kind.SURFACE else Vector3.ZERO)
	return Transform3D(Basis.looking_at(look - p, Vector3.UP), p)


## Точка на дуге через три ключевые точки (квадратичная кривая Безье: проходит через первую и последнюю, средняя тянет).
static func _along(path: Array, u: float) -> Vector3:
	var v := clampf(u, 0.0, 1.0)
	var a: Vector3 = path[0]
	var b: Vector3 = path[1]
	var c: Vector3 = path[2]
	return a * (1.0 - v) * (1.0 - v) + b * 2.0 * v * (1.0 - v) + c * v * v
