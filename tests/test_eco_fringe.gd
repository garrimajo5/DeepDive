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


## Задетая нить отходит от корпуса за доли секунды, а не прыгает концом на PUSH (1,2 м) за кадр.
func test_push_eases_away_from_hull() -> void:
	var c := EcoFringe.Curtain.new()
	var pair := _under_longest(c)
	var i: int = pair[0]
	var ship: EcoLink.ShipState = pair[1]
	var dt := 1.0 / 30.0
	var t := 0.0
	var prev := c.push[i]
	var jump := 0.0
	var peak := 0.0
	var touched_at := -1.0
	while t < 3.0:
		c.step(ship, t, dt)
		if touched_at < 0.0 and c.touches > 0:
			touched_at = t
		jump = maxf(jump, c.push[i].distance_to(prev))
		peak = maxf(peak, c.push[i].length())
		prev = c.push[i]
		t += dt
	ok(touched_at >= 0.0, "корпус задел нить")
	ok(jump < 0.25, "конец за кадр сдвигается меньше 0,25 м: %.2f" % jump)
	ok(peak > 0.6, "но отходит заметно: %.2f м" % peak)


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


## Коробка корпуса (EcoHull.box) содержит каждую точку, которая касается корпуса: отсечка по ней ничего не теряет.
func test_hull_box_holds_every_touching_point() -> void:
	var rng := EcoRandom.new(1174)
	var b := EcoHull.box(EcoFringe.TOUCH_R)
	var hit := 0
	var lost := 0
	for n in 4000:
		var l := Vector3(rng.range_f(-12.0, 12.0), rng.range_f(-10.0, 10.0), rng.range_f(-20.0, 34.0))
		if EcoHull.touches(l, Vector3.ZERO, 0.0, EcoFringe.TOUCH_R):
			hit += 1
			if not b.has_point(l):
				lost += 1
	ok(hit > 300, "точки у корпуса нашлись: %d" % hit)
	eq(lost, 0, "ни одна касающаяся точка не лежит вне коробки")


## Нити касаются так же, как при проверке каждой точки каждой нити (как до #1174): корабль проходит сквозь бахрому.
func test_box_cut_keeps_touches() -> void:
	var c := EcoFringe.Curtain.new()
	var ref := EcoFringe.Curtain.new()
	var t := 0.0
	for n in 300:
		t += 0.05
		var s := _ship(Vector3(-200.0 + n * 0.2, -12.0, -72.0 + sin(n * 0.03) * 6.0), deg_to_rad(90.0))
		c.step(s, t, 0.05)
		_brute_step(ref, s, t, 0.05)
	ok(ref.touches > 5, "бахрома задета: %d" % ref.touches)
	eq(c.touches, ref.touches, "касаний столько же")
	eq(c.touched, ref.touched, "время касаний то же")
	eq(c.mid, ref.mid, "участки следа те же")
	eq(c.half, ref.half, "ширина следа та же")


## У Светового колодца 05, как в кадре тестера 32o-mol-steklo (корабль в 20 м восточнее, носом к колодцу), шаг
## бахромы проверяет детали корпуса реже: без отсечки коробкой — ~400 проверок за шаг (issue #1174).
func test_well_step_checks_few_parts() -> void:
	var c := EcoFringe.Curtain.new()
	var s := _ship(Vector3(-150.0, -14.0, -72.0), deg_to_rad(90.0))
	EcoHull.checks = 0
	for n in 100:
		c.step(s, n * 0.033, 0.033)
	var per := EcoHull.checks / 100.0
	ok(per < 200.0, "проверок деталей за шаг: %.0f" % per)


## Шаг нитей по-старому: каждая точка каждой близкой нити — EcoHull.touches.
func _brute_step(c: EcoFringe.Curtain, ship: EcoLink.ShipState, t: float, dt: float) -> void:
	c.time = t
	var back := exp(-dt / EcoFringe.RETURN)
	var follow := 1.0 - exp(-dt / EcoFringe.PUSH_IN)
	for i in c.active:
		c.push_goal[i] *= back
		c.push[i] = c.push[i].lerp(c.push_goal[i], follow)
		var lo := 2.0
		var hi := -1.0
		for k in EcoFringe.SAMPLES:
			var v := float(k) / (EcoFringe.SAMPLES - 1)
			if EcoHull.touches(c.point(i, v, t), ship.pos, ship.yaw, EcoFringe.TOUCH_R):
				lo = minf(lo, v)
				hi = maxf(hi, v)
		if hi >= 0.0:
			c._touch(i, lo, hi, ship, t)


## Вид (часть 6): один MultiMesh пряди, буфер и uniform дают ту же нить, что мир (двойник шейдера), след — тот же.
func test_view_matches_world_strands() -> void:
	var f := EcoFringe.new()
	f.reset(null)
	var v := FringeView.new(f)
	tree.root.add_child(v)
	var c := f.curtain
	v.sync(_ship(Vector3(0, -20, 0), 0.0), 0.0)
	ok(not v.visible, "далеко от колодца — скрыт")
	eq(v.writes, 0, "и буфер не пишется")
	var pair := _under_longest(c)
	var i: int = pair[0]
	var ship: EcoLink.ShipState = pair[1]
	var t := 0.0
	while t < 2.0:
		c.step(ship, t, 0.1)
		t += 0.1
	v.sync(ship, t)
	ok(v.visible, "у колодца — виден")
	eq(v.strands.multimesh.visible_instance_count, EcoFringe.COUNT, "48 нитей одним MultiMesh")
	var worst := 0.0
	for n in c.active:
		for k in 5:
			var vv := k / 4.0
			worst = maxf(worst, v.strand_point(n, vv, t).distance_to(c.point(n, vv, t)))
	ok(worst < 1e-4, "нить в шейдере — там же, где в мире (качание, волна, отвод): %.6f м" % worst)
	ok(c.push[i].length() > 0.3, "отвод корпусом — в буфере")
	ok(v.glow_at(i, 1.0) > 0.99, "след у конца задетой нити светится")
	ok(absf(v.glow_at(i, 1.0) - c.glow(i, 1.0)) < 1e-4, "как в мире")
	eq(v.glow_at(i, 0.05), 0.0, "у льда — нет")
	var other := (i + 1) % c.active
	eq(v.glow_at(other, 1.0), 0.0, "незадетая нить не светится")
	v.queue_free()
	await frames(1)


## Бюджет листа ART-080: прядь — две полосы по 8 сегментов (32 треуг., 48 нитей — 1536), «Экономно» — одна полоса
## и 24 нити (384); тени выключены, тело со светом, свечение — общий приём eco_bio.
func test_view_budget_and_lite() -> void:
	var f := EcoFringe.new()
	f.reset(null)
	var v := FringeView.new(f)
	tree.root.add_child(v)
	var tris := func(m: Mesh) -> int: return m.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	eq(tris.call(v.mesh_full), 32, "прядь — 32 треугольника")
	eq(tris.call(v.mesh_lite), 16, "«Экономно» — одна полоса, 16")
	eq(v.strands.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без теней")
	var code := v.material.shader.code
	ok(not code.contains("unshaded"), "тело освещается")
	ok(code.contains("EMISSION = eco_bio("), "след светит через общий приём свечения")
	f.set_lite(true)
	v.set_lite(true)
	v.sync(_ship(Vector3(EcoFringe.WELL.x, -20.0, EcoFringe.WELL.y), 0.0), 1.0)
	eq(v.strands.multimesh.visible_instance_count, EcoFringe.COUNT_LITE, "«Экономно» — 24 нити")
	eq(v.strands.multimesh.mesh, v.mesh_lite, "по одной полосе")
	eq(EcoFringe.COUNT_LITE * tris.call(v.mesh_lite), 384, "384 треугольника")
	v.queue_free()
	await frames(1)


## В живом мире сцены вид бахромы есть и берёт «Экономно» вместе с миром.
func test_view_in_eco_view() -> void:
	var ev := EcoView.new()
	tree.root.add_child(ev)
	ok(ev.fringe_view != null and ev.fringe_view.get_parent() == ev, "вид бахромы в живом мире")
	ev.set_lite(true)
	eq(ev.fringe_view.strands.multimesh.mesh, ev.fringe_view.mesh_lite, "«Экономно» — одна полоса")
	ev.set_lite(false)
	eq(ev.fringe_view.strands.multimesh.mesh, ev.fringe_view.mesh_full, "обратно — две")
	ev.queue_free()
	await frames(1)


## Карты пряди ART-083 (#922): материал берёт цвет, маску следа и нормали; силуэт — в альфе (узлы шире стебля),
## маска ярче на узлах, чем на стебле между ними; конец тает; карты сжаты для видеокарты (нормали — режимом нормалей).
func test_view_uses_art083_maps() -> void:
	var f := EcoFringe.new()
	f.reset(null)
	var v := FringeView.new(f)
	var mat := v.material
	for key in ["map_color", "map_glow", "map_normal"]:
		ok(mat.get_shader_parameter(key) is Texture2D, "карта %s в материале" % key)
	var code := mat.shader.code
	ok(code.contains("NORMAL_MAP ="), "рельеф узлов и щели — картой нормалей")
	ok(code.contains("ALPHA = tex.a"), "силуэт пряди — альфа карты")
	ok(not code.contains("node_at"), "процедурных узлов больше нет")
	var col := Image.load_from_file(ProjectSettings.globalize_path(FringeView.MAP_COLOR))
	var glow := Image.load_from_file(ProjectSettings.globalize_path(FringeView.MAP_GLOW))
	eq(col.get_size(), Vector2i(256, 1024), "цвет 256×1024")
	eq(glow.get_size(), Vector2i(256, 1024), "маска того же размера")
	var wide := func(y: int) -> int:
		var n := 0
		for x in 256:
			if col.get_pixel(x, y).a > 0.1:
				n += 1
		return n
	var stem := 1024
	for k in FringeView.NODES.size() - 1:
		var mid := int((FringeView.NODES[k] + FringeView.NODES[k + 1]) * 512.0)
		stem = mini(stem, wide.call(mid))
	for vv in FringeView.NODES.slice(0, 6):
		var y := int(vv * 1024.0)
		ok(wide.call(y) > stem * 1.5, "узел на %.2f шире стебля (%d > %d)" % [vv, wide.call(y), stem])
		ok(glow.get_pixel(128 + 40, y).r > glow.get_pixel(128 + 40, int((vv + 0.04) * 1024.0)).r or
				glow.get_pixel(128, y).r >= 0.9, "маска ярче на узле %.2f" % vv)
	ok(stem * FringeView.SPAN / 256.0 * FringeView.WIDTH > 0.02, "стебель в мире не тоньше 2 см")
	eq(col.get_pixel(128, 1023).a < 0.5, true, "конец пряди тает")
	for m in [FringeView.MAP_COLOR, FringeView.MAP_GLOW, FringeView.MAP_NORMAL]:
		var cfg := ConfigFile.new()
		cfg.load(m + ".import")
		eq(int(cfg.get_value("params", "compress/mode")), 2, "%s сжата для видеокарты" % m)
	var cfg_n := ConfigFile.new()
	cfg_n.load(FringeView.MAP_NORMAL + ".import")
	eq(int(cfg_n.get_value("params", "compress/normal_map")), 1, "нормали — режимом нормалей")
	v.free()
