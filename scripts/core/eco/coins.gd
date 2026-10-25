class_name EcoCoins
extends EcoSystem
## Монетники и песчаные глазуны (initCoins, coinSpawn, coinsUpdate, coinsPing в js/creatures.js; бестиарий).
## Три стайки по 9 круглых рыбок пасутся над тремя пятнами мха, ближайшими к старту (не ближе 25 м друг к другу —
## у тех же пятен растёт пузырчатка), и понемногу объедают мох. В 2,2 м от середины пятна в песке лежит глазун:
## на сонаре его нет, видно только глаза. Монетник, проплывший над ним ближе 1,5 м, пропадает (наблюдение «ambush»,
## глазун снова голоден через 18 с, рыбка — снова над мхом через 30…45 с). В луче прожектора глаза вспыхивают
## («eyes», раз в 40 с). От импульса сонара ближе 70 м стайка 2,5 с рассыпается прочь от ближайшей угрозы — глазуна
## ближе 12 м, серпохвоста ближе 30 м или корабля («scatter» раз в 30 с; у глазуна ещё «sonar» без текста).
## Когда у куста пузырчатки той же стайки облако спор, монетники кормятся на нём.

const ID := "monet"
const GLAZUN := "glazun"
## Стаек — по пятнам мха у старта, рыбок в стайке (CN_PER); пятна — не ближе 25 м друг к другу.
const SCHOOLS := 3
const PER := 9
const PICK_GAP := 25.0
## Глазун — в 2,2 м от середины пятна, хватает ближе 1,5 м по горизонтали и ниже 2,2 м над собой (GZ_REACH).
const GZ_OFFSET := 2.2
const GZ_REACH := 1.5
const GZ_UP := 2.2
## После броска глазун ждёт 18 с, в начале — 8…20 с; съеденная рыбка появляется снова через 30…45 с.
const GZ_CD := 18.0
const RESPAWN_MIN := 30.0
const RESPAWN_MAX := 45.0
## Глаза в луче — наблюдение раз в 40 с; глаза — на стебельках (±0,07; 0,15; 0,16) в осях глазуна.
const EYES_CD := 40.0
const EYE := Vector3(0.07, 0.15, 0.16)
## Сонар: стайки ближе 70 м рассыпаются на 2,5 с, сообщение — раз в 30 с (SCATTER_R).
const SCATTER_R := 70.0
const SCATTER_TIME := 2.5
const SCATTER_CD := 30.0
const GZ_SCARE_R := 12.0
const PRED_SCARE_R := 30.0
## Бегство 5 м/с на 6 м вперёд, на 1,5 м над мхом; пасутся 0,8 м/с, к мху и спорам — 2,2 м/с (дальше 4 м).
const FLEE_SPEED := 5.0
const GRAZE_SPEED := 0.8
const RETURN_SPEED := 2.2
const HOME_R := 4.0
## Кормёжка: пасётся раз в 60 с, мох — минус 0,002 в секунду, если еды больше 0,2 — наблюдение «graze».
const GRAZE_CD := 60.0
const EAT := 0.002
## Споры пузырчатки своей стайки ближе 25 м — монетники плывут к облаку, «приплыли» — ближе 3 м.
const FEED_R := 25.0
const CAME_R := 3.0
## Не ниже 0,3 м над дном, корпус корабля — с запасом 0,25 м.
const CLEAR := 0.3
const HULL_R := 0.25
## Дно под рыбкой читается заново, когда она отплыла дальше 0,25 м (EcoAgent.GROUND_STEP).
const GROUND_STEP := 0.25


## Монетник.
class Coin:
	extends RefCounted
	var index := 0
	## Номер стайки (не ссылка: стайка держит рыбок, ссылка назад — цикл RefCounted и утечка при выходе).
	var school := 0
	var alive := true
	## Секунд до появления снова (у съеденной).
	var respawn := 0.0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var goal := Vector3.ZERO
	var goal_t := 0.0
	var phase := 0.0
	var gx := INF
	var gz := INF
	var gh := 0.0


## Песчаный глазун.
class Glazun:
	extends RefCounted
	var index := 0
	var pos := Vector3.ZERO
	var yaw := 0.0
	var cd := 0.0
	## Бросок 0…1: тело приподнимается из песка и гаснет за полсекунды.
	var lunge := 0.0
	var lit := false
	var eyes_cd := 0.0
	## Глаза (левый, правый) и середина между ними — в мире.
	var eyes: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var eye_c := Vector3.ZERO


## Стайка над пятном мха.
class School:
	extends RefCounted
	var index := 0
	## Середина пятна на дне.
	var center := Vector3.ZERO
	## Пятно мха (null — мха нет, есть нечего).
	var patch: EcoMoss.Patch
	var glazun: Glazun
	var members: Array[Coin] = []
	## Бегство: секунд осталось и от чего.
	var scatter := 0.0
	var from := Vector3.ZERO
	var graze_cd := 0.0
	var scatter_cd := 0.0

	func alive_count() -> int:
		var n := 0
		for c in members:
			if c.alive:
				n += 1
		return n


var schools: Array[School] = []
var coins: Array[Coin] = []
var glazuns: Array[Glazun] = []
var moss: EcoMoss
var preds: EcoPred
## Пузырчатка: куст i — у стайки i (EcoBladder.default_spots — те же пятна).
var bladders: EcoBladder

var _spots: Array[Vector3]
var _rnd: EcoRandom


## moss_system — пятна мха (подключены раньше); pred_system — серпохвосты, от них стайка тоже рассыпается;
## spots — свои середины стаек (для тестов), пусто — у пятен мха.
func _init(moss_system: EcoMoss = null, pred_system: EcoPred = null, spots: Array[Vector3] = []) -> void:
	moss = moss_system
	preds = pred_system
	_spots = spots.duplicate() if not spots.is_empty() else default_spots()


## Три пятна мха, ближайших к старту корабля, не ближе PICK_GAP друг к другу (initCoins).
static func default_spots() -> Array[Vector3]:
	var s0 := Helm.Ship.START
	var sorted := EcoMoss.SPOTS.duplicate()
	sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x - s0.x, a.z - s0.z).length() < Vector2(b.x - s0.x, b.z - s0.z).length())
	var picks: Array[Vector3] = []
	for p: Vector3 in sorted:
		if picks.size() >= SCHOOLS:
			break
		var far := true
		for q in picks:
			far = far and Vector2(q.x - p.x, q.z - p.z).length() > PICK_GAP
		if far:
			picks.append(p)
	return picks


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 4421) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	schools.clear()
	coins.clear()
	glazuns.clear()
	for i in _spots.size():
		var p := _spots[i]
		var sc := School.new()
		sc.index = i
		sc.center = Vector3(p.x, _floor(world, p.x, p.z, p.y), p.z)
		sc.patch = moss.nearest(p, 1.0) if moss else null
		sc.graze_cd = _rnd.range_f(5.0, 15.0)
		var a := _rnd.range_f(0.0, 6.28)
		var gz := Glazun.new()
		gz.index = i
		var gp := sc.center + Vector3(cos(a) * GZ_OFFSET, 0.0, sin(a) * GZ_OFFSET)
		gp.y = _floor(world, gp.x, gp.z, sc.center.y)
		gz.pos = gp
		gz.yaw = _rnd.range_f(0.0, 6.28)
		gz.cd = _rnd.range_f(8.0, 20.0)
		var b := Basis(Vector3.UP, gz.yaw)
		gz.eyes = [gp + b * Vector3(-EYE.x, EYE.y, EYE.z), gp + b * EYE]
		gz.eye_c = (gz.eyes[0] + gz.eyes[1]) * 0.5
		sc.glazun = gz
		glazuns.append(gz)
		schools.append(sc)
		for k in PER:
			var cn := Coin.new()
			cn.index = i * PER + k
			cn.school = i
			cn.phase = _rnd.range_f(0.0, 6.28)
			_spawn(cn)
			sc.members.append(cn)
			coins.append(cn)


## Монетник появляется над мхом, но не прямо над глазуном (coinSpawn).
func _spawn(cn: Coin) -> void:
	var sc := schools[cn.school] if cn.school < schools.size() else null
	if sc == null:
		return
	var gz := sc.glazun
	for k in 10:
		cn.pos = sc.center + Vector3(_rnd.range_f(-2.5, 2.5), _rnd.range_f(0.6, 1.4), _rnd.range_f(-2.5, 2.5))
		if gz == null or _flat(cn.pos, gz.pos) > GZ_REACH + 0.8:
			break
	cn.alive = true
	cn.respawn = 0.0
	cn.vel = Vector3.ZERO
	cn.goal_t = 0.0
	cn.goal = cn.pos


func step(world: EcoWorld, dt: float) -> void:
	for sc in schools:
		sc.scatter -= dt
		sc.graze_cd -= dt
		sc.scatter_cd -= dt
		var food := sc.patch.food if sc.patch else 1.0
		if sc.scatter <= 0.0 and sc.graze_cd <= 0.0 and food > 0.2 and sc.alive_count() > 0:
			sc.graze_cd = GRAZE_CD
			world.emit(ID, "graze", sc.center, _graze_text(world))
		if sc.scatter <= 0.0 and sc.patch:
			EcoMoss.eat(sc.patch, dt * EAT)
	for cn in coins:
		if not cn.alive:
			cn.respawn -= dt
			if cn.respawn > 0.0:
				continue
			_spawn(cn)
		_step_coin(world, cn, dt)
	for gz in glazuns:
		_step_glazun(world, gz, dt)


func _step_coin(world: EcoWorld, cn: Coin, dt: float) -> void:
	var sc := schools[cn.school]
	var max_s := GRAZE_SPEED
	if sc.scatter > 0.0:
		# бегство прочь от угрозы
		var away := Vector3(cn.pos.x - sc.from.x, 0.0, cn.pos.z - sc.from.z)
		if away.length_squared() < 0.01:
			away = Vector3(cos(cn.phase), 0.0, sin(cn.phase))
		cn.goal = cn.pos + away.normalized() * 6.0
		cn.goal.y = sc.center.y + 1.5
		max_s = FLEE_SPEED
	else:
		cn.goal_t -= dt
		var fd := feed_of(sc)
		if cn.goal_t <= 0.0 or (fd and cn.goal.distance_to(fd.cloud) > 3.0):
			cn.goal_t = _rnd.range_f(2.0, 5.0)
			if fd:
				cn.goal = fd.cloud + Vector3(_rnd.range_f(-1.5, 1.5), _rnd.range_f(-1.0, 1.0), _rnd.range_f(-1.5, 1.5))
			else:
				cn.goal = sc.center + Vector3(_rnd.range_f(-3.0, 3.0), _rnd.range_f(0.5, 1.3), _rnd.range_f(-3.0, 3.0))
		if fd or _flat(cn.pos, sc.center) > HOME_R:
			max_s = RETURN_SPEED
	var to := cn.goal - cn.pos
	var d := to.length()
	if d > 0.05:
		cn.vel = cn.vel.lerp(to * (minf(max_s, d * 1.5) / d), minf(1.0, dt * 3.0))
	cn.pos += cn.vel * dt
	var res := EcoHull.push_out(cn.pos, world.ship.pos, world.ship.yaw, HULL_R)
	if not res.is_empty():
		cn.pos = res[0]
		var n: Vector3 = res[1]
		var vn := cn.vel.dot(n)
		if vn < 0.0:
			cn.vel -= n * vn
	var h := _coin_floor(world, cn)
	if cn.pos.y < h + CLEAR:
		cn.pos.y = h + CLEAR
	cn.pos.x = clampf(cn.pos.x, -EcoAgent.EDGE, EcoAgent.EDGE)
	cn.pos.z = clampf(cn.pos.z, -EcoAgent.EDGE, EcoAgent.EDGE)


func _step_glazun(world: EcoWorld, gz: Glazun, dt: float) -> void:
	gz.cd -= dt
	gz.eyes_cd -= dt
	gz.lunge = maxf(0.0, gz.lunge - dt * 2.0)
	if gz.cd <= 0.0:
		for cn in schools[gz.index].members:
			if not cn.alive:
				continue
			if _flat(cn.pos, gz.pos) < GZ_REACH and cn.pos.y - gz.pos.y < GZ_UP:
				cn.alive = false
				cn.respawn = _rnd.range_f(RESPAWN_MIN, RESPAWN_MAX)
				gz.cd = GZ_CD
				gz.lunge = 1.0
				world.emit(GLAZUN, "ambush", gz.pos, _ambush_text(world))
				break
	var was := gz.lit
	gz.lit = world.in_beam(gz.eye_c)
	if gz.lit and not was and gz.eyes_cd <= 0.0:
		gz.eyes_cd = EYES_CD
		world.emit(GLAZUN, "eyes", gz.eye_c, _eyes_text(world))


## Импульс сонара: стайки ближе SCATTER_R рассыпаются прочь от ближайшей угрозы (coinsPing).
func on_ping(world: EcoWorld, pos: Vector3) -> void:
	for sc in schools:
		if sc.center.distance_to(pos) > SCATTER_R or sc.alive_count() == 0:
			continue
		var kind := "ship"
		var from := pos
		var bd := INF
		var gz := sc.glazun
		var dg := _flat(gz.pos, sc.center)
		if dg < GZ_SCARE_R:
			kind = GLAZUN
			from = gz.pos
			bd = dg
		if preds:
			for pr in preds.all:
				var d := pr.agent.p.distance_to(sc.center)
				if d < PRED_SCARE_R and d < bd:
					kind = "pred"
					from = pr.agent.p
					bd = d
		sc.from = from
		sc.scatter = SCATTER_TIME
		if sc.scatter_cd > 0.0:
			continue
		sc.scatter_cd = SCATTER_CD
		world.emit(ID, "scatter", sc.center, _scatter_text(world, kind))
		if kind == GLAZUN:
			world.emit(GLAZUN, "sonar", gz.pos)


## Стайка от трёх рыбок видна сонару и сканеру (по первой живой); глазун — только сканеру, по глазам.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for sc in schools:
		var first: Coin = null
		var n := 0
		for c in sc.members:
			if c.alive:
				n += 1
				if first == null:
					first = c
		if n >= 3:
			out.append(EcoWorld.target(ID, first.pos, 1.2))
	for gz in glazuns:
		out.append(EcoWorld.target(GLAZUN, gz.eye_c, 0.6, false))


## Облако спор, на котором кормится стайка (null — нет): куст пузырчатки той же стайки лопнул ближе FEED_R,
## а стайка не рассыпается.
func feed_of(sc: School) -> EcoBladder.Bush:
	if bladders == null or sc.scatter > 0.0 or sc.index >= bladders.bushes.size():
		return null
	var bl := bladders.bushes[sc.index]
	if bl.life > 0.0 and sc.center.distance_to(bl.cloud) < FEED_R:
		return bl
	return null


## Приплыла ли к облаку спор куста i хоть одна рыбка стайки i (для наблюдения пузырчатки «feed»).
func came_to(i: int) -> bool:
	if i >= schools.size():
		return false
	var sc := schools[i]
	var bl := feed_of(sc)
	if bl == null:
		return false
	for c in sc.members:
		if c.alive and c.pos.distance_to(bl.cloud) < CAME_R:
			return true
	return false


## Наклон монетника в момент t: нос по скорости (+Z — вперёд), покачивание с боку на бок.
static func coin_basis(cn: Coin, t: float, rate := 2.0) -> Basis:
	var b: Basis
	if cn.vel.length_squared() > 1e-4 and Vector2(cn.vel.x, cn.vel.z).length_squared() > 1e-6:
		b = Basis.looking_at(cn.vel, Vector3.UP, true)
	else:
		b = Basis(Vector3.UP, cn.phase)
	return b * Basis(Vector3.BACK, sin(t * rate + cn.phase) * 0.2)


## Тело глазуна: приподнимается в броске на 0,35 м и задирает голову.
static func glazun_transform(gz: Glazun) -> Transform3D:
	var b := Basis(Vector3.UP, gz.yaw) * Basis(Vector3.RIGHT, -gz.lunge * 0.4)
	return Transform3D(b, gz.pos + Vector3(0, gz.lunge * 0.35, 0))


## Яркость глаз: 1 в луче, иначе чуть мерцает около 0,35.
static func eye_k(gz: Glazun, t: float) -> float:
	return 1.0 if gz.lit else 0.35 + 0.1 * sin(t * 1.3 + gz.index)


static func eye_color(gz: Glazun, t: float) -> Color:
	var k := eye_k(gz, t)
	return Color(k + 0.2, k + 0.25, 0.45 * k)


func _coin_floor(world: EcoWorld, cn: Coin) -> float:
	if not world.ground.is_valid():
		return schools[cn.school].center.y
	var dx := cn.pos.x - cn.gx
	var dz := cn.pos.z - cn.gz
	if dx * dx + dz * dz > GROUND_STEP * GROUND_STEP:
		cn.gx = cn.pos.x
		cn.gz = cn.pos.z
		cn.gh = world.ground.call(cn.pos.x, cn.pos.z)
	return cn.gh


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


## Тексты собираются в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой.
static func _graze_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return "Стайка %s пасётся на светящемся мху" % (w.nm(ID, Species.Case.GEN) if w else Species.called(ID, Species.Case.GEN))


static func _ambush_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var coin := w.nm(ID, Species.Case.ACC) if w else Species.called(ID, Species.Case.ACC)
		var known := w != null and w.scanned.is_valid() and bool(w.scanned.call(GLAZUN))
		return ("Песчаный глазун схватил %s" if known else "Из песка что-то схватило %s") % coin


static func _eyes_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var known := w != null and w.scanned.is_valid() and bool(w.scanned.call(GLAZUN))
		return "В луче прожектора блеснули %s" % ("глаза песчаного глазуна" if known else "два глаза в песке")


static func _scatter_text(world: EcoWorld, kind: String) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var gen := w.nm(ID, Species.Case.GEN) if w else Species.called(ID, Species.Case.GEN)
		var where := "от корабля"
		if kind == GLAZUN:
			where = "от песка рядом — там кто-то прячется"
		elif kind == "pred":
			where = "от %s" % (w.nm("pred", Species.Case.GEN) if w else Species.called("pred", Species.Case.GEN))
		return "Стайка %s рассыпается %s" % [gen, where]
