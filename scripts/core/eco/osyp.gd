class_name EcoOsyp
extends RefCounted
## Каменная крошка, осыпи и валуны у дна (#2108, часть 3; схема участков уровней PR #2111): дно маршрута
## 00 → 01 → 07 перестаёт быть «голым песком» — у краёв полосы хода лежат камни, у рифа 01 плотнее всех
## («камни у подошвы лепестков»), на перегоне 01 → 07 — боковые каменистые гряды с осыпями, у врат 07 редко
## (внимание — к купольнику и диагностике). Полоса хода (ось ± LANE) — без валунов: обзор дна в луче
## свободен, мелкая крошка на ней остаётся (схема: «свободная полоса видима по ряби песка, мелкому детриту»).
## Это фон, не вид мира: в EcoWorld камней нет, сонар, сканер и хищники их не видят, столкновений не дают.
## Камни неподвижны: место, размер и поворот — формула хеша EcoVary (как EcoMeloch, но без времени), у гостя
## сети картина та же. Пятна живут в плитке TILE × TILE, повторённой по отмели: берётся ближайшая к кораблю
## копия (near_copy); смена копии бывает только дальше TILE/2 от корабля — там камень погашен (fade),
## перескока не видно. Камни освещаются (материал в OsypView): гребни осыпей ловят прожектор.
## «Экономно» — слой скрыт (OsypView.set_lite).

## Сторона плитки, м: больше 2 · FAR_OUT — в кольце видимости не бывает двух копий одного пятна.
const TILE := 160.0
## Кольцо видимости по горизонтали от корабля, м: полный размер до FAR_FULL, гаснет к FAR_OUT.
## Ближнего среза нет: камни лежат на дне, через корпус не летят.
const FAR_FULL := 38.0
const FAR_OUT := 55.0
## Пятна в плитке и камни в пятне.
const PATCHES := 20
const PER := 16
## Радиус пятна, м.
const R_MIN := 5.0
const R_MAX := 11.0
## Радиусы классов камней, м: крошка и камни — где угодно, валун — только у края полосы (band ≥ VALUN_BAND).
const KR_MIN := 0.06
const KR_MAX := 0.16
const KAM_MIN := 0.16
const KAM_MAX := 0.42
const VAL_MIN := 0.42
const VAL_MAX := 0.85
const VALUN_BAND := 0.55
## Доли классов по хешу размера: крошка 55 %, камни 33 %, валуны 12 %.
const KROSHKA := 0.55
const KAMEN := 0.88
## Камень утоплен в дно на долю SINK радиуса (лежит, не парит).
const SINK := 0.35
## Фоновая доля камней вне маршрута: отмель не мертва и в стороне, но заметно беднее.
const AMBIENT := 0.12
## Полоса маршрута (как у мелочи): до LANE м от оси пусто, плато mid…edge, спад к out.
const LANE := 7.0
## Участки маршрута 00 → 01 → 07 (PR #2111): [начало, конец, плотность, mid, edge, out]. У короткого
## плотного подхода к 01 полоса узкая — его камни не заливают спокойную середину ложбины (#1400).
const SEGS := [
	[Vector2(0.0, 95.0), Vector2(4.0, 80.0), 0.45, 10.0, 26.0, 40.0],      # выход 00 — крошка средне
	[Vector2(4.0, 80.0), Vector2(20.0, 23.0), 0.25, 12.0, 26.0, 40.0],     # ложбина — детрит у края, редко
	[Vector2(20.0, 23.0), Vector2(33.0, -22.0), 0.25, 12.0, 26.0, 40.0],   # ложбина — редко
	[Vector2(33.0, -22.0), Vector2(40.0, -50.0), 0.85, 8.0, 16.0, 26.0],   # подход к 01 — камни плотно
	[Vector2(40.0, -50.0), Vector2(-100.0, -240.0), 0.6, 12.0, 30.0, 44.0], # 01 → 07 — гряды с осыпями по краям
]
## Риф 01: камни у подошвы лепестков плотные даже ближе LANE к оси (зона осмотра рифа).
const REEF := Vector2(40.0, -50.0)
const REEF_R := 32.0
const REEF_K := 0.9
## Терраса врат 07: пол жёлоба чист, камни редки (внимание — к работе купольника).
const GATE := Vector2(-100.0, -240.0)
const GATE_R := 80.0
const GATE_K := 0.4
## Тон камня (серо-лиловая порода склонов `Seabed.color`, темнее песка) и разброс оттенка.
const COLOR := Color(0.30, 0.28, 0.34)
const SHADE := 0.55

const _BASE_X := 61
const _BASE_Z := 62
const _R := 63
const _OFF := 64
const _PRES := 66
const _TURN := 67
const _FORM := 68


static func count() -> int:
	return PATCHES * PER


## Середина пятна i в плитке (x, z), м.
static func base(i: int) -> Vector2:
	return Vector2(EcoVary.unit(i, _BASE_X) * TILE, EcoVary.unit(i, _BASE_Z) * TILE)


## Ближайшая к кораблю копия точки p плитки (по x и z).
static func near_copy(p: Vector2, ship: Vector2) -> Vector2:
	return Vector2(ship.x + wrapf(p.x - ship.x, -TILE * 0.5, TILE * 0.5),
		ship.y + wrapf(p.y - ship.y, -TILE * 0.5, TILE * 0.5))


## Доля размера по горизонтальному расстоянию d от корабля: 1 до FAR_FULL, 0 у FAR_OUT.
static func fade(d: float) -> float:
	return 1.0 - smoothstep(FAR_FULL, FAR_OUT, d)


## Профиль полосы маршрута: 0 на оси до LANE, 1 в кольце mid…edge, к out — 0.
static func band_seg(d: float, mid: float, edge: float, out: float) -> float:
	return smoothstep(LANE, mid, d) * (1.0 - smoothstep(edge, out, d))


## Расстояние от точки p до отрезка [a, b].
static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Доля камней в точке (x, z) по схеме участков: максимум по полосам отрезков маршрута против фона,
## у рифа — плотнее, у врат — реже. 0…1.
static func weight(p: Vector2) -> float:
	var w := AMBIENT
	for s in SEGS:
		w = maxf(w, s[2] * band_seg(_seg_dist(p, s[0], s[1]), s[3], s[4], s[5]))
	w = maxf(w, REEF_K * (1.0 - smoothstep(REEF_R * 0.55, REEF_R, p.distance_to(REEF))))
	if p.distance_to(GATE) < GATE_R:
		w *= GATE_K
	return clampf(w, 0.0, 1.0)


## Профиль полосы маршрута в точке p (0 на оси … 1 в плато края): чем ближе к краю, тем крупнее камни.
static func band_at(p: Vector2) -> float:
	var b := 0.0
	for s in SEGS:
		b = maxf(b, band_seg(_seg_dist(p, s[0], s[1]), s[3], s[4], s[5]))
	b = maxf(b, 1.0 - smoothstep(REEF_R * 0.55, REEF_R, p.distance_to(REEF)))
	return clampf(b, 0.0, 1.0)


## Радиус пятна i, м.
static func radius(i: int) -> float:
	return lerpf(R_MIN, R_MAX, EcoVary.unit(i, _R))


## Тон камня k = i · PER + j: COLOR темнее-светлее на SHADE.
static func tint(k: int) -> Color:
	var f := EcoVary.spread(k, EcoVary.SHADE, SHADE)
	return Color(COLOR.r * f, COLOR.g * f, COLOR.b * f)


## Радиус камня k при профиле полосы b (0 — ось, 1 — край), м; 0 — камня нет (валун вне края запрещён).
static func size_of(k: int, b: float) -> float:
	var h := EcoVary.unit(k, EcoVary.SIZE)
	if h < KROSHKA:
		return lerpf(KR_MIN, KR_MAX, h / KROSHKA)
	if h < KAMEN:
		return lerpf(KAM_MIN, KAM_MAX, (h - KROSHKA) / (KAMEN - KROSHKA))
	if b < VALUN_BAND:
		return 0.0    # валун только у края полосы хода
	return lerpf(VAL_MIN, VAL_MAX, (h - KAMEN) / (1.0 - KAMEN))


## Пятно i у корабля ship: [x, z — середина ближайшей копии, k — доля размера кольца (0 — не видно),
## дно под серединой, w — доля камней по схеме, b — профиль полосы]. Дно спрашивается раз на пятно.
static func patch_at(i: int, ship_pos: Vector3, ground: Callable) -> PackedFloat32Array:
	var ship := Vector2(ship_pos.x, ship_pos.z)
	var at := near_copy(base(i), ship)
	var k := fade(at.distance_to(ship))
	if k <= 0.0:
		return PackedFloat32Array([at.x, at.y, 0.0, 0.0, 0.0, 0.0])
	var floor_y := float(ground.call(at.x, at.y)) if ground.is_valid() else -30.0
	k *= EcoFarLife.alive(floor_y)
	if k <= 0.0:
		return PackedFloat32Array([at.x, at.y, 0.0, floor_y, 0.0, 0.0])
	return PackedFloat32Array([at.x, at.y, k, floor_y, weight(at), band_at(at)])


## Трансформ камня j пятна s = patch_at(i, …) (меш — радиус 1). Не виден или запрещён — сжат в точку.
## Дно под самим камнем — точно (огибающей у пятна нет: SINK топит камень в микрорельефе).
static func stone(i: int, j: int, s: PackedFloat32Array, ground: Callable) -> Transform3D:
	var c := Vector3(s[0], s[3], s[1])
	if s[2] <= 0.0:
		return Transform3D(Basis.from_scale(Vector3.ZERO), c)
	var k := i * PER + j
	# плотность участка — доля камней: хеш камня против weight пятна
	if EcoVary.unit(k, _PRES) >= s[4]:
		return Transform3D(Basis.from_scale(Vector3.ZERO), c)
	var size := size_of(k, s[5])
	if size <= 0.0:
		return Transform3D(Basis.from_scale(Vector3.ZERO), c)
	var r := radius(i)
	var ang := EcoVary.unit(k, _OFF) * TAU
	var rad := sqrt(EcoVary.unit(k, _OFF + 1)) * r
	var p := Vector2(c.x, c.z) + Vector2(cos(ang), sin(ang)) * rad
	var gy := float(ground.call(p.x, p.y)) if ground.is_valid() else c.y
	var yaw := EcoVary.unit(k, _TURN) * TAU
	# неодинаковые оси и приплюснутость по вертикали — валуны не похожи на шары
	var sx := size * lerpf(0.8, 1.3, EcoVary.unit(k, _FORM))
	var sy := size * lerpf(0.5, 0.8, EcoVary.unit(k, _FORM + 1))
	var sz := size * lerpf(0.8, 1.3, EcoVary.unit(k, _FORM + 2))
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sx, sy, sz) * s[2]),
		Vector3(p.x, gy + sy * (1.0 - SINK) * s[2], p.y))


## Трансформ камня j пятна i у корабля ship (для проверки; вид берёт patch_at + stone).
static func xform(i: int, j: int, ship: Vector3, ground: Callable) -> Transform3D:
	return stone(i, j, patch_at(i, ship, ground), ground)
