class_name EcoFishDust
extends RefCounted
## Муть у дна от светляков-полосников (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): стая всполошилась
## (EcoFish.Shoal.alarm был 0 — стал больше: хищник ближе EcoFish.PRED_ALARM или корабль пронёсся рядом) — рыбки,
## что шли у самого дна (ниже KICK_H над дном), бьют хвостом и поднимают облачко под собой, чуть позади по ходу
## (не больше KICK_MAX на стаю). Стая в тревоге добралась до дома в коралле (центр ближе HIDE_R к дому — как
## прячутся рыбки, EcoFish._step_members) и забилась в укрытие — если дом невысоко над дном (не выше HIDE_H), у дна
## под домом кольцом в RING м встаёт клуб из HIDE_N облачков. Стаи у кроны прячутся высоко в чаше — мути нет.
## Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают по течению,
## тают; светлее в луче прожектора) — свой пул на POOL мест, цвет — бурый ил рифа. Мир и его случай не меняются:
## что сделала стая — по её тревоге и месту между шагами (тревога едет гостю в кадре стай, EcoLink.apply_shoals),
## разброс — хешем EcoVary; поэтому у гостя муть та же. Шаг — проход по стаям (9) без обхода рыбок; рыбки —
## только в миг тревоги.
## Рисует FishView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле: на две-три стаи сразу по KICK_MAX и HIDE_N.
const POOL := 24
## Облачко под рыбкой ниже KICK_H над дном, не больше KICK_MAX на стаю (по номеру в стае), позади рыбки
## на KICK_BACK м против её хода; непрозрачность и доля размера (0,15 → 0,56 м).
const KICK_H := 2.0
const KICK_MAX := 3
const KICK_BACK := 0.35
const KICK_ALPHA := 0.32
const KICK_SCALE := 0.35
## Хвостом бьют не разом — за KICK_SPAN с.
const KICK_SPAN := 0.3
## Забились в коралл: центр стаи ближе HIDE_R к дому (как EcoFish: 4 м), дом не выше HIDE_H над дном.
const HIDE_R := 4.0
const HIDE_H := 5.0
## Клуб у дна под домом: облачков, непрозрачность, доля размера (0,3 → 0,96 м), кольцо RING м ± RING_SCATTER.
const HIDE_N := 3
const HIDE_ALPHA := 0.5
const HIDE_SCALE := 0.6
const RING := 1.4
const RING_SCATTER := 0.2
## Облачка клуба встают вразнобой за HIDE_SPAN с.
const HIDE_SPAN := 0.5
## Над дном в начале (м).
const BASE_LIFT := 0.15
const SALT := 277
## Цвет: бурый ил рифа (светлая муть на песке в луче не видна).
const COLOR := Color(0.2, 0.18, 0.15)
const LIT := Color(0.3, 0.27, 0.22)

var dust := EcoGrazerDust.new(POOL)
## Сколько облачков поднято (для тестов и ключей разброса).
var made := 0
var _alarm := PackedByteArray()
var _hid := PackedByteArray()
var _last := -1e9


## Забилась ли стая sh в укрытие: в тревоге, центр ближе HIDE_R к дому (стаи кроны — нет: дом высоко в чаше).
static func hiding(sh: EcoFish.Shoal) -> bool:
	return sh.alarm > 0.0 and not sh.crown and sh.alive > 0 \
			and sh.center.distance_squared_to(sh.home) < HIDE_R * HIDE_R


## Где встаёт облачко под рыбкой f (дно под ней — floor): позади на KICK_BACK против её хода.
static func kick_spot(f: EcoFish.Fish, floor: float) -> Vector3:
	var p := f.agent.p
	var back := Vector3(-f.agent.v.x, 0.0, -f.agent.v.z)
	back = back.normalized() * KICK_BACK if back.length_squared() > 1e-6 else Vector3.ZERO
	return Vector3(p.x + back.x, floor + BASE_LIFT, p.z + back.z)


## Где встаёт облачко n (c-е из count) клуба под домом home стаи (дно там — floor): кольцом ровно, с разбросом.
static func ring_spot(home: Vector3, floor: float, n: int, c: int = 0, count: int = 1) -> Vector3:
	var ang := (float(c) / maxi(1, count) + (EcoVary.unit(n, SALT) - 0.5) * 0.3) * TAU
	var r := RING * (1.0 + (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * RING_SCATTER)
	return Vector3(home.x + cos(ang) * r, floor + BASE_LIFT, home.z + sin(ang) * r)


## Шаг мути в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет; ground(x, z) — дно мира
## (пустой — мути нет: не знаем, где дно).
func update(system: EcoFish, t: float, ship: Vector3, ground: Callable = Callable()) -> void:
	if system == null:
		return
	var n := system.shoals.size()
	var fresh := t < _last or _last < -1e8 or _alarm.size() != n
	_last = t
	if fresh:   # первый шаг или новый забег — запомнить, мути нет
		_alarm.resize(n)
		_hid.resize(n)
		for i in n:
			var sh := system.shoals[i]
			_alarm[i] = 1 if sh.alarm > 0.0 else 0
			_hid[i] = 1 if hiding(sh) else 0
		return
	var can := ground.is_valid() and not EcoGrazerDust.lite
	for i in n:
		var sh := system.shoals[i]
		var al := 1 if sh.alarm > 0.0 else 0
		var hid := 1 if hiding(sh) else 0
		var rose := al == 1 and _alarm[i] == 0
		var went := hid == 1 and _hid[i] == 0
		_alarm[i] = al
		_hid[i] = hid
		if not can or not (rose or went) or sh.center.distance_to(ship) > EcoGrazerDust.NEAR:
			continue
		if rose:
			_kick(sh, t, ground)
		if went:
			var floor: float = ground.call(sh.home.x, sh.home.z)
			if sh.home.y - floor <= HIDE_H:
				_burst(sh, floor, t)


## Стая всполошилась: облачко под каждой живой рыбкой ниже KICK_H над дном, не больше KICK_MAX.
func _kick(sh: EcoFish.Shoal, t: float, ground: Callable) -> void:
	var k := 0
	for f: EcoFish.Fish in sh.members:
		if k >= KICK_MAX:
			return
		if not f.agent.alive:
			continue
		var floor := f.agent.ground_y(ground)
		if f.agent.p.y - floor > KICK_H:
			continue
		made += 1
		var key := made
		var born := t + KICK_SPAN * EcoVary.unit(key, SALT + 2)
		dust.add(kick_spot(f, floor), born, KICK_ALPHA * EcoVary.spread(key, SALT + 3, 0.2), key,
				KICK_SCALE * EcoVary.spread(key, SALT + 4, 0.15))
		k += 1


## Забились в коралл: HIDE_N облачков кольцом у дна под домом вразнобой за HIDE_SPAN с.
func _burst(sh: EcoFish.Shoal, floor: float, t: float) -> void:
	for c in HIDE_N:
		made += 1
		var key := made
		var born := t + HIDE_SPAN * EcoVary.unit(key, SALT + 5)
		dust.add(ring_spot(sh.home, floor, key, c, HIDE_N), born, HIDE_ALPHA * EcoVary.spread(key, SALT + 6, 0.2),
				key, HIDE_SCALE)
