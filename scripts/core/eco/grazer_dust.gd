class_name EcoGrazerDust
extends RefCounted
## Муть у дна от скребунов (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): пасущийся скребун поднимает скребком
## облачко ила перед носом, идущий — слабое облачко из-под лап. Облачко встаёт там, где поднято (за скребуном не
## ходит), за LIFE с раздувается, поднимается на RISE и уплывает по течению, тает к концу. Мир и его случай не
## меняются: ритм и разброс — хешем EcoVary от номера скребуна и номера облачка, поэтому у гостя сети муть та же
## по виду (скребуны у него из кадра хоста). Все облачка — один пул на POOL мест (старое уступает новому), рисует
## GrazerView одним MultiMesh (общий шейдер EcoShaders.MIST, режим INK) — +1 вызов отрисовки, шейдеров не прибавилось.
## «Экономно» — `lite`: новых облачков нет.

## Мест в пуле на всех скребунов.
const POOL := 48
## Жизнь облачка (с), подъём (м), размер в начале и в конце (м).
const LIFE := 3.6
const RISE := 0.5
const SIZE_START := 0.5
const SIZE_END := 1.6
## Пауза между облачками у пасущегося и у идущего скребуна (с); у каждого скребуна ×(1 ± RATE_SPREAD).
const GRAZE_EVERY := 0.8
const WALK_EVERY := 1.7
const RATE_SPREAD := 0.2
## Непрозрачность в пике: от скребка — гуще, из-под лап — слабее.
const GRAZE_ALPHA := 0.55
const WALK_ALPHA := 0.25
## Скребок — впереди по курсу, перед панцирем (м), разброс места облачка (м), высота над дном в начале (м).
const SNOUT := 1.1
const SCATTER := 0.25
const BASE_LIFT := 0.35
## Середина облачка над видимым дном — не ниже этой доли его размера (above).
const CLEAR := 0.35
## Течение уносит облачко с этой долей своей скорости (у дна поток слабее).
const DRIFT := 0.6
## Дальше этого от корабля новых облачков не поднимают — их не видно (м).
const NEAR := 80.0
## Цвет ила: в темноте — серо-зелёный, как придонная пыль; в луче прожектора — светлый (взвесь ловит свет).
## Шейдер мути без света (общий MIST), поэтому свет луча — числом: `light`.
const COLOR := Color(0.30, 0.34, 0.31)
const LIT := Color(0.66, 0.72, 0.64)
## Соль номера облачка для EcoVary.
const SALT := 11

## Выключатель «Экономно» для всех: новых облачков нет, поднятые дотаивают.
static var lite := false


## Облачко: где поднято, когда, своя непрозрачность и разброс.
class Puff:
	extends RefCounted
	var at := Vector3.ZERO
	var born := -1e9
	var alpha := 0.0
	var key := 0
	## Высота видимого дна под местом подъёма (считает рисунок один раз на облачко; −INF — ещё не считана).
	var floor_y := -INF


var puffs: Array[Puff] = []
## Время следующего облачка у каждого скребуна (по номеру).
var _next := PackedFloat32Array()
var _slot := 0
var _made := 0
var _last := -1e9


## pool — мест в пуле (у скребунов POOL; кольчужнику хватает меньше — EcoKrabDust).
func _init(pool: int = POOL) -> void:
	for i in pool:
		puffs.append(Puff.new())


## Поднять облачко в точке at в момент t с непрозрачностью alpha; key — номер для разброса. Старое уступает новому.
func add(at: Vector3, t: float, alpha: float, key: int) -> Puff:
	var p := puffs[_slot]
	_slot = (_slot + 1) % puffs.size()
	p.key = key
	p.at = at
	p.born = t
	p.alpha = alpha
	p.floor_y = -INF
	return p


## Пауза до следующего облачка скребуна g (пасётся — чаще).
static func every(g: EcoGrazer.Grazer) -> float:
	var base := GRAZE_EVERY if g.grazing() else WALK_EVERY
	return base * EcoVary.spread(g.index, EcoVary.RATE + SALT, RATE_SPREAD)


## Поднимает ли скребун муть сейчас: пасётся или идёт.
static func stirs(g: EcoGrazer.Grazer) -> bool:
	return g.grazing() or EcoGrazerLook.walking(g)


## Возраст облачка в долях жизни (0…1; > 1 — растаяло).
static func age(p: Puff, t: float) -> float:
	return (t - p.born) / LIFE


## Жива ли муть облачка в момент t.
static func alive(p: Puff, t: float) -> bool:
	var a := age(p, t)
	return a >= 0.0 and a < 1.0


## Размер облачка в момент t: быстро раздувается и замедляется (ease-out).
static func size(p: Puff, t: float) -> float:
	var a := clampf(age(p, t), 0.0, 1.0)
	return lerpf(SIZE_START, SIZE_END, 1.0 - (1.0 - a) * (1.0 - a))


## Непрозрачность в момент t: проявляется за десятую жизни, ровно тает к концу.
static func fade(p: Puff, t: float) -> float:
	var a := age(p, t)
	if a < 0.0 or a >= 1.0:
		return 0.0
	return p.alpha * minf(1.0, a / 0.1) * (1.0 - a)


## Место облачка в момент t: поднимается и уплывает по течению flow (м/с).
static func pos(p: Puff, t: float, flow: Vector3) -> Vector3:
	var a := clampf(age(p, t), 0.0, 1.0)
	var dt := a * LIFE
	var rise := RISE * (1.0 - (1.0 - a) * (1.0 - a))
	return p.at + Vector3(flow.x, 0.0, flow.z) * DRIFT * dt + Vector3(0, rise, 0)


## Где поднять облачко скребуна g (номер облачка n): у скребка впереди или под брюхом, с разбросом.
static func spot(g: EcoGrazer.Grazer, n: int) -> Vector3:
	var o := EcoGrazerLook.origin(g)
	var fw := EcoGrazerLook.forward(g)
	var ahead := SNOUT if g.grazing() else -0.9
	var sx := (EcoVary.unit(n, SALT) * 2.0 - 1.0) * SCATTER
	var sz := (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * SCATTER
	return o + fw * ahead + Vector3(sx, BASE_LIFT, sz)


## Шаг мути в момент t (время мира): скребуны system поднимают новые облачка. ship — корабль: дальше NEAR — нет.
func update(system: EcoGrazer, t: float, ship: Vector3) -> void:
	if _next.size() != system.all.size() or t < _last:
		_next.resize(system.all.size())
		for g in system.all:
			_next[g.index] = t + EcoVary.unit(g.index, SALT + 2) * GRAZE_EVERY
	_last = t
	for g in system.all:
		if not stirs(g):
			_next[g.index] = maxf(_next[g.index], t)
			continue
		if t < _next[g.index]:
			continue
		_next[g.index] = t + every(g)
		if lite or g.agent.p.distance_to(ship) > NEAR:
			continue
		_made += 1
		var key := _made * 16 + g.index
		add(spot(g, key), t, (GRAZE_ALPHA if g.grazing() else WALK_ALPHA) * EcoVary.spread(key, SALT + 3, 0.25), key)


## Высота середины облачка размером s над видимым дном floor_y: не ниже доли CLEAR размера — облачко лицом к
## камере, нижняя его половина иначе уходит под сетку дна.
static func above(y: float, s: float, floor_y: float) -> float:
	return maxf(y, floor_y + s * CLEAR)


## Насколько облачко в точке at освещено прожектором корабля ship (0…1): ближе к кораблю — светлее, за дальностью
## луча — темно; прожектор погашен — 0.
static func light(at: Vector3, ship: EcoLink.ShipState) -> float:
	if ship == null or not ship.light_on or ship.light_range <= 0.0:
		return 0.0
	var k := 1.0 - at.distance_to(ship.pos) / ship.light_range
	return clampf(k * 2.0, 0.0, 1.0)


## Цвет облачка при свете k (0…1).
static func tone(k: float) -> Color:
	return COLOR.lerp(LIT, clampf(k, 0.0, 1.0))


## Сколько облачков видно в момент t.
func shown(t: float) -> int:
	var n := 0
	for p in puffs:
		if alive(p, t):
			n += 1
	return n
