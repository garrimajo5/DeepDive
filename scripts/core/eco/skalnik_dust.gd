class_name EcoSkalnikDust
extends RefCounted
## Муть у дна от скальника (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): «камень» снимается с места — с него
## разом сходит клуб ила вокруг дома (WAKE_N облачков), возвращается и оседает — клуб слабее (SETTLE_N); ползёт у
## самого дна (подстерегает краба, домой — быстрее CRAWL м/с ниже LOW м над дном) — щупальца поднимают облачка
## позади тела, в броске к захвату лебёдки (быстрее RUSH) — чаще и гуще; бросил украденный образец дома — облачко
## у камешка. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают по
## течению, тают; светлее в луче прожектора) — свой пул на POOL мест, доля размера SCALE, цвет — серо-лиловый ил
## под цвет «камня». Мир и его случай не меняются: что делает скальник — по месту тела (дальше AWAY от дома — снялся)
## и его скорости между шагами, разброс — хешем EcoVary; поэтому у гостя сети муть та же по виду.
## Рисует SkalnikView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле (клуб 3 + след 3,6 с / 0,35 с ≈ 13).
const POOL := 16
## Доля размера облачка скребуна (0,5 → 1,6 м): у скальника 0,4 → 1,28 м.
const SCALE := 0.8
## Тело дальше этого от дома (м) — снялся с места (дома оно ровно на месте, HOME_DIST 0,5 — оседает).
const AWAY := 0.3
## Клуб при снятии с места: облачков, непрозрачность; при возвращении — меньше и слабее. Облачка встают вразнобой
## за BURST_SPAN с кольцом в RING м вокруг дома, с разбросом SCATTER.
const WAKE_N := 3
const WAKE_ALPHA := 0.8
const SETTLE_N := 2
const SETTLE_ALPHA := 0.4
const BURST_SPAN := 0.25
const RING := 0.7
const SCATTER := 0.25
## След: быстрее CRAWL (м/с: подстерегает 1,6, домой 1,8, с добычей 2,2, к стеклу 1,2 — высоко, нет) ниже LOW м
## над дном; пауза между облачками (с), ×(1 ± 0,2); быстрее RUSH (к захвату 5 м/с) — чаще и гуще.
const CRAWL := 1.0
const LOW := 0.8
const CRAWL_EVERY := 0.7
const CRAWL_ALPHA := 0.3
const RUSH := 3.5
const RUSH_EVERY := 0.35
const RUSH_ALPHA := 0.5
## Облачко следа позади тела (м).
const BEHIND := 0.8
## Брошенный образец: облачко у камешка.
const STASH_ALPHA := 0.45
## Над дном в начале (м).
const BASE_LIFT := 0.25
const SALT := 61
## Цвет: тёмный серо-лиловый ил под цвет «камня» (#4f4a5c) — в луче темнее светлого песка у норы, иначе не виден.
const COLOR := Color(0.20, 0.19, 0.22)
const LIT := Color(0.36, 0.34, 0.38)

var dust := EcoGrazerDust.new(POOL)
var _away := false
var _prev := Vector3.ZERO
var _loot := -1
var _next := 0.0
var _made := 0
var _last := -1e9


## Скальник sk снялся с места.
static func away(sk: EcoSkalnik.Octo) -> bool:
	return sk.pos.distance_to(sk.home) > AWAY


## Где встаёт облачко n клуба вокруг дома sk.
static func burst_spot(sk: EcoSkalnik.Octo, n: int) -> Vector3:
	var ang := EcoVary.unit(n, SALT) * TAU
	var r := RING + (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * SCATTER
	return sk.home + Vector3(cos(ang) * r, BASE_LIFT, sin(ang) * r)


## Как сильно скальник sk взбивает ил следом при скорости speed (по дну, без вертикали) (0 — никак); ground — дно мира.
static func strength(sk: EcoSkalnik.Octo, speed: float, ground: Callable) -> float:
	if sk == null or speed < CRAWL or not away(sk):
		return 0.0
	var floor_y := float(ground.call(sk.pos.x, sk.pos.z)) if ground.is_valid() else sk.home.y
	if sk.pos.y - floor_y >= LOW:
		return 0.0
	return RUSH_ALPHA if speed >= RUSH else CRAWL_ALPHA


## Где встаёт облачко n следа: на дне позади тела (против хода dir), с разбросом.
static func trail_spot(sk: EcoSkalnik.Octo, dir: Vector3, n: int, ground: Callable) -> Vector3:
	var fw := Vector3(dir.x, 0.0, dir.z)
	fw = fw.normalized() if fw.length_squared() > 1e-6 else Vector3.FORWARD
	var sx := (EcoVary.unit(n, SALT + 2) * 2.0 - 1.0) * SCATTER
	var sz := (EcoVary.unit(n, SALT + 3) * 2.0 - 1.0) * SCATTER
	var at := sk.pos - fw * BEHIND + Vector3(sx, 0.0, sz)
	at.y = (float(ground.call(at.x, at.z)) if ground.is_valid() else sk.home.y) + BASE_LIFT
	return at


## Шаг мути в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoSkalnik, t: float, ship: Vector3) -> void:
	if system == null or system.octo == null:
		return
	var sk := system.octo
	if t < _last or _last < -1e8:
		_away = away(sk)
		_prev = sk.pos
		_loot = sk.loot
		_next = t
		_last = t
		return
	var dt := t - _last
	_last = t
	var move := Vector3(sk.pos.x - _prev.x, 0.0, sk.pos.z - _prev.z)
	var speed := move.length() / dt if dt > 1e-6 else 0.0
	_prev = sk.pos
	var near := not EcoGrazerDust.lite and sk.pos.distance_to(ship) <= EcoGrazerDust.NEAR
	if _loot >= 0 and sk.loot < 0 and near and sk.pos.distance_to(sk.home) < EcoSkalnik.LOOT_HOME + 0.1:
		_made += 1
		var at := EcoSkalnik.stash_point(sk.home, _loot) + Vector3(0, BASE_LIFT, 0)
		dust.add(at, t, STASH_ALPHA, _made, SCALE * 0.7)
	_loot = sk.loot
	var now := away(sk)
	if now != _away:
		_away = now
		if near:
			_burst(sk, t, WAKE_N if now else SETTLE_N, WAKE_ALPHA if now else SETTLE_ALPHA)
		_next = t + CRAWL_EVERY
		return
	var k := strength(sk, speed, system.ground)
	if k <= 0.0:
		_next = maxf(_next, t)
		return
	if t < _next:
		return
	var key := _made + 1
	_next = t + (RUSH_EVERY if speed >= RUSH else CRAWL_EVERY) * EcoVary.spread(key, SALT + 4, 0.2)
	if not near:
		return
	_made += 1
	dust.add(trail_spot(sk, move, key, system.ground), t, k * EcoVary.spread(key, SALT + 5, 0.2), key, SCALE)


## Клуб вокруг дома: count облачков вразнобой за BURST_SPAN с.
func _burst(sk: EcoSkalnik.Octo, t: float, count: int, alpha: float) -> void:
	for c in count:
		_made += 1
		var key := _made
		var born := t + BURST_SPAN * c / float(maxi(1, count - 1)) * EcoVary.unit(key, SALT + 6)
		dust.add(burst_spot(sk, key), born, alpha * EcoVary.spread(key, SALT + 7, 0.2), key, SCALE)
