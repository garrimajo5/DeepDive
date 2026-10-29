extends TestCase
## Флора отмели по ART-004, первая часть: течение мира (currentUpdate в js/creatures.js), огнецвет (места станций
## initStations; кончики гаснут от шума, сонара и разряда и разгораются) и веерники (initFans: поперёк течения,
## разворот при смене, сообщения across/turn). В сцене — один меш огнецвета и один MultiMesh веерников.


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var cur := w.add(EcoCurrent.new()) as EcoCurrent
	w.add(EcoCoral.new())
	w.add(EcoFan.new(cur))
	return w


## Только огнецвет: сообщения веерников не мешают.
func _coral_world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	w.add(EcoCoral.new())
	return w


func _sys(w: EcoWorld, cls: Variant) -> Variant:
	for s in w.systems:
		if is_instance_of(s, cls):
			return s
	return null


func _texts(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		if (e["type"] == EcoLink.MESSAGE or e["type"] == EcoLink.OBSERVE) and e["text"] != "":
			out.append(e["text"])
	return out


# ---------- Течение ----------

func test_current_matches_ship_current() -> void:
	var w := _world()
	var cur: EcoCurrent = _sys(w, EcoCurrent)
	near(cur.angle, 0.7, 1e-6, "первое направление — как у корабля")
	near(cur.vel().length(), 0.3, 1e-6, "0,3 м/с")
	var sea := Helm.SeaCurrent.new()
	for i in 4000:  # 200 с — через смену направления
		w.step(0.05)
		sea.update(0.05)
	eq(cur.index, sea.index, "сменилось вместе с течением корабля")
	eq(cur.turns, 1)
	ok(cur.vel().distance_to(sea.vel()) < 1e-4, "поток тот же, что сносит корабль")


# ---------- Огнецвет ----------

func test_coral_bushes_on_station_spots() -> void:
	var w := _world()
	var co: EcoCoral = _sys(w, EcoCoral)
	eq(co.bushes.size(), 4, "три куста — места станций огнёвок, четвёртый — в Тихой заводи (#831)")
	for b in co.bushes:
		near(b.base.y, Seabed.height(b.base.x, b.base.z), 1e-4, "куст на дне")
		near(b.glow, 1.0, 1e-6, "горит")
		ok(b.top.y - b.base.y > 3.5 and b.top.y - b.base.y < 4.7, "вершина на ~4 м")
	# у подножия лежит образец «Ветка огнецвета» (Samples, 1,6 м к востоку и 0,4 к югу)
	near(co.bushes[0].base.x + 1.6, -55.35, 0.01)
	near(co.bushes[0].base.z + 0.4, 23.24, 0.01)


func test_coral_dims_from_noise_and_relights() -> void:
	var w := _coral_world()
	var co: EcoCoral = _sys(w, EcoCoral)
	var b := co.bushes[1]
	w.ship.pos = b.top + Vector3(10, 0, 0)
	w.ship.speed = 5.0
	w.run(2.0)
	near(b.glow, EcoCoral.MIN_GLOW, 1e-6, "быстрый ход рядом — погас")
	near(co.bushes[0].glow, 1.0, 1e-6, "дальний куст горит")
	var msgs := _texts(w.take_link())
	eq(msgs.size(), 1, "одно сообщение")
	ok(msgs[0].begins_with("Огнецвет гасит огни"), msgs[0])
	w.ship.speed = 1.0
	w.run(10.0)
	ok(b.glow > 0.4 and b.glow < 0.6, "тихо — разгорается: %f" % b.glow)
	w.run(20.0)
	near(b.glow, 1.0, 1e-6, "за 25 с снова горит")
	# снова погас раньше 40 с — без повтора сообщения
	w.ship.speed = 5.0
	w.run(2.0)
	eq(_texts(w.take_link()).size(), 0, "не чаще раза в 40 с")


func test_coral_dims_from_ping_and_zap() -> void:
	var w := _coral_world()
	var co: EcoCoral = _sys(w, EcoCoral)
	var b := co.bushes[2]
	w.ship.pos = b.top + Vector3(0, 0, 25)
	w.ship.sonar_ping = true
	w.step(0.05)
	w.ship.sonar_ping = false
	ok(b.glow < 0.55 and b.glow > 0.45, "импульс сонара гасит половину")
	near(co.bushes[0].glow, 1.0, 1e-6, "дальнего сонар не трогает")
	w.take_link()
	w.ship.pos = b.top + Vector3(0, 0, 15)
	w.ship.zap = true
	w.ship.zap_radius = 20.0
	w.step(0.05)
	w.ship.zap = false
	near(b.glow, EcoCoral.MIN_GLOW, 0.01, "разряд гасит весь свет")
	ok(_texts(w.take_link()).has("Огнецвет гаснет от разряда"))


# ---------- Веерники ----------

func test_fans_by_coral_and_at_start() -> void:
	var w := _world()
	var f: EcoFan = _sys(w, EcoFan)
	var co: EcoCoral = _sys(w, EcoCoral)
	eq(f.fans.size(), EcoCoral.BASES.size() + EcoField.FANS.size() + EcoGate.FANS.size() + EcoVent.FANS.size() + 1,
		"у каждого огнецвета (с заводью 09), два у площадки 08, два у врат 07, три у курильщика 02 и один у старта")
	for i in EcoCoral.BASES.size():
		near(Vector2(f.fans[i].pos.x - co.bushes[i].base.x, f.fans[i].pos.z - co.bushes[i].base.z).length(), 7.0, 1e-3,
			"в 7 м от огнецвета")
	near(f.fans[-1].pos.x, EcoFan.START.x, 1e-6)
	near(f.fans[-1].pos.z, EcoFan.START.y, 1e-6)
	for fan in f.fans:
		near(fan.pos.y, Seabed.height(fan.pos.x, fan.pos.z) - 0.05, 1e-4, "на дне")
	var t := w.scan_targets()
	var n := 0
	for x in t:
		if x["species"] == "fan":
			n += 1
			ok(x["sonar"], "сонар видит веерник")
	eq(n, f.fans.size(), "все веерники — цели сонара и сканера")


func test_fan_stands_across_current_and_turns_after_it() -> void:
	var w := _world()
	var cur: EcoCurrent = _sys(w, EcoCurrent)
	var f: EcoFan = _sys(w, EcoFan)
	var fan := f.fans[0]
	ok(EcoFan.facing(fan).distance_to(cur.vel().normalized()) < 1e-4, "плоскость поперёк потока с начала")
	w.run(60.0)
	near(fan.yaw, cur.angle, 1e-4, "без смены течения не крутится")
	w.run(130.0)  # течение сменилось на 180-й секунде
	eq(cur.turns, 1)
	var lag := absf(wrapf(cur.target - fan.yaw, -PI, PI))
	ok(lag > 0.3, "разворачивается медленно, вслед за потоком: %f" % lag)
	w.run(120.0)
	ok(EcoFan.facing(fan).distance_to(cur.vel().normalized()) < 0.02, "снова поперёк течения")


func test_fan_messages_near_ship() -> void:
	var w := _world()
	var f: EcoFan = _sys(w, EcoFan)
	w.ship.pos = f.fans[3].top + Vector3(0, 10, 10)
	w.step(0.05)
	var m := _texts(w.take_link())
	eq(m.size(), 1)
	eq(m[0], "Кружевной веер стоит поперёк течения — по нему видно, куда несёт", "без скана — описательное имя")
	w.run(100.0)
	eq(_texts(w.take_link()).size(), 0, "не чаще раза в 150 с")
	w.run(85.0)  # смена течения на 180-й секунде, «поперёк» снова на 150-й
	var all := _texts(w.take_link())
	ok(all.has("Кружевной веер разворачивается следом за течением — оно сменилось"), str(all))
	w.scanned = func(sp: String) -> bool: return sp == "fan"
	w.run(150.0)
	ok(_texts(w.take_link()).has("Веерник стоит поперёк течения — по нему видно, куда несёт"), "изученный — Веерник")


func test_far_fans_silent() -> void:
	var w := _world()
	w.run(200.0)
	eq(_texts(w.take_link()).size(), 0, "корабль далеко — ничего не слышно")


func test_flora_does_not_shift_fish() -> void:
	var a := EcoWorld.new()
	a.ground = Seabed.height
	var fa := a.add(EcoFish.new()) as EcoFish
	var b := EcoWorld.new()
	b.ground = Seabed.height
	var fb := b.add(EcoFish.new()) as EcoFish
	var cur := b.add(EcoCurrent.new()) as EcoCurrent
	b.add(EcoCoral.new())
	b.add(EcoFan.new(cur))
	a.ship.pos = Vector3(500, 0, 500)
	b.ship.pos = Vector3(500, 0, 500)
	a.run(10.0)
	b.run(10.0)
	for i in fa.all.size():
		if not eq(fa.all[i].agent.p, fb.all[i].agent.p, "светляки те же"):
			return


# ---------- Вид огнецвета ----------

func test_coral_shape_by_concept() -> void:
	var v := EcoCoralLook.verts
	eq(EcoCoralLook.normals.size(), v.size())
	eq(EcoCoralLook.colors.size(), v.size())
	eq(EcoCoralLook.tris.size() % 3, 0)
	ok(EcoCoralLook.branch_count >= 12 and EcoCoralLook.branch_count <= 18, "12–18 ветвей: %d" % EcoCoralLook.branch_count)
	ok(EcoCoralLook.tip_count >= 8 and EcoCoralLook.tip_count <= 12, "8–12 кончиков: %d" % EcoCoralLook.tip_count)
	var top := 0.0
	for p in v:
		top = maxf(top, p.y)
	ok(top > 3.6 and top < 4.3, "высота около 4 м: %f" % top)
	ok(EcoCoralLook.tris.size() / 3 * EcoCoral.BASES.size() < 6000, "три куста — меньше 6 тыс. треугольников")
	ok(EcoCoralLook.colors.has(EcoCoralLook.TIP), "оранжевые кончики")


func test_coral_parts_face_out_by_godot_rule() -> void:
	# каждая часть замкнута сверху, её треугольники по правилу Godot смотрят внутрь: (b − a) × (c − a) от центра
	# треугольника к оси части — проверим знак объёма по кончикам и камням (замкнутые многогранники)
	var v := EcoCoralLook.verts
	var t := EcoCoralLook.tris
	var vol := 0.0
	var n := 0
	for i in range(0, t.size(), 3):
		if EcoCoralLook.parts[t[i]] == EcoCoralLook.Part.TIP:
			vol += v[t[i]].dot(v[t[i + 1]].cross(v[t[i + 2]])) / 6.0
			n += 1
	ok(n > 0)
	ok(vol < 0.0, "кончики: объём со знаком минус (%f)" % vol)


# ---------- В сцене ----------

func test_view_one_coral_mesh_and_one_fan_multimesh() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var cv := view.coral_view
	var fv := view.fan_view
	ok(cv != null and cv.get_parent() == view, "огнецвет — в живом мире")
	ok(fv != null and fv.get_parent() == view, "веерники — в живом мире")
	eq(cv.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(fv.layers, OceanView.LAYER_WORLD)
	eq(cv.mesh.get_surface_count(), 1, "все кусты — один меш")
	eq(fv.multimesh.instance_count, view.fans.fans.size(), "один MultiMesh на все веера")
	var b0 := view.coral.bushes[0]
	near(cv.verts[0].y, EcoCoralLook.transform(b0).origin.y + EcoCoralLook.verts[0].y * b0.scale, 1e-3, "куст — по дну сцены")
	near(b0.base.y, Seabed.height(b0.base.x, b0.base.z), 1e-3)

	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	view.step(0.05, ship)
	var fan := view.fans.fans[2]
	var tr := FanView.transform_at(fv.buffer, fan.index)
	ok(tr.origin.distance_to(fan.pos) < 1e-4, "веер на своём месте")
	ok((tr.basis * Vector3(0, 0, 1)).normalized().distance_to(EcoFan.facing(fan)) < 0.06, "смотрит навстречу потоку")

	var up := cv.uploads
	b0.glow = EcoCoral.MIN_GLOW
	view.step(0.05, ship)
	ok(cv.uploads > up, "свет отдан шейдеру")
	near(cv.glows[0], b0.glow, 0.01, "погасший куст")
	up = cv.uploads
	view.step(0.01, ship)
	eq(cv.uploads, up, "медленное разгорание не гоняет шейдер каждый кадр")
	view.queue_free()
	await frames(1)
