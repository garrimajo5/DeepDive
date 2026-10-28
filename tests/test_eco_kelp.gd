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

func test_two_groves_by_shoals_on_ground() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var f := w.add(EcoFish.new()) as EcoFish
	var k := w.add(EcoKelp.new(f)) as EcoKelp
	eq(k.groves.size(), 2 + EcoKelp.EXTRA.size(), "две рощи у стай и роща в Тихой заводи (#831)")
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
