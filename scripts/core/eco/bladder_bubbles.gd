class_name EcoBladderBubbles
extends RefCounted
## Пузырьки от пузырчатки (docs/grafika-plan-eco.md, Б3 «Мелочь жизни», «облачка и пузырьки от существ»): луковицы
## лопаются — с каждой срывается POP_N пузырька газа и всплывает вместе с облаком спор; спелые луковицы (спелее
## SEEP_RIPE) понемногу сочатся — куст раз в SEEP_EVERY с выпускает пузырёк с одной из луковиц. Пузырёк поднимается
## со своей скоростью, виляет из стороны в сторону, течение его сносит, к концу жизни он чуть раздувается (давление
## падает) и тает. Мир и его случай не меняются: что делает куст — по его облаку спор и спелости между шагами
## (облако спор появилось — лопнул), разброс — хешем EcoVary; у гостя сети мир идёт сам, поэтому и пузырьки те же.
## Все пузырьки — один пул на POOL мест (старое уступает новому), рисует BladderView дочерним MultiMesh «Пузырьки»
## на общем шейдере EcoShaders.MIST (BUBBLE, `placed` — место и размер считает процессор) — +1 вызов отрисовки,
## шейдеров не прибавилось. «Экономно» — общий выключатель мелочи жизни EcoGrazerDust.lite: новых пузырьков нет.

## Мест в пуле: три куста лопаются разом — 3 × 7 × 2 = 42, и сочатся спелые.
const POOL := 64
## С каждой луковицы при лопании — пузырьков; срываются вразнобой за POP_SPAN с.
const POP_N := 2
const POP_SPAN := 0.6
## Спелые луковицы сочатся: куст раз в SEEP_EVERY с (× 1 ± SEEP_SPREAD) — один пузырёк.
const SEEP_RIPE := 0.75
const SEEP_EVERY := 2.4
const SEEP_SPREAD := 0.35
## Жизнь пузырька (с), скорость всплытия (м/с, × 1 ± RISE_SPREAD), размер в начале (м, × 1 ± SIZE_SPREAD) и рост
## к концу жизни.
const LIFE := 5.0
const RISE := 0.5
const RISE_SPREAD := 0.25
const SIZE := 0.12
const SIZE_SPREAD := 0.3
const GROW := 1.35
## Виляние: размах (м) и частота (рад/с), у пузырька своя фаза.
const WOBBLE := 0.06
const WOBBLE_RATE := 5.0
## Течение сносит пузырёк с этой долей своей скорости.
const DRIFT := 0.8
## Над луковицей в начале (м): срывается с её верха.
const LIFT := 0.12
## Непрозрачность ободка: при лопании — ярче, сочится — слабее.
const POP_ALPHA := 0.85
const SEEP_ALPHA := 0.55
## Дальше этого от корабля новых пузырьков нет (м).
const NEAR := 80.0
## Цвет: в темноте — бледно-зелёный отсвет сока луковиц; в луче прожектора — светлое серебро (пузырь блестит).
## Шейдер без света, поэтому свет луча — числом: EcoGrazerDust.light.
const COLOR := Color(0.40, 0.62, 0.48)
const LIT := Color(0.86, 0.94, 0.96)
const SALT := 131


## Пузырёк: где сорвался, когда, своя скорость, размер, фаза и непрозрачность.
class Bubble:
	extends RefCounted
	var at := Vector3.ZERO
	var born := -1e9
	var rise := RISE
	var size := SIZE
	var phase := 0.0
	var alpha := 0.0


var bubbles: Array[Bubble] = []
var _slot := 0
## Сколько раз пузырёк ставился в пул (рисунок по нему находит новые места пула, не перебирая весь пул).
var added := 0
var _made := 0
var _last := -1e9
## По кусту: облако спор на прошлом шаге и время следующего пузырька спелых луковиц.
var _life := PackedFloat32Array()
var _next := PackedFloat32Array()


func _init(pool: int = POOL) -> void:
	for i in pool:
		bubbles.append(Bubble.new())


## Пузырёк в точке at в момент t с непрозрачностью alpha; key — номер для разброса. Старое уступает новому.
func add(at: Vector3, t: float, alpha: float, key: int) -> Bubble:
	var b := bubbles[_slot]
	_slot = (_slot + 1) % bubbles.size()
	added += 1
	b.at = at
	b.born = t
	b.alpha = alpha
	b.rise = RISE * EcoVary.spread(key, SALT, RISE_SPREAD)
	b.size = SIZE * EcoVary.spread(key, SALT + 1, SIZE_SPREAD)
	b.phase = EcoVary.unit(key, SALT + 2) * TAU
	return b


## Место пула, куда встанет следующий пузырёк.
func slot() -> int:
	return _slot


## Возраст пузырька в долях жизни (0…1; > 1 — растаял, < 0 — ещё не сорвался).
static func age(b: Bubble, t: float) -> float:
	return (t - b.born) / LIFE


static func alive(b: Bubble, t: float) -> bool:
	var a := age(b, t)
	return a >= 0.0 and a < 1.0


## Размер в момент t: раздувается к концу в GROW раз.
static func size(b: Bubble, t: float) -> float:
	return b.size * lerpf(1.0, GROW, clampf(age(b, t), 0.0, 1.0))


## Непрозрачность в момент t: проявляется за двадцатую жизни, тает за последнюю треть.
static func fade(b: Bubble, t: float) -> float:
	var a := age(b, t)
	if a < 0.0 or a >= 1.0:
		return 0.0
	return b.alpha * minf(1.0, a / 0.05) * minf(1.0, (1.0 - a) / 0.3)


## Место в момент t: всплывает со своей скоростью, виляет поперёк (в плоскости xz по своей фазе), течение flow
## (м/с) сносит с долей DRIFT.
static func pos(b: Bubble, t: float, flow: Vector3) -> Vector3:
	var dt := clampf(age(b, t), 0.0, 1.0) * LIFE
	var w := sin(dt * WOBBLE_RATE + b.phase) * WOBBLE * minf(1.0, dt * 2.0)
	var side := Vector3(cos(b.phase), 0.0, sin(b.phase))
	return b.at + Vector3(0, b.rise * dt, 0) + side * w + Vector3(flow.x, 0.0, flow.z) * DRIFT * dt


## Откуда срывается пузырёк: верх луковицы стебля k куста bl в момент t.
static func spot(bl: EcoBladder.Bush, k: int, t: float) -> Vector3:
	return EcoBladder.bulb(bl, k, t) + Vector3(0, LIFT, 0)


## Пауза до следующего пузырька спелых луковиц куста i.
static func every(i: int, n: int) -> float:
	return SEEP_EVERY * EcoVary.spread(i * 977 + n, SALT + 3, SEEP_SPREAD)


## Шаг в момент t (время мира): лопнувшие кусты выпускают пузырьки со всех луковиц, спелые — сочатся.
## ship — корабль: дальше NEAR — новых нет.
func update(system: EcoBladder, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var n := system.bushes.size()
	if t < _last or _last < -1e8 or _life.size() != n:
		_life.resize(n)
		_next.resize(n)
		for bl in system.bushes:
			_life[bl.index] = bl.life
			_next[bl.index] = t + EcoVary.unit(bl.index, SALT + 4) * SEEP_EVERY
		_last = t
		return
	_last = t
	for bl in system.bushes:
		var i := bl.index
		var popped := bl.life > _life[i] + 1e-4
		_life[i] = bl.life
		var seeping := not bl.popped() and bl.ripe > SEEP_RIPE
		var due := seeping and t >= _next[i]
		if not seeping:
			_next[i] = maxf(_next[i], t)
		elif due:
			_next[i] = t + every(i, _made)
		if not popped and not due:
			continue
		if EcoGrazerDust.lite or bl.base.distance_to(ship) > NEAR:
			continue
		if popped:
			_pop(bl, t)
		else:
			_made += 1
			var key := _made
			var k := int(EcoVary.unit(key, SALT + 5) * EcoBladder.STEMS) % EcoBladder.STEMS
			add(spot(bl, k, t), t, SEEP_ALPHA * EcoVary.spread(key, SALT + 6, 0.2), key)


## Луковицы лопнули: с каждой — POP_N пузырьков вразнобой за POP_SPAN с.
func _pop(bl: EcoBladder.Bush, t: float) -> void:
	for k in EcoBladder.STEMS:
		for c in POP_N:
			_made += 1
			var key := _made
			var born := t + POP_SPAN * EcoVary.unit(key, SALT + 7)
			add(spot(bl, k, t), born, POP_ALPHA * EcoVary.spread(key, SALT + 6, 0.15), key)


## Сколько пузырьков видно в момент t.
func shown(t: float) -> int:
	var n := 0
	for b in bubbles:
		if alive(b, t):
			n += 1
	return n
