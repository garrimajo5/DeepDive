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
## Три рощи на переходе 00 → 01 (#1400, постановка в docs/urovni/sloj-1.md): густая сторона прохода — восточная, от
## огнецвета у старта (EcoCoral.BASES[1]) мимо трубного органа (EcoOrgan.SPOTS[1]) к стае 5 у 01; западная остаётся
## открытым обходом. Третья — впереди середины перехода (t ≈ 0,72), чтобы из середины у оси взгляда пилота справа
## стояла заросль, а не пустой песок. Края рощ — в ROUTE_GAP от прямой 00 → 01, свободный габарит прохода не трогают.
const ROUTE: Array[Vector2] = [Vector2(36.0, 38.0), Vector2(45.0, 14.0), Vector2(47.0, -4.0)]
const ROUTE_GAP := 11.0
## Рощи без своей стаи (x, z): Тихая заводь 09 (EcoCove, #831) — ежи там пасутся, а прятаться в ней некому;
## две у террасы врат 07 — рама позади арки (EcoGate, #831); три — на переходе 00 → 01 (ROUTE).
const EXTRA: Array[Vector2] = [EcoCove.KELP, EcoGate.KELP[0], EcoGate.KELP[1], ROUTE[0], ROUTE[1], ROUTE[2]]
## Лент в роще и радиус рощи (KELP_N, KELP_R); ежей у рощи (URCH_N).
const KELP_N := 34
const KELP_R := 7.0
const URCH_N := 7
## Корпус раздвигает ленты (Б3): корабль, опустившийся к роще, шёл сквозь ленты — они проходили сквозь обшивку.
## Лента клонится от основания так, чтобы её точки на долях LEAN_PROBE длины были вне корпуса с запасом LEAN_GAP
## (`EcoHull.touches`), — к борту, у которого стоит, и по ходу корабля (LEAN_ALONG). Не круче LEAN_MAX; клонится
## быстро (LEAN_IN рад/с), выпрямляется медленно (LEAN_OUT) — лента пружинит. Рощи дальше HULL_NEAR от корабля
## не проверяются; в вид — только сдвиг больше LEAN_REDRAW.
const LEAN_PROBE: Array[float] = [0.45, 0.7, 1.0]
const LEAN_GAP := 0.15
const LEAN_MAX := 1.35
const LEAN_IN := 4.0
const LEAN_OUT := 0.6
const LEAN_ALONG := 0.8
const LEAN_TURN := 6.0
const LEAN_REDRAW := 0.01
const LEAN_STEPS := 7
## Полуширина корпуса для выбора борта (меньше — лента у киля клонится больше по ходу).
const LEAN_SIDE := 2.5
## Дальше этого от середины рощи до корабля ленты не достать: корпус + круг рощи + самая высокая лента.
const HULL_NEAR := EcoHull.BOUND + KELP_R + H_MAX
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
## Скорость ежа меняется не быстрее ACCEL (м/с²): трогается и останавливается за секунду, а не рывком 0 → 0,3 м/с
## за шаг (план реализма Б3); за ARRIVE (м) до места, где встанет, сбавляет ход, но не медленнее CREEP — доползает.
const ACCEL := 0.3
const ARRIVE := 0.6
const CREEP := 0.03
## Первые секунды мира ежи пасутся молча — без «graze» и строки «Новое наблюдение» (как EcoGrazer.START_QUIET): с
## плавным разгоном ближний к старту ёж доходит до ленты на 5-й с и перебивал строку приборов.
const START_QUIET := 8.0
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
## Ленточник глушит шум (бестиарий, #1338): корабль в густой роще — ближе KELP_R + MUFFLE_PAD к середине по
## горизонтали и не выше MUFFLE_UP над её дном (лента до 5,5 м, корабль держится в 3 м над дном) — хищник не слышит
## двигатели. Свет, сонар и светящийся след ленты не прячут. Объеденная роща (cover < COVER_MIN) не глушит.
const MUFFLE_PAD := 1.5
const MUFFLE_UP := 7.5
## Наблюдение «kelp» у серпохвоста — раз в MUFFLE_CD у рощи.
const MUFFLE_CD := 40.0


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
	## Корпус клонит ленту (Б3, `EcoKelp.part_hull`): угол от вертикали, рад, и куда — горизонталь мира.
	var lean := 0.0
	var lean_dir := Vector3.FORWARD
	## Наклон, с которым лента нарисована.
	var lean_drawn := 0.0


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
	## Пауза наблюдения «ленточник заглушил двигатели» (muffled).
	var muffle_cd := 0.0
	var stalks: Array[Stalk] = []
	## Ленты рощи пора переписать в буфер вида (KelpView.sync переписывает только такие рощи).
	var redraw := true
	## Хоть одна лента рощи наклонена корпусом — рощу шагать, даже когда корабль ушёл.
	var bent := false


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
	## Скорость сейчас (м/с), догоняет want_speed не быстрее ACCEL.
	var speed := 0.0
	## Фаза покачивания (рисунок).
	var phase := 0.0
	## Где последний раз смотрели дно под ежом и его высота (`EcoKelp.urchin_floor`, issue #1247).
	var gx := INF
	var gz := INF
	var gh := 0.0
	## Уклон дна в этой точке (м на м по x и z): между точками ёж идёт по нему (`urchin_floor`, #1400).
	var sx := 0.0
	var sz := 0.0
	## Чем прежний уклон разошёлся с дном в новой точке (м): гаснет за следующий шаг пути, а не скачком.
	var go := 0.0
	## Набранное время вдали (EcoLod): шагает реже, догоняя пропущенное.
	var lag := 0.0


var groves: Array[Grove] = []
var urchins: Array[Urchin] = []
## Светляки, у чьих стай растут рощи.
var fish: EcoFish
## Лента нарисована не с той густотой — сцена перерисует ленточник (сбрасывает KelpView).
var dirty := true

var _rnd: EcoRandom
var _spots: Array[Vector3]
var _ground: Callable
## Шаги модуля с reset — очередь ежей вдали (EcoLod).
var _tick := 0


## prey_fish — светляки мира (подключены раньше); spots — свои середины рощ (для тестов), пусто — у стай 1 и 2
## и в местах EXTRA.
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
	_tick = 0
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
		for xz in EXTRA:
			places.append(Vector3(xz.x, fish.shoals[0].home.y - 3.5, xz.y))
			owners.append(null)
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
			u.graze_cd = START_QUIET
			urchins.append(u)


## Ёж вдали шагает реже (EcoLod): ползёт 0,3 м/с у дна в мути, а высота дна под ним (шум fbm) — самое дорогое в шаге.
func step(world: EcoWorld, dt: float) -> void:
	for u in urchins:
		if EcoLod.wait(u.pos.distance_to(world.ship.pos), _tick, u.index, u.lag, dt):
			u.lag += dt
			continue
		var h := dt + u.lag
		u.lag = 0.0
		_step_urchin(world, u, h)
	_tick += 1
	for gr in groves:
		gr.msg_cd -= dt
		gr.graze_cd -= dt
		gr.muffle_cd -= dt
		var sum := 0.0
		for s in gr.stalks:
			if s.eater < 0:
				s.f = minf(1.0, s.f + dt * REGROW)  # объеденный ленточник медленно отрастает
			if absf(s.f - s.drawn) > REDRAW:
				dirty = true
				gr.redraw = true
			sum += s.f
		gr.cover = (sum / KELP_N - F_MIN) / (1.0 - F_MIN)
		part_hull(world, gr, dt)


## Корпус раздвигает ленты рощи gr (Б3): наклон каждой ленты догоняет нужный (`hull_lean`) — быстро к большему,
## медленно назад. Роща далеко от корабля и прямая — ничего не считаем.
func part_hull(world: EcoWorld, gr: Grove, dt: float) -> void:
	var near := gr.center.distance_to(world.ship.pos) < HULL_NEAR
	if not near and not gr.bent:
		return
	gr.bent = false
	for s in gr.stalks:
		var want := 0.0
		if near:
			var lean := hull_lean(s, world.ship)
			want = lean.x
			if want > 0.0:
				var d := Vector3(lean.y, 0.0, lean.z)
				if s.lean < 0.02:
					s.lean_dir = d
				else:
					s.lean_dir = s.lean_dir.lerp(d, minf(1.0, LEAN_TURN * dt)).normalized()
		if want > s.lean:
			s.lean = minf(want, s.lean + LEAN_IN * dt)
		else:
			s.lean = maxf(want, s.lean - LEAN_OUT * dt)
		if s.lean > 0.0:
			gr.bent = true
		if absf(s.lean - s.lean_drawn) > LEAN_REDRAW or (s.lean == 0.0 and s.lean_drawn != 0.0):
			s.lean_drawn = s.lean
			dirty = true
			gr.redraw = true


## Высота ленты s по густоте — как в `stalk_basis`.
static func stalk_len(s: Stalk) -> float:
	return s.height * (0.35 + 0.65 * s.f)


## Куда ленте s клониться от корпуса корабля ship: (угол, направление x, 0, z). Угол 0 — корпус ленту не задевает.
## Направление — к своему борту (по x ленты в осях корабля) и по ходу; угол — наименьший, при котором точки
## LEAN_PROBE вне корпуса (делением отрезка пополам, LEAN_STEPS раз); не выходит и при LEAN_MAX — LEAN_MAX.
static func hull_lean(s: Stalk, ship: EcoLink.ShipState) -> Vector3:
	var ln := stalk_len(s)
	var up := stalk_basis(s, false).y.normalized()
	if not _stalk_hits(s.pos, up, ln, ship):
		return Vector3.ZERO
	var l := EcoHull.to_ship(s.pos, ship.pos, ship.yaw)
	var fwd := -1.0 if ship.speed >= -0.05 else 1.0   # по ходу корабля: нос в −Z
	var dl := Vector3(clampf(l.x / LEAN_SIDE, -1.0, 1.0), 0.0, fwd * LEAN_ALONG).normalized()
	var d := dl.rotated(Vector3.UP, ship.yaw)
	var axis := Vector3.UP.cross(d).normalized()
	var lo := 0.0
	var hi := LEAN_MAX
	if _stalk_hits(s.pos, up.rotated(axis, hi), ln, ship):
		return Vector3(LEAN_MAX, d.x, d.z)
	for i in LEAN_STEPS:
		var mid := (lo + hi) * 0.5
		if _stalk_hits(s.pos, up.rotated(axis, mid), ln, ship):
			lo = mid
		else:
			hi = mid
	return Vector3(hi, d.x, d.z)


static func _stalk_hits(base: Vector3, up: Vector3, ln: float, ship: EcoLink.ShipState) -> bool:
	for k in LEAN_PROBE:
		if EcoHull.touches(base + up * (ln * k), ship.pos, ship.yaw, LEAN_GAP):
			return true
	return false


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
	u.speed = 0.0


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
	var stop := EAT_DIST if u.goal >= 0 else 0.05
	if dist < stop:
		u.speed = move_toward(u.speed, 0.0, ACCEL * dt)   # доползает на CREEP — гаснет без рывка
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
		u.speed = move_toward(u.speed, want_speed(speed, dist - stop), ACCEL * dt)
		u.pos += d * (minf(dist, u.speed * dt) / dist)
		# высоту дна — только когда ёж сдвинулся: дно — шум fbm, стоящему ежу пересчитывать нечего (issue #133)
		u.pos.y = urchin_floor(u) + UP


## Нужная скорость ежа: full — ход к ленте или блуждание, rest — сколько осталось до места, где он встанет (м).
static func want_speed(full: float, rest: float) -> float:
	return maxf(full * clampf(rest / ARRIVE, 0.0, 1.0), CREEP)


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


## Густая роща, в которой корабль (#1338): шум его двигателей хищникам не слышен. null — корабль не в роще
## или роща объедена шипоежами.
func muffling(world: EcoWorld) -> Grove:
	var p := world.ship.pos
	for gr in groves:
		if gr.cover < COVER_MIN or p.y - gr.center.y > MUFFLE_UP:
			continue
		if Vector2(p.x - gr.center.x, p.z - gr.center.z).length() < KELP_R + MUFFLE_PAD:
			return gr
	return null


## Ленточник спрятал двигатели от серпохвоста: watching — тот патрулирует или проверяет звук. Наблюдение
## серпохвоста «kelp» — раз в MUFFLE_CD у рощи (биолог объясняет укрытие по журналу).
func muffled(world: EcoWorld, gr: Grove, watching: bool) -> void:
	if watching and gr.muffle_cd <= 0.0:
		gr.muffle_cd = MUFFLE_CD
		world.emit(EcoPred.ID, "kelp", gr.center, _muffle_text(world))


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
## Наклон корпусом (`Stalk.lean`) — поворотом мира от вертикали к `lean_dir`; with_lean = false — своя стойка ленты.
static func stalk_basis(s: Stalk, with_lean := true) -> Basis:
	var r := Basis(Vector3.RIGHT, s.tilt_x) * Basis(Vector3.UP, s.yaw) * Basis(Vector3.BACK, s.tilt_z)
	if with_lean and s.lean > 0.0:
		r = Basis(Vector3.UP.cross(s.lean_dir).normalized(), s.lean) * r
	return r * Basis.from_scale(Vector3(0.12 + 0.88 * s.f, stalk_len(s), 1.0))


## Цвет ленты: от голого стебля к своему цвету по густоте.
static func stalk_color(s: Stalk) -> Color:
	return BARE.lerp(s.color, s.f)


## Ёж в момент t: медленно поворачивается и чуть дышит (urchinRender).
static func urchin_basis(u: Urchin, t: float) -> Basis:
	return Basis(Vector3.UP, t * 0.1 + u.phase) * Basis.from_scale(Vector3.ONE * (1.0 + sin(t * 1.5 + u.phase) * 0.04))


## Дно под ежом u: пересчитывается, только когда ёж отполз дальше URCHIN_GROUND_STEP от прошлой точки (issue #1247:
## ползущие ежи звали fbm каждый шаг — 14 вызовов за кадр при 0,005 м хода за кадр). В точке запоминается и уклон
## (ещё два чтения дна в URCHIN_SLOPE_D по x и z в сторону хода), между точками ёж идёт по нему (#1400: по запомненной
## высоте ёж на крутом склоне съезжал ступенькой 0,14 м за кадр раз в 11 кадров, `tools/jerk.gd scena=2 move=3`).
## Дно — сетка треугольников: перешёл на треугольник с другим уклоном — в новой точке высота разойдётся с уклоном
## прежней; расхождение `go` гаснет за следующий шаг пути, а не скачком. Шаг вдвое длиннее прежнего 0,1 м — чтений
## дна на метр пути в полтора раза больше, а не втрое.
const URCHIN_GROUND_STEP := 0.2
const URCHIN_SLOPE_D := 0.02
## Расхождение больше — не догоняет плавно, а встаёт на дно (появился заново, перенесли): ниже UP — ушёл бы в грунт.
const URCHIN_GO_MAX := UP
func urchin_floor(u: Urchin) -> float:
	var dx := u.pos.x - u.gx
	var dz := u.pos.z - u.gz
	var d2 := dx * dx + dz * dz
	if d2 > URCHIN_GROUND_STEP * URCHIN_GROUND_STEP:
		var was := u.gh + u.sx * dx + u.sz * dz + u.go * _go_k(d2)
		var ax := -URCHIN_SLOPE_D if dx < 0.0 else URCHIN_SLOPE_D
		var az := -URCHIN_SLOPE_D if dz < 0.0 else URCHIN_SLOPE_D
		u.gx = u.pos.x
		u.gz = u.pos.z
		u.gh = _floor(u.pos.x, u.pos.z, u.pos.y - UP)
		u.sx = (_floor(u.pos.x + ax, u.pos.z, u.gh) - u.gh) / ax
		u.sz = (_floor(u.pos.x, u.pos.z + az, u.gh) - u.gh) / az
		u.go = was - u.gh if is_finite(was) and absf(was - u.gh) < URCHIN_GO_MAX else 0.0
		return u.gh + u.go
	return u.gh + u.sx * dx + u.sz * dz + u.go * _go_k(d2)


## Доля расхождения `go`, что осталась, когда ёж отполз от точки на √d2.
static func _go_k(d2: float) -> float:
	return maxf(0.0, 1.0 - sqrt(d2) / URCHIN_GROUND_STEP)


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


static func _muffle_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var pred := w.nm(EcoPred.ID) if w else Species.called(EcoPred.ID)
		return "Ленточник глушит двигатели — %s не слышит корабль" % pred


static func _bare_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var known := w != null and w.scanned.is_valid() and bool(w.scanned.call(ID))
		return "Ленточник объеден %s: стае негде спрятаться" % ("шипоежами" if known else "морскими ежами")
