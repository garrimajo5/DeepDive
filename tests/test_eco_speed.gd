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


## Мерка скорости машины: 40 раз толчки соседей в стае из 22 рыбок (чистый GDScript, как шаг мира); на ПК ≈ 0,6 мс.
const REF_PC_MS := 0.6
## Больше всего замеров шага живого мира на шумной машине (test_view_step_fits_frame, issue #732).
const ROUNDS := 12


static func _ref_ms() -> float:
	var r := EcoRandom.new(7)
	var pos := PackedVector3Array()
	var live := PackedByteArray()
	for i in 22:
		pos.append(Vector3(r.range_f(-1.5, 1.5), r.range_f(-1, 1), r.range_f(-1.5, 1.5)))
		live.append(1)
	var t0 := Time.get_ticks_usec()
	for i in 40:
		EcoFish._separation(pos, live)
	return (Time.get_ticks_usec() - t0) / 1000.0


func test_view_step_fits_frame() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	var ship := EcoLink.ShipState.new()
	ship.pos = Helm.Ship.START
	for i in 30:
		view.step(1.0 / 60.0, ship)
	# лучшее из пяти замеров по 60 кадров: на ПК было 3,2 мс, стало ≈ 0,95; со стеклоустами 1,4, после #133 — 1,1;
	# с радужниками, огнёвками и хватнями 1,47; дальние хватни, средние стаи радужников и стоящие стаи светляков
	# не переписываются каждый кадр — 1,29 (issue #133, второй раз). С ледокрылами и присосками шаг снова упёрся
	# в порог; скребуны и ежи, что едят на месте, больше не считают дно каждый подшаг (issue #133, третий раз).
	# Порог 2 мс — для машины не медленнее ПК; медленная машина CI (в полтора раза и больше) или занятая облачная
	# сессия получает порог по мерке скорости, замеренной между теми же кадрами: тест ловит рост шага, а не железо.
	# Муть Б3 у одиннадцати видов подняла шаг до ≈ 2,8 мс на облачной машине — буфер мути стал общим EcoDustBuffer
	# (растаявшее не переписывается, пустой пул не проходится), шаг снова ниже порога (issue #732). Шумная машина:
	# не меньше пяти замеров и до ROUNDS, пока лучший не уложится, — тест ловит устойчивый рост шага, а не всплеск.
	var best := INF
	var ref := INF
	var slow := 1.0
	var limit := 2.0
	for k in ROUNDS:
		ref = minf(ref, _ref_ms())
		var t0 := Time.get_ticks_usec()
		for i in 60:
			view.step(1.0 / 60.0, ship)
		best = minf(best, (Time.get_ticks_usec() - t0) / 60.0 / 1000.0)
		slow = maxf(1.0, ref / REF_PC_MS)
		limit = 2.0 * slow
		if k >= 4 and best < limit:
			break
	ok(best < limit, "шаг живого мира %.2f мс (< %.2f мс; машина медленнее ПК в %.2f раза)" % [best, limit, slow])
	view.queue_free()
	await frames(1)


## Дальний хватень вне луча переписывается раз в три кадра, близкий и освещённый — каждый (issue #133).
func test_far_hvaten_synced_every_third_frame() -> void:
	var hv := EcoHvaten.Anemone.new()
	hv.index = 2
	hv.base = Vector3(0, -30, 0)
	var far := Vector3(HvatenView.FAR + 5.0, -30, 0)
	var hits := 0
	for f in 30:
		if HvatenView.due(hv, far, f):
			hits += 1
	eq(hits, 10, "дальний — раз в три кадра")
	for f in 3:
		ok(HvatenView.due(hv, Vector3(10, -30, 0), f), "близкий — каждый кадр")
	hv.lit = true
	for f in 3:
		ok(HvatenView.due(hv, far, f), "в луче — каждый кадр")


func test_view_skips_far_hvaten() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	var hvv := view.hvaten_view
	var writes := 0
	for f in 30:
		hvv.tent_buffer[3] = 1234.0
		view.step(1.0 / 60.0, ship)
		if hvv.tent_buffer[3] != 1234.0:
			writes += 1
	eq(writes, 10, "хватень 0 вдали переписан 10 раз за 30 кадров")
	view.queue_free()
	await frames(1)


## Средняя стая радужников (между MID и FAR) — через кадр.
func test_mid_raduzh_swarm_synced_every_second_frame() -> void:
	var sw := EcoRaduzh.Swarm.new()
	sw.index = 0
	sw.c = Vector3(0, -30, 0)
	var mid := Vector3((RaduzhView.MID + RaduzhView.FAR) * 0.5, -30, 0)
	var hits := 0
	for f in 30:
		if RaduzhView.due(sw, mid, f):
			hits += 1
	eq(hits, 15, "средняя — через кадр")


## Стоящая (дальняя, копит время) стая светляков в буфере не переписывается, но съеденная рыбка гаснет сразу;
## шагнувшая — как EcoFishLook (issue #133).
func test_fish_view_keeps_waiting_shoals() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	view.step(1.0 / 60.0, ship)
	var fv := view.fish_view
	var waiting: EcoFish.Shoal = null
	for sh in view.fish.shoals:
		if sh.lag > 0.0:
			waiting = sh
			break
	if not ok(waiting != null, "есть стая, которая в этом кадре стоит"):
		view.queue_free()
		return
	var f0 := waiting.members[0] as EcoFish.Fish
	var f1 := waiting.members[1] as EcoFish.Fish
	fv.buffer[f0.index * FishView.STRIDE + 3] = 1234.0
	view.fish.kill(f1)
	fv.sync(view.world.time)
	eq(fv.buffer[f0.index * FishView.STRIDE + 3], 1234.0, "стоящая стая не переписана")
	near(FishView.transform_at(fv.buffer, f1.index).basis.x.length(), 0.0, 1e-9, "съеденная погасла сразу")
	var full := FishView.pack(view.fish, view.world.time)
	for sh in view.fish.shoals:
		if sh.lag > 0.0:
			continue
		for f: EcoFish.Fish in sh.members:
			var i := f.index * FishView.STRIDE
			for c in FishView.STRIDE:
				if not ok(absf(fv.buffer[i + c] - full[i + c]) < 1e-6, "шагнувшая стая — как pack"):
					view.queue_free()
					return
	view.queue_free()
	await frames(1)


func test_mid_shoal_steps_every_second_frame() -> void:
	var w := _world(EcoFish.HOMES[0] + Vector3(0, 0, 70))  # стая 0 — между MID и FAR
	var sh := (w.systems[0] as EcoFish).shoals[0]
	var d := sh.center.distance_to(w.ship.pos)
	ok(d > EcoFish.MID and d < EcoFish.FAR, "стая в средней дали: %.0f м" % d)
	var moves := 0
	for i in 300:
		var before := (sh.members[0] as EcoFish.Fish).agent.p
		w.step(1.0 / 60.0)
		if (sh.members[0] as EcoFish.Fish).agent.p != before:
			moves += 1
	ok(moves >= 149 and moves <= 151, "шагов %d из 300 кадров (через кадр)" % moves)


## Нераскрытая пузырчатка и подушка без чернил буфер облака не переписывают (issue #133); лопнула — пишется.
func test_quiet_clouds_skip_buffers() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	view.step(1.0 / 60.0, ship)
	var bv := view.bladder_view
	var bl := view.bladders.bushes[0]
	var si := bl.index * EcoBladder.SPORES * BladderView.STRIDE_C
	bv.spore_buffer[si + 3] = 42.0
	var cv := view.cushion_view
	var cu := view.cushions.cushions[0]
	var ci := cu.index * EcoCushion.INK_N * CushionView.STRIDE_C
	cv.ink_buffer[ci + 3] = 42.0
	view.step(1.0 / 60.0, ship)
	eq(bv.spore_buffer[si + 3], 42.0, "споры спрятаны — буфер не переписан")
	eq(cv.ink_buffer[ci + 3], 42.0, "чернил нет — буфер не переписан")
	view.bladders.pop(view.world, bl, false)
	view.cushions.squeeze(view.world, cu, true)
	view.world.run(0.5)
	view.step(1.0 / 60.0, ship)
	ok(bv.spore_buffer[si + 3] != 42.0, "лопнула — споры пишутся")
	ok(cv.ink_buffer[ci + 3] != 42.0, "чернила — облако пишется")
	near(BladderView.transform_at(bv.spore_buffer, bl.index * EcoBladder.SPORES).basis.x.length(), 1.0, 1e-6)
	bl.life = 0.0
	cu.ink = 0.0
	view.step(1.0 / 60.0, ship)
	near(BladderView.transform_at(bv.spore_buffer, bl.index * EcoBladder.SPORES).basis.x.length(), 0.0, 1e-6,
		"облако ушло — споры снова спрятаны")
	near(CushionView.transform_at(cv.ink_buffer, cu.index * EcoCushion.INK_N).basis.get_scale().x, 0.0, 1e-6,
		"чернила ушли — пятна спрятаны")
	view.queue_free()
	await frames(1)


func test_far_raduzh_swarm_synced_every_third_frame() -> void:
	var sw := EcoRaduzh.Swarm.new()
	sw.index = 1
	sw.c = Vector3(0, -30, 0)
	var far := Vector3(RaduzhView.FAR + 10.0, -30, 0)
	var hits := 0
	for f in 30:
		if RaduzhView.due(sw, far, f):
			hits += 1
	eq(hits, 10, "дальняя тёмная стая — раз в три кадра")
	for f in 3:
		ok(RaduzhView.due(sw, Vector3(10, -30, 0), f), "близкая — каждый кадр")
	sw.glow = 0.3
	for f in 3:
		ok(RaduzhView.due(sw, far, f), "вспыхнувшая — каждый кадр")


## Скребун, что ест мох на месте, не пересчитывает дно (шум fbm) каждый подшаг (issue #133, третий раз).
func test_grazing_grazer_skips_ground() -> void:
	var calls := [0]
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float:
		calls[0] += 1
		return -30.0
	var moss := w.add(EcoMoss.new()) as EcoMoss
	var gz := w.add(EcoGrazer.new(moss)) as EcoGrazer
	for g in gz.all:
		g.agent.set_state(EcoAgent.State.GRAZE, 100.0)
		g.patch = moss.patches[0]
		g.patch.food = 1.0
	calls[0] = 0
	w.step(0.05)
	eq(calls[0], 0, "все едят на месте — дно не считают")
	gz.all[0].agent.set_state(EcoAgent.State.SEEK)
	gz.all[0].agent.p = moss.patches[0].pos + Vector3(10, 0, 0)
	w.step(0.05)
	eq(calls[0], 1, "идущий — считает")


## Ёж у ленты ест на месте и тоже не пересчитывает дно (issue #133, третий раз).
func test_eating_urchin_skips_ground() -> void:
	var calls := [0]
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float:
		calls[0] += 1
		return -30.0
	var fish := w.add(EcoFish.new()) as EcoFish
	var kelp := w.add(EcoKelp.new(fish)) as EcoKelp
	w.systems.erase(fish)   # рощи — у стай; сами светляки дно считают, здесь их шаг не нужен
	ok(not kelp.urchins.is_empty())
	for u in kelp.urchins:
		kelp.kill(u, 1e9)
	var u := kelp.urchins[0]
	u.alive = true
	u.goal = 0
	var s := kelp.groves[u.grove].stalks[0]
	s.f = 1.0
	s.eater = u.index
	u.pos = Vector3(s.pos.x, u.pos.y, s.pos.z)
	calls[0] = 0
	w.step(0.05)
	eq(calls[0], 0, "ёж ест на месте — дно не считает")


## Медленный кадр до SLOW_STEP мир проходит одним подшагом (issue #713): кадр 55 мс не удваивает шаг мира.
func test_slow_frame_one_substep() -> void:
	var w := EcoWorld.new()
	w.reset()
	w.step(1.0 / 60.0)
	eq(w.steps, 1, "обычный кадр — один подшаг")
	w.step(0.055)
	eq(w.steps, 2, "кадр 55 мс — тоже один подшаг")
	w.step(EcoWorld.SLOW_STEP)
	eq(w.steps, 3, "кадр SLOW_STEP — один подшаг")
	w.step(0.1)
	eq(w.steps, 5, "кадр 100 мс — два подшага по 50 мс")
	near(w.time, 1.0 / 60.0 + 0.055 + EcoWorld.SLOW_STEP + 0.1, 1e-6, "время мира — всё время кадров")


## После долгой заминки мир в кадре догоняет не больше FRAME_CAP — не десяток подшагов разом (issue #713).
func test_view_caps_long_frame() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	var ship := EcoLink.ShipState.new()
	ship.pos = Helm.Ship.START
	view.step(1.0 / 60.0, ship)
	var t := view.world.time
	var s := view.world.steps
	view.step(1.5, ship)
	near(view.world.time - t, EcoWorld.FRAME_CAP, 1e-6, "заминка 1,5 с — мир прошёл FRAME_CAP")
	ok(view.world.steps - s <= int(ceil(EcoWorld.FRAME_CAP / EcoWorld.SLOW_STEP)), "подшагов не больше 4")
	view.step(0.1, ship)
	near(view.world.time - t, EcoWorld.FRAME_CAP + 0.1, 1e-6, "обычный кадр — всё время")
	view.queue_free()
	await frames(1)


## Весь мир на длинном подшаге SLOW_STEP не разлетается: существа на месте, числа конечные.
func test_world_steady_on_slow_step() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	var ship := EcoLink.ShipState.new()
	ship.pos = Helm.Ship.START
	for i in int(40.0 / EcoWorld.SLOW_STEP):
		view.step(EcoWorld.SLOW_STEP, ship)
	eq(view.world.steps, int(40.0 / EcoWorld.SLOW_STEP), "каждый кадр — один подшаг")
	var bad := 0
	for a in view.world.agents:
		var p := a.p
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)) or absf(p.x) > 400.0 or absf(p.z) > 400.0 \
				or p.y > 5.0 or p.y < Seabed.height(p.x, p.z) - 3.0:
			bad += 1
			if bad <= 3:
				ok(false, "%s в %s" % [a.species, p])
	eq(bad, 0, "все %d существ в воде над дном" % view.world.agents.size())
	view.queue_free()
	await frames(1)
