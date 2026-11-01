extends TestCase
## Кольчужник (initKelp — нора, crabUpdate в js/creatures.js): нора у второй рощи ленточника, голодный краб
## раскалывает ближнего шипоежа и вплетает иглы в панцирь, у норы охраняет её от корабля и щиплет корпус.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const SPOTS: Array[Vector3] = [Vector3(-60, FLAT, 0), Vector3(0, FLAT, 0)]


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


## Ровное дно, корабль далеко, две рощи в SPOTS и кольчужник.
func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var k := w.add(EcoKelp.new(null, SPOTS)) as EcoKelp
	w.add(EcoKrab.new(k))
	return w


func _kelp(w: EcoWorld) -> EcoKelp:
	return w.systems[0] as EcoKelp


func _krab(w: EcoWorld) -> EcoKrab:
	return w.systems[1] as EcoKrab


# ---------- Нора ----------

func test_den_at_second_grove_edge() -> void:
	var w := _world()
	var cr := _krab(w).crab
	ok(cr != null, "краб есть")
	var c := _kelp(w).groves[1].center
	near(Vector2(cr.den.x - c.x, cr.den.z - c.z).length(), EcoKelp.KELP_R + EcoKrab.DEN_PAD, 1e-4, "у края второй рощи")
	ok(cr.out.dot(EcoKrab.OUT.normalized()) > 0.999, "нора смотрит наружу")
	near(cr.den.y, FLAT, 1e-5, "на дне")
	ok(cr.pos == cr.den, "сидит в норе")
	eq(cr.state, EcoKrab.State.DEN)
	eq(cr.spines, EcoKrab.SPINES_START, "три иглы с начала")


func test_no_groves_no_crab() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	var k := w.add(EcoKelp.new()) as EcoKelp
	var kr := w.add(EcoKrab.new(k)) as EcoKrab
	ok(kr.crab == null, "без рощ краба нет")
	w.run(1.0)
	var out: Array[Dictionary] = []
	kr.targets(w, out)
	eq(out.size(), 0)


# ---------- Охота ----------

func test_fed_crab_stays_home() -> void:
	var w := _world()
	w.run(15.0)
	var cr := _krab(w).crab
	eq(cr.state, EcoKrab.State.DEN, "сытый сидит в норе")
	ok(cr.pos.distance_to(cr.den) < 1e-4)
	eq(_kelp(w).alive_count(), 2 * EcoKelp.URCH_N, "ежи целы")


func test_hungry_crab_cracks_nearest_urchin() -> void:
	var w := _world()
	var k := _kelp(w)
	var cr := _krab(w).crab
	cr.hunger = 1.05
	w.step(0.05)
	eq(cr.state, EcoKrab.State.HUNT, "голодный вышел на охоту")
	var prey := k.urchins[cr.target]
	for u in k.urchins:
		if u.alive and u != prey:
			ok(u.pos.distance_to(cr.den) >= prey.pos.distance_to(cr.den) - 0.05, "ближний к норе ёж")
	ok(prey.grove == 1, "ёж своей рощи")
	var t := 0.0
	while cr.state != EcoKrab.State.HOME and t < 60.0:
		w.step(0.05)
		t += 0.05
	ok(not prey.alive, "ёж расколот")
	ok(prey.respawn >= EcoKrab.RESPAWN_MIN - 1.0 and prey.respawn <= EcoKrab.RESPAWN_MAX, "появится через 80…120 с")
	eq(cr.spines, EcoKrab.SPINES_START + EcoKrab.SPINES_PER_MEAL, "две иглы в панцирь")
	near(cr.hunger, 0.0, 0.01, "сыт")
	eq(_notes(w, EcoKrab.ID, "hunt").size(), 1, "наблюдение «hunt»")
	var armor := _notes(w, EcoKrab.ID, "armor")
	eq(armor.size(), 1, "наблюдение «armor»")
	ok(armor[0].text().begins_with("Донный краб вплетает иглы морского ежа"), armor[0].text())
	w.run(15.0)
	eq(cr.state, EcoKrab.State.DEN, "вернулся в нору")
	ok(Vector2(cr.pos.x - cr.den.x, cr.pos.z - cr.den.z).length() < EcoKrab.HOME_DIST)


## Поворот по дну (EcoAgent.turn_flat): навстречу — разворот с ограниченной скоростью, а не через нулевой курс.
func test_turn_flat_reverses_without_zero() -> void:
	var f := Vector3.FORWARD
	var d := EcoAgent.turn_flat(f, Vector3.BACK, 0.05, 4.0, 2.5)
	near(d.length(), 1.0, 1e-5, "курс не обнулился")
	near(f.angle_to(d), 2.5 * 0.05, 1e-4, "навстречу — не быстрее 2,5 рад/с")
	var e := EcoAgent.turn_flat(f, Vector3.LEFT, 0.05, 4.0, 2.5)
	ok(e.x < 0.0, "влево — через лево")
	near(f.angle_to(e), 0.125, 1e-4, "доля угла 4/с меньше предела — предел")
	var small := EcoAgent.turn_flat(f, Vector3(-0.1, 0.0, -1.0), 0.05, 4.0, 2.5)
	near(f.angle_to(small), Vector3.FORWARD.angle_to(Vector3(-0.1, 0, -1)) * 0.2, 1e-4, "малый угол — доля 4/с")
	ok(EcoAgent.turn_flat(f, Vector3.ZERO, 0.05, 4.0, 2.5) == f, "нулевая цель — курс тот же")
	near(EcoAgent.turn_flat(f, Vector3(0, 5, -1), 0.05, 4.0, 2.5).y, 0.0, 1e-6, "без вертикали")


## Весь путь за ежом и домой — тело доворачивает не быстрее TURN_MAX (раньше lerp курса щёлкал носом
## на развороте от расколотого ежа к норе), в норе — снова лицом наружу.
func test_crab_turns_smoothly_and_faces_out_at_home() -> void:
	var w := _world()
	var cr := _krab(w).crab
	cr.hunger = 1.05
	var dt := 0.05
	var worst := 0.0
	var t := 0.0
	var prev := cr.dir
	var saw_home := false
	while t < 70.0:
		w.step(dt)
		t += dt
		near(cr.dir.length(), 1.0, 1e-4, "курс не нулевой")
		worst = maxf(worst, prev.angle_to(cr.dir))
		prev = cr.dir
		saw_home = saw_home or cr.state == EcoKrab.State.HOME
		if saw_home and cr.state == EcoKrab.State.DEN and t > 5.0:
			break
	ok(saw_home, "сходил за ежом и домой")
	ok(worst <= EcoKrab.TURN_MAX * dt + 1e-4, "поворот за шаг %.3f ≤ %.3f" % [worst, EcoKrab.TURN_MAX * dt])
	w.run(3.0)
	ok(cr.dir.dot(cr.out) > 0.99, "в норе лицом наружу")


func test_crack_takes_three_seconds() -> void:
	var w := _world()
	var k := _kelp(w)
	var cr := _krab(w).crab
	var u := k.urchins[EcoKelp.URCH_N]
	cr.pos = u.pos
	cr.target = u.index
	cr.state = EcoKrab.State.HUNT
	cr.timer = 60.0
	w.step(0.02)
	eq(cr.state, EcoKrab.State.CRACK)
	w.run(2.5)
	ok(u.alive, "ещё раскалывает")
	ok(cr.raise > 0.2, "клешни работают")
	w.run(0.6)
	ok(not u.alive, "расколол за 3 с")


func test_spines_capped() -> void:
	var w := _world()
	var k := _kelp(w)
	var cr := _krab(w).crab
	cr.spines = EcoKrab.SPINE_MAX - 1
	var u := k.urchins[EcoKelp.URCH_N + 1]
	cr.pos = u.pos
	cr.target = u.index
	cr.state = EcoKrab.State.CRACK
	cr.timer = 0.01
	w.step(0.05)
	eq(cr.spines, EcoKrab.SPINE_MAX, "не больше 10 игл")


func test_urchins_beyond_reach_ignored() -> void:
	var w := _world()
	var k := _kelp(w)
	var cr := _krab(w).crab
	for u in k.urchins:
		if u.pos.distance_to(cr.den) < EcoKrab.HUNT_R:
			k.kill(u, 1000.0)
	cr.hunger = 1.2
	w.step(0.05)
	eq(cr.state, EcoKrab.State.DEN, "дальних ежей не ищет")


func test_crab_keeps_its_grove_dense() -> void:
	# за 10 минут голодный краб съедает ежей у норы — без них ленты рощи объедают меньше
	var a := _world()
	var b := EcoWorld.new()
	b.ground = _flat
	b.ship.pos = FAR
	b.add(EcoKelp.new(null, SPOTS))
	a.run(600.0)
	b.run(600.0)
	ok(_kelp(a).alive_count() < _kelp(b).alive_count(), "краб раскалывал ежей")
	ok(_kelp(a).groves[1].cover > _kelp(b).groves[1].cover, "роща у норы гуще: %.2f > %.2f" % [_kelp(a).groves[1].cover, _kelp(b).groves[1].cover])


# ---------- Охрана норы ----------

func test_guard_and_pinch_ship_near_den() -> void:
	var w := _world()
	var cr := _krab(w).crab
	w.ship.pos = cr.den + Vector3(0, 4, 0)
	w.step(0.05)
	eq(cr.state, EcoKrab.State.GUARD, "охраняет нору")
	eq(_notes(w, EcoKrab.ID, "guard").size(), 2, "поднял клешни и зажал корпус")
	var link := w.take_link()
	var hits := 0
	for e in link:
		if e["type"] == EcoLink.HIT:
			hits += 1
			near(float(e["damage"]), EcoKrab.PINCH_DAMAGE, 1e-6)
			eq(e["by"], "Донный краб")
	eq(hits, 1, "щипок")
	w.run(8.5)
	var later := 0
	for e in w.take_link():
		if e["type"] == EcoLink.HIT:
			later += 1
	eq(later, 1, "щипок раз в 8 с")
	near(cr.raise, 1.0, 0.01, "клешни подняты")
	ok(cr.dir.dot(Vector3(w.ship.pos.x - cr.pos.x, 0, w.ship.pos.z - cr.pos.z).normalized()) > 0.9 \
		or Vector2(w.ship.pos.x - cr.pos.x, w.ship.pos.z - cr.pos.z).length() < 0.2, "смотрит на корабль")


func test_guard_without_pinch_between_7_and_12_m() -> void:
	var w := _world()
	var cr := _krab(w).crab
	w.ship.pos = cr.den + Vector3(10, 0, 0)
	w.run(5.0)
	eq(cr.state, EcoKrab.State.GUARD)
	eq(w.hits, 0, "дальше 7 м не щиплет")
	w.ship.pos = cr.den + Vector3(13, 0, 0)
	w.run(1.0)
	eq(cr.state, EcoKrab.State.GUARD, "до 14 м ещё охраняет")
	w.ship.pos = FAR
	w.step(0.05)
	eq(cr.state, EcoKrab.State.HOME, "корабль ушёл — домой")
	w.run(2.0)
	eq(cr.state, EcoKrab.State.DEN)


func test_ship_breaks_hunt_but_not_crack() -> void:
	var w := _world()
	var k := _kelp(w)
	var cr := _krab(w).crab
	cr.hunger = 1.2
	w.step(0.05)
	eq(cr.state, EcoKrab.State.HUNT)
	w.ship.pos = cr.den + Vector3(0, 5, 0)
	w.step(0.05)
	eq(cr.state, EcoKrab.State.GUARD, "охота брошена")
	eq(cr.target, -1)
	w.ship.pos = FAR
	var u := k.urchins[EcoKelp.URCH_N + 2]
	cr.pos = u.pos
	cr.target = u.index
	cr.state = EcoKrab.State.CRACK
	cr.timer = 1.0
	w.ship.pos = cr.den + Vector3(0, 5, 0)
	w.step(0.05)
	eq(cr.state, EcoKrab.State.CRACK, "раскалывает и при корабле")


# ---------- Испуг (скальник) ----------

func test_scared_crab_runs_home_and_skips_hunt() -> void:
	var w := _world()
	var kr := _krab(w)
	var cr := kr.crab
	cr.hunger = 1.2
	w.step(0.05)
	eq(cr.state, EcoKrab.State.HUNT)
	w.run(3.0)
	var away := Vector2(cr.pos.x - cr.den.x, cr.pos.z - cr.den.z).length()
	kr.scare(10.0)
	eq(cr.state, EcoKrab.State.HOME, "бросил охоту")
	w.step(0.5)
	var now := Vector2(cr.pos.x - cr.den.x, cr.pos.z - cr.den.z).length()
	ok(now < away - 0.8 or now < EcoKrab.HOME_DIST, "удирает бегом: %.2f → %.2f" % [away, now])
	w.run(5.0)
	eq(cr.state, EcoKrab.State.DEN)
	w.run(1.0)
	eq(cr.state, EcoKrab.State.DEN, "напуганный не выходит")
	w.run(5.0)
	eq(cr.state, EcoKrab.State.HUNT, "испуг прошёл — снова охота")


# ---------- Сонар, сканер, детерминизм ----------

func test_target_for_sonar_and_scanner() -> void:
	var w := _world()
	var out: Array[Dictionary] = []
	_krab(w).targets(w, out)
	eq(out.size(), 1)
	eq(out[0]["species"], EcoKrab.ID)
	near(float(out[0]["r"]), 0.9, 1e-6)
	ok(out[0]["sonar"] and not out[0]["hidden"])


func test_same_seed_same_story() -> void:
	var a := _world()
	var b := _world()
	_krab(a).crab.hunger = 1.2
	_krab(b).crab.hunger = 1.2
	a.run(40.0)
	b.run(40.0)
	ok(_krab(a).crab.pos.is_equal_approx(_krab(b).crab.pos), "один и тот же путь")
	for i in _kelp(a).urchins.size():
		near(_kelp(a).urchins[i].respawn, _kelp(b).urchins[i].respawn, 1e-5)


func test_reset_returns_crab_home() -> void:
	var w := _world()
	var cr := _krab(w).crab
	cr.hunger = 1.2
	w.run(20.0)
	w.reset()
	cr = _krab(w).crab
	eq(cr.state, EcoKrab.State.DEN)
	eq(cr.spines, EcoKrab.SPINES_START)
	ok(cr.pos == cr.den)


# ---------- Сцена ----------

func test_view_four_draws_spines_follow_meals() -> void:
	var w := _world()
	var kr := _krab(w)
	var v := KrabView.new(kr)
	tree.root.add_child(v)
	await frames(1)
	ok(v.visible)
	eq(v.den.layers, OceanView.LAYER_WORLD)
	eq(v.body.layers, OceanView.LAYER_WORLD)
	eq(v.spines.layers, OceanView.LAYER_WORLD)
	eq(v.spines.multimesh.instance_count, EcoKrab.SPINE_MAX)
	eq(v.shown_spines, EcoKrab.SPINES_START, "три иглы")
	var hid := KelpView.transform_at(v.spine_buffer, EcoKrab.SPINES_START, KelpView.STRIDE)
	ok(hid.basis.x.length() < 1e-6, "лишние сжаты: %s" % hid)
	ok(v.body.global_position.is_equal_approx(kr.crab.pos), "тело на месте краба")
	var writes := v.spine_writes
	v.sync(1.0)
	eq(v.spine_writes, writes, "без перемен иглы не переписываются")
	kr.crab.spines = 7
	kr.dirty = true
	kr.crab.raise = 1.0
	v.sync(2.0)
	eq(v.shown_spines, 7)
	ok(KelpView.transform_at(v.spine_buffer, 6, KelpView.STRIDE).basis.x.length() > 0.5, "новая игла видна")
	near(v.claws.rotation.x, -0.9, 1e-5, "клешни подняты")
	v.queue_free()
	await frames(1)


## Вплетённая игла вырастает из панциря за SPINE_RISE, а не появляется за кадр (раньше кончик прыгал на 0,3 м).
func test_view_new_spine_grows_smoothly() -> void:
	var w := _world()
	var kr := _krab(w)
	var v := KrabView.new(kr)
	tree.root.add_child(v)
	await frames(1)
	var tip := Vector3(0, 0.3, 0)
	var n := EcoKrab.SPINES_START
	kr.crab.spines = n + EcoKrab.SPINES_PER_MEAL
	kr.dirty = true
	var dt := 1.0 / 30.0
	var t := 1.0
	v.sync(t)
	var last := KelpView.transform_at(v.spine_buffer, n, KelpView.STRIDE) * tip
	var worst := 0.0
	for i in int(KrabView.SPINE_RISE / dt) + 3:
		t += dt
		v.sync(t)
		var p := KelpView.transform_at(v.spine_buffer, n, KelpView.STRIDE) * tip
		worst = maxf(worst, p.distance_to(last))
		last = p
	ok(worst < 0.03, "кончик новой иглы за шаг %.3f м < 0,03" % worst)
	near(v.spine_k[n], 1.0, 1e-6, "выросла во всю длину")
	ok(last.is_equal_approx(KrabView.spine_transform(n) * tip), "кончик на месте целой иглы")
	var writes := v.spine_writes
	v.sync(t + 1.0)
	eq(v.spine_writes, writes, "выросла — буфер больше не переписывается")
	kr.crab.spines = n
	v.sync(t + 0.5)
	v.sync(t + 0.1)
	eq(v.spine_k[n], 0.0, "время назад — сразу к цели")
	v.queue_free()
	await frames(1)


func test_view_without_crab_hidden() -> void:
	var w := EcoWorld.new()
	var kr := w.add(EcoKrab.new(w.add(EcoKelp.new()) as EcoKelp)) as EcoKrab
	var v := KrabView.new(kr)
	tree.root.add_child(v)
	await frames(1)
	ok(not v.visible)
	v.sync(1.0)
	v.queue_free()
	await frames(1)


func test_meshes_face_outward() -> void:
	# обход по часовой снаружи: (b − a) × (c − a) смотрит внутрь, нормаль грани — наружу
	for m: ArrayMesh in [KrabView.build_body(), KrabView.build_den(), KrabView.build_spine()]:
		var arr := m.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bad := 0
		for i in range(0, v.size(), 3):
			var c := (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
			if c.dot(n[i]) > 0.0:
				bad += 1
		eq(bad, 0, "все грани наружу")


func test_eco_view_has_krab() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	var cr := view.krab.crab
	ok(cr != null, "краб у второй рощи")
	ok(view.krab.kelp == view.kelp)
	var c := view.kelp.groves[1].center
	near(Vector2(cr.den.x - c.x, cr.den.z - c.z).length(), EcoKelp.KELP_R + EcoKrab.DEN_PAD, 1e-3)
	near(cr.den.y, Seabed.height(cr.den.x, cr.den.z), 1e-3, "нора на дне")
	ok(view.krab_view != null and view.krab_view.get_parent() == view)
	var ship := EcoLink.ShipState.new()
	ship.pos = Helm.Ship.START
	view.step(0.1, ship)
	view.queue_free()
	await frames(1)


# ---------- «Экономно» (Б6) ----------

func test_view_lite_coarser_same_materials() -> void:
	var w := _world()
	var kr := _krab(w)
	var v := KrabView.new(kr)
	tree.root.add_child(v)
	await frames(1)
	var full := v.tris()
	eq(full, 424, "полный краб (полюса эллипсоидов без вырожденных граней)")
	var mats := [v.den.mesh.surface_get_material(0), v.body.mesh.surface_get_material(0),
		v.claws.mesh.surface_get_material(0)]
	var box := v.body.mesh.get_aabb()
	var spines := v.spines.multimesh
	var dust := v.dust_view
	v.set_lite(true)
	ok(v.lite, "краб — на «Экономно»")
	eq(v.tris(), 286, "треугольников: %d → %d" % [full, v.tris()])
	ok(v.tris() * 100 <= full * 70, "не больше 70 %")
	ok(v.den.mesh.surface_get_material(0) == mats[0], "нора та же")
	ok(v.body.mesh.surface_get_material(0) == mats[1], "материал панциря тот же (свечение)")
	ok(v.claws.mesh.surface_get_material(0) == mats[2], "материал клешней тот же")
	for mi: MeshInstance3D in [v.den, v.body, v.claws]:
		eq(mi.mesh.get_surface_count(), 1, "%s — один вызов" % mi.name)
	ok(v.spines.multimesh == spines and v.dust_view == dust, "иглы и муть те же")
	var lb := v.body.mesh.get_aabb()
	ok(lb.size.x > box.size.x * 0.9 and lb.size.y > box.size.y * 0.95, "силуэт тот же: %s → %s" % [box.size, lb.size])
	ok(v.claws.get_parent() == v.body and v.spines.get_parent() == v.body, "клешни и иглы — на теле")
	v.set_lite(false)
	eq(v.tris(), full, "назад — полный краб")
	v.queue_free()
	await frames(1)


func test_lite_meshes_face_outward() -> void:
	for m: ArrayMesh in [KrabView.build_body(true), KrabView.build_claws(true)]:
		var arr := m.surface_get_arrays(0)
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bad := 0
		for i in range(0, vv.size(), 3):
			if (vv[i + 1] - vv[i]).cross(vv[i + 2] - vv[i]).dot(n[i]) > 0.0:
				bad += 1
		eq(bad, 0, "все грани наружу")


func test_lite_kept_after_world_reset() -> void:
	var ev := EcoView.new()
	ev.ground = Seabed.height
	ev.set_lite(true)
	ok(ev.krab_view.lite, "уровень дошёл до краба")
	var t := ev.krab_view.tris()
	ev.ground = Seabed.height
	ok(ev.krab_view.lite, "после сброса мира — по-прежнему «Экономно»")
	eq(ev.krab_view.tris(), t, "и панцирь грубый")
	ev.set_lite(false)
	ev.free()
