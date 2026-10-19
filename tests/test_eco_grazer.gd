extends TestCase
## Скребуны и светящийся мох (grazerUpdate в js/creatures.js, W.patches в js/world.js, Unity EcoGrazerTests
## и EcoGrazerLookTests): пятна отрастают и тускнеют под скребунами, скребуны ходят по дну от пятна к пятну,
## форма скребуна по ART-006, шаг тройками, один меш мха и один MultiMesh скребунов в сцене.


func _world(world_seed: int = EcoRandom.WORLD_SEED) -> EcoWorld:
	var w := EcoWorld.new(world_seed)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var m := w.add(EcoMoss.new()) as EcoMoss
	w.add(EcoGrazer.new(m))
	return w


func _moss(w: EcoWorld) -> EcoMoss:
	for s in w.systems:
		if s is EcoMoss:
			return s
	return null


func _grazers(w: EcoWorld) -> EcoGrazer:
	for s in w.systems:
		if s is EcoGrazer:
			return s
	return null


## Ровное дно на −40 м, два пятна в 10 м друг от друга (еда полная) и один скребун.
func _pair() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return -40.0
	w.ship.pos = Vector3(500, 0, 500)
	var m := w.add(EcoMoss.new([Vector3(0, -40, 0), Vector3(0, -40, 10)] as Array[Vector3])) as EcoMoss
	for p in m.patches:
		p.food = 1.0
	w.add(EcoGrazer.new(m, 1))
	return w


func _run_until(w: EcoWorld, done: Callable, max_s: float) -> bool:
	var t := 0.0
	while t < max_s and not done.call():
		w.step(EcoWorld.MAX_STEP)
		t += EcoWorld.MAX_STEP
	return ok(done.call(), "не дождались за %s с" % max_s)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------- Мох и скребуны (EcoMoss, EcoGrazer) ----------

func test_22_patches_and_10_grazers() -> void:
	var w := _world()
	var moss := _moss(w)
	var gr := _grazers(w)
	eq(moss.patches.size(), 22, "22 пятна")
	near(moss.patches[0].pos.x, 30.831, 0.01, "первое пятно — как в браузере")
	near(moss.patches[0].pos.z, 94.437, 0.01)
	for p in moss.patches:
		ok(p.food >= 0.6 and p.food <= 1.0, "еда 0,6…1")
		near(p.pos.y, Seabed.height(p.pos.x, p.pos.z), 0.1, "пятно %d лежит на дне" % p.index)
	eq(gr.all.size(), EcoGrazer.COUNT)
	eq(w.count("grazer"), 10)
	for i in gr.all.size():
		var g := gr.all[i]
		var home := moss.patches[(i * 2) % 22].pos
		eq(g.agent.species, "grazer")
		ok(_flat(g.agent.p, home) <= 4.25, "скребун у своего пятна")
		near(g.agent.p.y, Seabed.height(g.agent.p.x, g.agent.p.z) + EcoGrazer.LIFT, 1e-3, "на дне")
		ok(g.patch != null, "сразу знает, к какому пятну идти")
		eq(g.agent.state, EcoAgent.State.SEEK)


func test_moss_regrows_to_full() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var moss := w.add(EcoMoss.new()) as EcoMoss  # без скребунов
	var p := moss.patches[3]
	p.food = 0.0
	near(p.glow(), EcoMoss.MIN_GLOW, 1e-5, "объеденное пятно едва светится")
	w.run(10.0)
	near(p.food, 0.12, 0.005, "за 10 с отрастает 0,12")
	w.run(80.0)
	near(p.food, 1.0, 1e-5, "за 90 с — полное, не больше 1")
	near(p.glow(), 1.0, 1e-5)
	near(EcoMoss.glow_of(0.5), 0.575, 1e-5)


func test_grazer_walks_to_patch_and_grazes() -> void:
	var w := _pair()
	var g := _grazers(w).all[0]
	var t := 0.0
	while t < 30.0 and not g.grazing():
		w.step(EcoWorld.MAX_STEP)
		t += EcoWorld.MAX_STEP
		if not g.grazing():
			if not eq(g.agent.state, EcoAgent.State.SEEK):
				return
			if not near(g.agent.v.length(), EcoGrazer.WALK_SPEED, 1e-3, "идёт шагом 0,9 м/с"):
				return
		if not near(g.agent.p.y, -40.0 + EcoGrazer.LIFT, 1e-4, "идёт по дну"):
			return
	ok(g.grazing(), "дошёл до пятна и пасётся")
	ok(_flat(g.agent.p, g.patch.pos) < EcoGrazer.REACH)
	near(g.agent.v.length(), 0.0, 1e-5, "пасётся на месте")


func test_moss_dims_under_grazer_and_regrows() -> void:
	var w := _pair()
	var moss := _moss(w)
	var g := _grazers(w).all[0]
	if not _run_until(w, g.grazing, 30.0):
		return
	var eaten := g.patch
	var other := moss.patches[1 if eaten.index == 0 else 0]
	var f0 := eaten.food
	w.run(1.0)
	ok(g.grazing(), "пасётся не меньше 8 с")
	near(eaten.food, f0 - (EcoGrazer.EAT_RATE - EcoMoss.REGROW), 0.003, "минус 0,05 в секунду, плюс отрастание")
	ok(eaten.glow() < EcoMoss.glow_of(f0), "пятно тускнеет")
	near(other.food, 1.0, 1e-5, "соседнее не тронуто")

	# объеденное пятно бросает сразу и идёт к другому
	eaten.food = 0.05
	w.step(EcoWorld.MAX_STEP)
	eq(g.agent.state, EcoAgent.State.SEEK)
	ok(g.patch == other, "выбрал другое пятно")
	var low := eaten.food
	w.run(8.0)
	ok(not g.grazing(), "до соседнего пятна больше 8 м, шагом 0,9 м/с — ещё в пути")
	near(eaten.food, low + 8.0 * EcoMoss.REGROW, 0.005, "брошенное пятно отрастает")


func test_graze_message_not_more_often_than_45_s() -> void:
	var w := _pair()
	var times: Array[float] = []
	var texts: Array[String] = []
	var watch := func(ev: EcoBus.Event) -> void:
		if ev.species == "grazer":
			times.append(w.time)
			texts.append(ev.text())
			eq(ev.note, "graze")
			ok(ev.is_observation(), "наблюдение для журнала")
	w.bus.emitted.connect(watch)
	w.run(150.0)
	w.bus.emitted.disconnect(watch)
	ok(times.size() >= 1 and times.size() <= 4, "пасётся и сообщает: %d" % times.size())
	for i in range(1, times.size()):
		ok(times[i] - times[i - 1] >= EcoGrazer.GRAZE_COOLDOWN - 0.01, "не чаще раза в 45 с")
	if texts.size() > 0:
		eq(texts[0], "Донный панцирник объедает светящийся мох", "до сканирования — описательное имя")
	w.scanned = func(sp: String) -> bool: return sp == "grazer"
	var gr := _grazers(w)
	var p := w.emit("grazer", "graze", Vector3.ZERO, EcoGrazer._graze_text(w))
	eq(p.text(), "Скребун объедает светящийся мох")
	ok(gr != null)


func test_all_grazers_graze_and_stay_on_ground() -> void:
	var w := _world()
	var moss := _moss(w)
	var gr := _grazers(w)
	var grazed := []
	grazed.resize(gr.all.size())
	grazed.fill(false)
	var events := [0]
	var watch := func(ev: EcoBus.Event) -> void:
		if ev.species == "grazer":
			events[0] += 1
	w.bus.emitted.connect(watch)
	for s in 300 * 20:
		w.step(EcoWorld.MAX_STEP)
		if s % 20 != 0:
			continue
		for i in gr.all.size():
			var g := gr.all[i]
			var p := g.agent.p
			if g.grazing():
				grazed[i] = true
			if not near(p.y, Seabed.height(p.x, p.z) + EcoGrazer.LIFT, 1e-3, "на дне"):
				return
			if not ok(absf(p.x) <= EcoAgent.EDGE and absf(p.z) <= EcoAgent.EDGE, "в пределах отмели"):
				return
		for pt in moss.patches:
			if not ok(pt.food >= 0.0 and pt.food <= 1.0, "еда 0…1"):
				return
	w.bus.emitted.disconnect(watch)
	for i in grazed.size():
		ok(grazed[i], "скребун %d за 5 минут попасся" % i)
	ok(events[0] >= 10 and events[0] <= 80, "каждый сообщает, но не чаще раза в 45 с: %d" % events[0])


func test_eaten_grazer_returns_at_patch() -> void:
	var w := _world()
	var moss := _moss(w)
	var gr := _grazers(w)
	var g := gr.all[4]
	ok(gr.nearest_grazer(g.agent.p, 0.5) == g)
	gr.kill(g)
	ok(not g.agent.alive)
	eq(w.count("grazer"), 9)
	ok(gr.nearest_grazer(g.agent.p, 0.5) != g, "съеденного не найти")
	w.run(39.0)
	ok(not g.agent.alive, "не раньше 40 с")
	if not _run_until(w, func() -> bool: return g.agent.alive, 22.0):
		return
	eq(w.count("grazer"), 10)
	ok(_flat(g.agent.p, moss.nearest(g.agent.p).pos) <= 4.3, "появился у пятна мха")
	eq(g.agent.state, EcoAgent.State.SEEK)
	ok(g.patch != null)


func test_same_seed_same_world() -> void:
	var a := _world()
	var b := _world()
	var c := _world(777)
	a.run(60.0)
	b.run(60.0)
	c.run(60.0)
	var ga := _grazers(a)
	var gb := _grazers(b)
	var gc := _grazers(c)
	var differs := false
	for i in ga.all.size():
		eq(ga.all[i].agent.p, gb.all[i].agent.p)
		if ga.all[i].agent.p != gc.all[i].agent.p:
			differs = true
	var ma := _moss(a)
	var mb := _moss(b)
	for i in ma.patches.size():
		eq(ma.patches[i].food, mb.patches[i].food)
	ok(differs, "другое зерно — другой мир")
	a.reset()
	var gf := _grazers(_world())
	for i in ga.all.size():
		eq(ga.all[i].agent.p, gf.all[i].agent.p, "сброс — с начала")


func test_grazers_do_not_shift_fish() -> void:
	var a := EcoWorld.new()
	a.ground = Seabed.height
	var fa := a.add(EcoFish.new()) as EcoFish
	var b := EcoWorld.new()
	b.ground = Seabed.height
	var fb := b.add(EcoFish.new()) as EcoFish
	var mb := b.add(EcoMoss.new()) as EcoMoss
	b.add(EcoGrazer.new(mb))
	a.ship.pos = Vector3(500, 0, 500)
	b.ship.pos = Vector3(500, 0, 500)
	a.run(20.0)
	b.run(20.0)
	for i in fa.all.size():
		if not eq(fa.all[i].agent.p, fb.all[i].agent.p, "светляки те же"):
			return


# ---------- Вид скребуна и мха (EcoGrazerLook, EcoMossLook) ----------

func test_grazer_by_concept() -> void:
	var r := EcoGrazerLook.rest
	eq(EcoGrazerLook.paint.size(), r.size())
	eq(EcoGrazerLook.part.size(), r.size())
	eq(EcoGrazerLook.tris.size() % 3, 0)
	for i in EcoGrazerLook.tris:
		if not ok(i >= 0 and i < r.size(), "номер вершины"):
			return
	ok(EcoGrazerLook.tris.size() / 3 * EcoGrazer.COUNT < 5000, "десять скребунов — меньше 5 тыс. треугольников")
	var min_y := INF
	var max_z := -INF
	var min_z := INF
	var max_x := 0.0
	var legs := [false, false, false, false, false, false]
	for i in r.size():
		min_y = minf(min_y, r[i].y)
		max_x = maxf(max_x, absf(r[i].x))
		var p := EcoGrazerLook.part[i]
		if p >= 0 and p < 6:
			legs[p] = true
		else:
			max_z = maxf(max_z, r[i].z)
			min_z = minf(min_z, r[i].z)
	near(min_y, 0.0, 1e-4, "стоит на стопах")
	near(max_z - min_z, 1.5, 0.05, "панцирь 1,5 м")
	ok(max_x >= 0.9 and max_x <= 1.1, "лапы шире панциря")
	ok(not legs.has(false), "ровно шесть лап")
	eq(EcoGrazerLook.hips.size(), 6)
	ok(EcoGrazerLook.paint.has(EcoGrazerLook.RIM), "кромка панциря светлее")


func test_parts_closed_faces_out_by_godot_rule() -> void:
	var r := EcoGrazerLook.rest
	var t := EcoGrazerLook.tris
	var vol := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in range(0, t.size(), 3):
		var p := EcoGrazerLook.part[t[i]] + 1
		if not eq(EcoGrazerLook.part[t[i + 1]] + 1, p, "треугольник в одной части"):
			return
		vol[p] += r[t[i]].dot(r[t[i + 1]].cross(r[t[i + 2]])) / 6.0
	# по правилу Godot (b − a) × (c − a) смотрит внутрь — объём со знаком минус
	ok(vol[0] < -0.3, "панцирь и нижний корпус: %f" % vol[0])
	for p in range(1, 8):
		ok(vol[p] < 0.0, "часть %d: %f" % [p - 1, vol[p]])


func test_legs_step_in_tripods() -> void:
	var a := 0
	var b := 0
	for leg in 6:
		if EcoGrazerLook.tripod(leg) > 0:
			a += 1
		else:
			b += 1
	eq(a, 3)
	eq(b, 3)
	eq(EcoGrazerLook.tripod(0), EcoGrazerLook.tripod(4), "передняя одного борта и средняя другого — вместе")
	ok(EcoGrazerLook.tripod(0) != EcoGrazerLook.tripod(3))

	var g := _grazers(_world()).all[0]
	g.agent.set_state(EcoAgent.State.SEEK)
	g.agent.v = Vector3(0.9, 0, 0)
	ok(EcoGrazerLook.walking(g))
	var max_lift := 0.0
	for i in 100:
		var t := i * 0.031
		var up := 0
		for leg in 6:
			var pose := EcoGrazerLook.leg_pose(g, leg, t)
			ok(absf(pose.x) <= EcoGrazerLook.SWING + 1e-5)
			if pose.y > 1e-4:
				up += 1
			max_lift = maxf(max_lift, pose.y)
		if not ok(up <= 3, "опора всегда хотя бы на трёх лапах"):
			return
	ok(max_lift > 0.05, "стопы поднимаются")

	g.agent.set_state(EcoAgent.State.GRAZE, 10.0)
	g.agent.v = Vector3.ZERO
	eq(EcoGrazerLook.leg_pose(g, 2, 0.4), Vector2.ZERO, "пасётся — лапы стоят")
	var max_scrape := 0.0
	for i in 60:
		max_scrape = maxf(max_scrape, EcoGrazerLook.scrape(g, i * 0.03))
	ok(max_scrape > 0.04, "скребок ходит, пока пасётся")


func test_stands_on_ground_nose_along_course() -> void:
	var g := _grazers(_world()).all[3]
	g.dir = PI / 2.0  # вперёд — +x
	var p := g.agent.p
	var min_y := INF
	var max_x := -INF
	for i in EcoGrazerLook.verts_per_grazer():
		var v := EcoGrazerLook.place(g, 0.0, i)
		min_y = minf(min_y, v.y)
		if EcoGrazerLook.part[i] == EcoGrazerLook.SCRAPER:
			max_x = maxf(max_x, v.x)
	near(min_y, p.y - EcoGrazer.LIFT, 1e-3, "стопы на дне")
	near(min_y, Seabed.height(p.x, p.z), 0.01)
	ok(max_x - p.x > 0.6, "скребок спереди, по курсу")
	ok(EcoGrazerLook.basis(g).determinant() > 0.99, "поворот без зеркала (грани не выворачиваются)")


func test_eaten_grazer_invisible() -> void:
	var gr := _grazers(_world())
	var g := gr.all[1]
	gr.kill(g)
	for i in EcoGrazerLook.verts_per_grazer():
		if not eq(EcoGrazerLook.place(g, 1.0, i), g.agent.p - Vector3(0, EcoGrazer.LIFT, 0), "стянут в точку"):
			return


func test_moss_patches_lie_on_ground() -> void:
	var moss := _moss(_world())
	var m := EcoMossLook.build(moss.patches, Seabed.height)
	eq(m.verts.size(), 22 * 81)
	eq(m.tris.size(), 22 * 128 * 3)
	for i in range(0, m.verts.size(), 7):
		var p := m.verts[i]
		if not near(p.y, Seabed.height(p.x, p.z) + EcoMossLook.ABOVE, 1e-3, "по дну"):
			return
	for i in range(0, m.tris.size(), 3):
		var n := (m.verts[m.tris[i + 1]] - m.verts[m.tris[i]]).cross(m.verts[m.tris[i + 2]] - m.verts[m.tris[i]])
		if not ok(n.y < 0.0, "грань смотрит вверх по правилу Godot"):
			return
	# середина пятна светится, углы 7 × 7 — нет (круг 3,4 м)
	var center := 4 * EcoMossLook.SIDE + 4
	ok(m.base[center] > 0.2, "середина светится")
	near(m.base[0], 0.0, 1e-6, "угол тёмный")
	near(m.base[EcoMossLook.VERTS_PER_PATCH - 1], 0.0, 1e-6)
	eq(m.patch[EcoMossLook.VERTS_PER_PATCH * 5 + 3], 5, "номер пятна у вершины")


func test_eaten_moss_dims() -> void:
	var moss := _moss(_world())
	var m := EcoMossLook.build(moss.patches, Seabed.height)
	var p := moss.patches[5]
	var center := p.index * EcoMossLook.VERTS_PER_PATCH + 4 * EcoMossLook.SIDE + 4
	p.food = 1.0
	near(EcoMossLook.brightness(m, moss.patches, center), m.base[center], 1e-5)
	p.food = 0.0
	near(EcoMossLook.brightness(m, moss.patches, center), m.base[center] * EcoMoss.MIN_GLOW, 1e-5,
		"объеденное — 0,15 яркости")


# ---------- В сцене (MossView, GrazerView) ----------

func test_view_one_moss_mesh_and_one_grazer_multimesh() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var mv := view.moss_view
	var gv := view.grazer_view
	ok(mv != null and mv.get_parent() == view, "мох — в живом мире")
	ok(gv != null and gv.get_parent() == view, "скребуны — в живом мире")
	eq(mv.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(gv.layers, OceanView.LAYER_WORLD)
	eq(mv.mesh.get_surface_count(), 1, "все пятна мха — один меш")
	eq(gv.multimesh.instance_count, 10, "один MultiMesh на всех скребунов")
	var p0 := view.moss.patches[0]
	near(mv.look.verts[4 * EcoMossLook.SIDE + 4].y, Seabed.height(p0.pos.x, p0.pos.z) + EcoMossLook.ABOVE, 1e-3,
		"меш мха — по дну сцены")

	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	for i in 20:
		view.step(0.05, ship)
	var g := view.grazers.all[2]
	var tr := GrazerView.transform_at(gv.buffer, g.index)
	ok(tr.origin.distance_to(EcoGrazerLook.origin(g)) < 1e-3, "место скребуна — из мира")
	ok((tr.basis * Vector3(0, 0, 1)).distance_to(EcoGrazerLook.forward(g)) < 1e-3, "нос по курсу")
	var pose := GrazerView.custom_at(gv.buffer, g.index)
	ok(pose.distance_to(EcoGrazerLook.custom(g, view.world.time)) < 1e-4, "поза — из мира")
	# шейдер двигает вершины так же, как posed: проверим лапу по буферу
	var leg_v := EcoGrazerLook.part.find(0)
	var want := EcoGrazerLook.place(g, view.world.time, leg_v)
	ok((tr * EcoGrazerLook.posed(leg_v, pose)).distance_to(want) < 1e-3, "лапа на месте")

	# пятно объели — шейдер получает новую яркость
	var up := mv.uploads
	p0.food = 0.0
	view.step(0.05, ship)
	ok(mv.uploads > up, "яркость отдана шейдеру")
	near(mv.glows[0], p0.glow(), 1e-5, "объеденное пятно тускнеет")
	up = mv.uploads
	view.step(0.01, ship)
	eq(mv.uploads, up, "мелкое отрастание не гоняет шейдер каждый кадр")

	view.grazers.kill(g)
	view.step(0.05, ship)
	eq(GrazerView.transform_at(gv.buffer, g.index).basis, Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO),
		"съеденный стянут в точку")
	view.queue_free()
	await frames(1)
