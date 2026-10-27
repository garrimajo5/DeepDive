extends TestCase
## Слизь радужников (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): вспыхнули в луче — облачка у гребневиков стаи;
## корпус упёрся в стаю — облачко у задетого, не чаще паузы; далеко и в «Экономно» — нет; время назад — без
## всплеска; одинаковый мир — облачка те же; в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _system() -> EcoRaduzh:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var rd := w.add(EcoRaduzh.new()) as EcoRaduzh
	w.step(EcoWorld.MAX_STEP)
	return rd


## Корабль в 20 м от стаи 0 — не задевает её корпусом.
func _beside(rd: EcoRaduzh) -> Vector3:
	return rd.swarms[0].c + Vector3(20, 0, 20)


func _flash(sw: EcoRaduzh.Swarm, glow: float) -> void:
	sw.glow = glow


func test_flash_puffs_at_members() -> void:
	EcoGrazerDust.lite = false
	var rd := _system()
	var d := EcoRaduzhDust.new()
	var sw := rd.swarms[0]
	var ship := _beside(rd)
	_flash(sw, 0.0)
	d.update(rd, 1.0, ship, 0.0)
	_flash(sw, 0.3)
	d.update(rd, 1.1, ship, 0.0)
	eq(d._made, 0, "разгорается ниже порога — облачков нет")
	_flash(sw, 0.6)
	d.update(rd, 1.2, ship, 0.0)
	eq(d._made, EcoRaduzhDust.FLASH_N, "вспышка — %d облачка" % EcoRaduzhDust.FLASH_N)
	for p in d.dust.puffs:
		if p.born < -1e8:
			continue
		ok(p.at.distance_to(sw.c) < EcoRaduzh.R + 1.0 + EcoRaduzhDust.SCATTER * 2.0, "облачко в стае")
		ok(p.alpha <= EcoRaduzhDust.FLASH_ALPHA * 1.21, "слабое")
		near(p.born, 1.2, 1e-6, "с вспышки")
	_flash(sw, 1.0)
	d.update(rd, 1.3, ship, 0.0)
	d.update(rd, 1.4, ship, 0.0)
	eq(d._made, EcoRaduzhDust.FLASH_N, "горит дальше — новых нет")
	_flash(sw, 0.2)
	d.update(rd, 2.0, ship, 0.0)
	_flash(sw, 0.9)
	d.update(rd, 2.1, ship, 0.0)
	eq(d._made, EcoRaduzhDust.FLASH_N * 2, "погасла и вспыхнула снова — ещё облачка")


func test_flash_members_vary() -> void:
	var seen := {}
	for f in 6:
		for k in EcoRaduzhDust.FLASH_N:
			var m := EcoRaduzhDust.flash_member(EcoRaduzhDust.flash_key(0, f + 1, k))
			ok(m >= 0 and m < EcoRaduzh.PER_SWARM, "номер гребневика в стае")
			seen[m] = true
	ok(seen.size() >= 6, "облачка у разных гребневиков (%d)" % seen.size())


func test_hull_bump_puffs() -> void:
	EcoGrazerDust.lite = false
	var rd := _system()
	var d := EcoRaduzhDust.new()
	var sw := rd.swarms[0]
	# корабль стоит центром корпуса (EcoHull.CENTER) в центре стаи — гребневики внутри обшивки
	var t := 5.0
	var ship := sw.c - EcoHull.CENTER
	ok(EcoRaduzhDust.bumped(sw, t, ship, 0.0) >= 0, "корпус задел гребневика")
	d.update(rd, t, ship, 0.0)
	for i in 90:   # 3 с
		t += 1.0 / 30.0
		d.update(rd, t, ship, 0.0)
	var made := d._made
	ok(made >= 3 and made <= int(3.0 / (EcoRaduzhDust.BUMP_EVERY * (1.0 - EcoRaduzhDust.BUMP_SPREAD))) + 1,
		"толчки — не чаще паузы (%d)" % made)
	for p in d.dust.puffs:
		if p.born < -1e8:
			continue
		ok(p.alpha <= EcoRaduzhDust.BUMP_ALPHA * 1.21, "слабое облачко")
		ok(not EcoHull.touches(p.at, ship, 0.0, -EcoRaduzhDust.SCATTER * 2.0), "облачко снаружи обшивки")
	# корабль сбоку — не задевает
	var d2 := EcoRaduzhDust.new()
	var side := _beside(rd)
	eq(EcoRaduzhDust.bumped(sw, t, side, 0.0), -1, "сбоку — не задевает")
	d2.update(rd, t, side, 0.0)
	for i in 90:
		t += 1.0 / 30.0
		d2.update(rd, t, side, 0.0)
	eq(d2._made, 0, "без толчков и вспышек — облачков нет")


func test_far_lite() -> void:
	var rd := _system()
	var sw := rd.swarms[0]
	var d := EcoRaduzhDust.new()
	EcoGrazerDust.lite = false
	_flash(sw, 0.0)
	d.update(rd, 1.0, FAR, 0.0)
	_flash(sw, 1.0)
	d.update(rd, 1.1, FAR, 0.0)
	eq(d._made, 0, "дальше 80 м облачков нет")
	EcoGrazerDust.lite = true
	_flash(sw, 0.0)
	d.update(rd, 1.2, _beside(rd), 0.0)
	_flash(sw, 1.0)
	d.update(rd, 1.3, _beside(rd), 0.0)
	eq(d._made, 0, "«Экономно» — облачков нет")
	EcoGrazerDust.lite = false
	_flash(sw, 0.0)
	d.update(rd, 1.4, _beside(rd), 0.0)
	_flash(sw, 1.0)
	d.update(rd, 1.5, _beside(rd), 0.0)
	eq(d._made, EcoRaduzhDust.FLASH_N, "выключатель вернули — облачка есть")


func test_time_back_no_burst() -> void:
	EcoGrazerDust.lite = false
	var rd := _system()
	var sw := rd.swarms[0]
	var d := EcoRaduzhDust.new()
	_flash(sw, 0.0)
	d.update(rd, 100.0, _beside(rd), 0.0)
	_flash(sw, 1.0)
	d.update(rd, 1.0, _beside(rd), 0.0)   # время назад (новый забег) — запомнить, без облачков
	d.update(rd, 1.0 + 1.0 / 30.0, _beside(rd), 0.0)
	eq(d._made, 0, "сброс — без всплеска")


func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for r in 2:
		var rd := _system()
		var sw := rd.swarms[0]
		var d := EcoRaduzhDust.new()
		var ship := sw.c - EcoHull.CENTER
		var t := 0.0
		d.update(rd, t, ship, 0.3)
		for i in 60:
			t += 1.0 / 30.0
			_flash(sw, 1.0 if i % 20 > 10 else 0.0)
			d.update(rd, t, ship, 0.3)
		var at: Array = []
		for p in d.dust.puffs:
			at.append([p.at, p.born, p.alpha])
		runs.append(at)
	eq(runs[0], runs[1], "одинаковый мир — облачка те же")


func test_view_dust_mesh() -> void:
	EcoGrazerDust.lite = false
	var view := EcoView.new()
	tree.root.add_child(view)
	await frames(1)
	var rv := view.raduzh_view
	ok(rv.dust_view != null and rv.dust_view.get_parent() == rv, "у радужников — MultiMesh «Муть»")
	eq(rv.dust_view.multimesh.instance_count, EcoRaduzhDust.POOL)
	eq(rv.dust_view.layers, OceanView.LAYER_WORLD)
	eq(rv.transform, Transform3D.IDENTITY, "облачка в мировых координатах")
	var mat := (rv.dust_view.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var ship := EcoLink.ShipState.new()
	var sw := view.raduzh.swarms[0]
	ship.pos = sw.c - EcoHull.CENTER   # корпус в стае
	for i in 60:
		view.step(0.05, ship)
		ship.pos = sw.c - EcoHull.CENTER
		if rv.dust._made > 0:
			break
	ok(rv.dust._made > 0, "корпус в стае — облачко слизи")
	for i in 4:   # миг рождения не виден — ещё 0,2 с
		view.step(0.05, ship)
	var shown := 0
	var buf := rv.dust_buffer
	for i in EcoRaduzhDust.POOL:
		if buf[i * GrazerView.DUST_STRIDE] > 0.0:
			shown += 1
	ok(shown >= 1, "облачко в буфере (%d)" % shown)
	tree.root.remove_child(view)
	view.free()
