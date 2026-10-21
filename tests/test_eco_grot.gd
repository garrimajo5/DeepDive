extends TestCase
## Гротовик (initGrot/grotUpdate/grotShelter в js/creatures.js): бредёт по кругу из четырёх точек, в рифе на спине
## живёт шестая стая светляков и прячется от серпохвоста; задетый кораблём прячет ноги и замирает; цель сонара;
## в сцене — четыре вызова отрисовки.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var p := w.add(EcoPred.new(f)) as EcoPred
	var g := w.add(EcoGrot.new(f)) as EcoGrot
	p.grot = g
	return w


func _sys(w: EcoWorld, cls: Variant) -> Variant:
	for s in w.systems:
		if is_instance_of(s, cls):
			return s
	return null


# ---------- Ход ----------

func test_starts_on_route_on_floor() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	near(gr.p.x, EcoGrot.ROUTE[0].x, 1e-4, "первая точка круга")
	near(gr.p.z, EcoGrot.ROUTE[0].y, 1e-4)
	eq(gr.wp, 1, "идёт ко второй точке")
	near(gr.p.y, FLAT, 1e-4, "на дне")
	near(gr.body_y, FLAT + 0.6 + 0.55, 1e-4, "тело на ногах")
	near(gr.back.y, gr.body_y + 1.6, 1e-4, "спина над телом")
	near(gr.top, gr.body_y + 3.5, 1e-4, "верх рифа")


func test_walks_route_in_order_slowly() -> void:
	var w := _world()
	var gr := (_sys(w, EcoGrot) as EcoGrot).grot
	var seen: Array[int] = []
	var last := Vector2(gr.p.x, gr.p.z)
	for i in 1200:  # 600 с
		w.run(0.5)
		var now := Vector2(gr.p.x, gr.p.z)
		ok(now.distance_to(last) <= EcoGrot.SPEED * 0.5 + 1e-3, "не быстрее 0,45 м/с")
		last = now
		if seen.is_empty() or seen[-1] != gr.wp:
			seen.append(gr.wp)
	ok(seen.size() >= 4, "прошёл несколько точек: %s" % [seen])
	for k in range(1, seen.size()):
		eq(seen[k], (seen[k - 1] + 1) % EcoGrot.ROUTE.size(), "точки по порядку")


func test_reset_returns_to_start() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	w.run(60.0)
	ok(g.grot.p.distance_to(Vector3(EcoGrot.ROUTE[0].x, FLAT, EcoGrot.ROUTE[0].y)) > 5.0, "ушёл")
	w.reset()
	near(g.grot.p.x, EcoGrot.ROUTE[0].x, 1e-4, "после сброса — на старте")
	eq(g.grot.wp, 1)
	ok(g.shoal.riding and g.shoal == (_sys(w, EcoFish) as EcoFish).shoals[EcoGrot.RIDERS], "стая снова на спине")


# ---------- Стая на спине ----------

func test_riders_live_on_back() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var f: EcoFish = _sys(w, EcoFish)
	var sh := f.shoals[EcoGrot.RIDERS]
	ok(g.shoal == sh and sh.riding, "шестая стая — на спине")
	near(sh.range_m, EcoGrot.RANGE, 1e-4, "блуждает в 4 м")
	near(sh.home.distance_to(g.grot.back + Vector3(0, 0.6, 0)), 0.0, 1e-4, "дом над спиной")
	for fi: EcoFish.Fish in sh.members:
		ok(fi.agent.p.distance_to(sh.home) < 6.0, "рыбка начинает у рифа")
	for k in f.shoals.size():
		if k != EcoGrot.RIDERS:
			ok(not f.shoals[k].riding, "другие стаи — не на спине")
	near(f.shoals[0].range_m, 14.0, 1e-4, "у других — прежний радиус")


func test_riders_travel_with_grot() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var sh := g.shoal
	var start := g.grot.back
	w.run(120.0)
	ok(g.grot.back.distance_to(start) > 30.0, "гротовик ушёл: %.1f м" % g.grot.back.distance_to(start))
	near(sh.home.distance_to(g.grot.back + Vector3(0, 0.6, 0)), 0.0, 1e-4, "дом едет на спине")
	ok(sh.center.distance_to(g.grot.back) < 9.0, "стая рядом с рифом: %.1f м" % sh.center.distance_to(g.grot.back))


func test_riders_skip_spores_ferns_and_rays() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var g := w.add(EcoGrot.new(f)) as EcoGrot
	var bl := w.add(EcoBladder.new(f)) as EcoBladder
	var fe := w.add(EcoFern.new(f)) as EcoFern
	var ry := w.add(EcoRay.new(f)) as EcoRay
	var sh := g.shoal
	sh.goal = sh.home
	var bush := EcoBladder.Bush.new()
	bush.cloud = sh.center + Vector3(2, 0, 0)
	bl._call_shoals(w, bush)
	ok(sh.goal != bush.cloud, "на споры не слетается")
	var fern: EcoFern.Fern = fe.ferns[0]
	fern.top = sh.center + Vector3(0, 0, 2)
	fe._call_shoals(w, fern)
	ok(sh.goal != fern.top, "к моллюскам не плывёт")
	var r: EcoRay.Ray = ry.rays[0]
	r.p = sh.center
	ry._lead(w, r)
	ok(sh.leader() == null, "ледокрыл её не уводит")


# ---------- Укрытие от серпохвоста ----------

func test_alarmed_rider_hidden_in_reef() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var fi: EcoFish.Fish = g.shoal.members[0]
	fi.agent.p = g.grot.back + Vector3(1, 0.5, 0)
	ok(g.shelter(fi) == null, "спокойная стая не прячется")
	g.shoal.alarm = 2.0
	ok(g.shelter(fi) == g.grot, "напуганная — в рифе")
	fi.agent.p = g.grot.back + Vector3(EcoGrot.HIDE_R + 0.5, 0, 0)
	ok(g.shelter(fi) == null, "дальше 5 м — не в рифе")
	var other: EcoFish.Fish = (_sys(w, EcoFish) as EcoFish).shoals[0].members[0]
	other.agent.p = g.grot.back
	ok(g.shelter(other) == null, "чужая стая в рифе не прячется")


func test_pred_loses_rider_in_reef() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var p: EcoPred = _sys(w, EcoPred)
	var f: EcoFish = _sys(w, EcoFish)
	var fi: EcoFish.Fish = g.shoal.members[0]
	fi.agent.p = g.grot.back
	g.shoal.alarm = 3.0
	var hidden := p._hidden_fish()
	ok(hidden.is_valid() and hidden.call(fi), "серпохвост не выбирает рыбку в рифе")
	ok(f.nearest_fish(g.grot.back, 3.0, hidden) == null or f.nearest_fish(g.grot.back, 3.0, hidden).shoal != g.shoal,
		"ближайшая — не из рифа")
	var pr: EcoPred.Pred = p.all[0]
	pr.agent.p = g.grot.back + Vector3(10, 0, 0)
	EcoPred._set_mode(pr, EcoPred.Mode.HUNT, 12.0)
	pr.prey = fi
	w.step(0.05)
	ok(pr.prey == null and pr.mode == EcoPred.Mode.PATROL, "потерял стаю — снова патруль")
	eq(_notes(w, "grot", "hide").size(), 1, "наблюдение «hide»")
	EcoPred._set_mode(pr, EcoPred.Mode.HUNT, 12.0)
	pr.prey = fi
	g.shoal.alarm = 3.0
	fi.agent.p = g.grot.back
	w.step(0.05)
	eq(_notes(w, "grot", "hide").size(), 1, "не чаще раза в 40 с")


func test_calm_world_no_hidden_filter_from_grot() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var p: EcoPred = _sys(w, EcoPred)
	g.shoal.alarm = 0.0
	ok(not p._hidden_fish().is_valid(), "спокойно — без лишнего фильтра")


# ---------- Корабль ----------

func test_ship_bump_makes_shy() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	w.ship.pos = Vector3(gr.p.x + 8.0, gr.back.y, gr.p.z)
	w.step(0.05)
	eq(_notes(w, "grot", "shy").size(), 1, "задели — «shy»")
	ok(not gr.moving(), "замер")
	ok(g.shoal.alarm >= 2.9, "стая на спине испугалась")
	w.ship.pos = FAR
	var at := Vector2(gr.p.x, gr.p.z)
	w.run(5.0)
	near(Vector2(gr.p.x, gr.p.z).distance_to(at), 0.0, 1e-4, "стоит")
	ok(gr.lift < 0.1, "ноги спрятаны: %.2f" % gr.lift)
	near(gr.body_y, FLAT + 0.6 + 0.55 * gr.lift, 1e-4, "опустился на дно")
	w.run(6.0)
	ok(gr.moving(), "через 10 с снова идёт")
	w.run(3.0)
	ok(Vector2(gr.p.x, gr.p.z).distance_to(at) > 0.5, "пошёл дальше")


func test_shy_cooldown_and_ship_above() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	w.ship.pos = Vector3(gr.p.x, gr.top + 1.0, gr.p.z)
	w.run(2.0)
	eq(_notes(w, "grot", "shy").size(), 0, "над рифом — не задевает")
	w.ship.pos = Vector3(gr.p.x + 5.0, gr.body_y, gr.p.z)
	w.run(15.0)
	eq(_notes(w, "grot", "shy").size(), 1, "раз — и 25 с перезарядки")
	w.run(12.0)
	eq(_notes(w, "grot", "shy").size(), 2, "через 25 с — снова")


func test_drift_note_near_ship() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	w.run(2.0)
	eq(_notes(w, "grot", "drift").size(), 0, "далеко — без наблюдения")
	w.ship.pos = g.grot.back + Vector3(0, 10, 25)
	w.step(0.05)
	eq(_notes(w, "grot", "drift").size(), 1, "рядом — «drift»")
	w.run(30.0)
	eq(_notes(w, "grot", "drift").size(), 1, "не чаще раза в 90 с")


func test_solid_shell() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	var base := Vector3(gr.p.x, gr.body_y, gr.p.z)
	ok(g.solid(base + Vector3(0, 0.5, 0)), "внутри панциря")
	ok(not g.solid(base + Vector3(0, 1.5, 0)), "над панцирем")
	ok(not g.solid(base + Vector3(3.0, 0.2, 0)), "сбоку за панцирем")
	ok(not g.solid(base + Vector3(0, -2.0, 0)), "под дном")
	var fwd := Basis(Vector3.UP, gr.yaw) * Vector3(0, 0.2, 3.5)
	ok(g.solid(base + fwd), "голова спереди по курсу")


func test_scan_target_and_texts() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var found := false
	for t in w.scan_targets():
		if t["species"] == "grot":
			found = true
			near((t["pos"] as Vector3).distance_to(g.grot.back), 0.0, 1e-4, "отметка на спине")
			near(float(t["r"]), 3.0, 1e-4, "размер 3 м")
	ok(found, "цель сонара")
	g.hid_fish(w)
	var ev := _notes(w, "grot", "hide")
	ok(ev[0].text().contains("рифе") and ev[0].text().contains("ходячего рифа"), ev[0].text())
	ok(Species.is_observation("grot", "shy") and Species.is_observation("grot", "drift"), "заметки вида")


# ---------- Сцена ----------

func test_view_four_draw_calls() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var gv := view.grot_view
	ok(gv != null and gv.get_parent() == view, "гротовик — в живом мире")
	ok(view.preds.grot == view.grot, "серпохвосты знают о гротовике")
	ok(view.grot.shoal == view.fish.shoals[EcoGrot.RIDERS], "стая на спине")
	var gr := view.grot.grot
	var ship := EcoLink.ShipState.new()
	ship.pos = gr.back + Vector3(0, 5, 30)
	view.step(0.05, ship)
	ok(gv.visible, "рядом — виден")
	near(gv.group.position.distance_to(Vector3(gr.p.x, gr.body_y, gr.p.z)), 0.0, 1e-4, "узел на теле")
	near(gv.legs.scale.y, 0.35 + 0.65 * gr.lift, 1e-4, "ноги по lift")
	var calls := 0
	var tris := 0
	for c in gv.group.get_children():
		var mi := c as MeshInstance3D
		eq(mi.layers, OceanView.LAYER_WORLD, "слой отмели: %s" % c.name)
		calls += 1
		tris += mi.mesh.surface_get_array_len(0) / 3
	eq(calls, 4, "четыре вызова отрисовки")
	ok(tris < 2500, "треугольников: %d" % tris)
	var far_ship := EcoLink.ShipState.new()
	far_ship.pos = Vector3(-300, -20, -300)
	view.step(0.05, far_ship)
	ok(not gv.visible, "далеко — спрятан")
	view.queue_free()
	await frames(1)
