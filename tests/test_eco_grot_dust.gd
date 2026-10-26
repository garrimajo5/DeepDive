extends TestCase
## Муть у дна от гротовика (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): идёт — облачко у ступни на каждом шаге,
## ноги треногой; корабль задел панцирь — ноги спрятаны, панцирь осел, кольцом у обода встаёт клуб; испуг прошёл —
## клуб слабее у ступней; дальние от корабля и «Экономно» мути не поднимают; в сцене — свой MultiMesh на общем
## шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const DT := 1.0 / 30.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	w.add(EcoGrot.new(f))
	return w


func _g(w: EcoWorld) -> EcoGrot:
	return w.systems[1] as EcoGrot


## Корабль над гротовиком, но выше рифа — не задевает.
func _watch(w: EcoWorld) -> Vector3:
	var gr := _g(w).grot
	return Vector3(gr.p.x + 20.0, gr.top + 15.0, gr.p.z)


func _run(w: EcoWorld, d: EcoGrotDust, secs: float, follow := true) -> void:
	var t := 0.0
	while t < secs - 1e-6:
		if follow:
			w.ship.pos = _watch(w)
		w.step(DT)
		d.update(_g(w), w.time, w.ship.pos)
		t += DT


func _live(d: EcoGrotDust) -> Array[EcoGrazerDust.Puff]:
	var out: Array[EcoGrazerDust.Puff] = []
	for p in d.dust.puffs:
		if p.born >= 0.0:
			out.append(p)
	return out


## Место облачка в осях гротовика (без высоты).
func _local(gr: EcoGrot.Walker, at: Vector3) -> Vector3:
	return Basis(Vector3.UP, gr.yaw).inverse() * Vector3(at.x - gr.p.x, 0.0, at.z - gr.p.z)


func test_feet_match_view() -> void:
	eq(EcoGrotDust.FOOT_Z, GrotView.LEG_Z, "ступни — под ногами GrotView")
	var tip := Basis(Vector3.BACK, GrotView.LEG_TILT) * Vector3(0, -1.1, 0)
	near(EcoGrotDust.FOOT_X, GrotView.LEG_X + tip.x, 0.1, "ступня — у конца разваленной ноги")


func test_walking_puffs_at_feet_in_tripod_order() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var gr := _g(w).grot
	var d := EcoGrotDust.new()
	w.ship.pos = _watch(w)
	d.update(_g(w), w.time, w.ship.pos)
	var sides: Array[int] = []
	var rows: Array[int] = []
	var made := 0
	var t := 0.0
	while t < 10.0:
		w.ship.pos = _watch(w)
		w.step(DT)
		d.update(_g(w), w.time, w.ship.pos)
		t += DT
		if d._made > made:
			made = d._made
			var p := d.dust.puffs[(made - 1) % EcoGrotDust.POOL]
			var l := _local(gr, p.at)
			ok(absf(absf(l.x) - EcoGrotDust.FOOT_X) <= EcoGrotDust.SCATTER + 0.05, "у ступни сбоку (%.2f)" % l.x)
			near(p.at.y, FLAT + EcoGrotDust.BASE_LIFT, 1e-4, "у дна")
			near(p.scale, EcoGrotDust.SCALE, 1e-6, "доля размера гротовика")
			ok(p.alpha <= EcoGrotDust.STEP_ALPHA * 1.21, "шаг — слабое облачко (%.2f)" % p.alpha)
			sides.append(signi(roundi(l.x)))
			var best := 0
			for k in 3:
				if absf(l.z - EcoGrotDust.FOOT_Z[k]) < absf(l.z - EcoGrotDust.FOOT_Z[best]):
					best = k
			rows.append(best)
	ok(EcoGrotDust.walking(gr), "идёт")
	ok(made >= int(10.0 / (EcoGrotDust.STEP_EVERY * 1.2)) and made <= int(10.0 / (EcoGrotDust.STEP_EVERY * 0.8)) + 1,
			"облачко раз в %.1f с (%d за 10 с)" % [EcoGrotDust.STEP_EVERY, made])
	for i in mini(sides.size(), 6):
		eq(Vector2i(sides[i], rows[i]), EcoGrotDust.STEP_ORDER[i], "нога %d — по треноге" % i)
	for i in sides.size() - 1:
		ok(sides[i] != sides[i + 1], "борта чередуются")


func test_shy_settles_shell_with_ring_then_rise() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var sys := _g(w)
	var gr := sys.grot
	var d := EcoGrotDust.new()
	w.ship.pos = _watch(w)
	d.update(sys, w.time, w.ship.pos)
	_run(w, d, 3.0)
	var before := d._made
	# корабль вплотную у панциря, ниже верха рифа — задел
	w.ship.pos = Vector3(gr.p.x + EcoGrot.R + 1.0, gr.body_y + 1.0, gr.p.z)
	w.step(DT)
	d.update(sys, w.time, w.ship.pos)
	ok(not gr.moving(), "задетый — замер")
	eq(d._made - before, EcoGrotDust.SETTLE_N, "панцирь осел — клуб из %d облачков" % EcoGrotDust.SETTLE_N)
	var sum := Vector2.ZERO
	for i in EcoGrotDust.SETTLE_N:
		var p := d.dust.puffs[(before + i) % EcoGrotDust.POOL]
		var l := _local(gr, p.at)
		var e := Vector2(l.x / EcoGrotDust.RING.x, l.z / EcoGrotDust.RING.y).length()
		ok(absf(e - 1.0) <= EcoGrotDust.RING_SCATTER + 1e-3, "кольцом у обода (%.2f)" % e)
		ok(Vector2(l.x / EcoGrot.SHELL.x, l.z / EcoGrot.SHELL.z).length() > 1.0, "снаружи панциря")
		near(p.scale, EcoGrotDust.SCALE * EcoGrotDust.BURST_SCALE, 1e-6, "клуб крупнее шага")
		ok(p.alpha > EcoGrotDust.SETTLE_ALPHA * 0.79, "клуб густой (%.2f)" % p.alpha)
		sum += Vector2(l.x, l.z).normalized()
	ok(sum.length() < EcoGrotDust.SETTLE_N * 0.5, "облачка обступают панцирь (%.2f)" % sum.length())
	var settled := d._made
	_run(w, d, EcoGrot.SHY_T - 1.0, false)
	eq(d._made, settled, "пока замер — новой мути нет")
	var guard := 0
	while not gr.moving() and guard < 90:
		_run(w, d, DT)
		guard += 1
	ok(gr.moving(), "испуг прошёл — идёт")
	ok(d._made >= settled + EcoGrotDust.RISE_N, "ноги выпущены — облачка у ступней")
	for i in EcoGrotDust.RISE_N:
		var p := d.dust.puffs[(settled + i) % EcoGrotDust.POOL]
		var l := _local(gr, p.at)
		ok(absf(absf(l.x) - EcoGrotDust.FOOT_X) <= EcoGrotDust.SCATTER + 0.1, "у ступни (%.2f)" % l.x)
		ok(p.alpha <= EcoGrotDust.RISE_ALPHA * 1.21 and p.alpha > EcoGrotDust.STEP_ALPHA, "слабее оседания, гуще шага")


func test_far_and_lite_make_no_dust() -> void:
	var w := _world()
	var sys := _g(w)
	var d := EcoGrotDust.new()
	EcoGrazerDust.lite = false
	w.ship.pos = FAR
	d.update(sys, w.time, FAR)
	_run(w, d, 5.0, false)
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	EcoGrazerDust.lite = true
	_run(w, d, 5.0)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	_run(w, d, 3.0)
	ok(d._made > 0, "выключатель вернули — муть есть")


func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var d := EcoGrotDust.new()
		w.ship.pos = _watch(w)
		d.update(_g(w), w.time, w.ship.pos)
		_run(w, d, 20.0)
		eq(d.dust.puffs.size(), EcoGrotDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_new_run_resets() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var d := EcoGrotDust.new()
	w.ship.pos = _watch(w)
	d.update(_g(w), w.time, w.ship.pos)
	_run(w, d, 3.0)
	var made := d._made
	w.reset()
	d.update(_g(w), w.time, w.ship.pos)
	eq(d._made, made, "новый забег — первый шаг только запоминает")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var sys := _g(w)
	var view := GrotView.new(sys)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть гротовика в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoGrotDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var gr := sys.grot
	var ship := Vector3(gr.p.x + 20.0, gr.top + 15.0, gr.p.z)
	var info := EcoLink.ShipState.new()
	info.pos = ship
	view.sync(0.0, ship, info)
	gr.shy = EcoGrot.SHY_T
	view.sync(0.1, ship, info)
	view.sync(0.8, ship, info)
	var seen := 0
	for n in EcoGrotDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			near(view.dust_buffer[i + 12], EcoGrotDust.COLOR.r, 1e-5, "бурый ил без луча")
	eq(seen, EcoGrotDust.SETTLE_N, "гротовик поднял муть")
	view.queue_free()
	await frames(1)
