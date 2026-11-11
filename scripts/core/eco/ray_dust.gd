class_name EcoRayDust
extends RefCounted
## Вихри с кончиков крыльев ледокрыла (docs/grafika-plan-eco.md, Б3 «Мелочь жизни», «облачка и пузырьки от
## существ»): корабль на пути — скат взмывает над корпусом (EcoRay.Ray.over стал true), сильный взмах срывает
## с каждого кончика крыла клуб из RISE_N облачков подлёдной взвеси; пока идёт над кораблём — раз в WAKE_EVERY с
## (× 1 ± 0,25) слабое облачко с кончика, по очереди с левого и правого; прошёл и опускается (over стал false) —
## SETTLE_N облачков с каждого кончика, слабее. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где сорваны,
## растут, поднимаются, уплывают по течению, тают; светлее в луче прожектора) — свой пул на POOL мест, крупнее
## (скат огромный), цвет — бледная голубовато-серая взвесь подо льдом. Мир и его случай не меняются: что делает скат —
## по over между шагами, разброс — хешем EcoVary; у гостя сети скаты идут в его мире — облачка те же по виду.
## Рисует RayView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки,
## шейдеров не прибавилось. «Экономно» — общий выключатель мелочи жизни EcoGrazerDust.lite.

## Мест в пуле: 2 ската × (взлёт 2 × 3 + след над кораблём ~5 + посадка 2 × 2) — хватает с запасом на одного,
## второй над кораблём бывает редко.
const POOL := 16
## Кончик крыла в осях ската (+Z — по курсу, как EcoRay.xform): полуразмах RayView.SPAN / 2, отогнут назад
## на RayView.SWEEP от самого широкого места тела (z = −0,6).
const TIP := Vector3(7.0, 0.0, -2.8)
## Разброс места облачка у кончика (м).
const SCATTER := 0.6
## Взмыл над кораблём — клуб с каждого кончика.
const RISE_N := 3
const RISE_ALPHA := 0.4
const RISE_SCALE := 1.2
## Идёт над кораблём — слабое облачко раз в WAKE_EVERY с (× 1 ± WAKE_SPREAD), кончики по очереди.
const WAKE_EVERY := 0.7
const WAKE_SPREAD := 0.25
const WAKE_ALPHA := 0.25
const WAKE_SCALE := 0.9
## Прошёл и опускается — слабее взлёта.
const SETTLE_N := 2
const SETTLE_ALPHA := 0.3
const SETTLE_SCALE := 1.0
const SALT := 331
## Цвет: бледная голубовато-серая взвесь подо льдом (на светлом теле #a8cfe0 и тёмной воде видна); в луче — светлая.
const COLOR := Color(0.24, 0.30, 0.34)
const LIT := Color(0.66, 0.76, 0.82)

enum Kind { NONE, WAKE, RISE, SETTLE }

var dust := EcoGrazerDust.new(POOL)
## У каждого ската: время следующего облачка следа и был ли над кораблём прошлым шагом.
var _next := PackedFloat32Array()
var _over := PackedByteArray()
var _made := 0
var _last := -1e9


## Что сделал скат: был над кораблём was, сейчас now.
static func kind(was: bool, now: bool) -> Kind:
	if now and not was:
		return Kind.RISE
	if was and not now:
		return Kind.SETTLE
	return Kind.WAKE if now else Kind.NONE


## Кончик крыла ската ry в мире: side = 1 — правое крыло (+X меша), −1 — левое.
static func tip(ry: EcoRay.Ray, side: float) -> Vector3:
	return EcoRay.xform(ry) * Vector3(TIP.x * side, TIP.y, TIP.z)


## Шаг в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoRay, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var n := system.rays.size()
	if _next.size() != n or t < _last:   # первый шаг или время мира пошло назад — запомнить, без облачков
		_next.resize(n)
		_over.resize(n)
		for ry in system.rays:
			_next[ry.index] = t
			_over[ry.index] = 1 if ry.over else 0
		_last = t
		return
	_last = t
	for ry in system.rays:
		var i := ry.index
		var k := kind(_over[i] != 0, ry.over)
		_over[i] = 1 if ry.over else 0
		if k == Kind.NONE:
			continue
		var quiet := EcoGrazerDust.lite or ry.p.distance_to(ship) > EcoGrazerDust.NEAR
		match k:
			Kind.RISE:
				if not quiet:
					for c in RISE_N:
						_puff(ry, 1.0, t, RISE_ALPHA, RISE_SCALE)
						_puff(ry, -1.0, t, RISE_ALPHA, RISE_SCALE)
				_next[i] = t + WAKE_EVERY
				continue
			Kind.SETTLE:
				if not quiet:
					for c in SETTLE_N:
						_puff(ry, 1.0, t, SETTLE_ALPHA, SETTLE_SCALE)
						_puff(ry, -1.0, t, SETTLE_ALPHA, SETTLE_SCALE)
				continue
		if t < _next[i]:
			continue
		var key := (_made + 1) * 2 + i
		_next[i] = t + WAKE_EVERY * EcoVary.spread(key, SALT + 2, WAKE_SPREAD)
		if not quiet:
			_puff(ry, 1.0 if _made % 2 == 0 else -1.0, t, WAKE_ALPHA, WAKE_SCALE)


func _puff(ry: EcoRay.Ray, side: float, t: float, alpha: float, scale: float) -> void:
	_made += 1
	var key := _made * 2 + ry.index
	var off := Vector3(EcoVary.unit(key, SALT) - 0.5, EcoVary.unit(key, SALT + 5) - 0.5,
			EcoVary.unit(key, SALT + 6) - 0.5) * (2.0 * SCATTER)
	dust.add(tip(ry, side) + off, t, alpha * EcoVary.spread(key, SALT + 3, 0.2), key,
			scale * EcoVary.spread(key, SALT + 4, 0.15))
