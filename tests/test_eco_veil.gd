extends TestCase
## Фонарные вуали (initVeils/veilUpdate в js/creatures.js, обход вуалей в updateFish и predUpdate, E.shipHidden):
## две колонии медуз дрейфуют у своих мест, жалят светляков под куполом, серпохвост их обходит, корабль под куполом
## спрятан от хищников; цели сонара; в сцене — три вызова отрисовки на вуаль.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
## Своё место вуали: купол на −19 (−40 + 21), щупальца до −34.
const SPOT := Vector2(0, 0)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


func _world(spots: Array[Vector2] = [SPOT]) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoVeil.new(spots))
	return w


func _veils(w: EcoWorld) -> EcoVeil:
	for s in w.systems:
		if s is EcoVeil:
			return s
	return null


## Светляки, серпохвосты и вуаль в SPOT, связанные как в EcoView.
func _full_world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var p := w.add(EcoPred.new(f)) as EcoPred
	var v := w.add(EcoVeil.new([SPOT] as Array[Vector2])) as EcoVeil
	f.veils = v
	p.veils = v
	return w


# ---------- Места и дрейф ----------

func test_two_veils_on_browser_places() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var v := w.add(EcoVeil.new()) as EcoVeil
	eq(v.veils.size(), 2, "две вуали")
	for i in 2:
		var vl := v.veils[i]
		near(vl.home.x, EcoVeil.PLACES[i].x, 1e-4, "место браузера")
		near(vl.home.z, EcoVeil.PLACES[i].y, 1e-4)
		var top := minf(Seabed.height(vl.home.x, vl.home.z) + 21.0, -9.0)
		near(vl.home.y, top, 1e-4, "купол в 21 м над дном, не выше −9")
		eq(vl.tent_a.size(), EcoVeil.TENTACLES, "40 щупалец")
		eq(vl.small_size.size(), EcoVeil.SMALL, "9 колокольчиков")
		for k in EcoVeil.TENTACLES:
			ok(vl.tent_r[k] >= 1.5 - 1e-4 and vl.tent_r[k] <= 5.4 + 1e-4, "щупальце под куполом")
			ok(vl.tent_len[k] >= 9.0 - 1e-4 and vl.tent_len[k] <= 15.0 + 1e-4, "длина 9–15 м")


func test_drifts_near_home_above_floor() -> void:
	var w := _world()
	var vl := _veils(w).veils[0]
	var moved := 0.0
	for i in 60:
		w.run(5.0)
		var d := Vector2(vl.p.x - vl.home.x, vl.p.z - vl.home.z).length()
		moved = maxf(moved, d)
		ok(d < 40.0, "дрейфует у своего места: %.1f м" % d)
		ok(vl.p.y <= EcoVeil.CEIL_Y + EcoVeil.BOB + 1e-4, "подо льдом")
		ok(vl.p.y - EcoVeil.LEN >= FLAT + EcoVeil.FLOOR_PAD - EcoVeil.BOB - 1e-3, "щупальца не на дне")
	ok(moved > 3.0, "дрейфует: %.1f м" % moved)


func test_high_floor_lifts_veil() -> void:
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return -28.0
	w.ship.pos = FAR
	var v := w.add(EcoVeil.new([SPOT] as Array[Vector2])) as EcoVeil
	w.run(1.0)
	var vl := v.veils[0]
	ok(vl.p.y >= -28.0 + EcoVeil.LEN + EcoVeil.FLOOR_PAD - EcoVeil.BOB - 1e-3, "щупальца выше дна")
	ok(vl.p.y > vl.home.y - 0.5 - EcoVeil.BOB, "дно поднимает купол до −10 м")
	ok(vl.p.y <= EcoVeil.CEIL_Y + EcoVeil.BOB + 1e-4, "но не выше −7")


func test_reset_same_seed_same_veils() -> void:
	var a := _world()
	var b := _world()
	a.run(30.0)
	b.run(30.0)
	var va := _veils(a).veils[0]
	var vb := _veils(b).veils[0]
	near(va.p.distance_to(vb.p), 0.0, 1e-5, "то же место")
	eq(va.tent_r, vb.tent_r, "те же щупальца")


func test_pulse_and_rim() -> void:
	var vl := _veils(_world()).veils[0]
	for i in 50:
		var t := i * 0.37
		var s := EcoVeil.pulse(vl, t)
		ok(absf(s.x - 1.0) <= EcoVeil.PULSE + 1e-5, "купол 1 ± 0,07")
		ok(absf(s.y - 1.0) <= EcoVeil.PULSE_IN + 1e-5, "ядро 1 ± 0,09")
		var g := EcoVeil.rim_glow(vl, t)
		ok(g >= 0.2 - 1e-5 and g <= 1.0 + 1e-5, "кромка мерцает 0,2…1")


# ---------- Светляки ----------

func test_fish_pushed_aside_under_bell() -> void:
	var w := _world()
	var v := _veils(w)
	var vl := v.veils[0]
	var stung := []
	var acc := v.fish_push(w, vl.p + Vector3(7.0, -5.0, 0.0), 0.0, stung)
	ok(acc.x > 2.0 and absf(acc.z) < 1e-3 and acc.y == 0.0, "толкает вбок от середины: %s" % acc)
	eq(stung.size(), 0, "dt = 0 — не жалит")
	eq(v.fish_push(w, vl.p + Vector3(10.0, -5.0, 0.0), 1.0, stung), Vector3.ZERO, "дальше r + 3 — не трогает")
	eq(v.fish_push(w, vl.p + Vector3(2.0, 3.0, 0.0), 1.0, stung), Vector3.ZERO, "выше купола — не трогает")
	eq(v.fish_push(w, vl.p + Vector3(2.0, -16.0, 0.0), 1.0, stung), Vector3.ZERO, "ниже щупалец — не трогает")


func test_stings_fish_under_bell() -> void:
	var w := _world()
	var v := _veils(w)
	var vl := v.veils[0]
	var hits := 0
	for i in 2000:
		var stung := []
		v.fish_push(w, vl.p + Vector3(1.0, -4.0, 1.0), 0.05, stung)
		hits += stung.size()
	# 0,22 в секунду × 100 с ≈ 22
	ok(hits > 10 and hits < 40, "жалит ≈ 0,22 в секунду: %d за 100 с" % hits)
	ok(_notes(w, "veil", "sting").size() == hits, "наблюдение «sting» на каждый укус")
	var none := []
	for i in 400:
		v.fish_push(w, vl.p + Vector3(5.5, -4.0, 0.0), 0.05, none)
	eq(none.size(), 0, "у края купола (дальше 0,85 r) не жалит")


func test_fish_under_veil_die() -> void:
	var w := _full_world()
	var f: EcoFish = w.systems[0]
	var vl := _veils(w).veils[0]
	var sh := f.shoals[0]
	var dead := 0
	for i in 200:
		for fi: EcoFish.Fish in sh.members:
			if fi.agent.alive:
				fi.agent.p = vl.p + Vector3((fi.slot % 5) * 0.4 - 1.0, -4.0, (fi.slot / 5) * 0.4 - 1.0)
		w.step(0.05)
	for fi: EcoFish.Fish in sh.members:
		if not fi.agent.alive:
			dead += 1
	ok(sh.near_veil, "стая у вуали")
	ok(dead > 0, "вуаль ужалила светляков: %d" % dead)
	ok(not _notes(w, "veil", "sting").is_empty(), "наблюдение «sting»")
	ok(not f.shoals[3].near_veil or f.shoals[3].center.distance_to(vl.p) < 60.0, "дальние стаи вуаль не проверяют")


func test_fish_without_veil_unchanged() -> void:
	# без вуалей стая шагает как раньше: поле veils пустое — те же места
	var a := EcoWorld.new()
	a.ground = _flat
	a.ship.pos = FAR
	var fa := a.add(EcoFish.new()) as EcoFish
	var b := EcoWorld.new()
	b.ground = _flat
	b.ship.pos = FAR
	var fb := b.add(EcoFish.new()) as EcoFish
	fb.veils = EcoVeil.new([Vector2(-250, -250)] as Array[Vector2])  # вуаль далеко от всех стай
	fb.veils.reset(b)
	a.run(10.0)
	b.run(10.0)
	near(fa.all[5].agent.p.distance_to(fb.all[5].agent.p), 0.0, 1e-5, "далёкая вуаль стаю не сдвигает")


# ---------- Серпохвост и корабль ----------

func test_pred_pushed_around_veil() -> void:
	var v := _veils(_world())
	var vl := v.veils[0]
	var push := v.pred_push(vl.p + Vector3(0, -5, 10))
	ok(push.z > 7.0 and absf(push.x) < 1e-3, "толкает прочь от вуали: %s" % push)
	eq(v.pred_push(vl.p + Vector3(0, -5, 16)), Vector3.ZERO, "дальше r + 9 — не трогает")
	eq(v.pred_push(vl.p + Vector3(0, 5, 5)), Vector3.ZERO, "выше 4 м над куполом — не трогает")


func test_pred_avoids_veil_with_note() -> void:
	var w := _full_world()
	var p: EcoPred = w.systems[1]
	var vl := _veils(w).veils[0]
	var pr := p.all[0]
	pr.agent.p = vl.p + Vector3(9.0, -6.0, 0.0)
	pr.agent.goal = vl.p + Vector3(-60.0, -6.0, 0.0)  # цель — прямо сквозь вуаль
	pr.agent.v = Vector3.ZERO
	w.step(0.05)
	eq(_notes(w, "pred", "avoid").size(), 1, "наблюдение «avoid»")
	var x0 := pr.agent.p.x
	w.run(2.0)
	eq(_notes(w, "pred", "avoid").size(), 1, "не чаще раза в 40 с")
	ok(pr.agent.p.x > x0 - 6.0, "не лезет сквозь щупальца: x %.1f → %.1f" % [x0, pr.agent.p.x])


func test_ship_under_bell_hidden() -> void:
	var w := _full_world()
	var p: EcoPred = w.systems[1]
	var v := _veils(w)
	var vl := v.veils[0]
	w.ship.pos = vl.p + Vector3(3.0, -10.0, 0.0)
	ok(v.ship_under(w) == vl, "корабль под куполом")
	ok(p.ship_hidden(w), "хищники его не видят")
	w.ship.light_on = true
	ok(not p.lured(w, p.all[0], 10.0), "свет под куполом не манит")
	w.ship.pos = vl.p + Vector3(13.0, -10.0, 0.0)
	ok(v.ship_under(w) == null, "дальше r + 6 — не под куполом")
	w.ship.pos = vl.p + Vector3(0.0, 2.0, 0.0)
	ok(v.ship_under(w) == null, "выше купола — не спрятан")
	w.ship.pos = vl.p + Vector3(0.0, -EcoVeil.LEN - 7.0, 0.0)
	ok(v.ship_under(w) == null, "далеко под щупальцами — не спрятан")


func test_charge_broken_under_veil() -> void:
	var w := _full_world()
	var p: EcoPred = w.systems[1]
	var vl := _veils(w).veils[0]
	w.ship.pos = vl.p + Vector3(0.0, -10.0, 0.0)
	var pr := p.all[0]
	pr.agent.p = w.ship.pos + Vector3(30.0, 0.0, 0.0)
	EcoPred._set_mode(pr, EcoPred.Mode.CHARGE, 10.0)
	w.step(0.05)
	eq(pr.mode, EcoPred.Mode.RETREAT, "бросок сорван — уходит")
	var ev := _notes(w, "veil", "hide")
	eq(ev.size(), 1, "наблюдение вуали «hide»")
	ok(ev[0].text().begins_with("Корабль под куполом"), ev[0].text())
	eq(w.hits, 0, "не укусил")


func test_veils_are_scan_targets() -> void:
	var w := _world([SPOT, Vector2(60, 0)] as Array[Vector2])
	var out: Array[Dictionary] = []
	_veils(w).targets(w, out)
	eq(out.size(), 2, "обе вуали")
	near(out[0]["pos"].y, _veils(w).veils[0].p.y - 3.0, 1e-5, "в 3 м под куполом")
	eq(out[0]["species"], "veil")
	near(out[0]["r"], 7.0, 1e-5)


func test_texts_name_species() -> void:
	var w := _full_world()
	var v := _veils(w)
	v.avoided(w, Vector3.ZERO)
	var ev := _notes(w, "pred", "avoid")
	ok(ev[0].text().contains("стороной"), ev[0].text())


# ---------- Сцена ----------

func test_view_three_draw_calls_per_veil() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var vv := view.veil_view
	ok(vv != null and vv.get_parent() == view, "вуали — в живом мире")
	eq(vv.groups.size(), 2, "две вуали")
	ok(view.fish.veils == view.veils and view.preds.veils == view.veils, "светляки и серпохвосты знают о вуалях")
	var ship := EcoLink.ShipState.new()
	ship.pos = view.veils.veils[0].p + Vector3(0, -5, 30)
	view.step(0.05, ship)
	var g := vv.groups[0]
	ok(g.visible, "ближняя вуаль видна")
	near(g.position.distance_to(view.veils.veils[0].p), 0.0, 1e-4, "узел на куполе")
	eq(vv.groups[1].visible, view.veils.veils[1].p.distance_to(ship.pos) < VeilView.FAR, "дальше FAR — спрятана")
	var far_ship := EcoLink.ShipState.new()
	far_ship.pos = Vector3(-250, -20, -250)
	view.step(0.05, far_ship)
	ok(not vv.groups[0].visible and not vv.groups[1].visible, "далеко от корабля обе спрятаны")
	view.step(0.05, ship)
	var calls := 0
	var tris := 0
	for c in g.get_children():
		var gi := c as GeometryInstance3D
		eq(gi.layers, OceanView.LAYER_WORLD, "слой отмели: %s" % c.name)
		calls += 1
		if c is MultiMeshInstance3D:
			var mm := (c as MultiMeshInstance3D).multimesh
			eq(mm.instance_count, VeilView.BELLS, "купол, ядро и 9 колокольчиков")
			tris += mm.mesh.get_faces().size() / 3 * mm.instance_count
	eq(calls, 3, "три вызова отрисовки на вуаль")
	ok(tris < 12000, "треугольников куполов: %d" % tris)
	var buf := vv.bell_buffers[0]
	near(buf[0], EcoVeil.R * EcoVeil.pulse(view.veils.veils[0], view.world.time).x, 1e-4, "купол 6 м с пульсом")
	near(buf[15], VeilView.BELL.a, 1e-4, "прозрачный купол")
	view.queue_free()
	await frames(1)


func test_tentacle_mesh_matches_shader_formula() -> void:
	var w := _world()
	var vl := _veils(w).veils[0]
	var m := VeilView.build_tentacles(vl)
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	eq(v.size(), EcoVeil.TENTACLES * EcoVeil.SEGMENTS * 2, "40 × 10 отрезков")
	eq(m.surface_get_primitive_type(0), Mesh.PRIMITIVE_LINES, "линии")
	var t := 12.7
	var s := EcoVeil.pulse(vl, t).x
	for i in [0, 1, 37, 101, 799]:
		var k := int(uv[i].x)
		var j := int(uv[i].y)
		var got := VeilView.shader_point(v[i], k, j, t, s)
		near(got.distance_to(EcoVeil.tentacle_point(vl, k, j, t)), 0.0, 1e-4, "точка %d щупальца %d" % [j, k])
