class_name EcoPredDust
extends RefCounted
## Муть у дна от броска серпохвоста (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): хищник, что несётся у самого
## дна (охота, бросок на корабль, бегство — быстрее FAST м/с ниже LOW м над дном), волной от тела и хвоста взбивает ил — позади
## тела на дне встают облачка, попеременно слева и справа от следа. Чем ниже и быстрее — тем гуще. Облачка те же,
## что у скребунов (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают по течению, тают; светлее в
## луче прожектора) — свой пул на POOL мест на всех серпохвостов. Мир и его случай не меняются: разброс — хешем
## EcoVary от номера облачка; у гостя хищники идут в его мире, муть та же по виду.
## Рисует PredView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле на всех хищников (жизнь облачка 3,6 с / пауза 0,2 с ≈ 18 на одного; у дна разом редко больше одного).
const POOL := 24
## Взбивает ил быстрее этой скорости (м/с: охота 7,6, бросок 9,5, бегство 9; патруль 3 и разведка 5,5 — нет)…
const FAST := 6.5
## …и ниже этой высоты над дном (м; ближе EcoAgent.clearance 1,8 хищник к дну не опускается).
const LOW := 5.0
## Пауза между облачками у самого дна (с); выше — реже (до ×2 у LOW), у каждого облачка ×(1 ± 0,2).
const EVERY := 0.2
## Непрозрачность в пике у самого дна в броске; у LOW — доля MIN_K.
const ALPHA := 0.7
const MIN_K := 0.3
## Хвост позади середины тела (м; серпохвост ~6 м), облачко — в сторону от следа (м), разброс (м), над дном (м).
const TAIL := 2.6
const SIDE := 0.6
const SCATTER := 0.3
const BASE_LIFT := 0.3
const SALT := 37
## Цвет: хвост поднимает тёмный ил из-под песка — темнее светлого песка в луче, как у кольчужника.
const COLOR := Color(0.24, 0.24, 0.20)
const LIT := Color(0.54, 0.54, 0.46)

var dust := EcoGrazerDust.new(POOL)
## Время следующего облачка у каждого хищника (по номеру).
var _next := PackedFloat32Array()
var _made := 0
var _last := -1e9


## Высота хищника pr над дном (ground — (x, z) -> float; без дна — бесконечность).
static func height(pr: EcoPred.Pred, ground: Callable) -> float:
	if not ground.is_valid():
		return INF
	return pr.agent.p.y - pr.agent.ground_y(ground)


## Как сильно хищник pr взбивает ил сейчас (0 — никак, 1 — у самого дна): быстрее FAST и ниже LOW.
static func strength(pr: EcoPred.Pred, ground: Callable) -> float:
	if pr == null or not pr.agent.alive or pr.agent.v.length() < FAST:
		return 0.0
	var h := height(pr, ground)
	if h >= LOW:
		return 0.0
	var low := clampf((LOW - h) / (LOW - pr.agent.clearance), 0.0, 1.0)
	return lerpf(MIN_K, 1.0, low)


## Пауза до следующего облачка при силе k (ниже — чаще).
static func every(k: float, n: int) -> float:
	return EVERY * lerpf(2.0, 1.0, clampf((k - MIN_K) / (1.0 - MIN_K), 0.0, 1.0)) * EcoVary.spread(n, SALT + 2, 0.2)


## Где поднять облачко номер n (номер × 4 + хищник): на дне позади тела (у хвоста), попеременно слева и справа от следа, с разбросом.
static func spot(pr: EcoPred.Pred, n: int, ground: Callable) -> Vector3:
	var fw := Vector3(pr.look.x, 0.0, pr.look.z)
	if fw.length_squared() < 1e-6:
		fw = Vector3(pr.agent.v.x, 0.0, pr.agent.v.z)
	fw = fw.normalized() if fw.length_squared() > 1e-6 else Vector3.FORWARD
	var side := Vector3(-fw.z, 0.0, fw.x) * (SIDE if (n >> 2) % 2 == 0 else -SIDE)
	var sx := (EcoVary.unit(n, SALT) * 2.0 - 1.0) * SCATTER
	var sz := (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * SCATTER
	var at := pr.agent.p - fw * TAIL + side + Vector3(sx, 0.0, sz)
	at.y = (float(ground.call(at.x, at.z)) if ground.is_valid() else pr.agent.p.y - pr.agent.clearance) + BASE_LIFT
	return at


## Шаг мути в момент t (время мира): хищники system у дна поднимают облачка. ship — корабль: дальше
## EcoGrazerDust.NEAR — нет; ground — дно мира.
func update(system: EcoPred, t: float, ship: Vector3, ground: Callable) -> void:
	if system == null:
		return
	if _next.size() != system.all.size() or t < _last:
		_next.resize(system.all.size())
		_next.fill(t)
	_last = t
	for pr in system.all:
		var k := strength(pr, ground)
		if k <= 0.0:
			_next[pr.index] = maxf(_next[pr.index], t)
			continue
		if t < _next[pr.index]:
			continue
		var key := (_made + 1) * 4 + pr.index
		_next[pr.index] = t + every(k, key)
		if EcoGrazerDust.lite or pr.agent.p.distance_to(ship) > EcoGrazerDust.NEAR:
			continue
		_made += 1
		dust.add(spot(pr, key, ground), t, ALPHA * k * EcoVary.spread(key, SALT + 3, 0.2), key)
