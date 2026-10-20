extends TestCase
## Волнолист (fernsUpdate в js/creatures.js; ART-004): луч прожектора (EcoWorld.in_beam), раскрытие и сворачивание,
## моллюски зовут стаи светляков, наблюдения «open» и «mollusk», цели сонара и сканера. В сцене — два MultiMesh.


func _world(with_fish := false) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var f: EcoFish = w.add(EcoFish.new()) as EcoFish if with_fish else null
	w.add(EcoFern.new(f))
	return w


func _fern(w: EcoWorld) -> EcoFern:
	for s in w.systems:
		if s is EcoFern:
			return s
	return null


## Корабль над точкой p так, что она в середине луча (курс yaw, d м по лучу от прожектора).
func _aim(w: EcoWorld, p: Vector3, yaw: float = 0.0, d: float = 15.0) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var down := deg_to_rad(Searchlight.PITCH)
	var dir := turn * Vector3(0, -sin(down), -cos(down))
	w.ship.yaw = yaw
	w.ship.pos = p - dir * d - turn * Searchlight.LAMP
	w.ship.light_on = true
	w.ship.light_range = Searchlight.BASE_RANGE


func _notes(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		if e["type"] == EcoLink.OBSERVE and e["species"] == EcoFern.ID:
			out.append(e["note"])
	return out


# ---------- Луч ----------

func test_beam_cone() -> void:
	var s := EcoLink.ShipState.new()
	s.pos = Vector3(10, -20, 30)
	s.yaw = 0.7
	var turn := Basis(Vector3.UP, s.yaw)
	var lamp := s.pos + turn * Searchlight.LAMP
	var down := deg_to_rad(Searchlight.PITCH)
	var dir := turn * Vector3(0, -sin(down), -cos(down))
	ok(not EcoWorld.beam_hits(s, lamp + dir * 20.0), "свет погашен — не освещает")
	s.light_on = true
	ok(EcoWorld.beam_hits(s, lamp + dir * 20.0), "на оси луча")
	ok(EcoWorld.beam_hits(s, lamp + dir * 44.0), "у конца луча (45 м)")
	ok(not EcoWorld.beam_hits(s, lamp + dir * 46.0), "дальше 45 м — нет")
	ok(not EcoWorld.beam_hits(s, lamp - dir * 10.0), "за кормой луча — нет")
	var side := turn * Vector3.RIGHT
	ok(EcoWorld.beam_hits(s, lamp + (dir + side * tan(0.45)).normalized() * 20.0), "внутри 0,5 рад от оси")
	ok(not EcoWorld.beam_hits(s, lamp + (dir + side * tan(0.55)).normalized() * 20.0), "снаружи конуса")
	s.light_range = Searchlight.range_m(0.25)
	ok(EcoWorld.beam_hits(s, lamp + dir * 22.0), "при доле 0,25 — 22,5 м")
	ok(not EcoWorld.beam_hits(s, lamp + dir * 23.0), "и не дальше (√доли, как в браузере)")


# ---------- Расстановка ----------

func test_two_clusters_of_four_on_ground() -> void:
	var w := _world()
	var fr := _fern(w)
	eq(fr.ferns.size(), 8, "две куртины по четыре")
	var c := EcoFern.default_clusters()
	near(c[1].x, EcoFish.HOMES[2].x - 6.0, 1e-4, "вторая — у третьей стаи")
	for fe in fr.ferns:
		near(fe.pos.y, Seabed.height(fe.pos.x, fe.pos.z), 1e-4, "на дне")
		var cl := c[0] if fe.index < 4 else c[1]
		ok(absf(fe.pos.x - cl.x) <= 2.5 and absf(fe.pos.z - cl.y) <= 2.5, "в куртине")
		ok(fe.scale >= 0.8 and fe.scale <= 1.2, "разброс ±20 %")
		near(fe.open, 0.0, 1e-6, "свёрнут")
	var other := EcoWorld.new()
	other.ground = Seabed.height
	other.add(EcoFern.new())
	eq(_fern(other).ferns[3].pos, fr.ferns[3].pos, "то же зерно — те же места")


func test_start_cluster_not_nearest_scan_target() -> void:
	# ближайшей целью сканера у старта остаётся стая светляков (как в браузере)
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var f := w.add(EcoFish.new()) as EcoFish
	var fr := w.add(EcoFern.new(f)) as EcoFern
	var shoal_d := f.shoals[0].center.distance_to(Helm.Ship.START)
	for fe in fr.ferns:
		ok(fe.top.distance_to(Helm.Ship.START) > shoal_d + 1.0, "куст дальше стаи от старта")


# ---------- Раскрытие ----------

func test_opens_in_beam_and_closes_after() -> void:
	var w := _world()
	var fr := _fern(w)
	var fe := fr.ferns[5]
	_aim(w, fe.top)
	ok(w.in_beam(fe.top), "куст в луче")
	w.run(1.0)
	near(fe.open, 0.6, 0.02, "раскрывается 0,6 в секунду")
	w.run(1.0)
	near(fe.open, 1.0, 1e-6, "раскрыт")
	near(fr.ferns[0].open, 0.0, 1e-6, "другая куртина в темноте")
	w.ship.light_on = false
	w.run(4.9)
	near(fe.open, 1.0, 1e-6, "после луча 5 с держится раскрытым")
	w.run(2.1)
	ok(fe.open < 1.0 and fe.open > 0.4, "сворачивается медленно: %f" % fe.open)
	w.run(4.0)
	near(fe.open, 0.0, 1e-6, "свернулся")


func test_open_observation_once_per_40s() -> void:
	var w := _world()
	var fr := _fern(w)
	var fe := fr.ferns[1]
	_aim(w, fe.top)
	w.step(0.05)
	var notes := _notes(w.take_link())
	eq(notes, ["open"] as Array[String], "наблюдение «раскрывается в луче»")
	var bus_text := ""
	w.ship.light_on = false
	w.run(20.0)
	w.ship.light_on = true
	w.run(1.0)
	eq(_notes(w.take_link()), [] as Array[String], "чаще раза в 40 с — молчит")
	w.ship.light_on = false
	w.run(30.0)
	w.ship.light_on = true
	w.step(0.05)
	var ev := w.take_link()
	eq(_notes(ev), ["open"] as Array[String], "через 40 с — снова")
	for e in ev:
		if e["type"] == EcoLink.OBSERVE:
			bus_text = e["text"]
	ok(bus_text.ends_with("разворачивает листья к свету прожектора"), bus_text)
	ok(bus_text.begins_with("Папоротник-спираль"), "неизученный — описательное имя: " + bus_text)


func test_no_open_message_if_still_open() -> void:
	var w := _world()
	var fr := _fern(w)
	var fe := fr.ferns[2]
	for x in fr.ferns:
		x.open = 0.5
		x.lit_t = 3.0
	_aim(w, fe.top)
	w.step(0.05)
	eq(_notes(w.take_link()), [] as Array[String], "уже полураскрыт — не сообщает")


# ---------- Моллюски зовут стаи ----------

func test_open_fern_calls_calm_shoal() -> void:
	var w := _world(true)
	var fr := _fern(w)
	var f: EcoFish = w.systems[0]
	var fe := fr.ferns[0]  # куртина у стаи 0 рядом со стартом
	var sh := f.shoals[0]
	ok(sh.center.distance_to(fe.top) < EcoFern.CALL_R, "стая рядом")
	_aim(w, fe.top, 0.0, 12.0)
	w.ship.speed = 0.0
	w.run(2.0)
	ok(fe.open > EcoFern.FEED_OPEN, "раскрыт")
	w.step(0.05)
	var tops: Array[Vector3] = []
	for x in fr.ferns:
		if x.open > EcoFern.FEED_OPEN:
			tops.append(x.top)
	ok(tops.has(sh.goal), "стая плывёт к моллюскам раскрытого куста")
	ok(not tops.has(f.shoals[1].goal), "дальняя стая — нет")
	var notes: Array[String] = []
	for i in 600:  # до 30 с
		w.step(0.05)
		notes.append_array(_notes(w.take_link()))
		if notes.has("mollusk"):
			break
	ok(notes.has("mollusk"), "стая приплыла — наблюдение «моллюски»")
	var best := INF
	for t in tops:
		best = minf(best, sh.center.distance_to(t))
	ok(best < EcoFern.CAME_R + 0.5, "стая у куста: %f" % best)


func test_alarmed_shoal_not_called() -> void:
	var w := _world(true)
	var fr := _fern(w)
	var f: EcoFish = w.systems[0]
	var fe := fr.ferns[0]
	fe.open = 1.0
	fe.lit_t = 5.0
	var sh := f.shoals[0]
	sh.alarm = 3.0
	sh.goal = sh.home
	sh.goal_timer = 10.0
	fr.step(w, 0.05)
	eq(sh.goal, sh.home, "в тревоге не до моллюсков")


func test_closed_fern_calls_no_one() -> void:
	var w := _world(true)
	var fr := _fern(w)
	var f: EcoFish = w.systems[0]
	w.run(5.0)
	for sh in f.shoals:
		for fe in fr.ferns:
			ok(sh.goal != fe.top, "свёрнутый никого не зовёт")


# ---------- Сонар и сканер ----------

func test_ferns_are_scan_targets() -> void:
	var w := _world()
	var fr := _fern(w)
	var fe := fr.ferns[4]
	w.ship.pos = fe.top + Vector3(5, 0, 0)
	w.ship.scan_range = 80.0
	w.step(0.05)
	var got := false
	for e in w.take_link():
		if e["type"] == EcoLink.NEAR and e["species"] == EcoFern.ID:
			got = true
			near(e["r"], 0.7, 1e-6)
	ok(got, "куст — цель сканера")


func test_observations_in_species_notes() -> void:
	ok(Species.is_observation(EcoFern.ID, "open"))
	ok(Species.is_observation(EcoFern.ID, "mollusk"))


# ---------- В сцене ----------

func test_view_two_multimeshes() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var fv := view.fern_view
	ok(fv != null and fv.get_parent() == view, "волнолист — в живом мире")
	eq(fv.leaves.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(fv.shells.layers, OceanView.LAYER_WORLD)
	eq(fv.leaves.multimesh.instance_count, 8 * EcoFern.LEAVES, "все листья — один MultiMesh")
	eq(fv.shells.multimesh.instance_count, 8 * EcoFern.SHELLS, "все моллюски — один MultiMesh")
	var tris := fv.leaves.multimesh.mesh.get_faces().size() / 3
	eq(tris, FernView.SEGMENTS * 2, "лист — 12 треугольников")
	var fe := view.ferns.ferns[3]
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	view.step(0.05, ship)
	var n := fe.index * EcoFern.LEAVES + 2
	var tr := FernView.transform_at(fv.buffer, n)
	ok(tr.origin.distance_to(fe.pos) < 1e-4, "лист растёт из подножия")
	var closed_up := (tr.basis * Vector3.UP).normalized().y
	fe.open = 1.0
	view.step(0.05, ship)
	tr = FernView.transform_at(fv.buffer, n)
	var open_up := (tr.basis * Vector3.UP).normalized().y
	ok(closed_up > 0.95 and open_up < 0.7, "раскрытый лист ложится наружу: %f → %f" % [closed_up, open_up])
	var sh := FernView.transform_at(fv.shells.multimesh.buffer, fe.index * EcoFern.SHELLS)
	near(sh.origin.y, Seabed.height(sh.origin.x, sh.origin.z) + 0.02, 1e-3, "моллюск на дне")
	view.queue_free()
	await frames(1)
