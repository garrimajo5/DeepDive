class_name EcoCurrent
extends EcoSystem
## Течение отмели для живого мира (E.current в js/creatures.js, currentUpdate): медленный поток 0,3 м/с, раз в 180 с
## меняет направление по кругу из шести, поворачивается плавно. Числа те же, что у течения корабля Helm.SeaCurrent
## (поток А): оба начинают с первого направления в начале забега и идут одним временем, поэтому веерники стоят
## поперёк того же течения, что сносит корабль. Модуль подключают в мир раньше флоры, которая читает течение.

const SPEED := 0.3
const PERIOD := 180.0
const TURN_RATE := 0.08
## Направления: поток идёт в (sin a, 0, cos a).
const DIRS: Array[float] = [0.7, 2.4, -1.9, 0.1, 2.9, -0.9]

## Куда идёт поток сейчас (рад).
var angle := 0.0
## Куда он поворачивает.
var target := 0.0
## Номер направления в DIRS.
var index := 0
## Секунд до смены направления.
var timer := PERIOD
## Сколько раз течение сменилось с начала (флора узнаёт смену по этому счёту).
var turns := 0


func reset(_world: EcoWorld) -> void:
	index = 0
	angle = DIRS[0]
	target = DIRS[0]
	timer = PERIOD
	turns = 0


func step(_world: EcoWorld, dt: float) -> void:
	timer -= dt
	if timer <= 0.0:
		timer += PERIOD
		index = (index + 1) % DIRS.size()
		target = DIRS[index]
		turns += 1
	var da := wrapf(target - angle, -PI, PI)
	angle += da * minf(1.0, dt * TURN_RATE)


## Скорость потока (м/с).
func vel() -> Vector3:
	return Vector3(sin(angle), 0.0, cos(angle)) * SPEED
