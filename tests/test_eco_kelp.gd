extends TestCase
## Ленточник и шипоежи (initKelp, urchinUpdate, kelpUpdate, kelpShelter в js/creatures.js): две рощи по 34 ленты
## у стай светляков 1 и 2, по 7 ежей у рощи объедают ленты, ленты отрастают; в густой роще серпохвост теряет
## напуганную стаю («kelp»), в объеденной ловит («bare»); три MultiMesh в сцене.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const SPOT := Vector3(0, FLAT, 0)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


## Ровное дно, корабль далеко, одна роща в SPOT.
func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoKelp.new(null, [SPOT] as Array[Vector3]))
	return w


func _kelp(w: EcoWorld) -> EcoKelp:
	for s in w.systems:
		if s is EcoKelp:
			return s
	return null


## Светляки, серпохвосты и ленточник у стай 1 и 2 на ровном дне.
func _pred_world(with_kelp := true) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var p := w.add(EcoPred.new(f)) as EcoPred
	p.alert = 0.0  # бросок сразу: здесь чутьё и бросок; «замер» #1498 — test_eco_pred_zamer
	if with_kelp:
		p.kelp = w.add(EcoKelp.new(f)) as EcoKelp
	return w


## Хищник 0 охотится на первую рыбку стаи 1, рыбка — в середине рощи 0, стая напугана.
func _hunt(w: EcoWorld) -> Array:
	var fish := w.systems[0] as EcoFish
	var pr := (w.systems[1] as EcoPred).all[0]
	var sh := fish.shoals[1]
	var prey: EcoFish.Fish = sh.members[0]
	prey.agent.p = Vector3(sh.home.x, FLAT + 1.5, sh.home.z)
	sh.alarm = 5.0
	pr.agent.p = prey.agent.p + Vector3(6, 2, 0)
	pr.mode = EcoPred.Mode.HUNT
	pr.agent.timer = 12.0
	pr.prey = prey
	return [pr, prey]


# ---------- Расстановка ----------

## #1400: рощи перехода 00 → 01 — с восточной стороны прямой между местами, краем не ближе ROUTE_GAP;
## западная сторона остаётся открытым обходом.
func test_route_groves_east_of_passage() -> void:
	var a := Vector2(LayerMap.POINTS["00"]["x"], LayerMap.POINTS["00"]["z"])
	var b := Vector2(LayerMap.POINTS["01"]["x"], LayerMap.POINTS["01"]["z"])
	var d := (b - a).normalized()
	var right := Vector2(-d.y, d.x)
	ok(right.x > 0.0, "правая нормаль к курсу на север смотрит на восток (+X)")
	for p in EcoKelp.ROUTE:
		ok(EcoKelp.EXTRA.has(p), "роща перехода — в рощах EcoKelp")
		var t := (p - a).dot(d) / a.distance_to(b)
		ok(t > 0.1 and t < 0.9, "роща посередине перехода, не у самих мест")
		var side := (p - a).dot(right)
		ok(side - EcoKelp.KELP_R >= EcoKelp.ROUTE_GAP, "край рощи %s в %.1f м от прямой 00 → 01" % [p, side - EcoKelp.KELP_R])
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var f := w.add(EcoFish.new()) as EcoFish
	var k := w.add(EcoKelp.new(f)) as EcoKelp
	for gr in k.groves:
		var c := Vector2(gr.center.x, gr.center.z)
		var t := (c - a).dot(d) / a.distance_to(b)
		if t > 0.0 and t < 1.0:
			ok((c - a).dot(right) > 0.0 or absf((c - a).dot(right)) > 30.0, "на западе у прохода рощ нет: %s" % c)


func test_two_groves_by_shoals_on_ground() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var f := w.add(EcoFish.new()) as EcoFish
	var k := w.add(EcoKelp.new(f)) as EcoKelp
	eq(k.groves.size(), 2 + EcoKelp.EXTRA.size(), "две рощи у стай, роща в Тихой заводи, две у врат 07 (#831) и три на переходе 00 → 01 (#1400)")
	eq(k.urchins.size(), k.groves.size() * EcoKelp.URCH_N, "по 7 ежей у рощи")
	eq(k.groves[2].shoal, null, "у рощи заводи своей стаи нет")
	near(k.groves[2].center.x, EcoKelp.EXTRA[0].x, 1e-4)
	for gi in k.groves.size():
		var gr := k.groves[gi]
		if gi < 2:
			ok(gr.shoal == f.shoals[EcoKelp.SHOALS[gi]], "роща у своей стаи")
			near(gr.center.x, f.shoals[gi + 1].home.x, 1e-4)
		eq(gr.stalks.size(), EcoKelp.KELP_N, "34 ленты")
		near(gr.cover, 1.0, 1e-6, "густая")
		for s in gr.stalks:
			ok(Vector2(s.pos.x - gr.center.x, s.pos.z - gr.center.z).length() <= EcoKelp.KELP_R + 1e-3, "лента в круге 7 м")
			near(s.pos.y, Seabed.height(s.pos.x, s.pos.z) - EcoKelp.SINK, 1e-3, "лента стоит на дне")
			ok(s.height >= EcoKelp.H_MIN and s.height <= EcoKelp.H_MAX, "высота 3–5,5 м")
	for u in k.urchins:
		var gr := k.groves[u.grove]
		var r := Vector2(u.pos.x - gr.center.x, u.pos.z - gr.center.z).length()
		ok(r >= EcoKelp.KELP_R * 0.6 - 1e-3 and r <= EcoKelp.KELP_R + 2.0 + 1e-3, "ёж в кольце у рощи")
		near(u.pos.y, Seabed.height(u.pos.x, u.pos.z) + EcoKelp.UP, 1e-3, "ёж на дне")


func test_no_groves_without_shoals() -> void:
	var w := EcoWorld.new()
	var k := w.add(EcoKelp.new()) as EcoKelp
	eq(k.groves.size(), 0)
	eq(k.urchins.size(), 0)
	w.run(1.0)


func test_same_seed_same_grove() -> void:
	var a := _kelp(_world())
	var b := _kelp(_world())
	for i in EcoKelp.KELP_N:
		near(a.groves[0].stalks[i].height, b.groves[0].stalks[i].height, 1e-6)
	for i in a.urchins.size():
		ok(a.urchins[i].pos.is_equal_approx(b.urchins[i].pos), "ежи там же")


# ---------- Ежи и ленты ----------

func test_urchins_graze_stalks_down() -> void:
	var w := _world()
	var k := _kelp(w)
	w.run(60.0)
	var eaten := 0
	for s in k.groves[0].stalks:
		if s.f < 0.99:
			eaten += 1
		ok(s.f >= EcoKelp.F_MIN - 1e-6, "не тоньше голого стебля")
	ok(eaten >= 3, "ежи объели ленты (%d)" % eaten)
	ok(k.groves[0].cover < 1.0, "роща поредела: %.2f" % k.groves[0].cover)
	var gz := _notes(w, EcoKelp.ID, "graze")
	ok(gz.size() >= 1, "наблюдение «graze»")
	var said := 0
	for ev in gz:
		if ev.text() != "":
			said += 1
	eq(said, 1, "текст — раз в 90 с у рощи")
	ok(gz[0].text().contains("объедает ленточник до стеблей"), gz[0].text())


func test_each_stalk_one_eater() -> void:
	var w := _world()
	var k := _kelp(w)
	w.run(20.0)
	var seen := {}
	for u in k.urchins:
		if u.goal >= 0:
			ok(not seen.has(u.goal), "одну ленту ест один ёж")
			seen[u.goal] = true
			eq(k.groves[0].stalks[u.goal].eater, u.index)


func test_stalk_regrows_without_eater() -> void:
	var w := _world()
	var k := _kelp(w)
	for u in k.urchins:
		k.kill(u, 1000.0)
	var s := k.groves[0].stalks[0]
	s.f = 0.5
	w.run(10.0)
	near(s.f, 0.5 + 10.0 * EcoKelp.REGROW, 1e-3, "отрастает 0,005 в секунду")


func test_cover_from_stalks() -> void:
	var w := _world()
	var k := _kelp(w)
	for u in k.urchins:
		k.kill(u, 1000.0)
	for s in k.groves[0].stalks:
		s.f = EcoKelp.F_MIN
	w.step(1e-4)
	near(k.groves[0].cover, 0.0, 1e-3, "голые стебли — густота 0")


func test_killed_urchin_respawns() -> void:
	var w := _world()
	var k := _kelp(w)
	var u := k.urchins[0]
	w.run(5.0)
	var g := u.goal
	k.kill(u, 2.0)
	ok(not u.alive)
	if g >= 0:
		eq(k.groves[0].stalks[g].eater, -1, "лента свободна")
	eq(k.alive_count(), EcoKelp.URCH_N - 1)
	w.run(2.1)
	ok(u.alive, "появился снова")


# ---------- Укрытие стаи и серпохвост ----------

func test_shelter_needs_alarm_and_cover() -> void:
	var w := _pred_world()
	var h := _hunt(w)
	var prey: EcoFish.Fish = h[1]
	var k := _kelp(w)
	ok(k.shelter(prey) == k.groves[0], "напуганная стая в густой роще прячется")
	prey.shoal.alarm = 0.0
	ok(k.shelter(prey) == null, "спокойная — не прячется")
	prey.shoal.alarm = 5.0
	k.groves[0].cover = EcoKelp.COVER_MIN - 0.01
	ok(k.shelter(prey) == null, "в объеденной роще не спрятаться")
	k.groves[0].cover = 1.0
	prey.agent.p.y = FLAT + EcoKelp.SHELTER_UP + 0.5
	ok(k.shelter(prey) == null, "выше лент — не в роще")
	var other: EcoFish.Fish = (w.systems[0] as EcoFish).shoals[0].members[0]
	other.shoal.alarm = 5.0
	other.agent.p = prey.agent.p
	other.agent.p.y = FLAT + 1.5
	ok(k.shelter(other) == null, "роща прячет только свою стаю")


func test_pred_loses_fish_in_kelp() -> void:
	var w := _pred_world()
	var h := _hunt(w)
	var pr: EcoPred.Pred = h[0]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "стая в ленточнике — охота сорвана")
	ok(pr.prey == null)
	ok(pr.agent.timer >= 4.0 - 0.1 and pr.agent.timer <= 8.0, "патруль 4–8 с")
	var ev := _notes(w, EcoFish.ID, "kelp")
	eq(ev.size(), 1, "наблюдение светляка «kelp»")
	ok(ev[0].text().contains("стая спряталась в ленточнике"), ev[0].text())
	_hunt(w)
	w.step(EcoWorld.MAX_STEP)
	eq(_notes(w, EcoFish.ID, "kelp").size(), 1, "раз в 40 с у рощи")


func test_pred_hunts_on_without_kelp() -> void:
	var w := _pred_world(false)
	var h := _hunt(w)
	var pr: EcoPred.Pred = h[0]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.HUNT, "без ленточника — охотится дальше")


func test_hungry_pred_does_not_pick_fish_in_kelp() -> void:
	var w := _pred_world()
	var fish := w.systems[0] as EcoFish
	var pred := w.systems[1] as EcoPred
	var sh := fish.shoals[1]
	sh.alarm = 5.0
	for f: EcoFish.Fish in fish.all:
		f.agent.p = Vector3(sh.home.x, FLAT + 1.5, sh.home.z) if f.shoal == sh else FAR
		if f.shoal != sh:
			f.agent.alive = false
	var pr := pred.all[0]
	pr.agent.p = Vector3(sh.home.x + 10, FLAT + 4, sh.home.z)
	pr.hunger = 0.9
	pr.mode = EcoPred.Mode.PATROL
	ok(fish.nearest_fish(pr.agent.p, EcoPred.HUNT_RADIUS, pred._hidden_fish()) == null, "в густом ленточнике не видно")
	_kelp(w).groves[0].cover = 0.2
	ok(fish.nearest_fish(pr.agent.p, EcoPred.HUNT_RADIUS, pred._hidden_fish()) != null, "в объеденном — видно")


func test_catch_in_bare_grove_is_bare() -> void:
	var w := _pred_world()
	var k := _kelp(w)
	for u in k.urchins:
		k.kill(u, 1000.0)
	for s in k.groves[0].stalks:
		s.f = EcoKelp.F_MIN
	w.step(1e-4)  # густота пересчитана
	var h := _hunt(w)
	var pr: EcoPred.Pred = h[0]
	var prey: EcoFish.Fish = h[1]
	pr.agent.p = prey.agent.p + Vector3(0.5, 0, 0)
	w.step(EcoWorld.MAX_STEP)
	ok(not prey.agent.alive, "в объеденной роще светляк пойман")
	var ev := _notes(w, EcoKelp.ID, "bare")
	eq(ev.size(), 1, "наблюдение «bare»")
	ok(ev[0].text().contains("Ленточник объеден морскими ежами"), ev[0].text())


func test_bare_is_link_observe() -> void:
	var w := _pred_world()
	var k := _kelp(w)
	w.ship.pos = k.groves[0].center + Vector3(0, 10, 0)
	k.caught_at(w, k.groves[0].center)
	eq(w.take_link().size(), 0, "в густой роще не «bare»")
	k.groves[0].cover = 0.1
	k.caught_at(w, k.groves[0].center)
	var link := w.take_link()
	var found := false
	for e in link:
		if e["type"] == EcoLink.OBSERVE and e["species"] == EcoKelp.ID and e["note"] == "bare":
			found = true
	ok(found, "кораблю — EcoLink.OBSERVE «bare»")


# ---------- Сонар и сканер ----------

func test_targets_each_urchin_for_scanner_herd_for_sonar() -> void:
	var w := _world()
	var k := _kelp(w)
	k.kill(k.urchins[0], 100.0)
	var out: Array[Dictionary] = []
	k.targets(w, out)
	var scan := 0
	var sonar := 0
	for t in out:
		eq(t["species"], EcoKelp.ID)
		if not t["hidden"]:
			scan += 1
			ok(not t["sonar"], "отдельный ёж на сонаре не виден")
		if t["sonar"]:
			sonar += 1
			ok(t["hidden"], "отметка стада — не цель сканера")
	eq(scan, EcoKelp.URCH_N - 1, "сканеру — каждый живой ёж")
	eq(sonar, 1, "сонару — одно стадо у рощи")


# ---------- Сцена ----------

func test_view_two_multimeshes() -> void:
	var w := _world()
	var k := _kelp(w)
	var v := KelpView.new(k)
	tree.root.add_child(v)
	await frames(1)
	eq(v.stalks.multimesh.instance_count, EcoKelp.KELP_N)
	eq(v.bodies.multimesh.instance_count, EcoKelp.URCH_N)
	# #849: ёж целиком (тело, стержни, кончики) — один MultiMesh и одна поверхность, кроме мути узлов два
	var mms := v.find_children("*", "MultiMeshInstance3D", false, false).filter(
		func(n: Node) -> bool: return n != v.dust_view)
	eq(mms.size(), 2, "ленты и ежи — два вызова отрисовки")
	eq(v.bodies.multimesh.mesh.get_surface_count(), 1, "ёж — одна поверхность")
	eq(v.stalks.layers, OceanView.LAYER_WORLD)
	var s := k.groves[0].stalks[3]
	var tr := KelpView.transform_at(v.stalk_buffer, 3)
	ok(tr.origin.is_equal_approx(s.pos), "лента на месте")
	near(tr.basis.y.length(), s.height, 1e-3, "целая лента — во всю высоту")
	var writes := v.stalk_writes
	v.sync(1.0)
	eq(v.stalk_writes, writes, "без перемен ленты не переписываются")
	s.f = 0.3
	w.step(1e-4)
	v.sync(1.0)
	eq(v.stalk_writes, writes + 1, "объеденная — переписана")
	tr = KelpView.transform_at(v.stalk_buffer, 3)
	ok(tr.basis.y.length() < s.height * 0.6, "объеденная лента ниже")
	var u := k.urchins[2]
	k.kill(u, 100.0)
	v.sync(2.0)
	near(KelpView.transform_at(v.urchin_buffer, 2, KelpView.STRIDE).basis.x.length(), 0.0, 1e-6, "съеденного ежа не видно")
	v.queue_free()
	await frames(1)


## Съеденный ёж сжимается на месте за URCHIN_FADE, появившийся вырастает за URCHIN_RISE — не за кадр.
func test_view_urchin_fades_and_grows() -> void:
	var w := EcoWorld.new()
	w.ship.pos = Vector3(500, -30, 500)
	var k := w.add(EcoKelp.new(null, [Vector3(0, -40, 0)] as Array[Vector3])) as EcoKelp
	w.reset()
	var v := KelpView.new(k)
	tree.root.add_child(v)
	await frames(1)
	var u := k.urchins[2]
	var t := 1.0
	v.sync(t)
	var at := u.pos
	var size0 := KelpView.transform_at(v.urchin_buffer, 2, KelpView.STRIDE).basis.x.length()
	ok(size0 > 0.9 * KelpView.urchin_scale(2), "живой ёж во весь свой размер")
	k.kill(u, 100.0)
	var dt := 1.0 / 30.0
	var last := size0
	var worst := 0.0
	for i in int(KelpView.URCHIN_FADE / dt) + 2:
		t += dt
		v.sync(t)
		var tr := KelpView.transform_at(v.urchin_buffer, 2, KelpView.STRIDE)
		var sz := tr.basis.x.length()
		worst = maxf(worst, last - sz)
		last = sz
		if sz > 0.0:
			ok(tr.origin.is_equal_approx(at), "сжимается там, где съеден")
	ok(worst < 0.15, "за шаг меньше на %.3f < 0,15" % worst)
	near(last, 0.0, 1e-6, "съеденного не видно")
	u.respawn = 0.0
	for i in 8:
		if not u.alive:
			w.step(1e-4)
	ok(u.alive, "появился снова")
	t += dt
	v.sync(t)
	var grow := KelpView.transform_at(v.urchin_buffer, 2, KelpView.STRIDE)
	ok(grow.basis.x.length() < 0.05, "появился крошечным: %.3f" % grow.basis.x.length())
	ok(grow.origin.is_equal_approx(u.pos), "растёт на новом месте")
	t += KelpView.URCHIN_RISE
	v.sync(t)
	ok(KelpView.transform_at(v.urchin_buffer, 2, KelpView.STRIDE).basis.x.length() > 0.9 * KelpView.urchin_scale(2), "вырос во весь свой размер")
	v.queue_free()
	await frames(1)


func test_eco_view_has_kelp() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	ok(view.preds.kelp == view.kelp, "серпохвосты знают про ленточник")
	eq(view.kelp.groves.size(), 2 + EcoKelp.EXTRA.size())
	ok(view.kelp_view != null and view.kelp_view.get_parent() == view)
	var ship := EcoLink.ShipState.new()
	ship.pos = Helm.Ship.START
	view.step(0.1, ship)
	view.queue_free()
	await frames(1)


func test_view_lite_draws_every_other_stalk() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var kv := view.kelp_view
	var n := view.kelp.groves.size()
	var all := n * EcoKelp.KELP_N
	ok(n > 0, "рощи есть")
	eq(kv.drawn(), all, "на «Обычно» — все ленты")
	view.set_lite(true)
	ok(kv.lite, "ленточник — на «Экономно»")
	eq(kv.drawn(), n * KelpView.lite_per_grove(), "каждая вторая лента")
	ok(kv.drawn() < all * 0.6, "лент почти вдвое меньше")
	var seen := {}
	for g in n:
		for k in EcoKelp.KELP_N:
			var s := KelpView.slot(g, k, n, true)
			seen[s] = true
			eq(s < kv.drawn(), KelpView.lite_shown(k), "видно только показанное (%d, %d)" % [g, k])
	eq(seen.size(), all, "места в буфере не повторяются")
	var gr := view.kelp.groves[n - 1]
	var st := gr.stalks[4]
	ok(KelpView.transform_at(kv.stalk_buffer, KelpView.slot(gr.index, 4, n, true)).origin.is_equal_approx(st.pos),
		"видимая лента — на своём месте буфера")
	# объеденная видимая лента переписывается и на «Экономно»
	st.f = 0.3
	view.kelp.dirty = true
	gr.redraw = true
	kv.sync(1.0)
	ok(KelpView.transform_at(kv.stalk_buffer, KelpView.slot(gr.index, 4, n, true)).basis.y.length() < st.height * 0.6,
		"объеденная лента ниже")
	view.ground = Seabed.height   # сброс мира — виды пересобираются
	ok(view.kelp_view.lite and view.kelp_view.drawn() == n * KelpView.lite_per_grove(), "сброс мира — снова «Экономно»")
	view.set_lite(false)
	kv = view.kelp_view
	eq(kv.drawn(), all, "назад — все")
	gr = view.kelp.groves[0]
	ok(KelpView.transform_at(kv.stalk_buffer, 5).origin.is_equal_approx(gr.stalks[5].pos), "буфер снова по номеру")
	view.queue_free()
	await frames(1)


## Б3: ёж трогается и встаёт за секунду — ход меняется не быстрее ACCEL (раньше 0 → 0,3 м/с за шаг и обратно),
## к ленте и точке блуждания всё равно доходит.
func test_urchin_speed_eases() -> void:
	var w := _world()
	w.ship.pos = SPOT + Vector3(0, 10, 0)   # рядом: ежи шагают каждый кадр (EcoLod)
	var k := _kelp(w)
	w.reset()
	var dt := 1.0 / 30.0
	var last: Array[Vector3] = []
	var vel: Array[float] = []
	for u in k.urchins:
		last.append(u.pos)
		vel.append(0.0)
	var worst := 0.0
	var top := 0.0
	var ate := false
	for i in 1800:
		w.step(dt)
		for u in k.urchins:
			var j := u.index
			var d := Vector2(u.pos.x - last[j].x, u.pos.z - last[j].z).length()
			last[j] = u.pos
			if not u.alive or d > 0.5:   # съеден или появился заново
				vel[j] = 0.0
				continue
			var v := d / dt
			worst = maxf(worst, absf(v - vel[j]))
			top = maxf(top, v)
			vel[j] = v
			if u.goal >= 0 and Vector2(u.pos.x - k.groves[0].stalks[u.goal].pos.x,
					u.pos.z - k.groves[0].stalks[u.goal].pos.z).length() < EcoKelp.EAT_DIST:
				ate = true
	ok(worst <= maxf(EcoKelp.ACCEL * dt, EcoKelp.CREEP) + 1e-3,
		"ход меняется плавно: худший скачок %.3f м/с за шаг" % worst)
	ok(top > EcoKelp.WANDER_SPEED * 0.9, "разгоняется до своего хода: %.2f м/с" % top)
	ok(top <= EcoKelp.SPEED + 1e-3, "не быстрее SPEED: %.2f" % top)
	ok(ate, "ёж дошёл до ленты и ест")


func test_urchin_want_speed_slows_to_creep() -> void:
	near(EcoKelp.want_speed(EcoKelp.SPEED, 5.0), EcoKelp.SPEED, 1e-6, "вдали — полный ход")
	near(EcoKelp.want_speed(EcoKelp.SPEED, EcoKelp.ARRIVE * 0.5), EcoKelp.SPEED * 0.5, 1e-6, "у места — вполовину")
	near(EcoKelp.want_speed(EcoKelp.SPEED, 0.0), EcoKelp.CREEP, 1e-6, "у самого места — доползает")


## Первые START_QUIET с ежи пасутся молча: ни наблюдения «graze», ни строки (с разгоном первый доходит позже и
## перебивал строку приборов в test_status).
func test_urchins_quiet_at_start() -> void:
	var w := _world()
	w.ship.pos = SPOT + Vector3(0, 10, 0)
	w.reset()
	w.run(EcoKelp.START_QUIET - 0.5, 1.0 / 30.0)
	eq(_notes(w, EcoKelp.ID, "graze").size(), 0, "в начале ежи молчат")


## Б3 «вершинная анимация»: иглы ежей качаются вбок от основания — ветка breath общего шейдера растений; в меше UV
## (фаза иглы, доля длины), UV2 — вбок поперёк иглы; тело не качается; время мира — uniform t.
func test_view_urchin_spines_sway() -> void:
	var m := KelpView.build_urchin()
	var mat := m.surface_get_material(0) as ShaderMaterial
	eq(mat.get_shader_parameter("breath"), Vector2(KelpView.SPINE_AMP, KelpView.SPINE_RATE), "иглы качаются — breath")
	var arr := m.surface_get_arrays(0)
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	var cc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	eq(uv.size(), vv.size(), "UV у каждой вершины")
	eq(uv2.size(), vv.size(), "UV2 у каждой вершины")
	var tips := 0
	var phases := {}
	for i in vv.size():
		var r := vv[i].length()
		if uv[i].y > 0.5:
			tips += 1
			phases[snappedf(uv[i].x, 1e-4)] = true
			ok(r > 0.2 + KelpView.SPINE_LEN * 0.5, "качается только кончик иглы: %.3f м" % r)
			ok(cc[i].a == 0.0 or cc[i].a == 1.0, "альфа кончика 0 или 1 — фаза не сдвигается")
			near(uv2[i].length(), 1.0, 1e-4, "вбок — единичный")
			# вбок — поперёк иглы (горизонталь иглы не трогает её длину)
			var d := vv[i].normalized()
			ok(absf(Vector2(d.x, d.z).dot(uv2[i])) < 0.15, "вбок поперёк иглы")
		else:
			eq(uv[i].y, 0.0, "тело и основания игл стоят")
	ok(tips > KelpView.SPINES * 10, "у каждой иглы кончик и ромбик: %d" % tips)
	eq(phases.size(), KelpView.SPINES, "фаза у каждой иглы своя")
	# двойник: размах на кончике, через полкачания — в другую сторону, у основания — стоит, «Экономно» — стоит
	var dir := KelpView.spine_dir(5)
	var t0 := (1.0 - KelpView.spine_phase(5)) / KelpView.SPINE_RATE
	near(KelpView.spine_offset(dir, 5, 1.0, t0).length(), KelpView.SPINE_AMP, 1e-5, "кончик на полном размахе")
	ok(KelpView.spine_offset(dir, 5, 1.0, t0 + 0.5 / KelpView.SPINE_RATE).dot(KelpView.spine_offset(dir, 5, 1.0, t0)) < 0.0,
		"через полкачания — в другую сторону")
	near(KelpView.spine_offset(dir, 5, 0.0, t0).length(), 0.0, 1e-6, "основание стоит")
	near(KelpView.spine_offset(dir, 5, 1.0, t0, 0.0).length(), 0.0, 1e-6, "«Экономно» — стоит")
	ok(KelpView.spine_offset(KelpView.spine_dir(6), 6, 1.0, t0).distance_to(
		KelpView.spine_offset(KelpView.spine_dir(6), 6, 1.0, t0 + 1.0 / KelpView.SPINE_RATE)) < 1e-5, "период качания")
	var worst := 0.0
	for k in 90:
		var t := k / 30.0
		worst = maxf(worst, KelpView.spine_offset(dir, 5, 1.0, t + 1.0 / 30.0).distance_to(KelpView.spine_offset(dir, 5, 1.0, t)))
	ok(worst < 0.004, "без рывков: %.4f м за кадр" % worst)
	# в сцене время мира уходит в шейдер
	var w := _world()
	var v := KelpView.new(_kelp(w))
	v.sync(12.5)
	near(float((v.bodies.multimesh.mesh.surface_get_material(0) as ShaderMaterial).get_shader_parameter("t")), 12.5, 1e-6,
		"время мира — в шейдере ежей")
	v.free()


# ---------- Корпус раздвигает ленты (Б3) ----------
## Корабль опустился на рощу (низ корпуса ≈ 1,9 м над дном): ленты клонятся, ни одна точка ленты не в обшивке.
func test_hull_parts_stalks() -> void:
	var w := _world()
	var k := _kelp(w)
	w.ship.pos = SPOT + Vector3(0, 3.5, 0)
	w.ship.yaw = 0.4
	var hit := 0
	for s in k.groves[0].stalks:
		if EcoKelp._stalk_hits(s.pos, EcoKelp.stalk_basis(s).y.normalized(), EcoKelp.stalk_len(s), w.ship):
			hit += 1
	ok(hit >= 10, "без раздвигания ленты в обшивке (%d)" % hit)
	w.run(2.0)
	var leaned := 0
	for s in k.groves[0].stalks:
		if s.lean > 0.0:
			leaned += 1
		if s.lean < EcoKelp.LEAN_MAX - 1e-3:
			ok(not EcoKelp._stalk_hits(s.pos, EcoKelp.stalk_basis(s).y.normalized(), EcoKelp.stalk_len(s), w.ship),
					"лента в обшивке: lean %.2f" % s.lean)
	ok(leaned >= hit, "клонятся задетые (%d из %d)" % [leaned, hit])


## Лента клонится к своему борту и по ходу корабля, а не сквозь корпус.
func test_hull_lean_goes_to_own_side() -> void:
	var w := _world()
	var k := _kelp(w)
	w.ship.pos = SPOT + Vector3(0, 3.5, 0)
	var right := 0
	var left := 0
	for s in k.groves[0].stalks:
		var l := EcoKelp.hull_lean(s, w.ship)
		if l.x <= 0.0:
			continue
		var side := EcoHull.to_ship(s.pos, w.ship.pos, w.ship.yaw).x
		ok(l.z < 0.0, "по ходу — к носу (−Z)")
		if side > 0.5:
			ok(l.y > 0.0, "правый борт — вправо")
			right += 1
		elif side < -0.5:
			ok(l.y < 0.0, "левый борт — влево")
			left += 1
	ok(right > 0 and left > 0, "есть ленты у обоих бортов (%d / %d)" % [right, left])


## Корабль ушёл — ленты медленно выпрямляются; роща вдали больше не считается.
func test_stalks_spring_back_after_ship() -> void:
	var w := _world()
	var k := _kelp(w)
	w.ship.pos = SPOT + Vector3(0, 3.5, 0)
	w.run(2.0)
	var top := 0.0
	for s in k.groves[0].stalks:
		top = maxf(top, s.lean)
	ok(top > 0.3, "клонились: %.2f" % top)
	w.ship.pos = FAR
	w.run(0.5)
	var mid := 0.0
	for s in k.groves[0].stalks:
		mid = maxf(mid, s.lean)
	ok(mid > 0.0 and mid < top, "выпрямляются не за кадр: %.2f" % mid)
	w.run(EcoKelp.LEAN_MAX / EcoKelp.LEAN_OUT + 1.0)
	for s in k.groves[0].stalks:
		eq(s.lean, 0.0, "выпрямилась")
	ok(not k.groves[0].bent, "роща прямая")


## Наклон доходит до вида: роща перерисовывается, ось ленты в буфере наклонена.
func test_view_draws_lean() -> void:
	var w := _world()
	var k := _kelp(w)
	var v := KelpView.new(k)
	tree.root.add_child(v)
	v.sync(0.0)
	w.ship.pos = SPOT + Vector3(0, 3.5, 0)
	w.run(2.0)
	ok(k.dirty, "роща помечена к перерисовке")
	v.sync(1.0)
	var most := 1.0
	for i in k.groves[0].stalks.size():
		var tr := KelpView.transform_at(v.stalks.multimesh.buffer, i)
		most = minf(most, tr.basis.y.normalized().y)
	ok(most < cos(0.3), "в буфере лента наклонена (cos %.2f)" % most)
	v.free()


# ---------- Ленточник глушит двигатели (#1338) ----------

## Серпохвост голоден и готов напасть, роща — в 20 м по +X от него, корабль в её середине идёт быстро (5 м/с)
## без света, сонара и следа. with_kelp = false — рощи нет (та же точка).
func _muffle_world(with_kelp := true) -> Array:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var p := w.add(EcoPred.new()) as EcoPred
	p.alert = 0.0  # бросок сразу: здесь чутьё и бросок; «замер» #1498 — test_eco_pred_zamer
	var pr: EcoPred.Pred = p.all[0]
	var spot := Vector3(pr.agent.p.x + 20.0, FLAT, pr.agent.p.z)
	var k: EcoKelp = null
	if with_kelp:
		k = w.add(EcoKelp.new(null, [spot] as Array[Vector3])) as EcoKelp
		p.kelp = k
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = spot + Vector3(0, Helm.Ship.CLEARANCE, 0)
	w.ship.speed = 5.0
	w.ship.light_on = false
	w.last_ping = -1000.0
	return [w, pr, k]


func test_dense_kelp_muffles_engines() -> void:
	var a := _muffle_world(false)
	var w: EcoWorld = a[0]
	var pr: EcoPred.Pred = a[1]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "вне рощи серпохвост слышит двигатели")
	eq(_notes(w, EcoPred.ID, "hear").size(), 1)

	a = _muffle_world()
	w = a[0]
	pr = a[1]
	var k: EcoKelp = a[2]
	ok(k.muffling(w) == k.groves[0], "корабль в густой роще")
	w.run(3.0)
	eq(pr.mode, EcoPred.Mode.PATROL, "в густом ленточнике не слышит")
	eq(_notes(w, EcoPred.ID, "hear").size(), 0)
	var ev := _notes(w, EcoPred.ID, "kelp")
	eq(ev.size(), 1, "наблюдение серпохвоста «kelp» для журнала")
	ok(ev[0].text().begins_with("Ленточник глушит двигатели — ") and ev[0].text().ends_with(" не слышит корабль"), ev[0].text())
	w.run(30.0)
	eq(_notes(w, EcoPred.ID, "kelp").size(), 1, "раз в 40 с у рощи")


func test_grazed_kelp_does_not_muffle() -> void:
	var a := _muffle_world()
	var w: EcoWorld = a[0]
	var pr: EcoPred.Pred = a[1]
	var k: EcoKelp = a[2]
	for s in k.groves[0].stalks:
		s.f = EcoKelp.F_MIN
	k.groves[0].cover = 0.0   # густоту роща пересчитывает в своём шаге, после хищника
	eq(k.muffling(w), null, "голые стебли шум не глушат")
	w.step(EcoWorld.MAX_STEP)
	ok(k.groves[0].cover < EcoKelp.COVER_MIN, "роща выедена шипоежами")
	eq(pr.mode, EcoPred.Mode.CHARGE, "в выеденной роще снова слышит")
	eq(_notes(w, EcoPred.ID, "kelp").size(), 0)


func test_kelp_does_not_hide_light_or_ping() -> void:
	var a := _muffle_world()
	var w: EcoWorld = a[0]
	var pr: EcoPred.Pred = a[1]
	w.ship.light_on = true
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "свет прожектора заросли не прячут")
	eq(_notes(w, EcoPred.ID, "ship").size(), 1)

	a = _muffle_world()
	w = a[0]
	pr = a[1]
	w.last_ping = w.time
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "недавний сонар заросли не прячут")
	eq(_notes(w, EcoPred.ID, "ping").size(), 1)


func test_muffle_only_inside_low_grove() -> void:
	var a := _muffle_world()
	var w: EcoWorld = a[0]
	var k: EcoKelp = a[2]
	var c := k.groves[0].center
	w.ship.pos = c + Vector3(0, EcoKelp.MUFFLE_UP + 0.5, 0)
	eq(k.muffling(w), null, "над рощей — не в зарослях")
	w.ship.pos = c + Vector3(EcoKelp.KELP_R + EcoKelp.MUFFLE_PAD + 0.5, 3, 0)
	eq(k.muffling(w), null, "за краем рощи")
	w.ship.pos = c + Vector3(EcoKelp.KELP_R, 3, 0)
	ok(k.muffling(w) != null, "у края, в лентах")


func test_muffle_note_in_registry() -> void:
	ok(Species.is_observation(EcoPred.ID, "kelp"), "заметка журнала: биолог объясняет укрытие")
