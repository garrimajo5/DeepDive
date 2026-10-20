class_name EcoKelp
extends EcoSystem
## Ленточник и шипоежи (initKelp, urchinUpdate, kelpUpdate, kelpShelter в js/creatures.js; бестиарий): заросли
## ленточника у стай светляков 1 и 2 — по 34 ленты в круге 7 м. Напуганная стая прячется в густом ленточнике,
## и серпохвост её теряет (EcoPred: охота сорвана, наблюдение светляка «kelp», раз в 40 с у рощи). Шипоежи — по 7
## у каждой рощи — ползают по дну и объедают ленты до голых стеблей (наблюдение «graze»); объеденный ленточник
## медленно отрастает. Если густота рощи ниже 0,45, стае негде спрятаться: хищник ловит в ней светляка, наблюдение
## «bare». Шипоежи заметны сканеру, стадо у рощи — одной отметкой на сонаре. Кольчужник (раскалывает ежей) —
## отдельный модуль, ему — kill().

const ID := "ezh"
## Рощи — у этих стай светляков (E.shoals[gi + 1]); стай должно быть хотя бы три.
const SHOALS: Array[int] = [1, 2]
const MIN_SHOALS := 3
## Лент в роще и радиус рощи (KELP_N, KELP_R); ежей у рощи (URCH_N).
const KELP_N := 34
const KELP_R := 7.0
const URCH_N := 7
## Густота рощи, ниже которой стае негде спрятаться (COVER_MIN).
const COVER_MIN := 0.45
## Лента: высота 3…5,5 м, ширина 0,45 м; основание на 0,1 м в дне; наклон до ±0,08 рад.
const H_MIN := 3.0
const H_MAX := 5.5
const WIDTH := 0.45
const SINK := 0.1
const TILT := 0.08
## Цвета лент (pal) и голых стеблей (bare).
const PALETTE: Array[Color] = [Color("5f9a4a"), Color("8aa83c"), Color("3f8f7a")]
const BARE := Color(0.32, 0.26, 0.16)
## Объеденная лента — не тоньше 0,15; ёж ест 0,035 в секунду, отрастает 0,005 в секунду (без едока).
const F_MIN := 0.15
const EAT_RATE := 0.035
const REGROW := 0.005
## Ёж выбирает ленты гуще 0,3; ест ближе 0,45 м; ползёт к ленте 0,3 м/с, бродит 0,15 м/с (новая точка — через 6…12 с).
const PICK_F := 0.3
const EAT_DIST := 0.45
const SPEED := 0.3
const WANDER_SPEED := 0.15
## Ёж — на 0,15 м над дном; появляется в кольце 0,6 · KELP_R … KELP_R + 2 м от середины рощи.
const UP := 0.15
## Наблюдение «graze» — раз в 60 с от ежа, текст — раз в 90 с у рощи; «kelp» и «bare» — раз в 40 с у рощи.
const GRAZE_CD := 60.0
const GRAZE_SAY_CD := 90.0
const MSG_CD := 40.0
## Стая прячется: светляк ближе KELP_R + 1 м к середине рощи по горизонтали и ниже 5 м над её дном.
const SHELTER_PAD := 1.0
const SHELTER_UP := 5.0
## Светляк «в роще» для наблюдения «bare» (groveOf) — ближе KELP_R + 1,5 м.
const GROVE_PAD := 1.5
## Изменение ленты, после которого её надо перерисовать (s.drawn).
const REDRAW := 0.01


## Лента ленточника.
class Stalk:
	extends RefCounted
	var pos := Vector3.ZERO
	var height := 4.0
	## Густота 0,15…1 (1 — целая лента).
	var f := 1.0
	var tilt_x := 0.0
	var tilt_z := 0.0
	var yaw := 0.0
	var color := Color.WHITE
	## Номер ежа, который её ест (−1 — никто): номер, а не ссылка, чтобы не было цикла RefCounted.
	var eater := -1
	## Густота, с которой лента нарисована.
	var drawn := 1.0


## Роща ленточника у стаи.
class Grove:
	extends RefCounted
	var index := 0
	var center := Vector3.ZERO
	## Стая, у которой растёт (null — свои места из теста).
	var shoal: EcoFish.Shoal
	## Густота 0…1: (средняя густота лент − 0,15) / 0,85.
	var cover := 1.0
	var msg_cd := 0.0
	var graze_cd := 0.0
	var stalks: Array[Stalk] = []


## Шипоёж.
class Urchin:
	extends RefCounted
	var index := 0
	var grove := 0
	var alive := true
	## Сколько ещё до появления заново (съеденный).
	var respawn := 0.0
	var pos := Vector3.ZERO
	## Лента, к которой ползёт (−1 — бродит).
	var goal := -1
	var wander := Vector3.ZERO
	var wander_t := 0.0
	var graze_cd := 0.0
	## Фаза покачивания (рисунок).
	var phase := 0.0


var groves: Array[Grove] = []
var urchins: Array[Urchin] = []
## Светляки, у чьих стай растут рощи.
var fish: EcoFish
## Лента нарисована не с той густотой — сцена перерисует ленточник (сбрасывает KelpView).
var dirty := true

var _rnd: EcoRandom
var _spots: Array[Vector3]
var _ground: Callable


## prey_fish — светляки мира (подключены раньше); spots — свои середины рощ (для тестов), пусто — у стай 1 и 2.
func _init(prey_fish: EcoFish = null, spots: Array[Vector3] = []) -> void:
	fish = prey_fish
	_spots = spots.duplicate()


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 9013) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	_ground = world.ground
	groves.clear()
	urchins.clear()
	dirty = true
	var places: Array[Vector3] = []
	var owners: Array[EcoFish.Shoal] = []
	if not _spots.is_empty():
		places = _spots.duplicate()
		for p in places:
			owners.append(null)
	elif fish and fish.shoals.size() >= MIN_SHOALS:
		for si in SHOALS:
			places.append(fish.shoals[si].home)
			owners.append(fish.shoals[si])
	for gi in places.size():
		var gr := Grove.new()
		gr.index = gi
		gr.shoal = owners[gi]
		var c := places[gi]
		gr.center = Vector3(c.x, _floor(c.x, c.z, c.y), c.z)
		for k in KELP_N:
			var a := k * 2.39996
			var r := sqrt((k + 0.5) / KELP_N) * KELP_R
			var s := Stalk.new()
			var x := gr.center.x + cos(a) * r
			var z := gr.center.z + sin(a) * r
			s.pos = Vector3(x, _floor(x, z, gr.center.y) - SINK, z)
			s.height = _rnd.range_f(H_MIN, H_MAX)
			s.tilt_x = _rnd.range_f(-TILT, TILT)
			s.tilt_z = _rnd.range_f(-TILT, TILT)
			s.yaw = _rnd.range_f(0, TAU)
			s.color = _rnd.pick(PALETTE)
			gr.stalks.append(s)
		groves.append(gr)
		for k in URCH_N:
			var u := Urchin.new()
			u.index = urchins.size()
			u.grove = gi
			u.phase = _rnd.range_f(0, 6)
			_spawn(u)
			urchins.append(u)


func step(world: EcoWorld, dt: float) -> void:
	for u in urchins:
		_step_urchin(world, u, dt)
	for gr in groves:
		gr.msg_cd -= dt
		gr.graze_cd -= dt
		var sum := 0.0
		for s in gr.stalks:
			if s.eater < 0:
				s.f = minf(1.0, s.f + dt * REGROW)  # объеденный ленточник медленно отрастает
			if absf(s.f - s.drawn) > REDRAW:
				dirty = true
			sum += s.f
		gr.cover = (sum / KELP_N - F_MIN) / (1.0 - F_MIN)


## Ёж появляется в кольце вокруг рощи и бродит (urchSpawn).
func _spawn(u: Urchin) -> void:
	var gr := groves[u.grove]
	var a := _rnd.range_f(0, TAU)
	var r := _rnd.range_f(KELP_R * 0.6, KELP_R + 2.0)
	var x := gr.center.x + cos(a) * r
	var z := gr.center.z + sin(a) * r
	u.pos = Vector3(x, _floor(x, z, gr.center.y) + UP, z)
	u.alive = true
	u.goal = -1
	u.wander_t = 0.0
	u.graze_cd = 0.0


func _step_urchin(world: EcoWorld, u: Urchin, dt: float) -> void:
	if not u.alive:
		u.respawn -= dt
		if u.respawn <= 0.0:
			_spawn(u)
		return
	var gr := groves[u.grove]
	u.graze_cd -= dt
	if u.goal >= 0 and gr.stalks[u.goal].f <= F_MIN:  # лента объедена до стебля — ищет следующую
		gr.stalks[u.goal].eater = -1
		u.goal = -1
	if u.goal < 0:
		var bd := INF
		for k in gr.stalks.size():
			var s := gr.stalks[k]
			if s.f <= PICK_F or (s.eater >= 0 and s.eater != u.index):
				continue
			var d := s.pos.distance_squared_to(u.pos)
			if d < bd:
				bd = d
				u.goal = k
		if u.goal >= 0:
			gr.stalks[u.goal].eater = u.index
	var speed := SPEED
	var to: Vector3
	if u.goal >= 0:
		to = gr.stalks[u.goal].pos
	else:
		u.wander_t -= dt
		if u.wander_t <= 0.0:
			u.wander_t = _rnd.range_f(6, 12)
			u.wander = Vector3(gr.center.x + _rnd.range_f(-KELP_R, KELP_R), 0.0, gr.center.z + _rnd.range_f(-KELP_R, KELP_R))
		to = u.wander
		speed = WANDER_SPEED
	var d := Vector3(to.x - u.pos.x, 0.0, to.z - u.pos.z)
	var dist := d.length()
	if u.goal >= 0 and dist < EAT_DIST:
		var s := gr.stalks[u.goal]
		s.f = maxf(F_MIN, s.f - dt * EAT_RATE)
		if u.graze_cd <= 0.0:
			u.graze_cd = GRAZE_CD
			var say := gr.graze_cd <= 0.0
			if say:
				gr.graze_cd = GRAZE_SAY_CD
			world.emit(ID, "graze", u.pos, _graze_text(world) if say else Callable())
	elif dist > 0.05:
		u.pos += d * (minf(dist, speed * dt) / dist)
	u.pos.y = _floor(u.pos.x, u.pos.z, u.pos.y - UP) + UP


## Съесть ежа (кольчужник): пропадает на respawn секунд, лента свободна.
func kill(u: Urchin, respawn: float) -> void:
	if not u.alive:
		return
	u.alive = false
	u.respawn = respawn
	if u.goal >= 0:
		groves[u.grove].stalks[u.goal].eater = -1
		u.goal = -1


## Роща, в которой прячется светляк (kelpShelter): стая напугана, роща её, ленточник ещё густой. null — не прячется.
func shelter(f: EcoFish.Fish) -> Grove:
	var sh := f.shoal
	if sh == null or sh.alarm <= 0.0:
		return null
	var p := f.agent.p
	for gr in groves:
		if gr.shoal != sh or gr.cover < COVER_MIN:
			continue
		if Vector2(p.x - gr.center.x, p.z - gr.center.z).length() < KELP_R + SHELTER_PAD and p.y < gr.center.y + SHELTER_UP:
			return gr
	return null


## Роща, в которой точка p (groveOf); null — ни в одной.
func grove_at(p: Vector3) -> Grove:
	for gr in groves:
		if Vector2(p.x - gr.center.x, p.z - gr.center.z).length() < KELP_R + GROVE_PAD:
			return gr
	return null


## Серпохвост потерял стаю в ленточнике: наблюдение светляка «kelp», раз в MSG_CD у рощи.
func hid_fish(world: EcoWorld, gr: Grove) -> void:
	if gr.msg_cd <= 0.0:
		gr.msg_cd = MSG_CD
		world.emit(EcoFish.ID, "kelp", gr.center, _kelp_text(world))


## Серпохвост поймал светляка в точке p: если это объеденная роща — наблюдение «bare», раз в MSG_CD у рощи.
func caught_at(world: EcoWorld, p: Vector3) -> void:
	var gr := grove_at(p)
	if gr and gr.cover < COVER_MIN and gr.msg_cd <= 0.0:
		gr.msg_cd = MSG_CD
		world.emit(ID, "bare", gr.center, _bare_text(world))


## Сканер берёт в прицел каждого живого ежа (r 0,6), а на сонаре стадо у рощи — одна отметка в середине живых ежей
## (как стая светляков): голограмма держит EcoLink.NEAR ближних не больше Sonar.MAX_BLIPS, и 14 ежей вытеснили бы
## с неё хищников.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	var sums: Array[Vector3] = []
	var n: Array[int] = []
	sums.resize(groves.size())
	n.resize(groves.size())
	for u in urchins:
		if u.alive:
			out.append(EcoWorld.target(ID, u.pos, 0.6, false))
			sums[u.grove] += u.pos
			n[u.grove] += 1
	for gi in groves.size():
		if n[gi] > 0:
			out.append(EcoWorld.target(ID, sums[gi] / n[gi], 1.0, true, true))


## Сколько живых ежей.
func alive_count() -> int:
	var n := 0
	for u in urchins:
		if u.alive:
			n += 1
	return n


## Наклон и масштаб ленты (setKelp): повороты X · Y · Z, ширина 0,12 + 0,88f, высота h · (0,35 + 0,65f).
static func stalk_basis(s: Stalk) -> Basis:
	var r := Basis(Vector3.RIGHT, s.tilt_x) * Basis(Vector3.UP, s.yaw) * Basis(Vector3.BACK, s.tilt_z)
	return r * Basis.from_scale(Vector3(0.12 + 0.88 * s.f, s.height * (0.35 + 0.65 * s.f), 1.0))


## Цвет ленты: от голого стебля к своему цвету по густоте.
static func stalk_color(s: Stalk) -> Color:
	return BARE.lerp(s.color, s.f)


## Ёж в момент t: медленно поворачивается и чуть дышит (urchinRender).
static func urchin_basis(u: Urchin, t: float) -> Basis:
	return Basis(Vector3.UP, t * 0.1 + u.phase) * Basis.from_scale(Vector3.ONE * (1.0 + sin(t * 1.5 + u.phase) * 0.04))


func _floor(x: float, z: float, fallback: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else fallback


## Тексты собираются в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой.
static func _graze_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID) if w else Species.called(ID)
		return "%s объедает ленточник до стеблей" % Species.cap(name)


static func _kelp_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var fish_n := w.nm(EcoFish.ID) if w else Species.called(EcoFish.ID)
		var pred := w.nm(EcoPred.ID) if w else Species.called(EcoPred.ID)
		return "%s: стая спряталась в ленточнике, %s её потерял" % [Species.cap(fish_n), pred]


static func _bare_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var known := w != null and w.scanned.is_valid() and bool(w.scanned.call(ID))
		return "Ленточник объеден %s: стае негде спрятаться" % ("шипоежами" if known else "морскими ежами")
