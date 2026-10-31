extends TestCase
## Подушечник (initCushions, squeeze, inkAt, cushionsUpdate в js/creatures.js; ART-004): две подушки у стай светляков,
## от касания корабля или напуганной стаи — облако чернил на 9 с (снова через 40 с), в нём серпохвост теряет
## светляка и корабль; наблюдения «touch», «hide», «ship»; два MultiMesh в сцене.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
## Своё место подушки для тестов: основание на дне −40,1, макушка −38,7, середина облака −38,1.
const SPOT := Vector3(0, FLAT, 0)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


## Ровное дно, корабль далеко, одна подушка в SPOT.
func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoCushion.new(null, [SPOT] as Array[Vector3]))
	return w


func _cushions(w: EcoWorld) -> EcoCushion:
	for s in w.systems:
		if s is EcoCushion:
			return s
	return null


func _preds(w: EcoWorld) -> EcoPred:
	for s in w.systems:
		if s is EcoPred:
			return s
	return null


## Светляки, серпохвосты и подушка в SPOT; первый хищник — в 20 м от подушки.
func _pred_world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var p := w.add(EcoPred.new(f)) as EcoPred
	p.cushions = w.add(EcoCushion.new(f, [SPOT] as Array[Vector3])) as EcoCushion
	p.all[0].agent.p = SPOT + Vector3(20, 3, 0)
	return w


# ---------- Расстановка ----------

func test_two_cushions_by_shoals_on_ground() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var f := w.add(EcoFish.new()) as EcoFish
	var c := w.add(EcoCushion.new(f)) as EcoCushion
	eq(c.cushions.size(), 2, "две подушки")
	for i in 2:
		var cu := c.cushions[i]
		var sh := f.shoals[EcoCushion.SHOALS[i]]
		ok(cu.shoal == sh, "у стаи %d" % EcoCushion.SHOALS[i])
		var a := i * 2.4 + 1.1
		near(cu.base.x, sh.home.x + cos(a) * 3.0, 1e-4, "в 3 м от дома стаи")
		near(cu.base.z, sh.home.z + sin(a) * 3.0, 1e-4)
		near(cu.base.y, Seabed.height(cu.base.x, cu.base.z) - 0.1, 1e-4, "на 0,1 м в дне")
		near(cu.top.y - cu.base.y, 1.4, 1e-4, "макушка на 1,4 м")
		near(cu.ink_c.y - cu.base.y, 2.0, 1e-4, "облако на 2 м")
		eq(cu.off.size(), EcoCushion.INK_N, "70 частиц облака")
		for o in cu.off:
			ok(o.length() <= EcoCushion.INK_R + 1e-4, "частица в радиусе 5,5 м")
		ok(not cu.inked(), "чернил сначала нет")
	var t := w.scan_targets()
	eq(t.size(), 2 + f.shoals.size(), "подушки видны сонару и сканеру")
	var pads := t.filter(func(d: Dictionary) -> bool: return d["species"] == EcoCushion.ID)
	eq(pads.size(), 2)
	near(pads[0]["r"], 1.3, 1e-6)


func test_no_cushions_without_shoals() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	var c := w.add(EcoCushion.new()) as EcoCushion
	eq(c.cushions.size(), 0, "без стай подушки не растут")
	w.run(1.0)


# ---------- Касание ----------

func test_ship_touch_squeezes_ink_9s_recharge_40s() -> void:
	var w := _world()
	var cu := _cushions(w).cushions[0]
	w.ship.pos = Vector3(6.0, FLAT + 2.0, 0.0)
	w.step(EcoWorld.MAX_STEP)
	ok(cu.inked(), "корабль задел — облако")
	near(cu.squeeze, 1.0 - EcoWorld.MAX_STEP * 0.15, 1e-4, "сжалась")
	var ev := _notes(w, EcoCushion.ID, "touch")
	eq(ev.size(), 1, "наблюдение «touch»")
	eq(ev[0].text(), "Мягкая подушка сжимается и выпускает облако чернил — корабль его задел", "не изучен — по виду")
	near(EcoCushion.squash(cu).x, 1.0 - cu.squeeze * 0.45, 1e-6, "ниже и уже")
	w.run(8.8)
	ok(cu.inked(), "облако ещё держится")
	w.run(0.3)
	ok(not cu.inked(), "через 9 с облако растаяло")
	w.run(30.0)
	eq(_notes(w, EcoCushion.ID, "touch").size(), 1, "40 с набирается чернил")
	near(cu.squeeze, 0.0, 1e-6, "расправилась")
	w.run(1.0)
	eq(_notes(w, EcoCushion.ID, "touch").size(), 2, "через 40 с — снова")


func test_ship_far_or_high_does_not_touch() -> void:
	var w := _world()
	var cu := _cushions(w).cushions[0]
	w.ship.pos = Vector3(7.0, FLAT, 0.0)
	w.run(1.0)
	ok(not cu.inked(), "дальше 6,8 м — не задел")
	w.ship.pos = Vector3(2.0, cu.top.y + 3.1, 0.0)
	w.run(1.0)
	ok(not cu.inked(), "выше 3 м над макушкой — не задел")
	w.ship.pos = Vector3(2.0, cu.top.y + 2.9, 0.0)
	w.run(0.1)
	ok(cu.inked(), "ниже — задел")


func test_ship_can_touch_over_flat_floor() -> void:
	var w := _world()
	var cu := _cushions(w).cushions[0]
	# корабль опустился, насколько пускает штурвал (Helm.Ship.CLEARANCE над дном), и подошёл к подушке
	w.ship.pos = Vector3(5.0, FLAT + Helm.Ship.CLEARANCE, 0.0)
	w.run(0.1)
	ok(cu.inked(), "над ровным дном подушку можно задеть")


func test_scared_shoal_squeezes() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var c := w.add(EcoCushion.new(f, [SPOT] as Array[Vector3])) as EcoCushion
	var cu := c.cushions[0]
	cu.shoal = f.shoals[0]
	var fi: EcoFish.Fish = cu.shoal.members[0]
	fi.agent.p = cu.top + Vector3(1, 0, 0)
	cu.shoal.alarm = 0.0
	c.step(w, 0.01)
	ok(not cu.inked(), "спокойная стая подушку не трогает")
	cu.shoal.alarm = 2.0
	c.step(w, 0.01)
	ok(cu.inked(), "напуганная стая нырнула в подушку — облако")
	eq(_notes(w, EcoCushion.ID, "touch")[0].text(), "Мягкая подушка сжимается и выпускает облако чернил", "без корабля")


func test_ink_at_and_ship_ink_radii() -> void:
	var w := _world()
	var c := _cushions(w)
	var cu := c.cushions[0]
	ok(c.ink_at(cu.ink_c) == null, "без облака чернил нет")
	ok(not c.any_ink())
	ok(c.squeeze(w, cu, false), "сжалась")
	ok(not c.squeeze(w, cu, false), "второй раз — нет, набирается")
	ok(c.any_ink())
	ok(c.ink_at(cu.ink_c + Vector3(5.4, 0, 0)) == cu, "ближе 5,5 м — в чернилах")
	ok(c.ink_at(cu.ink_c + Vector3(5.6, 0, 0)) == null, "дальше — нет")
	w.ship.pos = cu.ink_c + Vector3(0, 0, 7.4)
	ok(c.ship_ink(w) == cu, "корабль ближе 7,5 м — в чернилах")
	w.ship.pos = cu.ink_c + Vector3(0, 0, 7.6)
	ok(c.ship_ink(w) == null, "дальше — нет")


func test_touch_is_link_observe() -> void:
	var w := _world()
	w.scanned = func(id: String) -> bool: return id == EcoCushion.ID
	w.ship.pos = Vector3(3.0, FLAT, 0.0)
	w.run(0.1)
	var found := false
	for e in w.take_link():
		if e["type"] == EcoLink.OBSERVE and e["species"] == EcoCushion.ID and e["note"] == "touch":
			found = true
			eq(e["text"], "Подушечник сжимается и выпускает облако чернил — корабль его задел", "изучен — по имени")
	ok(found, "наблюдение для журнала")


# ---------- Серпохвост в чернилах ----------

func test_pred_loses_fish_in_ink() -> void:
	var w := _pred_world()
	var c := _cushions(w)
	var cu := c.cushions[0]
	var pr := _preds(w).all[0]
	var prey: EcoFish.Fish = (w.systems[0] as EcoFish).all[0]
	prey.agent.p = cu.ink_c
	pr.mode = EcoPred.Mode.HUNT
	pr.agent.timer = 12.0
	pr.prey = prey
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.HUNT, "без чернил — охотится")
	c.squeeze(w, cu, false)
	prey.agent.p = cu.ink_c
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "светляк в чернилах — охота сорвана")
	ok(pr.prey == null)
	ok(pr.agent.timer >= 4.0 - 0.1 and pr.agent.timer <= 8.0, "патруль 4–8 с")
	var ev := _notes(w, EcoCushion.ID, "hide")
	eq(ev.size(), 1, "наблюдение «hide»")
	ok(ev[0].text().contains("стая скрылась в чернилах мягкой подушки"), ev[0].text())
	pr.mode = EcoPred.Mode.HUNT
	pr.agent.timer = 12.0
	pr.prey = prey
	prey.agent.p = cu.ink_c
	w.step(EcoWorld.MAX_STEP)
	eq(_notes(w, EcoCushion.ID, "hide").size(), 1, "раз в 30 с")


func test_hungry_pred_does_not_pick_fish_in_ink() -> void:
	var w := _pred_world()
	var c := _cushions(w)
	var cu := c.cushions[0]
	var fish := w.systems[0] as EcoFish
	var p := _preds(w)
	var f := fish.all[0]
	f.agent.p = cu.ink_c
	ok(fish.nearest_fish(cu.ink_c, 1.0, p._in_ink) == f, "без чернил видно")
	c.squeeze(w, cu, false)
	ok(fish.nearest_fish(cu.ink_c, 1.0, p._in_ink) == null, "в чернилах — не видно")


func test_ship_in_ink_not_lured_and_charge_breaks() -> void:
	var w := _pred_world()
	var c := _cushions(w)
	var cu := c.cushions[0]
	var p := _preds(w)
	var pr := p.all[0]
	pr.hunger = 0.3  # нападать готов, на светляков не охотится
	pr.cooldown = 0.0
	w.ship.light_on = true
	w.ship.pos = cu.ink_c + Vector3(0, 0, 7.0)  # рядом с облаком, но дальше 6,8 м — подушку не задевает
	w.ship.pos.y = cu.top.y + 2.0
	pr.agent.p = w.ship.pos + Vector3(20, 0, 0)
	ok(p.lured(w, pr, 20.0), "свет манит")
	c.squeeze(w, cu, false)
	ok(p.ship_hidden(w), "корабль в чернилах")
	ok(not p.lured(w, pr, 20.0), "в чернилах свет не манит")
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "не бросается")

	pr.mode = EcoPred.Mode.CHARGE
	pr.agent.timer = 10.0
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.RETREAT, "бросок сорван — уходит")
	near(pr.agent.timer, 10.0, EcoWorld.MAX_STEP + 1e-4, "на 10 с")
	ok(pr.agent.goal.y <= EcoPred.GOAL_CEILING, "не выше потолка")
	var ev := _notes(w, EcoCushion.ID, "ship")
	eq(ev.size(), 1, "наблюдение «ship»")
	ok(ev[0].text().begins_with("Корабль в чернилах мягкой подушки: ") and ev[0].text().ends_with(" потерял его из виду"), ev[0].text())

	w.run(9.5)
	ok(not p.ship_hidden(w), "чернила растаяли")
	ok(p.lured(w, pr, 20.0), "и свет снова манит")


func test_reset_clears_ink() -> void:
	var w := _world()
	var c := _cushions(w)
	c.squeeze(w, c.cushions[0], true)
	w.reset()
	var cu := c.cushions[0]
	ok(not cu.inked(), "облака нет")
	near(cu.cd, 0.0, 1e-6, "набралась")
	near(cu.squeeze, 0.0, 1e-6)
	eq(w.bus.pending.size(), 0)


# ---------- Сцена ----------

func test_view_two_multimeshes() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	ok(view.preds.cushions == view.cushions, "серпохвосты знают про подушечники")
	var cv := view.cushion_view
	ok(cv != null and cv.get_parent() == view, "подушечники — в живом мире")
	eq(cv.pads.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(cv.ink.layers, OceanView.LAYER_WORLD)
	eq(cv.pads.multimesh.instance_count, 2, "две подушки одним MultiMesh")
	eq(cv.ink.multimesh.instance_count, 2 * EcoCushion.INK_N, "облака одним MultiMesh")
	var cu := view.cushions.cushions[1]
	var tr := CushionView.transform_at(cv.pad_buffer, 1, CushionView.STRIDE)
	ok(tr.origin.is_equal_approx(cu.base), "подушка на месте")
	near(tr.basis.get_scale().y, 1.0, 1e-4, "не сжата")
	near(CushionView.transform_at(cv.ink_buffer, EcoCushion.INK_N).basis.get_scale().x, 0.0, 1e-6, "чернил нет — пятна скрыты")
	view.cushions.squeeze(view.world, cu, true)
	view.world.run(1.0)
	cv.sync(view.world.time)
	tr = CushionView.transform_at(cv.pad_buffer, 1, CushionView.STRIDE)
	ok(tr.basis.get_scale().y < 0.7, "сжатая — ниже")
	var ink0 := CushionView.transform_at(cv.ink_buffer, EcoCushion.INK_N)
	near(ink0.basis.get_scale().x, 1.0, 1e-4, "облако видно")
	ok(ink0.origin.distance_to(cu.ink_c) < EcoCushion.INK_R + 0.5, "пятно в облаке")
	near(cv.ink_buffer[EcoCushion.INK_N * CushionView.STRIDE_C + 15], CushionView.INK_ALPHA, 1e-4, "непрозрачность 0,85")
	view.queue_free()
	await frames(1)


## «Экономно» (Б6): рисуется половина пятен каждого облака чернил — места вперемешку по подушкам, видимые в начале
## буфера; назад — буфер снова по подушке; сброс мира уровень не теряет.
func test_view_lite_draws_half_of_each_ink_cloud() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var cv := view.cushion_view
	var n := view.cushions.cushions.size()
	eq(cv.ink_drawn(), n * EcoCushion.INK_N, "на «Обычно» — все пятна")
	view.set_lite(true)
	ok(cv.lite, "подушечник — на «Экономно»")
	var per := EcoMM.cloud_per(EcoCushion.INK_N)
	eq(cv.ink_drawn(), per * n, "половина каждого облака")
	ok(cv.ink_drawn() <= n * EcoCushion.INK_N / 2, "пятен вдвое меньше: %d" % cv.ink_drawn())
	var seen := {}
	for cu in view.cushions.cushions:
		var shown := 0
		for j in EcoCushion.INK_N:
			var s := cv.ink_slot(cu.index, j)
			seen[s] = true
			if s < cv.ink_drawn():
				shown += 1
		eq(shown, per, "у подушки %d видно %d" % [cu.index, per])
	eq(seen.size(), n * EcoCushion.INK_N, "места в буфере не повторяются")
	var cu := view.cushions.cushions[1]
	view.cushions.squeeze(view.world, cu, true)
	view.world.run(1.0)
	cv.sync(view.world.time)
	var slot := cv.ink_slot(cu.index, 5)
	ok(slot < cv.ink_drawn(), "пятно первой половины рисуется")
	var ink5 := CushionView.transform_at(cv.ink_buffer, slot)
	near(ink5.basis.get_scale().x, 1.0, 1e-4, "облако видно на своём месте")
	near(ink5.origin.distance_to(EcoCushion.ink_point(cu, 5, view.world.time)), 0.0, 1e-4, "там, где его считает мир")
	view.ground = Seabed.height   # сброс мира — виды пересобираются
	ok(view.cushion_view.lite and view.cushion_view.ink_drawn() == per * n, "сброс мира — снова «Экономно»")
	view.set_lite(false)
	cv = view.cushion_view
	eq(cv.ink_drawn(), n * EcoCushion.INK_N, "назад — все")
	eq(cv.ink_slot(1, 5), EcoCushion.INK_N + 5, "буфер снова по подушке")
	view.queue_free()
	await frames(1)
