class_name EcoLeechDust
extends RefCounted
## Облачка на станции чистки (docs/grafika-plan-eco.md, Б3 «Мелочь жизни», «облачка и пузырьки от существ»):
## серпохвост с пиявником стоит у вершины огнецвета (EcoPred.Mode.CLEAN ближе EcoLeech.CLEAN_R), огнёвки обирают
## жабры — у жаберной щели (EcoLeech.position_on) раз в WORK_EVERY с встаёт маленькое облачко слизи; паразит снят
## (у хищника leech было — стало нет) — у жабр разом клуб из BURST облачков: сорванная лента и слизь. Облачка те же,
## что у скребунов (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают по течению, тают; светлее в
## луче прожектора) — свой пул на POOL мест, цвет — бурая слизь в тон пиявника (LeechView.COLOR). Мир и его случай
## не меняются: что делает хищник — по его режиму и пиявнику между шагами, разброс — хешем EcoVary; у гостя сети
## хищники идут в его мире, облачка те же по виду.
## Рисует LeechView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки, шейдеров
## не прибавилось. «Экономно» — общий выключатель мелочи жизни EcoGrazerDust.lite.

## Мест в пуле: чистка 6 с — до 7 облачков на хищника, клуб — ещё 3; станций две, на чистке редко больше одного.
const POOL := 12
## Пауза между облачками чистки (с), у каждого облачка ×(1 ± 0,25).
const WORK_EVERY := 0.9
## Непрозрачность и доля размера (размер скребуна 0,5 → 1,6 м): чистка — слабое и мелкое, снят — гуще и крупнее.
const WORK_ALPHA := 0.35
const WORK_SCALE := 0.35
const BURST := 3
const BURST_ALPHA := 0.7
const BURST_SCALE := 0.55
## Разброс места у жабр (м).
const SCATTER := 0.25
const SALT := 211
## Цвет: бурая слизь в тон пиявника (#7a4636); в луче — светлая.
const COLOR := Color(0.24, 0.16, 0.13)
const LIT := Color(0.74, 0.56, 0.47)

var dust := EcoGrazerDust.new(POOL)
## Время следующего облачка чистки у каждого хищника и был ли на нём пиявник прошлым шагом (по номеру).
var _next := PackedFloat32Array()
var _had := PackedByteArray()
var _made := 0
var _last := -1e9


## Хищник pr сейчас на чистке у станции (огнёвки работают): режим чистки, пиявник на нём, ближе CLEAN_R к вершине.
static func cleaning(system: EcoLeech, pr: EcoPred.Pred) -> bool:
	if pr == null or not pr.agent.alive or not pr.leech or pr.mode != EcoPred.Mode.CLEAN:
		return false
	if pr.station < 0 or pr.station >= system.stations.size():
		return false
	return pr.agent.distance_to(system.stations[pr.station].top) < EcoLeech.CLEAN_R


## Где поднять облачко с ключом key у жабр хищника pr: у жаберной щели с разбросом.
static func spot(pr: EcoPred.Pred, key: int) -> Vector3:
	var s := Vector3(EcoVary.unit(key, SALT) * 2.0 - 1.0, EcoVary.unit(key, SALT + 1) * 2.0 - 1.0,
			EcoVary.unit(key, SALT + 2) * 2.0 - 1.0) * SCATTER
	return EcoLeech.position_on(pr) + s


## Шаг в момент t (время мира): хищники на чистке пускают облачка, снятый паразит — клуб. ship — корабль: дальше
## EcoGrazerDust.NEAR — нет.
func update(system: EcoLeech, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var ps := system.preds()
	if ps == null:
		return
	var n := ps.all.size()
	if _next.size() != n or t < _last:   # первый шаг или время мира пошло назад — запомнить, без облачков
		_next.resize(n)
		_next.fill(t)
		_had.resize(n)
		for pr in ps.all:
			_had[pr.index] = 1 if pr.leech else 0
		_last = t
		return
	_last = t
	for pr in ps.all:
		var i := pr.index
		var had := _had[i] != 0
		_had[i] = 1 if pr.leech else 0
		var quiet := EcoGrazerDust.lite or pr.agent.p.distance_to(ship) > EcoGrazerDust.NEAR
		if had and not pr.leech:   # паразит снят — клуб слизи у жабр
			if not quiet:
				for b in BURST:
					_puff(pr, t, BURST_ALPHA, BURST_SCALE)
			_next[i] = t
			continue
		if not cleaning(system, pr):
			_next[i] = maxf(_next[i], t)
			continue
		if t < _next[i]:
			continue
		var key := (_made + 1) * 4 + i
		_next[i] = t + WORK_EVERY * EcoVary.spread(key, SALT + 3, 0.25)
		if not quiet:
			_puff(pr, t, WORK_ALPHA, WORK_SCALE)


func _puff(pr: EcoPred.Pred, t: float, alpha: float, scale: float) -> void:
	_made += 1
	var key := _made * 4 + pr.index
	dust.add(spot(pr, key), t, alpha * EcoVary.spread(key, SALT + 4, 0.2), key, scale * EcoVary.spread(key, SALT + 5, 0.15))
