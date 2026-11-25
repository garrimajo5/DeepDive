class_name EcoMeloch
extends RefCounted
## Фоновая мелочь у дна (#2108, схема участков уровней PR #2111): косячки мелких существ (6–15 см) дрейфуют
## в 0,4–3,2 м над дном, видны в кольце 9…45 м от корабля — маршрут 00 → 01 → 07 перестаёт быть пустым между
## местами. Плотность — по участкам схемы: свободная полоса хода (ось маршрута ± LANE) пуста, жизнь гуще по
## краям; самая плотная — у рифа 01, у врат 07 и в ложбине — редкая. Плотность участка — ДОЛЯ видимой мелочи
## в пятне (хеш < weight), а не её размер: редкая жизнь — это мало полноразмерной мелочи, не много мелкой.
## Это фон, не вид мира: в EcoWorld её нет, сонар, сканер и хищники её не видят, на поведение не влияют. Где
## мелочь и куда плывёт — формула от времени мира и хеша EcoVary (как EcoFarLife), поэтому у гостя сети картина
## та же, что у хоста. Пятна живут в плитке TILE × TILE, повторённой по отмели: из копий пятна берётся ближайшая
## к кораблю (near_copy). Ближе NEAR_IN и дальше FAR_OUT мелочь сжата в точку (fade) — не летит через корпус и
## не мигает на краю. Цвет — тёмный, без света: читается движением на фоне дна в луче прожектора.
## «Экономно» — слой скрыт (MelochView.set_lite).

## Сторона плитки, м: больше 2 · FAR_OUT — в кольце видимости не бывает двух копий одного пятна.
const TILE := 160.0
## Кольцо видимости по горизонтали от корабля, м: растёт NEAR_IN → NEAR_FULL, гаснет FAR_FULL → FAR_OUT.
## NEAR_IN 9 — мелочь не пересекает корпус у иллюминаторов (полуширина корпуса ~5 м).
const NEAR_IN := 9.0
const NEAR_FULL := 14.0
const FAR_FULL := 32.0
const FAR_OUT := 45.0
## Пятна в плитке и мелочь в пятне.
const PATCHES := 24
const PER := 14
## Радиус пятна, м.
const R_MIN := 6.0
const R_MAX := 13.0
## Высота над дном, м.
const LOW := 0.4
const HIGH := 3.2
## Фоновая доля мелочи вне маршрута: отмель не мертва и в стороне, но заметно реже.
const AMBIENT := 0.10
## Полоса маршрута по умолчанию: до LANE м от оси пусто (свободный ход), к BAND_MID подъём до полной,
## плато до BAND_EDGE, спад к BAND_OUT (схема: «рамка гуще у краёв, полоса хода видима»).
const LANE := 7.0
const BAND_MID := 16.0
const BAND_EDGE := 28.0
const BAND_OUT := 42.0
## Участки маршрута 00 → 01 → 07 (PR #2111): [начало, конец, плотность, mid, edge, out]. У короткого плотного
## подхода к 01 полоса узкая (10/14/20) — его густая жизнь не заливает спокойную середину ложбины (#1400).
const SEGS := [
	[Vector2(0.0, 95.0), Vector2(4.0, 80.0), 0.35, 16.0, 28.0, 42.0],     # выход 00 — разреженно
	[Vector2(4.0, 80.0), Vector2(20.0, 23.0), 0.22, 16.0, 28.0, 42.0],    # ложбина — низкая
	[Vector2(20.0, 23.0), Vector2(33.0, -22.0), 0.22, 16.0, 28.0, 42.0],  # ложбина — низкая
	[Vector2(33.0, -22.0), Vector2(40.0, -50.0), 0.85, 10.0, 14.0, 20.0], # подход к 01 — самая плотная
	[Vector2(40.0, -50.0), Vector2(-100.0, -240.0), 0.5, 16.0, 28.0, 42.0], # 01 → 07 — средняя по краям
]
## Риф 01: жизнь у подошвы плотная даже ближе LANE к оси (конец плеча, зона осмотра рифа).
const REEF := Vector2(40.0, -50.0)
const REEF_R := 35.0
const REEF_K := 0.9
## Терраса врат 07: перед жёлобом и у опор плотность низкая (внимание — к купольнику и диагностике).
const GATE := Vector2(-100.0, -240.0)
const GATE_R := 80.0
const GATE_K := 0.45
## Собственный дрейф мелочи внутри пятна: круг 0,5–1,6 м со скоростью DRIFT_MIN…DRIFT_MAX м/с
## (обход за 6–60 с); покачивание по высоте ±0,4 м.
const DRIFT_MIN := 0.16
const DRIFT_MAX := 0.5
## Цвет (почти чёрная вода, чуть светлее силуэтов вдали — ближе к лучу) и разброс тона пятна.
const COLOR := Color(0.05, 0.09, 0.11)
const SHADE := 0.4

const _BASE_X := 41
const _BASE_Z := 42
const _R := 43
const _DRIFT := 44
const _PHASE := 45
const _DIR := 46
const _OFF := 47
const _PRES := 48


static func count() -> int:
	return PATCHES * PER


## Середина пятна i в плитке (x, z), м.
static func base(i: int) -> Vector2:
	return Vector2(EcoVary.unit(i, _BASE_X) * TILE, EcoVary.unit(i, _BASE_Z) * TILE)


## Ближайшая к кораблю копия точки p плитки (по x и z).
static func near_copy(p: Vector2, ship: Vector2) -> Vector2:
	return Vector2(ship.x + wrapf(p.x - ship.x, -TILE * 0.5, TILE * 0.5),
		ship.y + wrapf(p.y - ship.y, -TILE * 0.5, TILE * 0.5))


## Доля размера по горизонтальному расстоянию d от корабля: 0 вне кольца, 1 внутри.
static func fade(d: float) -> float:
	return smoothstep(NEAR_IN, NEAR_FULL, d) * (1.0 - smoothstep(FAR_FULL, FAR_OUT, d))


## Профиль полосы маршрута: 0 на оси до LANE, 1 в кольце mid…edge, к out — 0.
static func band_seg(d: float, mid: float, edge: float, out: float) -> float:
	return smoothstep(LANE, mid, d) * (1.0 - smoothstep(edge, out, d))


## Профиль полосы по умолчанию (для проверок).
static func band(d: float) -> float:
	return band_seg(d, BAND_MID, BAND_EDGE, BAND_OUT)


## Расстояние от точки p до отрезка [a, b].
static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Доля видимой мелочи в точке (x, z) по схеме участков: максимум по полосам отрезков маршрута против фона,
## у рифа — гуще, у врат — реже. 0…1.
static func weight(p: Vector2) -> float:
	var w := AMBIENT
	for s in SEGS:
		w = maxf(w, s[2] * band_seg(_seg_dist(p, s[0], s[1]), s[3], s[4], s[5]))
	w = maxf(w, REEF_K * (1.0 - smoothstep(REEF_R * 0.55, REEF_R, p.distance_to(REEF))))
	if p.distance_to(GATE) < GATE_R:
		w *= GATE_K
	return clampf(w, 0.0, 1.0)


## Радиус пятна i, м.
static func radius(i: int) -> float:
	return lerpf(R_MIN, R_MAX, EcoVary.unit(i, _R))


## Цвет пятна i: COLOR темнее-светлее на SHADE.
static func tint(i: int) -> Color:
	var k := EcoVary.spread(i, EcoVary.SHADE, SHADE)
	return Color(COLOR.r * k, COLOR.g * k, COLOR.b * k)


## Длина мелочи j пятна i, м.
static func length_of(i: int, j: int) -> float:
	return lerpf(0.06, 0.15, EcoVary.unit(i * 32 + j, EcoVary.SIZE))


## Пятно i во время t у корабля ship: [x, z — середина ближайшей копии, k — доля размера кольца (0 — не видно),
## дно под серединой, w — доля видимой мелочи по схеме]. Дно спрашивается раз на пятно и только у видимого.
static func patch_at(i: int, t: float, ship_pos: Vector3, ground: Callable) -> PackedFloat32Array:
	var ship := Vector2(ship_pos.x, ship_pos.z)
	var at := near_copy(base(i), ship)
	var k := fade(at.distance_to(ship))
	if k <= 0.0:
		return PackedFloat32Array([at.x, at.y, 0.0, 0.0, 0.0])
	var floor_y := float(ground.call(at.x, at.y)) if ground.is_valid() else -30.0
	k *= EcoFarLife.alive(floor_y)
	if k <= 0.0:
		return PackedFloat32Array([at.x, at.y, 0.0, floor_y, 0.0])
	return PackedFloat32Array([at.x, at.y, k, floor_y, weight(at)])


## Трансформ мелочи j пятна s = patch_at(i, …) во время t (меш — длина 1, нос в −Z). Не видна — сжата в точку.
## Дно под самой мелочью — точно (огибающей у пятна нет: пятно ≤ 13 м, высоты LOW…HIGH хватает над рельефом).
static func mote(i: int, j: int, t: float, s: PackedFloat32Array, ground: Callable) -> Transform3D:
	var c := Vector3(s[0], s[3], s[1])
	if s[2] <= 0.0:
		return Transform3D(Basis.from_scale(Vector3.ZERO), c)
	var k := i * 32 + j
	# плотность участка — доля видимой мелочи: хеш мелочи против weight пятна
	if EcoVary.unit(k, _PRES) >= s[4]:
		return Transform3D(Basis.from_scale(Vector3.ZERO), c)
	var r := radius(i)
	# своё место в пятне (диск) + медленный обход по кругу 0,5–1,6 м
	var ang := EcoVary.unit(k, _OFF) * TAU
	var rad := sqrt(EcoVary.unit(k, _OFF + 1)) * r
	var dr := lerpf(0.5, 1.6, EcoVary.unit(k, _DRIFT))
	var w := lerpf(DRIFT_MIN, DRIFT_MAX, EcoVary.unit(k, _DRIFT + 1)) / dr
	var dir := 1.0 if EcoVary.unit(k, _DIR) < 0.5 else -1.0
	var ph := EcoVary.unit(k, _PHASE) * TAU
	var a := t * w * dir + ph
	var o := Vector2(cos(ang), sin(ang)) * rad + Vector2(cos(a), sin(a)) * dr
	var p := Vector2(c.x, c.z) + o
	var gy := float(ground.call(p.x, p.y)) if ground.is_valid() else c.y
	var h := lerpf(LOW, HIGH, EcoVary.unit(k, _OFF + 2)) + sin(t * 0.5 + ph) * 0.4
	var y := gy + maxf(LOW, h)
	# нос по ходу обхода (касательная), лёгкое виляние
	var v := Vector2(-sin(a), cos(a)) * dir
	var yaw := atan2(-v.x, -v.y) + sin(t * 2.6 + ph * 1.7) * 0.15
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * length_of(i, j) * s[2]),
		Vector3(p.x, y, p.y))


## Трансформ мелочи j пятна i во время t у корабля ship (для проверки; вид берёт patch_at + mote).
static func xform(i: int, j: int, t: float, ship: Vector3, ground: Callable) -> Transform3D:
	return mote(i, j, t, patch_at(i, t, ship, ground), ground)
