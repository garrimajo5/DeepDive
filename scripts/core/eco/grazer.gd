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
## Ближе этого к середине пятна — пасётся (м).
const REACH := 1.6
## Сколько мха съедает за секунду.
const EAT_RATE := 0.05
## Пятно беднее этого бросает.
const LEAVE := 0.08
## Пауза между сообщениями «объедает мох» у одного скребуна (с).
const GRAZE_COOLDOWN := 45.0
## Над дном (м).
const LIFT := 0.1


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
		g.graze_cd = _rnd.range_f(0, 20)
		a.set_state(EcoAgent.State.SEEK)
		g.patch = _pick_patch(g)
		if g.patch:
			a.goal = g.patch.pos
		all.append(g)


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
			g.dir += da * minf(1.0, dt * TURN_RATE)
			a.v = Vector3(sin(g.dir) * WALK_SPEED, 0, cos(g.dir) * WALK_SPEED)
			a.p = Vector3(a.p.x + a.v.x * dt, a.p.y, a.p.z + a.v.z * dt)
			moved = true
	else:
		EcoMoss.eat(g.patch, dt * EAT_RATE)
		if a.expired() or g.patch.food < LEAVE:
			g.patch = _pick_patch(g)
			a.set_state(EcoAgent.State.SEEK)
	if not moved:
		return   # стоит (ест или только что дошёл): дно под ним то же — шум fbm не пересчитываем (issue #133)
	a.p.x = clampf(a.p.x, -EcoAgent.EDGE, EcoAgent.EDGE)
	a.p.z = clampf(a.p.z, -EcoAgent.EDGE, EcoAgent.EDGE)
	a.p.y = _ground_y(world, a.p.x, a.p.z, g.patch.pos.y if g.patch else a.p.y - LIFT)
