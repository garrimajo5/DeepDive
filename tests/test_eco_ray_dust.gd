extends TestCase
## Вихри с кончиков крыльев ледокрыла (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): скат взмыл над кораблём — клуб
## с каждого кончика; идёт над кораблём — слабые облачка раз в ~0,7 с по очереди с кончиков; прошёл — слабее взлёта;
## в обычном полёте, далеко от корабля и в «Экономно» облачков нет; облачка — у кончиков крыльев меша; скат
## действительно взмывает над кораблём на пути — и срывает облачка; в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoRay.new())
	w.step(EcoWorld.MAX_STEP)
	return w


func _rays(w: EcoWorld) -> EcoRay:
	for s in w.systems:
		if s is EcoRay:
			return s
	return null


## Облачка от t0 до t1 с шагом 1/30 (мир стоит — over правит тест).
func _run(d: EcoRayDust, r: EcoRay, t0: float, t1: float, ship: Vector3) -> float:
	var t := t0
	while t < t1 - 1e-6:
		t += 1.0 / 30.0
		d.update(r, t, ship)
	return t


func _near(r: EcoRay) -> Vector3:
	return r.rays[0].p + Vector3(0, -6, 10)


func test_kind() -> void:
	eq(EcoRayDust.kind(false, true), EcoRayDust.Kind.RISE, "взмыл над кораблём — клуб")
	eq(EcoRayDust.kind(true, true), EcoRayDust.Kind.WAKE, "идёт над кораблём — след")
	eq(EcoRayDust.kind(true, false), EcoRayDust.Kind.SETTLE, "прошёл — облачка слабее")
	eq(EcoRayDust.kind(false, false), EcoRayDust.Kind.NONE, "обычный полёт — нет")


func test_tip_matches_mesh() -> void:
	near(EcoRayDust.TIP.x, RayView.SPAN * 0.5, 1e-4, "полуразмах меша")
	near(EcoRayDust.TIP.z, -0.6 - RayView.SWEEP, 1e-4, "кончик отогнут назад, как в меше")
	var r := _rays(_world())
	var ry := r.rays[0]
	var x := EcoRay.xform(ry)
	var right := EcoRayDust.tip(ry, 1.0)
	var left := EcoRayDust.tip(ry, -1.0)
	near(right.distance_to(left), RayView.SPAN, 1e-3, "между кончиками — размах")
	ok((right - x.origin).dot(x.basis.x) > 0.0 and (left - x.origin).dot(x.basis.x) < 0.0, "правое и левое крыло")
	ok((right - x.origin).dot(x.basis.z) < 0.0, "кончики позади середины")


func test_rise_wake_settle() -> void:
	EcoGrazerDust.lite = false
	var r := _rays(_world())
	var ry := r.rays[0]
	ry.over = false
	var d := EcoRayDust.new()
	var ship := _near(r)
	d.update(r, 0.0, ship)
	var t := _run(d, r, 0.0, 5.0, ship)
	eq(d._made, 0, "обычный полёт — облачков нет")
	ry.over = true
	t = _run(d, r, t, t + 1.0 / 30.0, ship)
	eq(d._made, EcoRayDust.RISE_N * 2, "взмыл — клуб из %d с каждого кончика" % EcoRayDust.RISE_N)
	var tips: Array[Vector3] = [EcoRayDust.tip(ry, 1.0), EcoRayDust.tip(ry, -1.0)]
	var sides := [0, 0]
	for p in d.dust.puffs:
		if p.born < 0.0:
			continue
		var dr := p.at.distance_to(tips[0])
		var dl := p.at.distance_to(tips[1])
		ok(minf(dr, dl) <= EcoRayDust.SCATTER * sqrt(3.0) + 1e-3, "у кончика крыла (%.2f м)" % minf(dr, dl))
		sides[0 if dr < dl else 1] += 1
		ok(p.alpha >= EcoRayDust.RISE_ALPHA * 0.79, "клуб густой")
	eq(sides, [EcoRayDust.RISE_N, EcoRayDust.RISE_N], "поровну с обоих крыльев")
	var before := d._made
	t = _run(d, r, t, t + EcoRayDust.WAKE_EVERY * 0.7, ship)
	eq(d._made, before, "след — не сразу после взлёта")
	t = _run(d, r, t, t + 10.0, ship)
	var wake := d._made - before
	var per := 10.0 / EcoRayDust.WAKE_EVERY
	ok(wake >= int(per * 0.7) and wake <= int(per * 1.4) + 1, "след раз в ~0,7 с (%d за 10 с)" % wake)
	var weak := 0
	for p in d.dust.puffs:
		if p.born > t - 3.0 and p.alpha <= EcoRayDust.WAKE_ALPHA * 1.21:
			weak += 1
	ok(weak >= 3, "след слабый (%d)" % weak)
	before = d._made
	ry.over = false
	t = _run(d, r, t, t + 1.0 / 30.0, ship)
	eq(d._made - before, EcoRayDust.SETTLE_N * 2, "прошёл — %d с каждого кончика" % EcoRayDust.SETTLE_N)
	before = d._made
	_run(d, r, t, t + 5.0, ship)
	eq(d._made, before, "дальше обычный полёт — тихо")


func test_far_lite() -> void:
	var r := _rays(_world())
	var ry := r.rays[0]
	var d := EcoRayDust.new()
	EcoGrazerDust.lite = false
	ry.over = false
	d.update(r, 0.0, FAR)
	ry.over = true
	_run(d, r, 0.0, 4.0, FAR)
	eq(d._made, 0, "дальше 80 м облачков нет")
	ry.over = false
	_run(d, r, 4.0, 5.0, FAR)
	EcoGrazerDust.lite = true
	ry.over = true
	_run(d, r, 5.0, 9.0, _near(r))
	eq(d._made, 0, "«Экономно» — облачков нет")
	EcoGrazerDust.lite = false
	_run(d, r, 9.0, 12.0, _near(r))
	ok(d._made > 0, "выключатель вернули — облачка есть")


func test_time_back_no_burst() -> void:
	EcoGrazerDust.lite = false
	var r := _rays(_world())
	var d := EcoRayDust.new()
	r.rays[0].over = false
	d.update(r, 10.0, _near(r))
	r.rays[0].over = true
	d.update(r, 1.0, _near(r))   # время назад (новый забег) — запомнить, без облачков
	eq(d._made, 0, "сброс — без клуба взлёта")


## Корабль на круге ската: скат сам взмывает над ним — и с кончиков срываются облачка.
func test_real_pass_over_ship() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var r := _rays(w)
	var ry := r.rays[0]
	# корабль на круге первого ската, на четверть оборота впереди него
	var a := ry.ang + 0.5
	w.ship.pos = Vector3(ry.center.x + cos(a) * ry.radius, -16.0, ry.center.z + sin(a) * ry.radius)
	var d := EcoRayDust.new()
	d.update(r, w.time, w.ship.pos)
	var rose := false
	for i in 30 * 40:
		w.step(1.0 / 30.0)
		d.update(r, w.time, w.ship.pos)
		rose = rose or ry.over
	ok(rose, "скат взмыл над кораблём")
	ok(d._made >= EcoRayDust.RISE_N * 2 + EcoRayDust.SETTLE_N * 2, "облачка с кончиков (%d)" % d._made)


func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var r := _rays(_world())
		var d := EcoRayDust.new()
		r.rays[0].over = false
		d.update(r, 0.0, _near(r))
		r.rays[0].over = true
		_run(d, r, 0.0, 6.0, _near(r))
		var at: Array = []
		for p in d.dust.puffs:
			at.append(p.at)
		runs.append(at)
	eq(runs[0], runs[1], "одинаковый мир — облачка те же")


func test_view_dust_mesh() -> void:
	EcoGrazerDust.lite = false
	var view := EcoView.new()
	tree.root.add_child(view)
	await frames(1)
	var rv := view.ray_view
	ok(rv.dust_view == null and view.dust_layer.parts.has(rv._dust), "у ледокрылов — MultiMesh «Муть» — кусок общего слоя (#849)")
	eq(view.dust_layer.pools[view.dust_layer.parts.find(rv._dust)], EcoRayDust.POOL)
	eq(view.dust_layer.layers, OceanView.LAYER_WORLD)
	eq(rv.transform, Transform3D.IDENTITY, "облачка в мировых координатах")
	var mat := (view.dust_layer.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var ship := EcoLink.ShipState.new()
	var ry := view.rays.rays[0]
	ship.pos = ry.p + Vector3(0, -6, 10)
	view.step(0.05, ship)
	rv.dust.dust.add(ry.p, view.world.time, 0.4, 1, 1.2)
	view.step(0.05, ship)
	var shown := 0
	var buf := rv.dust_buffer
	for i in EcoRayDust.POOL:
		if buf[i * GrazerView.DUST_STRIDE] > 0.0:
			shown += 1
	ok(shown >= 1, "облачко у ската в буфере (%d)" % shown)
	tree.root.remove_child(view)
	view.free()
