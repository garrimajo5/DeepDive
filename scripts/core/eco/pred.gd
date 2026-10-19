class_name EcoPred
extends EcoSystem
## Серпохвосты — крупные хищники рифа (initPreds/predUpdate в js/creatures.js, Unity `Core/EcoPred.cs`). Три хищника
## на местах из браузера патрулируют отмель, чаще у стай светляков. Голод растёт на 0,03 в секунду; голоднее 0,45 —
## охота на ближайшего светляка не дальше 50 м (7,6 м/с, 12 с), поймал ближе 1,6 м — рыбка съедена (EcoFish.kill),
## событие «catch», 5 с ест.
## Корабль манит: прожектор или сонар (последние 12 с) ближе 32 м, шум двигателей быстрее 3 м/с ближе 24 м. Голоднее 0,2
## и без паузы — бросок на корабль (9,5 м/с, до 10 с) с событием «ship», «ping» или «hear». Ближе 8,5 м к кораблю — укус:
## EcoLink.HIT с уроном 0,12 (что он делает с кораблём — решает корабль), хищник уходит на 60 м и 25 с не нападает.
## Сонар (ShipState.sonar_ping → on_ping) зовёт хищников ближе 150 м проверить звук, разряд (ShipState.zap → on_zap)
## отпугивает тех, кто ближе радиуса разряда. Пиявники, станции чистки, вуали и укрытия стай придут со своими видами.

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

## Режим хищника (pr.state в браузере); общее EcoAgent.State — у его существа.
enum Mode { PATROL, HUNT, EAT, INVESTIGATE, CHARGE, RETREAT, FLEE }


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


var all: Array[Pred] = []
## Светляки, на которых охотится; null — охотиться не на кого.
var fish: EcoFish

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


func step(world: EcoWorld, dt: float) -> void:
	for pr in all:
		_step_pred(world, pr, dt)


static func _set_mode(pr: Pred, m: Mode, t: float) -> void:
	pr.mode = m
	pr.agent.timer = t
	match m:
		Mode.HUNT, Mode.CHARGE:
			pr.agent.state = EcoAgent.State.HUNT
		Mode.INVESTIGATE:
			pr.agent.state = EcoAgent.State.SEEK
		Mode.RETREAT, Mode.FLEE:
			pr.agent.state = EcoAgent.State.FLEE
		_:
			pr.agent.state = EcoAgent.State.GRAZE


## Манит ли корабль: свет или недавний сонар ближе 32 м, шум двигателей ближе 24 м.
static func lured(world: EcoWorld, d_ship: float) -> bool:
	var s := world.ship
	var seen := d_ship < REACH and (s.light_on or world.time - world.last_ping < PING_MEMORY)
	var heard := d_ship < HEAR_RADIUS and absf(s.speed) > HEAR_SPEED
	return seen or heard


## Текст события собирается в момент показа (вид мог быть уже просканирован). Мир — слабой ссылкой и без self:
## событие лежит в шине мира, сильная ссылка замкнула бы круг. fmt — с одним %s для названия хищника.
static func _text(world: EcoWorld, fmt: String, c: Species.Case = Species.Case.NOM, cap := true) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID, c) if w else Species.called(ID, c)
		return fmt % (Species.cap(name) if cap else name)


func _start_charge(world: EcoWorld, pr: Pred) -> void:
	_set_mode(pr, Mode.CHARGE, 10.0)
	pr.prey = null
	var at := pr.agent.p
	if world.ship.light_on:
		world.emit(ID, "ship", at, _text(world, "%s разворачивается к кораблю — его привлёк свет"))
	elif world.time - world.last_ping < PING_MEMORY:
		world.emit(ID, "ping", at, _text(world, "%s разворачивается к кораблю — его привлёк сонар"))
	else:
		world.emit(ID, "hear", at, _text(world, "%s услышал двигатели и разворачивается к кораблю"))


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


func _step_pred(world: EcoWorld, pr: Pred, dt: float) -> void:
	var a := pr.agent
	pr.hunger = minf(1.0, pr.hunger + dt * HUNGER_RATE)
	pr.cooldown -= dt
	var ship := world.ship.pos
	var d_ship := a.distance_to(ship)
	var can_attack := pr.cooldown <= 0.0 and pr.hunger > ATTACK_HUNGER and lured(world, d_ship)

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
			if pr.hunger > HUNT_HUNGER and fish:
				var f := fish.nearest_fish(a.p, HUNT_RADIUS)
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
			else:
				a.goal = pr.prey.agent.p + pr.prey.agent.v * 0.4
				if a.distance_to(pr.prey.agent.p) < CATCH_DIST:
					fish.kill(pr.prey)
					pr.hunger = 0.0
					pr.prey = null
					_set_mode(pr, Mode.EAT, 5.0)
					world.emit(ID, "catch", a.p, _catch_text(world))
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
			if d_ship < BITE_DIST:
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

	# прямо к цели с постоянной скоростью; в охоте и броске поворачивает резче
	var d := a.goal - a.p
	var want := d.normalized() * speed if d.length_squared() > 1e-4 else d
	a.agility = 1.6 if pr.mode == Mode.HUNT or pr.mode == Mode.CHARGE else 1.1
	a.drive(want, dt, world.ground)


static func _catch_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var pred := w.nm(ID) if w else Species.called(ID)
		var prey := w.nm(EcoFish.ID, Species.Case.ACC) if w else Species.called(EcoFish.ID, Species.Case.ACC)
		return "%s поймал %s" % [Species.cap(pred), prey]
