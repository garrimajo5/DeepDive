class_name EcoCoralDust
extends RefCounted
## Облачка слизи у огнецвета (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): полипы рывком втягивают светящиеся
## кончики — и выдыхают воду со слизью. Куст гаснет быстро (свет падает быстрее SNAP_RATE в секунду), начав с
## горящего (не меньше EcoCoral.DARK): разряд (свет упал разом на ZAP_DROP и больше) — клуб из ZAP_N облачков у
## кончиков, импульс сонара (разом на PING_DROP) — PING_N, шумный ход корабля рядом (гаснет плавно, ~1 с) — NOISE_N
## слабых. Погасший куст и медленное разгорание слизи не дают. Облачко встаёт у кончика ветки (вершина кончика из
## меша EcoCoralLook в осях куста), растёт, поднимается, уплывает по течению и тает — пул EcoGrazerDust на POOL мест,
## доля размера SCALE, цвет — бледная оранжево-бурая слизь (в луче — светлее). Мир и его случай не меняются: что
## делает куст — по его свету между шагами, разброс — хешем EcoVary.
## Рисует CoralView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле (3 куста × клуб разряда 5 + запас).
const POOL := 18
## Доля размера облачка скребуна (0,5 → 1,6 м): у кончиков 0,3 → 0,96 м.
const SCALE := 0.6
## Гаснет рывком: свет падает быстрее SNAP_RATE в секунду (шум — 0,8/с, разгорается — 0,04/с вверх).
const SNAP_RATE := 0.5
## Свет упал за шаг разом: на ZAP_DROP — разряд, на PING_DROP — импульс сонара (EcoCoral.PING_DIM = 0,5).
const ZAP_DROP := 0.6
const PING_DROP := 0.3
## Облачков и непрозрачность (× свет куста в начале рывка).
const ZAP_N := 5
const ZAP_ALPHA := 0.75
const PING_N := 3
const PING_ALPHA := 0.55
const NOISE_N := 2
const NOISE_ALPHA := 0.35
## Облачка встают вразнобой за BURST_SPAN с у разных кончиков, чуть над ними (LIFT м).
const BURST_SPAN := 0.35
const LIFT := 0.1
const SALT := 83
## Цвет: бледная оранжево-бурая слизь (в тон погасших кончиков) — на тёмной воде над кустом видна.
const COLOR := Color(0.40, 0.30, 0.24)
const LIT := Color(0.78, 0.60, 0.46)

enum Kind { NONE, NOISE, PING, ZAP }

## Номера вершин кончиков в меше EcoCoralLook (кончик — шар; берём его вершины).
static var _tips := PackedInt32Array()

var dust := EcoGrazerDust.new(POOL)
var _glow := PackedFloat32Array()
var _snap := PackedByteArray()
var _made := 0
var _last := -1e9


## Какой рывок: свет был was, стал now за dt с; dimming — куст уже гас прошлым шагом (плавный шум — один раз).
static func kind(was: float, now: float, dt: float, dimming: bool) -> Kind:
	if was < EcoCoral.DARK or dt <= 0.0:
		return Kind.NONE
	var drop := was - now
	if drop >= ZAP_DROP:
		return Kind.ZAP
	if drop >= PING_DROP:
		return Kind.PING
	if drop / dt > SNAP_RATE and not dimming:
		return Kind.NOISE
	return Kind.NONE


## Где встаёт облачко n: у одного из кончиков куста b (вершина кончика в мире), чуть выше.
static func tip_spot(b: EcoCoral.Bush, n: int) -> Vector3:
	if _tips.is_empty():
		for i in EcoCoralLook.parts.size():
			if EcoCoralLook.parts[i] == EcoCoralLook.Part.TIP:
				_tips.append(i)
	if _tips.is_empty():
		return b.top
	var v := _tips[mini(_tips.size() - 1, int(EcoVary.unit(n, SALT) * _tips.size()))]
	return EcoCoralLook.transform(b) * EcoCoralLook.verts[v] + Vector3(0, LIFT, 0)


## Шаг облачков в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoCoral, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var n := system.bushes.size()
	if t < _last or _last < -1e8 or _glow.size() != n:
		_glow.resize(n)
		_snap.resize(n)
		for i in n:
			_glow[i] = system.bushes[i].glow
			_snap[i] = 0
		_last = t
		return
	var dt := t - _last
	_last = t
	if dt <= 1e-6:
		return
	for i in n:
		var b := system.bushes[i]
		var was := _glow[i]
		_glow[i] = b.glow
		var k := kind(was, b.glow, dt, _snap[i] != 0)
		_snap[i] = 1 if (was - b.glow) / dt > SNAP_RATE else 0
		if k == Kind.NONE or EcoGrazerDust.lite or b.top.distance_to(ship) > EcoGrazerDust.NEAR:
			continue
		match k:
			Kind.ZAP:
				_burst(b, t, ZAP_N, ZAP_ALPHA * was)
			Kind.PING:
				_burst(b, t, PING_N, PING_ALPHA * was)
			_:
				_burst(b, t, NOISE_N, NOISE_ALPHA * was)


## Клуб у кончиков: count облачков вразнобой за BURST_SPAN с.
func _burst(b: EcoCoral.Bush, t: float, count: int, alpha: float) -> void:
	for c in count:
		_made += 1
		var key := _made
		var born := t + BURST_SPAN * c / float(maxi(1, count - 1)) * EcoVary.unit(key, SALT + 2)
		dust.add(tip_spot(b, key), born, alpha * EcoVary.spread(key, SALT + 3, 0.2), key, SCALE)
