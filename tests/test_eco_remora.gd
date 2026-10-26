extends TestCase
## Присоски (initRemoras/remorasUpdate/remorasZap в js/creatures.js): по три на ледокрыле, перебираются на корпус,
## тормозят корабль (EcoLink.DRAG), стеклоуст не садится на корпус с прилипалами, разряд сбрасывает их.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Все события шины мира (take_link их забирает из pending, поэтому слушаем сигнал).
var _heard: Array[EcoBus.Event] = []


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	_heard = []
	var heard := _heard
	w.bus.emitted.connect(func(ev: EcoBus.Event) -> void: heard.append(ev))
	w.ground = _flat
	w.ship.pos = FAR
	var r := w.add(EcoRay.new()) as EcoRay
	w.add(EcoRemora.new(r))
	return w


func _rays(w: EcoWorld) -> EcoRay:
	for s in w.systems:
		if s is EcoRay:
			return s
	return null


func _remoras(w: EcoWorld) -> EcoRemora:
	for s in w.systems:
		if s is EcoRemora:
			return s
	return null


func _notes(w: EcoWorld, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in (_heard if not _heard.is_empty() else w.bus.pending):
		if ev.species == EcoRemora.ID and ev.note == note:
			out.append(ev)
	return out


func _drags(events: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["type"] == EcoLink.DRAG:
			out.append(e)
	return out


## Корабль идёт под первым скатом (на 9 м ниже): скат проходит поверху, прилипалы рядом. seconds — сколько.
func _follow_ray(w: EcoWorld, seconds: float) -> Array[Dictionary]:
	var ry := _rays(w).rays[0]
	var events: Array[Dictionary] = []
	for i in int(round(seconds / 0.05)):
		w.ship.pos = Vector3(ry.p.x, -20.0, ry.p.z)
		w.ship.yaw = 0.3
		w.step(0.05)
		events.append_array(w.take_link())
	return events


func _count(w: EcoWorld, m: EcoRemora.Mode) -> int:
	var n := 0
	for rm in _remoras(w).remoras:
		if rm.mode == m:
			n += 1
	return n


# ---------- На скатах ----------

func test_three_on_each_ray() -> void:
	var w := _world()
	var rm := _remoras(w)
	eq(rm.remoras.size(), EcoRemora.PER_RAY * 2, "по три на каждом из двух скатов")
	w.run(5.0)
	for r in rm.remoras:
		eq(r.mode, EcoRemora.Mode.RAY, "корабль далеко — катаются")
		var local := EcoRay.xform(r.ray).affine_inverse() * r.p
		near(local.distance_to(EcoRemora.ON_RAY[r.spot]), 0.0, 1e-3, "сидят на своём месте спины")
		near(r.dir.dot(r.ray.dir), 1.0, 1e-4, "смотрят по курсу ската")
	eq(rm.on_hull, 0)
	eq(_drags(w.take_link()).size(), 0, "никто не тормозит")


func test_spots_sit_on_ray_back() -> void:
	# места на спине — над горбом меша RayView, не глубже 0,2 м над ним и не внутри
	var view := RayView.new(EcoRay.new())
	var body := (RayView.CELLS_X + 1) * (RayView.CELLS_Z + 1)   # вершины пластины тела идут первыми
	for o in EcoRemora.ON_RAY:
		var top := -INF
		for i in body:
			var v := view.verts[i]
			if Vector2(v.x - o.x, v.z - o.z).length() < 0.6:
				top = maxf(top, v.y)
		ok(o.y > top, "над спиной")
		ok(o.y - top < 0.2, "у самой спины (%.2f м)" % (o.y - top))
	view.free()


func test_hull_slots_outside_near_skin() -> void:
	for p in EcoRemora.SLOTS:
		ok(not EcoHull.touches(p, Vector3.ZERO, 0.0, 0.0), "место %s снаружи корпуса" % p)
		ok(EcoHull.touches(p, Vector3.ZERO, 0.0, 0.2), "место %s у обшивки (ближе 0,2 м)" % p)


# ---------- На корпус ----------

func test_hop_to_hull_and_drag() -> void:
	var w := _world()
	var events := _follow_ray(w, 12.0)
	var rm := _remoras(w)
	eq(rm.on_hull, EcoRemora.PER_RAY, "все три с ближнего ската на корпусе")
	for r in rm.remoras:
		if r.mode == EcoRemora.Mode.HULL:
			near(r.p.distance_to(EcoRemora.hull_point(w.ship, r.slot)), 0.0, 1e-4, "держится за своё место")
			near(r.dir.dot(w.ship.nose()), 1.0, 1e-4, "смотрит по носу")
	var slots := {}
	for r in rm.remoras:
		if r.slot >= 0:
			slots[r.slot] = true
	eq(slots.size(), EcoRemora.PER_RAY, "у каждой своё место")
	eq(_notes(w, "hop").size(), EcoRemora.PER_RAY, "hop на каждую")
	ok(_notes(w, "hop")[0].text().contains("на корпус корабля"), "первая — с текстом")
	eq(_notes(w, "hop")[1].text(), "", "остальные — без текста")
	eq(_notes(w, "drag").size(), 1, "третья — «корабль идёт тяжелее»")
	ok(_notes(w, "drag")[0].text().contains("тяжелее"))
	var d := _drags(events)
	ok(d.size() > 0)
	var last: Dictionary = d[-1]
	eq(last["count"], 3)
	near(last["k"], EcoRemora.DRAG * 3.0, 1e-6, "+0,025 к сопротивлению за каждую")
	eq(last["by"], "Присоска")


func test_one_drag_event_per_step() -> void:
	var w := _world()
	_follow_ray(w, 12.0)
	w.step(0.2)   # четыре подшага — одно событие
	eq(_drags(w.take_link()).size(), 1)


func test_hops_one_at_a_time() -> void:
	var w := _world()
	var ry := _rays(w).rays[0]
	w.ship.pos = Vector3(ry.p.x, -20.0, ry.p.z)
	w.step(0.05)
	eq(_count(w, EcoRemora.Mode.SWIM), 1, "одна поплыла")
	for i in 20:   # 1 с — меньше паузы 1,5 с
		w.ship.pos = Vector3(ry.p.x, -20.0, ry.p.z)
		w.step(0.05)
	ok(_count(w, EcoRemora.Mode.SWIM) + _count(w, EcoRemora.Mode.HULL) == 1, "вторая ждёт 1,5 с")


func test_ship_far_no_hop() -> void:
	var w := _world()
	var ry := _rays(w).rays[0]
	for i in 200:
		w.ship.pos = ry.p + Vector3(0, -20.0, 0)   # 20 м под скатом — дальше 16 м
		w.step(0.05)
	eq(_count(w, EcoRemora.Mode.RAY), 6, "все на скатах")


func test_ride_note_near_ray() -> void:
	var w := _world()
	var ry := _rays(w).rays[0]
	w.ship.pos = ry.p + Vector3(30, 0, 0)
	w.step(0.05)
	eq(_notes(w, "ride").size(), 1, "скат с прилипалами ближе 40 м")
	ok(_notes(w, "ride")[0].text().begins_with("На спине"), _notes(w, "ride")[0].text())
	ok(_notes(w, "ride")[0].text().contains("рыбы-прилипалы"), "до сканирования — описательно")
	for i in 40:
		w.ship.pos = ry.p + Vector3(30, 0, 0)
		w.step(0.05)
	eq(_notes(w, "ride").size(), 1, "не чаще раза в 2 мин")


func test_scanned_names_in_text() -> void:
	var w := _world()
	w.scanned = func(sp: String) -> bool: return sp == EcoRemora.ID
	var ry := _rays(w).rays[0]
	w.ship.pos = ry.p + Vector3(30, 0, 0)
	w.step(0.05)
	ok(_notes(w, "ride")[0].text().ends_with("катаются присоски"), _notes(w, "ride")[0].text())


# ---------- Разряд ----------

func test_zap_shakes_off_to_ray() -> void:
	var w := _world()
	_follow_ray(w, 12.0)
	var rm := _remoras(w)
	eq(rm.on_hull, 3)
	w.ship.zap = true
	w.step(0.05)
	w.ship.zap = false
	eq(rm.on_hull, 0, "сброшены")
	eq(_notes(w, "zap").size(), 1)
	ok(_notes(w, "zap")[0].text().begins_with("Разряд сбросил"), _notes(w, "zap")[0].text())
	eq(_drags(w.take_link()).size(), 0, "тормоз снят в тот же шаг")
	for r in rm.remoras:
		ok(r.slot < 0, "без места на корпусе")
	# уплывают к скату, минуту не возвращаются (корабль всё ещё под ним)
	_follow_ray(w, 30.0)
	eq(_count(w, EcoRemora.Mode.RAY), 6, "вернулись на скатов")
	eq(rm.on_hull, 0, "минуту не перебираются")
	_follow_ray(w, 40.0)
	ok(rm.on_hull > 0, "через минуту — снова на корпусе")


func test_zap_without_remoras_is_quiet() -> void:
	var w := _world()
	w.ship.zap = true
	w.step(0.05)
	eq(_notes(w, "zap").size(), 0)


# ---------- Стеклоуст ----------

func test_eel_does_not_latch_over_remoras() -> void:
	var lair := Vector3(0, FLAT, 0)
	var w := EcoWorld.new()
	w.ground = _flat
	var eels := w.add(EcoEel.new(null, null, [lair] as Array[Vector3])) as EcoEel
	var r := w.add(EcoRay.new()) as EcoRay
	var rms := w.add(EcoRemora.new(r)) as EcoRemora
	eels.remoras = rms
	var e := eels.eels[0]
	e.cd = 0.0
	w.ship.yaw = PI
	w.ship.pos = e.lair + Vector3(0, 6, -15) - EcoEel.FRONT.rotated(Vector3.UP, PI)
	var one := rms.remoras[0]
	one.mode = EcoRemora.Mode.HULL
	one.slot = 0
	for i in 600:   # 30 с: без прилипал присосался бы за пару секунд
		w.step(0.05)
		if one.mode != EcoRemora.Mode.HULL:
			break
	eq(one.mode, EcoRemora.Mode.HULL, "прилипала держится")
	ok(eels.latched == null, "стеклоуст не сел на корпус")
	var notes: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == EcoRemora.ID and ev.note == "eel":
			notes.append(ev)
	eq(notes.size(), 1, "«eel» — раз в 40 с")
	ok(notes[0].text().contains("не сел на корпус"), notes[0].text())


func test_eel_latches_without_remoras() -> void:
	# та же сцена без прилипал на корпусе — стеклоуст присасывается
	var lair := Vector3(0, FLAT, 0)
	var w := EcoWorld.new()
	w.ground = _flat
	var eels := w.add(EcoEel.new(null, null, [lair] as Array[Vector3])) as EcoEel
	var r := w.add(EcoRay.new()) as EcoRay
	eels.remoras = w.add(EcoRemora.new(r)) as EcoRemora
	var e := eels.eels[0]
	e.cd = 0.0
	w.ship.yaw = PI
	w.ship.pos = e.lair + Vector3(0, 6, -15) - EcoEel.FRONT.rotated(Vector3.UP, PI)
	for i in 600:
		w.step(0.05)
		if eels.latched:
			break
	ok(eels.latched != null, "присосался")


# ---------- Сонар, сканер, детерминизм ----------

func test_scanner_only() -> void:
	var w := _world()
	var found := 0
	for t in w.scan_targets():
		if t["species"] == EcoRemora.ID:
			found += 1
			ok(not t["sonar"], "сонар не видит")
			near(t["r"], EcoRemora.TARGET_R, 1e-6)
	eq(found, 6)


func test_same_seed_same_story() -> void:
	var a := _world()
	var b := _world()
	_follow_ray(a, 8.0)
	_follow_ray(b, 8.0)
	for i in 6:
		near(_remoras(a).remoras[i].p.distance_to(_remoras(b).remoras[i].p), 0.0, 1e-5)
	a.reset()
	eq(_remoras(a).on_hull, 0, "сброс — все снова на скатах")
	eq(_count(a, EcoRemora.Mode.RAY), 6)


func test_no_rays_no_remoras() -> void:
	var w := EcoWorld.new()
	var rm := w.add(EcoRemora.new()) as EcoRemora
	w.run(1.0)
	eq(rm.remoras.size(), 0)


# ---------- Сцена ----------

func test_view_one_multimesh() -> void:
	var w := _world()
	var view := RemoraView.new(_remoras(w))
	tree.root.add_child(view)
	await frames(1)
	eq(view.multimesh.instance_count, 6, "шесть прилипал — один MultiMesh")
	ok(view.tris > 0 and view.tris < 200, "меш рыбы маленький (%d треуг.)" % view.tris)
	eq(view.layers, OceanView.LAYER_WORLD)
	_follow_ray(w, 12.0)
	view.sync(w.time)
	for i in 6:
		near(view.placed[i].origin.distance_to(_remoras(w).remoras[i].p), 0.0, 1e-5, "на месте рыбы")
		near(view.placed[i].basis.z.length(), RemoraView.SCALE * RemoraView.remora_scale(_remoras(w).remoras[i].index), 1e-4,
			"масштаб 1,6 с разбросом особи")
	view.queue_free()
	await frames(1)


func test_mesh_faces_outward() -> void:
	var view := RemoraView.new(EcoRemora.new())
	var arr := view.multimesh.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bad := 0
	eq(view.mids.size(), v.size() / 3)
	for i in range(0, v.size(), 3):
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		var n := (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
		if n.dot(c - view.mids[i / 3]) > 0.0:
			bad += 1
	eq(bad, 0, "лицевая — по часовой снаружи: (b − a) × (c − a) внутрь")
	view.free()


func test_eco_view_has_remoras() -> void:
	var ev := EcoView.new()
	ok(ev.remoras != null and ev.remora_view != null)
	ok(ev.eels.remoras == ev.remoras, "стеклоуст знает о прилипалах")
	eq(ev.remoras.remoras.size(), 6)
	ev.free()


# ---------- Поворот носа ----------

func test_turn_is_rate_limited() -> void:
	var d := Vector3.BACK
	var lim := EcoRemora.TURN_MAX * 0.05 + 1e-4
	for i in 40:
		var n := EcoRemora.turn(d, Vector3.FORWARD, 0.05)
		near(n.length(), 1.0, 1e-4, "нос — единичный")
		ok(d.angle_to(n) <= lim, "за шаг не больше %.2f рад (%.3f)" % [lim, d.angle_to(n)])
		d = n
	near(d.dot(Vector3.FORWARD), 1.0, 1e-3, "за 2 с развернулась кругом")
	near(EcoRemora.turn(Vector3.BACK, Vector3.BACK * 3.0, 0.05).dot(Vector3.BACK), 1.0, 1e-6, "по курсу — как есть")


## Нос за шаг — не больше TURN_MAX · dt плюс поворот носителя (скат за шаг поворачивает мало).
func _check_turns(w: EcoWorld, seconds: float, prev: Array[Vector3]) -> int:
	var rm := _remoras(w)
	var ry := _rays(w).rays[0]
	var lim := EcoRemora.TURN_MAX * 0.05 + 0.03
	var bad := 0
	for i in int(round(seconds / 0.05)):
		w.ship.pos = Vector3(ry.p.x, -20.0, ry.p.z)
		w.ship.yaw = 0.3
		w.step(0.05)
		for k in rm.remoras.size():
			if rm.remoras[k].dir.angle_to(prev[k]) > lim:
				bad += 1
			prev[k] = rm.remoras[k].dir
	return bad


func test_nose_turns_smoothly_hop_and_zap() -> void:
	var w := _world()
	var rm := _remoras(w)
	var prev: Array[Vector3] = []
	for r in rm.remoras:
		prev.append(r.dir)
	eq(_check_turns(w, 12.0, prev), 0, "перебираясь на корпус, нос не щёлкает")
	eq(rm.on_hull, 3)
	w.ship.zap = true
	eq(_check_turns(w, 0.05, prev), 0, "разряд не щёлкает носом")
	w.ship.zap = false
	eq(_check_turns(w, 30.0, prev), 0, "обратно на ската — тоже плавно")
	eq(_count(w, EcoRemora.Mode.RAY), 6)
	for r in rm.remoras:
		near(r.dir.dot(r.ray.dir), 1.0, 1e-3, "на скате снова смотрит по его курсу")


func test_hull_rider_turns_with_ship() -> void:
	var w := _world()
	_follow_ray(w, 12.0)
	var rm := _remoras(w)
	eq(rm.on_hull, 3)
	# корабль разом повернул на 0,6 рад: сидящие на корпусе — вместе с ним, без отставания
	w.ship.yaw = 0.9
	w.step(0.05)
	for r in rm.remoras:
		if r.mode == EcoRemora.Mode.HULL:
			near(r.dir.dot(w.ship.nose()), 1.0, 1e-4, "нос по носу корабля сразу")
