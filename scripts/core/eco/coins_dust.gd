class_name EcoCoinsDust
extends RefCounted
## Муть у дна от глазунов и монетников (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): песчаный глазун лежит
## в песке у пятна мха. Бросился на монетника (EcoCoins.Glazun.lunge подскочил между шагами) — песок вокруг тела
## взлетает: кольцом у края тела (полуоси RING в осях глазуна) встаёт клуб из LUNGE_N облачков. Импульс сонара
## рассыпал стайку (EcoCoins.School.scatter вырос) — рыбки, что висели у самого мха (ниже KICK_H над дном), бьют
## хвостом и поднимают облачко под собой, чуть позади по ходу бегства (не больше KICK_MAX на стайку).
## Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают по течению,
## тают; светлее в луче прожектора) — свой пул на POOL мест, цвет — песок с илом под цвет глазуна. Мир и его случай
## не меняются: что сделали глазун и стайка — по их состоянию между шагами (lunge и scatter едут гостю в кадре
## монетников, EcoLink.apply_coins), разброс — хешем EcoVary; поэтому у гостя муть та же.
## Рисует CoinsView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле: три глазуна по LUNGE_N и три стайки по KICK_MAX, с запасом.
const POOL := 24
## Бросок глазуна: lunge вырос больше чем на LUNGE_JUMP за шаг (бросок ставит 1, дальше он спадает 2/с).
const LUNGE_JUMP := 0.3
## Клуб броска: облачков, непрозрачность, доля размера (0,3 → 0,96 м), кольцо у края тела (тело 0,9 × 0,6 м —
## CoinsView.build_glazun; полуоси вбок RING.x, вдоль RING.y), разброс радиуса ± RING_SCATTER (доля).
const LUNGE_N := 5
const LUNGE_ALPHA := 0.75
const LUNGE_SCALE := 0.6
const RING := Vector2(0.65, 0.5)
const RING_SCATTER := 0.15
## Облачка клуба встают вразнобой за BURST_SPAN с.
const BURST_SPAN := 0.3
## Стайка рассыпалась: scatter вырос больше чем на SCATTER_JUMP за шаг (импульс ставит 2,5 с, дальше он спадает
## и уходит в минус; кадр хоста у гостя чуть сдвигает его — это не новый импульс).
const SCATTER_JUMP := 0.5
## Облачко под рыбкой ниже KICK_H над дном, не больше KICK_MAX на стайку (по номеру в стайке),
## позади рыбки на KICK_BACK м против бегства (к угрозе); непрозрачность и доля размера (0,2 → 0,64 м).
const KICK_H := 1.2
const KICK_MAX := 3
const KICK_BACK := 0.3
const KICK_ALPHA := 0.3
const KICK_SCALE := 0.4
## Хвостом бьют не разом — за KICK_SPAN с.
const KICK_SPAN := 0.25
## Над дном в начале (м).
const BASE_LIFT := 0.15
const SALT := 151
## Цвет: песок с илом под тело глазуна (#8a7a60), темнее — бледная муть на светлом песке в луче не видна.
const COLOR := Color(0.22, 0.19, 0.14)
const LIT := Color(0.33, 0.29, 0.21)

var dust := EcoGrazerDust.new(POOL)
## Сколько облачков поднято (для тестов и ключей разброса).
var made := 0
var _lunge := PackedFloat32Array()
var _scatter := PackedFloat32Array()
var _last := -1e9


## Где встаёт облачко n (c-е из count) клуба броска глазуна gz: по кольцу у края тела ровно, с разбросом.
static func ring_spot(gz: EcoCoins.Glazun, n: int, c: int = 0, count: int = 1) -> Vector3:
	var ang := (float(c) / maxi(1, count) + (EcoVary.unit(n, SALT) - 0.5) * 0.3) * TAU
	var k := 1.0 + (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * RING_SCATTER
	var w := Basis(Vector3.UP, gz.yaw) * Vector3(cos(ang) * RING.x * k, 0.0, sin(ang) * RING.y * k)
	return Vector3(gz.pos.x + w.x, gz.pos.y + BASE_LIFT, gz.pos.z + w.z)


## Дно под монетником: последнее прочитанное (EcoCoins._coin_floor), иначе — середина пятна стайки.
static func coin_floor(cn: EcoCoins.Coin, sc: EcoCoins.School) -> float:
	return cn.gh if is_finite(cn.gx) else sc.center.y


## Где встаёт облачко под монетником cn стайки sc, что рассыпается прочь от sc.from: на дне, позади на KICK_BACK.
static func kick_spot(cn: EcoCoins.Coin, sc: EcoCoins.School) -> Vector3:
	var back := Vector3(sc.from.x - cn.pos.x, 0.0, sc.from.z - cn.pos.z)
	back = back.normalized() * KICK_BACK if back.length_squared() > 1e-4 else Vector3.ZERO
	return Vector3(cn.pos.x + back.x, coin_floor(cn, sc) + BASE_LIFT, cn.pos.z + back.z)


## Шаг мути в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoCoins, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var fresh := t < _last or _last < -1e8 or _lunge.size() != system.glazuns.size() \
			or _scatter.size() != system.schools.size()
	_last = t
	if fresh:   # первый шаг или новый забег — запомнить, мути нет
		_lunge.resize(system.glazuns.size())
		_scatter.resize(system.schools.size())
		for i in system.glazuns.size():
			_lunge[i] = system.glazuns[i].lunge
		for i in system.schools.size():
			_scatter[i] = system.schools[i].scatter
		return
	for i in system.glazuns.size():
		var gz := system.glazuns[i]
		var jump := gz.lunge - _lunge[i] > LUNGE_JUMP
		_lunge[i] = gz.lunge
		if jump and _near(gz.pos, ship):
			_burst(gz, t)
	for i in system.schools.size():
		var sc := system.schools[i]
		var rose := sc.scatter > 0.0 and sc.scatter - maxf(_scatter[i], 0.0) > SCATTER_JUMP
		_scatter[i] = sc.scatter
		if rose and _near(sc.center, ship):
			_kick(sc, t)


static func _near(at: Vector3, ship: Vector3) -> bool:
	return not EcoGrazerDust.lite and at.distance_to(ship) <= EcoGrazerDust.NEAR


## Бросок глазуна: LUNGE_N облачков кольцом у края тела вразнобой за BURST_SPAN с.
func _burst(gz: EcoCoins.Glazun, t: float) -> void:
	for c in LUNGE_N:
		made += 1
		var key := made
		var born := t + BURST_SPAN * c / float(LUNGE_N - 1) * EcoVary.unit(key, SALT + 2)
		dust.add(ring_spot(gz, key, c, LUNGE_N), born, LUNGE_ALPHA * EcoVary.spread(key, SALT + 3, 0.2), key,
				LUNGE_SCALE)


## Стайка рассыпалась: облачко под каждой живой рыбкой ниже KICK_H над дном, не больше KICK_MAX.
func _kick(sc: EcoCoins.School, t: float) -> void:
	var n := 0
	for cn in sc.members:
		if n >= KICK_MAX:
			return
		if not cn.alive or cn.pos.y - coin_floor(cn, sc) > KICK_H:
			continue
		made += 1
		var key := made
		var born := t + KICK_SPAN * EcoVary.unit(key, SALT + 4)
		dust.add(kick_spot(cn, sc), born, KICK_ALPHA * EcoVary.spread(key, SALT + 5, 0.2), key, KICK_SCALE)
		n += 1
