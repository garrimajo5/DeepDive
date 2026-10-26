extends TestCase
## Пузырьки от пузырчатки (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): луковицы лопаются — с каждой срываются
## пузырьки газа; спелые сочатся по одному; пузырёк всплывает, виляет, течение сносит, раздувается и тает; дальние
## от корабля и «Экономно» пузырьков не дают; у гостя (облако спор пришло без события) — те же пузырьки; в сцене —
## свой MultiMesh на общем шейдере мира.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Ровное дно, один куст пузырчатки у start; корабль рядом.
func _world(start := Vector3(0, FLAT, 0)) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = start + Vector3(8, 6, 0)
	w.add(EcoBladder.new(null, [start] as Array[Vector3]))
	return w


func _bl(w: EcoWorld) -> EcoBladder:
	return w.systems[0] as EcoBladder


## Мир идёт secs секунд кадрами по 1/30 с, пузырьки шагают за ним.
func _run(w: EcoWorld, d: EcoBladderBubbles, secs: float) -> void:
	var t := 0.0
	while t < secs - 1e-6:
		w.step(1.0 / 30.0)
		d.update(_bl(w), w.time, w.ship.pos)
		t += 1.0 / 30.0


func _born(d: EcoBladderBubbles) -> Array[EcoBladderBubbles.Bubble]:
	var out: Array[EcoBladderBubbles.Bubble] = []
	for b in d.bubbles:
		if b.born > -1e8:
			out.append(b)
	return out


func test_pop_releases_bubbles_from_every_bulb() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var bush := _bl(w).bushes[0]
	bush.ripe = 0.1   # не сочится
	var d := EcoBladderBubbles.new()
	d.update(_bl(w), w.time, w.ship.pos)
	_run(w, d, 0.5)
	eq(_born(d).size(), 0, "незрелый куст пузырьков не даёт")
	_bl(w).pop(w, bush, false)
	var t0 := w.time
	_run(w, d, 0.1)
	var all := _born(d)
	eq(all.size(), EcoBladderBubbles.POP_N * EcoBladder.STEMS, "с каждой луковицы — по %d" % EcoBladderBubbles.POP_N)
	for k in EcoBladder.STEMS:
		var at_bulb := 0
		for b in all:
			if b.at.distance_to(EcoBladder.bulb(bush, k, w.time) + Vector3(0, EcoBladderBubbles.LIFT, 0)) < 0.12:
				at_bulb += 1
		ok(at_bulb >= EcoBladderBubbles.POP_N, "пузырьки у луковицы %d (%d)" % [k, at_bulb])
	for b in all:
		ok(b.born >= t0 and b.born <= t0 + 1.0 / 30.0 + EcoBladderBubbles.POP_SPAN + 1e-4, "срываются вразнобой за миг")
		ok(b.alpha > EcoBladderBubbles.POP_ALPHA * 0.8, "ярче, чем сочащиеся")
	_run(w, d, 2.0)
	eq(_born(d).size(), EcoBladderBubbles.POP_N * EcoBladder.STEMS, "облако спор висит — новых нет")


func test_bubble_rises_wobbles_drifts_and_fades() -> void:
	var d := EcoBladderBubbles.new()
	var b := d.add(Vector3(1, FLAT + 1.0, 2), 10.0, 0.8, 5)
	eq(EcoBladderBubbles.fade(b, 9.9), 0.0, "до срыва не виден")
	ok(EcoBladderBubbles.fade(b, 11.0) > 0.7, "виден")
	eq(EcoBladderBubbles.fade(b, 10.0 + EcoBladderBubbles.LIFE), 0.0, "растаял")
	ok(EcoBladderBubbles.fade(b, 10.0 + EcoBladderBubbles.LIFE * 0.9) < EcoBladderBubbles.fade(b, 11.0), "тает к концу")
	var still := Vector3.ZERO
	var y0 := EcoBladderBubbles.pos(b, 10.0, still).y
	var y1 := EcoBladderBubbles.pos(b, 12.0, still).y
	near(y1 - y0, b.rise * 2.0, 1e-4, "всплывает со своей скоростью")
	ok(b.rise > EcoBladderBubbles.RISE * 0.7 and b.rise < EcoBladderBubbles.RISE * 1.3, "скорость с разбросом")
	# виляет поперёк: в плоскости xz отходит от вертикали, но не дальше размаха
	var max_side := 0.0
	for i in 50:
		var p := EcoBladderBubbles.pos(b, 10.0 + i * 0.1, still)
		max_side = maxf(max_side, Vector2(p.x - 1.0, p.z - 2.0).length())
	ok(max_side > EcoBladderBubbles.WOBBLE * 0.5 and max_side <= EcoBladderBubbles.WOBBLE + 1e-4,
		"виляет (%.3f м)" % max_side)
	var flow := Vector3(0.2, 0.5, 0)
	var dx := EcoBladderBubbles.pos(b, 12.0, flow).x - EcoBladderBubbles.pos(b, 12.0, still).x
	near(dx, 0.2 * EcoBladderBubbles.DRIFT * 2.0, 1e-4, "течение сносит")
	near(EcoBladderBubbles.pos(b, 12.0, flow).y, y1, 1e-4, "вертикаль течения не тянет")
	ok(EcoBladderBubbles.size(b, 14.5) > EcoBladderBubbles.size(b, 10.0) * 1.25, "к концу раздувается")


func test_ripe_bulbs_seep_unripe_do_not() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var bush := _bl(w).bushes[0]
	bush.ripe = 0.8   # до 1 — 14 с, не лопнет
	var d := EcoBladderBubbles.new()
	d.update(_bl(w), w.time, w.ship.pos)
	_run(w, d, 10.0)
	var n := _born(d).size()
	ok(n >= 2 and n <= 7, "спелые сочатся по одному (%d за 10 с)" % n)
	for b in _born(d):
		ok(b.alpha < EcoBladderBubbles.POP_ALPHA * 0.8, "слабее, чем при лопании")
		var from_bulb := false
		for k in EcoBladder.STEMS:
			from_bulb = from_bulb or Vector2(b.at.x - bush.stem_top[k].x, b.at.z - bush.stem_top[k].z).length() < 0.1
		ok(from_bulb, "с луковицы")
	var w2 := _world()
	_bl(w2).bushes[0].ripe = 0.3
	var d2 := EcoBladderBubbles.new()
	d2.update(_bl(w2), w2.time, w2.ship.pos)
	_run(w2, d2, 10.0)
	eq(_born(d2).size(), 0, "незрелые не сочатся")


func test_far_and_lite_make_none() -> void:
	var w := _world()
	w.ship.pos = Vector3(300, FLAT, 0)
	var d := EcoBladderBubbles.new()
	d.update(_bl(w), w.time, w.ship.pos)
	_bl(w).pop(w, _bl(w).bushes[0], false)
	_run(w, d, 1.0)
	eq(_born(d).size(), 0, "дальше %d м — нет" % int(EcoBladderBubbles.NEAR))
	EcoGrazerDust.lite = true
	var w2 := _world()
	var d2 := EcoBladderBubbles.new()
	d2.update(_bl(w2), w2.time, w2.ship.pos)
	_bl(w2).pop(w2, _bl(w2).bushes[0], false)
	_run(w2, d2, 1.0)
	EcoGrazerDust.lite = false
	eq(_born(d2).size(), 0, "«Экономно» — нет")


## У гостя облако спор приходит состоянием, а не событием pop — пузырьки те же.
func test_guest_cloud_without_event_and_same_bubbles() -> void:
	EcoGrazerDust.lite = false
	var a := _world()
	var b := _world()
	_bl(a).bushes[0].ripe = 0.1
	_bl(b).bushes[0].ripe = 0.1
	var da := EcoBladderBubbles.new()
	var db := EcoBladderBubbles.new()
	da.update(_bl(a), a.time, a.ship.pos)
	db.update(_bl(b), b.time, b.ship.pos)
	_bl(a).pop(a, _bl(a).bushes[0], false)
	_bl(b).bushes[0].life = EcoBladder.LIFE   # как из кадра хоста
	_bl(b).bushes[0].ripe = 0.0
	_run(a, da, 1.0)
	_run(b, db, 1.0)
	eq(_born(db).size(), _born(da).size(), "столько же")
	for i in da.bubbles.size():
		ok(da.bubbles[i].at.distance_to(db.bubbles[i].at) < 1e-4, "там же")
		near(da.bubbles[i].rise, db.bubbles[i].rise, 1e-6, "так же")


func test_scene_multimesh_on_world_shader() -> void:
	EcoGrazerDust.lite = false
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var bv := view.bladder_view
	var mi := bv.bubbles
	ok(mi != null and mi.get_parent() == bv, "пузырьки — у пузырчатки")
	eq(mi.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(mi.multimesh.instance_count, EcoBladderBubbles.POOL, "все пузырьки — один MultiMesh")
	var mat := (mi.multimesh.mesh as QuadMesh).material as ShaderMaterial
	eq(mat.shader, EcoShaders.shader(EcoShaders.MIST), "общий шейдер мира MIST")
	eq(int(mat.get_shader_parameter("mode")), int(EcoShaders.Mist.BUBBLE), "режим пузырей")
	ok(bool(mat.get_shader_parameter("placed")), "место считает процессор")
	for other in view.bladders.bushes:
		other.ripe = 0.1   # не сочатся и сами не лопнут
	var bl := view.bladders.bushes[0]
	var ship := EcoLink.ShipState.new()
	ship.pos = bl.base + Vector3(6, 5, 0)
	view.step(0.05, ship)
	var before := 0
	for n in EcoBladderBubbles.POOL:
		if BladderView.transform_at(bv.bubble_buffer, n).basis.x.length() > 0.0:
			before += 1
	eq(before, 0, "пока не лопнула — пузырьков нет")
	view.bladders.pop(view.world, bl, false)
	for i in 20:
		view.step(0.05, ship)
	var shown := 0
	for n in EcoBladderBubbles.POOL:
		var tr := BladderView.transform_at(bv.bubble_buffer, n)
		if tr.basis.x.length() > 0.0:
			shown += 1
			ok(tr.origin.y > bl.base.y + 0.5 and Vector2(tr.origin.x - bl.base.x, tr.origin.z - bl.base.z).length() < 2.5,
				"над кустом")
			ok(bv.bubble_buffer[n * BladderView.STRIDE_C + 15] > 0.0, "виден")
	eq(shown, EcoBladderBubbles.POP_N * EcoBladder.STEMS, "все пузырьки лопнувшего куста видны")
	view.queue_free()
	await frames(1)
