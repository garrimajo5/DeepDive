extends TestCase
## Инеевая бахрома у колодца 05 (#836, часть 5; ART-080): нити со льда тремя группами, качание, след касания корпусом —
## светится после касания и гаснет к минуте, только на задетом участке; «Экономно» — 24 нити.


func _ship(at: Vector3, yaw: float) -> EcoLink.ShipState:
	var s := EcoLink.ShipState.new()
	s.pos = at
	s.yaw = yaw
	return s


## Корабль на 20 м прямо под самой длинной нитью: верх корпуса задевает её низ.
func _under_longest(c: EcoFringe.Curtain) -> Array:
	var best := 0
	for i in c.active:
		if c.length[i] > c.length[best]:
			best = i
	var r := c.root[best]
	return [best, _ship(Vector3(r.x, -20.0, r.z - 9.0), 0.0)]


func test_strands_hang_from_ice_in_three_groups() -> void:
	var c := EcoFringe.Curtain.new()
	eq(c.root.size(), EcoFringe.COUNT, "48 нитей")
	eq(EcoFringe.Curtain.new(true).active, EcoFringe.COUNT_LITE, "«Экономно» — 24")
	eq(EcoFringe.WELL, LayerMap.xz("05"), "у колодца 05")
	var groups := [0, 0, 0]
	var bad := 0
	for i in c.root.size():
		groups[i % 3] += 1
		var flat := Vector2(c.root[i].x, c.root[i].z).distance_to(EcoFringe.WELL)
		if c.root[i].y != 0.0 or flat < EcoFringe.RING.x - 1e-3 or flat > EcoFringe.RING.y + 1e-3:
			bad += 1
		if c.length[i] < EcoFringe.LEN_MIN or c.length[i] > EcoFringe.LEN_MAX:
			bad += 1
	eq(bad, 0, "корни на льду в кольце, центр трещины открыт, длины 8–20 м")
	eq(groups, [16, 16, 16], "по 16 в группе")
	eq(c.point(3, 0.0, 12.3), c.root[3], "корень неподвижен")


func test_sway_grows_to_tip() -> void:
	var c := EcoFringe.Curtain.new()
	var tip := 0.0
	var midv := 0.0
	for k in 120:
		var t := k * 0.1
		var straight := c.root[5] + Vector3(0, -c.length[5], 0)
		tip = maxf(tip, Vector2(c.point(5, 1.0, t).x - straight.x, c.point(5, 1.0, t).z - straight.z).length())
		var half := c.root[5] + Vector3(0, -c.length[5] * 0.5, 0)
		midv = maxf(midv, Vector2(c.point(5, 0.5, t).x - half.x, c.point(5, 0.5, t).z - half.z).length())
	ok(tip > 0.25 and tip < EcoFringe.SWAY.y + EcoFringe.WAVE + 0.01, "конец качается на 0,3–0,6 м: %.2f" % tip)
	ok(midv < tip * 0.5, "середина качается меньше конца")


func test_envelope_rise_hold_fade() -> void:
	near(EcoFringe.envelope(0.15), 0.5, 1e-4, "подъём за 0,3 с")
	eq(EcoFringe.envelope(5.0), 1.0, "ровно до 10 с")
	ok(EcoFringe.envelope(30.0) > 0.2 and EcoFringe.envelope(30.0) < 0.9, "гаснет к минуте")
	ok(EcoFringe.envelope(59.0) < 0.01, "почти погас к 60 с")
	eq(EcoFringe.envelope(60.0), 0.0, "через минуту — тьма")
	eq(EcoFringe.envelope(-INF), 0.0, "незадетая не светится")
	eq(EcoFringe.envelope(INF), 0.0, "давно задетая не светится")


func test_touch_glows_then_fades() -> void:
	var c := EcoFringe.Curtain.new()
	var pair := _under_longest(c)
	var i: int = pair[0]
	var ship: EcoLink.ShipState = pair[1]
	ok(c.length[i] >= 16.0, "длинная нить достаёт до корабля на 20 м: %.1f" % c.length[i])
	eq(c.lit_count(), 0, "до касания ничего не светится")
	var t := 0.0
	while t < 2.0:
		c.step(ship, t, 0.1)
		t += 0.1
	ok(c.touches >= 1, "корпус задел нить")
	ok(c.glow(i, 1.0) > 0.99, "конец светится")
	eq(c.glow(i, 0.1), 0.0, "у льда, где корпус не был, — нет")
	ok(c.push[i].length() > 0.5, "корпус отвёл нить")
	# корабль ушёл в сторону — след держится, потом гаснет
	ship.pos += Vector3(60, 0, 0)
	while t < 30.0:
		c.step(ship, t, 0.1)
		t += 0.1
	ok(c.glow(i, 1.0) > 0.2, "через 30 с ещё светится")
	ok(c.push[i].length() < 0.01, "вернулась на место за секунды")
	while t < 63.0:
		c.step(ship, t, 0.1)
		t += 0.1
	eq(c.glow(i, 1.0), 0.0, "через минуту погасла")
	eq(c.lit_count(), 0, "след весь погас")
	var cu := c.custom(i)
	eq(cu.r, EcoFringe.FADE, "в шейдер — «давно»")


func test_new_touch_refreshes_without_blink() -> void:
	var c := EcoFringe.Curtain.new()
	var pair := _under_longest(c)
	var i: int = pair[0]
	var ship: EcoLink.ShipState = pair[1]
	c.step(ship, 0.0, 0.1)
	c.step(ship, 0.5, 0.1)
	var first := c.touches
	ship.pos += Vector3(60, 0, 0)
	c.step(ship, 25.0, 0.1)
	var dim := c.glow(i, 1.0)
	ok(dim < 0.9, "след тускнеет: %.2f" % dim)
	ship.pos -= Vector3(60, 0, 0)
	c.step(ship, 25.1, 0.1)
	ok(c.glow(i, 1.0) > 0.99, "новое касание обновляет след сразу, без мигания")
	eq(c.touches, first, "это то же касание, не новое")


func test_far_ship_does_not_touch_and_world_skips() -> void:
	var c := EcoFringe.Curtain.new()
	c.step(_ship(Vector3(EcoFringe.WELL.x, -20.0, EcoFringe.WELL.y + 40.0), 0.0), 1.0, 0.1)
	eq(c.touches, 0, "вне занавеса не задевает")
	var deep := EcoFringe.Curtain.new()
	var r := deep.root[0]
	deep.step(_ship(Vector3(r.x, -45.0, r.z), 0.0), 1.0, 0.1)
	eq(deep.touches, 0, "глубже нитей не задевает")
	var f := EcoFringe.new()
	var w := EcoWorld.new()
	f.reset(w)
	w.ship = _ship(Vector3(0, -20, 0), 0.0)
	ok(not EcoFringe.near(w.ship), "далеко от колодца")
	f.step(w, 0.1)
	eq(f.curtain.time, 0.0, "вдали не шагает")


func test_in_eco_view() -> void:
	var ev := EcoView.new()
	tree.root.add_child(ev)
	ok(ev.fringe != null and ev.world.systems.has(ev.fringe), "бахрома в мире")
	ev.set_lite(true)
	eq(ev.fringe.curtain.active, EcoFringe.COUNT_LITE, "«Экономно» из уровня графики")
	ev.set_lite(false)
	eq(ev.fringe.curtain.active, EcoFringe.COUNT, "обратно — 48")
	ev.queue_free()
	await frames(1)
