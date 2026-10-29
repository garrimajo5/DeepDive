extends TestCase
## Ледяная моль у колодца 05 (#836): рой под льдом, ход с рывками, тяга к прожектору (часть 1); модуль мира и вид
## одним MultiMesh атласа ART-080 (часть 2); моль на стекле (часть 4).


func _ship(at: Vector3, yaw: float, light: bool) -> EcoLink.ShipState:
	var s := EcoLink.ShipState.new()
	s.pos = at
	s.yaw = yaw
	s.light_on = light
	s.light_range = 40.0
	return s


func _run(sw: EcoMoth.Swarm, ship: EcoLink.ShipState, secs: float) -> void:
	var t := 0.0
	while t < secs:
		sw.step(ship, 0.1)
		t += 0.1


func test_swarm_under_ice_at_well() -> void:
	var sw := EcoMoth.Swarm.new()
	eq(sw.pos.size(), EcoMoth.COUNT, "240 рачков в воде")
	eq(EcoMoth.Swarm.new(true).pos.size(), EcoMoth.COUNT_LITE, "«Экономно» — 80")
	var well := LayerMap.xz("05")
	eq(EcoMoth.WELL, well, "середина — место 05 карты")
	var bad := 0
	for p in sw.pos:
		if p.y > EcoMoth.CEIL_HIGH + 1e-4 or p.y < EcoMoth.CEIL_LOW - 1e-4 or Vector2(p.x, p.z).distance_to(well) > 20.0:
			bad += 1
	eq(bad, 0, "все под льдом у колодца")


func test_no_light_stays_in_clouds_and_moves() -> void:
	var sw := EcoMoth.Swarm.new()
	var start := sw.pos.duplicate()
	var far := _ship(Vector3(0, -20, 0), 0.0, false)
	_run(sw, far, 60.0)
	var out := 0
	var moved := 0
	for i in sw.pos.size():
		var p := sw.pos[i]
		var o := EcoMoth.cloud_center(sw.home[i])
		if Vector2(p.x - o.x, p.z - o.z).length() > EcoMoth.R + 1e-3 or p.y > EcoMoth.CEIL_HIGH + 1e-4:
			out += 1
		if p.distance_to(start[i]) > 0.05:
			moved += 1
		ok(p.distance_to(start[i]) <= EcoMoth.FAST * 60.0 + 1e-3, "не быстрее рывка")
	eq(out, 0, "без света рой держится своих облаков")
	ok(moved > sw.pos.size() / 2, "рачки шевелятся рывками: %d" % moved)


func test_searchlight_pulls_to_beam() -> void:
	# корабль в 20 м к востоку от облаков, нос на запад (yaw = π/2 — нос в −x), луч через колодец
	var ship := _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, true)
	var sw := EcoMoth.Swarm.new()
	var n0 := sw.in_beam(ship)
	ok(n0 > 0, "часть роя в луче: %d" % n0)
	var dir := EcoMoth.nose_dir(ship)
	var o := ship.pos + dir * EcoMoth.NOSE
	var lit_before := {}
	var axis0 := 0.0
	for i in sw.pos.size():
		if EcoMoth.lit(ship, sw.pos[i]):
			lit_before[i] = true
			var d := sw.pos[i] - o
			axis0 += (d - dir * d.dot(dir)).length()
	_run(sw, ship, 30.0)
	var axis1 := 0.0
	for i in lit_before:
		var d := sw.pos[i] - o
		axis1 += (d - dir * d.dot(dir)).length()
	ok(axis1 < axis0 * 0.8, "в луче моль тянется к оси: %.1f → %.1f" % [axis0, axis1])
	ok(sw.in_beam(ship) >= n0, "из луча не уходит")


func test_light_off_returns_home() -> void:
	var ship := _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, true)
	var sw := EcoMoth.Swarm.new()
	_run(sw, ship, 60.0)
	ship.light_on = false
	eq(sw.in_beam(ship), 0, "свет погас — луча нет")
	_run(sw, ship, 200.0)
	var out := 0
	for i in sw.pos.size():
		var p := sw.pos[i]
		var o := EcoMoth.cloud_center(sw.home[i])
		if Vector2(p.x - o.x, p.z - o.z).length() > EcoMoth.R + 0.05:
			out += 1
	eq(out, 0, "без света вернулись в облака")


func test_same_seed_same_swarm() -> void:
	var ship := _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, true)
	var a := EcoMoth.Swarm.new()
	var b := EcoMoth.Swarm.new()
	_run(a, ship, 10.0)
	_run(b, ship, 10.0)
	eq(a.pos, b.pos, "детерминированно — у хоста и гостя один рой")


## Часть 2: в мире рой шагает только у колодца, «Экономно» — 80 рачков, тот же случай мира.
func test_world_module_steps_only_near_well() -> void:
	var w := EcoWorld.new()
	var m := w.add(EcoMoth.new()) as EcoMoth
	var start := m.swarm.pos.duplicate()
	w.ship = _ship(Vector3(0, -20, 0), 0.0, true)
	ok(not EcoMoth.near(w.ship), "старт отмели далеко от колодца")
	w.run(10.0)
	eq(m.swarm.pos, start, "далеко — рой стоит (шаг не тратится)")
	w.ship = _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, true)
	w.run(10.0)
	ok(m.swarm.pos != start, "у колодца рой живёт")
	m.set_lite(true)
	eq(m.swarm.active, EcoMoth.COUNT_LITE, "«Экономно» — 80 рачков")
	var tail := m.swarm.pos[EcoMoth.COUNT_LITE]
	w.run(5.0)
	eq(m.swarm.pos[EcoMoth.COUNT_LITE], tail, "лишние рачки не шагают")
	w.reset()
	eq(m.swarm.active, EcoMoth.COUNT_LITE, "сброс мира помнит «Экономно»")
	eq(m.swarm.pos, EcoMoth.Swarm.new().pos, "сброс — тот же рой с начала")


## Вид: один MultiMesh атласа, у колодца — места в буфере, далеко — скрыт и не пишет; своего свечения нет.
func test_view_buffer_and_hide() -> void:
	var m := EcoMoth.new()
	m.reset(null)
	var v := MothView.new(m)
	tree.root.add_child(v)
	eq(v.cards.multimesh.instance_count, EcoMoth.COUNT + EcoMoth.GLASS, "240 + 60 на стекле одним MultiMesh")
	ok(v.material.get_shader_parameter("atlas") is Texture2D, "атлас ART-080 загружен")
	ok(not v.material.shader.code.contains("unshaded"), "моль без своего свечения — светит отражённым светом")
	ok(not v.material.shader.code.contains("EMISSION"), "и без EMISSION")
	var far := _ship(Vector3(0, -20, 0), 0.0, true)
	v.sync(far)
	ok(not v.visible, "далеко от колодца — скрыт")
	eq(v.writes, 0, "и буфер не пишется")
	var ship := _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, true)
	v.sync(ship)
	ok(v.visible, "у колодца — виден")
	eq(v.writes, 1, "буфер записан")
	var bad := 0
	for i in EcoMoth.COUNT:
		if not v.origin_at(i).is_equal_approx(m.swarm.pos[i]):
			bad += 1
	eq(bad, 0, "места рачков в буфере")
	eq(v.cards.multimesh.visible_instance_count, EcoMoth.COUNT, "240 карточек видно")
	m.set_lite(true)
	v.sync(ship)
	eq(v.cards.multimesh.visible_instance_count, EcoMoth.COUNT_LITE, "«Экономно» — 80 карточек")
	v.queue_free()
	await frames(1)


## В живом мире сцены моль есть и выключается «Экономно».
func test_in_eco_view() -> void:
	var ev := EcoView.new()
	tree.root.add_child(ev)
	ok(ev.moth != null and ev.moth_view != null, "моль в мире и в сцене")
	ok(ev.world.systems.has(ev.moth), "модуль мира подключён")
	ev.set_lite(true)
	eq(ev.moth.swarm.active, EcoMoth.COUNT_LITE, "«Экономно» из уровня графики")
	ev.set_lite(false)
	eq(ev.moth.swarm.active, EcoMoth.COUNT, "обратно — 240")
	ev.queue_free()
	await frames(1)


## Часть 4: моль из луча садится на наружное стекло — гуще у краёв, без света и на ходу слетает, вдали стекло чистое.
func test_lands_on_glass_from_beam() -> void:
	var ship := _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, true)
	var sw := EcoMoth.Swarm.new()
	_run(sw, ship, 40.0)
	ok(sw.on_glass > 20, "в луче моль садится на стекло: %d" % sw.on_glass)
	ok(sw.on_glass <= EcoMoth.GLASS, "не больше 60")
	var edge := 0
	for k in EcoMoth.GLASS:
		if sw.glass_life[k] <= 0.0:
			continue
		var g := sw.glass[k]
		ok(absf(g.x) <= EcoMoth.GLASS_HALF + 1e-4 and g.y >= EcoMoth.GLASS_Y.x - 1e-4 and g.y <= EcoMoth.GLASS_Y.y + 1e-4,
				"в пределах стекла")
		near(g.z, HullPlan.NOSE_CUT - EcoMoth.GLASS_OUT, 1e-4, "снаружи на срезе носа")
		if absf(g.x) > EcoMoth.GLASS_HALF * 0.4:
			edge += 1
	ok(edge > sw.on_glass * 0.75, "центральные 40 %% окна почти чисты: у краёв %d из %d" % [edge, sw.on_glass])
	# точка в мире — на носу корабля по курсу
	for k in EcoMoth.GLASS:
		if sw.glass_life[k] > 0.0:
			var wp := sw.glass_world(ship, k)
			var local := (wp - ship.pos).rotated(Vector3.UP, -ship.yaw)
			ok(local.is_equal_approx(sw.glass[k]), "мир ↔ оси корабля")
			ok((wp - ship.pos).dot(EcoMoth.nose_dir(ship)) > 7.0, "у носа, перед кораблём")
			break


func test_no_light_no_landing_and_leaves() -> void:
	var ship := _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, false)
	var sw := EcoMoth.Swarm.new()
	_run(sw, ship, 30.0)
	eq(sw.on_glass, 0, "без прожектора не садится")
	ship.light_on = true
	_run(sw, ship, 30.0)
	var n := sw.on_glass
	ok(n > 0, "свет — сели")
	ship.light_on = false
	_run(sw, ship, EcoMoth.STAY.y / EcoMoth.DARK_K + 1.0)
	eq(sw.on_glass, 0, "свет погас — слетели быстрее обычного")


func test_wash_off_on_speed() -> void:
	var ship := _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, true)
	var sw := EcoMoth.Swarm.new()
	_run(sw, ship, 30.0)
	var still := sw.glass_life.duplicate()
	ship.speed = 3.0
	sw.step_glass(ship, 1.0, 0)
	for k in EcoMoth.GLASS:
		if still[k] > EcoMoth.WASH_K:
			near(sw.glass_life[k], still[k] - EcoMoth.WASH_K, 1e-4, "на ходу время сидения идёт быстрее")
			return
	ok(false, "кто-то сидел на стекле")


func test_glass_lite_and_leaving_well() -> void:
	var w := EcoWorld.new()
	var m := w.add(EcoMoth.new()) as EcoMoth
	w.ship = _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, true)
	w.run(40.0)
	ok(m.swarm.on_glass > EcoMoth.GLASS_LITE, "на стекле больше 16: %d" % m.swarm.on_glass)
	m.set_lite(true)
	eq(m.swarm.on_glass, _alive(m.swarm), "счёт сходится")
	ok(m.swarm.on_glass <= EcoMoth.GLASS_LITE, "«Экономно» — не больше 16")
	w.run(20.0)
	ok(m.swarm.on_glass <= EcoMoth.GLASS_LITE, "и не садятся сверх 16")
	w.ship = _ship(Vector3(0, -20, 0), 0.0, true)
	w.run(0.5)
	eq(m.swarm.on_glass, 0, "ушли от колодца — стекло чистое")


func _alive(sw: EcoMoth.Swarm) -> int:
	var n := 0
	for k in EcoMoth.GLASS:
		if sw.glass_life[k] > 0.0:
			n += 1
	return n


func test_view_draws_glass_after_water() -> void:
	var m := EcoMoth.new()
	m.reset(null)
	var v := MothView.new(m)
	tree.root.add_child(v)
	var ship := _ship(Vector3(EcoMoth.WELL.x + 30.0, -6.0, EcoMoth.WELL.y), PI / 2.0, true)
	for i in 300:
		m.swarm.step(ship, 0.1)
	v.sync(ship)
	var n := m.swarm.on_glass
	ok(n > 0, "есть моль на стекле")
	eq(v.cards.multimesh.visible_instance_count, EcoMoth.COUNT + n, "вода + стекло")
	var k := 0
	while m.swarm.glass_life[k] <= 0.0:
		k += 1
	ok(v.origin_at(EcoMoth.COUNT).is_equal_approx(m.swarm.glass_world(ship, k)), "первая на стекле — сразу после воды")
	v.queue_free()
	await frames(1)
