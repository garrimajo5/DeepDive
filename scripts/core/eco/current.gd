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


## Колыхание флоры в течении (план реализма Б3) — двойник ветки `sway` общего шейдера растений EcoShaders.PLANT.
## Растение ложится по потоку (`lean`, порывы раз в ~14 с), по нему бежит волна вверх (`flutter`) и чуть
## поперёк (`across`); всё — доли высоты растения и растёт к верху как h². Фаза — от места куста, поэтому соседи
## колышутся вразнобой. Без течения остаётся лёгкое колыхание (IDLE доли), крен — только по потоку.
const IDLE := 0.4
## Фаза от места подножия: x · 0,23 + z · 0,19 (как G.sway у ленточника).
const PHASE_X := 0.23
const PHASE_Z := 0.19


## Смещение точки растения в мире: o — подножие куста, h — доля высоты (0 — у дна, 1 — кончик), height — высота
## растения (м), t — время, flow — скорость потока (м/с), bend — (крен, волна, поперёк) в долях высоты на полном
## течении SPEED. Конец опускается, чтобы стебель не вытягивался.
static func sway(o: Vector3, h: float, height: float, t: float, flow: Vector3, bend: Vector3) -> Vector3:
	var v := flow.length()
	var s := v / SPEED
	var d := flow / v if v > 1e-5 else Vector3.BACK
	var c := Vector3(-d.z, 0.0, d.x)
	var ph := o.x * PHASE_X + o.z * PHASE_Z
	var gust := 0.65 + 0.35 * sin(t * 0.45 + ph)
	var fl := sin(t * 1.6 + ph * 1.3 - h * 2.2)
	var cr := sin(t * 1.1 + ph * 0.7 - h * 1.5)
	var w := IDLE + (1.0 - IDLE) * s
	var k := clampf(h, 0.0, 1.0)
	k = k * k * height
	var off := d * (bend.x * s * gust + bend.y * w * fl) * k + c * (bend.z * w * cr) * k
	off.y -= off.dot(off) / (2.0 * maxf(height, 0.1))
	return off
