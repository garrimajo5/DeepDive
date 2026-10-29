class_name EcoEel
extends EcoSystem
## Стеклоуст (eel в js/creatures.js: initEels, eelUpdate, onZap; логова — W.lairs в js/world.js; ART-006,
## `docs/concept-art/stekloust-skrebun.md`): прозрачный угорь-засадчик 5 м. Одно логово в каменной расщелине; в логове
## снаружи только голова и красный глаз. Скребун ближе 9 м или светляк ближе 6 м к устью — бросок (11 м/с, 3 с),
## добыча съедена (наблюдение «eelcatch»). Корабль носом ближе 28 м к устью — плывёт к носу в обход корпуса (10 м/с,
## 6 с) и присасывается снаружи к панорамному стеклу (наблюдение «latch»): пока висит — тянет заряд корабля,
## EcoLink.DRAIN 3,2 ед./с. Разряд по корпусу сбрасывает его (наблюдение «zap»), он уходит в логово.
## На корпусе прилипалы (EcoRemora) — к кораблю не плывёт. Заметен сонару и сканеру.

const ID := "eel"
## Логово (x, z); устье — на 1,1 м над дном и на 0,3 м наружу. Слой 1 (#834, `docs/sloj1-sad.md` «Стеклоуст»): один
## читаемый эпизод — у трещины на подходе 02↔01, в 14 м от отрезка (из трёх логов js/world.js оставлено это). Два
## других убраны: (28, 52) стоял на пути обучения 00→01, (62, −45) — в 23 м от Каменного цветка 01, где серпохвост, —
## две угрозы сразу. Логово не ближе LAIR_CLEAR к местам сохранения и терминалу (00, 07, 09, 10) и к цветку 01.
const LAIRS: Array[Vector2] = [Vector2(-62, -8)]
const LAIR_CLEAR := 80.0
## Знак раньше угрозы: корабль по горизонтали входит в WARN_R от логова, стеклоуст сидит — мир шлёт строку WARN_TEXT
## (EcoLink.MESSAGE). К стеклу он плывёт, когда нос ближе SHIP_R (28 м), — знак приходит на 20 м раньше, обход стороной
## (дальше SHIP_R) есть с обеих сторон трещины. Снова — после выхода из круга и не чаще WARN_CD.
const WARN_R := 55.0
const WARN_CD := 120.0
const WARN_TEXT := "В расщелине у трещины — красный глаз стеклоуста. Обходите стороной: ближе 28 м он бросится к стеклу."
## Глаз вдали (#970): сам глаз — шар 0,07 м, с 45 м это меньше пикселя телефона, и знак WARN_TEXT в окне не
## читается. Поверх глаза — мягкое красное пятно лицом к камере постоянного углового размера GLINT_ANG (радиус на
## метр расстояния): с 45 м — 0,63 м (мягкий край — видимое ядро около трети), около 10 px в окне 1600 px. Ближе GLINT_NEAR пятна нет (глаз виден сам), к
## GLINT_FULL оно набирает силу, дальше GLINT_FAR гаснет (дальше знака WARN_R).
const GLINT_ANG := 0.014
const GLINT_NEAR := 10.0
const GLINT_FULL := 20.0
const GLINT_FAR := 70.0
const GLINT_OFF := 85.0


## Пятно глаза с расстояния dist (м): (радиус, непрозрачность 0…1).
static func glint(dist: float) -> Vector2:
	var a := smoothstep(GLINT_NEAR, GLINT_FULL, dist) * (1.0 - smoothstep(GLINT_FAR, GLINT_OFF, dist))
	return Vector2(dist * GLINT_ANG, a)
const MOUTH_UP := 1.1
const MOUTH_OUT := 0.3
## Камни логова (как в js/world.js): смещение вбок, вверх и размер; камни — на 2,4 м за устьем.
const ROCKS: Array[Vector3] = [Vector3(0, 0.2, 2.7), Vector3(1.7, 1.0, 1.9), Vector3(-1.7, 1.0, 1.9),
	Vector3(0, 2.6, 2.1), Vector3(0.6, -0.2, 2.2)]
const ROCK_BACK := 2.4
## Звеньев тела (ESEG); в логове — через 0,45 м, на ходу тянутся за головой не дальше 0,42 м.
const SEGS := 14
const SEG_HIDE := 0.45
const SEG_FOLLOW := 0.42
## Добыча: скребун ближе 9 м, светляк ближе 6 м к устью; бросок с вероятностью 0,6 в секунду.
const PREY_GRAZER_R := 9.0
const PREY_FISH_R := 6.0
const STRIKE_CHANCE := 0.6
const STRIKE_SPEED := 11.0
const STRIKE_TIME := 3.0
const CATCH_R := 1.3
## Корабль: нос ближе 28 м к устью — с вероятностью 0,5 в секунду плывёт к носу 10 м/с, на это — 6 с.
const SHIP_R := 28.0
const SHIP_CHANCE := 0.5
const TO_SHIP_SPEED := 10.0
const TO_SHIP_TIME := 6.0
const LATCH_R := 2.0
## Назад в логово 6 м/с, бегство 12 м/с; ближе 0,8 м к устью — снова прячется.
const RETURN_SPEED := 6.0
const FLEE_SPEED := 12.0
const HOME_R := 0.8
## Паузы до следующего броска (с): в начале 10–25; не догнал — 8; поел — 25; корабль ушёл — 15; разряд — 40.
const CD_MISS := 8.0
const CD_FED := 25.0
const CD_SHIP := 15.0
const CD_ZAP := 40.0
## На корпусе прилипалы (EcoRemora.on_hull) — к кораблю не плывёт, снова глянет через 15 с.
const CD_REMORA := 15.0
## Тянет заряд корабля, пока висит на стекле (ед./с, ship.js: drain += 3,2).
const DRAIN := 3.2
## Нос для стеклоуста в осях корабля: середина панорамного стекла (HullPlan: стекло 9 × 2 м на срезе носа z = −7,2,
## середина на 1,75 м), снаружи на 0,65 м: от середины головы до кольца присоски 0,56 м — кольцо прижато к стеклу.
const FRONT := Vector3(0, 1.75, HullPlan.NOSE_CUT - 0.65)
## На стекле тело лежит поперёк окна (S.group.localToWorld(−3,4 + 0,5k, 1,8 + 0,45 sin(0,8k + 2,2t), −6,36)): голова
## у левой стойки, хвост волной к правой; волна 0,3 м (в браузере 0,45 — тело выходило за стекло 2 м), у головы
## гаснет, чтобы присоска не ёрзала по стеклу.
const LATCH_X0 := -3.4
const LATCH_DX := 0.5
const LATCH_WAVE := 0.3
## Плавность (Б3): тело переходит в позу логова и стекла не прыжком, а за SETTLE с (смягчённо, к движущейся цели —
## стекло едет с кораблём); голова доворачивает к своему курсу долей угла FACE_FOLLOW в секунду, не быстрее FACE_MAX
## рад/с. Раньше на входе в логово 14 звеньев перескакивали из-за головы в расщелину, а на стекле — на окно за шаг,
## голова щёлкала на пол-оборота.
const SETTLE := 0.7
const FACE_FOLLOW := 10.0
const FACE_MAX := 7.0
## Запас от корпуса на ходу: голова 0,3 м, звенья 0,25 м.
const HEAD_PAD := 0.3
const SEG_PAD := 0.25

enum Mode { HIDE, STRIKE, RETURN, FLEE, TO_SHIP, LATCHED }


## Один стеклоуст и его логово.
class Eel:
	extends RefCounted
	var agent: EcoAgent
	var index := 0
	var mode: Mode = Mode.HIDE
	## Устье логова, куда смотрит расщелина (единичный, горизонтальный), камни логова (место и размер в w).
	var lair := Vector3.ZERO
	var out := Vector3.FORWARD
	var rocks: Array[Vector4] = []
	## Звенья тела: 0 — голова; куда смотрит голова (единичный): на стекле — в стекло, иначе — от первого звена.
	var segs := PackedVector3Array()
	var face := Vector3.FORWARD
	## Доля перехода тела в позу логова или стекла: 0 — только вошёл в режим, 1 — лежит как надо (SETTLE).
	var settle := 1.0
	## Пауза до следующего броска; секунды до конца броска или пути к кораблю.
	var cd := 0.0
	var timer := 0.0
	## Добыча броска: скребун или светляк (одно из двух).
	var prey_grazer: EcoGrazer.Grazer
	var prey_fish: EcoFish.Fish
	## Набранное время вдали (EcoLod): шагает реже, догоняя пропущенное.
	var lag := 0.0

	func latched() -> bool:
		return mode == Mode.LATCHED

	func moving() -> bool:
		return mode != Mode.HIDE and mode != Mode.LATCHED


var eels: Array[Eel] = []
## Прилипалы на корпусе (E.hullRemoras): пока они там, стеклоуст на корабль не садится. null — прилипал нет.
var remoras: EcoRemora
## Кто висит на стекле (E.latched); null — никого.
var latched: Eel
## Добыча: скребуны и светляки мира (null — нет такой добычи).
var grazers: EcoGrazer
var fish: EcoFish

var _spots: Array[Vector3]
var _rnd: EcoRandom
## Знак у логова: пауза до следующего; знак за этот заход в круг WARN_R уже был.
var warn_cd := 0.0
var _warned := false
## Шаги модуля с reset — очередь стеклоустов вдали (EcoLod).
var _tick := 0


## spots — свои устья (x, дно, z) для тестов; пусто — логова LAIRS на дне мира.
func _init(prey_grazers: EcoGrazer = null, prey_fish: EcoFish = null, spots: Array[Vector3] = []) -> void:
	grazers = prey_grazers
	fish = prey_fish
	_spots = spots.duplicate()


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7005) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	eels.clear()
	latched = null
	_tick = 0
	warn_cd = 0.0
	_warned = false
	var places := _spots.duplicate()
	if places.is_empty():
		for xz in LAIRS:
			places.append(Vector3(xz.x, _floor(world, xz.x, xz.y, -40.0), xz.y))
	for i in places.size():
		var p: Vector3 = places[i]
		var e := Eel.new()
		e.index = i
		var o := Vector3(_rnd.range_f(-1, 1), 0.0, _rnd.range_f(-1, 1))
		e.out = o.normalized() if o.length_squared() > 1e-6 else Vector3.FORWARD
		e.face = e.out
		e.lair = p + Vector3(0, MOUTH_UP, 0) + e.out * MOUTH_OUT
		var side := Vector3(e.out.z, 0.0, -e.out.x)
		var back := p - e.out * ROCK_BACK
		for r in ROCKS:
			var c := back + side * r.x + Vector3(0, r.y, 0)
			e.rocks.append(Vector4(c.x, c.y, c.z, r.z))
		e.cd = _rnd.range_f(10, 25)
		e.agent = world.spawn(ID, e.lair)
		e.agent.set_state(EcoAgent.State.HIDE)
		e.segs.resize(SEGS)
		for k in SEGS:
			e.segs[k] = e.lair - e.out * (k * SEG_HIDE)
		eels.append(e)


## Нос корабля для стеклоуста (S.front) в мире.
static func front(s: EcoLink.ShipState) -> Vector3:
	return s.pos + FRONT.rotated(Vector3.UP, s.yaw)


## Стеклоуст вдали шагает реже (EcoLod): в логове в мути или на броске за скребуном сдвиг за кадр не виден, а поиск
## добычи и звенья мимо корпуса — каждый шаг. К кораблю и на стекле — каждый шаг (он у носа, ближе MID).
func step(world: EcoWorld, dt: float) -> void:
	var t := world.time
	for e in eels:
		var far := e.mode != Mode.TO_SHIP and e.mode != Mode.LATCHED
		if far and EcoLod.wait(e.agent.p.distance_to(world.ship.pos), _tick, e.index, e.lag, dt):
			e.lag += dt
			continue
		var h := dt + e.lag
		e.lag = 0.0
		_update(world, e, h, t)
		if e.mode == Mode.TO_SHIP or e.mode == Mode.LATCHED:   # к стеклу и на стекле — эпизод угрозы (#834)
			world.hold_threat(e)
	_tick += 1
	_sign(world, dt)
	if latched:
		world.drain(Species.info(ID).name, DRAIN)


func _update(world: EcoWorld, e: Eel, dt: float, t: float) -> void:
	e.timer -= dt
	e.cd -= dt
	var a := e.agent
	var speed := 0.0
	var goal := a.p
	var has_goal := false
	match e.mode:
		Mode.HIDE:
			a.p = e.lair + e.out * (0.3 + sin(t * 0.8 + e.index) * 0.15)
			if e.cd <= 0.0:
				_look_around(world, e, dt)
		Mode.STRIKE:
			var prey := _prey_agent(e)
			if prey == null or not prey.alive or e.timer <= 0.0:
				_go_home(e, Mode.RETURN, CD_MISS)
			else:
				speed = STRIKE_SPEED
				goal = prey.p
				has_goal = true
				if a.p.distance_to(goal) < CATCH_R:
					_eat(world, e)
		Mode.RETURN, Mode.FLEE:
			speed = FLEE_SPEED if e.mode == Mode.FLEE else RETURN_SPEED
			goal = e.lair
			has_goal = true
			if a.p.distance_to(e.lair) < HOME_R:
				_set_mode(e, Mode.HIDE)
		Mode.TO_SHIP:
			if latched or e.timer <= 0.0:
				_go_home(e, Mode.RETURN, CD_SHIP)
			else:
				var f := front(world.ship)
				speed = TO_SHIP_SPEED
				goal = EcoHull.detour(a.p, f, world.ship.pos, world.ship.yaw, HEAD_PAD)
				has_goal = true
				if a.p.distance_to(f) < LATCH_R:
					_latch(world, e)
	if has_goal and e.moving():
		var d := goal - a.p
		var dl := d.length()
		if dl > 0.01:
			a.p += d * minf(1.0, speed * dt / dl)
		world.push_out(a, HEAD_PAD)
	_pose(world, e, dt)


## Знак раньше угрозы (WARN_R): корабль вошёл в круг логова, стеклоуст в нём сидит, на стекле никого — строка на
## приборах. Пока корабль в круге, второй раз не шлёт.
func _sign(world: EcoWorld, dt: float) -> void:
	warn_cd -= dt
	var p := Vector2(world.ship.pos.x, world.ship.pos.z)
	var near: Eel = null
	for e in eels:
		if p.distance_to(Vector2(e.lair.x, e.lair.z)) < WARN_R:
			near = e
			break
	if near == null:
		_warned = false
	elif not _warned and warn_cd <= 0.0 and latched == null and near.mode == Mode.HIDE:
		_warned = true
		warn_cd = WARN_CD
		world.send(EcoLink.message(WARN_TEXT))


## В логове: добыча рядом — бросок; иначе корабль рядом — к носу (eelUpdate, case 'hide').
func _look_around(world: EcoWorld, e: Eel, dt: float) -> void:
	var g: EcoGrazer.Grazer = grazers.nearest_grazer(e.lair, PREY_GRAZER_R) if grazers else null
	var f: EcoFish.Fish = null
	if g == null and fish:
		f = fish.nearest_fish(e.lair, PREY_FISH_R)
	if (g or f) and _rnd.next() < dt * STRIKE_CHANCE:
		e.prey_grazer = g
		e.prey_fish = f
		_set_mode(e, Mode.STRIKE)
		e.timer = STRIKE_TIME
	elif latched == null and front(world.ship).distance_to(e.lair) < SHIP_R and world.threat_free(e) \
			and _rnd.next() < dt * SHIP_CHANCE:
		if remoras and remoras.on_hull > 0:   # на корпусе уже прилипалы — не садится
			e.cd = CD_REMORA
			remoras.scare_eel(world, e.lair)
		else:
			_set_mode(e, Mode.TO_SHIP)
			e.timer = TO_SHIP_TIME
			world.hold_threat(e)


func _prey_agent(e: Eel) -> EcoAgent:
	if e.prey_grazer:
		return e.prey_grazer.agent
	if e.prey_fish:
		return e.prey_fish.agent
	return null


func _eat(world: EcoWorld, e: Eel) -> void:
	var by_grazer := e.prey_grazer != null
	if by_grazer:
		grazers.kill(e.prey_grazer)
	else:
		fish.kill(e.prey_fish)
	world.emit(ID, "eelcatch", e.agent.p, _catch_text(world, by_grazer))
	_go_home(e, Mode.RETURN, CD_FED)


func _latch(world: EcoWorld, e: Eel) -> void:
	_set_mode(e, Mode.LATCHED)
	latched = e
	world.emit(ID, "latch", e.agent.p, _latch_text(world))


func _go_home(e: Eel, m: Mode, cd: float) -> void:
	_set_mode(e, m)
	e.cd = cd


func _set_mode(e: Eel, m: Mode) -> void:
	if (m == Mode.HIDE or m == Mode.LATCHED) and m != e.mode:
		e.settle = 0.0   # тело было на ходу — в позу переходит за SETTLE
	e.mode = m
	if m != Mode.STRIKE:
		e.prey_grazer = null
		e.prey_fish = null
	match m:
		Mode.HIDE: e.agent.set_state(EcoAgent.State.HIDE)
		Mode.STRIKE: e.agent.set_state(EcoAgent.State.HUNT)
		Mode.FLEE: e.agent.set_state(EcoAgent.State.FLEE)
		_: e.agent.set_state(EcoAgent.State.SEEK)


## Разряд по корпусу сбрасывает стеклоуста со стекла (E.onZap): бежит в логово, 40 с не выходит.
func on_zap(world: EcoWorld, _radius: float) -> void:
	if latched == null:
		return
	var e := latched
	latched = null
	_go_home(e, Mode.FLEE, CD_ZAP)
	world.emit(ID, "zap", front(world.ship), _zap_text(world))


## Звенья тела: в логове — в расщелину, на стекле — поперёк окна, на ходу — тянутся за головой мимо корпуса.
## В логово и на стекло тело переходит за SETTLE (settle_frac), голова доворачивает (turn_face).
func _pose(world: EcoWorld, e: Eel, dt: float) -> void:
	var a := e.agent
	var want := e.face
	match e.mode:
		Mode.LATCHED:
			var k_in := settle_frac(e, dt)
			for k in SEGS:
				var q := e.segs[k].lerp(latch_point(world.ship, k, world.time), k_in)
				if k_in < 1.0:   # по пути на стекло — мимо корпуса
					var res := EcoHull.push_out(q, world.ship.pos, world.ship.yaw, SEG_PAD)
					q = res[0] if not res.is_empty() else q
				e.segs[k] = q
			a.p = e.segs[0]
			want = Vector3.BACK.rotated(Vector3.UP, world.ship.yaw)
		Mode.HIDE:
			var k_in := settle_frac(e, dt)
			for k in SEGS:
				e.segs[k] = e.segs[k].lerp(a.p - e.out * ((k + 0.5) * SEG_HIDE), k_in)
			want = e.out
		_:
			e.segs[0] = a.p
			for k in range(1, SEGS):
				var d := e.segs[k] - e.segs[k - 1]
				var dl := d.length()
				var q := e.segs[k]
				if dl > SEG_FOLLOW:
					q = e.segs[k - 1] + d * (SEG_FOLLOW / dl)
				var res := EcoHull.push_out(q, world.ship.pos, world.ship.yaw, SEG_PAD)
				e.segs[k] = res[0] if not res.is_empty() else q
			var f := e.segs[0] - e.segs[1]
			if f.length_squared() > 1e-6:
				want = f.normalized()
	# легло в логово или на стекло — голова стоит ровно (на стекле едет с кораблём, как бы он ни поворачивал)
	var laid := e.settle >= 1.0 and not e.moving()
	e.face = want if laid else turn_face(e.face, want, dt)


## Доля пути звеньев к позе за этот шаг: смягчённый (smoothstep) переход за SETTLE к цели, которая может ехать (стекло
## с кораблём). На последнем шаге — 1: тело ложится ровно в позу. settle растёт.
static func settle_frac(e: Eel, dt: float) -> float:
	if e.settle >= 1.0:
		return 1.0
	var s0 := e.settle
	var s1 := minf(1.0, s0 + dt / SETTLE)
	e.settle = s1
	var e0 := smoothstep(0.0, 1.0, s0)
	var e1 := smoothstep(0.0, 1.0, s1)
	return 1.0 if s1 >= 1.0 else (e1 - e0) / maxf(1e-6, 1.0 - e0)


## Курс головы from доворачивает к want: доля угла FACE_FOLLOW в секунду, не быстрее FACE_MAX рад/с; ровно назад —
## разворот по горизонтали (вокруг вертикали). Оба — единичные.
static func turn_face(from: Vector3, want: Vector3, dt: float) -> Vector3:
	var ang := from.angle_to(want)
	if ang < 1e-5 or dt <= 0.0:
		return want if ang < 1e-5 else from
	var axis := from.cross(want)
	if axis.length_squared() < 1e-10:
		axis = Vector3.UP
	var step := minf(ang * (1.0 - exp(-FACE_FOLLOW * dt)), FACE_MAX * dt)
	return from.rotated(axis.normalized(), step).normalized()


## Звено k стеклоуста на стекле в момент t (мир).
static func latch_point(s: EcoLink.ShipState, k: int, t: float) -> Vector3:
	var wave := sin(k * 0.8 + t * 2.2) * LATCH_WAVE * minf(1.0, k / 3.0)
	var l := Vector3(LATCH_X0 + k * LATCH_DX, FRONT.y + wave, FRONT.z)
	return s.pos + l.rotated(Vector3.UP, s.yaw)


## Стеклоусты видны сонару и сканеру (E.scanTargets: r 1,3) — и в логове.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for e in eels:
		out.append(EcoWorld.target(ID, e.agent.p, 1.3))


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


## Тексты собираются в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой.
static func _catch_text(world: EcoWorld, grazer: bool) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var eel := w.nm(ID) if w else Species.called(ID)
		if grazer:
			var g := w.nm(EcoGrazer.ID, Species.Case.ACC) if w else Species.called(EcoGrazer.ID, Species.Case.ACC)
			return "%s утащил %s в расщелину" % [Species.cap(eel), g]
		var f := w.nm(EcoFish.ID, Species.Case.ACC) if w else Species.called(EcoFish.ID, Species.Case.ACC)
		return "%s схватил %s" % [Species.cap(eel), f]


static func _latch_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return "%s присосался к корпусу!" % Species.cap(w.nm(ID) if w else Species.called(ID))


static func _zap_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return "Разряд сбросил %s с корпуса" % (w.nm(ID, Species.Case.ACC) if w else Species.called(ID, Species.Case.ACC))
