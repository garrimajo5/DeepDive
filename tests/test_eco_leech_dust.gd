extends TestCase
## Облачка на станции чистки (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): серпохвост на чистке — огнёвки обирают
## жабры, у жаберной щели встают маленькие облачка слизи; паразит снят — клуб; дальние от корабля, здоровые и
## «Экономно» облачков не дают; в сцене — свой MultiMesh «Муть» у пиявников на общем шейдере.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Мир: серпохвосты с пиявниками и станция в 30 м от первого хищника; первый сыт — плывёт на чистку.
func _world() -> EcoWorld:
	var probe := EcoWorld.new()
	probe.ground = _flat
	var pp := probe.add(EcoPred.new()) as EcoPred
	probe.add(EcoLeech.new(pp))
	var top := pp.all[0].agent.p + Vector3(30, 0, 0)
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var ps := w.add(EcoPred.new()) as EcoPred
	var tops: Array[Vector3] = [top, Vector3(300, -30, 300)]
	w.add(EcoLeech.new(ps, null, tops))
	ps.all[0].hunger = 0.2
	return w


func _leeches(w: EcoWorld) -> EcoLeech:
	for s in w.systems:
		if s is EcoLeech:
			return s
	return null


## Шагать мир, пока паразит на первом хищнике (не дольше 40 с); облачка — за миром, корабль — ship (null — у хищника).
func _clean(w: EcoWorld, d: EcoLeechDust, ship = null) -> Dictionary:
	var lc := _leeches(w)
	var pr := lc.preds().all[0]
	var t := 0.0
	var work := 0.0
	var made_work := -1
	d.update(lc, w.time, pr.agent.p if ship == null else ship)
	while pr.leech and t < 40.0:
		w.step(EcoWorld.MAX_STEP)
		t += EcoWorld.MAX_STEP
		if EcoLeechDust.cleaning(lc, pr):
			work += EcoWorld.MAX_STEP
		d.update(lc, w.time, pr.agent.p if ship == null else ship)
		if pr.leech:
			made_work = d._made
	return {"work": work, "made_work": made_work, "pr": pr}


func test_cleaning_puffs_at_gills_and_burst() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var d := EcoLeechDust.new()
	var r := _clean(w, d)
	var pr: EcoPred.Pred = r["pr"]
	ok(not pr.leech, "огнёвки сняли паразита")
	ok(r["work"] >= EcoLeech.CLEAN_WORK - 0.1, "чистка у вершины %.1f с" % r["work"])
	var work_n: int = r["made_work"]
	var expect: float = float(r["work"]) / EcoLeechDust.WORK_EVERY
	ok(work_n >= int(expect * 0.6) and work_n <= int(expect * 1.5) + 1,
			"пока чистят — облачко раз в ~0,9 с (%d за %.1f с)" % [work_n, r["work"]])
	eq(d._made - work_n, EcoLeechDust.BURST, "паразит снят — клуб из трёх облачков")
	var gills := EcoLeech.position_on(pr)
	var bursts := 0
	for p in d.dust.puffs:
		if p.born < -1e8:
			continue
		ok(p.born <= w.time + 1e-4, "облачко не из будущего")
		if p.scale > EcoLeechDust.BURST_SCALE * 0.8:
			bursts += 1
			ok(p.at.distance_to(gills) <= EcoLeechDust.SCATTER * 1.8, "клуб — у жабр (%.2f м)" % p.at.distance_to(gills))
			ok(p.alpha > EcoLeechDust.WORK_ALPHA * 1.3, "клуб гуще облачков чистки")
		else:
			ok(p.scale < EcoLeechDust.WORK_SCALE * 1.2, "облачко чистки мелкое")
	eq(bursts, EcoLeechDust.BURST)


func test_no_puffs_without_cleaning() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var lc := _leeches(w)
	lc.preds().all[0].hunger = 0.6   # голодный не плывёт на чистку
	var d := EcoLeechDust.new()
	var pr := lc.preds().all[0]
	d.update(lc, w.time, pr.agent.p)
	for i in 200:
		w.step(EcoWorld.MAX_STEP)
		d.update(lc, w.time, pr.agent.p)
	ok(pr.mode != EcoPred.Mode.CLEAN, "не на чистке")
	eq(d._made, 0, "без чистки облачков нет — пиявник сам слизи не пускает")


func test_far_and_lite_quiet() -> void:
	EcoGrazerDust.lite = false
	var d := EcoLeechDust.new()
	_clean(_world(), d, FAR)
	eq(d._made, 0, "дальше 80 м от корабля облачков нет")
	EcoGrazerDust.lite = true
	d = EcoLeechDust.new()
	var r := _clean(_world(), d)
	ok(not (r["pr"] as EcoPred.Pred).leech, "чистка прошла")
	eq(d._made, 0, "«Экономно» — облачков нет")
	EcoGrazerDust.lite = false


## Первый шаг и время мира назад (новый забег) — запоминает, кто заражён, без ложного клуба.
func test_reset_no_false_burst() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var lc := _leeches(w)
	var pr := lc.preds().all[0]
	var d := EcoLeechDust.new()
	pr.leech = false
	d.update(lc, 10.0, pr.agent.p)
	eq(d._made, 0, "первый шаг — без облачков")
	pr.leech = true
	d.update(lc, 10.1, pr.agent.p)
	d.update(lc, 1.0, pr.agent.p)   # время назад
	pr.leech = false
	d.update(lc, 1.1, pr.agent.p)
	eq(d._made, EcoLeechDust.BURST, "снят после сброса — клуб, а не от сброса")


func test_view_dust_mesh() -> void:
	EcoGrazerDust.lite = false
	var view := EcoView.new()
	tree.root.add_child(view)
	await frames(1)
	var lv := view.leech_view
	ok(lv.dust_view == null and view.dust_layer.parts.has(lv._dust), "у пиявников — MultiMesh «Муть» — кусок общего слоя (#849)")
	eq(view.dust_layer.pools[view.dust_layer.parts.find(lv._dust)], EcoLeechDust.POOL)
	eq(view.dust_layer.layers, OceanView.LAYER_WORLD)
	var mat := (view.dust_layer.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var pr := view.preds.all[0]
	var ship := EcoLink.ShipState.new()
	ship.pos = pr.agent.p + Vector3(0, 0, 10)
	view.step(0.05, ship)
	lv.dust.dust.add(EcoLeech.position_on(pr), view.world.time, 0.7, 1, 0.5)
	view.step(0.05, ship)
	var shown := 0
	var buf := lv.dust_buffer
	for i in EcoLeechDust.POOL:
		if buf[i * GrazerView.DUST_STRIDE] > 0.0:
			shown += 1
	eq(shown, 1, "облачко у жабр в буфере")
	tree.root.remove_child(view)
	view.free()
