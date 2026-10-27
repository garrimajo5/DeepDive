class_name EcoKrab
extends EcoSystem
## Кольчужник (initKelp — нора, crabUpdate, crabSpines в js/creatures.js; бестиарий): донный краб в каменной норе
## у края второй рощи ленточника. Голодный (голод растёт 1/30 в секунду) выходит к ближайшему живому шипоежу
## не дальше 16 м от норы, 3 с раскалывает его (EcoKelp.kill — ёж пропадает на 80…120 с, наблюдения «hunt»
## и «armor») и вплетает две иглы в панцирь (до 10), потом возвращается в нору. Потому возле норы ленточник
## остаётся густым. Корабль ближе 12 м к норе — краб встаёт у входа и поднимает клешни (наблюдение «guard»
## раз в 40 с), ближе 7 м — раз в 8 с зажимает корпус (EcoLink.HIT 0,03); дальше 14 м — уходит в нору.
## Скальник (EcoSkalnik) пугает краба — scared: не выходит на охоту и удирает в нору бегом.

const ID := "krab"
## Нора — у этой рощи ленточника (G2 − 1: вторая), отступ от края рощи наружу.
const GROVE := 1
const OUT := Vector3(1, 0, 0.4)
const DEN_PAD := 3.0
## Ищет ежей не дальше 16 м от норы (CRAB_R); игл на панцире — от 3 до 10 (SPINE_MAX), +2 за ежа.
const HUNT_R := 16.0
const SPINES_START := 3
const SPINE_MAX := 10
const SPINES_PER_MEAL := 2
## Голод: с 0,3, растёт 1/30 в секунду до 1,5; выходит на охоту, когда больше 1.
const HUNGER_START := 0.3
const HUNGER_RATE := 1.0 / 30.0
const HUNGER_MAX := 1.5
## Охота: идёт 0,9 м/с не дольше 60 с, раскалывает ближе 0,7 м за 3 с; съеденный ёж — снова через 80…120 с.
const HUNT_SPEED := 0.9
const HUNT_TIME := 60.0
const CRACK_DIST := 0.7
const CRACK_TIME := 3.0
const RESPAWN_MIN := 80.0
const RESPAWN_MAX := 120.0
## Поворот тела: доля угла 4/с, не быстрее 2,5 рад/с (EcoAgent.turn_flat) — не щёлкает при развороте к дому.
const TURN_K := 4.0
const TURN_MAX := 2.5
## Домой — 0,8 м/с (напуганный — 2), дома ближе 0,4 м.
const HOME_SPEED := 0.8
const SCARED_SPEED := 2.0
const HOME_DIST := 0.4
## Охрана: корабль ближе 12 м к норе — к входу 1,2 м/с, клешни вверх; щипок ближе 7 м раз в 8 с;
## уходит, когда корабль дальше 14 м; «guard» — раз в 40 с.
const GUARD_R := 12.0
const PINCH_R := 7.0
const LEAVE_R := 14.0
const GUARD_SPEED := 1.2
const PINCH_CD := 8.0
const PINCH_DAMAGE := 0.03
const GUARD_CD := 40.0

enum State { DEN, HUNT, CRACK, HOME, GUARD }


## Сам краб.
class Crab:
	extends RefCounted
	var den := Vector3.ZERO
	## Наружу от рощи (лицом из норы).
	var out := Vector3.FORWARD
	var pos := Vector3.ZERO
	var dir := Vector3.FORWARD
	var state := State.DEN
	var hunger := HUNGER_START
	## Ёж, на которого охотится (номер в EcoKelp.urchins; −1 — никто).
	var target := -1
	var timer := 0.0
	var spines := SPINES_START
	var guard_cd := 0.0
	var pinch_cd := 0.0
	## Поднятые клешни 0…1 (рисунок).
	var raise := 0.0
	## Напуган скальником, секунд.
	var scared := 0.0
	## Идёт в этот шаг (рисунок: подпрыгивает).
	var moving := false


## Краб; null — рощ нет, краба нет.
var crab: Crab
var kelp: EcoKelp
## Иглы на панцире поменялись — сцена перерисует (сбрасывает KrabView).
var dirty := true

var _rnd: EcoRandom


func _init(kelp_system: EcoKelp = null) -> void:
	kelp = kelp_system


static func seed_for(world_seed: int) -> int:
	return (world_seed * 37 + 4127) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	crab = null
	dirty = true
	if kelp == null or kelp.groves.is_empty():
		return
	var gr := kelp.groves[mini(GROVE, kelp.groves.size() - 1)]
	var out := OUT.normalized()
	var den := gr.center + out * (EcoKelp.KELP_R + DEN_PAD)
	den.y = _floor(world, den.x, den.z, gr.center.y)
	crab = Crab.new()
	crab.den = den
	crab.out = out
	crab.pos = den
	crab.dir = out


func step(world: EcoWorld, dt: float) -> void:
	var cr := crab
	if cr == null:
		return
	cr.hunger = minf(HUNGER_MAX, cr.hunger + dt * HUNGER_RATE)
	cr.timer -= dt
	cr.guard_cd -= dt
	cr.pinch_cd -= dt
	cr.scared = maxf(0.0, cr.scared - dt)
	var d_ship := world.ship.pos.distance_to(cr.den)
	var speed := 0.0
	var goal := Vector3.INF
	var raise := 0.0
	if d_ship < GUARD_R and cr.state != State.CRACK:
		cr.target = -1
		cr.state = State.GUARD
	match cr.state:
		State.DEN:
			if cr.hunger > 1.0 and cr.scared <= 0.0:
				var bd := HUNT_R
				for u in kelp.urchins:
					if not u.alive:
						continue
					var d := u.pos.distance_to(cr.den)
					if d < bd:
						bd = d
						cr.target = u.index
				if cr.target >= 0:
					cr.state = State.HUNT
					cr.timer = HUNT_TIME
		State.HUNT:
			var u := _prey()
			if u == null or cr.timer <= 0.0:
				cr.state = State.HOME
				cr.target = -1
			else:
				goal = u.pos
				speed = HUNT_SPEED
				if cr.pos.distance_to(u.pos) < CRACK_DIST:
					cr.state = State.CRACK
					cr.timer = CRACK_TIME
		State.CRACK:
			raise = 0.6 + sin(world.time * 14.0) * 0.3
			if cr.timer <= 0.0:
				var u := _prey()
				if u:
					kelp.kill(u, _rnd.range_f(RESPAWN_MIN, RESPAWN_MAX))
					cr.hunger = 0.0
					cr.spines = mini(SPINE_MAX, cr.spines + SPINES_PER_MEAL)
					dirty = true
					world.emit(ID, "hunt", cr.pos, _hunt_text(world))
					world.emit(ID, "armor", cr.pos, _armor_text(world))
				cr.state = State.HOME
				cr.target = -1
		State.HOME:
			goal = cr.den
			speed = SCARED_SPEED if cr.scared > 0.0 else HOME_SPEED
			if _flat_dist(cr.pos, cr.den) < HOME_DIST:
				cr.state = State.DEN
		State.GUARD:
			raise = 1.0
			if _flat_dist(cr.pos, cr.den) > HOME_DIST:
				goal = cr.den
			speed = GUARD_SPEED
			var to_ship := Vector3(world.ship.pos.x - cr.pos.x, 0.0, world.ship.pos.z - cr.pos.z)
			if to_ship.length_squared() > 0.01:
				cr.dir = EcoAgent.turn_flat(cr.dir, to_ship, dt, TURN_K, TURN_MAX)
			if cr.guard_cd <= 0.0:
				cr.guard_cd = GUARD_CD
				world.emit(ID, "guard", cr.pos, _guard_text(world, false))
			if d_ship < PINCH_R and cr.pinch_cd <= 0.0:
				cr.pinch_cd = PINCH_CD
				world.hit_ship(Species.cap(world.nm(ID)), PINCH_DAMAGE, cr.pos)
				world.emit(ID, "guard", cr.pos, _guard_text(world, true))
			if d_ship > LEAVE_R:
				cr.state = State.HOME
	cr.moving = goal != Vector3.INF
	if cr.state == State.DEN:
		cr.dir = EcoAgent.turn_flat(cr.dir, cr.out, dt, TURN_K, TURN_MAX)   # в норе — лицом наружу, доворотом
	if cr.moving:
		var to := Vector3(goal.x - cr.pos.x, 0.0, goal.z - cr.pos.z)
		var dist := to.length()
		if dist > 0.05:
			cr.pos += to * (minf(dist, speed * dt) / dist)
			if cr.state != State.GUARD:
				cr.dir = EcoAgent.turn_flat(cr.dir, to, dt, TURN_K, TURN_MAX)
			cr.pos.y = _floor(world, cr.pos.x, cr.pos.z, cr.pos.y)   # стоящему — дно то же (issue #133)
	cr.raise += (raise - cr.raise) * minf(1.0, dt * 5.0)


## Кольчужник виден сонару и сканеру (E.scanTargets: r 0,9).
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	if crab:
		out.append(EcoWorld.target(ID, crab.pos, 0.9))


## Напугать краба на seconds секунд (скальник): бросает охоту (и недоколотого ежа) и удирает в нору.
func scare(seconds: float) -> void:
	if crab == null:
		return
	crab.scared = maxf(crab.scared, seconds)
	if crab.state == State.HUNT or crab.state == State.CRACK:
		crab.state = State.HOME
		crab.target = -1


func _prey() -> EcoKelp.Urchin:
	var cr := crab
	if cr.target < 0 or cr.target >= kelp.urchins.size():
		return null
	var u := kelp.urchins[cr.target]
	return u if u.alive else null


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


## Тексты собираются в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой.
static func _hunt_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var krab := w.nm(ID) if w else Species.called(ID)
		var ezh := w.nm(EcoKelp.ID, Species.Case.ACC) if w else Species.called(EcoKelp.ID, Species.Case.ACC)
		return "%s расколол %s" % [Species.cap(krab), ezh]


static func _armor_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var krab := w.nm(ID) if w else Species.called(ID)
		var ezh := w.nm(EcoKelp.ID, Species.Case.GEN) if w else Species.called(EcoKelp.ID, Species.Case.GEN)
		return "%s вплетает иглы %s в панцирь" % [Species.cap(krab), ezh]


static func _guard_text(world: EcoWorld, pinch: bool) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var krab := Species.cap(w.nm(ID) if w else Species.called(ID))
		if pinch:
			return "%s зажал корпус клешнёй" % krab
		return "%s поднял клешни: корабль слишком близко к норе" % krab
