extends TestCase
## Ледяная моль у колодца 05 (#836, часть 1): рой под льдом, ход с рывками, тяга к прожектору.


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
