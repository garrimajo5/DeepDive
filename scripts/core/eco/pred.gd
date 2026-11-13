class_name EcoPred
extends EcoSystem
## Серпохвосты — крупные хищники рифа (initPreds/predUpdate в js/creatures.js, Unity `Core/EcoPred.cs`). Три хищника
## на местах из браузера патрулируют отмель, чаще у стай светляков. Голод растёт на 0,03 в секунду; голоднее 0,45 —
## охота на ближайшего светляка не дальше 50 м (7,6 м/с, 12 с), поймал ближе 1,6 м — рыбка съедена (EcoFish.kill),
## событие «catch», 5 с ест.
## Корабль манит: прожектор или сонар (последние 12 с) ближе 32 м, шум двигателей быстрее 3 м/с ближе 24 м. Голоднее 0,2
## и без паузы — бросок на корабль (9,5 м/с, до 10 с) с событием «ship», «ping» или «hear». Ближе 8,5 м к кораблю или 1,2 м к корпусу (EcoHull) — укус:
## EcoLink.HIT с уроном 0,12 (что он делает с кораблём — решает корабль), хищник уходит на 60 м и 25 с не нападает.
## Сонар (ShipState.sonar_ping → on_ping) зовёт хищников ближе 150 м проверить звук, разряд (ShipState.zap → on_zap)
## отпугивает тех, кто ближе радиуса разряда. В гуле трубного органа (EcoOrgan) двигатели не слышно; в чернилах
## подушечника (EcoCushion) хищник теряет светляка и корабль. Пиявник (EcoLeech, поле leeches) делает хищника
## медленнее и злее и гонит на станцию чистки (режим CLEAN). Вспышка радужников (EcoRaduzh, поле raduzh) зовёт
## хищника издалека. У станции чистки (EcoOgnevka, поле ognevka) хищник бросает охоту, корабль там в укрытии.
## В густом ленточнике (EcoKelp, поле kelp) хищник теряет напуганную стаю.
## Фонарные вуали (EcoVeil, поле veils) обходит стороной, корабль под куполом вуали теряет.
## Напуганную стаю в рифе на спине гротовика (EcoGrot, поле grot) теряет.
## Сквозь корпус не проходят (EcoWorld.push_out).
## Риф у Каменного цветка 01 (#834, «читаемая встреча»): хищник патрулирует снаружи кольца REEF_KEEP и в него не
## заходит; импульс сонара у цветка зовёт его к внешнему краю рифа со своей стороны (REEF_EDGE), а не к кораблю;
## корабль в рифе он не атакует — туда можно отступить. Стаи у кроны прячутся раньше (EcoFish.CROWN_ALARM).

const ID := "pred"

## Места появления (x, z) — как в браузере (js: [[-60, 20], [70, -20], [10, -110]]).
const STARTS: Array[Vector2] = [Vector2(-60, 20), Vector2(70, -20), Vector2(10, -110)]

## Скорости по режимам (м/с).
const PATROL_SPEED := 3.0
const HUNT_SPEED := 7.6
const INVESTIGATE_SPEED := 5.5
const CHARGE_SPEED := 9.5
const RETREAT_SPEED := 6.0
const FLEE_SPEED := 9.0
const EAT_SPEED := 1.0
## Голод: прирост в секунду, с какого охотится, с какого нападает на корабль, с какого бросает охоту ради корабля.
const HUNGER_RATE := 0.03
const HUNT_HUNGER := 0.45
const ATTACK_HUNGER := 0.2
const HUNT_TO_SHIP_HUNGER := 0.6
## Видит светляка не дальше (м), хватает ближе (м).
const HUNT_RADIUS := 50.0
const CATCH_DIST := 1.6


## Достаёт ли хищник a добычу b: ближе CATCH_DIST, а у дна по высоте — с броском вниз на то, на что сам не
## опускается (свой clearance + LOOK_GAP над дном против clearance светляка): светляк, прижатый к дну, ловится сверху,
## а не только когда подскочит (план Б3: светляки больше не прыгают на зажиме).
static func can_catch(a: EcoAgent, b: EcoAgent) -> bool:
	var d := a.p - b.p
	var reach := maxf(a.clearance + EcoAgent.LOOK_GAP - b.clearance, 0.0)
	if d.y > 0.0:
		d.y = maxf(d.y - reach, 0.0)
	return d.length_squared() < CATCH_DIST * CATCH_DIST
## Видит свет прожектора и слышит сонар корабля не дальше (м).
const REACH := 32.0
## Слышит двигатели ближе (м) и быстрее (м/с).
const HEAR_RADIUS := 24.0
const HEAR_SPEED := 3.0
## Сколько секунд после импульса сонара корабль ещё «звучит».
const PING_MEMORY := 12.0
## Сонар зовёт хищников ближе (м); экипаж слышит это, если хищник ближе (м).
const PING_CALL := 150.0
const PING_HEARD := 110.0
## Укус ближе (м) к кораблю, урон — доля прочности (как −12 % в браузере), пауза после укуса (с).
const BITE_DIST := 8.5
const BITE_DAMAGE := 0.12
const BITE_COOLDOWN := 25.0
## Радиус разряда, если корабль его не сообщил (м; 20 при полной доле реактора, как Zap.BASE_RADIUS).
const ZAP_RADIUS := EcoWorld.ZAP_RADIUS
## Потолок цели и места появления (м).
const GOAL_CEILING := -6.0
## Запас до корпуса корабля, м (S.pushOut(pr.p, 0.7)), и до какого зазора дотягивается укусом (hullDist < 1,2).
const HULL_GAP := 0.7
const BITE_REACH := 1.2
## Б3: у обшивки ход внутрь гаснет заранее (`hull_soften`): ближе HULL_SOFT_R, м, — с постоянной HULL_SOFT_K, 1/с.
const HULL_SOFT_R := 3.0
const HULL_SOFT_K := 6.0
## Риф у Каменного цветка (ось — подножие цветка, EcoFish.Shoal.axis стай кроны): внутрь кольца REEF_KEEP (м по
## горизонтали; крона Ø 26 м и кусты коралла вокруг) хищник не заходит, импульс ближе REEF_PING к оси зовёт его на
## REEF_EDGE от оси со своей стороны. Отталкивание от кольца — REEF_PUSH (м/с на долю заступа). Сообщение «не идёт
## в риф» — не чаще REEF_CD с на хищника.
const REEF_KEEP := 32.0
const REEF_EDGE := 42.0
const REEF_PING := EcoFlower.PING_R
const REEF_PUSH := 8.0
## С какого запаса до кольца хищник начинает огибать риф, м.
const REEF_MARGIN := 8.0
const REEF_CD := 30.0

## Проба расстановки сцены 00 → 01 (#1400, вариант 3 потока Б, гипотеза гейм-дизайнера, дуга — дизайнер уровней):
## цели патруля — вне тихого круга QUIET_R вокруг спокойной остановки QUIET (как вне кольца рифа), хищник ARC_PRED
## появляется в ARC[0] и ходит по дуге ARC за внешней стороной 01 туда и обратно (±ARC_JITTER). Чувства, скорости,
## охота и бросок — те же. Включает `probe` до reset мира; в игре пока выключено — ждёт сравнения (tools/patrol.gd).
const QUIET := Vector2(20.0, 22.5)
const QUIET_R := 55.0
const ARC_PRED := 1
const ARC: Array[Vector2] = [Vector2(90, -90), Vector2(65, -100), Vector2(15, -95)]
const ARC_JITTER := 5.0
## Фаза «замер» перед броском #1498 (`alert` > 0): хищник почти стоит и разворачивается к кораблю; манящее
## пропало (свет погас, корабль затих, ушёл в укрытие) — уходит в патруль с паузой ALERT_LOSE_CD.
const ALERT_SPEED := 1.5
const ALERT_LOSE_CD := 8.0
## Отход после «потерял корабль» #1498 (`alert_leave` > 0): уходит прочь от корабля на ALERT_LEAVE_DIST м.
const ALERT_LEAVE_DIST := 45.0
## Числа варианта 1 гейм-дизайнера (#1498, 09.11): замер 4 с, отход 20 с — значения `alert`/`alert_leave` в игре.
const ALERT_ON := 4.0
const ALERT_LEAVE_ON := 20.0

## Режим хищника (pr.state в браузере); общее EcoAgent.State — у его существа.
enum Mode { PATROL, HUNT, EAT, INVESTIGATE, CHARGE, RETREAT, FLEE, CLEAN, ALERT }


## Серпохвост: существо мира, режим, голод, пауза перед нападением и добыча.
class Pred:
	extends RefCounted
	var agent: EcoAgent
	var index := 0
	var mode: Mode = Mode.PATROL
	## Голод 0…1.
	var hunger := 0.0
	## Секунды до того, как снова может напасть на корабль (pr.cd).
	var cooldown := 0.0
	## За кем охотится (null — ни за кем).
	var prey: EcoFish.Fish
	## Где появился.
	var start := Vector3.ZERO
	## Время мира последнего укуса (для удара серпом в виде); −99 — не кусал.
	var bit_at := -99.0
	## Пиявник на жабрах (EcoLeech); секунд до заражения; пауза наблюдения «angry»; станция чистки (−1 — не плывёт).
	var leech := false
	var leech_cd := 0.0
	var angry_cd := 0.0
	## Пауза сообщения «заметил вспышку радужников» (flareCd).
	var flare_cd := 0.0
	var station := -1
	## Пауза сообщений перемирия и укрытия у станции чистки (truceCd).
	var truce_cd := 0.0
	## Пауза наблюдения «обходит вуаль» (avoidCd).
	var avoid_cd := 0.0
	## Куда смотрит тело (единичный, догоняет скорость плавно — turn) и крен в повороте (рад, > 0 —
	## левым боком вниз).
	var look := Vector3(0, 0, 1)
	var bank := 0.0
	## Скорость поворота тела (вектор вдоль оси, рад/с): набирается и гаснет не быстрее TURN_ACCEL (`turn`).
	var spin := Vector3.ZERO
	## Секунды до следующего поиска добычи в патруле (раз в SEEK_EVERY, issue #848); 0 — ищет сразу.
	var seek_t := 0.0
	## Пауза сообщения «не идёт в риф у цветка» (#834).
	var reef_cd := 0.0
	## Точка дуги ARC (проба #1400) и куда идёт по ней: +1 — к концу, −1 — назад.
	var arc_i := 0
	var arc_dir := 1
	## Секунды после «потерял корабль» (#1498, фаза «замер»): манящее снова в чутье — сразу новый «замер», пауза
	## cooldown не спасает (скрытой неуязвимости нет); 0 — не терял. Бросок и разряд сбрасывают.
	var wary := 0.0


var all: Array[Pred] = []
## Фильтр укрытий на нынешний шаг (_skip_now); сбрасывается в конце step.
var _skip := Callable()
var _skip_built := false
## Светляки, на которых охотится; null — охотиться не на кого.
var fish: EcoFish
## Трубные органы: в их гуле двигатели корабля не слышно (null — органов нет).
var organs: EcoOrgan
## Подушечники: в их чернилах не видно ни светляков, ни корабля (null — подушечников нет).
var cushions: EcoCushion
## Ленточник: в густой роще хищник теряет напуганную стаю (null — ленточника нет).
var kelp: EcoKelp
## Пиявники и станции чистки (null — пиявников нет; ставит EcoLeech.new).
var leeches: EcoLeech
## Радужники: их вспышка в луче выдаёт корабль издалека (null — радужников нет).
var raduzh: EcoRaduzh
## Огнёвки: у станции чистки перемирие, корабль у станции в укрытии (null — огнёвок нет; ставит EcoOgnevka.new).
var ognevka: EcoOgnevka
## Фонарные вуали: хищник их обходит, корабль под куполом спрятан (null — вуалей нет).
var veils: EcoVeil
## Гротовик: в рифе на его спине прячется своя стая (null — гротовика нет).
var grot: EcoGrot
## Мерцающий планктон: светящийся след выдаёт корабль даже без прожектора (null — планктона нет).
var plankton: EcoPlankton

var _rnd: EcoRandom
## Проба расстановки #1400 (QUIET, ARC): ставить до reset мира.
var probe := false
## Проба целей патруля #1400 (уровни и гейм-дизайнер, 12.11, вариант 1): номер серпохвоста → {"homes": [номера стай
## светляков], "rect": Rect2 по x, z}. Цель «у дома» этих стай он берёт не в ±25 м от дома, а в прямоугольнике rect
## (те же два числа случайности — остальной мир не сдвигается). Пусто — как в игре; ставит tools/mid_calm.gd `band0=`.
var home_band := {}
## Длина фазы «замер» перед броском на манящий корабль, с (#1498: 4 с по гейм-дизайнеру); 0 — бросок сразу (до #1498).
var alert := ALERT_ON
## Сколько секунд после «потерял корабль» хищник отходит прочь (RETREAT, #1498: 20 с); 0 — сразу патруль рядом.
var alert_leave := ALERT_LEAVE_ON
## Ось рифа у цветка на этот шаг (reef_axis).
var _reef := Vector3.INF


func _init(prey_fish: EcoFish = null) -> void:
	fish = prey_fish


## Своё зерно серпохвостов.
static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7004) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	all.clear()
	for i in STARTS.size():
		var at := ARC[0] if probe and i == ARC_PRED else STARTS[i]
		var x := at.x
		var z := at.y
		var y := minf(float(world.ground.call(x, z)) + 8.0, GOAL_CEILING) if world.ground.is_valid() else GOAL_CEILING
		var p := Vector3(x, y, z)
		var a := world.spawn(ID, p)
		a.v = Vector3(0, 0, 1)
		a.set_state(EcoAgent.State.GRAZE)
		var pr := Pred.new()
		pr.agent = a
		a.look = LOOK
		pr.index = i
		pr.hunger = _rnd.range_f(0.1, 0.5)
		pr.cooldown = 20.0
		pr.start = p
		all.append(pr)


## Импульс сонара из точки pos (E.onPing): хищники ближе 150 м плывут проверить звук.
func on_ping(world: EcoWorld, pos: Vector3) -> void:
	world.last_ping = world.time
	var heard := false
	var reef := reef_axis()
	var at_reef := reef.is_finite() and _flat_dist(pos, reef) < REEF_PING
	for pr in all:
		if pr.mode == Mode.CHARGE or pr.mode == Mode.RETREAT or pr.mode == Mode.FLEE or pr.mode == Mode.ALERT:
			continue   # в «замере» сонар только держит внимание (lured), фаза не начинается заново
		var d := pr.agent.distance_to(pos)
		if d >= PING_CALL:
			continue
		_set_mode(pr, Mode.INVESTIGATE, 25.0)
		pr.prey = null
		pr.agent.goal = pos
		if at_reef:  # у цветка — к краю рифа со своей стороны, не к кораблю
			var g := reef_edge(reef, pr.agent.p, REEF_EDGE)
			g.y = minf(_floor(world, g.x, g.z, GOAL_CEILING - 8.0) + 8.0, GOAL_CEILING)
			pr.agent.goal = g
		if d < PING_HEARD:
			heard = true
	if heard and at_reef:
		world.emit(ID, "ping", pos, _text(world, "%s услышал сонар и кружит у внешнего края рифа — в риф он не заходит"))
	elif heard:
		world.emit(ID, "ping", pos, _text(world, "%s услышал сонар и плывёт на звук"))


## Разряд по корпусу (E.onZap): хищники ближе radius уходят на 50 м и 30 с не нападают.
func on_zap(world: EcoWorld, radius: float = ZAP_RADIUS) -> void:
	var c := world.ship.pos
	for pr in all:
		var a := pr.agent
		if a.distance_to(c) >= radius:
			continue
		_set_mode(pr, Mode.FLEE, 8.0)
		pr.prey = null
		pr.cooldown = 30.0
		pr.wary = 0.0
		var away := a.p - c
		if away.length_squared() < 0.01:
			away = Vector3(1, 0, 0)
		var g := a.p + away.normalized() * 50.0
		g.y = minf(g.y, GOAL_CEILING)
		a.goal = g
		world.emit(ID, "zap", a.p, _text(world, "Разряд отпугнул %s", Species.Case.ACC, false))


## Сценарий тестера (#1401): серпохвост n ставится в from и плывёт к to, как на звук (INVESTIGATE), PASS_CALM с
## не нападает, со станции чистки уходит. Так проход хищника мимо куста огнецвета и ряда каменщиков (#1337, #1339)
## виден в кадрах прогона без ожидания случайной встречи. Возвращает false, если такого серпохвоста нет.
const PASS_CALM := 40.0


func pass_by(n: int, from: Vector3, to: Vector3) -> bool:
	if n < 0 or n >= all.size() or not all[n].agent.alive:
		return false
	var pr := all[n]
	if pr.station >= 0 and leeches and pr.station < leeches.stations.size() \
			and leeches.stations[pr.station].busy == pr.index:
		leeches.stations[pr.station].busy = -1
	pr.station = -1
	pr.prey = null
	pr.cooldown = maxf(pr.cooldown, PASS_CALM)
	pr.agent.p = from
	pr.agent.v = (to - from).normalized() * INVESTIGATE_SPEED
	_set_mode(pr, Mode.INVESTIGATE, 25.0)
	pr.agent.goal = to
	return true


## Постановка «замера» (#1498) для сценария тестера (шаг `zamer`) и снимка (`shot.gd zamer=`): хищник встаёт на
## STAGE_DIST м от корабля с нужной стороны — ближе REACH, свет его зовёт; не ниже STAGE_FLOOR над видимым дном.
const STAGE_DIST := 26.0
const STAGE_FLOOR := 3.0
const STAGE_SIDES := ["bok", "korma", "nos"]
## Голод поставленного хищника: выше ATTACK_HUNGER — свет зовёт его сразу.
const STAGE_HUNGER := 0.5
## Остальные — за столько метров от корабля и с такой паузой, с: в кадре один эпизод угрозы.
const STAGE_FAR := 400.0
const STAGE_CALM := 999.0


## Где ставить хищника: bok — с правого борта (+X корабля), korma — за кормой (+Z), nos — перед носом (−Z);
## на высоте корабля, не ниже STAGE_FLOOR над видимым дном. Другая сторона — Vector3.INF.
static func stage_spot(ship: Vector3, yaw: float, side: String) -> Vector3:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var dir: Vector3
	match side:
		"bok":
			dir = right
		"korma":
			dir = -fwd
		"nos":
			dir = fwd
		_:
			return Vector3.INF
	var p := ship + dir * STAGE_DIST
	p.y = maxf(ship.y, Seabed.mesh_height(p.x, p.z) + STAGE_FLOOR)
	return p


## Ставит голодного хищника n в at без паузы, в патруле — «замер» мир начнёт сам, если корабль манит (свет, сонар,
## ход); остальных живых уводит за STAGE_FAR м от корабля ship с паузой STAGE_CALM. false — нет такого хищника.
func stage_near(n: int, at: Vector3, ship: Vector3) -> bool:
	if n < 0 or n >= all.size() or not all[n].agent.alive:
		return false
	for pr in all:
		if pr.station >= 0 and leeches and pr.station < leeches.stations.size() \
				and leeches.stations[pr.station].busy == pr.index:
			leeches.stations[pr.station].busy = -1
		pr.station = -1
		pr.cooldown = 0.0 if pr.index == n else STAGE_CALM
		pr.wary = 0.0
		pr.agent.v = Vector3.ZERO
		pr.agent.p = at if pr.index == n else ship + Vector3(STAGE_FAR + 30.0 * pr.index, 0.0, 0.0)
		pr.agent.goal = pr.agent.p
		pr.prey = null
		_set_mode(pr, Mode.PATROL, 30.0)
	all[n].hunger = STAGE_HUNGER
	return true


## Каждый серпохвост виден сонару и сканеру.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for pr in all:
		if pr.agent.alive:
			out.append(EcoWorld.target(ID, pr.agent.p, 2.5))


## Голодный хищник в патруле ищет добычу не каждый шаг, а раз в столько секунд (issue #848: поиск по всем
## светлякам с фильтром укрытий — главная доля «мира» в провалах кадра).
const SEEK_EVERY := 0.25


## Ось рифа у Каменного цветка — подножие, вокруг которого кружат стаи кроны; Vector3.INF — рифа нет (нет светляков).
func reef_axis() -> Vector3:
	if fish:
		for sh in fish.shoals:
			if sh.crown:
				return sh.axis
	return Vector3.INF


## Расстояние по горизонтали.
static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Точка на кольце радиуса r вокруг оси рифа в сторону from (по горизонтали; высота — from).
static func reef_edge(axis: Vector3, from: Vector3, r: float) -> Vector3:
	var off := Vector2(from.x - axis.x, from.z - axis.z)
	off = off.normalized() if off.length_squared() > 1e-6 else Vector2(1, 0)
	return Vector3(axis.x + off.x * r, from.y, axis.z + off.y * r)


## Цель за кольцом рифа: внутри кольца keep — вынесена на кольцо по горизонтали.
## Цель в прямоугольнике rect (x, z) по сдвигу от дома dx, dz ∈ [−25; 25] — та же доля по каждой оси (`home_band`).
static func band_goal(rect: Rect2, dx: float, dz: float) -> Vector2:
	return rect.position + rect.size * Vector2(clampf((dx + 25.0) / 50.0, 0.0, 1.0), clampf((dz + 25.0) / 50.0, 0.0, 1.0))


static func outside_reef(axis: Vector3, g: Vector3, keep: float) -> Vector3:
	if not axis.is_finite() or _flat_dist(g, axis) >= keep:
		return g
	return reef_edge(axis, g, keep)


## Обход рифа у цветка: ближе REEF_KEEP + REEF_MARGIN к оси скорость внутрь кольца поворачивает вдоль него (в лоб —
## против часовой, если смотреть сверху), заступившего за кольцо выталкивает (REEF_PUSH). Скорость по горизонтали
## не меняется по величине — хищник огибает риф, а не тормозит у него.
static func reef_steer(axis: Vector3, p: Vector3, want: Vector3) -> Vector3:
	var off := Vector2(p.x - axis.x, p.z - axis.z)
	var r := off.length()
	if r >= REEF_KEEP + REEF_MARGIN:
		return want
	var out := off / r if r > 1e-4 else Vector2(1, 0)
	var w2 := Vector2(want.x, want.z)
	var sp := w2.length()
	var radial := w2.dot(out)
	if radial < 0.0:
		var tang := w2 - out * radial
		if tang.length() < 0.2 * sp:
			tang = Vector2(-out.y, out.x) * (signf(tang.dot(Vector2(-out.y, out.x))) if tang.length() > 1e-4 else 1.0)
		w2 = tang.normalized() * sp
	if r < REEF_KEEP:
		w2 += out * (REEF_PUSH * (REEF_KEEP - r) / REEF_KEEP + 1.0)
	return Vector3(w2.x, want.y, w2.y)


## Следующая точка дуги ARC для патруля (проба #1400): туда и обратно по тем же отрезкам, концы — разворот.
static func arc_next(pr: Pred) -> Vector2:
	var n := ARC.size()
	if n == 1:
		return ARC[0]
	var j := pr.arc_i + pr.arc_dir
	if j < 0 or j >= n:
		pr.arc_dir = -pr.arc_dir
		j = pr.arc_i + pr.arc_dir
	pr.arc_i = j
	return ARC[j]


## Корабль в рифе у цветка: хищник его там не атакует (#834).
func ship_in_reef(world: EcoWorld, reef: Vector3) -> bool:
	return reef.is_finite() and _flat_dist(world.ship.pos, reef) < REEF_KEEP


func step(world: EcoWorld, dt: float) -> void:
	_reef = reef_axis()
	for pr in all:
		_step_pred(world, pr, dt)
		turn(pr, dt)
	_skip = Callable()
	_skip_built = false  # лямбда держит хищников — до следующего шага не храним


## Фильтр укрытий светляков на этот шаг: собирается один раз (первый, кому нужен), не на каждого хищника.
func _skip_now() -> Callable:
	if not _skip_built:
		_skip = _hidden_fish()
		_skip_built = true
	return _skip


## Плавный поворот (Б3, «плавность поведения»): тело не щёлкает за скоростью, а догоняет её — доля угла за секунду
## TURN_FOLLOW, но не быстрее TURN_MAX (рад/с); в повороте ложится на бок: крен BANK_K на 1 рад/с поворота, не больше
## BANK_MAX, догоняет нужный за BANK_FOLLOW (1/с). Остановился — держит курс, нос выравнивается к горизонту.
## Сам поворот — с инерцией: скорость поворота `Pred.spin` меняется не быстрее TURN_ACCEL рад/с², к курсу — не быстрее
## √(2 · TURN_ACCEL · угол), и тормозит заранее. Раньше хищник встал у точки патруля, а следующая — в 1,5 рад: тело
## срывалось с 0,05 до 3 рад/с за кадр (88 рад/с², нашёл обход мира по угловым ускорениям), так же — смена цели.
## На сколько секунд хода вперёд смотрит на дно (`EcoAgent.look`): раньше на склоне рифа и у гребня взлетал вплотную ко
## дну до 12 м/с вверх и вставал на вершине за кадр (рывок до 107 м/с²).
const LOOK := 1.5
const TURN_FOLLOW := 4.0
const TURN_MAX := 3.0
const TURN_ACCEL := 8.0
const BANK_K := 0.35
const BANK_MAX := deg_to_rad(25.0)
const BANK_FOLLOW := 3.0
## Наклон тела вверх-вниз не больше (рад).
const PITCH_MAX := deg_to_rad(30.0)
## Ход разворачивается дугой, а не через остановку (`EcoAgent.swim`): курс скорости — доля угла SWIM_TURN/с, не
## быстрее SWIM_TURN_MAX рад/с (в охоте и броске — SWIM_TURN_SHARP); в крутом повороте ход сбавляется до cos угла,
## не меньше SWIM_SLOW доли. Раньше цель патруля за спиной гасила ход до нуля и хищник ~1 с плыл хвостом вперёд.
const SWIM_TURN := 3.0
const SWIM_TURN_MAX := 1.5
const SWIM_TURN_SHARP := 3.0
const SWIM_SLOW := 0.3
## Вне охоты и броска у цели ход — не больше ARRIVE_K × остаток (м/с на метр): встаёт у неё, а не кружит.
const ARRIVE_K := 0.5


## Куда хочет смотреть голова: по скорости, наклон — не больше PITCH_MAX; почти стоит — прежний курс без наклона.
static func aim(pr: Pred) -> Vector3:
	var v := pr.agent.v
	if v.length_squared() <= 0.01:
		var f := Vector2(pr.look.x, pr.look.z)
		f = f.normalized() if f.length_squared() > 1e-8 else Vector2(0, 1)
		return Vector3(f.x, 0.0, f.y)
	var flat := Vector2(v.x, v.z).length()
	var pitch := clampf(atan2(v.y, flat), -PITCH_MAX, PITCH_MAX)
	var h := Vector2(v.x, v.z).normalized() if flat > 1e-4 else Vector2(pr.look.x, pr.look.z).normalized()
	if not h.is_finite() or h.length_squared() < 0.5:
		h = Vector2(0, 1)
	return Vector3(h.x * cos(pitch), sin(pitch), h.y * cos(pitch))


## Курс по горизонтали (рад; растёт — поворот влево, 0 — нос в −Z, как yaw корабля).
static func yaw_of(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


## Шаг поворота тела за dt: look догоняет aim со скоростью поворота spin (инерция), крен — скорость поворота по
## горизонтали.
static func turn(pr: Pred, dt: float) -> void:
	if dt <= 0.0:
		return
	var from := pr.look
	var want := aim(pr)
	var ang := from.angle_to(want)
	var goal := Vector3.ZERO
	if ang > 1e-5:
		var axis := from.cross(want)
		if axis.length_squared() < 1e-10:  # ровно назад — разворот по горизонтали
			axis = pr.spin if absf(pr.spin.normalized().dot(Vector3.UP)) > 0.5 else Vector3.UP
		var rate := minf(minf(ang * TURN_FOLLOW, TURN_MAX), sqrt(2.0 * TURN_ACCEL * ang))
		goal = axis.normalized() * rate
	pr.spin += (goal - pr.spin).limit_length(TURN_ACCEL * dt)
	var sp := pr.spin.length()
	if sp > 1e-6:
		var ax := pr.spin / sp
		# только составляющая к курсу: ось сменилась — не уводит нос в сторону от want
		var step := minf(sp * dt, ang)
		var to := from.cross(want)
		if to.length_squared() > 1e-10 and ax.dot(to.normalized()) < 0.0:
			step = sp * dt  # ещё крутит прочь — гасит ход по инерции
		pr.look = from.rotated(ax, step).normalized()
	var rate := wrapf(yaw_of(pr.look) - yaw_of(from), -PI, PI) / dt
	var bank_want := clampf(rate * BANK_K, -BANK_MAX, BANK_MAX)
	pr.bank = lerpf(pr.bank, bank_want, 1.0 - exp(-BANK_FOLLOW * dt))


static func _set_mode(pr: Pred, m: Mode, t: float) -> void:
	pr.mode = m
	pr.agent.timer = t
	match m:
		Mode.HUNT, Mode.CHARGE:
			pr.agent.state = EcoAgent.State.HUNT
		Mode.INVESTIGATE, Mode.CLEAN, Mode.ALERT:
			pr.agent.state = EcoAgent.State.SEEK
		Mode.RETREAT, Mode.FLEE:
			pr.agent.state = EcoAgent.State.FLEE
		_:
			pr.agent.state = EcoAgent.State.GRAZE


## Манит ли корабль: свет, недавний сонар или светящийся след планктона (EcoPlankton) ближе 32 м (заражённого
## пиявником — 48 м; с каждым спуском «глубже» — дальше, × ShipState.pred_k()), шум двигателей ближе 24 м
## (если его не глушит трубный орган). Корабль в чернилах подушечника не манит вовсе (!E.shipHidden).
func lured(world: EcoWorld, pr: Pred, d_ship: float) -> bool:
	if ship_hidden(world):
		return false
	var s := world.ship
	var seen := d_ship < reach(pr, s.pred_k()) and (s.light_on or world.time - world.last_ping < PING_MEMORY \
		or (plankton != null and plankton.betrays()))
	return seen or hears_ship(world, pr, d_ship)


## С какого расстояния видит свет и сонар корабля: заражённый пиявником — издалека; глубже — чутьё острее
## (pred_k — ShipState.pred_k(), js: (pr.leech ? 48 : 32) * G.Run.predK()).
static func reach(pr: Pred, pred_k := 1.0) -> float:
	return (EcoLeech.REACH if pr.leech else REACH) * pred_k


## Спрятан ли корабль от хищников (E.shipHidden): в облаке чернил подушечника или под куполом фонарной вуали.
func ship_hidden(world: EcoWorld) -> bool:
	return (cushions != null and cushions.ship_ink(world) != null) or (veils != null and veils.ship_under(world) != null)


## Корабль в укрытии у станции чистки огнёвок (E.shipSheltered): ближе 18 м к вершине огнецвета.
func ship_sheltered(world: EcoWorld) -> bool:
	return ognevka != null and ognevka.shelter(world.ship.pos) != null


## Слышит ли двигатели корабля (hearsShip): ближе 24 м и быстрее 3 м/с, если корабль не в гуле трубного органа
## и не в густом ленточнике (`EcoKelp.muffling`, #1338).
## Гул спрятал корабль от патрулирующего или проверяющего звук хищника — наблюдение органа «mask».
func hears_ship(world: EcoWorld, pr: Pred, d_ship: float) -> bool:
	if d_ship >= HEAR_RADIUS or absf(world.ship.speed) <= HEAR_SPEED:
		return false
	if organs:
		var og := organs.masking(world)
		if og:
			organs.masked(world, og, pr.mode == Mode.PATROL or pr.mode == Mode.INVESTIGATE)
			return false
	if kelp:
		var gr := kelp.muffling(world)
		if gr:
			kelp.muffled(world, gr, pr.mode == Mode.PATROL or pr.mode == Mode.INVESTIGATE)
			return false
	return true


## Текст события собирается в момент показа (вид мог быть уже просканирован). Мир — слабой ссылкой и без self:
## событие лежит в шине мира, сильная ссылка замкнула бы круг. fmt — с одним %s для названия хищника.
static func _text(world: EcoWorld, fmt: String, c: Species.Case = Species.Case.NOM, cap := true) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID, c) if w else Species.called(ID, c)
		return fmt % (Species.cap(name) if cap else name)


## Заманить хищника на корабль (E.lure: эхоловец выпросил свет) — бросок, как на свет прожектора.
func lure(world: EcoWorld, pr: Pred) -> void:
	_start_charge(world, pr)


## Хищника поманил корабль: сначала «замер» (#1498, `alert` > 0), с `alert` = 0 — бросок сразу.
func _react(world: EcoWorld, pr: Pred) -> void:
	if alert <= 0.0:
		_start_charge(world, pr)
		return
	if not world.threat_free(pr):
		return
	world.hold_threat(pr)
	_set_mode(pr, Mode.ALERT, alert)
	pr.prey = null
	world.emit(ID, "alert", pr.agent.p, _text(world, alert_fmt(_lure_kind(world))))


enum Lure { LIGHT, PING, WAKE, NOISE }


## Что манит корабль сейчас — в том же порядке, что строки броска (`_start_charge`).
func _lure_kind(world: EcoWorld) -> Lure:
	if world.ship.light_on:
		return Lure.LIGHT
	if world.time - world.last_ping < PING_MEMORY:
		return Lure.PING
	if plankton != null and plankton.betrays():
		return Lure.WAKE
	return Lure.NOISE


## Строка «замер» (#1498) с причиной — экипаж видит, что убрать: свет, сонар, ход. Без обещаний «безопасно».
static func alert_fmt(kind: Lure) -> String:
	match kind:
		Lure.LIGHT:
			return "%s замер и смотрит на корабль — его манит свет"
		Lure.PING:
			return "%s замер и смотрит на корабль — услышал сонар"
		Lure.WAKE:
			return "%s замер и смотрит на корабль — видит светящийся след"
	return "%s замер и смотрит на корабль — слышит двигатели"


func _start_charge(world: EcoWorld, pr: Pred) -> void:
	if not world.threat_free(pr):   # у корабля уже идёт другой эпизод угрозы (#834) — бросок позже
		return
	world.hold_threat(pr)
	_set_mode(pr, Mode.CHARGE, 10.0)
	pr.prey = null
	pr.wary = 0.0
	var at := pr.agent.p
	if world.ship.light_on:
		world.emit(ID, "ship", at, _text(world, "%s разворачивается к кораблю — его привлёк свет"))
	elif world.time - world.last_ping < PING_MEMORY:
		world.emit(ID, "ping", at, _text(world, "%s разворачивается к кораблю — его привлёк сонар"))
	elif plankton != null and plankton.betrays():
		world.emit(EcoPlankton.ID, "betray", at, _wake_text(world))
	else:
		world.emit(ID, "hear", at, _text(world, "%s услышал двигатели и разворачивается к кораблю"))


## «Серпохвост заметил светящийся след мерцающего планктона…» — названия собираются в момент показа.
static func _wake_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var p := w.nm(ID) if w else Species.called(ID)
		var c := w.nm(EcoPlankton.ID, Species.Case.GEN) if w else Species.called(EcoPlankton.ID, Species.Case.GEN)
		return "%s заметил светящийся след %s и разворачивается к кораблю" % [Species.cap(p), c]


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


func _step_pred(world: EcoWorld, pr: Pred, dt: float) -> void:
	var a := pr.agent
	var rate := HUNGER_RATE
	if pr.mode == Mode.CLEAN:
		rate = EcoLeech.CLEAN_HUNGER_RATE
	elif pr.leech:
		rate = EcoLeech.HUNGER_RATE
	pr.hunger = minf(1.0, pr.hunger + dt * rate)
	pr.cooldown -= dt
	pr.angry_cd -= dt
	pr.flare_cd -= dt
	pr.truce_cd -= dt
	pr.avoid_cd -= dt
	pr.reef_cd -= dt
	pr.wary = maxf(pr.wary - dt, 0.0)
	var ship := world.ship.pos
	var d_ship := a.distance_to(ship)
	var at_station := leeches.near_station(a.p) != null if leeches else false
	var lure := lured(world, pr, d_ship)  # и голодного, и сытого: гул органа прячет корабль от каждого
	var sheltered := ship_sheltered(world)
	var in_reef := ship_in_reef(world, _reef)
	var can_attack := (pr.cooldown <= 0.0 or pr.wary > 0.0) and pr.hunger > (EcoLeech.ATTACK_HUNGER if pr.leech else ATTACK_HUNGER) \
		and lure and not at_station and not sheltered and not in_reef
	if raduzh and not sheltered:
		_step_flare(world, pr, d_ship)
	if lure and sheltered and pr.cooldown <= 0.0 and pr.truce_cd <= 0.0 \
			and (pr.mode == Mode.PATROL or pr.mode == Mode.INVESTIGATE):
		pr.truce_cd = EcoOgnevka.TRUCE_CD
		pr.cooldown = maxf(pr.cooldown, EcoOgnevka.SHELTER_PAUSE)
		ognevka.sheltered(world, a.p, false)
	if leeches:
		_step_leech(world, pr, dt, can_attack, d_ship, at_station)

	var speed := PATROL_SPEED
	match pr.mode:
		Mode.PATROL:
			if a.expired() or a.distance_to(a.goal) < 4.0:
				a.timer = _rnd.range_f(10, 20)
				var gx: float
				var gz: float
				if probe and pr.index == ARC_PRED:
					var g2 := arc_next(pr)
					gx = g2.x + _rnd.range_f(-ARC_JITTER, ARC_JITTER)
					gz = g2.y + _rnd.range_f(-ARC_JITTER, ARC_JITTER)
				elif fish and fish.shoals.size() > 0 and _rnd.chance(0.6):
					var sh: EcoFish.Shoal = _rnd.pick(fish.shoals)
					var h: Vector3 = sh.home
					gx = h.x + _rnd.range_f(-25, 25)
					gz = h.z + _rnd.range_f(-25, 25)
					var band: Dictionary = home_band.get(pr.index, {})
					if not band.is_empty() and sh.index in (band["homes"] as Array):
						var gb := band_goal(band["rect"], gx - h.x, gz - h.z)
						gx = gb.x
						gz = gb.y
				else:
					gx = _rnd.range_f(-170, 150)
					gz = _rnd.range_f(-170, 150)
				var gp := outside_reef(_reef, Vector3(gx, 0.0, gz), REEF_KEEP)  # патруль — снаружи рифа у цветка
				if probe:  # и снаружи тихого круга у спокойной остановки
					gp = outside_reef(Vector3(QUIET.x, 0.0, QUIET.y), gp, QUIET_R)
				gx = gp.x
				gz = gp.z
				var gy := minf(_floor(world, gx, gz, GOAL_CEILING - 14.0) + _rnd.range_f(4, 14), GOAL_CEILING)
				a.goal = Vector3(gx, gy, gz)
			pr.seek_t = maxf(pr.seek_t - dt, 0.0)
			if pr.hunger > HUNT_HUNGER and fish and not at_station and pr.seek_t <= 0.0:
				pr.seek_t = SEEK_EVERY
				var f := fish.nearest_fish(a.p, HUNT_RADIUS, _skip_now())
				if f:
					_set_mode(pr, Mode.HUNT, 12.0)
					pr.prey = f
			if can_attack:
				_react(world, pr)

		Mode.HUNT:
			speed = HUNT_SPEED
			if pr.prey == null or not pr.prey.agent.alive or a.expired():  # упустил за 12 с или добычу съел другой
				_give_up(pr, _rnd.range_f(4, 8))
			elif ognevka and (at_station or leeches.near_station(pr.prey.agent.p)):  # у станции чистки перемирие
				_give_up(pr, _rnd.range_f(4, 8))
				if pr.truce_cd <= 0.0:
					pr.truce_cd = EcoOgnevka.TRUCE_CD
					ognevka.truce(world, a.p)
			else:
				var gr := kelp.shelter(pr.prey) if kelp else null
				var cu := cushions.ink_at(pr.prey.agent.p) if cushions and gr == null else null
				var gt := grot.shelter(pr.prey) if grot and gr == null and cu == null else null
				if gr:  # стая нырнула в густой ленточник
					_give_up(pr, _rnd.range_f(4, 8))
					kelp.hid_fish(world, gr)
				elif cu:  # светляк скрылся в чернилах подушечника
					_give_up(pr, _rnd.range_f(4, 8))
					cushions.hid_fish(world, cu)
				elif gt:  # стая нырнула в риф на спине гротовика
					_give_up(pr, _rnd.range_f(4, 8))
					grot.hid_fish(world)
				else:
					a.goal = pr.prey.agent.p + pr.prey.agent.v * 0.4
					if can_catch(a, pr.prey.agent):
						var caught := pr.prey.agent.p
						fish.kill(pr.prey)
						pr.hunger = 0.0
						pr.prey = null
						_set_mode(pr, Mode.EAT, 5.0)
						world.emit(ID, "catch", a.p, _catch_text(world))
						if kelp:
							kelp.caught_at(world, caught)
					elif can_attack and pr.hunger > HUNT_TO_SHIP_HUNGER:
						_react(world, pr)

		Mode.EAT:
			speed = EAT_SPEED
			if a.expired():
				_set_mode(pr, Mode.PATROL, 0.0)

		Mode.INVESTIGATE:
			speed = INVESTIGATE_SPEED
			if a.distance_to(a.goal) < 10.0 or a.expired():
				_set_mode(pr, Mode.PATROL, 0.0)
			if can_attack:
				_react(world, pr)

		Mode.ALERT:
			speed = ALERT_SPEED
			world.hold_threat(pr)
			var to := ship - a.p
			a.goal = a.p + (to.normalized() * 3.0 if to.length_squared() > 1e-4 else Vector3.ZERO)
			if not can_attack:  # свет погас, корабль затих или в укрытии — потерял
				pr.wary = alert_leave + ALERT_LOSE_CD
				if alert_leave > 0.0:
					_set_mode(pr, Mode.RETREAT, alert_leave)
					pr.cooldown = maxf(pr.cooldown, alert_leave + ALERT_LOSE_CD)
					var away := a.p - ship
					away.y = 0.0
					if away.length_squared() < 0.01:
						away = Vector3(1, 0, 0)
					var g := a.p + away.normalized() * ALERT_LEAVE_DIST
					g.y = minf(_floor(world, g.x, g.z, GOAL_CEILING - 8.0) + 8.0, GOAL_CEILING)
					a.goal = g
				else:
					_set_mode(pr, Mode.PATROL, 0.0)
					pr.cooldown = maxf(pr.cooldown, ALERT_LOSE_CD)
				world.emit(ID, "lost", a.p, _text(world, "%s потерял корабль и отворачивает"))
			elif a.expired():
				_start_charge(world, pr)

		Mode.CHARGE:
			speed = CHARGE_SPEED
			a.goal = ship
			world.hold_threat(pr)
			if in_reef:  # корабль ушёл в риф у цветка — хищник отворачивает к краю рифа
				_set_mode(pr, Mode.RETREAT, 8.0)
				pr.cooldown = maxf(pr.cooldown, 10.0)
				var g := reef_edge(_reef, a.p, REEF_EDGE)
				g.y = minf(_floor(world, g.x, g.z, GOAL_CEILING - 8.0) + 8.0, GOAL_CEILING)
				a.goal = g
				if pr.reef_cd <= 0.0:
					pr.reef_cd = REEF_CD
					world.emit(ID, "reef", a.p, _text(world, "%s не идёт за кораблём в риф у Каменного цветка"))
			elif sheltered:  # корабль у станции чистки — хищник отворачивает
				_set_mode(pr, Mode.RETREAT, EcoOgnevka.TURN_AWAY_TIME)
				pr.cooldown = maxf(pr.cooldown, EcoOgnevka.TURN_AWAY_PAUSE)
				var g := a.p + Vector3(_rnd.range_f(-40, 40), 4.0, _rnd.range_f(-40, 40))
				g.y = minf(g.y, GOAL_CEILING)
				a.goal = g
				if pr.truce_cd <= 0.0:
					pr.truce_cd = EcoOgnevka.TRUCE_CD
					ognevka.sheltered(world, a.p, true)
			elif ship_hidden(world):  # корабль в чернилах подушечника — хищник его потерял
				_set_mode(pr, Mode.RETREAT, 10.0)
				var g := a.p + Vector3(_rnd.range_f(-40, 40), 5.0, _rnd.range_f(-40, 40))
				g.y = minf(g.y, GOAL_CEILING)
				a.goal = g
				if cushions != null and cushions.ship_ink(world) != null:
					cushions.hid_ship(world, a.p)
				else:  # под куполом вуали
					veils.hid_ship(world, a.p)
			elif d_ship < BITE_DIST or world.touches_ship(a.p, BITE_REACH):
				if world.hit_ship(Species.cap(world.nm(ID)), BITE_DAMAGE, a.p):
					world.emit(ID, "bite", a.p, _text(world, "%s укусил корпус"))
				pr.bit_at = world.time
				_set_mode(pr, Mode.RETREAT, 14.0)
				pr.cooldown = BITE_COOLDOWN
				var away := a.p - ship
				away.y = 0.0
				if away.length_squared() < 0.01:
					away = Vector3(1, 0, 0)
				var g := a.p + away.normalized() * 60.0
				g.y = minf(_floor(world, g.x, g.z, GOAL_CEILING - 8.0) + 8.0, GOAL_CEILING)
				a.goal = g
			elif a.expired():
				_set_mode(pr, Mode.PATROL, 0.0)
				pr.cooldown = 10.0

		Mode.RETREAT, Mode.FLEE:
			speed = FLEE_SPEED if pr.mode == Mode.FLEE else RETREAT_SPEED
			if pr.mode == Mode.RETREAT and pr.wary > 0.0 and can_attack:   # отходил, потеряв корабль, — манит снова
				_react(world, pr)
			elif a.expired():
				_set_mode(pr, Mode.PATROL, 0.0)

		Mode.CLEAN:
			speed = _step_clean(world, pr, dt)
			if pr.mode == Mode.CLEAN and can_attack and pr.hunger > HUNT_TO_SHIP_HUNGER:
				_react(world, pr)

	if pr.leech and pr.mode != Mode.CLEAN:
		speed *= EcoLeech.SLOW  # пиявник замедляет хищника

	# прямо к цели с постоянной скоростью; в охоте и броске поворачивает резче
	var d := a.goal - a.p
	var want := d.normalized() * speed if d.length_squared() > 1e-4 else d
	var sharp := pr.mode == Mode.HUNT or pr.mode == Mode.CHARGE
	if not sharp:  # у цели сбавляет ход и встаёт, а не кружит над ней дугой разворота
		want *= minf(1.0, d.length() * ARRIVE_K / maxf(speed, 0.01))
	if veils:  # фонарные вуали обходит стороной
		var push := veils.pred_push(a.p)
		if push != Vector3.ZERO:
			want += push
			if pr.avoid_cd <= 0.0:
				pr.avoid_cd = EcoVeil.AVOID_CD
				veils.avoided(world, a.p)
	if _reef.is_finite() and pr.mode != Mode.CHARGE:
		want = reef_steer(_reef, a.p, want)
	a.agility = 1.6 if sharp else 1.1
	a.swim(want, dt, SWIM_TURN, SWIM_TURN_SHARP if sharp else SWIM_TURN_MAX, SWIM_SLOW, world.ground)
	if pr.mode == Mode.CHARGE or world.time - pr.bit_at < STRIKE_AFTER:
		strike_brake(a, world.ship, dt, pr.mode == Mode.CHARGE or world.ship.speed < STRIKE_SHIP)   # бросок и отход после укуса тормозят ровно, а не встают о обшивку (#1753)
	else:   # у обшивки тормозит заранее, а не встаёт о неё за кадр
		hull_soften(a, world.ship, dt)
	world.push_out(a, HULL_GAP) # корпус не пускает внутрь


## Добыча ушла в укрытие (ленточник, чернила, риф гротовика) или к станции чистки, погоня вышла за 12 с, добычу
## съел другой — хищник бросает охоту и t с патрулирует, не ища новую (#1753). Раньше `seek_t` — 0,25 с, и он тут же брал соседа той же стаи: за 5 минут
## мира 28 охот из 56 начинались меньше чем через 8 с после брошенной, часто через 0,27 с, — ход 3 ↔ 7,6 м/с
## и волна хвоста 0,42 ↔ 0,72 Гц перескакивали каждые 1–5 с («рывками по скорости», `tools/pred_jerk.gd`).
static func _give_up(pr: Pred, t: float) -> void:
	_set_mode(pr, Mode.PATROL, t)
	pr.prey = null
	pr.seek_t = t


## Б3: ближе HULL_SOFT_R к обшивке ход внутрь корпуса гаснет с постоянной HULL_SOFT_K в секунду, а не за кадр в
## `push_out`. Раньше после укуса корпуса на ходу корабля тело по инерции входило в обшивку и вставало: 8 → 5 м/с
## за кадр, 183 м/с² (`tools/jerk.gd scena=1 move=3 seed=3`). Бросок (CHARGE) бьёт в корпус как прежде.
static func hull_soften(a: EcoAgent, ship: EcoLink.ShipState, dt: float) -> void:
	var res := EcoHull.push_out(a.p, ship.pos, ship.yaw, HULL_SOFT_R)
	if res.is_empty():
		return
	var n: Vector3 = res[1]
	var sv := Vector3(-sin(ship.yaw), 0.0, -cos(ship.yaw)) * ship.speed
	var vn := (a.v - sv).dot(n)
	if vn < 0.0:
		a.v -= n * vn * minf(1.0, HULL_SOFT_K * dt)


## #1753: бросок (CHARGE) шёл к обшивке на 7–9,5 м/с, а после укуса `hull_soften` гасил ход внутрь с 6/с — центр
## тела 42 м/с² (7 → 3 м/с за 0,2 с, `tools/pred_jerk.gd`), в шаг укуса — удар о обшивку до 56 м/с² (нос навстречу —
## 184): удар «встаёт» о корпус. Теперь в броске и STRIKE_AFTER с после укуса ход относительно корабля не выше
## sqrt(2·STRIKE_DECEL·L), где L — путь по этому ходу до обшивки (луч, STRIKE_R вперёд): тело тормозит не круче
## STRIKE_DECEL м/с² и доходит до укуса (BITE_REACH) уже медленно, по той же кривой, что и после него, — укус
## «с подходом», без стопа о корпус. Луч мимо обшивки — ход не трогает (проходит вдоль борта). Сошёл с кривой
## (нос корабля сам идёт на зверя) — после укуса за шаг гасит не больше, чем `hull_soften`.
const STRIKE_R := 8.0
const STRIKE_DECEL := 11.0
## Сколько секунд после укуса ход у обшивки гасит strike_brake, а не hull_soften.
const STRIKE_AFTER := 1.5
## Корабль быстрее (м/с) — после укуса кривую держит мягко: нос сам идёт на зверя, жёсткая кривая встала бы ударом.
const STRIKE_SHIP := 1.0
## Точность пути до обшивки по лучу, м.
const STRIKE_TOL := 0.05

static func strike_brake(a: EcoAgent, ship: EcoLink.ShipState, dt: float, hard: bool) -> void:
	if not EcoHull.touches(a.p, ship.pos, ship.yaw, STRIKE_R + HULL_GAP):
		return
	var sv := Vector3(-sin(ship.yaw), 0.0, -cos(ship.yaw)) * ship.speed
	var rel := a.v - sv
	var s := rel.length()
	if s < 1e-3:
		return
	var dir := rel / s
	var lo := 0.0
	var hi := minf(STRIKE_R, s * s / (2.0 * STRIKE_DECEL) + 0.5)  # дальше этого кривая ход не режет
	if not EcoHull.touches(a.p + dir * hi, ship.pos, ship.yaw, HULL_GAP):
		return   # по ходу обшивки нет (ближе, чем успел бы затормозить)
	while hi - lo > STRIKE_TOL:
		var m := (lo + hi) * 0.5
		if EcoHull.touches(a.p + dir * m, ship.pos, ship.yaw, HULL_GAP):
			hi = m
		else:
			lo = m
	var cap := sqrt(2.0 * STRIKE_DECEL * lo)
	var over := s - cap
	if over <= 0.0:
		return
	if not hard:   # за шаг — не круче STRIKE_DECEL, если кривая не нарушена сильнее, и не круче hull_soften
		over = minf(over, maxf(STRIKE_DECEL * dt, over * minf(1.0, HULL_SOFT_K * dt)))
	a.v -= dir * over


## Вспышка радужников видна издалека: патрульный или проверяющий звук хищник дальше своего чутья, но ближе 110 м
## к кораблю, без паузы после укуса, плывёт к кораблю проверить (25 с); наблюдение «betray» — раз в 30 с на хищника.
## Корабль в чернилах подушечника вспышка не выдаёт.
func _step_flare(world: EcoWorld, pr: Pred, d_ship: float) -> void:
	if not raduzh.flare_seen(d_ship, reach(pr, world.ship.pred_k())) or ship_hidden(world) or pr.cooldown > 0.0:
		return
	if pr.mode != Mode.PATROL and pr.mode != Mode.INVESTIGATE:
		return
	_set_mode(pr, Mode.INVESTIGATE, 25.0)
	pr.agent.goal = world.ship.pos
	if pr.flare_cd <= 0.0:
		pr.flare_cd = EcoRaduzh.FLARE_CD
		world.emit(EcoRaduzh.ID, "betray", pr.agent.p, _flare_text(world))


## «Серпохвост заметил вспышку радужников и плывёт к кораблю» — оба названия в момент показа.
static func _flare_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var p := w.nm(ID) if w else Species.called(ID)
		var r := w.nm(EcoRaduzh.ID, Species.Case.GEN) if w else Species.called(EcoRaduzh.ID, Species.Case.GEN)
		return "%s заметил вспышку %s и плывёт к кораблю" % [Species.cap(p), r]


## Пиявник: злость издалека, заражение здорового (не у станции), сытый заражённый плывёт на чистку.
func _step_leech(world: EcoWorld, pr: Pred, dt: float, can_attack: bool, d_ship: float, at_station: bool) -> void:
	if pr.leech and can_attack and d_ship > REACH and pr.angry_cd <= 0.0:
		pr.angry_cd = EcoLeech.ANGRY_CD
		world.emit(EcoLeech.ID, "angry", pr.agent.p, _angry_text(world))
	if not pr.leech:
		pr.leech_cd -= dt
		if pr.leech_cd <= 0.0 and not at_station:
			pr.leech = true
			world.emit(EcoLeech.ID, "infest", pr.agent.p, _infest_text(world))
	elif pr.station < 0 and pr.hunger < EcoLeech.SEEK_HUNGER and (pr.mode == Mode.PATROL or pr.mode == Mode.EAT):
		var st := leeches.nearest_station(pr.agent.p)
		if st:
			pr.station = st.index
			_set_mode(pr, Mode.CLEAN, EcoLeech.CLEAN_TIME)
			pr.agent.goal = st.top


## Чистка: к вершине огнецвета, ближе 4 м — стоит, огнёвки работают 6 с и снимают пиявника. Возвращает скорость.
func _step_clean(world: EcoWorld, pr: Pred, dt: float) -> float:
	var a := pr.agent
	var st: EcoLeech.Station = leeches.stations[pr.station] if pr.station >= 0 and pr.station < leeches.stations.size() else null
	if st == null or not pr.leech:
		pr.station = -1
		_set_mode(pr, Mode.PATROL, 0.0)
		return PATROL_SPEED
	var d := a.distance_to(st.top)
	a.goal = st.top
	if d < EcoLeech.CLEAN_R:
		st.busy = pr.index
		st.work += dt
	if st.work >= EcoLeech.CLEAN_WORK:
		st.work = 0.0
		st.busy = -1
		pr.leech = false
		pr.station = -1
		pr.leech_cd = leeches.next_cd()
		pr.hunger = minf(pr.hunger, 0.3)
		_set_mode(pr, Mode.PATROL, _rnd.range_f(4, 8))
		world.emit("ognevka", "clean", st.top, _clean_text(world))
		world.emit(EcoLeech.ID, "cleaned", st.top)
	elif a.expired() or pr.hunger > EcoLeech.GIVE_UP_HUNGER:
		pr.station = -1
		_set_mode(pr, Mode.PATROL, 0.0)
	return EcoLeech.CLEAN_SLOW if d < EcoLeech.CLEAN_R else EcoLeech.CLEAN_SPEED


static func _infest_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var leech := w.nm(EcoLeech.ID) if w else Species.called(EcoLeech.ID)
		var pred := w.nm(ID, Species.Case.GEN) if w else Species.called(ID, Species.Case.GEN)
		return "%s присосался к жабрам %s" % [Species.cap(leech), pred]


static func _angry_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var pred := w.nm(ID) if w else Species.called(ID)
		return "Заражённый %s злее обычного и замечает корабль издалека" % pred


static func _clean_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var pred := w.nm(ID) if w else Species.called(ID)
		var leech := w.nm(EcoLeech.ID, Species.Case.GEN) if w else Species.called(EcoLeech.ID, Species.Case.GEN)
		return "%s на станции чистки: его очистили от %s" % [Species.cap(pred), leech]


## Каких светляков хищник не ловит: у станции чистки, в густом ленточнике (EcoKelp), в рифе гротовика (EcoGrot)
## и в чернилах подушечника (nearestFish пропускает nearStation, kelpShelter, grotShelter, inkAt).
## Внутри кольца REEF_KEEP рифа у цветка — тоже: хищник туда не заходит, и бросок за рыбкой не ведёт его внутрь
## (стая рифа (55; −69) живёт в кольце, #1400).
func _hidden_fish() -> Callable:
	var ink := cushions != null and cushions.any_ink()
	var truce := ognevka != null and leeches != null and not leeches.stations.is_empty()
	var grove := kelp != null and not kelp.groves.is_empty()
	var reef := grot != null and grot.shoal != null and grot.shoal.alarm > 0.0
	var crown := false  # стая в чаше кроны цветка (#834)
	if fish:
		for sh in fish.shoals:
			if sh.crown and sh.alarm > 0.0:
				crown = true
	var ring := _reef if _reef.is_finite() else Vector3.INF
	if not ink and not truce and not grove and not reef and not crown and not ring.is_finite():
		return Callable()
	return func(f: EcoFish.Fish) -> bool:
		return (ring.is_finite() and _flat_dist(f.agent.p, ring) < REEF_KEEP) \
			or (crown and f.shoal.crown and f.shoal.alarm > 0.0) or (truce and leeches.near_station(f.agent.p) != null) or (grove and kelp.shelter(f) != null) \
			or (reef and grot.shelter(f) != null) or (ink and _in_ink(f))


## Светляк в чернилах подушечника — хищник его не видит.
func _in_ink(f: EcoFish.Fish) -> bool:
	return cushions != null and cushions.ink_at(f.agent.p) != null


static func _catch_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var pred := w.nm(ID) if w else Species.called(ID)
		var prey := w.nm(EcoFish.ID, Species.Case.ACC) if w else Species.called(EcoFish.ID, Species.Case.ACC)
		return "%s поймал %s" % [Species.cap(pred), prey]
