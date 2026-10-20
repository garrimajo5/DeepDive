extends TestCase
## Шаг живого мира укладывается в кадр телефона (issue #77): светляки читают дно редко, дальние стаи ходят реже,
## соседи в стае считаются парами, буфер MultiMesh собирается без лишних вызовов, корпус не ищут вдали от корабля.


func _world(ship_pos: Vector3) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = ship_pos
	w.add(EcoFish.new())
	w.reset()
	return w


func test_fish_read_ground_rarely() -> void:
	var calls := [0]
	var w := EcoWorld.new()
	w.ground = func(x: float, z: float) -> float:
		calls[0] += 1
		return Seabed.height(x, z)
	w.ship.pos = Helm.Ship.START  # все стаи ближе FAR, кроме одной — шагают каждый кадр
	w.add(EcoFish.new())
	w.reset()
	calls[0] = 0
	for i in 60:
		w.step(1.0 / 60.0)
	# раньше — по вызову на рыбку за шаг: 132 × 60 = 7920
	ok(calls[0] < 132 * 60 / 4, "дно читается редко: %d вызовов за 60 шагов" % calls[0])
	for f: EcoFish.Fish in (w.systems[0] as EcoFish).all:
		var p := f.agent.p
		ok(p.y >= Seabed.height(p.x, p.z) + f.agent.clearance - 0.2, "рыбка не уходит под дно")


func test_agent_ground_cache() -> void:
	var calls := [0]
	var slope := func(x: float, _z: float) -> float:
		calls[0] += 1
		return x * 0.5
	var a := EcoAgent.new("fish", Vector3(0, 5, 0))
	near(a.ground_y(slope), 0.0, 1e-6, "первый раз — по дну")
	a.p.x += EcoAgent.GROUND_STEP * 0.5
	near(a.ground_y(slope), 0.0, 1e-6, "рядом — запомненное")
	eq(calls[0], 1, "дно не читали второй раз")
	a.p.x += EcoAgent.GROUND_STEP
	near(a.ground_y(slope), a.p.x * 0.5, 1e-6, "отплыло — читает заново")
	eq(calls[0], 2)
	var flat := func(_x: float, _z: float) -> float:
		return -10.0
	near(a.ground_y(flat), -10.0, 1e-6, "другое дно — читает заново")


func test_far_shoals_step_every_third_frame() -> void:
	var w := _world(Vector3(500, 0, 500))  # все стаи дальше FAR
	var fish := w.systems[0] as EcoFish
	var moves: Array[int] = []
	moves.resize(fish.shoals.size())
	moves.fill(0)
	for i in 300:
		var before: Array[Vector3] = []
		for sh in fish.shoals:
			before.append((sh.members[0] as EcoFish.Fish).agent.p)
		w.step(1.0 / 60.0)
		for k in fish.shoals.size():
			if (fish.shoals[k].members[0] as EcoFish.Fish).agent.p != before[k]:
				moves[k] += 1
	for k in moves.size():
		ok(moves[k] >= 99 and moves[k] <= 101, "стая %d: шагов %d из 300 кадров (каждый третий)" % [k, moves[k]])
	# в одном кадре — не все дальние стаи сразу
	var first := []
	for sh in fish.shoals:
		first.append(sh.lag)
	ok(first.max() - first.min() > 0.01, "дальние стаи сдвинуты по фазе")


func test_near_shoal_steps_every_frame() -> void:
	var w := _world(EcoFish.HOMES[0] + Vector3(0, 0, 30))
	var f := ((w.systems[0] as EcoFish).shoals[0].members[0] as EcoFish.Fish).agent
	for i in 30:
		var before := f.p
		w.step(1.0 / 60.0)
		if not ok(f.p != before, "ближняя стая плывёт каждый кадр"):
			return


func test_shoal_coming_near_catches_up_lag() -> void:
	var w := _world(Vector3(500, 0, 500))
	var sh := (w.systems[0] as EcoFish).shoals[0]
	w.step(1.0 / 60.0)
	ok(sh.lag > 0.0, "дальняя стая копит время")
	w.ship.pos = sh.center + Vector3(0, 0, 30)
	w.step(1.0 / 60.0)
	near(sh.lag, 0.0, 1e-9, "подошли — догнала набранное")


func test_separation_by_pairs() -> void:
	var pos := PackedVector3Array([Vector3.ZERO, Vector3(0.5, 0, 0), Vector3(5, 0, 0), Vector3(0, 0.3, 0)])
	var live := PackedByteArray([1, 1, 1, 0])
	var sep := EcoFish._separation(pos, live)
	var want := Vector3(-0.5, 0, 0) * (1.8 / (0.25 + 0.05))
	ok(sep[0].distance_to(want) < 1e-4, "толчок по формуле 1,8 / (d² + 0,05)")
	ok((sep[0] + sep[1]).length() < 1e-5, "пара толкается поровну и в разные стороны")
	eq(sep[2], Vector3.ZERO, "дальний сосед не толкает")
	eq(sep[3], Vector3.ZERO, "съеденная не толкается и не толкает")


func test_pack_same_as_look() -> void:
	var w := _world(Vector3(500, 0, 500))
	var fish := w.systems[0] as EcoFish
	w.run(3.0)
	fish.shoals[1].alarm = 2.0
	fish.kill(fish.all[5])
	var t := w.time
	var buf := FishView.pack(fish, t)
	for f in fish.all:
		var tr := FishView.transform_at(buf, f.index)
		var b := EcoFishLook.basis(f, t)
		if not ok(tr.basis.x.distance_to(b.x) < 1e-5 and tr.basis.y.distance_to(b.y) < 1e-5
				and tr.basis.z.distance_to(b.z) < 1e-5, "basis рыбки %d как EcoFishLook" % f.index):
			return
		ok(tr.origin.distance_to(f.agent.p) < 1e-4, "место")
		var c := FishView.stripe_at(buf, f.index)
		var want := EcoFishLook.stripe(f)
		ok(absf(c.r - want.r) + absf(c.g - want.g) + absf(c.b - want.b) < 1e-5, "цвет полос (с тревогой)")


func test_hull_bound_covers_hull() -> void:
	ok(EcoHull.BOUND >= EcoHull.REACH + EcoHull.CENTER.length(), "BOUND — с запасом на любой курс")
	var ship := Vector3(10, -20, 5)
	for yaw in [0.0, 1.3, 3.1]:
		ok(not EcoHull.push_out(ship + Vector3(0, HullPlan.CENTER_Y, 0), ship, yaw, 0.3).is_empty(),
			"точка в корпусе выталкивается")
		eq(EcoHull.push_out(ship + Vector3(EcoHull.BOUND + 1.0, 0, 0), ship, yaw, 0.3), [], "вдали — пусто")


func test_view_step_fits_frame() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	var ship := EcoLink.ShipState.new()
	ship.pos = Helm.Ship.START
	for i in 30:
		view.step(1.0 / 60.0, ship)
	# лучшее из пяти замеров по 60 кадров: на ПК было 3,2 мс, стало ≈ 0,95; запас на медленную машину CI
	var best := INF
	for k in 5:
		var t0 := Time.get_ticks_usec()
		for i in 60:
			view.step(1.0 / 60.0, ship)
		best = minf(best, (Time.get_ticks_usec() - t0) / 60.0 / 1000.0)
	ok(best < 2.0, "шаг живого мира %.2f мс (< 2 мс)" % best)
	view.queue_free()
	await frames(1)
