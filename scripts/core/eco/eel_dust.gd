class_name EcoEelDust
extends RefCounted
## Муть у дна от стеклоуста (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): засадчик вылетает из расщелины —
## у устья логова разом встаёт клуб ила (OUT_N облачков), возвращается и прячется — клуб слабее (IN_N); несётся у
## самого дна (бросок на скребуна, бегство — быстрее FAST м/с ниже LOW м над дном) — под головой позади встают
## облачка следа. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают
## по течению, тают; светлее в луче прожектора) — свой пул на POOL мест на все логова, доля размера SCALE (тело
## угря тонкое), цвет — серый ил расщелин. Мир и его случай не меняются: что делает угорь — по месту головы
## (дальше EXIT_R от устья — снаружи) и её скорости между шагами, разброс — хешем EcoVary; поэтому у гостя сети
## (существа рядом из кадра хоста) муть та же по виду.
## Рисует EelView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле на все логова (клуб 4 + след 3,6 с / 0,3 с ≈ 12 на угря; разом в броске обычно один).
const POOL := 24
## Доля размера облачка скребуна (0,5 → 1,6 м): у угря 0,45 → 1,44 м.
const SCALE := 0.9
## Голова дальше этого от устья (м) — угорь снаружи (в логове она в 0,15…0,45 м).
const EXIT_R := 1.6
## Клуб при выходе: облачков, непрозрачность; при возвращении — меньше и слабее. Облачка клуба встают вразнобой
## за BURST_SPAN с, в BURST_OUT м наружу от устья, с разбросом BURST_SCATTER м.
const OUT_N := 4
const OUT_ALPHA := 0.8
const IN_N := 2
const IN_ALPHA := 0.5
const BURST_SPAN := 0.3
const BURST_OUT := 1.2
const BURST_SCATTER := 0.6
## След: быстрее FAST (м/с: бросок 11, бегство 12, к кораблю 10, домой 6 — нет) и ниже LOW м над дном; пауза
## между облачками (с), ×(1 ± 0,2); непрозрачность у самого дна, у LOW — доля MIN_K; облачко позади головы (м).
const FAST := 7.0
const LOW := 2.5
const TRAIL_EVERY := 0.3
const TRAIL_ALPHA := 0.45
const MIN_K := 0.35
const BEHIND := 0.9
const SCATTER := 0.2
## Над дном в начале (м).
const BASE_LIFT := 0.25
const SALT := 53
## Цвет: серый ил из каменных расщелин — темнее светлого песка в луче.
const COLOR := Color(0.21, 0.21, 0.21)
const LIT := Color(0.44, 0.45, 0.44)

var dust := EcoGrazerDust.new(POOL)
## У каждого угря (по номеру): голова снаружи логова, где была голова, когда следующее облачко следа.
var _out: Array[bool] = []
var _prev := PackedVector3Array()
var _next := PackedFloat32Array()
var _made := 0
var _last := -1e9


## Голова угря e снаружи логова.
static func outside(e: EcoEel.Eel) -> bool:
	return e.agent.p.distance_to(e.lair) > EXIT_R


## Дно под устьем логова (устье — на MOUTH_UP над дном и MOUTH_OUT наружу).
static func lair_floor(e: EcoEel.Eel) -> float:
	return e.lair.y - EcoEel.MOUTH_UP


## Где встаёт облачко n клуба у устья логова e.
static func burst_spot(e: EcoEel.Eel, n: int) -> Vector3:
	var sx := (EcoVary.unit(n, SALT) * 2.0 - 1.0) * BURST_SCATTER
	var sz := (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * BURST_SCATTER
	var at := e.lair + e.out * BURST_OUT + Vector3(sx, 0.0, sz)
	at.y = lair_floor(e) + BASE_LIFT
	return at


## Как сильно угорь e взбивает ил следом (0 — никак, 1 — у самого дна) при скорости speed; ground — дно мира.
static func strength(e: EcoEel.Eel, speed: float, ground: Callable) -> float:
	if e == null or speed < FAST or not ground.is_valid() or not outside(e):
		return 0.0
	var h := e.agent.p.y - float(ground.call(e.agent.p.x, e.agent.p.z))
	if h >= LOW:
		return 0.0
	return lerpf(MIN_K, 1.0, clampf((LOW - h) / LOW, 0.0, 1.0))


## Где встаёт облачко n следа: на дне позади головы, с разбросом.
static func trail_spot(e: EcoEel.Eel, n: int, ground: Callable) -> Vector3:
	var fw := Vector3(e.face.x, 0.0, e.face.z)
	fw = fw.normalized() if fw.length_squared() > 1e-6 else Vector3.FORWARD
	var sx := (EcoVary.unit(n, SALT + 2) * 2.0 - 1.0) * SCATTER
	var sz := (EcoVary.unit(n, SALT + 3) * 2.0 - 1.0) * SCATTER
	var at := e.agent.p - fw * BEHIND + Vector3(sx, 0.0, sz)
	at.y = float(ground.call(at.x, at.z)) + BASE_LIFT
	return at


## Шаг мути в момент t (время мира): угри system у логова и у дна поднимают облачка. ship — корабль: дальше
## EcoGrazerDust.NEAR — нет; ground — дно мира (без него — только клубы у логова).
func update(system: EcoEel, t: float, ship: Vector3, ground: Callable = Callable()) -> void:
	if system == null:
		return
	var n := system.eels.size()
	var fresh := _out.size() != n or t < _last
	if fresh:
		_out.resize(n)
		_prev.resize(n)
		_next.resize(n)
		for e in system.eels:
			_out[e.index] = outside(e)
			_prev[e.index] = e.agent.p
			_next[e.index] = t
	var dt := t - _last
	_last = t
	if fresh:
		return
	for e in system.eels:
		var i := e.index
		var was_out := _out[i]
		var now_out := outside(e)
		_out[i] = now_out
		var speed := e.agent.p.distance_to(_prev[i]) / dt if dt > 1e-6 else 0.0
		_prev[i] = e.agent.p
		var near := not EcoGrazerDust.lite and e.agent.p.distance_to(ship) <= EcoGrazerDust.NEAR
		if now_out != was_out:
			if near:
				_burst(e, t, OUT_N if now_out else IN_N, OUT_ALPHA if now_out else IN_ALPHA)
			_next[i] = t + TRAIL_EVERY
			continue
		var k := strength(e, speed, ground)
		if k <= 0.0:
			_next[i] = maxf(_next[i], t)
			continue
		if t < _next[i]:
			continue
		var key := (_made + 1) * 4 + i
		_next[i] = t + TRAIL_EVERY * EcoVary.spread(key, SALT + 4, 0.2)
		if not near:
			continue
		_made += 1
		dust.add(trail_spot(e, key, ground), t, TRAIL_ALPHA * k * EcoVary.spread(key, SALT + 5, 0.2), key, SCALE)


## Клуб у устья логова e: count облачков вразнобой за BURST_SPAN с.
func _burst(e: EcoEel.Eel, t: float, count: int, alpha: float) -> void:
	for c in count:
		_made += 1
		var key := _made * 4 + e.index
		var born := t + BURST_SPAN * c / float(maxi(1, count - 1)) * EcoVary.unit(key, SALT + 6)
		dust.add(burst_spot(e, key), born, alpha * EcoVary.spread(key, SALT + 7, 0.2), key, SCALE)
