class_name EcoOgnevka
extends EcoSystem
## Огнёвки — рачки-чистильщики на станциях чистки (initStations/stationsUpdate в js/creatures.js; бестиарий):
## по 10 светящихся креветок 8 см на вершине каждого огнецвета (станции — EcoLeech.stations). Пока серпохвост на
## чистке, огнёвки облепляют его; на пустой станции половина кормится на соседнем веернике (EcoFan), остальные
## кружат над вершиной. Корабль ближе 18 м к вершине — «в укрытии» (E.shipSheltered): хищник не нападает и
## отворачивает (наблюдение «shelter»); у станции (ближе 14 м) хищник бросает охоту (наблюдение «truce») — сама
## логика хищника в EcoPred (поле ognevka). Пустая станция у корабля (веерник ближе 30 м) — наблюдение веерника
## «ognevka», не чаще раза в 120 с. Станция — цель сканера (r 1,6), сонару огнёвки не видны.

const ID := "ognevka"
## Огнёвок на станции; корабль в укрытии ближе SHELTER_R к вершине.
const PER_STATION := 10
const SHELTER_R := 18.0
## Пауза сообщений «truce»/«shelter» у хищника (truceCd) и сколько он не нападает, увидев корабль в укрытии.
const TRUCE_CD := 40.0
const SHELTER_PAUSE := 8.0
## Хищник, отвернувший в броске: уходит 8 с и 15 с не нападает.
const TURN_AWAY_TIME := 8.0
const TURN_AWAY_PAUSE := 15.0
## Наблюдение веерника «ognevka»: веерник станции ближе 30 м к кораблю, раз в 120 с; веерник станции — ближе 10 м.
const FAN_R := 30.0
const FAN_CD := 120.0
const FAN_OF := 10.0
## Цель сканера на вершине станции.
const SCAN_R := 1.6
## Огнёвки догоняют своё место с долей dt·3 (lerp), кружат с частотой 0,8 рад/с.
const FOLLOW := 3.0
const SPIN := 0.8
## Быстрее этого (м/с) рачок не плывёт: хищник встал на чистку в 8 м — доля lerp дала бы рывок 26 м/с за шаг
## (Б3, `test_eco_reset_jumps`); теперь стая перебирается к нему и обратно к вершине за пару секунд.
const DART := 4.0
## Нос рачка `Shrimp.dir` догоняет ход долей угла LOOK_K в секунду, не быстрее LOOK_MAX рад/с (`turn`, Б3):
## смена цели (станция → хищник на чистке → веерник) разворачивает рачка за ~0,4 с, а не за шаг; почти стоит —
## держит курс (раньше нос щёлкал на касательную круга).
const LOOK_K := 10.0
const LOOK_MAX := 8.0


## Одна огнёвка: станция, фаза, радиус круга и высота над вершиной.
class Shrimp:
	extends RefCounted
	var station := 0
	var phase := 0.0
	var r := 1.0
	var h := 0.0
	var p := Vector3.ZERO
	## Куда смотрит (по движению).
	var dir := Vector3(1, 0, 0)


var shrimp: Array[Shrimp] = []
var leeches: EcoLeech
## Веерники (null — нет): половина огнёвок пустой станции кормится на ближайшем.
var fans: EcoFan
var fan_cd := 0.0

var _rnd: EcoRandom
## Веерник каждой станции (null — нет), находится при сбросе; чётность шага — рачки шагают через раз, половинами.
var _fan_of: Array[EcoFan.Fan] = []
var _half := 0


## leeches — станции чистки (EcoLeech, подключён раньше); ставит preds.ognevka = self у его хищников.
func _init(stations: EcoLeech, fan: EcoFan = null) -> void:
	leeches = stations
	fans = fan
	var ps := stations.preds()
	if ps:
		ps.ognevka = self


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7522) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	shrimp.clear()
	fan_cd = 0.0
	_half = 0
	_fan_of.clear()
	for st in leeches.stations:
		_fan_of.append(_find_fan(st))
	for st in leeches.stations:
		for k in PER_STATION:
			var s := Shrimp.new()
			s.station = st.index
			s.phase = _rnd.range_f(0, TAU)
			s.r = _rnd.range_f(0.6, 1.6)
			s.h = _rnd.range_f(-0.6, 0.8)
			shrimp.append(s)
			# с начала — там, куда его ведёт шаг (круг над вершиной или веерник); раньше все стояли в вершине и на
			# первом шаге прыгали к веернику до 1,5 м за кадр (44 м/с)
			s.p = goal_of(s, shrimp.size() - 1, world.time, null)
			s.dir = _tangent(s.phase)


## Чётность рачков, шагнувших в последнем шаге (для вида: переписать только их).
func moved_half() -> int:
	return _half


## Станция, у которой корабль в укрытии (ближе 18 м к вершине), или null.
func shelter(pos: Vector3) -> EcoLeech.Station:
	for st in leeches.stations:
		if pos.distance_to(st.top) < SHELTER_R:
			return st
	return null


## Веерник станции (ближе 10 м к подножию огнецвета) или null.
func fan_at(st: EcoLeech.Station) -> EcoFan.Fan:
	return _fan_of[st.index] if st.index < _fan_of.size() else null


func _find_fan(st: EcoLeech.Station) -> EcoFan.Fan:
	if fans == null:
		return null
	var base := st.top - Vector3(0, EcoLeech.TOP, 0)
	for f in fans.fans:
		if Vector2(f.pos.x - base.x, f.pos.z - base.z).length() < FAN_OF:
			return f
	return null


func step(world: EcoWorld, dt: float) -> void:
	var t := world.time
	var ps := leeches.preds()
	_half ^= 1
	var sdt := dt * 2.0  # каждый рачок шагает через шаг мира: половина за шаг (бюджет кадра, issue #77)
	for k in range(_half, shrimp.size(), 2):
		var s := shrimp[k]
		var st := leeches.stations[s.station]
		var pr: EcoPred.Pred = ps.all[st.busy] if ps and st.busy >= 0 and st.busy < ps.all.size() else null
		var goal := goal_of(s, k, t, pr)
		var was := s.p
		s.p = follow(s.p, goal, sdt)
		s.dir = turn(s.dir, s.p - was, sdt)
	fan_cd -= dt
	if fans and fan_cd <= 0.0:
		for st in leeches.stations:
			var f := fan_at(st)
			if st.busy < 0 and f and f.pos.distance_to(world.ship.pos) < FAN_R:
				fan_cd = FAN_CD
				world.emit(EcoFan.ID, "ognevka", f.top, _fan_text(world))
				break


## Куда тянется рачок k в момент t: облепил хищника pr на чистке, кормится на веернике (нечётные у пустой станции
## с веерником) или кружит над вершиной. Общее для сброса и шага.
func goal_of(s: Shrimp, k: int, t: float, pr: EcoPred.Pred) -> Vector3:
	var st := leeches.stations[s.station]
	var a := t * SPIN + s.phase
	var fan := fan_at(st) if k % 2 == 1 else null
	if pr:  # облепили хищника на чистке
		return pr.agent.p + Vector3(cos(a * 2) * s.r * 0.5, 0.4 + s.h * 0.4, sin(a * 2) * s.r * 0.5)
	if fan:  # половина кормится на веернике
		return fan.top + Vector3(cos(a) * s.r * 0.8, s.h + sin(t * 3 + s.phase) * 0.3, sin(a) * s.r * 0.3)
	return st.top + Vector3(cos(a) * s.r, s.h + sin(t * 3 + s.phase) * 0.15, sin(a) * s.r)


## Шаг к цели на dt с: доля FOLLOW·dt пути, не дальше DART·dt.
static func follow(from: Vector3, goal: Vector3, dt: float) -> Vector3:
	var step := (goal - from) * minf(1.0, dt * FOLLOW)
	return from + step.limit_length(DART * dt)


## Нос from → по ходу move: доля угла LOOK_K·dt, не больше LOOK_MAX·dt; хода нет — держит курс.
static func turn(from: Vector3, move: Vector3, dt: float) -> Vector3:
	if move.length_squared() < 1e-10:
		return from
	var want := move.normalized()
	if from.length_squared() < 1e-8:
		return want
	var ang := from.angle_to(want)
	if ang < 1e-4:
		return want
	var axis := from.cross(want)
	if axis.length_squared() < 1e-10:
		axis = Vector3.UP if absf(from.y) < 0.9 else Vector3.RIGHT
	return from.rotated(axis.normalized(), minf(ang * minf(1.0, LOOK_K * dt), LOOK_MAX * dt)).normalized()


## Касательная круга над вершиной при фазе a (первый курс рачка).
static func _tangent(a: float) -> Vector3:
	return Vector3(cos(a + PI / 2), 0, sin(a + PI / 2))


## Станции видны сканеру (огнёвки 8 см — сонару нет).
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for st in leeches.stations:
		out.append(EcoWorld.target(ID, st.top, SCAN_R, false))


## Хищник бросил охоту у станции (наблюдение «truce»).
func truce(world: EcoWorld, at: Vector3) -> void:
	world.emit(ID, "truce", at, EcoPred._text(world, "%s бросил охоту у станции чистки", Species.Case.NOM))


## Хищник не трогает корабль в укрытии (turned — отвернул в броске).
func sheltered(world: EcoWorld, at: Vector3, turned: bool) -> void:
	var fmt := "%s отвернул: корабль у станции чистки" if turned else "%s не трогает корабль у станции чистки"
	world.emit(ID, "shelter", at, EcoPred._text(world, fmt, Species.Case.NOM))


## «Огнёвки кормятся на веернике, пока станция пустует» — оба названия в момент показа.
static func _fan_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var known := func(id: String) -> bool: return w != null and w.scanned.is_valid() and bool(w.scanned.call(id))
		var who := "Огнёвки" if known.call(ID) else "Рачки-чистильщики"
		var where := "веернике" if known.call(EcoFan.ID) else "кружевном веере"
		return "%s кормятся на %s, пока станция пустует" % [who, where]
