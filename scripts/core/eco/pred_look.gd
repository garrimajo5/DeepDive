class_name EcoPredLook
extends RefCounted
## Как двигается серпохвост в сцене (модель MOD-011, `docs/concept-art/serpohvost.md`): тело по скорости, хвост-серп
## качается волной вокруг корня (чем быстрее — тем чаще и шире), после укуса — быстрый взмах серпом вбок, пасть
## раскрывается в броске на корабль и в охоте у самой добычи, во время еды жуёт. Только числа, без узлов: рисует
## PredView. Модель смотрит головой в −Z.

## Модели художника: тело (голова, верхняя челюсть, плавники), хвост со серпом, нижняя челюсть.
const BODY_GLB := "res://models/serpohvost-telo.glb"
const TAIL_GLB := "res://models/serpohvost-hvost.glb"
const JAW_GLB := "res://models/serpohvost-chelyust.glb"
## Где в осях тела корень хвоста и шарнир челюсти (MOD-011, notes.md).
const TAIL_ROOT := Vector3(0, -0.19, 1.80)
const JAW_HINGE := Vector3(0, -0.12, -0.95)
## Пределы поворота: хвост вокруг Y, челюсть вокруг X (рад, 35°) — больше модель не рассчитана.
const TAIL_MAX := deg_to_rad(35.0)
const JAW_MAX := deg_to_rad(35.0)
## Наклон тела вверх-вниз не больше (рад).
const PITCH_MAX := deg_to_rad(30.0)
## Волна хвоста: частота в покое (рад/с) и прибавка за 1 м/с; размах в покое (рад) и прибавка за 1 м/с.
const WAVE_RATE := 3.0
const WAVE_RATE_PER_SPEED := 0.6
const WAVE_AMP := deg_to_rad(12.0)
const WAVE_AMP_PER_SPEED := deg_to_rad(1.6)
## Удар серпом после укуса: длительность (с).
const STRIKE_TIME := 0.6
## Пасть раскрыта, если до корабля в броске или до добычи в охоте ближе (м).
const JAW_SHIP_DIST := 20.0
const JAW_PREY_DIST := 6.0
## Жуёт: частота (рад/с) и доля раскрытия.
const CHEW_RATE := 6.0
const CHEW_OPEN := 0.5


## Куда смотрит голова: по скорости; почти стоит — на +Z (как lookAt в браузере). Наклон — не больше PITCH_MAX.
static func forward(pr: EcoPred.Pred) -> Vector3:
	var v := pr.agent.v
	if v.length_squared() <= 0.01:
		return Vector3(0, 0, 1)
	var flat := Vector2(v.x, v.z).length()
	var pitch := clampf(atan2(v.y, flat), -PITCH_MAX, PITCH_MAX)
	var h := Vector2(v.x, v.z).normalized() if flat > 1e-4 else Vector2(0, 1)
	return Vector3(h.x * cos(pitch), sin(pitch), h.y * cos(pitch))


## Поворот тела: −Z модели смотрит в forward, спина вверх.
static func basis(pr: EcoPred.Pred) -> Basis:
	return Basis.looking_at(forward(pr), Vector3.UP)


## Поворот хвоста вокруг Y (рад, ±TAIL_MAX) в момент t: волна, после укуса — взмах серпом.
static func tail_angle(pr: EcoPred.Pred, t: float) -> float:
	var since := t - pr.bit_at
	if since >= 0.0 and since < STRIKE_TIME:
		return TAIL_MAX * sin(PI * since / STRIKE_TIME)
	var s := pr.agent.v.length()
	var amp := minf(WAVE_AMP + WAVE_AMP_PER_SPEED * s, TAIL_MAX)
	var rate := WAVE_RATE + WAVE_RATE_PER_SPEED * s
	return amp * sin(t * rate + pr.index * 2.1)


## Раскрытие пасти 0…JAW_MAX (рад; модель поворачивает челюсть на −угол вокруг X) в момент t у корабля в ship.
static func jaw_angle(pr: EcoPred.Pred, ship: Vector3, t: float) -> float:
	match pr.mode:
		EcoPred.Mode.CHARGE:
			if pr.agent.distance_to(ship) < JAW_SHIP_DIST:
				return JAW_MAX
		EcoPred.Mode.HUNT:
			if pr.prey and pr.agent.distance_to(pr.prey.agent.p) < JAW_PREY_DIST:
				return JAW_MAX
		EcoPred.Mode.EAT:
			return JAW_MAX * CHEW_OPEN * 0.5 * (1.0 + sin(t * CHEW_RATE))
	return 0.0
