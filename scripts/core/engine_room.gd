class_name EngineRoom
extends RefCounted
## Машинное по ART-008 и моделям MOD-009 (`docs/concept-art/mashinnoe.md`): вентиль сброса пара на левой стене и щиток
## «Аварийный сброс» на правой. Вентиль — удержанием кнопки действия: маховик крутится, пар уходит, реактор остывает,
## но шум пара слышат существа (`EcoLink.ShipState.hull_noise`). Щиток — нажатием: крышка откидывается, кнопка
## глушит перегретый реактор сразу и на 6 с (сам он срывается на 100° и на 12 с), после пуска он холоднее.
## Оси корабля; стены машинного на x ±3 (`ShipLayout.ROOMS`).

## Вентиль: корпус на стене, маховик — на 0,32 м от неё (ось вращения x).
const VALVE_POS := Vector3(-3.0, 1.3, 17.2)
const VALVE_WHEEL := Vector3(-2.68, 1.3, 17.2)
## Щиток: центр задней стенки на стене, крышка — на верхнем шарнире (ось z, открыта на −110°).
const PANEL_POS := Vector3(3.0, 1.4, 17.2)
const LID_POS := Vector3(2.822, 1.425, 17.2)
const LID_OPEN_DEG := -110.0
const LID_TIME := 0.35
## Посты на полу у стен (x, z), радиус.
const VALVE_POST := Vector2(-2.2, 17.2)
const PANEL_POST := Vector2(2.2, 17.2)
const POST_R := 0.9
## Что выступает со стен: в это место не встать (x0, z0, ширина, глубина).
const VALVE_RECT := Rect2(-3.0, 16.95, 0.37, 0.5)
const PANEL_RECT := Rect2(2.85, 16.9, 0.15, 0.6)

## Сброс пара: градусов в секунду, шум (0…1), оборотов маховика в секунду.
const VENT_RATE := 8.0
const VENT_NOISE := 0.6
const WHEEL_TURNS := 0.6
## Ручной сброс: обесточено на 6 с, после пуска реактор на 20° (после срыва — на 50°).
const MANUAL_SCRAM := 6.0
const MANUAL_RESTART_HEAT := 20.0

var venting := false       ## пар идёт в этом шаге
var wheel_deg := 0.0       ## поворот маховика
var lid := 0.0             ## крышка щитка 0 — закрыта, 1 — открыта
var pressed := 0.0         ## кнопка подсвечена после нажатия, с

## Сообщение для приборов.
signal message(text: String)


## Шаг: held — игрок держит кнопку действия у вентиля.
func update(dt: float, r: Reactor, held: bool) -> void:
	var was := venting
	venting = held
	if held:
		wheel_deg = fmod(wheel_deg + WHEEL_TURNS * 360.0 * dt, 360.0)
		if r.heat > 0.0:
			r.heat = maxf(0.0, r.heat - VENT_RATE * dt)
		if not was:
			message.emit("Сброс пара: реактор остывает" if r.hot else "Сброс пара: реактор не перегрет")
	pressed = maxf(0.0, pressed - dt)
	var want := 1.0 if pressed > 0.0 or r.scram > 0.0 else 0.0
	lid = move_toward(lid, want, dt / LID_TIME)


## Нажать «Аварийный сброс». Без перегрева — нельзя (крышка не открывается), в сбросе — уже обесточен.
func press(r: Reactor) -> bool:
	if r.scram > 0.0:
		message.emit("Реактор уже обесточен")
		return false
	if not r.hot:
		message.emit("Сброс не нужен: реактор в норме")
		return false
	pressed = 1.0
	r.manual_scram(MANUAL_SCRAM, MANUAL_RESTART_HEAT)
	return true


## Шум корабля для живого мира: пар громче хода.
func noise(base: float) -> float:
	return maxf(base, VENT_NOISE) if venting else base


static func blocks(x: float, z: float, r: float) -> bool:
	return VALVE_RECT.grow(r).has_point(Vector2(x, z)) or PANEL_RECT.grow(r).has_point(Vector2(x, z))
