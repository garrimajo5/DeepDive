class_name EcoEchoDust
extends RefCounted
## Муть у дна от эхоловца (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): засадчик лежит у костей, присыпанный илом.
## Импульс сонара выдал его (EcoEcho.Lurker.revealed: был затаён — стал раскрыт) — он вздрагивает и стряхивает ил:
## вокруг тела овалом встаёт клуб из REVEAL_N облачков. Ударил по корпусу на выпрошенный импульс (Lurker.strikes
## вырос) — рывок поднимает ил под головой: STRIKE_N облачков впереди тела. Пока раскрыт, новый импульс мути не
## поднимает (он уже не затаён). Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты, растут,
## поднимаются, уплывают по течению, тают; светлее в луче прожектора) — свой пул на POOL мест, доля размера SCALE,
## цвет — серо-зелёный ил у костей. Мир и его случай не меняются: что сделал эхоловец — по его состоянию между
## шагами, разброс — хешем EcoVary; у гостя сети мир идёт сам, поэтому и муть та же.
## Рисует EchoView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле (клуб раскрытия и удар сразу, с запасом).
const POOL := 10
## Доля размера облачка скребуна (0,5 → 1,6 м): у эхоловца 0,6 → 1,92 м (тело — 3 м).
const SCALE := 1.2
## Раскрыт сонаром: облачков и непрозрачность — овалом вокруг тела (полуоси в осях тела: вбок RING.x, вдоль RING.y;
## тело — 1,2 × 3 м), с разбросом SCATTER.
const REVEAL_N := 5
const REVEAL_ALPHA := 0.75
const RING := Vector2(1.2, 2.0)
const SCATTER := 0.2
## Удар по корпусу: облачков, непрозрачность и где — под головой впереди тела (в осях тела), вразброс ± SPREAD вбок.
const STRIKE_N := 3
const STRIKE_ALPHA := 0.55
const HEAD := Vector3(0.0, 0.0, 1.9)
const SPREAD := 0.6
## Облачка встают вразнобой за BURST_SPAN с.
const BURST_SPAN := 0.35
## Над дном в начале (м); дно под телом — EcoEcho.UP ниже середины тела.
const BASE_LIFT := 0.25
const SALT := 97
## Цвет: серо-зелёный ил у костей — бледная муть на светлом песке в луче не видна.
const COLOR := Color(0.22, 0.24, 0.21)
const LIT := Color(0.36, 0.39, 0.34)

var dust := EcoGrazerDust.new(POOL)
var _revealed := false
var _strikes := 0
var _made := 0
var _last := -1e9


## Дно под телом эхоловца ec (его середина — на EcoEcho.UP выше).
static func floor_of(ec: EcoEcho.Lurker) -> float:
	return ec.p.y - EcoEcho.UP


## Где встаёт облачко n (c-е из count) клуба раскрытия: по овалу вокруг тела ровно, с разбросом угла и радиуса.
static func ring_spot(ec: EcoEcho.Lurker, n: int, c: int = 0, count: int = 1) -> Vector3:
	var ang := (float(c) / maxi(1, count) + (EcoVary.unit(n, SALT) - 0.5) * 0.3) * TAU
	var k := 1.0 + (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * SCATTER
	var local := Vector3(cos(ang) * RING.x * k, 0.0, sin(ang) * RING.y * k)
	var w := ec.xform() * local
	return Vector3(w.x, floor_of(ec) + BASE_LIFT, w.z)


## Где встаёт облачко n удара: под головой впереди тела, вразброс вбок.
static func strike_spot(ec: EcoEcho.Lurker, n: int) -> Vector3:
	var local := HEAD + Vector3((EcoVary.unit(n, SALT + 4) * 2.0 - 1.0) * SPREAD, 0.0,
			(EcoVary.unit(n, SALT + 5) - 0.5) * 0.4)
	var w := ec.xform() * local
	return Vector3(w.x, floor_of(ec) + BASE_LIFT, w.z)


## Шаг мути в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoEcho, t: float, ship: Vector3) -> void:
	if system == null or system.echo == null:
		return
	var ec := system.echo
	if t < _last or _last < -1e8:   # первый шаг или новый забег — запомнить, мути нет
		_revealed = ec.is_revealed()
		_strikes = ec.strikes
		_last = t
		return
	_last = t
	var was := _revealed
	_revealed = ec.is_revealed()
	var hit := ec.strikes > _strikes
	_strikes = ec.strikes
	if EcoGrazerDust.lite or ec.p.distance_to(ship) > EcoGrazerDust.NEAR:
		return
	if _revealed and not was:
		_burst(ec, t, REVEAL_N, REVEAL_ALPHA, false)
	if hit:
		_burst(ec, t, STRIKE_N, STRIKE_ALPHA, true)


## Клуб: count облачков вразнобой за BURST_SPAN с — вокруг тела или под головой (strike).
func _burst(ec: EcoEcho.Lurker, t: float, count: int, alpha: float, strike: bool) -> void:
	for c in count:
		_made += 1
		var key := _made
		var born := t + BURST_SPAN * c / float(maxi(1, count - 1)) * EcoVary.unit(key, SALT + 2)
		var at := strike_spot(ec, key) if strike else ring_spot(ec, key, c, count)
		dust.add(at, born, alpha * EcoVary.spread(key, SALT + 3, 0.2), key, SCALE)
