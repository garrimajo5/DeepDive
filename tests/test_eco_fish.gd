extends TestCase
## Светляки-полосники (updateFish в js/creatures.js, Unity EcoFishTests и EcoFishLookTests): стаи у кораллов, тревога
## от хищника и корабля, форма рыбки по ART-011, курс и цвет стаи, один MultiMesh в сцене.


## Всех рыбок: шесть стай рифа и две у кроны Каменного цветка по 22, молодь в костях — 14.
const ALL := EcoFish.PER_SHOAL * (6 + EcoFish.CROWN_SHOALS) + EcoFish.JUV_PER


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
	eq(fish.shoals.size(), 9, "шесть стай рифа, две у кроны и молодь в костях")
	eq(fish.all.size(), 190, "190 рыбок")
	eq(EcoFish.total(), 190)
	eq(w.count("fish"), 190, "все в мире")
	near(fish.shoals[0].home.x, 15.375, 0.01, "дом первой стаи — как в браузере")
	near(fish.shoals[0].home.z, 75.99, 0.01)
	for i in fish.all.size():
		var f := fish.all[i]
		eq(f.index, i, "номер рыбки")
		eq(f.agent.species, "fish")
		if f.shoal.crown or f.shoal.cage:
			continue  # стаи у кроны — test_crown_shoals_circle_flower, молодь — test_young_hide_between_ribs
		var d := f.agent.p - f.shoal.home
		if not ok(absf(d.x) <= 3.0 and d.y >= 0.0 and d.y <= 3.0 and absf(d.z) <= 3.0, "рыбка у дома: %s" % d):
			return
		ok(f.bright >= 0.75 and f.bright <= 1.15, "яркость 0,75…1,15")
	for sh in fish.shoals:
		if not sh.crown and not sh.cage:
			near(sh.home.y - Seabed.height(sh.home.x, sh.home.z), 3.5, 0.25, "дом стаи на 3,5 м над дном")



## Б3 «плавность»: центр стаи после сброса — среднее рыбок, как в шаге; раньше стоял в доме, а рыбки — выше и
## вразброс, и на первом шаге центр (цель сканера и сонара, испуг, охота) прыгал до 1,9 м.
func test_center_is_mean_after_reset() -> void:
	var w := _world()
	var fish := _fish(w)
	for sh in fish.shoals:
		var sum := Vector3.ZERO
		for f: EcoFish.Fish in sh.members:
			sum += f.agent.p
		near(sh.center.distance_to(sum / sh.members.size()), 0.0, 1e-3, "центр стаи %d — среднее рыбок" % sh.index)
	w.reset()
	var sh0 := fish.shoals[0]
	var sum0 := Vector3.ZERO
	for f: EcoFish.Fish in sh0.members:
		sum0 += f.agent.p
	near(sh0.center.distance_to(sum0 / sh0.members.size()), 0.0, 1e-3, "и после сброса мира")


func test_shoal_roams_near_home_and_keeps_together() -> void:
	var w := _world()
	var fish := _fish(w)
	for s in 6:
		w.run(30.0)
		for sh in fish.shoals:
			eq(sh.alive, sh.members.size(), "все живы")
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
	w.ship.pos = sh.home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира, не по очереди дальних (issue #803)
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


## Стаи у кроны Каменного цветка (ART-027): кружат снаружи кроны, каждая в свою сторону, сквозь ветви почти не ходят.
func test_crown_shoals_circle_flower() -> void:
	var w := _world()
	var fish := _fish(w)
	var flower := w.add(EcoFlower.new()) as EcoFlower
	var foot := Vector3(EcoFlower.CENTER.x, Seabed.height(EcoFlower.CENTER.x, EcoFlower.CENTER.y), EcoFlower.CENTER.y)
	var crown: Array[EcoFish.Shoal] = []
	for sh in fish.shoals:
		if sh.crown:
			crown.append(sh)
	eq(crown.size(), EcoFish.CROWN_SHOALS, "две стаи у кроны")
	eq(fish.shoals[6], crown[0], "после шести стай рифа — их номера не сдвинулись")
	ok(crown[0].turn * crown[1].turn < 0.0, "кружат в разные стороны")
	for sh in crown:
		near(sh.home.distance_to(foot + Vector3(0, EcoFish.CROWN_HIDE, 0)), 0.0, 1e-3, "дом — в чаше на оси")
		ok(not flower.solid(sh.home), "в доме ветвей нет")
		ok(_flat(sh.center, foot) > EcoFlower.SPREAD, "начинают снаружи кроны")
	var turned: Array[float] = [0.0, 0.0]
	var last: Array[float] = []
	for sh in crown:
		last.append(atan2(sh.center.z - foot.z, sh.center.x - foot.x))
	var samples := 0
	var inside := 0
	for s in 360:
		w.run(0.5)
		for i in crown.size():
			var sh := crown[i]
			eq(sh.alarm, 0.0, "без угроз спокойны")
			var r := _flat(sh.center, foot)
			var h := sh.center.y - foot.y
			if not ok(r > 12.0 and r < 23.0 and h > 11.0 and h < 32.0,
					"стая %d у кроны снаружи: r=%.1f, h=%.1f" % [sh.index, r, h]):
				return
			var a := atan2(sh.center.z - foot.z, sh.center.x - foot.x)
			turned[i] += wrapf(a - last[i], -PI, PI)
			last[i] = a
			for f: EcoFish.Fish in sh.members:
				samples += 1
				if flower.solid(f.agent.p):
					inside += 1
	for i in crown.size():
		ok(turned[i] * crown[i].turn > TAU, "стая %d обошла крону в свою сторону: %.1f рад" % [i, turned[i]])
	ok(inside < samples * 0.01, "сквозь ветви почти не плывут: %d из %d" % [inside, samples])


func test_crown_shoal_hides_in_chalice() -> void:
	var w := _world()
	var fish := _fish(w)
	var flower := w.add(EcoFlower.new()) as EcoFlower
	var sh := fish.shoals[6]
	w.run(10.0)
	var pred := w.spawn("pred", sh.center)
	for s in 30:  # хищник гонит стаю снаружи, со стороны от кроны
		var out := Vector3(sh.center.x - sh.home.x, 0, sh.center.z - sh.home.z)
		if out.length() > 6.0:  # у чаши хищник остаётся снаружи кроны
			pred.p = sh.center + out.normalized() * 5.0
		w.run(0.5)
	ok(_mean_to(sh, sh.home) < 5.0, "стая ушла в чашу кроны: %.1f м" % _mean_to(sh, sh.home))
	var hiding := 0
	var inside := 0
	for f: EcoFish.Fish in sh.members:
		if f.agent.state == EcoAgent.State.HIDE:
			hiding += 1
		if flower.solid(f.agent.p):
			inside += 1
	ok(hiding >= 15, "прячутся почти все: %d" % hiding)
	ok(inside <= 1, "в чаше, а не в ветвях: %d" % inside)


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
	eq(w.count("fish"), ALL - 1)
	ok(fish.nearest_fish(at, 50.0) != f, "съеденную не ловят")
	ok(fish.nearest_fish(at, 50.0, func(_x: EcoFish.Fish) -> bool: return true) == null, "все в укрытии — ловить некого")
	w.run(24.0)
	ok(not f.agent.alive, "не раньше 25 с")
	w.run(16.5)
	ok(f.agent.alive, "вернулась")
	eq(w.count("fish"), ALL)
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
	eq(_fish(a).all.size(), ALL)
	a.run(10.0)
	eq(_snapshot(_fish(b)), _snapshot(_fish(a)), "сброс возвращает стаи в начало")


func test_scanned_fish_is_named() -> void:
	var w := _world()
	w.scanned = func(sp: String) -> bool: return sp == "fish"
	w.ship.pos = _fish(w).shoals[2].home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира, не по очереди дальних (issue #803)
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


## Момент, когда рыбка не виляет: sin(t·частота особи + фаза) = 0.
func _straight(f: EcoFish.Fish) -> float:
	return -f.phase / EcoFishLook.wiggle_rate(f)


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
	var k := EcoFishLook.scale(f)
	_close(p + Vector3(0.28, 0, 0) * k, EcoFishLook.place(f, t, _find(0, 0, 0.28)), "нос по ходу")
	_close(p + Vector3(-0.25, 0, 0) * k, EcoFishLook.place(f, t, _find(0, 0, -0.25)), "корма сзади")
	_close(p + Vector3(-0.42, 0.12, 0) * k, EcoFishLook.place(f, t, _find(0, 0.12, -0.42)), "хвост позади и вверх")
	var side := EcoFishLook.shape[EcoFishLook.stripe_vertex]
	ok(side.x > 0.05, "вершина полосы — на боку")
	_close(p + Vector3(side.z, 0, -side.x) * k, EcoFishLook.place(f, t, EcoFishLook.stripe_vertex), "бок поперёк хода")
	near(EcoFishLook.basis(f, t).determinant(), k * k * k, 1e-3, "поворот без зеркала — грани не выворачиваются")


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
	_close(f.agent.p + Vector3(0, 0.28 * EcoFishLook.scale(f), 0), EcoFishLook.place(f, 1.3, _find(0, 0, 0.28)),
		"плывёт вверх — нос вверх")
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
		var c := EcoFish.COLORS[s % EcoFish.COLORS.size()]
		ok(c.b > c.r, "полосы в голубой гамме: синего больше красного")
		var st := EcoFishLook.stripe(f)
		near(st.r, c.r * f.bright, 1e-4)
		near(st.g, c.g * f.bright, 1e-4)
		near(st.b, c.b * f.bright, 1e-4)
		near(EcoFishLook.vertex_color(f, EcoFishLook.Paint.FIN).g, st.g * EcoFishLook.FIN_GLOW, 1e-4, "концы хвоста тише")
		var body := EcoFishLook.vertex_color(f, EcoFishLook.Paint.BODY)
		var sd := EcoFishLook.shade(f)
		near(body.r, 0x34 / 255.0 * sd, 1e-4, "тело #344F63 своего оттенка")
		near(body.g, 0x4F / 255.0 * sd, 1e-4)
		near(body.b, 0x63 / 255.0 * sd, 1e-4)
	var f0: EcoFish.Fish = fish.shoals[0].members[0]
	var g0 := EcoFishLook.stripe(f0).g
	fish.shoals[0].alarm = 2.0
	eq(EcoFishLook.vertex_color(f0, EcoFishLook.Paint.BODY), EcoFishLook.body_color(f0), "в тревоге тело не меняется")
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


## Волна хвоста (Б3): голова жёсткая, изгиб растёт к кончику хвоста; волна бежит к хвосту; «Экономно» гасит.
func test_tail_wave_bends_tail_not_head() -> void:
	eq(EcoFishLook.tail_bend(EcoFishLook.NOSE), 0.0, "нос не гнётся")
	eq(EcoFishLook.tail_bend(EcoFishLook.TAIL_FROM), 0.0, "голова до TAIL_FROM жёсткая")
	near(EcoFishLook.tail_bend(EcoFishLook.TAIL_TIP), 1.0, 1e-6, "кончик хвоста гнётся целиком")
	ok(EcoFishLook.tail_bend(-0.22) < EcoFishLook.tail_bend(-0.35), "к кончику сильнее")
	var most := 0.0
	var head := 0.0
	for k in 200:
		var t := k * 0.013
		most = maxf(most, absf(EcoFishLook.tail_wave(EcoFishLook.TAIL_TIP, t, 0.3)))
		head = maxf(head, absf(EcoFishLook.tail_wave(0.2, t, 0.3)))
	eq(head, 0.0, "голова стоит")
	ok(most > EcoFishLook.TAIL_AMP * 0.9 and most <= EcoFishLook.TAIL_AMP + 1e-6, "кончик ходит на ±TAIL_AMP")
	eq(EcoFishLook.tail_wave(EcoFishLook.TAIL_TIP, 0.7, 0.3, 0.0), 0.0, "«Экономно» — без волны")
	# бегущая волна: гребень у корня хвоста догоняется кончиком чуть позже
	var a := 0.3
	var rate := EcoFishLook.TAIL_RATE * (1.0 - EcoFishLook.TAIL_RATE_SPREAD
		+ 2.0 * EcoFishLook.TAIL_RATE_SPREAD * fposmod(a * 7.13, 1.0))
	var dt := (-0.1 - EcoFishLook.TAIL_TIP) * EcoFishLook.TAIL_K / rate
	var root := EcoFishLook.tail_wave(-0.1, 0.5, a) / EcoFishLook.tail_bend(-0.1)
	var tip := EcoFishLook.tail_wave(EcoFishLook.TAIL_TIP, 0.5 + dt, a) / EcoFishLook.TAIL_AMP
	near(root / EcoFishLook.TAIL_AMP, tip, 1e-4, "волна бежит к кончику")


## У рыбок одной стаи фазы хвоста разные — машут вразнобой.
func test_tail_phase_differs_in_shoal() -> void:
	var w := _world()
	var fish := _fish(w)
	var phases := {}
	for f: EcoFish.Fish in fish.shoals[0].members:
		var a := EcoFishLook.tail_phase(f)
		ok(a >= 0.0 and a < 1.0, "фаза — доля оборота")
		phases[snappedf(a, 0.01)] = true
	ok(phases.size() > fish.shoals[0].members.size() / 2, "фазы разные")


# ---------- В сцене ----------

func test_view_one_multimesh_follows_world() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var fv := view.fish_view
	ok(fv != null and fv.get_parent() == view, "светляки — в живом мире")
	eq(fv.multimesh.instance_count, ALL, "один MultiMesh на всех")
	eq(fv.layers, OceanView.LAYER_WORLD, "слой отмели")
	var ship := EcoLink.ShipState.new()
	var f := view.fish.all[10]
	ship.pos = f.shoal.home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира, не по очереди дальних (issue #803)
	for i in 20:
		view.step(0.05, ship)
	var tr := FishView.transform_at(fv.buffer, f.index)
	ok(tr.origin.distance_to(f.agent.p) < 1e-3, "место рыбки — из мира")
	_close(EcoFishLook.forward(f, view.world.time) * EcoFishLook.scale(f), tr.basis * Vector3(0, 0, 1), "нос по курсу")
	_close(EcoFishLook.basis(f, view.world.time).x, tr.basis.x, "расстановка — как EcoFishLook.basis")
	near(FishView.shade_at(fv.buffer, f.index), EcoFishLook.shade(f), 1e-5, "оттенок тела особи")
	near(FishView.tail_phase_at(fv.buffer, f.index), EcoFishLook.tail_phase(f), 1e-5, "фаза хвоста — в альфе цвета")
	var mat := fv.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	var code := mat.shader.code
	ok(code.contains("VERTEX.x +=") and code.contains("%.5f" % EcoFishLook.TAIL_K)
		and code.contains("%.5f" % EcoFishLook.TAIL_AMP), "волна хвоста в шейдере — числа из EcoFishLook")
	EcoShaders.set_sway_lite(true)
	eq(mat.get_shader_parameter("sway_k"), 0.0, "«Экономно» гасит волну хвоста")
	EcoShaders.set_sway_lite(false)
	eq(mat.get_shader_parameter("sway_k"), 1.0, "и возвращает")
	ok(fv.buffer.size() == ALL * FishView.STRIDE, "буфер на всех рыбок")
	var c := FishView.stripe_at(fv.buffer, f.index)
	near(c.g, EcoFishLook.stripe(f).g, 1e-3, "цвет полос стаи")
	view.fish.kill(f)
	view.step(0.05, ship)
	eq(FishView.transform_at(fv.buffer, f.index).basis, Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO),
		"съеденная стянута в точку")
	view.queue_free()
	await frames(1)



## «Экономно» (Б6): в каждой стае рисуются две рыбки из трёх — видимые в начале буфера; мир считает всех, назад —
## буфер снова по номеру рыбки.
func test_view_lite_draws_two_of_three_per_shoal() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var fv := view.fish_view
	eq(fv.drawn(), ALL, "на «Обычно» — все рыбки")
	view.set_lite(true)
	ok(fv.lite, "вид рыбок — на «Экономно»")
	var shown := 0
	for sh: EcoFish.Shoal in view.fish.shoals:
		var n := 0
		for f: EcoFish.Fish in sh.members:
			if fv.slot_of(f.index) < fv.drawn():
				n += 1
		eq(n, sh.members.size() - sh.members.size() / FishView.LITE_SKIP, "в стае %d — две из трёх" % sh.members.size())
		ok(n > 0, "каждая стая видна")
		shown += n
	eq(fv.drawn(), shown, "рисуются ровно видимые")
	ok(fv.drawn() < ALL * 0.7, "рыбок меньше на треть: %d из %d" % [fv.drawn(), ALL])
	var seen := {}
	for f: EcoFish.Fish in view.fish.all:
		seen[fv.slot_of(f.index)] = true
	eq(seen.size(), ALL, "места в буфере не повторяются")
	var f: EcoFish.Fish = view.fish.shoals[0].members[0]
	var ship := EcoLink.ShipState.new()
	ship.pos = f.shoal.home + Vector3(0, 0, 40)
	for i in 10:
		view.step(0.05, ship)
	ok(FishView.transform_at(fv.buffer, fv.slot_of(f.index)).origin.distance_to(f.agent.p) < 1e-3,
		"видимая рыбка — на своём месте буфера")
	view.set_lite(false)
	view.step(0.05, ship)
	eq(fv.drawn(), ALL, "назад — все рыбки")
	eq(fv.slot_of(f.index), f.index, "буфер снова по номеру")
	ok(FishView.transform_at(fv.buffer, f.index).origin.distance_to(f.agent.p) < 1e-3, "и места переписаны")
	view.queue_free()
	await frames(1)

## «Между рёбрами прячется молодь» (ART-030): стайка мелких светляков бродит внутри чистого прохода клетки
## Костей левиафана, в кость не заходит, от хищника прячется в середине клетки.
func test_young_hide_between_ribs() -> void:
	var w := _world()
	var fish := _fish(w)
	var bones := w.add(EcoBones.new()) as EcoBones
	var sh: EcoFish.Shoal = fish.shoals[8]
	ok(sh.cage and not sh.crown, "девятая стая — молодь в костях, номера прежних не сдвинулись")
	eq(sh.members.size(), EcoFish.JUV_PER, "14 мальков")
	for f: EcoFish.Fish in sh.members:
		near(f.size, EcoFish.JUV_SIZE, 1e-6, "мельче взрослых")
		near(EcoFishLook.basis(f, 0.0).x.length(), EcoFish.JUV_SIZE * EcoFishLook.scale(f) / f.size, 1e-4, "и в форме")
		ok(EcoFishLook.scale(f) <= EcoFish.JUV_SIZE * (1.0 + EcoFishLook.SIZE_SPREAD) + 1e-5, "малёк мельче взрослых")
	var hl := bones.to_local(sh.home)
	ok(absf(hl.x) < 0.01 and absf(hl.z) < 0.01, "дом — в середине клетки")
	ok(not bones.solid(sh.home), "в доме костей нет")
	var samples := 0
	var in_bone := 0
	var halves := [0, 0]
	for s in 240:
		w.run(0.5)
		var c := bones.to_local(sh.center)
		if not ok(absf(c.x) < EcoBones.PASS_W * 0.5 and absf(c.z) < EcoBones.CAGE_LEN * 0.5 + 1.0
				and c.y > bones.floor_y(sh.center.x, sh.center.z) and c.y < bones.pass_floor(c.z) + EcoBones.PASS_H,
				"%d с: стая в проходе клетки (%s)" % [s / 2, c]):
			return
		halves[0 if c.z < 0.0 else 1] += 1
		for f: EcoFish.Fish in sh.members:
			samples += 1
			if bones.solid(f.agent.p):
				in_bone += 1
	ok(halves[0] > 20 and halves[1] > 20, "бродит по всей клетке: %s" % [halves])
	ok(in_bone * 100 <= samples, "сквозь кость почти не плывут: %d из %d" % [in_bone, samples])
	eq(sh.alarm, 0.0, "без угроз спокойна")
	var pred := w.spawn("pred", sh.center + Vector3(6, 0, 0))
	w.run(8.0)
	ok(sh.alarm > 0.0, "хищник рядом — тревога")
	ok(_mean_to(sh, sh.home) < 4.0, "прячется в середине клетки")
	pred.alive = false


## Б3: нос `Fish.look` догоняет скорость — рывок от хищника разворачивает тело за доли секунды, а не за кадр.
func test_nose_turns_smoothly() -> void:
	var dt := 1.0 / 30.0
	near(EcoFish.turn(Vector3.ZERO, Vector3(0, 0, -2), dt).z, -1.0, 1e-6, "не плыла — нос сразу по скорости")
	var look := Vector3(1, 0, 0)
	var after := EcoFish.turn(look, Vector3(-3, 0, 0), dt)   # скорость развернулась навстречу за кадр
	near(after.length(), 1.0, 1e-5, "нос единичный")
	near(look.angle_to(after), EcoFish.LOOK_MAX * dt, 1e-4, "за кадр — не больше LOOK_MAX · dt")
	var steps := 0
	while look.angle_to(Vector3(-1, 0, 0)) > 0.05 and steps < 100:
		look = EcoFish.turn(look, Vector3(-3, 0, 0), dt)
		steps += 1
	ok(steps > 6 and steps < 30, "разворот за 0,2–1 с: %d кадров" % steps)
	eq(EcoFish.turn(look, Vector3.ZERO, dt), look, "скорости нет — держит нос")
	var w := _world()
	var fish := _fish(w)
	for i in 60:
		w.step(dt)
	var f := fish.all[0]
	ok(f.look.length_squared() > 0.9, "мир ведёт нос рыбки")
	ok(f.look.angle_to(f.agent.v) < 0.6, "нос близко к курсу")
	var fw := EcoFishLook.forward(f, 0.0)
	var flat := Vector3(f.look.x, 0, f.look.z)
	ok(flat.length() < 1e-3 or fw.angle_to(f.look) <= EcoFishLook.WIGGLE + 1e-3, "тело — по носу с вилянием")
