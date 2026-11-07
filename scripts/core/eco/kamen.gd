class_name EcoKamen
extends EcoSystem
## Каменщики (бестиарий: трубчатые черви ~30 см, «в игре»; реестр Species "kamen", #1337): у каждого куста огнецвета
## (EcoCoral.BASES) — ряд известковых трубок длиной около 9 м, в каждом гнезде ряда несколько трубок с яркими розовыми
## венчиками. Венчики прячутся в трубки от вибрации: рядом движется крупное существо (EcoAgent.big — серпохвост,
## стеклоуст…, быстрее MOVE_SPEED и ближе HIDE_R) или шумно идёт корабль (как у огнецвета: быстрее NOISE_SPEED,
## ближе NOISE_R). Каждое гнездо слушает само, поэтому ряд гаснет с того края, откуда подходят, — по ряду видно
## сторону возмущения до того, как существо видно в луче. После QUIET секунд тишины венчики раскрываются за ~4 с.
## Стоящий хищник (чистка на станции огнёвок) не вибрирует — ряд у станции открыт.
## Наблюдения журнала: «hide» — ряд прячется от шумного хода корабля (раз в HIDE_CD у ряда), «warn» — от прохода
## крупного существа, когда корабль ближе SEE_R (раз в WARN_CD). Свой шум корабля «warn» не даёт — причину
## называет только сторонняя вибрация. Ряды видны сонару и сканеру. Рисует KamenView.

const ID := "kamen"
## Гнёзд в ряду, трубок в гнезде, шаг гнёзд вдоль ряда (м).
const PER_ROW := 10
const TUBES := 3
const SPACING := 0.95
## Полдлины ряда с запасом на изгиб и трубки (м).
const HALF := PER_ROW * SPACING * 0.5 + 1.0
## Середина ряда — в OFFSET м от подножия куста, на дальней от старта стороне (не перебивает цели сканера у старта).
const OFFSET := 6.0
## Откуда считать «дальнюю сторону» (место 00, Helm.Ship.START).
const FROM := Vector2(0.0, 95.0)
## Трубка: длина (м) и разброс, радиус у устья.
const TUBE_LEN := 0.6
const TUBE_SPREAD := 0.25
const TUBE_R := 0.08
## Крупное существо ближе HIDE_R к гнезду, плывущее быстрее MOVE_SPEED, — вибрация.
const HIDE_R := 11.0
const MOVE_SPEED := 0.6
## Шумный ход корабля — как для огнецвета.
const NOISE_SPEED := EcoCoral.NOISE_SPEED
const NOISE_R := 14.0
## Венчик прячется за 1 / HIDE_RATE с, раскрывается за 1 / OPEN_RATE с после QUIET с тишины.
const HIDE_RATE := 4.0
const OPEN_RATE := 0.25
const QUIET := 4.0
## Венчик открыт меньше этого — «спрятан».
const HIDDEN := 0.5
## Строка «крупный» — только когда корабль ближе SEE_R к ряду (ряд видно); кулдауны у ряда.
const SEE_R := 70.0
const HIDE_CD := 60.0
const WARN_CD := 40.0

## Почему спрятался венчик.
enum Cause { NONE, SHIP, BIG }


## Гнездо ряда: несколько трубок с общим венчиком-состоянием.
class Worm:
	extends RefCounted
	var base := Vector3.ZERO
	## Раскрыт: 1 — венчики снаружи, 0 — в трубках.
	var open := 1.0
	## Секунд тишины до раскрытия.
	var quiet := 0.0
	var cause: Cause = Cause.NONE
	## Трубки: основание (в дне) и длина.
	var tube_base := PackedVector3Array()
	var tube_len := PackedFloat32Array()


## Ряд у куста огнецвета.
class Row:
	extends RefCounted
	var index := 0
	var center := Vector3.ZERO
	## Вдоль ряда (горизонтально, единичный).
	var along := Vector3.RIGHT
	var worms: Array[Worm] = []
	var hide_cd := 0.0
	var warn_cd := 0.0
	## Все гнёзда раскрыты — шаг пропускает ряд, пока рядом тихо.
	var calm := true


var rows: Array[Row] = []
## Ряд изменился с прошлой отрисовки (виду — переписать буфер; сбрасывает KamenView.sync).
var changed := true

var _bases: Array[Vector2]
## Крупные из world.agents (пересобирается, когда агентов стало больше или меньше).
var _big: Array[EcoAgent] = []
var _seen := -1


## bases — подножия кустов (для тестов); пусто — кусты огнецвета.
func _init(bases: Array[Vector2] = []) -> void:
	_bases = bases.duplicate() if not bases.is_empty() else EcoCoral.BASES.duplicate()


func reset(world: EcoWorld) -> void:
	rows.clear()
	changed = true
	_seen = -1
	for i in _bases.size():
		rows.append(_row(world, i, _bases[i]))


static func _out_dir(base: Vector2) -> Vector2:
	var d := base - FROM
	return d.normalized() if d.length() > 0.01 else Vector2.RIGHT


func _row(world: EcoWorld, i: int, base: Vector2) -> Row:
	var r := Row.new()
	r.index = i
	var out := _out_dir(base)
	var c := base + out * OFFSET
	var along := Vector2(-out.y, out.x)
	r.along = Vector3(along.x, 0.0, along.y)
	r.center = Vector3(c.x, _floor(world, c.x, c.y, 0.0), c.y)
	for k in PER_ROW:
		var w := Worm.new()
		# ряд чуть изогнут к кусту (арки срастаются вдоль подножия), гнёзда не на линейке
		var t := (k - (PER_ROW - 1) * 0.5) * SPACING
		var bend := -out * (t * t * 0.02) + out * (_hash(i, k, 1) - 0.5) * 0.4
		var p := c + along * t + bend
		w.base = Vector3(p.x, _floor(world, p.x, p.y, r.center.y), p.y)
		for j in TUBES:
			var a := (j + _hash(i, k, 2)) * TAU / TUBES
			var off := Vector2(cos(a), sin(a)) * (0.12 + 0.1 * _hash(i, k, 3 + j))
			var q := p + off
			w.tube_base.append(Vector3(q.x, _floor(world, q.x, q.y, w.base.y) - 0.05, q.y))
			w.tube_len.append(TUBE_LEN * (1.0 + TUBE_SPREAD * (_hash(i, k, 6 + j) * 2.0 - 1.0)))
		r.worms.append(w)
	return r


func step(world: EcoWorld, dt: float) -> void:
	var s := world.ship
	var loud := absf(s.speed) > NOISE_SPEED
	if world.agents.size() != _seen:
		_seen = world.agents.size()
		_big.clear()
		for a in world.agents:
			if a.big:
				_big.append(a)
	var movers := PackedVector3Array()
	for a in _big:
		if a.alive and a.v.length_squared() > MOVE_SPEED * MOVE_SPEED:
			movers.append(a.p)
	for r in rows:
		r.hide_cd -= dt
		r.warn_cd -= dt
		if r.calm and not _stirred(r, loud, s.pos, movers):
			continue   # ряд раскрыт и вокруг тихо — гнёзда не перебираем (шаг мира на телефоне, test_eco_speed)
		var by_ship := false
		var by_big := false
		var calm := true
		for w in r.worms:
			var was := w.open
			var cause := cause_at(w.base, loud, s.pos, movers)
			if cause != Cause.NONE:
				w.cause = cause
				w.quiet = QUIET
				w.open = maxf(0.0, w.open - dt * HIDE_RATE)
			else:
				w.quiet = maxf(0.0, w.quiet - dt)
				if w.quiet <= 0.0:
					w.open = minf(1.0, w.open + dt * OPEN_RATE)
					if w.open >= 1.0:
						w.cause = Cause.NONE
			calm = calm and w.open >= 1.0
			if w.open != was:
				changed = true
			if was >= HIDDEN and w.open < HIDDEN:
				by_ship = by_ship or cause == Cause.SHIP
				by_big = by_big or cause == Cause.BIG
		r.calm = calm
		if by_big and r.warn_cd <= 0.0 and s.pos.distance_to(r.center) < SEE_R:
			r.warn_cd = WARN_CD
			world.emit(ID, "warn", r.center, _text(world, "Ряд %s прячет венчики — рядом проходит кто-то крупный"))
		elif by_ship and r.hide_cd <= 0.0:
			r.hide_cd = HIDE_CD
			world.emit(ID, "hide", r.center, _text(world, "Ряд %s прячет венчики в трубки — корабль шумит рядом"))


## Рядом с рядом r есть вибрация (корабль или крупный ближе своего радиуса плюс полдлины ряда).
static func _stirred(r: Row, loud: bool, ship: Vector3, movers: PackedVector3Array) -> bool:
	if loud and ship.distance_to(r.center) < NOISE_R + HALF:
		return true
	for m in movers:
		if m.distance_to(r.center) < HIDE_R + HALF:
			return true
	return false


## Причина вибрации у гнезда at: шумный корабль ближе NOISE_R важнее (свой шум — не довод «кто-то крупный»),
## иначе — плывущий крупный ближе HIDE_R.
static func cause_at(at: Vector3, loud: bool, ship: Vector3, movers: PackedVector3Array) -> Cause:
	if loud and ship.distance_to(at) < NOISE_R:
		return Cause.SHIP
	for m in movers:
		if m.distance_to(at) < HIDE_R:
			return Cause.BIG
	return Cause.NONE


## Разряд сотрясает воду: ряды ближе radius + 6 м прячутся (без строки — причина очевидна).
func on_zap(world: EcoWorld, radius: float) -> void:
	for r in rows:
		if world.ship.pos.distance_to(r.center) < radius + 6.0:
			for w in r.worms:
				w.open = 0.0
				w.quiet = QUIET
				w.cause = Cause.SHIP
			r.calm = false
			changed = true


## Сколько гнёзд ряда спрятано.
func hidden_in(r: Row) -> int:
	var n := 0
	for w in r.worms:
		if w.open < HIDDEN:
			n += 1
	return n


## Каждый ряд виден сонару и сканеру — по середине, чуть над дном.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for r in rows:
		out.append(EcoWorld.target(ID, r.center + Vector3(0, 0.6, 0), 2.5))


static func _hash(i: int, k: int, salt: int) -> float:
	var h := (i * 73856093) ^ (k * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


## Текст собирается в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой.
static func _text(world: EcoWorld, fmt: String) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return fmt % (w.nm(ID, Species.Case.GEN) if w else Species.called(ID, Species.Case.GEN))
