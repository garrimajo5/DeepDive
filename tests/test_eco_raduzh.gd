extends TestCase
## Радужники (initSwarms, swarmUpdate, predUpdate в js/creatures.js): три стаи по 28 гребневиков над дном,
## вспышка в луче прожектора и затухание, наблюдения «flare», «fade», «betray», вспышка зовёт серпохвоста
## издалека, цели сонара и сканера; в сцене — два MultiMesh.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _sys(w: EcoWorld, cls: Variant) -> EcoSystem:
	for s in w.systems:
		if is_instance_of(s, cls):
			return s
	return null


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


## Одна стая в (0, 0) над ровным дном; with_pred — и серпохвосты (до радужников, как в EcoView).
func _world(with_pred := false) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var p: EcoPred = w.add(EcoPred.new()) as EcoPred if with_pred else null
	var r := w.add(EcoRaduzh.new([Vector2(0, 0)] as Array[Vector2])) as EcoRaduzh
	if p:
		p.raduzh = r
	return w


## Корабль светит так, что центр стаи — на оси луча в d м от прожектора.
func _aim(w: EcoWorld, p: Vector3, d: float = 15.0) -> void:
	var down := deg_to_rad(Searchlight.PITCH)
	var dir := Vector3(0, -sin(down), -cos(down))
	w.ship.yaw = 0.0
	w.ship.pos = p - dir * d - Searchlight.LAMP
	w.ship.light_on = true
	w.ship.light_range = Searchlight.BASE_RANGE


# ---------- Расстановка ----------

func test_three_swarms_above_ground() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var r := w.add(EcoRaduzh.new()) as EcoRaduzh
	eq(r.swarms.size(), 3, "три стаи")
	for i in 3:
		var sw := r.swarms[i]
		var h := EcoRaduzh.HOMES[i]
		near(sw.home.x, h.x, 1e-6)
		near(sw.home.z, h.y, 1e-6)
		near(sw.home.y, minf(Seabed.height(h.x, h.y) + 9.0, -8.0), 1e-4, "9 м над дном, не выше −8")
		eq(sw.members.size(), 28, "28 гребневиков")
		for m in sw.members:
			ok(m.o.length() <= EcoRaduzh.R + 1e-4, "внутри стаи 4 м")
			ok(m.hue >= 0.0 and m.hue < 1.0)
	var other := EcoWorld.new()
	other.ground = Seabed.height
	var r2 := other.add(EcoRaduzh.new()) as EcoRaduzh
	near(r2.swarms[1].members[5].o.x, r.swarms[1].members[5].o.x, 1e-9, "то же зерно — та же стая")


## #1400 (решение по умолчанию, срок 14.11): в спокойной середине 00 → 01 ни одна стая не висит в луче с оси прохода —
## дом не ближе 45 м к оси `tools/mid_calm.gd` PATH (дальность луча мира) и не у подхода к 01, не над волнолистом у
## прохода. Прежний дом стаи 1 (45, 0) — в 5 м от волнолиста, и вспышка звала серпохвоста в 7 из 16 проходов.
func test_no_swarm_home_on_calm_middle() -> void:
	var path: Array[Vector2] = (load("res://tools/mid_calm.gd") as GDScript).PATH
	var p01 := LayerMap.at("01")
	for i in EcoRaduzh.HOMES.size():
		var h := EcoRaduzh.HOMES[i]
		var best := INF
		for k in path.size() - 1:
			best = minf(best, h.distance_to(Geometry2D.get_closest_point_to_segment(h, path[k], path[k + 1])))
		ok(best >= 45.0, "дом стаи %d в %.1f м от оси прохода 00 → 01, нужно не ближе 45" % [i, best])
		ok(h.distance_to(Vector2(p01.x, p01.z)) >= 60.0, "дом стаи %d не у подхода к 01" % i)
		ok(h.distance_to(EcoFern.ROUTE_CLUSTER) >= 30.0, "дом стаи %d не над волнолистом у прохода" % i)
	eq(EcoRaduzh.HOMES[1], Vector2(80, 5), "стая 1 — в (80, 5) над илом восточнее прохода")


func test_swarm_drifts_around_home() -> void:
	var w := _world()
	var r := _sys(w, EcoRaduzh) as EcoRaduzh
	var sw := r.swarms[0]
	var far := 0.0
	for i in 60:
		w.run(2.0, 0.05)
		var d := Vector2(sw.c.x - sw.home.x, sw.c.z - sw.home.z)
		ok(absf(d.x) <= 10.0 + 1e-4 and absf(d.y) <= 10.0 + 1e-4, "дрейф не дальше 10 м")
		ok(absf(sw.c.y - sw.home.y) <= 1.2 + 1e-4)
		far = maxf(far, d.length())
	ok(far > 3.0, "стая дрейфует: %.1f м" % far)


## Б3 «плавность»: центр стаи после сброса — уже по дрейфу; раньше стоял в доме и на первом шаге прыгал до 10 м.
func test_no_jump_after_reset() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = FAR
	var r := w.add(EcoRaduzh.new()) as EcoRaduzh
	var dt := 1.0 / 30.0
	var was: Array[Vector3] = []
	for sw in r.swarms:
		was.append(sw.c)
	var worst := 0.0
	for i in 30 * 5:
		w.step(dt)
		for k in r.swarms.size():
			worst = maxf(worst, r.swarms[k].c.distance_to(was[k]) / dt)
			was[k] = r.swarms[k].c
	ok(worst < 1.0, "центр стаи без рывков: %.2f м/с" % worst)


# ---------- Вспышка ----------

func test_flares_in_beam_and_fades() -> void:
	var w := _world()
	var r := _sys(w, EcoRaduzh) as EcoRaduzh
	var sw := r.swarms[0]
	w.step(0.05)
	near(sw.glow, 0.0, 1e-6, "вдали от луча — тёмная")
	_aim(w, sw.c)
	w.step(0.05)
	ok(sw.lit, "луч задел стаю")
	near(sw.glow, 0.15, 1e-4, "разгорается 3 в секунду")
	for i in 10:
		_aim(w, EcoRaduzh.center(sw, w.time))
		w.step(0.05)
	near(sw.glow, 1.0, 1e-6, "за 0,33 с — в полную силу")
	near(r.flare, 1.0, 1e-6, "самая яркая вспышка мира")
	ok(r.flare_swarm == sw)
	var ev := _notes(w, EcoRaduzh.ID, "flare")
	eq(ev.size(), 1, "наблюдение «flare» один раз")
	eq(ev[0].text(), "Стая гребневиков вспыхивает радугой в луче прожектора — корабль видно издалека", ev[0].text())
	w.ship.light_on = false
	w.run(0.5)
	near(sw.glow, 0.7, 1e-3, "гаснет 0,6 в секунду")
	w.run(0.5)
	ok(sw.glow < 0.5)
	var fade := _notes(w, EcoRaduzh.ID, "fade")
	eq(fade.size(), 1, "наблюдение «fade»: прожектор погашен рядом")
	eq(fade[0].text(), "Прожектор погашен — стая гребневиков гаснет")
	w.run(2.0)
	near(sw.glow, 0.0, 1e-6, "погасла")


func test_flare_and_fade_cooldowns() -> void:
	var w := _world()
	var sw := (_sys(w, EcoRaduzh) as EcoRaduzh).swarms[0]
	for round in 3:
		for i in 10:
			_aim(w, EcoRaduzh.center(sw, w.time))
			w.step(0.05)
		w.ship.light_on = false
		w.run(2.0)
	eq(_notes(w, EcoRaduzh.ID, "flare").size(), 1, "вспышка — раз в 30 с")
	eq(_notes(w, EcoRaduzh.ID, "fade").size(), 1, "затухание — раз в 60 с")
	w.run(30.0)
	for i in 10:
		_aim(w, EcoRaduzh.center(sw, w.time))
		w.step(0.05)
	eq(_notes(w, EcoRaduzh.ID, "flare").size(), 2, "через 30 с — снова")


func test_no_fade_note_far_or_light_on() -> void:
	var w := _world()
	var sw := (_sys(w, EcoRaduzh) as EcoRaduzh).swarms[0]
	for i in 10:
		_aim(w, EcoRaduzh.center(sw, w.time))
		w.step(0.05)
	# корабль отвернул луч, свет горит — стая гаснет без сообщения «прожектор погашен»
	w.ship.yaw = PI
	w.run(2.0)
	ok(sw.glow < 0.5)
	eq(_notes(w, EcoRaduzh.ID, "fade").size(), 0, "свет не гас — заметки нет")
	for i in 10:
		w.ship.yaw = 0.0
		_aim(w, EcoRaduzh.center(sw, w.time))
		w.step(0.05)
	w.ship.light_on = false
	w.ship.pos = sw.c + Vector3(80, 0, 0)
	w.run(2.0)
	eq(_notes(w, EcoRaduzh.ID, "fade").size(), 0, "дальше 60 м — не видно, как гаснет")


func test_names_scanned() -> void:
	var w := _world()
	w.scanned = func(id: String) -> bool: return id == EcoRaduzh.ID
	var sw := (_sys(w, EcoRaduzh) as EcoRaduzh).swarms[0]
	_aim(w, sw.c)
	w.step(0.05)
	var ev := _notes(w, EcoRaduzh.ID, "flare")
	eq(ev[0].text(), "Стая радужников вспыхивает радугой в луче прожектора — корабль видно издалека", "изучен — по имени")
	ok(Species.is_observation(EcoRaduzh.ID, "flare") and Species.is_observation(EcoRaduzh.ID, "fade") \
		and Species.is_observation(EcoRaduzh.ID, "betray"), "три заметки журнала")


func test_color_dark_then_rainbow() -> void:
	var w := _world()
	var sw := (_sys(w, EcoRaduzh) as EcoRaduzh).swarms[0]
	var c := EcoRaduzh.member_color(sw, 0, 1.0)
	ok(c.b > c.r and c.b <= 0.12 * 1.2 + 1e-4, "без света — тусклый голубоватый силуэт")
	sw.glow = 1.0
	var a := EcoRaduzh.member_color(sw, 0, 0.0)
	var b := EcoRaduzh.member_color(sw, 0, 1.0)
	ok(maxf(a.r, maxf(a.g, a.b)) > 0.95, "в луче — яркая радуга")
	ok(not a.is_equal_approx(b), "радуга бежит по ресничкам")


# ---------- Серпохвост ----------

## Первый серпохвост голоден, корабль в d м от него; стая вспыхнула (glow = 1, держится лучом каждый шаг).
func _flare_world(d: float) -> Array:
	var w := _world(true)
	var preds := _sys(w, EcoPred) as EcoPred
	var r := _sys(w, EcoRaduzh) as EcoRaduzh
	var pr := preds.all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(d, 0, 0)
	w.ship.light_on = true
	r.swarms[0].glow = 1.0
	r.flare = 1.0  # хищник шагает раньше стаи и видит вспышку прошлого шага
	return [w, pr, r]


func test_flare_calls_pred_from_afar() -> void:
	var a := _flare_world(80.0)
	var w: EcoWorld = a[0]
	var pr: EcoPred.Pred = a[1]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.INVESTIGATE, "дальше чутья (32 м), но вспышку видно — плывёт проверить")
	near(pr.agent.timer, 25.0, 0.1)
	ok(pr.agent.goal.distance_to(w.ship.pos) < 1.0, "к кораблю")
	var ev := _notes(w, EcoRaduzh.ID, "betray")
	eq(ev.size(), 1, "наблюдение «betray»")
	eq(ev[0].text(), "Крупный хищник заметил вспышку гребневиков и плывёт к кораблю", ev[0].text())
	w.run(10.0)
	eq(_notes(w, EcoRaduzh.ID, "betray").size(), 1, "раз в 30 с")


func test_flare_ignored_out_of_range_or_dark() -> void:
	var a := _flare_world(120.0)
	var w: EcoWorld = a[0]
	var pr: EcoPred.Pred = a[1]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "дальше 110 м вспышки не видно")

	a = _flare_world(80.0)
	w = a[0]
	pr = a[1]
	(a[2] as EcoRaduzh).swarms[0].glow = 0.4
	(a[2] as EcoRaduzh).flare = 0.4
	w.ship.light_on = false
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "тусклая стая (≤ 0,5) не выдаёт")

	a = _flare_world(80.0)
	w = a[0]
	pr = a[1]
	pr.cooldown = 10.0
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "после укуса — не плывёт")

	a = _flare_world(80.0)
	w = a[0]
	pr = a[1]
	pr.mode = EcoPred.Mode.EAT
	pr.agent.timer = 5.0
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.EAT, "ест — не отвлекается")
	eq(_notes(w, EcoRaduzh.ID, "betray").size(), 0)


# ---------- Цели и сцена ----------

func test_swarms_are_targets() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var r := w.add(EcoRaduzh.new()) as EcoRaduzh
	var n := 0
	for t in w.scan_targets():
		if t["species"] == EcoRaduzh.ID:
			n += 1
			near(t["r"], 4.0, 1e-6)
			ok(t["sonar"], "видна сонару")
	eq(n, 3, "три цели")
	w.ship.pos = r.swarms[0].c + Vector3(10, 0, 0)
	w.ship.scan_range = 80.0
	w.step(0.05)
	var found := false
	for e in w.take_link():
		if e["type"] == EcoLink.NEAR and e["species"] == EcoRaduzh.ID:
			found = true
	ok(found, "сканер видит стаю рядом")


func test_member_outside_hull() -> void:
	var w := _world()
	var sw := (_sys(w, EcoRaduzh) as EcoRaduzh).swarms[0]
	var p := EcoRaduzh.member_pos(sw, 3, 0.0)
	# корабль ставим так, что гребневик внутри корпуса (у центра EcoHull)
	var ship := p - EcoHull.CENTER
	ok(EcoHull.touches(p, ship, 0.0), "без корпуса — внутри")
	var q := EcoRaduzh.member_pos_outside(sw, 3, 0.0, ship, 0.0)
	ok(not EcoHull.touches(q, ship, 0.0, 0.2), "расступился перед корпусом")
	near(EcoRaduzh.member_pos_outside(sw, 3, 0.0, FAR, 0.0).distance_to(p), 0.0, 1e-6, "вдали — на месте")


## Корабль проходит сквозь стаю: гребневики расступаются вдоль обшивки, а не перескакивают на другой борт (раньше
## до 6 м за кадр), в корпусе не остаются, а когда корабль ушёл — возвращаются на места по дрейфу.
func test_ship_through_swarm_no_jump() -> void:
	for spd in [1.0, 4.0, 8.0]:
		var w := _world()
		var r := _sys(w, EcoRaduzh) as EcoRaduzh
		var sw := r.swarms[0]
		var dt := 1.0 / 30.0
		var c0 := sw.c
		var prev: Array[Vector3] = []
		var worst := 0.0
		var inside := 0
		var pushed := 0.0
		for i in int((60.0 / spd) / dt):
			w.ship.pos = Vector3(c0.x, c0.y + 0.5, c0.z + 30.0 - spd * w.time)
			w.ship.yaw = 0.0
			w.ship.speed = spd
			w.step(dt)
			var cur: Array[Vector3] = []
			for k in EcoRaduzh.PER_SWARM:
				var q := EcoRaduzh.member_pos_outside(sw, k, w.time, w.ship.pos, 0.0)
				cur.append(q - EcoRaduzh.member_pos(sw, k, w.time))
				if EcoHull.touches(q, w.ship.pos, 0.0, 0.2):
					inside += 1
				pushed = maxf(pushed, sw.members[k].d.length())
			if not prev.is_empty():
				for k in EcoRaduzh.PER_SWARM:
					worst = maxf(worst, (cur[k] - prev[k]).length())
			prev = cur
		ok(pushed > 1.0, "корпус отодвигал гребневиков (%.1f м) на %.0f м/с" % [pushed, spd])
		ok(worst < spd * dt + 0.3, "сдвиг за кадр %.2f м на %.0f м/с — без скачка через корпус" % [worst, spd])
		eq(inside, 0, "в корпусе не остаются на %.0f м/с" % spd)
		# корабль ушёл — за 25 с сдвиг растаял, назад — не быстрее RETURN_V
		w.ship.pos = FAR
		w.ship.speed = 0.0
		for i in 25 * 30:
			w.step(dt)
		var left := 0.0
		ok(pushed < 20.0, "не едут на носу (сдвиг до %.1f м)" % pushed)
		for m in sw.members:
			left = maxf(left, m.d.length())
		ok(left < 0.05, "вернулись на места (%.3f м)" % left)


func test_view_two_multimeshes() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	ok(view.preds.raduzh == view.raduzh, "серпохвосты видят вспышки")
	var rv := view.raduzh_view
	ok(rv != null and rv.get_parent() == view, "радужники — в живом мире")
	eq(rv.bodies.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(rv.bodies.multimesh.instance_count, 84, "все гребневики — один MultiMesh")
	eq(rv.halos.multimesh.instance_count, 84, "ореолы — второй")
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	view.step(0.05, ship)
	rv.sync(view.world.time, FAR, 0.0, true)  # дальние стаи переписываются через кадр — здесь все сразу
	var sw := view.raduzh.swarms[2]
	var j := 2 * EcoRaduzh.PER_SWARM + 4
	near(RaduzhView.origin_at(rv.body_buffer, j).distance_to(EcoRaduzh.member_pos(sw, 4, view.world.time)), 0.0, 1e-4,
		"гребневик на месте")
	near(RaduzhView.color_at(rv.halo_buffer, j).r, 0.0, 1e-6, "без вспышки ореола нет")
	sw.glow = 1.0
	rv.sync(view.world.time, FAR, 0.0)
	ok(RaduzhView.color_at(rv.halo_buffer, j).get_luminance() > 0.1, "вспышка — ореол горит")
	view.queue_free()
	await frames(1)


## «Экономно» (Б6): в каждой стае рисуются два гребневика из трёх и их ореолы — видимые в начале буферов; мир считает
## всех, назад — буфер снова по номеру; сброс мира уровень не теряет.
func test_view_lite_draws_two_of_three_per_swarm() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var rv := view.raduzh_view
	eq(rv.drawn(), 84, "на «Обычно» — все гребневики")
	view.set_lite(true)
	ok(rv.lite, "радужники — на «Экономно»")
	var per := EcoRaduzh.PER_SWARM - EcoRaduzh.PER_SWARM / RaduzhView.LITE_SKIP
	eq(rv.drawn(), per * view.raduzh.swarms.size(), "две трети в каждой стае")
	eq(rv.halos.multimesh.visible_instance_count, rv.drawn(), "ореолы — тех же")
	ok(rv.drawn() < 84 * 0.7, "гребневиков меньше на треть: %d" % rv.drawn())
	var seen := {}
	for sw in view.raduzh.swarms:
		var n := 0
		for k in EcoRaduzh.PER_SWARM:
			var idx := sw.index * EcoRaduzh.PER_SWARM + k
			seen[rv.slot_of(idx)] = true
			if rv.slot_of(idx) < rv.drawn():
				n += 1
				ok(RaduzhView.lite_shown(k), "видим только показанный")
		eq(n, per, "в стае %d видно %d" % [sw.index, per])
	eq(seen.size(), 84, "места в буфере не повторяются")
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	view.step(0.05, ship)
	var sw := view.raduzh.swarms[2]
	var idx := 2 * EcoRaduzh.PER_SWARM + 4
	near(RaduzhView.origin_at(rv.body_buffer, rv.slot_of(idx)).distance_to(
		EcoRaduzh.member_pos(sw, 4, view.world.time)), 0.0, 1e-4, "видимый гребневик — на своём месте буфера")
	sw.glow = 1.0
	rv.sync(view.world.time, FAR, 0.0)
	ok(RaduzhView.color_at(rv.halo_buffer, rv.slot_of(idx)).get_luminance() > 0.1, "ореол — на том же месте")
	view.ground = Seabed.height   # сброс мира — виды пересобираются
	ok(view.raduzh_view.lite and view.raduzh_view.drawn() < 84, "сброс мира — снова «Экономно»")
	view.set_lite(false)
	rv = view.raduzh_view
	view.step(0.05, ship)
	eq(rv.drawn(), 84, "назад — все")
	eq(rv.slot_of(idx), idx, "буфер снова по номеру")
	near(RaduzhView.origin_at(rv.body_buffer, idx).distance_to(
		EcoRaduzh.member_pos(view.raduzh.swarms[2], 4, view.world.time)), 0.0, 1e-4, "и места переписаны")
	view.queue_free()
	await frames(1)


## Ряды ресничек бьют (Б3): на ряду под гребнем волны тело ярче, между рядами — тусклее; волна бежит со временем
## от верха ко рту; в среднем по телу яркость прежняя; фаза особи — в альфе цвета тела, время мира — в шейдере.
func test_view_comb_rows_beat() -> void:
	var on_row := Vector3(0.0, 0.0, 1.0)            # atan2(0, 1) = 0 — середина ряда
	var between := Vector3(sin(PI / 8.0), 0.0, cos(PI / 8.0))  # между рядами (8 рядов — через π/4)
	var best := 0.0
	var worst := 99.0
	for i in 40:
		var t := i * 0.02
		best = maxf(best, RaduzhView.comb_k(on_row, t, 0.0))
		worst = minf(worst, RaduzhView.comb_k(on_row, t, 0.0))
		near(RaduzhView.comb_k(between, t, 0.0), lerpf(1.0, RaduzhView.COMB_BASE, RaduzhView.COMB), 1e-4,
			"между рядами — ровно тускло")
	ok(best > 2.5, "на ряду под гребнем волны — вспыхивает (%.2f)" % best)
	ok(worst < 0.7, "на ряду меж гребнями — гаснет (%.2f)" % worst)
	# гребень волны со временем уходит вниз по телу (ко рту)
	var t0 := (PI / 2.0) / RaduzhView.COMB_RATE   # в t0 на экваторе гребень
	var top_y := 0.0
	var later := t0 + 0.05
	var y_peak := -INF
	var k_peak := -INF
	for s in 41:
		var y := -1.0 + s * 0.05
		var k := RaduzhView.comb_k(Vector3(0.0, y, sqrt(maxf(0.0, 1.0 - y * y))), later, 0.0)
		if absf(y) < 0.6 and k > k_peak:
			k_peak = k
			y_peak = y
	ok(y_peak < top_y, "гребень сместился вниз (%.2f)" % y_peak)
	# среднее по сфере ≈ 1
	var sum := 0.0
	var n := 0
	for a in 64:
		for b in 32:
			var y := -1.0 + (b + 0.5) / 16.0
			var r := sqrt(1.0 - y * y)
			var ang := a * TAU / 64.0
			sum += RaduzhView.comb_k(Vector3(sin(ang) * r, y, cos(ang) * r), 0.37, 1.1)
			n += 1
	near(sum / n, 1.0, 0.08, "в среднем по телу яркость прежняя")
	near(RaduzhView.beat_alpha(TAU * 0.25), 0.25, 1e-6, "фаза — доля оборота")
	# сцена: фаза особи в альфе тела, время мира — uniform
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var rv := view.raduzh_view
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	view.step(0.05, ship)
	rv.sync(view.world.time, FAR, 0.0, true)
	var sw := view.raduzh.swarms[1]
	var j := rv.slot_of(1 * EcoRaduzh.PER_SWARM + 5)
	near(RaduzhView.color_at(rv.body_buffer, j).a, RaduzhView.beat_alpha(sw.members[5].phase), 1e-5,
		"фаза биения — в альфе тела")
	near(RaduzhView.color_at(rv.halo_buffer, j).a, 1.0, 1e-6, "ореол не тронут")
	var mat := (rv.bodies.multimesh.mesh as PrimitiveMesh).material as ShaderMaterial
	near(float(mat.get_shader_parameter("world_t")), view.world.time, 1e-5, "время мира — в шейдере тела")
	ok(RaduzhView.body_code().contains("comb_rows"), "ряды — в шейдере тела")
	view.queue_free()
	await frames(1)
