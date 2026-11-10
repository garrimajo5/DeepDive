class_name HullLights
## Огни корпуса снаружи ART-070 (`docs/concept-art/ogni-korpusa.md`, таблица — `ogni-korpusa.json`): шесть карточек
## с ореолом `textures/ogni/oreol.png`, без Light3D. Левый борт — вытянутый ореол #B8D9E8, правый — круглый #67DDEB,
## верх кормы — ровный, маяк на рубке — проблеск 2,4 с. Рисует HullView одним MultiMesh (+1 вызов).
## Здесь — числа и расчёт без узлов: место карточки по камере, размер по дистанции, яркость по проблеску, заряду,
## миганию света и шторке «Корпус разрушен».

const HALO_TEX := "res://textures/ogni/oreol.png"

enum Kind { SIDE, TOP, BEACON }

## Огни в осях корабля (м): ЛН, ПН, ЛК, ПК, ВК, М.
const IDS: Array[String] = ["ЛН", "ПН", "ЛК", "ПК", "ВК", "М"]
const POS: Array[Vector3] = [
	Vector3(-6.78, 1.6, -2.0), Vector3(6.78, 1.6, -2.0),
	Vector3(-6.55, 2.74, 24.6), Vector3(6.55, 2.74, 24.6),
	Vector3(0.0, 5.06, 25.0), Vector3(0.0, 4.92, -2.0),
]
const COLORS: Array[Color] = [
	Color("#B8D9E8"), Color("#67DDEB"), Color("#B8D9E8"), Color("#67DDEB"), Color("#C6D6DE"), Color("#B8D9E8"),
]
const KINDS: Array[int] = [Kind.SIDE, Kind.SIDE, Kind.SIDE, Kind.SIDE, Kind.TOP, Kind.BEACON]
## Ореол на дистанции AT (ширина × высота, м): левый борт вытянут, остальные круглые.
const LEFT_HALO := Vector2(1.0, 1.7)
const ROUND_HALO := Vector2(1.3, 1.3)

const AT := 45.0          ## на этой дистанции ореол — размер таблицы
const SCALE_MIN := 0.3
const SCALE_MAX := 1.5
const TOWARD := 1.3       ## центр карточки к камере вдоль луча: экранное место то же, корпус ореол не режет

## Маяк М: период 2,4 с, вход 0–0,10 с, выход 0,25–0,35 с.
const PERIOD := 2.4
const RISE := 0.10
const FALL_FROM := 0.25
const FALL_TO := 0.35

## Решения встройки (поток А, по предложениям художника): заряд ниже Vitals.LOW_ENERGY — маяк гаснет, верх кормы
## 0,35, борта 0,25; заряд 0 — всё гаснет. «Корпус разрушен» — гаснут за 0,3 с, после перезапуска снова горят.
## «Экономно» — ореолы × 0,6, маяк ровный 0,35. Пробоина огни не меняет.
const LOW_TOP := 0.35
const LOW_SIDE := 0.25
const WRECK_FADE := 0.3
const LITE_SIZE := 0.6
const LITE_BEACON := 0.35


static func count() -> int:
	return POS.size()


static func halo(i: int) -> Vector2:
	return LEFT_HALO if POS[i].x < 0.0 else ROUND_HALO


## Множитель размера ореола по дистанции до камеры (м).
static func scale_at(d: float) -> float:
	return clampf(d / AT, SCALE_MIN, SCALE_MAX)


## Проблеск маяка по времени (с): 0…1.
static func pulse(t: float) -> float:
	var ph := fposmod(t, PERIOD)
	return smoothstep(0.0, RISE, ph) * (1.0 - smoothstep(FALL_FROM, FALL_TO, ph))


## Шторка «Корпус разрушен» (Wreck.t, < 0 — нет): огни гаснут за WRECK_FADE, с перезапуском горят снова.
static func wreck_k(wreck_t: float) -> float:
	if wreck_t < 0.0 or wreck_t >= Wreck.RESTART_AT:
		return 1.0
	return 1.0 - clampf(wreck_t / WRECK_FADE, 0.0, 1.0)


## Яркость огня i (0…1, альфа карточки): t — время игры, energy — заряд (%), lamp_k — Vitals.lamp_k.
static func alpha(i: int, t: float, energy: float, lamp_k: float, wreck_t: float, lite: bool) -> float:
	if energy <= 0.0:
		return 0.0
	var low := energy < Vitals.LOW_ENERGY
	var a := 1.0
	match KINDS[i]:
		Kind.BEACON:
			a = 0.0 if low else LITE_BEACON if lite else pulse(t)
		Kind.TOP:
			a = LOW_TOP if low else 1.0
		_:
			a = LOW_SIDE if low else 1.0
	return a * clampf(lamp_k, 0.0, 1.0) * wreck_k(wreck_t)


## Карточка огня i в осях корабля для камеры cam (оси корабля): сдвиг к камере на TOWARD, масштаб по дистанции.
## Поворот к камере делает материал (billboard с сохранением масштаба).
static func card(i: int, cam: Vector3, lite: bool) -> Transform3D:
	var p := POS[i]
	var to := cam - p
	var d := to.length()
	var s := halo(i) * scale_at(d) * (LITE_SIZE if lite else 1.0)
	var at := p + to / d * minf(TOWARD, d * 0.5) if d > 0.001 else p
	return Transform3D(Basis.from_scale(Vector3(s.x, s.y, 1.0)), at)


## Огни видны, только когда камера снаружи корпуса: изнутри их не видно, а сдвиг к камере увёл бы карточку в отсек.
static func shown(cam: Vector3) -> bool:
	return not HullPlan.inside(cam)
