class_name EcoGrazer
extends EcoSystem
## Скребуны — донные панцирники на шести лапах (initGrazers/grazerUpdate в js/creatures.js, Unity `Core/EcoGrazer.cs`).
## Десять скребунов ходят по дну от пятна мха к пятну (EcoMoss) со скоростью 0,9 м/с, плавно поворачивая к цели.
## Ближе 1,6 м к пятну — пасутся 8–14 с и едят мох (0,05 в секунду, пятно тускнеет), потом выбирают следующее: где
## больше еды и ближе, с долей случая. Объеденное ниже 0,08 пятно бросают сразу. Начав пастись, скребун шлёт событие
## «graze» — не чаще раза в 45 с. Хищник берёт скребуна через nearest_grazer и kill; съеденный через 40–60 с появляется
## у случайного пятна.

const ID := "grazer"
## Сколько скребунов.
const COUNT := 10
## Шаг (м/с), поворот (доля разницы курса в секунду).
const WALK_SPEED := 0.9
const TURN_RATE := 1.5
## Плавность (grafika-plan-eco, «Плавность поведения»): поворот не быстрее TURN_MAX (рад/с); скорость меняется не
## быстрее ACCEL (м/с²) — трогается и тормозит за секунду, а не рывком; за ARRIVE (м) до края пятна сбавляет шаг до
## доли ARRIVE_MIN; цель за спиной — сначала доворачивает почти на месте (доля скорости cos угла, не меньше TURN_SLOW).
const TURN_MAX := 1.2
const ACCEL := 0.9
const ARRIVE := 2.5
const ARRIVE_MIN := 0.2
const TURN_SLOW := 0.25
## Ближе этого к середине пятна — пасётся (м).
const REACH := 1.6
## Сколько мха съедает за секунду.
const EAT_RATE := 0.05
## Пятно беднее этого бросает.
const LEAVE := 0.08
## Пауза между сообщениями «объедает мох» у одного скребуна (с).
const GRAZE_COOLDOWN := 45.0
## Первые секунды мира скребуны молчат (как #1001: старт не перебивает строку приборов) — с плавным подходом к пятну
## ближний к старту скребун начинает пастись на третьей секунде.
const START_QUIET := 8.0
## Над дном (м).
const LIFT := 0.1
## Уклон под шагом разошёлся с прошлым больше этого — шаг пересчитывается по найденному (`walk`, перегиб дна).
const SLOPE_REDO := 0.3


## Скребун: существо мира, курс и пятно, к которому идёт или на котором пасётся.
class Grazer:
	extends RefCounted
	var agent: EcoAgent
	var index := 0
	## Курс: вперёд — (sin dir, cos dir) по (x, z).
	var dir := 0.0
	var patch: EcoMoss.Patch
	## Секунды до следующего сообщения «объедает мох».
	var graze_cd := 0.0
	## Набранное время вдали (EcoLod): шагает реже, догоняя пропущенное.
	var lag := 0.0
	## Уклон дна по прошлому шагу (подъём к шагу по горизонтали): шаг идёт вдоль дна (`walk`, Б3) — раньше на
	## буграх рифа (уклон до 2:1) скребун взбегал и скатывался до 2 м/с при шаге 0,9 м/с. Уклон берётся с прошлого
	## шага, а не лишней выборкой дна: шум fbm — самое дорогое в шаге (issue #133).
	var slope := 0.0

	func grazing() -> bool:
		return agent.alive and agent.state == EcoAgent.State.GRAZE


var all: Array[Grazer] = []
var moss: EcoMoss

var _count: int
var _rnd: EcoRandom
## Шаги модуля с reset — очередь скребунов вдали (EcoLod).
var _tick := 0


func _init(moss_system: EcoMoss, n: int = COUNT) -> void:
	assert(moss_system != null, "EcoGrazer: нужен мох")
	moss = moss_system
	_count = n


## Своё зерно скребунов.
static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7003) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	_tick = 0
	all.clear()
	var pp := moss.patches
	if pp.is_empty():
		return
	for i in _count:
		var pt := pp[(i * 2) % pp.size()]
		var x := pt.pos.x + _rnd.range_f(-3, 3)
		var z := pt.pos.z + _rnd.range_f(-3, 3)
		var a := world.spawn(ID, Vector3(x, _ground_y(world, x, z, pt.pos.y), z))
		a.clearance = LIFT
		var g := Grazer.new()
		g.agent = a
		g.index = i
		g.dir = _rnd.range_f(0, 6.28)
		g.graze_cd = maxf(START_QUIET, _rnd.range_f(0, 20))
		a.set_state(EcoAgent.State.SEEK)
		g.patch = _pick_patch(g)
		if g.patch:
			a.goal = g.patch.pos
		all.append(g)


## Шаг, к которому скребун разгоняется или тормозит: до пятна d (м) по середине, цель на угол da (рад) от курса.
static func want_speed(d: float, da: float) -> float:
	var arrive := clampf((d - REACH) / ARRIVE, ARRIVE_MIN, 1.0)
	var aim := maxf(TURN_SLOW, cos(clampf(absf(da), 0.0, PI / 2.0)))
	return WALK_SPEED * arrive * aim


## Высота скребуна: дно мира + 0,1 м; без дна мира — fallback + 0,1 м.
static func _ground_y(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	var h: float = world.ground.call(x, z) if world.ground.is_valid() else fallback
	return h + LIFT


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Следующее пятно (pickPatch): больше еды и ближе, ×0,7–1,3 случая; не то же самое.
func _pick_patch(g: Grazer) -> EcoMoss.Patch:
	var best: EcoMoss.Patch = null
	var bs := -1.0
	var p := g.agent.p
	for pt in moss.patches:
		if pt == g.patch:
			continue
		var s := pt.food / (1.0 + _flat(pt.pos, p) / 25.0) * _rnd.range_f(0.7, 1.3)
		if s > bs:
			bs = s
			best = pt
	return best


## Съеденный скребун пропадает на 40–60 с, потом появляется у случайного пятна.
func kill(g: Grazer) -> void:
	if not g.agent.alive:
		return
	g.agent.alive = false
	g.agent.v = Vector3.ZERO
	g.agent.timer = _rnd.range_f(40, 60)


## Ближайший живой скребун не дальше radius (null — нет).
func nearest_grazer(pos: Vector3, radius: float) -> Grazer:
	var best: Grazer = null
	var bd := radius
	for g in all:
		if not g.agent.alive:
			continue
		var d := g.agent.p.distance_to(pos)
		if d < bd:
			bd = d
			best = g
	return best


## Живые скребуны видны сонару и сканеру.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for g in all:
		if g.agent.alive:
			out.append(EcoWorld.target(ID, g.agent.p, 1.4))


## Скребун вдали шагает реже (EcoLod): у дна в мути, сдвиг на 3 см за кадр не виден, а дно под ним (шум fbm) —
## самое дорогое в шаге.
func step(world: EcoWorld, dt: float) -> void:
	for g in all:
		if EcoLod.wait(g.agent.p.distance_to(world.ship.pos), _tick, g.index, g.lag, dt):
			g.lag += dt
			continue
		var h := dt + g.lag
		g.lag = 0.0
		_step_grazer(world, g, h)
	_tick += 1


## Текст «объедает мох» собирается в момент показа; мир — слабой ссылкой (событие лежит в шине мира).
static func _graze_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID) if w else Species.called(ID)
		return "%s объедает светящийся мох" % Species.cap(name)


func _step_grazer(world: EcoWorld, g: Grazer, dt: float) -> void:
	var a := g.agent
	var moved := false
	if not a.alive:
		if a.timer > 0.0 or moss.patches.is_empty():
			return
		var pt: EcoMoss.Patch = _rnd.pick(moss.patches)
		a.p = Vector3(pt.pos.x + _rnd.range_f(-3, 3), pt.pos.y, pt.pos.z + _rnd.range_f(-3, 3))
		a.alive = true
		g.slope = 0.0
		moved = true
		g.patch = _pick_patch(g)
		a.set_state(EcoAgent.State.SEEK)
	g.graze_cd -= dt
	if a.state != EcoAgent.State.GRAZE:
		var tp := g.patch
		if tp == null:
			g.patch = _pick_patch(g)
			a.v = Vector3.ZERO
			return
		a.goal = tp.pos
		var dx := tp.pos.x - a.p.x
		var dz := tp.pos.z - a.p.z
		var d := sqrt(dx * dx + dz * dz)
		if d < REACH:
			a.set_state(EcoAgent.State.GRAZE, _rnd.range_f(8, 14))
			a.v = Vector3.ZERO
			if g.graze_cd <= 0.0:
				g.graze_cd = GRAZE_COOLDOWN
				world.emit(ID, "graze", a.p, _graze_text(world))
		else:
			var da := atan2(dx, dz) - g.dir
			da = atan2(sin(da), cos(da))
			g.dir += clampf(da * minf(1.0, dt * TURN_RATE), -TURN_MAX * dt, TURN_MAX * dt)
			var sp := move_toward(a.v.length(), want_speed(d, da), ACCEL * dt)
			a.v = Vector3(sin(g.dir) * sp, 0, cos(g.dir) * sp)
			var was := a.p
			a.p = walk(world, a.p, a.v * dt, g.patch.pos.y if g.patch else a.p.y - LIFT, g.slope)
			var fl := _flat(a.p, was)
			if fl > 1e-5:
				g.slope = (a.p.y - was.y) / fl
	else:
		EcoMoss.eat(g.patch, dt * EAT_RATE)
		if a.expired() or g.patch.food < LEAVE:
			g.patch = _pick_patch(g)
			a.set_state(EcoAgent.State.SEEK)
	if not moved:
		return   # стоит, ест или идёт (`walk` уже поставил на дно): шум fbm не пересчитываем (issue #133)
	a.p.x = clampf(a.p.x, -EcoAgent.EDGE, EcoAgent.EDGE)
	a.p.z = clampf(a.p.z, -EcoAgent.EDGE, EcoAgent.EDGE)
	a.p.y = _ground_y(world, a.p.x, a.p.z, g.patch.pos.y if g.patch else a.p.y - LIFT)


## Шаг по дну из from на move (по горизонтали, м) при уклоне slope (подъём к шагу по горизонтали, с прошлого шага):
## новое место на дне + LIFT. Шаг по горизонтали укорачивается в √(1 + slope²) раз — путь вдоль дна длиной move:
## скребун идёт по бугру своим шагом, а не взбегает. fallback — высота дна без дна мира (тесты).
## Уклон с прошлого шага отстаёт на перегибе: на гребне бугра (вверх 2:1 → вниз 2:1) и у подножия шаг по уклону
## ≈ 0 шёл полным шагом по горизонтали — вдоль дна до 2 м/с вместо 0,9 (Б3: скребун на гребне соскакивал). Если
## уклон под шагом разошёлся с прошлым больше SLOPE_REDO, шаг пересчитывается по уклону, что он нашёл (одна выборка
## дна сверх обычной — только на перегибе).
static func walk(world: EcoWorld, from: Vector3, move: Vector3, fallback: float, slope: float = 0.0) -> Vector3:
	var p := _on_ground(world, from, move / sqrt(1.0 + slope * slope), fallback)
	var fl := _flat(p, from)
	if fl > 1e-5:
		var found := (p.y - from.y) / fl
		if absf(found - slope) > SLOPE_REDO:
			p = _on_ground(world, from, move / sqrt(1.0 + found * found), fallback)
	return p


static func _on_ground(world: EcoWorld, from: Vector3, move: Vector3, fallback: float) -> Vector3:
	var x := clampf(from.x + move.x, -EcoAgent.EDGE, EcoAgent.EDGE)
	var z := clampf(from.z + move.z, -EcoAgent.EDGE, EcoAgent.EDGE)
	return Vector3(x, _ground_y(world, x, z, fallback), z)
