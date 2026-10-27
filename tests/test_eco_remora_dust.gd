extends TestCase
## Слизь присосок (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): прилипала легла на корпус — облачко у диска,
## снялась со ската — слабее, сорвана разрядом — клуб там, где сидела; дальние и «Экономно» — без облачков;
## в сцене — свой MultiMesh «Муть» у присосок на общем шейдере.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var r := w.add(EcoRay.new()) as EcoRay
	w.add(EcoRemora.new(r))
	return w


func _remoras(w: EcoWorld) -> EcoRemora:
	for s in w.systems:
		if s is EcoRemora:
			return s
	return null


## Корабль идёт под первым скатом (на 9 м ниже), слизь — за миром; far — корабль для облачков дальше 80 м.
func _follow(w: EcoWorld, d: EcoRemoraDust, seconds: float, far := false) -> void:
	var ry := (w.systems[0] as EcoRay).rays[0]
	for i in int(round(seconds / 0.05)):
		w.ship.pos = Vector3(ry.p.x, -20.0, ry.p.z)
		w.ship.yaw = 0.3
		w.step(0.05)
		d.update(_remoras(w), w.time, FAR if far else w.ship.pos)


func _kinds(d: EcoRemoraDust) -> Dictionary:
	var out := {"latch": 0, "let_go": 0, "torn": 0}
	for p in d.dust.puffs:
		if p.born < -1e8:
			continue
		if p.scale > EcoRemoraDust.TORN_SCALE * 0.8:
			out["torn"] += 1
		elif p.scale > EcoRemoraDust.LET_GO_SCALE * 1.16:
			out["latch"] += 1
		else:
			out["let_go"] += 1
	return out


func test_kind_by_mode() -> void:
	var M := EcoRemora.Mode
	eq(EcoRemoraDust.kind(M.SWIM, M.HULL), EcoRemoraDust.Kind.LATCH, "легла на корпус")
	eq(EcoRemoraDust.kind(M.SWIM, M.RAY), EcoRemoraDust.Kind.LATCH, "легла на ската")
	eq(EcoRemoraDust.kind(M.RAY, M.SWIM), EcoRemoraDust.Kind.LET_GO, "снялась со ската")
	eq(EcoRemoraDust.kind(M.HULL, M.SWIM), EcoRemoraDust.Kind.TORN, "сорвана с корпуса")
	eq(EcoRemoraDust.kind(M.HULL, M.HULL), EcoRemoraDust.Kind.NONE)
	eq(EcoRemoraDust.kind(M.SWIM, M.SWIM), EcoRemoraDust.Kind.NONE)


func test_hop_latch_and_zap_tear() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var rm := _remoras(w)
	var d := EcoRemoraDust.new()
	d.update(rm, w.time, w.ship.pos)
	_follow(w, d, 12.0)
	eq(rm.on_hull, 3, "три прилипалы на корпусе")
	var k := _kinds(d)
	eq(k["let_go"], 3, "каждая снялась со ската — по облачку")
	eq(k["latch"], 3, "каждая легла на корпус — по облачку")
	eq(k["torn"], 0, "без разряда клуба нет")
	for p in d.dust.puffs:
		if p.born > -1e8:
			ok(p.alpha <= EcoRemoraDust.LATCH_ALPHA * 1.21, "легла/снялась — слабое облачко")
	# где сидели — до разряда
	var seats: Array[Vector3] = []
	for r in rm.remoras:
		if r.mode == EcoRemora.Mode.HULL:
			seats.append(r.p)
	var before := d._made
	w.ship.zap = true
	w.step(0.05)
	w.ship.zap = false
	d.update(rm, w.time, w.ship.pos)
	eq(rm.on_hull, 0, "сброшены")
	eq(d._made - before, 3 * EcoRemoraDust.TORN, "сорваны — клуб из трёх облачков у каждой")
	var torn := 0
	for p in d.dust.puffs:
		if p.scale <= EcoRemoraDust.TORN_SCALE * 0.8 or p.born < -1e8:
			continue
		torn += 1
		ok(p.born <= w.time + 1e-4, "облачко не из будущего")
		ok(p.alpha > EcoRemoraDust.LATCH_ALPHA * 1.2, "клуб гуще")
		var best := INF
		for s in seats:
			best = minf(best, p.at.distance_to(s))
		ok(best <= EcoRemoraDust.TORN_SCATTER * 1.8, "клуб — там, где сидела (%.2f м)" % best)
	eq(torn, 3 * EcoRemoraDust.TORN)


func test_riding_quiet() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var rm := _remoras(w)
	var d := EcoRemoraDust.new()
	d.update(rm, w.time, rm.remoras[0].p)
	for i in 200:   # корабль далеко — на скатах катаются, не перебираются
		w.step(0.05)
		d.update(rm, w.time, rm.remoras[0].p)
	eq(d._made, 0, "катаются на скате — слизи нет")


func test_far_and_lite_quiet() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var d := EcoRemoraDust.new()
	d.update(_remoras(w), w.time, FAR)
	_follow(w, d, 12.0, true)
	ok(_remoras(w).on_hull > 0, "перебрались")
	eq(d._made, 0, "дальше 80 м от корабля облачков нет")
	EcoGrazerDust.lite = true
	w = _world()
	d = EcoRemoraDust.new()
	d.update(_remoras(w), w.time, w.ship.pos)
	_follow(w, d, 12.0)
	ok(_remoras(w).on_hull > 0, "перебрались")
	eq(d._made, 0, "«Экономно» — облачков нет")
	EcoGrazerDust.lite = false


## Первый шаг и время мира назад (новый забег) — запоминает режимы, без ложных облачков.
func test_reset_no_false_puffs() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var rm := _remoras(w)
	var r := rm.remoras[0]
	var d := EcoRemoraDust.new()
	r.mode = EcoRemora.Mode.HULL
	d.update(rm, 10.0, r.p)
	eq(d._made, 0, "первый шаг — без облачков")
	d.update(rm, 1.0, r.p)   # время назад, рыба уже на скате
	r.mode = EcoRemora.Mode.RAY
	d.update(rm, 0.5, r.p)
	eq(d._made, 0, "сброс времени — без облачков")
	r.mode = EcoRemora.Mode.SWIM
	d.update(rm, 0.55, r.p)
	eq(d._made, 1, "снялась после сброса — облачко")


func test_view_dust_mesh() -> void:
	EcoGrazerDust.lite = false
	var view := EcoView.new()
	tree.root.add_child(view)
	await frames(1)
	var rv := view.remora_view
	ok(rv.dust_view != null and rv.dust_view.get_parent() == rv, "у присосок — MultiMesh «Муть»")
	eq(rv.dust_view.multimesh.instance_count, EcoRemoraDust.POOL)
	eq(rv.dust_view.layers, OceanView.LAYER_WORLD)
	var mat := (rv.dust_view.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var at := view.remoras.remoras[0].p
	var ship := EcoLink.ShipState.new()
	ship.pos = at + Vector3(0, 0, 10)
	view.step(0.05, ship)
	rv.dust.dust.add(at, view.world.time, 0.6, 1, 0.4)
	view.step(0.05, ship)
	var shown := 0
	var buf := rv.dust_buffer
	for i in EcoRemoraDust.POOL:
		if buf[i * GrazerView.DUST_STRIDE] > 0.0:
			shown += 1
	eq(shown, 1, "облачко слизи в буфере")
	tree.root.remove_child(view)
	view.free()
