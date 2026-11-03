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


func test_bulbs_shrink_and_regrow_smoothly() -> void:
	# Б3: лопнула — луковица опадает за SHRINK, к концу облака набухает до завязи за REGROW; раньше размер прыгал
	# 1 → 0,2 и 0,2 → 0,35 за кадр, цвет сока — с ярко-зелёного на тусклый
	var w := _world()
	var bl := _bl(w).bushes[0]
	bl.ripe = 1.0 - 0.01 / EcoBladder.RIPEN
	var dt := 1.0 / 30.0
	var size := EcoBladder.bulb_size(bl)
	var green := EcoBladder.bulb_color(bl).g
	var popped := false
	var worst := 0.0
	var worst_g := 0.0
	for i in int((EcoBladder.LIFE + 2.0) / dt):
		w.step(dt)
		popped = popped or bl.popped()
		var s := EcoBladder.bulb_size(bl)
		var g := EcoBladder.bulb_color(bl).g
		worst = maxf(worst, absf(s - size))
		worst_g = maxf(worst_g, absf(g - green))
		size = s
		green = g
	ok(popped, "лопнула и облако прошло")
	ok(not bl.popped(), "облако рассеялось")
	# 0,8 доли размера за 0,25 с мягко — не больше ≈ 0,8 · 1,5 · dt / 0,25 за кадр
	ok(worst < 0.8 * 1.5 * dt / EcoBladder.SHRINK + 1e-3, "размер без скачка: %.3f за кадр" % worst)
	ok(worst_g < 0.4 * 1.5 * dt / EcoBladder.SHRINK + 1e-3, "цвет без скачка: %.3f за кадр" % worst_g)
	bl.life = EcoBladder.LIFE - EcoBladder.SHRINK - 0.1
	near(EcoBladder.bulb_size(bl), 0.2, 1e-6, "опала до 0,2")
	bl.life = 1e-4
	near(EcoBladder.bulb_size(bl), 0.35, 1e-3, "к концу облака — размер завязи")


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
	ok(top.distance_to(bl.stem_top[3]) < 0.3, "до вершины (колышется)")
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	bl.ripe = 0.5
	view.step(0.05, ship)
	var n := bl.index * EcoBladder.STEMS + 2
	var tr := BladderView.transform_at(bv.bulb_buffer, n)
	var st2 := BladderView.transform_at(bv.stems.multimesh.buffer, n, BladderView.STRIDE)
	ok(tr.origin.distance_to(st2 * Vector3(0, 0.5, 0)) < 1e-3, "луковица на вершине своего стебля")
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


## «Экономно» (Б6): рисуется половина спор каждого облака — места вперемешку по кустам, видимые в начале буфера;
## назад — буфер снова по кусту; сброс мира уровень не теряет.
func test_view_lite_draws_half_of_each_spore_cloud() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var bv := view.bladder_view
	var n := view.bladders.bushes.size()
	eq(bv.spores_drawn(), n * EcoBladder.SPORES, "на «Обычно» — все споры")
	view.set_lite(true)
	ok(bv.lite, "пузырчатка — на «Экономно»")
	var per := EcoMM.cloud_per(EcoBladder.SPORES)
	eq(bv.spores_drawn(), per * n, "половина каждого облака")
	var seen := {}
	for bl in view.bladders.bushes:
		var shown := 0
		for j in EcoBladder.SPORES:
			var s := bv.spore_slot(bl.index, j)
			seen[s] = true
			if s < bv.spores_drawn():
				shown += 1
		eq(shown, per, "у куста %d видно %d" % [bl.index, per])
	eq(seen.size(), n * EcoBladder.SPORES, "места в буфере не повторяются")
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	var bl := view.bladders.bushes[1]
	view.bladders.pop(view.world, bl, false)
	view.step(0.05, ship)
	var s0 := BladderView.transform_at(bv.spore_buffer, bv.spore_slot(bl.index, 3))
	near(s0.basis.x.length(), 1.0, 1e-6, "лопнула — видимая спора на своём месте")
	near(s0.origin.distance_to(EcoBladder.spore(bl, 3, view.world.time)), 0.0, 1e-4, "там, где её считает мир")
	ok(bv.spore_slot(bl.index, 3) < bv.spores_drawn(), "и она рисуется")
	view.ground = Seabed.height   # сброс мира — виды пересобираются
	ok(view.bladder_view.lite and view.bladder_view.spores_drawn() == per * n, "сброс мира — снова «Экономно»")
	view.set_lite(false)
	bv = view.bladder_view
	eq(bv.spores_drawn(), n * EcoBladder.SPORES, "назад — все")
	eq(bv.spore_slot(1, 3), 1 * EcoBladder.SPORES + 3, "буфер снова по кусту")
	view.queue_free()
	await frames(1)


# ---------- Колыхание (Б3) ----------

## Стебли колышутся в течении (`EcoBladder.sway`): по потоку кренятся сильнее, чем в стоячей воде, длина стебля та же,
## на «Экономно» (amount = 0) стоят; пузырёк срывается с луковицы там, где она нарисована.
func test_stems_sway_in_current() -> void:
	var b := _bl(_world())
	var bl := b.bushes[0]
	var k := 4
	var flow := Vector3(EcoCurrent.SPEED, 0, 0)
	var calm := 0.0
	var lean := 0.0
	var moved := 0.0
	var steps := 120
	for i in steps:
		var t := i * 0.25
		var top := EcoBladder.bulb(bl, k, t, flow)
		calm += (EcoBladder.bulb(bl, k, t) - bl.stem_top[k]).x
		lean += (top - bl.stem_top[k]).x
		moved = maxf(moved, top.distance_to(bl.stem_top[k]))
		var h := bl.stem_base[k].distance_to(bl.stem_top[k])
		near(top.distance_to(bl.stem_base[k]), h, h * 0.03, "стебель не вытягивается")
		eq(EcoBladder.bulb(bl, k, t, flow, 0.0), bl.stem_top[k], "«Экономно» — стоит")
		var sp := EcoBladderBubbles.spot(bl, k, t, flow)
		ok(sp.distance_to(top + Vector3(0, EcoBladderBubbles.LIFT, 0)) < 1e-5, "пузырёк — с нарисованной луковицы")
	ok(lean / steps > 0.05, "по течению кренится в среднем на %.3f м" % (lean / steps))
	ok(absf(calm / steps) < 0.03, "в стоячей воде крена нет (%.3f)" % (calm / steps))
	ok(moved > 0.08 and moved < 0.35, "размах вершины %.2f м" % moved)
	# стебли одного куста не в лад
	var d0 := EcoBladder.sway(bl, 1, 3.0, flow)
	var d1 := EcoBladder.sway(bl, 2, 3.0, flow)
	ok(d0.distance_to(d1) > 1e-3, "соседние стебли гнутся по-своему")


## В сцене стебель и луковица идут вместе: за кадры вершина стебля уходит с места, луковица на ней; на «Экономно»
## стебли стоят.
func test_view_stem_follows_bulb() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var bv := view.bladder_view
	var bl := view.bladders.bushes[0]
	var n := bl.index * EcoBladder.STEMS + 5
	var flow := Vector3(0, 0, EcoCurrent.SPEED)
	var span := 0.0
	var first := Vector3.ZERO
	for f in 20:
		bv.sync(f * 0.4, null, flow)
		var st := BladderView.transform_at(bv.stems.multimesh.buffer, n, BladderView.STRIDE)
		var top := st * Vector3(0, 0.5, 0)
		ok((st * Vector3(0, -0.5, 0)).distance_to(bl.stem_base[5]) < 1e-3, "подножие стоит")
		ok(top.distance_to(BladderView.transform_at(bv.bulb_buffer, n).origin) < 1e-3, "луковица на вершине")
		if f == 0:
			first = top
		span = maxf(span, top.distance_to(first))
	ok(span > 0.03, "вершина стебля колышется (%.3f м)" % span)
	EcoShaders.set_sway_lite(true)
	bv.sync(9.0, null, flow)
	var still := BladderView.transform_at(bv.stems.multimesh.buffer, n, BladderView.STRIDE) * Vector3(0, 0.5, 0)
	EcoShaders.set_sway_lite(false)
	ok(still.distance_to(bl.stem_top[5]) < 1e-3, "«Экономно» — стебель стоит")
	view.queue_free()
	await frames(1)
