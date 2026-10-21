extends TestCase
## Эхоловец (js/echo.js, ART-007): лежит у Костей левиафана снаружи клетки, уши по отдельности поворачиваются
## на корабль, затаившегося нет на сонаре и в прицеле, импульс сонара ближе 70 м раскрывает его на 120 с;
## в сцене — шесть вызовов отрисовки.

const FLAT := -46.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world(with_bones: bool = true) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var b: EcoBones = null
	if with_bones:
		b = w.add(EcoBones.new()) as EcoBones
	w.add(EcoEcho.new(b))
	return w


func _sys(w: EcoWorld, cls: Variant) -> Variant:
	for s in w.systems:
		if is_instance_of(s, cls):
			return s
	return null


func _notes(w: EcoWorld, note: String) -> int:
	var n := 0
	for ev in w.bus.pending:
		if ev.species == EcoEcho.ID and ev.note == note:
			n += 1
	return n


func _ping(w: EcoWorld, at: Vector3) -> Array[Dictionary]:
	w.ship.pos = at
	w.ship.sonar_ping = true
	w.ship.sonar_range = 150.0
	w.step(0.05)
	w.ship.sonar_ping = false
	return w.take_link()


func _echo_near(link: Array[Dictionary]) -> Dictionary:
	for ev in link:
		if ev["type"] == EcoLink.NEAR and ev["species"] == EcoEcho.ID:
			return ev
	return {}


# ---------- Место ----------

func test_lies_outside_cage_between_ribs() -> void:
	var w := _world()
	var b: EcoBones = _sys(w, EcoBones)
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	near(ec.p.y, FLAT + EcoEcho.UP, 1e-4, "на дне")
	var q := b.to_local(ec.p)
	ok(q.z > b.rib_z[EcoEcho.PAIR] and q.z < b.rib_z[EcoEcho.PAIR + 1], "между парами рёбер: z %.2f" % q.z)
	var foot := absf(b.rib_point(EcoEcho.PAIR * 2, 0).x)
	ok(absf(q.x) > foot + 2.0, "снаружи клетки: |x| %.2f, нога %.2f" % [absf(q.x), foot])
	ok(absf(q.x) > EcoBones.PASS_W * 0.5 + 2.0, "не в проходе корабля")
	# тело ~3 м с запасом не в кости
	for dz in [-1.6, 0.0, 1.6]:
		for dx in [-0.7, 0.0, 0.7]:
			var p := ec.xform() * Vector3(dx, 0.0, dz)
			ok(not b.solid(p), "тело не в кости: %s" % p)
	ok(ec.p.distance_to(Vector3(EcoBones.CENTER.x, FLAT, EcoBones.CENTER.y)) < 25.0, "у Костей левиафана")
	# голова — наружу от оси клетки
	var head := ec.xform().basis * Vector3.BACK
	var out := ec.p - b.to_world(Vector3(0, ec.p.y - b.base.y, q.z))
	out.y = 0.0
	ok(head.dot(out.normalized()) > 0.95, "голова наружу от клетки")


func test_without_bones_offset_from_center() -> void:
	var w := _world(false)
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	near(ec.p.x, EcoBones.CENTER.x + 14.0, 1e-4, "как в браузере: +14")
	near(ec.p.z, EcoBones.CENTER.y + 10.0, 1e-4, "+10")
	near(ec.p.y, FLAT + 0.7, 1e-4)


static func _slope(x: float, _z: float) -> float:
	return FLAT + x * 0.4


func test_on_slope_body_above_floor() -> void:
	var w := EcoWorld.new()
	w.ground = _slope
	var e := w.add(EcoEcho.new()) as EcoEcho
	var ec := e.echo
	for o in EcoEcho.BED:
		var q := ec.xform().basis * o
		var p := ec.p + q
		ok(p.y >= _slope(p.x, p.z) + EcoEcho.UP - 1e-4, "тело не в склоне: %s" % o)


func test_reset_restores() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var p := e.echo.p
	_ping(w, p + Vector3(0, 10, 30))
	w.run(5.0)
	w.reset()
	ok(not e.echo.is_revealed(), "сброс — затаился")
	near(e.echo.p.distance_to(p), 0.0, 1e-4, "на том же месте")


# ---------- Уши ----------

func test_ears_turn_to_near_ship_each_separately() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	var ship := ec.xform() * Vector3(-8.0, 6.0, 4.0)
	w.ship.pos = ship
	w.run(6.0)
	ok(ec.near, "корабль ближе 60 м — слушает")
	for i in 2:
		var to := (ship - ec.ear_base(i)).normalized()
		ok(e.ear_dir(i).dot(to) > 0.99, "ухо %d смотрит на корабль: %.3f" % [i, e.ear_dir(i).dot(to)])
	ok(absf(ec.ears[0].x - ec.ears[1].x) > 0.02, "уши повёрнуты каждое на свой угол")


func test_ear_turn_speed_limited() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var before := ec.ears[0]
	w.ship.pos = ec.xform() * Vector3(0.0, 2.0, -20.0)  # позади
	w.step(0.1)
	var d := ec.ears[0] - before
	ok(absf(d.x) <= EcoEcho.EAR_TURN * 0.1 + 1e-4, "поворот не быстрее EAR_TURN")
	ok(absf(d.y) <= EcoEcho.EAR_TURN * 0.1 + 1e-4, "наклон не быстрее EAR_TURN")


func test_ear_joint_limits() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	var a := e.aim(0, ec.xform() * Vector3(0.0, 0.0, -30.0))  # прямо позади
	ok(absf(a.x) <= EcoEcho.EAR_YAW + 1e-5, "поворот в пределах")
	var up := e.aim(0, ec.ear_base(0) + Vector3(0, 40, 0))
	near(up.y, EcoEcho.EAR_PITCH_MAX, 1e-5, "наклон вверх ограничен")


func test_far_ship_ears_idle() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	w.ship.pos = ec.p + Vector3(0, 0, EcoEcho.LISTEN_R + 5.0)
	w.run(10.0)
	ok(not ec.near, "дальше 60 м — не слушает")
	var a := ec.ears[0]
	w.run(5.0)
	ok(ec.ears[0].distance_to(a) > 0.05, "уши медленно обводят воду")


# ---------- Сонар и сканер ----------

func test_hidden_from_sonar_and_scanner() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var t := {}
	for x in w.scan_targets():
		if x["species"] == EcoEcho.ID:
			t = x
	ok(not t.is_empty(), "цель есть")
	ok(t["hidden"] and not t["sonar"], "затаился — ни сонару, ни сканеру")
	w.ship.pos = ec.p + Vector3(0, 8, 20)
	w.ship.scan_range = 80.0
	w.step(0.05)
	ok(_echo_near(w.take_link()).is_empty(), "сканер его не видит")


func test_ping_reveals_for_120s() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var link := _ping(w, ec.p + Vector3(0, 10, 50))
	ok(ec.is_revealed(), "импульс ближе 70 м — раскрыт")
	var obs := 0
	for ev in link:
		if ev["type"] == EcoLink.OBSERVE and ev["species"] == EcoEcho.ID and ev["note"] == "reveal":
			obs += 1
			eq(ev["text"], "Импульс сонара выдал засадчика с ушами-воронками: он раскрыт", "текст наблюдения")
	eq(obs, 1, "наблюдение «reveal»")
	var n := _echo_near(link)
	ok(not n.is_empty() and n["sonar"], "отметка на сонаре в том же импульсе")
	w.ship.scan_range = 80.0
	w.step(0.05)
	var s := _echo_near(w.take_link())
	ok(not s.is_empty() and s["scan"], "раскрытый — в прицеле сканера")
	_ping(w, ec.p + Vector3(0, 10, 50))
	eq(_notes(w, "reveal"), 0, "повторный импульс — без нового наблюдения")
	w.ship.scan_range = 0.0
	w.run(EcoEcho.REVEAL_T - 1.0)
	ok(ec.is_revealed(), "держится REVEAL_T от последнего импульса")
	w.run(2.0)
	ok(not ec.is_revealed(), "потом снова затаился")


func test_far_ping_does_not_reveal() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var link := _ping(w, ec.p + Vector3(0, 0, EcoEcho.REVEAL_R + 2.0))
	ok(not ec.is_revealed(), "дальше 70 м — затаился")
	ok(_echo_near(link).is_empty(), "и на сонаре его нет")


func test_reveal_text_uses_scanned_name() -> void:
	var w := _world()
	w.scanned = func(sp: String) -> bool: return sp == EcoEcho.ID
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var link := _ping(w, ec.p + Vector3(0, 10, 30))
	var txt := ""
	for ev in link:
		if ev["type"] == EcoLink.OBSERVE and ev["note"] == "reveal":
			txt = ev["text"]
	eq(txt, "Импульс сонара выдал эхоловца: он раскрыт", "изученный — по имени")


# ---------- Сцена ----------

func test_view_six_draw_calls() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var ev := view.echo_view
	ok(ev != null and ev.get_parent() == view, "эхоловец — в живом мире")
	var ec := view.echo.echo
	ok(view.bones.to_local(ec.p).z > view.bones.rib_z[EcoEcho.PAIR], "у костей сцены")
	ok(ec.p.y >= Seabed.height(ec.p.x, ec.p.z) + EcoEcho.UP - 1e-3, "на дне сцены")
	ok(ec.p.y < Seabed.height(ec.p.x, ec.p.z) + EcoEcho.UP + 1.5, "не висит над дном")
	var ship := EcoLink.ShipState.new()
	ship.pos = ec.p + Vector3(10, 8, 10)
	for i in 80:
		view.step(0.05, ship)
	ok(ev.visible, "рядом — виден")
	near(ev.group.position.distance_to(ec.p), 0.0, 1e-4, "узел на теле")
	for i in 2:
		var dir := ev.group.basis * ev.ears[i].basis * Vector3.BACK
		ok(dir.dot(view.echo.ear_dir(i)) > 0.999, "ухо %d в сцене — как в мире" % i)
	var calls := 0
	var tris := 0
	for mi in ev.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		eq(m.layers, OceanView.LAYER_WORLD, "слой отмели: %s" % m.name)
		for s in m.mesh.get_surface_count():
			calls += 1
			tris += m.mesh.surface_get_array_len(s) / 3
	eq(calls, 6, "шесть вызовов отрисовки")
	ok(tris < 2500, "треугольников: %d" % tris)
	var hush: Color = ev.fold_mat.emission
	ship.sonar_ping = true
	ship.sonar_range = 150.0
	view.step(0.05, ship)
	ship.sonar_ping = false
	var brightest := 0.0
	for i in 40:
		view.step(0.05, ship)
		brightest = maxf(brightest, ev.fold_mat.emission.b)
	ok(brightest > hush.b * 3.0, "раскрытый — складки ушей светятся ярче")
	var far_ship := EcoLink.ShipState.new()
	far_ship.pos = Vector3(300, -20, 300)
	view.step(0.05, far_ship)
	ok(not ev.visible, "далеко — спрятан")
	view.queue_free()
	await frames(1)
