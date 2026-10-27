extends TestCase
## Облачка у веерника огнёвок (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): станция пустует — рачки обирают
## кружево, облачко раз в ~1,2 с; хищник пришёл на чистку — клуб с веера, ушёл — рачки вернулись, облачка слабее;
## станция без веерника, дальний корабль и «Экономно» облачков не дают; облачка — на плоскости веера под вершиной;
## в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Мир: светляки, серпохвосты, станция у (0, 0), веерник в 7 м (with_fan) — шагнул раз, чтобы всё встало.
func _world(with_fan := true) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var fish := w.add(EcoFish.new()) as EcoFish
	var ps := w.add(EcoPred.new(fish)) as EcoPred
	var tops: Array[Vector3] = [Vector3(0, FLAT + EcoLeech.TOP, 0)]
	var lc := w.add(EcoLeech.new(ps, null, tops)) as EcoLeech
	var fans: EcoFan = null
	if with_fan:
		var cur := w.add(EcoCurrent.new()) as EcoCurrent
		var spots: Array[Vector2] = [Vector2(7, 0)]
		fans = w.add(EcoFan.new(cur, spots)) as EcoFan
	w.add(EcoOgnevka.new(lc, fans))
	w.step(EcoWorld.MAX_STEP)
	return w


func _og(w: EcoWorld) -> EcoOgnevka:
	for s in w.systems:
		if s is EcoOgnevka:
			return s
	return null


## Облачка dust от t0 до t1 с шагом 1/30 (мир стоит — станцией правит тест); ship — корабль.
func _run(d: EcoOgnevkaDust, og: EcoOgnevka, t0: float, t1: float, ship: Vector3) -> float:
	var t := t0
	while t < t1 - 1e-6:
		t += 1.0 / 30.0
		d.update(og, t, ship)
	return t


func _near(og: EcoOgnevka) -> Vector3:
	return og.fan_at(og.leeches.stations[0]).top + Vector3(0, 4, 15)


func test_kind() -> void:
	eq(EcoOgnevkaDust.kind(true, true, true), EcoOgnevkaDust.Kind.PICK, "кормятся — облачка кормёжки")
	eq(EcoOgnevkaDust.kind(true, false, true), EcoOgnevkaDust.Kind.LEAVE, "снялись с веера — клуб")
	eq(EcoOgnevkaDust.kind(false, true, true), EcoOgnevkaDust.Kind.LAND, "вернулись — облачка")
	eq(EcoOgnevkaDust.kind(false, false, true), EcoOgnevkaDust.Kind.NONE, "на хищнике — у веера нет")
	eq(EcoOgnevkaDust.kind(true, true, false), EcoOgnevkaDust.Kind.NONE, "веерника нет — нет")


func test_feeding_picks_puffs_on_lace() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var og := _og(w)
	var st := og.leeches.stations[0]
	st.busy = -1
	ok(EcoOgnevkaDust.feeding(og, st), "станция пустует, веерник рядом — кормятся")
	var f := og.fan_at(st)
	var d := EcoOgnevkaDust.new()
	d.update(og, 0.0, _near(og))
	eq(d._made, 0, "первый шаг — без облачков")
	_run(d, og, 0.0, 12.0, _near(og))
	var per := 12.0 / EcoOgnevkaDust.PICK_EVERY
	ok(d._made >= int(per * 0.7) and d._made <= int(per * 1.4) + 1, "раз в ~1,2 с (%d за 12 с)" % d._made)
	var along := Vector3(cos(f.yaw), 0, -sin(f.yaw))
	var normal := Vector3(sin(f.yaw), 0, cos(f.yaw))
	var spots := {}
	for p in d.dust.puffs:
		if p.born < 0.0:
			continue
		var r := p.at - f.top
		ok(absf(r.dot(normal)) < 0.01, "на плоскости веера (%.3f м)" % r.dot(normal))
		ok(absf(r.dot(along)) <= EcoOgnevkaDust.LACE_W * 0.5 + 1e-4, "в ширину кружева")
		ok(r.y <= 1e-4 and r.y >= -EcoOgnevkaDust.LACE_DROP - 1e-4, "под вершиной (%.2f м)" % r.y)
		ok(p.alpha <= EcoOgnevkaDust.PICK_ALPHA * 1.21, "слабые")
		ok(p.scale <= EcoOgnevkaDust.PICK_SCALE * 1.16, "мелкие")
		spots[str(p.at.snapped(Vector3.ONE * 0.01))] = true
	ok(spots.size() >= 3, "в разных местах кружева (%d)" % spots.size())


func test_leave_and_land() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var og := _og(w)
	var st := og.leeches.stations[0]
	st.busy = -1
	var d := EcoOgnevkaDust.new()
	var ship := _near(og)
	d.update(og, 0.0, ship)
	var t := _run(d, og, 0.0, 0.5, ship)
	var before := d._made
	st.busy = 0   # серпохвост на чистке — рачки на нём
	t = _run(d, og, t, t + 1.0 / 30.0, ship)
	eq(d._made - before, EcoOgnevkaDust.LEAVE_N, "снялись — клуб из %d" % EcoOgnevkaDust.LEAVE_N)
	var dense := 0
	for p in d.dust.puffs:
		if p.born >= t - 1e-6 and p.alpha > EcoOgnevkaDust.PICK_ALPHA * 1.3:
			dense += 1
	eq(dense, EcoOgnevkaDust.LEAVE_N, "клуб гуще кормёжки")
	before = d._made
	t = _run(d, og, t, t + 6.0, ship)
	eq(d._made, before, "пока хищник на чистке — у веера тихо")
	st.busy = -1
	t = _run(d, og, t, t + 1.0 / 30.0, ship)
	eq(d._made - before, EcoOgnevkaDust.LAND_N, "вернулись — %d облачка" % EcoOgnevkaDust.LAND_N)
	before = d._made
	t = _run(d, og, t, t + EcoOgnevkaDust.PICK_EVERY * 0.9, ship)
	eq(d._made, before, "кормёжка — не сразу после посадки")


func test_no_fan_far_lite() -> void:
	EcoGrazerDust.lite = false
	var w := _world(false)
	var og := _og(w)
	var d := EcoOgnevkaDust.new()
	var ship := og.leeches.stations[0].top + Vector3(0, 0, 10)
	d.update(og, 0.0, ship)
	_run(d, og, 0.0, 6.0, ship)
	og.leeches.stations[0].busy = 0
	_run(d, og, 6.0, 7.0, ship)
	eq(d._made, 0, "станция без веерника — облачков нет")
	w = _world()
	og = _og(w)
	d = EcoOgnevkaDust.new()
	d.update(og, 0.0, FAR)
	_run(d, og, 0.0, 6.0, FAR)
	eq(d._made, 0, "дальше 80 м облачков нет")
	EcoGrazerDust.lite = true
	_run(d, og, 6.0, 12.0, _near(og))
	eq(d._made, 0, "«Экономно» — облачков нет")
	EcoGrazerDust.lite = false
	_run(d, og, 12.0, 18.0, _near(og))
	ok(d._made > 0, "выключатель вернули — облачка есть")


func test_time_back_no_burst() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var og := _og(w)
	var st := og.leeches.stations[0]
	var d := EcoOgnevkaDust.new()
	var ship := _near(og)
	st.busy = 0
	d.update(og, 10.0, ship)
	st.busy = -1
	d.update(og, 1.0, ship)   # время назад (новый забег) — запомнить, без облачков
	eq(d._made, 0, "сброс — без клуба посадки")


func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var og := _og(w)
		var d := EcoOgnevkaDust.new()
		d.update(og, 0.0, _near(og))
		_run(d, og, 0.0, 8.0, _near(og))
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
	var ov := view.ognevka_view
	ok(ov.dust_view != null and ov.dust_view.get_parent() == ov, "у огнёвок — MultiMesh «Муть»")
	eq(ov.dust_view.multimesh.instance_count, EcoOgnevkaDust.POOL)
	eq(ov.dust_view.layers, OceanView.LAYER_WORLD)
	var mat := (ov.dust_view.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var st := view.leeches.stations[0]
	var f := view.ognevka.fan_at(st)
	ok(f != null, "у станции огнецвета — веерник")
	var ship := EcoLink.ShipState.new()
	ship.pos = f.top + Vector3(0, 0, 10)
	view.step(0.05, ship)
	ov.dust.dust.add(f.top, view.world.time, 0.5, 1, 0.3)
	view.step(0.05, ship)
	var shown := 0
	var buf := ov.dust_buffer
	for i in EcoOgnevkaDust.POOL:
		if buf[i * GrazerView.DUST_STRIDE] > 0.0:
			shown += 1
	ok(shown >= 1, "облачко у веера в буфере (%d)" % shown)
	tree.root.remove_child(view)
	view.free()
