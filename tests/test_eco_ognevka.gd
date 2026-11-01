extends TestCase
## Огнёвки (initStations, stationsUpdate, predUpdate в js/creatures.js; бестиарий): рачки на станциях чистки,
## облепляют хищника на чистке, кормятся на веернике пустой станции; у станции хищник бросает охоту (truce),
## корабль у станции в укрытии (shelter); в сцене — один MultiMesh.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Мир: светляки, серпохвосты, станции на tops, огнёвки (веерники — по fan_spots, пусто — без веерников).
func _world(tops: Array[Vector3], fan_spots: Array[Vector2] = []) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var fish := w.add(EcoFish.new()) as EcoFish
	var ps := w.add(EcoPred.new(fish)) as EcoPred
	var lc := w.add(EcoLeech.new(ps, null, tops)) as EcoLeech
	var fans: EcoFan = null
	if not fan_spots.is_empty():
		var cur := w.add(EcoCurrent.new()) as EcoCurrent
		fans = w.add(EcoFan.new(cur, fan_spots)) as EcoFan
	w.add(EcoOgnevka.new(lc, fans))
	return w


func _sys(w: EcoWorld, kind: Variant) -> EcoSystem:
	for s in w.systems:
		if is_instance_of(s, kind):
			return s
	return null


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


func _run(w: EcoWorld, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		w.step(EcoWorld.MAX_STEP)
		t += EcoWorld.MAX_STEP


## Все серпохвосты сыты и здоровы — не мешают проверке.
func _calm(ps: EcoPred) -> void:
	for pr in ps.all:
		pr.hunger = 0.0
		pr.leech = false
		pr.leech_cd = 1e6


# ---------- Рачки на станции ----------

func test_ten_shrimp_per_station() -> void:
	var tops: Array[Vector3] = [Vector3(0, -36, 0), Vector3(80, -36, 0)]
	var w := _world(tops)
	var og := _sys(w, EcoOgnevka) as EcoOgnevka
	eq(og.shrimp.size(), 20, "по 10 огнёвок на станцию")
	_calm(_sys(w, EcoPred) as EcoPred)
	_run(w, 3.0)
	for s in og.shrimp:
		ok(s.p.distance_to(tops[s.station]) < 2.0, "кружат над вершиной: %.2f м" % s.p.distance_to(tops[s.station]))
		near(s.dir.length(), 1.0, 1e-4)
	w.reset()
	eq(og.shrimp.size(), 20, "сброс мира — те же рачки")
	ok(og.shrimp[0].p.distance_to(tops[0]) < 2.0, "снова над вершиной")


## Б3 «плавность»: после сброса рачок уже там, куда его ведёт шаг (круг над вершиной, веерник); раньше все стояли
## в вершине и на первом шаге прыгали к веернику до 1,5 м за кадр (44 м/с).
func test_no_jump_after_reset() -> void:
	var top := Vector3(0, -40 + EcoLeech.TOP, 0)
	var tops: Array[Vector3] = [top]
	var fan_spots: Array[Vector2] = [Vector2(7, 0)]
	var w := _world(tops, fan_spots)
	var og := _sys(w, EcoOgnevka) as EcoOgnevka
	_calm(_sys(w, EcoPred) as EcoPred)
	var dt := 1.0 / 30.0
	var was: Array[Vector3] = []
	for s in og.shrimp:
		was.append(s.p)
	var worst := 0.0
	for i in 30 * 3:
		w.step(dt)
		for k in og.shrimp.size():
			worst = maxf(worst, og.shrimp[k].p.distance_to(was[k]) / dt)
			was[k] = og.shrimp[k].p
	ok(worst < 6.0, "рачки без рывков после сброса: %.2f м/с" % worst)


## Б3: хищник встал на чистку в 8 м от вершины — стая плывёт к нему не быстрее DART (раньше доля lerp давала
## 26 м/с за шаг — нашла `test_eco_reset_jumps`), но всё равно облепляет его за пару секунд.
func test_no_dart_to_pred_on_cleaning() -> void:
	var top := Vector3(0, -36, 0)
	var tops: Array[Vector3] = [top]
	var w := _world(tops)
	var ps := _sys(w, EcoPred) as EcoPred
	var og := _sys(w, EcoOgnevka) as EcoOgnevka
	_calm(ps)
	_run(w, 1.0)
	var pr := ps.all[0]
	pr.leech = true
	pr.hunger = 0.2
	pr.agent.p = top + Vector3(8, 0, 0)
	var dt := EcoWorld.MAX_STEP
	var was: Array[Vector3] = []
	for s in og.shrimp:
		was.append(s.p)
	var worst := 0.0
	var t := 0.0
	while t < 4.0:
		w.step(dt)
		t += dt
		for k in og.shrimp.size():
			worst = maxf(worst, og.shrimp[k].p.distance_to(was[k]) / dt)
			was[k] = og.shrimp[k].p
	eq((_sys(w, EcoLeech) as EcoLeech).stations[0].busy, pr.index, "хищник на чистке")
	# рачок шагает через шаг мира: за свой шаг (2 dt) — не дальше DART · 2 dt
	ok(worst <= EcoOgnevka.DART * 2.0 + 1e-3, "к хищнику без рывка: %.2f м/с за шаг мира" % worst)
	for s in og.shrimp:
		ok(s.p.distance_to(pr.agent.p) < 1.8, "облепили: %.2f м" % s.p.distance_to(pr.agent.p))


func test_follow_capped() -> void:
	var p := EcoOgnevka.follow(Vector3.ZERO, Vector3(10, 0, 0), 0.1)
	near(p.x, EcoOgnevka.DART * 0.1, 1e-5, "далеко — не быстрее DART")
	p = EcoOgnevka.follow(Vector3.ZERO, Vector3(0.5, 0, 0), 0.1)
	near(p.x, 0.5 * 0.1 * EcoOgnevka.FOLLOW, 1e-5, "близко — прежняя доля lerp")


## Б3: нос рачка догоняет ход, а не прыгает за шаг; почти стоит — держит курс (раньше щёлкал на касательную).
func test_nose_turns_smoothly() -> void:
	var top := Vector3(0, -36, 0)
	var tops: Array[Vector3] = [top]
	var w := _world(tops)
	var og := _sys(w, EcoOgnevka) as EcoOgnevka
	_calm(_sys(w, EcoPred) as EcoPred)
	for s in og.shrimp:
		near(s.dir.length(), 1.0, 1e-4, "курс задан с начала")
		near(s.dir.y, 0.0, 1e-4, "первый курс — по кругу над вершиной")
	_run(w, 3.0)
	var was: Array[Vector3] = []
	var pos: Array[Vector3] = []
	for s in og.shrimp:
		s.dir = -s.dir  # развернули носом против хода
		was.append(s.dir)
		pos.append(s.p)
	w.step(EcoWorld.MAX_STEP)
	w.step(EcoWorld.MAX_STEP)
	var cap := EcoOgnevka.LOOK_MAX * EcoWorld.MAX_STEP * 2.0 + 1e-3
	for k in og.shrimp.size():
		var s := og.shrimp[k]
		ok(s.dir.angle_to(was[k]) <= cap, "за шаг рачка нос повернул на %.2f рад (не больше %.2f)" % [s.dir.angle_to(was[k]), cap])
		near(s.dir.length(), 1.0, 1e-4)
	_run(w, 1.5)
	for k in og.shrimp.size():
		var s := og.shrimp[k]
		var p0 := s.p
		w.step(EcoWorld.MAX_STEP)
		w.step(EcoWorld.MAX_STEP)
		var mv := s.p - p0
		if mv.length() > 1e-3:
			ok(s.dir.angle_to(mv) < 0.35, "через 1,5 с нос по ходу: %.2f рад" % s.dir.angle_to(mv))
	var d := Vector3(0, 0, -1)
	eq(EcoOgnevka.turn(d, Vector3.ZERO, 0.1), d, "хода нет — курс тот же")
	near(EcoOgnevka.turn(d, Vector3(0, 0, 1), 0.1).angle_to(d), EcoOgnevka.LOOK_MAX * 0.1, 1e-4,
		"навстречу — разворот не быстрее LOOK_MAX")


func test_shrimp_swarm_pred_on_cleaning() -> void:
	var top := Vector3(0, -36, 0)
	var tops: Array[Vector3] = [top]
	var w := _world(tops)
	var ps := _sys(w, EcoPred) as EcoPred
	var og := _sys(w, EcoOgnevka) as EcoOgnevka
	_calm(ps)
	var pr := ps.all[0]
	pr.leech = true
	pr.hunger = 0.2
	pr.agent.p = top + Vector3(1, 0, 0)
	_run(w, 2.0)
	eq(pr.mode, EcoPred.Mode.CLEAN, "заражённый на чистке")
	eq((_sys(w, EcoLeech) as EcoLeech).stations[0].busy, pr.index)
	for s in og.shrimp:
		ok(s.p.distance_to(pr.agent.p) < 1.8, "огнёвки облепили хищника: %.2f м" % s.p.distance_to(pr.agent.p))


func test_half_feed_on_fan_of_idle_station() -> void:
	var top := Vector3(0, -40 + EcoLeech.TOP, 0)
	var tops: Array[Vector3] = [top]
	var fan_spots: Array[Vector2] = [Vector2(7, 0)]
	var w := _world(tops, fan_spots)
	var og := _sys(w, EcoOgnevka) as EcoOgnevka
	var fans := _sys(w, EcoFan) as EcoFan
	_calm(_sys(w, EcoPred) as EcoPred)
	ok(og.fan_at((_sys(w, EcoLeech) as EcoLeech).stations[0]) == fans.fans[0], "веерник у подножия огнецвета — станции")
	_run(w, 3.0)
	for k in og.shrimp.size():
		var s := og.shrimp[k]
		if k % 2 == 1:
			ok(s.p.distance_to(fans.fans[0].top) < 2.0, "нечётные кормятся на веернике")
		else:
			ok(s.p.distance_to(top) < 2.0, "чётные над вершиной")


func test_fan_note_when_ship_near_idle_station() -> void:
	var top := Vector3(0, -40 + EcoLeech.TOP, 0)
	var tops: Array[Vector3] = [top]
	var fan_spots: Array[Vector2] = [Vector2(7, 0)]
	var w := _world(tops, fan_spots)
	_calm(_sys(w, EcoPred) as EcoPred)
	w.ship.pos = Vector3(30, -30, 0)
	_run(w, 1.0)
	var ev := _notes(w, "fan", "ognevka")
	eq(ev.size(), 1, "корабль у пустой станции — огнёвки на веернике")
	ok(ev[0].text().contains("кружевном веере"), ev[0].text())
	ok(ev[0].text().begins_with("Рачки-чистильщики"), ev[0].text())
	ok(ev[0].is_observation(), "заметка веерника «огнёвки кормятся»")
	_run(w, 60.0)
	eq(_notes(w, "fan", "ognevka").size(), 1, "не чаще раза в 120 с")
	w.scanned = func(id: String) -> bool: return id == "fan" or id == "ognevka"
	ok(ev[0].text().begins_with("Огнёвки кормятся на веернике"), ev[0].text())


# ---------- Перемирие ----------

func test_truce_drops_hunt_near_station() -> void:
	var top := Vector3(0, -36, 0)
	var tops: Array[Vector3] = [top]
	var w := _world(tops)
	var ps := _sys(w, EcoPred) as EcoPred
	var fish := _sys(w, EcoFish) as EcoFish
	_calm(ps)
	var pr := ps.all[0]
	var f := fish.all[0]
	f.agent.p = top + Vector3(3, 0, 0)
	pr.agent.p = top + Vector3(30, 0, 0)
	pr.prey = f
	pr.mode = EcoPred.Mode.HUNT
	pr.agent.timer = 12.0
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "светляк у станции — охота брошена")
	eq(pr.prey, null)
	var ev := _notes(w, "ognevka", "truce")
	eq(ev.size(), 1)
	ok(ev[0].text().contains("бросил охоту у станции чистки"), ev[0].text())
	ok(ev[0].is_observation(), "заметка «у станции не охотится»")
	near(pr.truce_cd, EcoOgnevka.TRUCE_CD, 0.1)
	pr.prey = f
	pr.mode = EcoPred.Mode.HUNT
	pr.agent.timer = 12.0
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL)
	eq(_notes(w, "ognevka", "truce").size(), 1, "сообщение не чаще раза в 40 с")


func test_fish_near_station_not_chosen() -> void:
	var top := Vector3(0, -36, 0)
	var tops: Array[Vector3] = [top]
	var w := _world(tops)
	var ps := _sys(w, EcoPred) as EcoPred
	var fish := _sys(w, EcoFish) as EcoFish
	var skip := ps._hidden_fish()
	ok(skip.is_valid())
	var f := fish.all[0]
	f.agent.p = top + Vector3(5, 0, 0)
	ok(skip.call(f), "у станции светляка не трогают (nearStation)")
	f.agent.p = top + Vector3(20, 0, 0)
	ok(not skip.call(f), "дальше 14 м — добыча")


# ---------- Укрытие корабля ----------

func test_ship_sheltered_at_station() -> void:
	var top := Vector3(0, -36, 0)
	var tops: Array[Vector3] = [top]
	var w := _world(tops)
	var ps := _sys(w, EcoPred) as EcoPred
	var og := _sys(w, EcoOgnevka) as EcoOgnevka
	_calm(ps)
	w.ship.pos = top + Vector3(10, 0, 0)
	ok(ps.ship_sheltered(w), "корабль ближе 18 м к вершине — в укрытии")
	ok(og.shelter(top + Vector3(17.9, 0, 0)) != null)
	ok(og.shelter(top + Vector3(18.1, 0, 0)) == null)
	var pr := ps.all[0]
	pr.agent.p = w.ship.pos + Vector3(20, 0, 0)
	pr.hunger = 0.7
	pr.cooldown = 0.0
	w.ship.light_on = true
	w.step(EcoWorld.MAX_STEP)
	ok(pr.mode != EcoPred.Mode.CHARGE, "в укрытии на корабль не бросается")
	ok(pr.cooldown >= EcoOgnevka.SHELTER_PAUSE - 0.1, "пауза 8 с: %.2f" % pr.cooldown)
	var ev := _notes(w, "ognevka", "shelter")
	eq(ev.size(), 1)
	ok(ev[0].text().contains("не трогает корабль у станции чистки"), ev[0].text())
	ok(ev[0].is_observation(), "заметка «корабль может переждать у станции»")

	w.ship.pos = top + Vector3(60, 0, 0)
	pr.agent.p = w.ship.pos + Vector3(20, 0, 0)
	pr.cooldown = 0.0
	pr.mode = EcoPred.Mode.PATROL
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "вне укрытия — бросок, как раньше")


func test_charge_turns_away_from_shelter() -> void:
	var top := Vector3(0, -36, 0)
	var tops: Array[Vector3] = [top]
	var w := _world(tops)
	var ps := _sys(w, EcoPred) as EcoPred
	_calm(ps)
	var pr := ps.all[0]
	pr.agent.p = top + Vector3(40, 0, 0)
	pr.hunger = 0.7
	pr.cooldown = 0.0
	w.ship.light_on = true
	w.ship.pos = top + Vector3(60, 0, 0)
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "корабль ещё не у станции — бросок")
	w.ship.pos = top + Vector3(5, 0, 0)
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.RETREAT, "корабль у станции — отвернул")
	ok(pr.cooldown >= EcoOgnevka.TURN_AWAY_PAUSE - 0.1, "15 с не нападает")
	near(pr.agent.timer, EcoOgnevka.TURN_AWAY_TIME, 0.1)
	ok(pr.agent.goal.y <= EcoPred.GOAL_CEILING)
	var ev := _notes(w, "ognevka", "shelter")
	eq(ev.size(), 1)
	ok(ev[0].text().contains("отвернул"), ev[0].text())
	eq(w.hits, 0, "корпус цел")


func test_no_ognevka_no_shelter() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	var ps := w.add(EcoPred.new()) as EcoPred
	w.add(EcoLeech.new(ps, null, [Vector3(0, -36, 0)] as Array[Vector3]))
	w.ship.pos = Vector3(5, -36, 0)
	ok(not ps.ship_sheltered(w), "без огнёвок укрытия нет")


# ---------- Сканер и сцена ----------

func test_scanner_sees_stations_not_sonar() -> void:
	var tops: Array[Vector3] = [Vector3(0, -36, 0), Vector3(80, -36, 0)]
	var w := _world(tops)
	var found: Array[Dictionary] = []
	for t in w.scan_targets():
		if t.species == "ognevka":
			found.append(t)
	eq(found.size(), 2, "станция — цель сканера")
	eq(found[0].pos, tops[0])
	near(found[0].r, EcoOgnevka.SCAN_R, 1e-6)
	ok(not found[0].sonar, "сонар огнёвок не видит")


func test_view_one_multimesh() -> void:
	var tops: Array[Vector3] = [Vector3(0, -36, 0), Vector3(80, -36, 0), Vector3(0, -36, 80)]
	var w := _world(tops)
	var og := _sys(w, EcoOgnevka) as EcoOgnevka
	_run(w, 1.0)
	var v := OgnevkaView.new(og)
	tree.root.add_child(v)
	await frames(1)
	eq(v.mesh.multimesh.instance_count, 30, "все огнёвки — один MultiMesh")
	eq(v.mesh.layers, OceanView.LAYER_WORLD)
	eq(v.placed.size(), 30)
	near(v.placed[3].origin.distance_to(og.shrimp[3].p), 0.0, 1e-5)
	var axis := v.placed[3].basis.y.normalized()
	near(absf(axis.dot(og.shrimp[3].dir)), 1.0, 1e-3, "капсула вытянута по ходу")
	v.queue_free()
	await frames(1)


func test_eco_view_has_ognevka() -> void:
	var ev := EcoView.new()
	tree.root.add_child(ev)
	await frames(1)
	ok(ev.ognevka != null)
	eq(ev.ognevka.leeches, ev.leeches)
	eq(ev.preds.ognevka, ev.ognevka)
	eq(ev.ognevka.shrimp.size(), ev.leeches.stations.size() * EcoOgnevka.PER_STATION)
	ev.step(0.1, EcoLink.ShipState.new())
	ok(ev.ognevka_view.placed.size() > 0)
	ev.queue_free()
	await frames(1)


## Место рачка из буфера вида (строки transform 3 × 4).
static func _at(buf: PackedFloat32Array, slot: int) -> Vector3:
	var o := slot * 12
	return Vector3(buf[o + 3], buf[o + 7], buf[o + 11])


func test_view_lite_draws_half_per_station() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var ov := view.ognevka_view
	var n := view.leeches.stations.size()
	var all := n * EcoOgnevka.PER_STATION
	ok(n > 0, "станции есть")
	eq(ov.drawn(), all, "на «Обычно» — все рачки")
	view.set_lite(true)
	ok(ov.lite, "огнёвки — на «Экономно»")
	eq(ov.drawn(), all / 2, "половина рачков")
	var seen := {}
	for i in all:
		var s := OgnevkaView.slot(i, n, true)
		seen[s] = true
		eq(s < ov.drawn(), OgnevkaView.lite_shown(i % EcoOgnevka.PER_STATION), "видно только показанное (%d)" % i)
	eq(seen.size(), all, "места в буфере не повторяются")
	var even := 0
	var odd := 0
	for k in EcoOgnevka.PER_STATION:
		if OgnevkaView.lite_shown(k):
			even += 1 if k % 2 == 0 else 0
			odd += 1 if k % 2 == 1 else 0
	ok(even > 0 and odd > 0, "видны и рачки у вершины (чётные), и кормящиеся на веернике (нечётные)")
	for k in 4:
		view.step(EcoWorld.MAX_STEP, EcoLink.ShipState.new())
	var i := EcoOgnevka.PER_STATION + 2   # вторая станция, показанный рачок
	near(_at(ov._buffer, OgnevkaView.slot(i, n, true)).distance_to(view.ognevka.shrimp[i].p), 0.0, 1e-4,
		"видимый рачок — на своём месте буфера")
	view.ground = Seabed.height   # сброс мира — виды пересобираются
	ok(view.ognevka_view.lite and view.ognevka_view.drawn() == all / 2, "сброс мира — снова «Экономно»")
	view.set_lite(false)
	ov = view.ognevka_view
	eq(ov.drawn(), all, "назад — все")
	i = EcoOgnevka.PER_STATION + 3
	near(_at(ov._buffer, i).distance_to(view.ognevka.shrimp[i].p), 0.0, 1e-4, "буфер снова по номеру")
	view.queue_free()
	await frames(1)
