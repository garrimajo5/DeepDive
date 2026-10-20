class_name EcoSkalnik
extends EcoSystem
## Скальник (initSkalnik, skUpdate в js/creatures.js; бестиарий): рогатый спрут у норы кольчужника, в 7 м сбоку
## от неё. Неподвижный — неотличим от камня: сонар и прицел сканера его не берут. В луче прожектора меняет цвет
## и выдаёт себя на 6 с (наблюдение «mimic» раз в 40 с). Подстерегает кольчужника, вышедшего на охоту дальше
## 2,5 м от норы: краба с бедным панцирем (меньше 7 игл) загоняет в нору бегом («hunt», EcoKrab.scare 6 с),
## от краба в броне отступает («armor»); снова — через 60 с. Любопытен: к неподвижному кораблю с погашенным
## светом ближе 25 м подплывает к самому стеклу («curious», раз в 60 с), свет или ход больше 1,5 м/с спугивают.
## Кража образцов с манипулятора («thief», «drop») — следующая подзадача, со связью с кораблём через EcoLink.

const ID := "skalnik"
## Дом — сбоку от норы кольчужника на 7 м (поперёк выхода из норы).
const SIDE := 7.0
## Броня краба, от которой отступает (SK_ARMOR); краб должен уйти от норы дальше 2,5 м.
const ARMOR := 7
const CRAB_AWAY := 2.5
## Подстерегает не дольше 30 с, 1,6 м/с, бросается ближе 1,4 м; после броска — 60 с покоя, на старте — 20.
const STALK_TIME := 30.0
const STALK_SPEED := 1.6
const POUNCE := 1.4
const COOLDOWN := 60.0
const COOLDOWN_START := 20.0
const SCARE := 6.0
## Любопытство: корабль тише 0,5 м/с без света, нос ближе 25 м к дому; 14 с, 1,2 м/с, снова через 60 с.
## Цель — 2,6 м перед стеклом носа и на 0,8 м ниже; спугнут свет или ход быстрее 1,5 м/с.
const CURIOUS_R := 25.0
const CURIOUS_TIME := 14.0
const CURIOUS_SPEED := 1.2
const CURIOUS_CD := 60.0
const STILL_SPEED := 0.5
const SPOOK_SPEED := 1.5
const GLASS_AHEAD := 2.6
const GLASS_DOWN := 0.8
## Домой 1,8 м/с, дома ближе 0,5 м.
const BACK_SPEED := 1.8
const HOME_DIST := 0.5
## В луче — показывает себя 6 с, сообщение «mimic» раз в 40 с, если был почти невидим (camo > 0,6).
const REVEAL := 6.0
const SPOOKED := 4.0
const MIMIC_CD := 40.0
## Размер для обхода корпуса и прицела.
const PAD := 0.5
const R := 1.0

enum State { ROCK, STALK, CURIOUS, BACK }


## Сам скальник.
class Octo:
	extends RefCounted
	var home := Vector3.ZERO
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var dir := Vector3.FORWARD
	var state := State.ROCK
	var timer := 0.0
	var cd := COOLDOWN_START
	var cur_cd := 0.0
	## Маскировка 1 — камень, 0 — живая кожа (рисунок и сонар).
	var camo := 1.0
	var reveal := 0.0
	var lit := false
	var mimic_cd := 0.0
	## Уже сообщил, что разглядывает корабль (в этот раз).
	var seen := false


## Скальник; null — кольчужника нет.
var octo: Octo
var krab: EcoKrab
## Дно мира (щупальца ложатся на него в рисунке).
var ground: Callable


func _init(krab_system: EcoKrab = null) -> void:
	krab = krab_system


func reset(world: EcoWorld) -> void:
	octo = null
	ground = world.ground
	if krab == null or krab.crab == null:
		return
	var cr := krab.crab
	var side := Vector3(-cr.out.z, 0.0, cr.out.x)
	var home := cr.den + side * SIDE
	home.y = EcoKrab._floor(world, home.x, home.z, cr.den.y)
	octo = Octo.new()
	octo.home = home
	octo.pos = home
	octo.dir = -cr.out


## Неподвижный корабль с погашенным светом (still в skUpdate).
static func ship_still(s: EcoLink.ShipState) -> bool:
	return absf(s.speed) < STILL_SPEED and not s.light_on


## Куда подплывает любопытный: перед стеклом носа.
static func glass_goal(s: EcoLink.ShipState) -> Vector3:
	return EcoEel.front(s) + s.nose() * GLASS_AHEAD + Vector3(0, -GLASS_DOWN, 0)


## Замаскирован: ни сонар, ни прицел его не берут.
func hidden() -> bool:
	return octo != null and octo.camo >= 0.5


func step(world: EcoWorld, dt: float) -> void:
	var sk := octo
	if sk == null:
		return
	var s := world.ship
	var cr := krab.crab
	sk.timer -= dt
	sk.cd -= dt
	sk.cur_cd -= dt
	sk.reveal -= dt
	sk.mimic_cd -= dt
	var was_lit := sk.lit
	sk.lit = world.in_beam(sk.pos + Vector3(0, 0.5, 0))
	if sk.lit and not was_lit and sk.camo > 0.6:
		sk.reveal = REVEAL
		if sk.mimic_cd <= 0.0:
			sk.mimic_cd = MIMIC_CD
			world.emit(ID, "mimic", sk.pos, _mimic_text(world))
	var speed := 0.0
	var goal := sk.home
	match sk.state:
		State.ROCK:
			if sk.cd <= 0.0 and _crab_out(cr):
				sk.state = State.STALK
				sk.timer = STALK_TIME
			elif sk.cur_cd <= 0.0 and ship_still(s) and EcoEel.front(s).distance_to(sk.home) < CURIOUS_R:
				sk.state = State.CURIOUS
				sk.timer = CURIOUS_TIME
				sk.cur_cd = CURIOUS_CD
		State.STALK:
			speed = STALK_SPEED
			if sk.timer <= 0.0 or not _crab_hunting(cr):
				sk.state = State.BACK
			else:
				goal = cr.pos
				if Vector2(sk.pos.x - cr.pos.x, sk.pos.z - cr.pos.z).length() < POUNCE:
					if cr.spines >= ARMOR:
						world.emit(ID, "armor", cr.pos, _armor_text(world))
					else:
						krab.scare(SCARE)
						world.emit(ID, "hunt", cr.pos, _hunt_text(world))
					sk.state = State.BACK
					sk.cd = COOLDOWN
		State.CURIOUS:
			speed = CURIOUS_SPEED
			goal = glass_goal(s)
			if sk.pos.distance_to(goal) < 1.0 and sk.timer < CURIOUS_TIME - 3.0 and not sk.seen:
				sk.seen = true
				world.emit(ID, "curious", sk.pos, _curious_text(world))
			if s.light_on or absf(s.speed) > SPOOK_SPEED:
				sk.state = State.BACK
				sk.reveal = SPOOKED
				speed = 0.0
			elif sk.timer <= 0.0:
				sk.state = State.BACK
		State.BACK:
			speed = BACK_SPEED
			sk.seen = false
			if sk.pos.distance_to(sk.home) < HOME_DIST:
				sk.state = State.ROCK
				sk.pos = sk.home
	if speed > 0.0:
		var to := EcoHull.detour(sk.pos, goal, s.pos, s.yaw, PAD) - sk.pos
		var d := to.length()
		if d > 0.05:
			sk.vel = to * (minf(speed, d * 2.0) / d)
			sk.pos += sk.vel * dt
			var flat := Vector3(sk.vel.x, 0.0, sk.vel.z)
			if flat.length_squared() > 1e-4:
				sk.dir = sk.dir.lerp(flat.normalized(), minf(1.0, dt * 3.0)).normalized()
		else:
			sk.vel = Vector3.ZERO
		var res := EcoHull.push_out(sk.pos, s.pos, s.yaw, PAD)
		if not res.is_empty():
			sk.pos = res[0]
			var n: Vector3 = res[1]
			var vn := sk.vel.dot(n)
			if vn < 0.0:
				sk.vel -= n * vn
		var h := EcoKrab._floor(world, sk.pos.x, sk.pos.z, sk.home.y)
		if sk.pos.y < h:
			sk.pos.y = h
		if sk.state == State.STALK or sk.state == State.BACK:
			sk.pos.y = maxf(h, sk.pos.y + (h + 0.2 - sk.pos.y) * minf(1.0, dt * 3.0))
	else:
		sk.vel = Vector3.ZERO
	var want := 1.0 if sk.state == State.ROCK and sk.reveal <= 0.0 else 0.0
	sk.camo += (want - sk.camo) * minf(1.0, dt * (0.5 if want > 0.0 else 4.0))


## Замаскированного нет ни на сонаре, ни в прицеле (E.scanTargets: hidden и noSonar).
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	if octo:
		var h := hidden()
		out.append(EcoWorld.target(ID, octo.pos, R, not h, h))


static func _crab_hunting(cr: EcoKrab.Crab) -> bool:
	return cr != null and (cr.state == EcoKrab.State.HUNT or cr.state == EcoKrab.State.CRACK)


static func _crab_out(cr: EcoKrab.Crab) -> bool:
	return _crab_hunting(cr) and cr.pos.distance_to(cr.den) > CRAB_AWAY


## Тексты собираются в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой.
static func _mimic_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		if w != null and w.scanned.is_valid() and bool(w.scanned.call(ID)):
			return "Скальник в луче прожектора сбросил маскировку"
		return "Камень в луче прожектора меняет цвет — это живое существо"


static func _hunt_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var sk := w.nm(ID) if w else Species.called(ID)
		var kr := w.nm(EcoKrab.ID, Species.Case.ACC) if w else Species.called(EcoKrab.ID, Species.Case.ACC)
		return "%s набросился на %s — тот удирает в нору" % [Species.cap(sk), kr]


static func _armor_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var sk := w.nm(ID) if w else Species.called(ID)
		var kr := w.nm(EcoKrab.ID, Species.Case.GEN) if w else Species.called(EcoKrab.ID, Species.Case.GEN)
		return "%s отступает: панцирь %s весь в иглах" % [Species.cap(sk), kr]


static func _curious_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var sk := w.nm(ID) if w else Species.called(ID)
		return "%s подплыл к самому стеклу и разглядывает корабль" % Species.cap(sk)
