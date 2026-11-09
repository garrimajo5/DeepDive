class_name EcoHvatenDust
extends RefCounted
## Муть у дна от хватня (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): анемон рывком прячет раскрытые щупальца —
## их взмах сдувает ил с дна кольцом вокруг основания. Луч прожектора застал хватня раскрытым больше чем на
## SNAP_OPEN — густой клуб из SNAP_N облачков; сжимается, схватив светляка (без луча: с 1 до половины), — слабее,
## CATCH_N облачков. Медленное раскрытие в темноте ила не поднимает. Облачка те же, что у скребунов
## (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают по течению, тают; светлее в луче прожектора) —
## свой пул на POOL мест, доля размера SCALE, цвет — бурый ил рифа. Мир и его случай не меняются: что делает хватень —
## по его раскрытию между шагами (быстрее SNAP_RATE в секунду — сжимается рывком) и полю lit, разброс — хешем
## EcoVary; у гостя сети мир идёт сам, раскрытие то же, поэтому и муть та же.
## Рисует HvatenView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле (4 хватня × клуб 4).
const POOL := 16
## Доля размера облачка скребуна (0,5 → 1,6 м): у хватня 0,35 → 1,12 м.
const SCALE := 0.7
## Сжимается рывком: раскрытие падает быстрее SNAP_RATE в секунду (прячет — 2,5/с, раскрывается — 0,35/с вверх).
const SNAP_RATE := 1.0
## Клуб — если рывок начался с раскрытия больше SNAP_OPEN (приоткрытый ила не сдувает).
const SNAP_OPEN := 0.5
## В луче: облачков и непрозрачность (× раскрытие в начале рывка); схватил добычу в темноте — меньше и слабее.
const SNAP_N := 4
const SNAP_ALPHA := 0.9
const CATCH_N := 2
const CATCH_ALPHA := 0.35
## Облачка встают вразнобой за BURST_SPAN с кольцом в RING м вокруг основания (под кончиками щупалец), с разбросом
## SCATTER.
const BURST_SPAN := 0.3
const RING := 0.8
const SCATTER := 0.2
## Над дном в начале (м).
const BASE_LIFT := 0.2
const SALT := 71
## Цвет: бурый ил рифа (как у кольчужника, чуть розовее под тело хватня) — бледная муть на светлом песке в луче не
## видна.
const COLOR := Color(0.23, 0.20, 0.19)
const LIT := Color(0.34, 0.29, 0.28)

var dust := EcoGrazerDust.new(POOL)
var _open := PackedFloat32Array()
var _snap := PackedByteArray()
var _made := 0
var _last := -1e9


## Где встаёт облачко n (c-е из count в клубе) вокруг основания хватня hv: по кругу ровно, с разбросом угла.
static func burst_spot(hv: EcoHvaten.Anemone, n: int, c: int = 0, count: int = 1) -> Vector3:
	var ang := hv.yaw + (float(c) / maxi(1, count) + (EcoVary.unit(n, SALT) - 0.5) * 0.3) * TAU
	var r := RING + (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * SCATTER
	return hv.base + Vector3(cos(ang) * r, BASE_LIFT, sin(ang) * r)


## Шаг мути в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoHvaten, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var n := system.anemones.size()
	if t < _last or _last < -1e8 or _open.size() != n:
		_open.resize(n)
		_snap.resize(n)
		for i in n:
			_open[i] = system.anemones[i].open
			_snap[i] = 0
		_last = t
		return
	var dt := t - _last
	_last = t
	if dt <= 1e-6:
		return
	for i in n:
		var hv := system.anemones[i]
		var was := _open[i]
		_open[i] = hv.open
		var snapping := (was - hv.open) / dt > SNAP_RATE
		var start := snapping and _snap[i] == 0
		_snap[i] = 1 if snapping else 0
		if not start or was <= SNAP_OPEN:
			continue
		if EcoGrazerDust.lite or hv.base.distance_to(ship) > EcoGrazerDust.NEAR:
			continue
		if hv.lit:
			_burst(hv, t, SNAP_N, SNAP_ALPHA * was)
		else:
			_burst(hv, t, CATCH_N, CATCH_ALPHA)


## Клуб вокруг основания: count облачков вразнобой за BURST_SPAN с.
func _burst(hv: EcoHvaten.Anemone, t: float, count: int, alpha: float) -> void:
	for c in count:
		_made += 1
		var key := _made
		var born := t + BURST_SPAN * c / float(maxi(1, count - 1)) * EcoVary.unit(key, SALT + 2)
		dust.add(burst_spot(hv, key, c, count), born, alpha * EcoVary.spread(key, SALT + 3, 0.2), key, SCALE)
