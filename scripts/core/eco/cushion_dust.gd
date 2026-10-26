class_name EcoCushionDust
extends RefCounted
## Муть у дна от подушечника (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): подушка резко сжимается (EcoCushion.squeeze)
## и выдавливает воду из-под себя — вокруг основания кольцом встаёт клуб ила, под облаком чернил. Задел корабль
## (ближе EcoCushion.SHIP_R по горизонтали к основанию) — клуб густой из SHIP_N облачков (струя корпуса добавляет);
## нырнула напуганная стая — слабее, FISH_N облачков. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где
## подняты, растут, поднимаются, уплывают по течению, тают; светлее в луче прожектора) — свой пул на POOL мест, доля
## размера SCALE, цвет — розово-бурый ил у подушек. Мир и его случай не меняются: сжатие — по росту
## EcoCushion.Cushion.squeeze между шагами (спадает само на 0,15/с), разброс — хешем EcoVary; у гостя сети мир идёт сам,
## сжатие то же, поэтому и муть та же.
## Рисует CushionView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле (2 подушки × клуб 5, с запасом).
const POOL := 12
## Доля размера облачка скребуна (0,5 → 1,6 м): у подушки 0,4 → 1,28 м.
const SCALE := 0.8
## Сжатие началось: squeeze вырос между шагами больше чем на RISE_MIN (само оно только спадает).
const RISE_MIN := 0.05
## Задел корабль: облачков и непрозрачность; нырнула стая — меньше и слабее.
const SHIP_N := 5
const SHIP_ALPHA := 0.8
const FISH_N := 3
const FISH_ALPHA := 0.45
## Облачка встают вразнобой за BURST_SPAN с кольцом в RING м вокруг основания (край подушки — 1,1 м), с разбросом
## SCATTER.
const BURST_SPAN := 0.4
const RING := 1.5
const SCATTER := 0.25
## Над дном в начале (м).
const BASE_LIFT := 0.25
const SALT := 83
## Цвет: розово-бурый ил у подушки — бледная муть на светлом песке в луче не видна.
const COLOR := Color(0.25, 0.20, 0.22)
const LIT := Color(0.38, 0.31, 0.34)

var dust := EcoGrazerDust.new(POOL)
var _squeeze := PackedFloat32Array()
var _made := 0
var _last := -1e9


## Где встаёт облачко n (c-е из count в клубе) вокруг основания подушки cu: по кругу ровно, с разбросом угла.
static func burst_spot(cu: EcoCushion.Cushion, n: int, c: int = 0, count: int = 1) -> Vector3:
	var ang := float(cu.index) + (float(c) / maxi(1, count) + (EcoVary.unit(n, SALT) - 0.5) * 0.3) * TAU
	var r := RING + (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * SCATTER
	return cu.base + Vector3(cos(ang) * r, BASE_LIFT, sin(ang) * r)


## Задел ли подушку корабль в точке ship (как в EcoCushion.step — по горизонтали).
static func by_ship(cu: EcoCushion.Cushion, ship: Vector3) -> bool:
	return Vector2(ship.x - cu.base.x, ship.z - cu.base.z).length() < EcoCushion.SHIP_R


## Шаг мути в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoCushion, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var n := system.cushions.size()
	if t < _last or _last < -1e8 or _squeeze.size() != n:
		_squeeze.resize(n)
		for i in n:
			_squeeze[i] = system.cushions[i].squeeze
		_last = t
		return
	_last = t
	for i in n:
		var cu := system.cushions[i]
		var was := _squeeze[i]
		_squeeze[i] = cu.squeeze
		if cu.squeeze - was <= RISE_MIN:
			continue
		if EcoGrazerDust.lite or cu.base.distance_to(ship) > EcoGrazerDust.NEAR:
			continue
		if by_ship(cu, ship):
			_burst(cu, t, SHIP_N, SHIP_ALPHA)
		else:
			_burst(cu, t, FISH_N, FISH_ALPHA)


## Клуб вокруг основания: count облачков вразнобой за BURST_SPAN с.
func _burst(cu: EcoCushion.Cushion, t: float, count: int, alpha: float) -> void:
	for c in count:
		_made += 1
		var key := _made
		var born := t + BURST_SPAN * c / float(maxi(1, count - 1)) * EcoVary.unit(key, SALT + 2)
		dust.add(burst_spot(cu, key, c, count), born, alpha * EcoVary.spread(key, SALT + 3, 0.2), key, SCALE)
