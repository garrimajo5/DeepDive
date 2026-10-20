extends TestCase
## Пузырчатка-фонарь (bladdersUpdate в js/creatures.js; ART-004): три куста у пятен мха у старта, луковицы зреют
## 70 с и лопаются облаком спор на 12 с, корабль на ходу лопает спелые, на споры слетаются стаи светляков,
## наблюдения «pop» и «feed», цели сонара и сканера. В сцене — три MultiMesh.


func _world(with_fish := false) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var f: EcoFish = w.add(EcoFish.new()) as EcoFish if with_fish else null
	w.add(EcoBladder.new(f))
	return w


func _bl(w: EcoWorld) -> EcoBladder:
	for s in w.systems:
		if s is EcoBladder:
			return s
	return null


func _notes(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		if e["type"] == EcoLink.OBSERVE and e["species"] == EcoBladder.ID:
			out.append(e["note"])
	return out


func _texts(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		if e["type"] == EcoLink.OBSERVE and e["species"] == EcoBladder.ID:
			out.append(e["text"])
	return out


# ---------- Расстановка ----------

func test_three_bushes_by_moss_near_start() -> void:
	var spots := EcoBladder.default_spots()
	eq(spots.size(), 3, "три куста")
	var s0 := Helm.Ship.START
	# три ближайших к старту пятна мха не ближе 25 м друг к другу: 0, 20 и 3 в EcoMoss.SPOTS
	var patches := [EcoMoss.SPOTS[0], EcoMoss.SPOTS[20], EcoMoss.SPOTS[3]]
	for i in 3:
		var p: Vector3 = patches[i]
		near(Vector2(spots[i].x - p.x, spots[i].z - p.z).length(), EcoBladder.OFFSET, 1e-4, "в 4,5 м от пятна %d" % i)
	for i in 3:
		for j in range(i + 1, 3):
			var a: Vector3 = patches[i]
			var b: Vector3 = patches[j]
			ok(Vector2(a.x - b.x, a.z - b.z).length() > EcoBladder.PICK_GAP, "пятна врозь")
	ok(Vector2(spots[0].x - s0.x, spots[0].z - s0.z).length() < 40.0, "первый куст рядом со стартом")


func test_stems_on_ground_ripeness_seeded() -> void:
	var w := _world()
	var b := _bl(w)
	eq(b.bushes.size(), 3)
	for bl in b.bushes:
		near(bl.base.y, Seabed.height(bl.base.x, bl.base.z), 1e-4, "на дне")
		eq(bl.stem_top.size(), EcoBladder.STEMS, "семь стеблей")
		ok(bl.ripe >= 0.2 and bl.ripe <= 0.8, "спелость 0,2…0,8")
		ok(not bl.popped(), "облака нет")
		for k in EcoBladder.STEMS:
			var h := bl.stem_top[k].distance_to(bl.stem_base[k])
			ok(h >= 0.8 and h <= 1.4, "стебель около метра: %f" % h)
			ok(bl.stem_top[k].y > bl.stem_base[k].y + 0.7, "растёт вверх")
		for o in bl.spores:
			ok(o.length() <= EcoBladder.CLOUD_R + 1e-4, "спора в облаке")
	var other := _world()
	eq(_bl(other).bushes[2].stem_top[4], b.bushes[2].stem_top[4], "то же зерно — те же стебли")
	near(_bl(other).bushes[1].ripe, b.bushes[1].ripe, 1e-9)


func test_start_bush_not_nearest_scan_target() -> void:
	# ближайшей целью сканера у старта остаётся стая светляков (как у волнолиста и веерника)
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var f := w.add(EcoFish.new()) as EcoFish
	var b := w.add(EcoBladder.new(f)) as EcoBladder
	var shoal_d := f.shoals[0].center.distance_to(Helm.Ship.START)
	for bl in b.bushes:
		ok(bl.stem_top[0].distance_to(Helm.Ship.START) > shoal_d + 1.0, "куст дальше стаи от старта")


# ---------- Зреет и лопается ----------

func test_ripens_in_70s_and_pops() -> void:
	var w := _world()
	var b := _bl(w)
	var bl := b.bushes[0]
	bl.ripe = 0.5
	w.run(10.0)
	near(bl.ripe, 0.5 + 10.0 / 70.0, 1e-3, "зреет 1/70 в секунду")
	w.run(35.0 - 10.0 - 0.1)
	ok(not bl.popped(), "ещё не спелая")
	w.run(0.2)
	ok(bl.popped(), "спелая лопнула")
	near(bl.ripe, 0.0, 0.01, "спелость с нуля")
	w.run(11.5)
	ok(bl.popped(), "облако 12 с")
	near(bl.ripe, 0.0, 1e-6, "пока облако — не зреет")
	w.run(0.6)
	ok(not bl.popped(), "облако рассеялось")
	ok(bl.ripe > 0.0, "снова зреет")


func test_pop_observation_near_ship_and_text() -> void:
	var w := _world()
	var b := _bl(w)
	var bl := b.bushes[1]
	w.ship.pos = bl.base + Vector3(10, 10, 0)
	w.ship.speed = 0.0
	bl.ripe = 0.999
	w.run(0.2)
	var ev := w.take_link()
	eq(_notes(ev), ["pop"] as Array[String], "наблюдение «лопнули»")
	eq(_texts(ev)[0], "Спелые луковицы лопаются облаком светящихся спор")
	w.scanned = func(sp: String) -> bool: return sp == EcoBladder.ID
	b.pop(w, b.bushes[1], false)
	eq(_texts(w.take_link())[0], "Спелые луковицы пузырчатки лопаются облаком светящихся спор", "вид изучен")
	ok(Species.is_observation(EcoBladder.ID, "pop"))
	ok(Species.is_observation(EcoBladder.ID, "feed"))


func test_ship_pops_ripe_bulbs_on_the_move() -> void:
	var w := _world()
	var b := _bl(w)
	var bl := b.bushes[0]
	bl.ripe = 0.7
	w.ship.pos = bl.base + Vector3(3, 2, 0)
	w.ship.speed = 0.3
	w.step(0.05)
	ok(not bl.popped(), "медленно — не задел")
	w.ship.speed = 2.0
	w.ship.pos = bl.base + Vector3(3, 4, 0)
	w.step(0.05)
	ok(not bl.popped(), "выше 3 м — не задел")
	w.ship.pos = bl.base + Vector3(7, 2, 0)
	w.step(0.05)
	ok(not bl.popped(), "дальше 6,5 м — не задел")
	w.ship.pos = bl.base + Vector3(3, 2, 0)
	w.take_link()
	w.step(0.05)
	ok(bl.popped(), "на ходу над кустом — лопнули")
	var t := _texts(w.take_link())
	eq(t, ["Корабль задел спелые луковицы — они лопаются облаком светящихся спор"] as Array[String])


func test_ship_leaves_unripe_bulbs() -> void:
	var w := _world()
	var bl := _bl(w).bushes[0]
	bl.ripe = 0.5
	w.ship.pos = bl.base + Vector3(1, 1, 0)
	w.ship.speed = 3.0
	w.run(1.0)
	ok(not bl.popped(), "незрелые не лопаются")


# ---------- Споры зовут стаи ----------

func test_spores_call_calm_shoal_and_feed_note() -> void:
	var w := _world(true)
	var b := _bl(w)
	var f: EcoFish = w.systems[0]
	# куст, к которому ближе всего какая-нибудь стая
	var best_sh: EcoFish.Shoal = null
	var bl: EcoBladder.Bush = null
	var bd := INF
	for x in b.bushes:
		for sh in f.shoals:
			var d := sh.center.distance_to(x.cloud)
			if d < bd:
				bd = d
				best_sh = sh
				bl = x
	ok(bd < EcoBladder.CALL_R, "стая ближе 35 м: %f" % bd)
	w.ship.pos = bl.base + Vector3(20, 15, 0)
	b.pop(w, bl, false)
	w.step(0.05)
	eq(best_sh.goal, bl.cloud, "стая плывёт к спорам")
	var notes: Array[String] = []
	for i in 230:  # до 11,5 с — пока облако живо
		w.step(0.05)
		notes.append_array(_notes(w.take_link()))
		if notes.has("feed"):
			break
	ok(notes.has("feed"), "рыбы у спор — наблюдение «feed»")
	ok(best_sh.center.distance_to(bl.cloud) < EcoBladder.CAME_R + 0.5, "стая у облака")


func test_alarmed_shoal_and_no_cloud_call_no_one() -> void:
	var w := _world(true)
	var b := _bl(w)
	var f: EcoFish = w.systems[0]
	for bl in b.bushes:
		bl.ripe = 0.0
	w.run(3.0)
	for sh in f.shoals:
		for bl in b.bushes:
			ok(sh.goal != bl.cloud, "без облака никого не зовёт")
	var bl0 := b.bushes[0]
	var sh := f.shoals[0]
	sh.alarm = 3.0
	sh.goal = sh.home
	bl0.life = EcoBladder.LIFE
	sh.center = bl0.cloud + Vector3(5, 0, 0)
	b.step(w, 0.05)
	eq(sh.goal, sh.home, "в тревоге не до спор")


# ---------- Сонар и сканер ----------

func test_bushes_are_scan_targets() -> void:
	var w := _world()
	var bl := _bl(w).bushes[2]
	w.ship.pos = bl.stem_top[0] + Vector3(5, 0, 0)
	w.ship.scan_range = 80.0
	w.step(0.05)
	var got := false
	for e in w.take_link():
		if e["type"] == EcoLink.NEAR and e["species"] == EcoBladder.ID:
			got = true
			near(e["r"], 0.9, 1e-6)
	ok(got, "куст — цель сканера")


# ---------- Облако и луковицы ----------

func test_bulb_size_color_and_spores() -> void:
	var bl := EcoBladder.Bush.new()
	bl.ripe = 0.0
	near(EcoBladder.bulb_size(bl), 0.35, 1e-6)
	bl.ripe = 1.0
	near(EcoBladder.bulb_size(bl), 1.0, 1e-6, "спелая — полная")
	ok(EcoBladder.bulb_color(bl).g > 0.95, "спелый сок ярко-зелёный")
	bl.life = 5.0
	near(EcoBladder.bulb_size(bl), 0.2, 1e-6, "лопнула — сморщилась")
	bl.cloud = Vector3(1, 2, 3)
	bl.spores = PackedVector3Array([Vector3(1, 0, 0)])
	bl.life = EcoBladder.LIFE
	var p0 := EcoBladder.spore(bl, 0, 0.0)
	near(p0.x, 1.3, 1e-4, "сразу облако тесное")
	bl.life = EcoBladder.LIFE - 3.0
	var p1 := EcoBladder.spore(bl, 0, 0.0)
	near(p1.x, 2.3, 1e-4, "за 1,7 с расходится")
	near(p1.y, 2.0 + 0.24, 1e-4, "и всплывает 8 см/с")
	near(EcoBladder.spore_glow(bl), 1.0, 1e-6)
	bl.life = 1.5
	near(EcoBladder.spore_glow(bl), 0.5, 1e-6, "гаснет за последние 3 с")


func test_bladder_does_not_shift_other_species() -> void:
	# своё зерно: светляки без спор (облаков нет первые 10 с) идут как без пузырчатки
	var a := EcoWorld.new()
	a.ground = Seabed.height
	var fa := a.add(EcoFish.new()) as EcoFish
	var ba := a.add(EcoBladder.new(fa)) as EcoBladder
	for bl in ba.bushes:
		bl.ripe = 0.0
	var b := EcoWorld.new()
	b.ground = Seabed.height
	var fb := b.add(EcoFish.new()) as EcoFish
	a.run(5.0)
	b.run(5.0)
	eq(fa.shoals[3].center, fb.shoals[3].center, "стаи те же")


# ---------- В сцене ----------

func test_view_three_multimeshes() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var bv := view.bladder_view
	ok(bv != null and bv.get_parent() == view, "пузырчатка — в живом мире")
	for mi in [bv.stems, bv.bulbs, bv.spores]:
		eq(mi.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(bv.stems.multimesh.instance_count, 3 * EcoBladder.STEMS, "все стебли — один MultiMesh")
	eq(bv.bulbs.multimesh.instance_count, 3 * EcoBladder.STEMS, "все луковицы — один MultiMesh")
	eq(bv.spores.multimesh.instance_count, 3 * EcoBladder.SPORES, "все споры — один MultiMesh")
	var bl := view.bladders.bushes[1]
	# стебель стоит от основания до вершины
	var st := BladderView.transform_at(bv.stems.multimesh.buffer, bl.index * EcoBladder.STEMS + 3, BladderView.STRIDE)
	var bottom := st * Vector3(0, -0.5, 0)
	var top := st * Vector3(0, 0.5, 0)
	ok(bottom.distance_to(bl.stem_base[3]) < 1e-3, "стебель — от дна")
	ok(top.distance_to(bl.stem_top[3]) < 1e-3, "до луковицы")
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	bl.ripe = 0.5
	view.step(0.05, ship)
	var n := bl.index * EcoBladder.STEMS + 2
	var tr := BladderView.transform_at(bv.bulb_buffer, n)
	ok(tr.origin.distance_to(bl.stem_top[2]) < 0.06, "луковица на стебле")
	near(tr.basis.x.length(), EcoBladder.bulb_size(bl), 1e-3)
	var s0 := BladderView.transform_at(bv.spore_buffer, bl.index * EcoBladder.SPORES)
	near(s0.basis.x.length(), 0.0, 1e-6, "облака нет — споры спрятаны")
	view.bladders.pop(view.world, bl, false)
	view.step(0.05, ship)
	s0 = BladderView.transform_at(bv.spore_buffer, bl.index * EcoBladder.SPORES)
	near(s0.basis.x.length(), 1.0, 1e-6, "лопнула — споры видны")
	ok(s0.origin.distance_to(bl.cloud) < EcoBladder.CLOUD_R * 1.5, "в облаке над кустом")
	view.queue_free()
	await frames(1)
