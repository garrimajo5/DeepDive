class_name EcoLeech
extends EcoSystem
## Пиявник (leech в js/creatures.js: setLeech, predUpdate, stationsUpdate; бестиарий, ART-003): плоский червь 0,2 м
## на жабрах серпохвоста. В начале забега заражён первый хищник, остальные — через 90…160 с (не у станции чистки).
## Заражённый медленнее (×0,75), голодает быстрее (0,05 в секунду), нападает уже с голода 0,1 и видит свет и сонар
## корабля за 48 м вместо 32 — «злее» (наблюдение «angry», раз в 60 с, когда корабль дальше 32 м).
## Сытый заражённый (голод < 0,45) плывёт на ближайшую станцию чистки — вершину огнецвета (EcoCoral): ближе 4 м
## стоит, огнёвки работают 6 с — паразит снят (наблюдения огнёвки «clean» и пиявника «cleaned»), снова заразится
## через 150…260 с. Ждёт не дольше 60 с и бросает, если голод выше 0,9. У станции (ближе 14 м) хищник не охотится
## и не нападает на корабль. Логика хищника — в EcoPred (поле leeches); здесь станции, заражение при сбросе и цели
## сканера. Сами огнёвки, перемирие с сообщениями и укрытие корабля у станции — EcoOgnevka.

const ID := "leech"
## Первое заражение здоровых хищников — через 90…160 с; после чистки — через 150…260 с.
const FIRST_CD := Vector2(90, 160)
const NEXT_CD := Vector2(150, 260)
## Заражённый видит свет и сонар корабля не дальше (м; у здорового EcoPred.REACH = 32).
const REACH := 48.0
## Скорость заражённого (кроме чистки), прирост голода, с какого голода нападает на корабль.
const SLOW := 0.75
const HUNGER_RATE := 0.05
const ATTACK_HUNGER := 0.1
## Наблюдение «angry» — не чаще раза в 60 с у хищника.
const ANGRY_CD := 60.0
## На чистку плывёт сытым (голод ниже); ждёт до 60 с; бросает, если голод выше 0,9; на чистке голод растёт на 0,01/с.
const SEEK_HUNGER := 0.45
const CLEAN_TIME := 60.0
const GIVE_UP_HUNGER := 0.9
const CLEAN_HUNGER_RATE := 0.01
## Скорость к станции и у станции (ближе CLEAN_R), сколько секунд работают огнёвки.
const CLEAN_SPEED := 4.0
const CLEAN_SLOW := 0.6
const CLEAN_R := 4.0
const CLEAN_WORK := 6.0
## Хищник отплыл дальше BUSY_R от вершины — станция свободна; без хищника работа спадает на 0,5 в секунду.
const BUSY_R := 5.0
const WORK_DECAY := 0.5
## У станции (ближе ST_R к вершине) хищник не охотится, не нападает и не заражается.
const ST_R := 14.0
## Вершина станции — на 4,2 м над подножием куста (EcoCoral.TOP).
const TOP := EcoCoral.TOP
## Пиявник в осях тела серпохвоста (MOD-011: голова в −Z): у жаберной щели правого борта; размер цели сканера.
const ON_BODY := Vector3(0.40, -0.08, -0.80)
const SCAN_R := 0.7


## Станция чистки огнёвок на вершине огнецвета.
class Station:
	extends RefCounted
	var index := 0
	var top := Vector3.ZERO
	## Номер хищника на чистке (EcoPred.Pred.index), −1 — пусто. Номер, а не ссылка: хищник держит номер станции.
	var busy := -1
	## Сколько секунд огнёвки уже работают.
	var work := 0.0


var stations: Array[Station] = []
## Кусты огнецвета, на чьих вершинах станции (null — свои места из теста).
var coral: EcoCoral

## Хищники — слабой ссылкой: они держат этот модуль (EcoPred.leeches), сильная замкнула бы круг.
var _preds: WeakRef
var _tops: Array[Vector3]
var _rnd: EcoRandom


## preds — серпохвосты мира (им ставится preds.leeches = self); coral — огнецвет, на нём станции (подключён раньше);
## tops — свои вершины станций (для тестов), пусто — вершины кустов огнецвета.
func _init(preds: EcoPred, reef: EcoCoral = null, tops: Array[Vector3] = []) -> void:
	_preds = weakref(preds)
	preds.leeches = self
	coral = reef
	_tops = tops.duplicate()


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7411) & 0xFFFFFFFF


func preds() -> EcoPred:
	return _preds.get_ref() as EcoPred


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	stations.clear()
	var tops: Array[Vector3] = _tops
	if tops.is_empty() and coral:
		tops = []
		for b in coral.bushes:
			tops.append(b.base + Vector3(0, TOP, 0))
	for i in tops.size():
		var st := Station.new()
		st.index = i
		st.top = tops[i]
		stations.append(st)
	var ps := preds()
	if ps == null:
		return
	for pr in ps.all:  # setLeech(pr, i === 0); pr.leechCd = rr(90, 160)
		pr.leech = pr.index == 0
		pr.station = -1
		pr.angry_cd = 0.0
		pr.leech_cd = _rnd.range_f(FIRST_CD.x, FIRST_CD.y)


## Секунд до нового заражения после чистки.
func next_cd() -> float:
	return _rnd.range_f(NEXT_CD.x, NEXT_CD.y)


## Станция, у которой точка (ближе ST_R к вершине), или null.
func near_station(p: Vector3) -> Station:
	for st in stations:
		if p.distance_to(st.top) < ST_R:
			return st
	return null


## Ближайшая станция (null — станций нет).
func nearest_station(p: Vector3) -> Station:
	var best: Station = null
	var bd := INF
	for st in stations:
		var d := st.top.distance_to(p)
		if d < bd:
			bd = d
			best = st
	return best


## Станции освобождаются, когда хищник ушёл с чистки; без хищника работа огнёвок спадает (stationsUpdate).
func step(_world: EcoWorld, dt: float) -> void:
	var ps := preds()
	for st in stations:
		if st.busy >= 0:
			var pr: EcoPred.Pred = ps.all[st.busy] if ps and st.busy < ps.all.size() else null
			if pr == null or pr.mode != EcoPred.Mode.CLEAN or pr.agent.distance_to(st.top) > BUSY_R:
				st.busy = -1
		if st.busy < 0:
			st.work = maxf(0.0, st.work - dt * WORK_DECAY)


## Где пиявник на хищнике (у жабр, в мире).
static func position_on(pr: EcoPred.Pred) -> Vector3:
	return pr.agent.p + EcoPredLook.basis(pr) * ON_BODY


## Пиявник заметен сканеру на заражённых хищниках; сонару — нет (20 см, сонар видит самого хищника).
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	var ps := preds()
	if ps == null:
		return
	for pr in ps.all:
		if pr.leech and pr.agent.alive:
			out.append(EcoWorld.target(ID, position_on(pr), SCAN_R, false))


## Сколько хищников заражено.
func infected() -> int:
	var n := 0
	var ps := preds()
	if ps:
		for pr in ps.all:
			if pr.leech:
				n += 1
	return n
