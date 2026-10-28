extends TestCase
## LOD шага мира вдали (issue #850, EcoLod): скребуны и стайки монетников дальше 50 м от корабля шагают через шаг,
## дальше 100 м — раз в три шага, набирая пропущенное время; вблизи — каждый шаг; подошёл корабль — догоняют.

const FLAT := -40.0


## Ровное дно, считающее свои вызовы (calls[0]).
static func _floor(calls: Array) -> Callable:
	return func(_x: float, _z: float) -> float:
		calls[0] += 1
		return FLAT


func test_wait_by_distance() -> void:
	# вблизи — никогда не ждёт
	for t in 6:
		ok(not EcoLod.wait(EcoLod.MID - 1.0, t, 0, 0.0, 0.05), "ближе MID шагает всегда")
	# дальше MID — через шаг, дальше FAR — раз в три
	var mid := 0
	var far := 0
	for t in 12:
		if not EcoLod.wait(EcoLod.MID + 10.0, t, 0, 0.0, 0.03):
			mid += 1
		if not EcoLod.wait(EcoLod.FAR + 10.0, t, 0, 0.0, 0.03):
			far += 1
	eq(mid, 12 / EcoLod.MID_EVERY)
	eq(far, 12 / EcoLod.FAR_EVERY)
	# фазы разнесены по номеру: соседние в один шаг не совпадают
	ok(EcoLod.wait(EcoLod.FAR + 10.0, 0, 1, 0.0, 0.03) != EcoLod.wait(EcoLod.FAR + 10.0, 0, 0, 0.0, 0.03))
	# набранное не больше LAG_MAX: длинный кадр — шаг раньше очереди
	ok(not EcoLod.wait(EcoLod.FAR + 10.0, 1, 0, EcoLod.LAG_MAX, 0.05), "шаг не длиннее LAG_MAX")


## Один скребун на ровном дне между двумя пятнами; корабль в ship.
func _grazer_world(ship: Vector3, calls: Array) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _floor(calls)
	w.ship.pos = ship
	var m := w.add(EcoMoss.new([Vector3(0, FLAT, 0), Vector3(0, FLAT, 30)] as Array[Vector3])) as EcoMoss
	for p in m.patches:
		p.food = 1.0
	var gr := w.add(EcoGrazer.new(m, 1)) as EcoGrazer
	w.reset()
	# ровно на первом пятне, идёт ко второму (30 м — за 2 с не дойдёт)
	var g := gr.all[0]
	g.agent.p = Vector3(0, FLAT + EcoGrazer.LIFT, 0)
	g.dir = 0.0
	g.patch = m.patches[1]
	g.agent.set_state(EcoAgent.State.SEEK)
	return w


func test_far_grazer_steps_less_often_same_path() -> void:
	var near_calls := [0]
	var far_calls := [0]
	var near := _grazer_world(Vector3(0, FLAT + 20.0, 15), near_calls)
	var far := _grazer_world(Vector3(0, FLAT, 15 + EcoLod.FAR + 60.0), far_calls)
	var gn: EcoGrazer = near.systems[1]
	var gf: EcoGrazer = far.systems[1]
	near_calls[0] = 0
	far_calls[0] = 0
	for i in 60:
		near.step(1.0 / 30.0)
		far.step(1.0 / 30.0)
	var an := gn.all[0].agent
	var af := gf.all[0].agent
	ok(an.state == EcoAgent.State.SEEK and af.state == EcoAgent.State.SEEK, "идут к пятну")
	ok(af.p.distance_to(an.p) < 0.1, "вдали — тот же путь, только реже: %.3f" % af.p.distance_to(an.p))
	ok(an.p.distance_to(Vector3(0, FLAT, 0)) > 1.0, "скребун прошёл путь")
	eq(near_calls[0], 60, "вблизи дно читается каждый шаг")
	ok(far_calls[0] <= 60 / EcoLod.FAR_EVERY + 1, "вдали — раз в три шага: %d" % far_calls[0])


func test_far_grazer_catches_up_when_ship_comes() -> void:
	var calls := [0]
	var w := _grazer_world(Vector3(0, FLAT, 15 + EcoLod.FAR + 60.0), calls)
	var g: EcoGrazer = w.systems[1]
	for i in 32:
		w.step(1.0 / 30.0)
	ok(g.all[0].lag > 0.0, "вдали набрал время")
	w.ship.pos = Vector3(0, FLAT + 10.0, 10)
	w.step(1.0 / 30.0)
	near(g.all[0].lag, 0.0, 1e-6, "корабль рядом — догнал набранное")


## Три стайки монетников на ровном дне в 60 м друг от друга.
func _coin_world(ship: Vector3) -> EcoWorld:
	var spots: Array[Vector3] = [Vector3(-60, FLAT, 0), Vector3(0, FLAT, 0), Vector3(60, FLAT, 0)]
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return FLAT
	w.ship.pos = ship
	var m := w.add(EcoMoss.new(spots)) as EcoMoss
	w.add(EcoCoins.new(m, null, spots))
	return w


func test_far_school_steps_less_often() -> void:
	# корабль над стайкой 1: она шагает каждый кадр, стайки 0 и 2 (в 60…70 м) — через шаг
	var w := _coin_world(Vector3(0, FLAT + 30.0, 0))
	w.reset()
	var c: EcoCoins = w.systems[1]
	var moved := [0, 0, 0]
	var prev: Array[Vector3] = []
	for cn in c.coins:
		prev.append(cn.pos)
	for i in 40:
		w.step(1.0 / 30.0)
		var seen := [false, false, false]
		for cn in c.coins:
			if cn.pos != prev[cn.index]:
				seen[cn.school] = true
			prev[cn.index] = cn.pos
		for s in 3:
			if seen[s]:
				moved[s] += 1
	eq(moved[1], 40, "стайка у корабля — каждый шаг")
	eq(moved[0], 40 / EcoLod.MID_EVERY, "стайка в 60 м — через шаг")
	eq(moved[2], 40 / EcoLod.MID_EVERY, "стайка в 60 м — через шаг")


func test_far_school_still_grazes_and_glazun_hunts() -> void:
	# корабль далеко: рыбки шагают реже, но так же пасутся, а глазун хватает проплывающих
	var w := _coin_world(Vector3(500, -30, 500))
	w.reset()
	var c: EcoCoins = w.systems[1]
	var ambush := 0
	for i in 3000:
		w.step(0.05)
		for ev in w.bus.pending:
			if ev.note == "ambush":
				ambush += 1
		w.bus.pending.clear()
		for cn in c.coins:
			if cn.alive:
				ok(Vector2(cn.pos.x - c.schools[cn.school].center.x, cn.pos.z - c.schools[cn.school].center.z).length() < 12.0,
					"рыбка у своего пятна")
	ok(ambush > 0, "глазун хватает и вдали: %d" % ambush)


## Роща ленточника с ежами на ровном дне в точке (0, 0); корабль в ship.
func _kelp_world(ship: Vector3, calls: Array) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _floor(calls)
	w.ship.pos = ship
	w.add(EcoKelp.new(null, [Vector3(0, FLAT, 0)] as Array[Vector3]))
	w.reset()
	calls[0] = 0
	return w


func test_far_urchins_step_less_often() -> void:
	# корабль над рощей: ежи шагают каждый кадр; в 160 м — раз в три, высоту дна считают реже
	var near_calls := [0]
	var far_calls := [0]
	var near := _kelp_world(Vector3(0, FLAT + 20.0, 0), near_calls)
	var far := _kelp_world(Vector3(0, FLAT, EcoLod.FAR + 60.0), far_calls)
	for i in 60:
		near.step(1.0 / 30.0)
		far.step(1.0 / 30.0)
	ok(near_calls[0] > 0, "вблизи ежи ползут — дно под ними считается")
	ok(far_calls[0] * 2 <= near_calls[0] + 1, "вдали дно реже: %d против %d" % [far_calls[0], near_calls[0]])
	# путь тот же: набранное время догоняется, ежи уходят от появления так же далеко
	var kn: EcoKelp = near.systems[0]
	var kf: EcoKelp = far.systems[0]
	for i in kn.urchins.size():
		var a := kn.urchins[i]
		var b := kf.urchins[i]
		near(a.pos.distance_to(b.pos), 0.0, 0.3, "ёж %d вдали на том же пути" % i)


func test_eel_far_waits_but_at_ship_steps_every_time() -> void:
	# логово в 160 м: стеклоуст на броске шагает раз в три; плывёт к носу — каждый шаг
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return FLAT
	w.ship.pos = Vector3(0, FLAT + 10.0, EcoLod.FAR + 60.0)
	var eels := w.add(EcoEel.new(null, null, [Vector3(0, FLAT, 0)] as Array[Vector3])) as EcoEel
	w.reset()
	var e := eels.eels[0]
	e.mode = EcoEel.Mode.RETURN
	e.agent.p = e.lair + Vector3(20, 0, 0)
	var moved := 0
	for i in 12:
		var was := e.agent.p
		w.step(1.0 / 30.0)
		if e.agent.p != was:
			moved += 1
	eq(moved, 12 / EcoLod.FAR_EVERY, "вдали — раз в три шага")
	e.mode = EcoEel.Mode.TO_SHIP
	e.timer = 100.0
	e.lag = 0.0
	moved = 0
	for i in 12:
		var was := e.agent.p
		w.step(1.0 / 30.0)
		if e.agent.p != was:
			moved += 1
	eq(moved, 12, "к носу — каждый шаг")
