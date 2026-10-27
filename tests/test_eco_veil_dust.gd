extends TestCase
## Выдох фонарной вуали (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): на каждом сокращении купола — облачка у
## кромки, под ней; ужалила светляка — клуб слизи у рыбки; далеко от корабля и в «Экономно» облачков нет; время
## назад — без всплеска; одинаковый мир — облачка те же; в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoVeil.new())
	w.step(EcoWorld.MAX_STEP)
	return w


func _veils(w: EcoWorld) -> EcoVeil:
	for s in w.systems:
		if s is EcoVeil:
			return s
	return null


func _run(d: EcoVeilDust, v: EcoVeil, t0: float, t1: float, ship: Vector3) -> float:
	var t := t0
	while t < t1 - 1e-6:
		t += 1.0 / 30.0
		d.update(v, t, ship)
	return t


func _near(v: EcoVeil) -> Vector3:
	return v.veils[0].p + Vector3(0, -8, 12)


func test_cycle_at_widest_bell() -> void:
	var v := _veils(_world())
	var vl := v.veils[0]
	for c in [3, 4, 10]:
		var t0 := EcoVeilDust.cycle_start(vl, c)
		near(EcoVeil.pulse(vl, t0).x, 1.0 + EcoVeil.PULSE, 1e-4, "такт — когда купол шире всего")
		ok(EcoVeil.pulse(vl, t0 + 0.2).x < EcoVeil.pulse(vl, t0).x, "и начинает сжиматься")
		eq(EcoVeilDust.cycle(vl, t0 + 0.01), c, "такт %d" % c)
		eq(EcoVeilDust.cycle(vl, t0 - 0.01), c - 1, "до начала — прошлый такт")


func test_exhale_each_contraction_at_rim() -> void:
	EcoGrazerDust.lite = false
	var v := _veils(_world())
	var d := EcoVeilDust.new()
	var ship := _near(v)
	d.update(v, 0.0, ship)
	var period := TAU / EcoVeil.PULSE_W
	_run(d, v, 0.0, period * 5.0, ship)
	# корабль у первой вуали, вторая в 113 м — дальше 80 м
	var made := d._made
	ok(made >= EcoVeilDust.EXHALE_N * 4 and made <= EcoVeilDust.EXHALE_N * 6,
		"за 5 тактов — по %d облачка на такт (%d)" % [EcoVeilDust.EXHALE_N, made])
	var vl := v.veils[0]
	var r := EcoVeil.R * (1.0 + EcoVeil.PULSE)
	for p in d.dust.puffs:
		if p.born < -1e8:
			continue
		var dh := Vector2(p.at.x - vl.p.x, p.at.z - vl.p.z).length()
		ok(absf(dh - r * (1.0 + EcoVeilDust.OUT)) < EcoVeilDust.SCATTER * 1.5 + 0.1, "у кромки (%.2f м от оси)" % dh)
		ok(p.at.y < vl.p.y and p.at.y > vl.p.y - EcoVeilDust.BELOW - EcoVeilDust.SCATTER * 1.5,
			"чуть ниже кромки")
		ok(p.alpha <= EcoVeilDust.EXHALE_ALPHA * 1.21, "выдох слабый")
		near(EcoVeil.pulse(vl, p.born).x, 1.0 + EcoVeil.PULSE, 1e-3, "облачко — с начала сжатия")


func test_sting_puffs_at_fish() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var v := _veils(w)
	var d := EcoVeilDust.new()
	var ship := _near(v)
	var vl := v.veils[0]
	d.update(v, 0.1, ship)
	var fish_p := vl.p + Vector3(1.0, -4.0, 0.5)
	var stung: Array = []
	for i in 2000:
		v.fish_push(w, fish_p, 0.05, stung)
		if not stung.is_empty():
			break
	ok(not stung.is_empty(), "рыбку под куполом ужалили")
	eq(vl.stings, 1, "счёт ужаливаний")
	eq(vl.sting_at, fish_p, "место — у рыбки")
	var before := d._made
	d.update(v, 0.1 + 1.0 / 30.0, ship)
	eq(d._made - before, EcoVeilDust.STING_N, "клуб слизи из %d" % EcoVeilDust.STING_N)
	var near_fish := 0
	for p in d.dust.puffs:
		if p.at.distance_to(fish_p) <= EcoVeilDust.STING_SCATTER * sqrt(3.0) + 1e-3:
			near_fish += 1
	eq(near_fish, EcoVeilDust.STING_N, "у ужаленной рыбки")
	before = d._made
	d.update(v, 0.1 + 2.0 / 30.0, ship)
	eq(d._made, before, "одно ужаливание — один клуб")


func test_far_lite() -> void:
	var v := _veils(_world())
	var d := EcoVeilDust.new()
	EcoGrazerDust.lite = false
	d.update(v, 0.0, FAR)
	_run(d, v, 0.0, 15.0, FAR)
	eq(d._made, 0, "дальше 80 м облачков нет")
	EcoGrazerDust.lite = true
	_run(d, v, 15.0, 30.0, _near(v))
	eq(d._made, 0, "«Экономно» — облачков нет")
	EcoGrazerDust.lite = false
	_run(d, v, 30.0, 40.0, _near(v))
	ok(d._made > 0, "выключатель вернули — облачка есть")


func test_time_back_no_burst() -> void:
	EcoGrazerDust.lite = false
	var v := _veils(_world())
	var d := EcoVeilDust.new()
	d.update(v, 100.0, _near(v))
	d.update(v, 1.0, _near(v))   # время назад (новый забег) — запомнить, без облачков
	d.update(v, 1.0 + 1.0 / 30.0, _near(v))
	eq(d._made, 0, "сброс — без всплеска")


func test_long_frame_one_exhale() -> void:
	EcoGrazerDust.lite = false
	var v := _veils(_world())
	var d := EcoVeilDust.new()
	d.update(v, 0.0, _near(v))
	d.update(v, 60.0, _near(v))   # долгий кадр — только последний такт
	eq(d._made, EcoVeilDust.EXHALE_N, "один выдох за долгий кадр")


func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var v := _veils(_world())
		var d := EcoVeilDust.new()
		d.update(v, 0.0, _near(v))
		_run(d, v, 0.0, 20.0, _near(v))
		var at: Array = []
		for p in d.dust.puffs:
			at.append([p.at, p.born])
		runs.append(at)
	eq(runs[0], runs[1], "одинаковый мир — облачка те же")


func test_view_dust_mesh() -> void:
	EcoGrazerDust.lite = false
	var view := EcoView.new()
	tree.root.add_child(view)
	await frames(1)
	var vv := view.veil_view
	ok(vv.dust_view != null and vv.dust_view.get_parent() == vv, "у вуалей — MultiMesh «Муть»")
	eq(vv.dust_view.multimesh.instance_count, EcoVeilDust.POOL)
	eq(vv.dust_view.layers, OceanView.LAYER_WORLD)
	eq(vv.transform, Transform3D.IDENTITY, "облачка в мировых координатах")
	var mat := (vv.dust_view.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var ship := EcoLink.ShipState.new()
	var vl := view.veils.veils[0]
	ship.pos = vl.p + Vector3(0, -8, 12)
	for i in 200:   # до 10 с — пока купол не сожмётся
		view.step(0.05, ship)
		if vv.dust._made > 0:
			break
	ok(vv.dust._made > 0, "купол сжался — выдох")
	var shown := 0
	var buf := vv.dust_buffer
	for i in EcoVeilDust.POOL:
		if buf[i * GrazerView.DUST_STRIDE] > 0.0:
			shown += 1
	ok(shown >= 1, "облачко выдоха в буфере (%d)" % shown)
	tree.root.remove_child(view)
	view.free()
