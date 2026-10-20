extends TestCase
## Пиявник (setLeech, predUpdate, stationsUpdate в js/creatures.js; бестиарий): заражает серпохвоста — медленнее,
## голоднее, злее (видит корабль за 48 м), сытый плывёт на станцию чистки на вершине огнецвета, огнёвки снимают
## паразита; лента у жабр в сцене.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Ровное дно на −40 м, серпохвосты с пиявниками; станции — tops (пусто — станций нет). Корабль далеко, тихо.
func _world(tops: Array[Vector3] = []) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var ps := w.add(EcoPred.new()) as EcoPred
	w.add(EcoLeech.new(ps, null, tops))
	return w


func _preds(w: EcoWorld) -> EcoPred:
	for s in w.systems:
		if s is EcoPred:
			return s
	return null


func _leeches(w: EcoWorld) -> EcoLeech:
	for s in w.systems:
		if s is EcoLeech:
			return s
	return null


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


func _step(w: EcoWorld) -> void:
	w.step(EcoWorld.MAX_STEP)


# ---------- Заражение ----------

func test_first_pred_infected_at_start() -> void:
	var w := _world()
	var all := _preds(w).all
	ok(all[0].leech, "первый серпохвост заражён с начала (setLeech(pr, i === 0))")
	for i in range(1, all.size()):
		ok(not all[i].leech, "остальные здоровы")
		ok(all[i].leech_cd >= 90.0 and all[i].leech_cd <= 160.0, "заразятся через 90…160 с: %s" % all[i].leech_cd)
		eq(all[i].station, -1)
	eq(_leeches(w).infected(), 1)
	w.reset()
	eq(_leeches(w).infected(), 1, "сброс мира — снова один заражённый")
	ok(_preds(w).all[0].leech)


func test_infests_after_timer() -> void:
	var w := _world()
	var pr := _preds(w).all[1]
	pr.leech_cd = 0.01
	_step(w)
	ok(pr.leech, "время вышло — пиявник присосался")
	var ev := _notes(w, "leech", "infest")
	eq(ev.size(), 1)
	ok(ev[0].text().contains("присосался к жабрам"), ev[0].text())
	ok(ev[0].is_observation(), "заметка журнала «присасывается к жабрам»")


func test_no_infest_at_station() -> void:
	var pr0 := _preds(_world()).all[1]
	var tops: Array[Vector3] = [pr0.agent.p + Vector3(6, 0, 0)]
	var w := _world(tops)
	var pr := _preds(w).all[1]
	pr.leech_cd = 0.01
	_step(w)
	ok(not pr.leech, "у станции чистки (ближе 14 м) не заражается")
	eq(_notes(w, "leech", "infest").size(), 0)


# ---------- Злее и медленнее ----------

func test_infected_sees_light_from_48() -> void:
	var w := _world()
	var all := _preds(w).all
	for pr in all:
		pr.hunger = 0.5
		pr.cooldown = 0.0
	var sick := all[0]
	w.ship.pos = sick.agent.p + Vector3(40, 0, 0)
	w.ship.light_on = true
	_step(w)
	eq(sick.mode, EcoPred.Mode.CHARGE, "заражённый видит свет за 40 м")
	var ev := _notes(w, "leech", "angry")
	eq(ev.size(), 1, "злее обычного — корабль дальше 32 м")
	ok(ev[0].text().contains("злее обычного"), ev[0].text())
	ok(ev[0].is_observation())
	eq(EcoPred.reach(sick), 48.0)
	eq(EcoPred.reach(all[1]), 32.0, "здоровый — 32 м")


func test_angry_once_a_minute() -> void:
	var w := _world()
	var pr := _preds(w).all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(40, 0, 0)
	w.ship.light_on = true
	_step(w)
	pr.cooldown = 0.0
	pr.mode = EcoPred.Mode.PATROL
	_step(w)
	eq(_notes(w, "leech", "angry").size(), 1, "не чаще раза в 60 с")
	near(pr.angry_cd, 60.0 - EcoWorld.MAX_STEP, 1e-4)


func test_infected_attacks_hungry_from_0_1() -> void:
	var w := _world()
	var all := _preds(w).all
	for pr in all:
		pr.hunger = 0.15
		pr.cooldown = 0.0
	w.ship.light_on = true
	w.ship.pos = all[0].agent.p + Vector3(20, 0, 0)
	_step(w)
	eq(all[0].mode, EcoPred.Mode.CHARGE, "заражённому хватает голода 0,15")

	w = _world()
	var healthy := _preds(w).all[1]
	healthy.hunger = 0.15
	healthy.cooldown = 0.0
	w.ship.light_on = true
	w.ship.pos = healthy.agent.p + Vector3(20, 0, 0)
	_step(w)
	eq(healthy.mode, EcoPred.Mode.PATROL, "здоровый с голодом 0,15 не нападает")


func test_infected_slower_and_hungrier() -> void:
	var w := _world()
	var all := _preds(w).all
	for pr in all:
		pr.hunger = 0.6  # голодный: на чистку не плывёт
		pr.agent.timer = 100.0
		pr.agent.goal = pr.agent.p + Vector3(0, 0, 200)
	var h0 := all[0].hunger
	var h1 := all[1].hunger
	w.run(5.0)
	near(all[0].agent.v.length(), EcoPred.PATROL_SPEED * EcoLeech.SLOW, 0.05, "заражённый плывёт на 0,75 скорости")
	near(all[1].agent.v.length(), EcoPred.PATROL_SPEED, 0.05)
	near(all[0].hunger - h0, 5.0 * EcoLeech.HUNGER_RATE, 1e-3, "голод растёт на 0,05/с")
	near(all[1].hunger - h1, 5.0 * EcoPred.HUNGER_RATE, 1e-3)


# ---------- Станция чистки ----------

func test_fed_infected_cleaned_at_station() -> void:
	var probe := _preds(_world()).all[0]
	var top := probe.agent.p + Vector3(30, 0, 0)
	var tops: Array[Vector3] = [top, Vector3(300, -30, 300)]
	var w := _world(tops)
	var pr := _preds(w).all[0]
	pr.hunger = 0.2
	_step(w)
	eq(pr.mode, EcoPred.Mode.CLEAN, "сытый заражённый плывёт на чистку")
	eq(pr.station, 0, "к ближайшей станции")
	eq(pr.agent.goal, top)
	eq(pr.agent.state, EcoAgent.State.SEEK)
	var st := _leeches(w).stations[0]
	var t := 0.0
	var was_busy := false
	while pr.leech and t < 40.0:
		_step(w)
		t += EcoWorld.MAX_STEP
		was_busy = was_busy or st.busy == pr.index
	ok(was_busy, "на станции — огнёвки заняты им")
	ok(not pr.leech, "огнёвки сняли паразита за %.1f с" % t)
	ok(t > EcoLeech.CLEAN_WORK, "работа — 6 с у вершины")
	eq(pr.mode, EcoPred.Mode.PATROL)
	eq(pr.station, -1)
	eq(st.busy, -1)
	near(st.work, 0.0, 1e-6)
	ok(pr.leech_cd >= 150.0 and pr.leech_cd <= 260.0, "снова заразится через 150…260 с")
	ok(pr.hunger <= 0.3)
	var clean := _notes(w, "ognevka", "clean")
	eq(clean.size(), 1)
	ok(clean[0].text().contains("на станции чистки"), clean[0].text())
	ok(clean[0].text().contains("паразита"), "пиявник ещё не изучен — «паразита»: " + clean[0].text())
	ok(clean[0].is_observation(), "заметка огнёвки «снимают пиявников»")
	eq(_notes(w, "leech", "cleaned").size(), 1)
	ok(_notes(w, "leech", "cleaned")[0].is_observation())


func test_hungry_infected_does_not_go_clean() -> void:
	var tops: Array[Vector3] = [Vector3(0, -30, 0)]
	var w := _world(tops)
	var pr := _preds(w).all[0]
	pr.hunger = 0.5
	_step(w)
	ok(pr.mode != EcoPred.Mode.CLEAN, "голодный (≥ 0,45) не плывёт на чистку")


func test_gives_up_cleaning() -> void:
	var tops: Array[Vector3] = [Vector3(250, -30, 250)]
	var w := _world(tops)
	var pr := _preds(w).all[0]
	pr.hunger = 0.2
	_step(w)
	eq(pr.mode, EcoPred.Mode.CLEAN)
	pr.hunger = 0.95
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "голод выше 0,9 — бросил чистку")
	eq(pr.station, -1)
	ok(pr.leech, "паразит остался")

	w = _world(tops)
	pr = _preds(w).all[0]
	pr.hunger = 0.2
	_step(w)
	pr.agent.timer = 0.0
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "60 с прошли — бросил")


func test_station_work_decays_when_left() -> void:
	var tops: Array[Vector3] = [Vector3(0, -30, 0)]
	var w := _world(tops)
	var lc := _leeches(w)
	var st := lc.stations[0]
	st.work = 3.0
	st.busy = 0  # хищник 0 далеко и не на чистке
	_step(w)
	eq(st.busy, -1, "хищник ушёл — станция свободна")
	near(st.work, 3.0 - EcoWorld.MAX_STEP * EcoLeech.WORK_DECAY, 1e-5, "работа спадает на 0,5/с")


func test_no_hunt_or_attack_at_station() -> void:
	var probe := _preds(_world()).all[0]
	var tops: Array[Vector3] = [probe.agent.p + Vector3(5, 0, 0)]
	var w := _world(tops)
	var pr := _preds(w).all[0]
	pr.hunger = 0.7
	pr.cooldown = 0.0
	w.ship.light_on = true
	w.ship.pos = pr.agent.p + Vector3(15, 0, 0)
	_step(w)
	ok(pr.mode != EcoPred.Mode.CHARGE, "у станции чистки на корабль не нападает")


func test_stations_on_coral_tops() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	var ps := w.add(EcoPred.new()) as EcoPred
	var coral := w.add(EcoCoral.new()) as EcoCoral
	var lc := w.add(EcoLeech.new(ps, coral)) as EcoLeech
	eq(lc.stations.size(), coral.bushes.size(), "станция на каждом кусте огнецвета")
	for i in lc.stations.size():
		near(lc.stations[i].top.y, coral.bushes[i].base.y + 4.2, 1e-5, "вершина станции — 4,2 м над подножием")
		near(lc.stations[i].top.x, coral.bushes[i].base.x, 1e-5)


func test_scanner_sees_leech_on_infected() -> void:
	var w := _world()
	var all := _preds(w).all
	var found: Array[Dictionary] = []
	for t in w.scan_targets():
		if t.species == "leech":
			found.append(t)
	eq(found.size(), 1, "цель сканера — только у заражённого")
	ok(not found[0].sonar, "сонару пиявник не виден")
	near(found[0].r, 0.7, 1e-6)
	ok((found[0].pos as Vector3).distance_to(all[0].agent.p) < 1.0, "у жабр хищника")


# ---------- Сцена ----------

func test_view_ribbon_on_infected() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	await frames(1)
	ok(view.leech_view != null, "пиявники в сцене")
	var mm := view.leech_view.mesh.multimesh
	eq(mm.instance_count, view.preds.all.size(), "по ленте на хищника — один MultiMesh")
	eq(view.leech_view.mesh.layers, OceanView.LAYER_WORLD)
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	view.step(0.05, ship)
	var sick := view.leech_view.placed[0]
	near(sick.basis.get_scale().y, 1.0, 1e-4, "у заражённого лента видна")
	near(sick.origin.distance_to(EcoLeech.position_on(view.preds.all[0])), 0.0, 1e-4)
	near(view.leech_view.placed[1].basis.get_scale().length(), 0.0, 1e-6, "у здорового — нет")
	tree.root.remove_child(view)
	view.free()
