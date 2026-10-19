class_name EcoFish
extends EcoSystem
## Светляки-полосники (initFish/updateFish в js/creatures.js, Unity `Core/EcoFish.cs`): шесть стай по 22 рыбки у кораллов
## рифа. Стая бродит у дома, держится вместе (к центру, в ногу, не толкаясь), рыбки не опускаются на дно и не поднимаются
## ко льду. Серпохвост ближе 16 м — тревога: стая уходит к дому в кораллы и там прячется (медленно, ≤ 1 м/с), событие
## «flee» раз в 30 с. Корабль ближе 11 м на ходу быстрее 1,2 м/с пугает без события: рыбки шарахаются, но домой не уходят.
## Хищники берут рыбок через nearest_fish и kill; съеденная появляется у дома через 25–40 с.

const ID := "fish"
## Рыбок в стае.
const PER_SHOAL := 22
## Ближе этого хищник поднимает тревогу (м).
const PRED_ALARM := 16.0
## Ближе этого корабль на ходу пугает стаю (м).
const SHIP_ALARM := 11.0
## Быстрее этого корабль пугает (м/с, вперёд или назад).
const SHIP_FAST := 1.2
## Пауза между сообщениями «стая уходит» (с).
const FLEE_COOLDOWN := 30.0
## Скорости: прячется у дома, в тревоге, спокойно; не медленнее MIN_SPEED.
const HIDE_SPEED := 1.0
const ALARM_SPEED := 6.5
const CALM_SPEED := 2.4
const MIN_SPEED := 0.5

## Дома стай: шесть мест кораллов (W.coralSpots), ближайших к (0, 55) и разнесённых больше чем на 35 м, плюс 1,5 м
## вверх — числа браузерной версии (в Unity x со знаком минус). Дом на 3,5 м над дном (Seabed.height).
## Шестую стаю в браузере уносит на спине гротовик — он придёт своей задачей и поменяет ей home и range_m.
const HOMES: Array[Vector3] = [
	Vector3(15.3753, -33.0888, 75.9897),
	Vector3(-26.4205, -40.8460, 24.4689),
	Vector3(-63.3665, -35.1576, 80.4209),
	Vector3(38.0868, -27.2991, 115.9097),
	Vector3(56.1066, -36.3559, 6.1835),
	Vector3(76.8304, -31.1474, 52.3365),
]

## Цвет полос стаи: по концепту ART-011 стаи светятся в голубой гамме (#67DDEB, #6FE3FF и близкие оттенки).
## У каждой рыбки своя яркость Fish.bright.
const COLORS: Array[Color] = [
	Color("67DDEB"), Color("6FE3FF"), Color("5EF2D6"), Color("7FE7FF"), Color("8FD0FF"), Color("4FD8E8"),
]


## Стая.
class Shoal:
	extends RefCounted
	var index := 0
	var home := Vector3.ZERO
	var goal := Vector3.ZERO
	var center := Vector3.ZERO
	var velocity := Vector3.ZERO
	## Радиус блуждания вокруг дома (м).
	var range_m := 14.0
	## Секунды тревоги (стая уходит домой или шарахается).
	var alarm := 0.0
	var flee_cd := 0.0
	var goal_timer := 0.0
	## Сколько рыбок живо.
	var alive := 0
	## От чего шарахается сейчас (has_threat — есть ли угроза).
	var has_threat := false
	var threat := Vector3.ZERO
	## Угроза — корабль, а не хищник: домой не уходят.
	var threat_is_ship := false
	var color := Color.WHITE
	var members: Array = []  ## Array[Fish]


## Рыбка: существо мира и её место в стае.
class Fish:
	extends RefCounted
	var agent: EcoAgent
	## Стая — слабая ссылка: стая держит рыбок, рыбка смотрит на стаю (без цикла RefCounted).
	var shoal: Shoal:
		get:
			return _shoal.get_ref() if _shoal else null
		set(value):
			_shoal = weakref(value) if value else null
	## Номер среди всех рыбок (место в MultiMesh).
	var index := 0
	## Фаза покачивания.
	var phase := 0.0
	## Яркость цвета стаи, 0,75–1,15.
	var bright := 1.0
	var _shoal: WeakRef


var shoals: Array[Shoal] = []
var all: Array[Fish] = []

var _rnd: EcoRandom


## Своё зерно стай: от зерна мира, чтобы другой мир был другим, а остальные виды не сдвигались.
static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7001) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	shoals.clear()
	all.clear()
	for si in HOMES.size():
		var h := HOMES[si]
		var sh := Shoal.new()
		sh.index = si
		sh.home = h
		sh.goal = h
		sh.center = h
		sh.color = COLORS[si % COLORS.size()]
		shoals.append(sh)
		for k in PER_SHOAL:
			var p := h + Vector3(_rnd.range_f(-3, 3), _rnd.range_f(0, 3), _rnd.range_f(-3, 3))
			var a := world.spawn(ID, p)
			a.home = h
			a.clearance = 0.4
			a.v = Vector3(_rnd.range_f(-1, 1), 0, _rnd.range_f(-1, 1))
			var f := Fish.new()
			f.agent = a
			f.shoal = sh
			f.index = all.size()
			f.phase = _rnd.range_f(0, 6)
			f.bright = _rnd.range_f(0.75, 1.15)
			all.append(f)
			sh.members.append(f)
		sh.alive = PER_SHOAL


## Съесть рыбку: пропадает на 25–40 с, потом появляется у дома стаи.
func kill(f: Fish) -> void:
	if not f.agent.alive:
		return
	f.agent.alive = false
	f.agent.v = Vector3.ZERO
	f.agent.timer = _rnd.range_f(25, 40)


## Ближайшая живая рыбка не дальше radius; skip — (Fish) -> bool, кого не видно (в укрытии). null — никого.
func nearest_fish(pos: Vector3, radius: float, skip: Callable = Callable()) -> Fish:
	var best: Fish = null
	var bd := radius
	for f in all:
		if not f.agent.alive or (skip.is_valid() and skip.call(f)):
			continue
		var d := f.agent.p.distance_to(pos)
		if d < bd:
			bd = d
			best = f
	return best


func step(world: EcoWorld, dt: float) -> void:
	for sh in shoals:
		_step_shoal(world, sh, dt)
	var t := world.time
	for f in all:
		_step_fish(world, f, dt, t)


func _step_shoal(world: EcoWorld, sh: Shoal, dt: float) -> void:
	var c := Vector3.ZERO
	var v := Vector3.ZERO
	var n := 0
	for f: Fish in sh.members:
		if f.agent.alive:
			c += f.agent.p
			v += f.agent.v
			n += 1
	sh.alive = n
	if n > 0:
		sh.center = c / n
		sh.velocity = v / n
	else:
		sh.center = sh.home
		sh.velocity = Vector3.ZERO
	sh.alarm = maxf(0.0, sh.alarm - dt)
	sh.flee_cd -= dt
	sh.goal_timer -= dt

	if sh.goal_timer <= 0.0:
		sh.goal_timer = _rnd.range_f(6, 12)
		var r := sh.range_m
		var gx := sh.home.x + _rnd.range_f(-r, r)
		var gz := sh.home.z + _rnd.range_f(-r, r)
		var lift := _rnd.range_f(2, 7)
		var gy: float = world.ground.call(gx, gz) if world.ground.is_valid() else sh.home.y - 3.5
		sh.goal = Vector3(gx, minf(gy + lift, -4.0), gz)

	sh.has_threat = false
	sh.threat_is_ship = false
	var best := PRED_ALARM
	for a in world.agents:
		if not a.alive or a.species != "pred":
			continue
		var d := a.p.distance_to(sh.center)
		if d < best:
			best = d
			sh.has_threat = true
			sh.threat = a.p
	if sh.has_threat:
		if sh.alarm <= 0.0 and sh.flee_cd <= 0.0:
			sh.flee_cd = FLEE_COOLDOWN
			world.emit(ID, "flee", sh.center, _flee_text(world))
		sh.alarm = 3.0
	elif world.ship.pos.distance_to(sh.center) < SHIP_ALARM and absf(world.ship.speed) > SHIP_FAST:
		sh.has_threat = true
		sh.threat = world.ship.pos
		sh.threat_is_ship = true
		sh.alarm = maxf(sh.alarm, 1.5)


## Текст «стая уходит» собирается в момент показа (вид мог быть уже просканирован). Мир — слабой ссылкой
## и без self: событие лежит в шине мира, сильная ссылка замкнула бы круг и мир не освободился бы.
static func _flee_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID) if w else Species.called(ID)
		return "%s: стая уходит в кораллы — рядом хищник" % Species.cap(name)


func _step_fish(world: EcoWorld, f: Fish, dt: float, t: float) -> void:
	var a := f.agent
	var sh := f.shoal
	if not a.alive:
		if a.timer > 0.0:
			return
		a.alive = true
		a.p = sh.home + Vector3(_rnd.range_f(-2, 2), _rnd.range_f(0, 2), _rnd.range_f(-2, 2))
		a.v = Vector3(0, 0.2, 0)
	var alarm := sh.alarm > 0.0
	var acc := (sh.center - a.p) * 0.5 + (sh.velocity - a.v) * 0.6
	var goal := sh.home if alarm and not sh.threat_is_ship else sh.goal
	acc += (goal - a.p).limit_length(8.0) * (1.2 if alarm else 0.35)
	for o: Fish in sh.members:
		if o == f or not o.agent.alive:
			continue
		var dp := a.p - o.agent.p
		var d2 := dp.length_squared()
		if d2 < 0.6 and d2 > 1e-5:
			acc += dp * (1.8 / (d2 + 0.05))
	if sh.has_threat:
		var away := a.p - sh.threat
		var d := away.length()
		if d < 14.0 and d > 0.01:
			acc += away * ((10.0 * (1.0 - d / 14.0) + 2.0) / d)
	acc += Vector3(sin(t * 1.7 + f.phase) * 0.6, sin(t * 1.3 + f.phase * 2.0) * 0.3, cos(t * 1.5 + f.phase) * 0.6)
	var has_ground := world.ground.is_valid()
	var h: float = world.ground.call(a.p.x, a.p.z) if has_ground else 0.0
	if has_ground and a.p.y < h + 1.2:
		acc.y += (h + 1.2 - a.p.y) * 6.0
	if a.p.y > -3.0:
		acc.y -= 4.0

	a.v += acc * dt
	var hide := alarm and a.p.distance_to(sh.home) < 4.0
	var max_s := HIDE_SPEED if hide else (ALARM_SPEED if alarm else CALM_SPEED)
	var sp := a.v.length()
	if sp > max_s:
		a.v *= max_s / sp
	elif sp < MIN_SPEED:
		a.v *= MIN_SPEED / (sp + 1e-3)
	a.p += a.v * dt
	if has_ground and a.p.y < h + a.clearance:
		a.p.y = h + a.clearance
	a.p.x = clampf(a.p.x, -EcoAgent.EDGE, EcoAgent.EDGE)
	a.p.z = clampf(a.p.z, -EcoAgent.EDGE, EcoAgent.EDGE)
	a.state = EcoAgent.State.HIDE if hide else (EcoAgent.State.FLEE if alarm else EcoAgent.State.GRAZE)
