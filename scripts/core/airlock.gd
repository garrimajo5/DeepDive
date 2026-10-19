class_name Airlock
extends RefCounted
## Нижний шлюз трюма (ART-001, ART-010 — docs/concept-art/tryum.md): круглая крышка Ø 2,2 м под проёмом 1,6 × 1,6 м
## в полу трюма, на петле у носовой кромки; открывается за 2 с и откидывается вниз на 100°. Пост «Шлюз» у носовой
## кромки проёма. Через открытый шлюз лебёдка поднимает образцы со дна (Samples).

const Z := HullPlan.AIRLOCK_Z            ## центр крышки и проёма
const Y := HullPlan.AIRLOCK_Y
const RADIUS := HullPlan.AIRLOCK_R
const THICK := HullPlan.AIRLOCK_THICK
const HINGE_Z := Z - RADIUS
const OPEN_TIME := 2.0
const MAX_ANGLE := 100.0
const HOLE := 1.6                        ## проём в полу трюма, м
const SHAFT_DEPTH := 0.85                ## шахта от пола до крышки
## Пост у правой кромки проёма: у носовой кромки (как в tryum.md) он слипался бы с люком в машинное (z 19,5).
const POST_AT := Vector2(1.5, 22.0)
const POST_R := 0.9

var open := false
var t := 0.0

signal message(text: String)


func fully_open() -> bool:
	return t >= 1.0


func closed() -> bool:
	return t <= 0.0


## Угол крышки, градусы: плавный разгон и торможение.
func angle() -> float:
	return t * t * (3.0 - 2.0 * t) * MAX_ANGLE


func label() -> String:
	return "Закрыть шлюз" if open else "Открыть шлюз"


func toggle() -> void:
	open = not open
	message.emit("Шлюз открывается" if open else "Шлюз закрывается")


func reset() -> void:
	open = false
	t = 0.0


func update(dt: float) -> void:
	if dt <= 0.0:
		return
	var was := t
	t = clampf(t + (1.0 if open else -1.0) * dt / OPEN_TIME, 0.0, 1.0)
	if was < 1.0 and t >= 1.0:
		message.emit("Шлюз открыт")
	if was > 0.0 and t <= 0.0:
		message.emit("Шлюз закрыт")


## Положение крышки в осях корабля: центр и поворот вокруг x (рад). Кормовая кромка уходит вниз.
func cover_pose() -> Transform3D:
	var a := deg_to_rad(angle())
	return Transform3D(Basis(Vector3.RIGHT, a), Vector3(0.0, Y - RADIUS * sin(a), HINGE_Z + RADIUS * cos(a)))


## Проём в полу (x, z) — сюда не встать.
static func in_hole(x: float, z: float, r: float) -> bool:
	return absf(x) < HOLE / 2.0 + r and absf(z - Z) < HOLE / 2.0 + r
