class_name EcoVeilDust
extends RefCounted
## Выдох фонарной вуали (docs/grafika-plan-eco.md, Б3 «Мелочь жизни», «облачка и пузырьки от существ»): купол
## пульсирует (EcoVeil.pulse — 1 ± 0,07, 1,3 рад/с, период ≈ 4,8 с) и на каждом сокращении (купол шире всего и
## начинает сжиматься) выталкивает из-под кромки воду с отработанной слизью (крупные: купол 6 м) — EXHALE_N облачков у кромки, чуть ниже
## неё, в своих местах по кругу. Ужалила светляка (EcoVeil.Veil.stings вырос) — у ужаленной рыбки клуб из STING_N
## облачков стрекательной слизи. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где выдохнуты, растут,
## поднимаются, уплывают по течению, тают; светлее в луче прожектора) — свой пул на POOL мест, цвет — бледная
## голубовато-сиреневая слизь в тон купола. Мир и его случай не меняются: такт — по времени мира и фазе вуали,
## место у кромки и разброс — хешем EcoVary от номера вуали и такта; у гостя сети время мира то же
## (EcoLink.synced_time), вуали дрейфуют по нему — выдохи те же; ужаливания у гостя идут в его мире — облачка те же
## по виду. Рисует VeilView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки,
## шейдеров не прибавилось. «Экономно» — общий выключатель мелочи жизни EcoGrazerDust.lite.

## Мест в пуле: 2 вуали × (выдох 2 облачка за такт 4,8 с при жизни 3,6 с + клуб ужаливания 3) — с запасом.
const POOL := 12
## Выдох на сокращении купола: облачков, непрозрачность, доля размера (у скребуна 0,5 → 1,6 м).
const EXHALE_N := 2
const EXHALE_ALPHA := 0.5
const EXHALE_SCALE := 1.4
## Под кромкой (м), наружу от кромки (доля радиуса) и разброс места (м).
const BELOW := 0.7
const OUT := 0.05
const SCATTER := 0.3
## Ужалила светляка — клуб стрекательной слизи у рыбки.
const STING_N := 3
const STING_ALPHA := 0.6
const STING_SCALE := 0.5
const STING_SCATTER := 0.25
const SALT := 401
## Цвет: бледная голубовато-сиреневая слизь (в тон купола #7ff5ff и ядра #ff8ae0) — светлее донного ила: её
## подсвечивают огни кромки; в луче — светлая.
const COLOR := Color(0.36, 0.42, 0.52)
const LIT := Color(0.74, 0.80, 0.90)

var dust := EcoGrazerDust.new(POOL)
## У каждой вуали: такт, до которого уже выдохнула, и сколько ужаливаний видели.
var _cycle := PackedInt64Array()
var _stings := PackedInt32Array()
var _made := 0
var _last := -1e9
## Начало ближайшего нового такта: до него выдохов нет.
var _due := -1e9


## Такт вуали vl в момент t: растёт на 1, когда купол шире всего (sin(W t + ph) = 1) и начинает сжиматься.
static func cycle(vl: EcoVeil.Veil, t: float) -> int:
	return int(floor((t * EcoVeil.PULSE_W + vl.ph - PI * 0.5) / TAU))


## Когда начался такт c вуали vl (время мира).
static func cycle_start(vl: EcoVeil.Veil, c: int) -> float:
	return (float(c) * TAU + PI * 0.5 - vl.ph) / EcoVeil.PULSE_W


## Где встаёт k-е облачко выдоха такта c у вуали vl: у кромки купола (радиус R × пульс в начале сжатия), под ней.
static func spot(vl: EcoVeil.Veil, c: int, k: int) -> Vector3:
	var key := key_of(vl, c, k)
	var a := EcoVary.unit(key, SALT) * TAU
	var r := EcoVeil.R * (1.0 + EcoVeil.PULSE) * (1.0 + OUT)
	var off := Vector3(EcoVary.unit(key, SALT + 1) - 0.5, EcoVary.unit(key, SALT + 2) - 0.5,
			EcoVary.unit(key, SALT + 3) - 0.5) * (2.0 * SCATTER)
	return vl.p + Vector3(cos(a) * r, -BELOW, sin(a) * r) + off


## Ключ разброса облачка k такта c вуали vl.
static func key_of(vl: EcoVeil.Veil, c: int, k: int) -> int:
	return (c * 8 + vl.index) * 4 + k


## Шаг в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoVeil, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var n := system.veils.size()
	if t < _last or _last < -1e8 or _cycle.size() != n:   # первый шаг или время пошло назад — запомнить, без облачков
		_cycle.resize(n)
		_stings.resize(n)
		for vl in system.veils:
			_cycle[vl.index] = cycle(vl, t)
			_stings[vl.index] = vl.stings
		_last = t
		_due = _next_due(system)
		return
	_last = t
	for vl in system.veils:
		var i := vl.index
		var quiet := EcoGrazerDust.lite or vl.p.distance_to(ship) > EcoGrazerDust.NEAR
		if vl.stings != _stings[i]:
			_stings[i] = vl.stings
			if not quiet:
				for k in STING_N:
					_made += 1
					var key := _made * 8 + i
					var off := Vector3(EcoVary.unit(key, SALT + 5) - 0.5, EcoVary.unit(key, SALT + 6) - 0.5,
							EcoVary.unit(key, SALT + 7) - 0.5) * (2.0 * STING_SCATTER)
					dust.add(vl.sting_at + off, t, STING_ALPHA * EcoVary.spread(key, SALT + 8, 0.2), key,
							STING_SCALE * EcoVary.spread(key, SALT + 9, 0.15))
	if t < _due:
		return
	for vl in system.veils:
		var i := vl.index
		var c := cycle(vl, t)
		if c <= _cycle[i]:
			continue
		_cycle[i] = c   # долгий кадр — только последний такт: прошлые облачка уже растаяли бы
		if EcoGrazerDust.lite or vl.p.distance_to(ship) > EcoGrazerDust.NEAR:
			continue
		var born := cycle_start(vl, c)
		for k in EXHALE_N:
			_made += 1
			var key := key_of(vl, c, k)
			dust.add(spot(vl, c, k), born, EXHALE_ALPHA * EcoVary.spread(key, SALT + 4, 0.2), key,
					EXHALE_SCALE * EcoVary.spread(key, SALT + 10, 0.15))
	_due = _next_due(system)


## Начало ближайшего следующего такта среди вуалей.
func _next_due(system: EcoVeil) -> float:
	var d := INF
	for vl in system.veils:
		d = minf(d, cycle_start(vl, int(_cycle[vl.index]) + 1))
	return d
