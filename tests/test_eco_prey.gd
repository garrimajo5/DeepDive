extends TestCase
## Поиск добычи (issue #848): EcoFish.nearest_fish перебирает только стаи, до которых можно дотянуться (рамка
## Shoal.spread), фильтр укрытий зовёт только для рыбок ближе лучшей; хищник в патруле ищет раз в SEEK_EVERY,
## фильтр укрытий собирается раз за шаг. Итог поиска — тот же, что у полного перебора.


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = Helm.Ship.START
	w.add(EcoFish.new())
	w.reset()
	return w


func _fish(w: EcoWorld) -> EcoFish:
	return w.systems[0] as EcoFish


## Полный перебор, как было до #848: ближайшая живая не дальше radius, мимо skip.
static func _brute(fish: EcoFish, pos: Vector3, radius: float, skip: Callable = Callable()) -> EcoFish.Fish:
	var best: EcoFish.Fish = null
	var bd := radius
	for f in fish.all:
		if not f.agent.alive or (skip.is_valid() and skip.call(f)):
			continue
		var d := f.agent.p.distance_to(pos)
		if d < bd:
			bd = d
			best = f
	return best


func test_same_as_full_search() -> void:
	var w := _world()
	var fish := _fish(w)
	var r := EcoRandom.new(11)
	var hits := 0
	var skip := func(f: EcoFish.Fish) -> bool: return f.index % 3 == 0
	for k in 40:
		w.run(0.5)
		for kill_i in 2:  # кто-то съеден — рамка не должна прятать живых
			fish.kill(fish.all[r.index(fish.all.size())])
		for q in 25:
			var sh: EcoFish.Shoal = fish.shoals[r.index(fish.shoals.size())]
			var pos := sh.center + Vector3(r.range_f(-25, 25), r.range_f(-6, 6), r.range_f(-25, 25))
			var radius := r.range_f(1.0, 30.0)
			var want := _brute(fish, pos, radius)
			if not ok(fish.nearest_fish(pos, radius) == want, "без фильтра — как полный перебор"):
				return
			if not ok(fish.nearest_fish(pos, radius, skip) == _brute(fish, pos, radius, skip), "с фильтром — тоже"):
				return
			if want:
				hits += 1
	ok(hits > 100, "проверка не пустая: найдено %d раз" % hits)


func test_spread_covers_alive_fish() -> void:
	var w := _world()
	var fish := _fish(w)
	for k in 30:
		w.run(0.3)
		for sh in fish.shoals:
			for f: EcoFish.Fish in sh.members:
				if f.agent.alive and not ok(f.agent.p.distance_to(sh.center) <= sh.spread + 1e-3,
						"стая %d: рыбка в рамке" % sh.index):
					return


func test_skip_called_only_for_closer_fish() -> void:
	var w := _world()
	var fish := _fish(w)
	w.run(1.0)
	var calls := [0]
	var none := func(_f: EcoFish.Fish) -> bool:
		calls[0] += 1
		return false
	var sh := fish.shoals[0]
	var f := fish.nearest_fish(sh.center, 30.0, none)
	ok(f != null, "у центра стаи рыбка есть")
	# раньше фильтр звали для каждой живой рыбки отмели: ~190 раз
	ok(calls[0] <= EcoFish.PER_SHOAL * 2, "фильтр укрытий — только для ближних: %d вызовов" % calls[0])
	calls[0] = 0
	ok(fish.nearest_fish(Vector3(280, -20, 280), 10.0, none) == null, "в пустом углу — никого")
	eq(calls[0], 0, "вдали от стай фильтр не зовут")


func test_moved_by_hand_needs_bounds() -> void:
	var w := _world()
	var fish := _fish(w)
	w.run(1.0)
	var f := fish.all[3]
	var far := Vector3(-200, -30, 200)
	f.agent.p = far
	fish.bounds()
	ok(fish.nearest_fish(far, 1.0) == f, "после bounds() переставленную рыбку видно")


func test_dead_shoal_skipped() -> void:
	var w := _world()
	var fish := _fish(w)
	w.run(0.5)
	var sh := fish.shoals[1]
	for f: EcoFish.Fish in sh.members:
		fish.kill(f)
	fish.bounds()
	near(sh.spread, -1.0, 1e-6, "живых нет — рамки нет")
	var f := fish.nearest_fish(sh.center, 2.0)
	ok(f == null or f.shoal != sh, "мёртвую стаю не перебирают")


func test_client_apply_refreshes_bounds() -> void:
	var host := _world()
	var guest := _world()
	host.run(3.0)
	var data := EcoLink.pack_world(host.agents, host.systems, host.ship.pos, EcoLink.NET_R, host.time)
	EcoLink.apply_world(guest.agents, guest.systems, data, guest)
	var fish := _fish(guest)
	for sh in fish.shoals:
		for f: EcoFish.Fish in sh.members:
			if f.agent.alive and not ok(f.agent.p.distance_to(sh.center) <= sh.spread + 1e-3,
					"у гостя рамка стаи %d после кадра хоста" % sh.index):
				return


# ---------- Хищник ----------

func _with_pred() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var fish := w.add(EcoFish.new()) as EcoFish
	var preds := w.add(EcoPred.new(fish)) as EcoPred
	w.reset()
	for pr in preds.all:
		pr.hunger = -10.0
		pr.cooldown = 100.0
	var pr := preds.all[0]
	pr.agent.p = Vector3(250, -20, -250)  # вдали от стай — добычи нет
	pr.agent.goal = pr.agent.p
	pr.hunger = 0.9
	return w


func test_pred_seeks_every_quarter_second() -> void:
	var w := _with_pred()
	var preds := w.systems[1] as EcoPred
	var pr := preds.all[0]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "добычи рядом нет")
	near(pr.seek_t, EcoPred.SEEK_EVERY, 1e-5, "искал на первом шаге — следующий раз через SEEK_EVERY")
	w.step(EcoWorld.MAX_STEP)
	near(pr.seek_t, EcoPred.SEEK_EVERY - EcoWorld.MAX_STEP, 1e-5, "на втором шаге не ищет")
	ok(not preds._skip.is_valid(), "фильтр укрытий не хранится между шагами (нет цикла ссылок)")


func test_pred_finds_prey_within_seek_delay() -> void:
	var w := _with_pred()
	var preds := w.systems[1] as EcoPred
	var fish := w.systems[0] as EcoFish
	var pr := preds.all[0]
	w.step(EcoWorld.MAX_STEP)  # поиск прошёл впустую
	pr.agent.p = fish.shoals[0].center + Vector3(5, 0, 0)
	pr.agent.goal = pr.agent.p
	var t := 0.0
	while pr.mode != EcoPred.Mode.HUNT and t < 1.0:
		w.step(EcoWorld.MAX_STEP)
		t += EcoWorld.MAX_STEP
	eq(pr.mode, EcoPred.Mode.HUNT, "добыча рядом — охотится")
	ok(t <= EcoPred.SEEK_EVERY + EcoWorld.MAX_STEP + 1e-4, "не позже SEEK_EVERY и шага: %.2f с" % t)
