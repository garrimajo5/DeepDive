extends TestCase
## Муть у дна от хватня (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): луч застал хватня раскрытым — рывком прячет
## щупальца, и вокруг основания встаёт клуб ила; схватил светляка в темноте — клуб слабее; медленное раскрытие и
## приоткрытый хватень ила не поднимают; дальние от корабля и «Экономно» мути не поднимают; в сцене — свой MultiMesh
## на общем шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Ровное дно, светляки, один голодный хватень у дома стаи 0 (как test_eco_hvaten).
func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var home := EcoFish.HOMES[0]
	var h := w.add(EcoHvaten.new(f, [Vector3(home.x + 3.0, FLAT, home.z)] as Array[Vector3])) as EcoHvaten
	for hv in h.anemones:
		hv.digest = 0.0
		hv.open = 1.0
	return w


func _hv(w: EcoWorld) -> EcoHvaten:
	return w.systems[1] as EcoHvaten


## Корабль над точкой p так, что она в середине луча (как в test_eco_hvaten).
func _aim(w: EcoWorld, p: Vector3, d: float = 12.0) -> void:
	var down := deg_to_rad(Searchlight.PITCH)
	var dir := Vector3(0, -sin(down), -cos(down))
	w.ship.yaw = 0.0
	w.ship.pos = p - dir * d - Searchlight.LAMP
	w.ship.light_on = true
	w.ship.light_range = Searchlight.BASE_RANGE


## Мир идёт secs секунд кадрами по 1/30 с, муть шагает за ним.
func _run(w: EcoWorld, d: EcoHvatenDust, secs: float) -> void:
	var t := 0.0
	while t < secs - 1e-6:
		w.step(1.0 / 30.0)
		d.update(_hv(w), w.time, w.ship.pos)
		t += 1.0 / 30.0


func test_beam_snap_raises_ring_at_base() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var hv := _hv(w).anemones[0]
	var d := EcoHvatenDust.new()
	d.update(_hv(w), w.time, w.ship.pos)
	_aim(w, hv.top)
	_run(w, d, 2.0)
	ok(hv.open < 0.01, "в луче спрятал щупальца")
	eq(d._made, EcoHvatenDust.SNAP_N, "рывок — один клуб из %d облачков" % EcoHvatenDust.SNAP_N)
	for p in d.dust.puffs:
		if p.born < 0.0:
			continue
		near(p.at.y, FLAT + EcoHvatenDust.BASE_LIFT, 1e-4, "у дна")
		var r := Vector2(p.at.x - hv.base.x, p.at.z - hv.base.z).length()
		ok(absf(r - EcoHvatenDust.RING) <= EcoHvatenDust.SCATTER + 1e-4, "кольцом вокруг основания (%.2f м)" % r)
		near(p.scale, EcoHvatenDust.SCALE, 1e-6, "доля размера хватня")
		ok(p.alpha > EcoHvatenDust.SNAP_ALPHA * 0.7, "клуб густой (%.2f)" % p.alpha)
		ok(p.born <= w.time, "облачко уже встало")
	# облачка клуба — по кругу, а не в одну сторону
	var dirs: Array[Vector2] = []
	for p in d.dust.puffs:
		if p.born >= 0.0:
			dirs.append(Vector2(p.at.x - hv.base.x, p.at.z - hv.base.z).normalized())
	var sum := Vector2.ZERO
	for v in dirs:
		sum += v
	ok(sum.length() < dirs.size() * 0.5, "облачка обступают основание (%.2f)" % sum.length())


func test_slow_reopen_and_closed_make_no_dust() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var hv := _hv(w).anemones[0]
	hv.open = 0.0
	var d := EcoHvatenDust.new()
	w.ship.pos = hv.base + Vector3(0, 10, 25)
	d.update(_hv(w), w.time, w.ship.pos)
	_run(w, d, 2.5)
	ok(hv.open > 0.5, "в темноте раскрылся")
	eq(d._made, 0, "раскрывается медленно — мути нет")
	hv.open = SNAP_LOW
	_aim(w, hv.top)
	d = EcoHvatenDust.new()
	d.update(_hv(w), w.time, w.ship.pos)
	_run(w, d, 1.0)
	ok(hv.open < 0.01, "спрятал")
	eq(d._made, 0, "приоткрытый хватень ила не сдувает")


const SNAP_LOW := 0.4


func test_catch_in_dark_weaker() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var hv := _hv(w).anemones[0]
	w.ship.pos = hv.base + Vector3(0, 10, 25)
	var d := EcoHvatenDust.new()
	d.update(_hv(w), w.time, w.ship.pos)
	hv.digest = EcoHvaten.DIGEST   # схватил светляка: сжимается до половины
	_run(w, d, 1.0)
	ok(not hv.lit, "без луча")
	near(hv.open, EcoHvaten.DIGEST_OPEN, 1e-3, "сжался наполовину")
	eq(d._made, EcoHvatenDust.CATCH_N, "схватил добычу — клуб меньше")
	for p in d.dust.puffs:
		if p.born >= 0.0:
			ok(p.alpha <= EcoHvatenDust.CATCH_ALPHA * 1.21, "и слабее")


func test_far_and_lite_make_no_dust() -> void:
	var w := _world()
	var hv := _hv(w).anemones[0]
	var d := EcoHvatenDust.new()
	EcoGrazerDust.lite = false
	d.update(_hv(w), 0.0, FAR)
	hv.open = 0.3
	d.update(_hv(w), 0.1, FAR)
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	var ship := hv.base + Vector3(0, 10, 25)
	EcoGrazerDust.lite = true
	hv.open = 1.0
	d.update(_hv(w), 0.2, ship)
	hv.open = 0.7
	hv.lit = true
	d.update(_hv(w), 0.3, ship)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	hv.open = 1.0
	d.update(_hv(w), 0.4, ship)
	d.update(_hv(w), 0.5, ship)
	hv.open = 0.7
	d.update(_hv(w), 0.6, ship)
	eq(d._made, EcoHvatenDust.SNAP_N, "выключатель вернули — муть есть")


## Корабль светит на хватня и уходит, снова светит — муть одна и та же при том же мире.
func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var hv := _hv(w).anemones[0]
		var d := EcoHvatenDust.new()
		d.update(_hv(w), w.time, w.ship.pos)
		for r in 2:
			_aim(w, hv.top)
			_run(w, d, 1.5)
			w.ship.light_on = false
			_run(w, d, 4.0)
		ok(d._made >= EcoHvatenDust.SNAP_N, "застал раскрытым — муть (%d)" % d._made)
		eq(d.dust.puffs.size(), EcoHvatenDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var h := _hv(w)
	var hv := h.anemones[0]
	var view := HvatenView.new(h)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть хватня в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoHvatenDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var ship := hv.base + Vector3(0, 10, 25)
	var info := EcoLink.ShipState.new()
	info.pos = ship
	view.sync(0.0, ship, false, info)
	view.sync(0.1, ship, false, info)
	hv.open = 0.6
	view.sync(0.2, ship, false, info)
	view.sync(0.8, ship, false, info)
	var seen := 0
	for n in EcoHvatenDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			ok(view.dust_buffer[i] <= EcoGrazerDust.SIZE_END * EcoHvatenDust.SCALE + 1e-5, "облачко — с размером")
			near(view.dust_buffer[i + 12], EcoHvatenDust.COLOR.r, 1e-5, "бурый ил без луча")
	ok(seen > 0, "хватень поднял муть (%d)" % seen)
	view.queue_free()
	await frames(1)
