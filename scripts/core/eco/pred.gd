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

## Режим хищника (pr.state в браузере); общее EcoAgent.State — у его существа.
enum Mode { PATROL, HUNT, EAT, INVESTIGATE, CHARGE, RETREAT, FLEE, CLEAN }


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


var all: Array[Pred] = []
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


func _init(prey_fish: EcoFish = null) -> void:
	fish = prey_fish


## Своё зерно серпохвостов.
static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7004) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	all.clear()
	for i in STARTS.size():
		var x := STARTS[i].x
		var z := STARTS[i].y
		var y := minf(float(world.ground.call(x, z)) + 8.0, GOAL_CEILING) if world.ground.is_valid() else GOAL_CEILING
		var p := Vector3(x, y, z)
		var a := world.spawn(ID, p)
		a.v = Vector3(0, 0, 1)
		a.set_state(EcoAgent.State.GRAZE)
		var pr := Pred.new()
		pr.agent = a
		pr.index = i
		pr.hunger = _rnd.range_f(0.1, 0.5)
		pr.cooldown = 20.0
		pr.start = p
		all.append(pr)


## Импульс сонара из точки pos (E.onPing): хищники ближе 150 м плывут проверить звук.
func on_ping(world: EcoWorld, pos: Vector3) -> void:
	world.last_ping = world.time
	var heard := false
	for pr in all:
		if pr.mode == Mode.CHARGE or pr.mode == Mode.RETREAT or pr.mode == Mode.FLEE:
			continue
		var d := pr.agent.distance_to(pos)
		if d >= PING_CALL:
			continue
		_set_mode(pr, Mode.INVESTIGATE, 25.0)
		pr.prey = null
		pr.agent.goal = pos
		if d < PING_HEARD:
			heard = true
	if heard:
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
		var away := a.p - c
		if away.length_squared() < 0.01:
			away = Vector3(1, 0, 0)
		var g := a.p + away.normalized() * 50.0
		g.y = minf(g.y, GOAL_CEILING)
		a.goal = g
		world.emit(ID, "zap", a.p, _text(world, "Разряд отпугнул %s", Species.Case.ACC, false))


## Каждый серпохвост виден сонару и сканеру.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for pr in all:
		if pr.agent.alive:
			out.append(EcoWorld.target(ID, pr.agent.p, 2.5))


func step(world: EcoWorld, dt: float) -> void:
	for pr in all:
		_step_pred(world, pr, dt)


static func _set_mode(pr: Pred, m: Mode, t: float) -> void:
	pr.mode = m
	pr.agent.timer = t
	match m:
		Mode.HUNT, Mode.CHARGE:
			pr.agent.state = EcoAgent.State.HUNT
		Mode.INVESTIGATE, Mode.CLEAN:
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


## Слышит ли двигатели корабля (hearsShip): ближе 24 м и быстрее 3 м/с, если корабль не в гуле трубного органа.
## Гул спрятал корабль от патрулирующего или проверяющего звук хищника — наблюдение органа «mask».
func hears_ship(world: EcoWorld, pr: Pred, d_ship: float) -> bool:
	if d_ship >= HEAR_RADIUS or absf(world.ship.speed) <= HEAR_SPEED:
		return false
	if organs:
		var og := organs.masking(world)
		if og:
			organs.masked(world, og, pr.mode == Mode.PATROL or pr.mode == Mode.INVESTIGATE)
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


func _start_charge(world: EcoWorld, pr: Pred) -> void:
	_set_mode(pr, Mode.CHARGE, 10.0)
	pr.prey = null
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
	var ship := world.ship.pos
	var d_ship := a.distance_to(ship)
	var at_station := leeches.near_station(a.p) != null if leeches else false
	var lure := lured(world, pr, d_ship)  # и голодного, и сытого: гул органа прячет корабль от каждого
	var sheltered := ship_sheltered(world)
	var can_attack := pr.cooldown <= 0.0 and pr.hunger > (EcoLeech.ATTACK_HUNGER if pr.leech else ATTACK_HUNGER) \
		and lure and not at_station and not sheltered
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
				if fish and fish.shoals.size() > 0 and _rnd.chance(0.6):
					var h: Vector3 = (_rnd.pick(fish.shoals) as EcoFish.Shoal).home
					gx = h.x + _rnd.range_f(-25, 25)
					gz = h.z + _rnd.range_f(-25, 25)
				else:
					gx = _rnd.range_f(-170, 150)
					gz = _rnd.range_f(-170, 150)
				var gy := minf(_floor(world, gx, gz, GOAL_CEILING - 14.0) + _rnd.range_f(4, 14), GOAL_CEILING)
				a.goal = Vector3(gx, gy, gz)
			if pr.hunger > HUNT_HUNGER and fish and not at_station:
				var f := fish.nearest_fish(a.p, HUNT_RADIUS, _hidden_fish())
				if f:
					_set_mode(pr, Mode.HUNT, 12.0)
					pr.prey = f
			if can_attack:
				_start_charge(world, pr)

		Mode.HUNT:
			speed = HUNT_SPEED
			if pr.prey == null or not pr.prey.agent.alive or a.expired():
				_set_mode(pr, Mode.PATROL, 0.0)
				pr.prey = null
			elif ognevka and (at_station or leeches.near_station(pr.prey.agent.p)):  # у станции чистки перемирие
				_set_mode(pr, Mode.PATROL, _rnd.range_f(4, 8))
				pr.prey = null
				if pr.truce_cd <= 0.0:
					pr.truce_cd = EcoOgnevka.TRUCE_CD
					ognevka.truce(world, a.p)
			else:
				var gr := kelp.shelter(pr.prey) if kelp else null
				var cu := cushions.ink_at(pr.prey.agent.p) if cushions and gr == null else null
				var gt := grot.shelter(pr.prey) if grot and gr == null and cu == null else null
				if gr:  # стая нырнула в густой ленточник
					_set_mode(pr, Mode.PATROL, _rnd.range_f(4, 8))
					pr.prey = null
					kelp.hid_fish(world, gr)
				elif cu:  # светляк скрылся в чернилах подушечника
					_set_mode(pr, Mode.PATROL, _rnd.range_f(4, 8))
					pr.prey = null
					cushions.hid_fish(world, cu)
				elif gt:  # стая нырнула в риф на спине гротовика
					_set_mode(pr, Mode.PATROL, _rnd.range_f(4, 8))
					pr.prey = null
					grot.hid_fish(world)
				else:
					a.goal = pr.prey.agent.p + pr.prey.agent.v * 0.4
					if a.distance_to(pr.prey.agent.p) < CATCH_DIST:
						var caught := pr.prey.agent.p
						fish.kill(pr.prey)
						pr.hunger = 0.0
						pr.prey = null
						_set_mode(pr, Mode.EAT, 5.0)
						world.emit(ID, "catch", a.p, _catch_text(world))
						if kelp:
							kelp.caught_at(world, caught)
					elif can_attack and pr.hunger > HUNT_TO_SHIP_HUNGER:
						_start_charge(world, pr)

		Mode.EAT:
			speed = EAT_SPEED
			if a.expired():
				_set_mode(pr, Mode.PATROL, 0.0)

		Mode.INVESTIGATE:
			speed = INVESTIGATE_SPEED
			if a.distance_to(a.goal) < 10.0 or a.expired():
				_set_mode(pr, Mode.PATROL, 0.0)
			if can_attack:
				_start_charge(world, pr)

		Mode.CHARGE:
			speed = CHARGE_SPEED
			a.goal = ship
			if sheltered:  # корабль у станции чистки — хищник отворачивает
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
				world.hit_ship(Species.cap(world.nm(ID)), BITE_DAMAGE, a.p)
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
			if a.expired():
				_set_mode(pr, Mode.PATROL, 0.0)

		Mode.CLEAN:
			speed = _step_clean(world, pr, dt)
			if pr.mode == Mode.CLEAN and can_attack and pr.hunger > HUNT_TO_SHIP_HUNGER:
				_start_charge(world, pr)

	if pr.leech and pr.mode != Mode.CLEAN:
		speed *= EcoLeech.SLOW  # пиявник замедляет хищника

	# прямо к цели с постоянной скоростью; в охоте и броске поворачивает резче
	var d := a.goal - a.p
	var want := d.normalized() * speed if d.length_squared() > 1e-4 else d
	if veils:  # фонарные вуали обходит стороной
		var push := veils.pred_push(a.p)
		if push != Vector3.ZERO:
			want += push
			if pr.avoid_cd <= 0.0:
				pr.avoid_cd = EcoVeil.AVOID_CD
				veils.avoided(world, a.p)
	a.agility = 1.6 if pr.mode == Mode.HUNT or pr.mode == Mode.CHARGE else 1.1
	a.drive(want, dt, world.ground)
	world.push_out(a, HULL_GAP) # корпус не пускает внутрь


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
func _hidden_fish() -> Callable:
	var ink := cushions != null and cushions.any_ink()
	var truce := ognevka != null and leeches != null and not leeches.stations.is_empty()
	var grove := kelp != null and not kelp.groves.is_empty()
	var reef := grot != null and grot.shoal != null and grot.shoal.alarm > 0.0
	if not ink and not truce and not grove and not reef:
		return Callable()
	return func(f: EcoFish.Fish) -> bool:
		return (truce and leeches.near_station(f.agent.p) != null) or (grove and kelp.shelter(f) != null) \
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
