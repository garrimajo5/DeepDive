extends TestCase
## Светляки-полосники (updateFish в js/creatures.js, Unity EcoFishTests и EcoFishLookTests): стаи у кораллов, тревога
## от хищника и корабля, форма рыбки по ART-011, курс и цвет стаи, один MultiMesh в сцене.


func _world(world_seed: int = EcoRandom.WORLD_SEED) -> EcoWorld:
	var w := EcoWorld.new(world_seed)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)  # корабль далеко и не мешает
	w.add(EcoFish.new())
	return w


func _fish(w: EcoWorld) -> EcoFish:
	return w.systems[0] as EcoFish


func _mean_to(sh: EcoFish.Shoal, p: Vector3) -> float:
	var s := 0.0
	var n := 0
	for f: EcoFish.Fish in sh.members:
		if f.agent.alive:
			s += f.agent.p.distance_to(p)
			n += 1
	return s / n


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------- Поведение стай ----------

func test_six_shoals_of_22_at_corals() -> void:
	var w := _world()
	var fish := _fish(w)
	eq(fish.shoals.size(), 6, "шесть стай")
	eq(fish.all.size(), 132, "132 рыбки")
	eq(w.count("fish"), 132, "все в мире")
	near(fish.shoals[0].home.x, 15.375, 0.01, "дом первой стаи — как в браузере")
	near(fish.shoals[0].home.z, 75.99, 0.01)
	for i in fish.all.size():
		var f := fish.all[i]
		eq(f.index, i, "номер рыбки")
		eq(f.agent.species, "fish")
		var d := f.agent.p - f.shoal.home
		if not ok(absf(d.x) <= 3.0 and d.y >= 0.0 and d.y <= 3.0 and absf(d.z) <= 3.0, "рыбка у дома: %s" % d):
			return
		ok(f.bright >= 0.75 and f.bright <= 1.15, "яркость 0,75…1,15")
	for sh in fish.shoals:
		near(sh.home.y - Seabed.height(sh.home.x, sh.home.z), 3.5, 0.25, "дом стаи на 3,5 м над дном")


func test_shoal_roams_near_home_and_keeps_together() -> void:
	var w := _world()
	var fish := _fish(w)
	for s in 6:
		w.run(30.0)
		for sh in fish.shoals:
			eq(sh.alive, EcoFish.PER_SHOAL, "все живы")
			eq(sh.alarm, 0.0, "без угроз тревоги нет")
			for f: EcoFish.Fish in sh.members:
				var p := f.agent.p
				var good := _flat(p, sh.home) < 30.0 and p.distance_to(sh.center) < 6.0 \
					and p.y - Seabed.height(p.x, p.z) > -0.5 and p.y < -3.0 \
					and f.agent.v.length() <= EcoFish.CALM_SPEED + 1e-3 and f.agent.state == EcoAgent.State.GRAZE
				if not ok(good, "стая %d, %d с: у дома, вместе, над дном, подо льдом, спокойно (p=%s, центр=%s)"
						% [sh.index, (s + 1) * 30, p, sh.center]):
					return
	eq(w.bus.pending.size(), 0, "спокойная стая молчит")


func test_predator_sends_shoal_home_to_hide() -> void:
	var w := _world()
	var fish := _fish(w)
	var sh := fish.shoals[0]
	w.run(8.0)  # стая отошла от дома
	ok(_mean_to(sh, sh.home) > 8.0, "стая отошла от дома")
	var pred := w.spawn("pred", sh.center + Vector3(5, 0, 0))  # стоит на месте
	w.step(0.05)
	ok(sh.alarm > 0.0, "тревога")
	for f: EcoFish.Fish in sh.members:
		if not ok(f.agent.state != EcoAgent.State.GRAZE, "в тревоге не пасётся"):
			break
	var ev := w.bus.take()
	eq(ev.size(), 1, "одно событие")
	eq(ev[0].species, "fish")
	eq(ev[0].note, "flee")
	ok(ev[0].is_observation(), "наблюдение для журнала")
	eq(ev[0].text(), "Мелкая рыба: стая уходит в кораллы — рядом хищник")

	w.run(8.0)
	ok(_mean_to(sh, sh.home) < 5.0, "стая у дома в кораллах")
	var hiding := 0
	for f: EcoFish.Fish in sh.members:
		if f.agent.state == EcoAgent.State.HIDE:
			hiding += 1
			ok(f.agent.v.length() <= EcoFish.HIDE_SPEED + 1e-3, "прячутся медленно")
	ok(hiding >= 15, "прячутся почти все: %d" % hiding)
	near(sh.flee_cd, EcoFish.FLEE_COOLDOWN - 8.0, 0.02, "сообщение не чаще раза в 30 с")
	eq(fish.shoals[4].alarm, 0.0, "дальняя стая спокойна")

	pred.alive = false  # хищник ушёл — тревога спадает
	w.run(4.0)
	eq(sh.alarm, 0.0, "тревога прошла")


func test_ship_under_way_scares_without_message() -> void:
	var w := _world()
	var fish := _fish(w)
	var sh := fish.shoals[0]
	w.run(8.0)
	w.ship.pos = sh.center + Vector3(3, 0, 0)
	w.ship.speed = 0.5  # медленно — не пугает
	w.step(0.05)
	eq(sh.alarm, 0.0, "медленный корабль не пугает")
	w.ship.speed = -2.0  # задний ход тоже шумит
	w.step(0.05)
	ok(sh.alarm > 0.0, "быстрый — пугает")
	ok(sh.threat_is_ship, "угроза — корабль")
	var close := _mean_to(sh, w.ship.pos)
	w.run(2.0)
	ok(_mean_to(sh, w.ship.pos) > close + 4.0, "рыбки шарахаются от корабля")
	eq(w.bus.pending.size(), 0, "корабль не хищник — сообщения нет")


func test_eaten_fish_returns_home() -> void:
	var w := _world()
	var fish := _fish(w)
	w.run(1.0)
	var f := fish.all[5]
	var at := f.agent.p
	fish.kill(f)
	ok(not f.agent.alive, "съедена")
	eq(w.count("fish"), 131)
	ok(fish.nearest_fish(at, 50.0) != f, "съеденную не ловят")
	ok(fish.nearest_fish(at, 50.0, func(_x: EcoFish.Fish) -> bool: return true) == null, "все в укрытии — ловить некого")
	w.run(24.0)
	ok(not f.agent.alive, "не раньше 25 с")
	w.run(16.5)
	ok(f.agent.alive, "вернулась")
	eq(w.count("fish"), 132)
	ok(f.agent.p.distance_to(f.shoal.home) < 32.0, "вернулась к своей стае")


func _snapshot(fish: EcoFish) -> String:
	var parts := PackedStringArray()
	for f in fish.all:
		parts.append(var_to_str(f.agent.p))
	return "|".join(parts)


func test_same_seed_same_shoals() -> void:
	var a := _world()
	var b := _world()
	var c := _world(7)
	a.run(10.0)
	b.run(10.0)
	c.run(10.0)
	eq(_snapshot(_fish(a)), _snapshot(_fish(b)), "одно зерно — одни стаи")
	ok(_snapshot(_fish(a)) != _snapshot(_fish(c)), "другое зерно — другие")
	a.reset()
	eq(_fish(a).all.size(), 132)
	a.run(10.0)
	eq(_snapshot(_fish(b)), _snapshot(_fish(a)), "сброс возвращает стаи в начало")


func test_scanned_fish_is_named() -> void:
	var w := _world()
	w.scanned = func(sp: String) -> bool: return sp == "fish"
	w.spawn("pred", _fish(w).shoals[2].center)
	w.step(0.05)
	var ev := w.bus.take()
	eq(ev.size(), 1)
	eq(ev[0].text(), "Светляк-полосник: стая уходит в кораллы — рядом хищник")


func test_flee_message_reaches_ship_nearby() -> void:
	var w := _world()
	var sh := _fish(w).shoals[0]
	w.ship.pos = sh.home + Vector3(0, 10, 40)  # в 80 м слышно, корабль стоит
	w.spawn("pred", sh.center + Vector3(4, 0, 0))
	w.step(0.05)
	var link := w.take_link()
	eq(link.size(), 1, "одно событие: наблюдение и текст вместе")
	eq(link[0]["type"], EcoLink.OBSERVE)
	eq([link[0]["species"], link[0]["note"]], ["fish", "flee"], "заметка журнала")
	eq(link[0]["text"], "Мелкая рыба: стая уходит в кораллы — рядом хищник")


# ---------- Вид рыбки (EcoFishLook) ----------

func _find(x: float, y: float, z: float) -> int:
	for i in EcoFishLook.shape.size():
		if EcoFishLook.shape[i].distance_to(Vector3(x, y, z)) < 1e-4:
			return i
	ok(false, "нет вершины (%f, %f, %f)" % [x, y, z])
	return 0


## Момент, когда рыбка не виляет: sin(t·12 + фаза) = 0.
func _straight(f: EcoFish.Fish) -> float:
	return -f.phase / EcoFishLook.WIGGLE_RATE


func _close(want: Vector3, got: Vector3, msg: String) -> void:
	ok(want.distance_to(got) < 1e-3, "%s: ждали %s, вышло %s" % [msg, want, got])


func test_spindle_with_four_stripes() -> void:
	var s := EcoFishLook.shape
	eq(EcoFishLook.paints.size(), s.size())
	eq(EcoFishLook.normals.size(), s.size())
	ok(EcoFishLook.tris.size() / 3 < 150, "до 150 треугольников, как в ART-011")
	for i in EcoFishLook.tris:
		if not ok(i >= 0 and i < s.size(), "номер вершины в форме"):
			return
	var stripes := 0
	for b in EcoFishLook.RING_STRIPE:
		if b:
			stripes += 1
	eq(stripes, 4, "четыре полосы")
	eq(EcoFishLook.paints[EcoFishLook.stripe_vertex], EcoFishLook.Paint.STRIPE)
	var mx := 0.0
	var my := 0.0
	var mn_z := 0.0
	var mx_z := 0.0
	for p in s:
		mx = maxf(mx, p.x)
		my = maxf(my, p.y)
		mn_z = minf(mn_z, p.z)
		mx_z = maxf(mx_z, p.z)
	near(mx_z, 0.28, 1e-5, "нос")
	near(mn_z, -0.42, 1e-5, "хвост")
	ok(mx >= 0.06 and mx <= 0.07, "полуширина")
	ok(my >= 0.1 and my <= 0.121, "спина и хвост")
	eq(EcoFishLook.paints[_find(0, 0.12, -0.42)], EcoFishLook.Paint.FIN, "концы хвоста светятся")
	eq(EcoFishLook.paints[_find(0, 0, 0.28)], EcoFishLook.Paint.BODY, "нос тёмный")


func test_body_closed_faces_out_by_godot_rule() -> void:
	var s := EcoFishLook.shape
	var t := EcoFishLook.tris
	var fin := _find(0, 0.12, -0.42)
	var vol := 0.0
	var edges := {}
	var fin_tris := 0
	for i in range(0, t.size(), 3):
		if t[i] == fin or t[i + 1] == fin or t[i + 2] == fin:
			fin_tris += 1
			continue
		vol += s[t[i]].dot(s[t[i + 1]].cross(s[t[i + 2]])) / 6.0
		for k in 3:
			var e := t[i + k] * 1000 + t[i + (k + 1) % 3]
			edges[e] = edges.get(e, 0) + 1
	# по правилу Godot (b − a) × (c − a) смотрит внутрь — объём со знаком минус
	ok(vol < 0.0, "грани тела смотрят наружу по правилу Godot: %f" % vol)
	for e: int in edges:
		if not eq(edges[e], 1, "ребро тела один раз в каждую сторону"):
			return
		if not ok(edges.has((e % 1000) * 1000 + e / 1000), "тело замкнуто"):
			return
	eq(fin_tris, 2, "хвост — один треугольник в обе стороны")


func test_nose_follows_velocity() -> void:
	var w := _world()
	var f := _fish(w).all[0]
	f.agent.v = Vector3(3, 0, 0)
	var p := f.agent.p
	var t := _straight(f)
	_close(p + Vector3(0.28, 0, 0), EcoFishLook.place(f, t, _find(0, 0, 0.28)), "нос по ходу")
	_close(p + Vector3(-0.25, 0, 0), EcoFishLook.place(f, t, _find(0, 0, -0.25)), "корма сзади")
	_close(p + Vector3(-0.42, 0.12, 0), EcoFishLook.place(f, t, _find(0, 0.12, -0.42)), "хвост позади и вверх")
	var side := EcoFishLook.shape[EcoFishLook.stripe_vertex]
	ok(side.x > 0.05, "вершина полосы — на боку")
	_close(p + Vector3(side.z, 0, -side.x), EcoFishLook.place(f, t, EcoFishLook.stripe_vertex), "бок поперёк хода")
	ok(EcoFishLook.basis(f, t).determinant() > 0.99, "поворот без зеркала — грани не выворачиваются")


func test_wiggle_within_025() -> void:
	var w := _world()
	var f := _fish(w).all[3]
	f.agent.v = Vector3(0, 0, -2)
	var mx := 0.0
	for i in 200:
		var fw := EcoFishLook.forward(f, i * 0.013)
		if not near(fw.length(), 1.0, 1e-4, "курс единичный"):
			return
		mx = maxf(mx, acos(minf(1.0, -fw.z)))
	ok(mx <= EcoFishLook.WIGGLE + 1e-3, "не больше 0,25 рад")
	ok(mx > 0.2, "виляет заметно")


func test_vertical_and_still_do_not_break() -> void:
	var w := _world()
	var f := _fish(w).all[5]
	f.agent.v = Vector3(0, 2, 0)
	_close(f.agent.p + Vector3(0, 0.28, 0), EcoFishLook.place(f, 1.3, _find(0, 0, 0.28)), "плывёт вверх — нос вверх")
	f.agent.v = Vector3.ZERO
	var b := EcoFishLook.basis(f, 1.3)
	for v in [b.x, b.y, b.z]:
		ok(not (is_nan(v.x) or is_nan(v.y) or is_nan(v.z)), "без NaN")


func test_eaten_fish_invisible() -> void:
	var w := _world()
	var fish := _fish(w)
	var f := fish.all[7]
	fish.kill(f)
	for i in EcoFishLook.verts_per_fish():
		if not eq(EcoFishLook.place(f, 0.0, i), f.agent.p, "все вершины в одной точке"):
			return


func test_stripes_shoal_colour_body_dark() -> void:
	var w := _world()
	var fish := _fish(w)
	for s in fish.shoals.size():
		var f: EcoFish.Fish = fish.shoals[s].members[0]
		var c := EcoFish.COLORS[s]
		ok(c.b > c.r, "полосы в голубой гамме: синего больше красного")
		var st := EcoFishLook.stripe(f)
		near(st.r, c.r * f.bright, 1e-4)
		near(st.g, c.g * f.bright, 1e-4)
		near(st.b, c.b * f.bright, 1e-4)
		near(EcoFishLook.vertex_color(f, EcoFishLook.Paint.FIN).g, st.g * EcoFishLook.FIN_GLOW, 1e-4, "концы хвоста тише")
		var body := EcoFishLook.vertex_color(f, EcoFishLook.Paint.BODY)
		near(body.r, 0x34 / 255.0, 1e-4, "тело #344F63")
		near(body.g, 0x4F / 255.0, 1e-4)
		near(body.b, 0x63 / 255.0, 1e-4)
	var f0: EcoFish.Fish = fish.shoals[0].members[0]
	var g0 := EcoFishLook.stripe(f0).g
	fish.shoals[0].alarm = 2.0
	eq(EcoFishLook.vertex_color(f0, EcoFishLook.Paint.BODY), EcoFishLook.BODY_COLOR, "в тревоге тело не меняется")
	near(EcoFishLook.stripe(f0).g, g0 * EcoFishLook.ALARM_GLOW, 1e-4, "полосы ярче")


func test_ship_under_way_lights_shoal_up() -> void:
	var w := _world()
	var sh := _fish(w).shoals[2]
	var f: EcoFish.Fish = sh.members[0]
	near(EcoFishLook.brightness(f), f.bright, 1e-6, "спокойная стая — своя яркость")
	w.ship.pos = sh.center + Vector3(3, 0, 0)
	w.ship.speed = 3.0
	w.step(0.05)
	near(EcoFishLook.brightness(f), f.bright * EcoFishLook.ALARM_GLOW, 1e-5, "в тревоге ярче")
	w.ship.pos = Vector3(500, 0, 500)
	w.run(3.0)
	near(EcoFishLook.brightness(f), f.bright, 1e-6, "угроза ушла — гаснет обратно")


# ---------- В сцене ----------

func test_view_one_multimesh_follows_world() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var fv := view.fish_view
	ok(fv != null and fv.get_parent() == view, "светляки — в живом мире")
	eq(fv.multimesh.instance_count, 132, "один MultiMesh на всех")
	eq(fv.layers, OceanView.LAYER_WORLD, "слой отмели")
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	for i in 20:
		view.step(0.05, ship)
	var f := view.fish.all[10]
	var tr := FishView.transform_at(fv.buffer, f.index)
	ok(tr.origin.distance_to(f.agent.p) < 1e-3, "место рыбки — из мира")
	_close(EcoFishLook.forward(f, view.world.time), tr.basis * Vector3(0, 0, 1), "нос по курсу")
	ok(fv.buffer.size() == 132 * FishView.STRIDE, "буфер на всех рыбок")
	var c := FishView.stripe_at(fv.buffer, f.index)
	near(c.g, EcoFishLook.stripe(f).g, 1e-3, "цвет полос стаи")
	view.fish.kill(f)
	view.step(0.05, ship)
	eq(FishView.transform_at(fv.buffer, f.index).basis, Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO),
		"съеденная стянута в точку")
	view.queue_free()
	await frames(1)
