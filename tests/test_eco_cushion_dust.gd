extends TestCase
## Муть у дна от подушечника (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): корабль задел подушку — она сжимается,
## и вокруг основания встаёт густой клуб ила; нырнула напуганная стая — клуб слабее; пока подушка набирает чернила,
## новой мути нет; дальние от корабля и «Экономно» мути не поднимают; в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const SPOT := Vector3(0, FLAT, 0)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Ровное дно, корабль далеко, одна подушка в SPOT (как test_eco_cushion).
func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoCushion.new(null, [SPOT] as Array[Vector3]))
	return w


func _cu(w: EcoWorld) -> EcoCushion:
	return w.systems[0] as EcoCushion


## Мир идёт secs секунд кадрами по 1/30 с, муть шагает за ним.
func _run(w: EcoWorld, d: EcoCushionDust, secs: float) -> void:
	var t := 0.0
	while t < secs - 1e-6:
		w.step(1.0 / 30.0)
		d.update(_cu(w), w.time, w.ship.pos)
		t += 1.0 / 30.0


## Корабль над подушкой: задевает.
func _touch(w: EcoWorld) -> void:
	var cu := _cu(w).cushions[0]
	w.ship.pos = cu.top + Vector3(2.0, 2.0, 0.0)


func _live(d: EcoCushionDust) -> Array[EcoGrazerDust.Puff]:
	var out: Array[EcoGrazerDust.Puff] = []
	for p in d.dust.puffs:
		if p.born >= 0.0:
			out.append(p)
	return out


func test_ship_touch_raises_ring_at_base() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var cu := _cu(w).cushions[0]
	var d := EcoCushionDust.new()
	d.update(_cu(w), w.time, w.ship.pos)
	_touch(w)
	_run(w, d, 1.0)
	ok(cu.squeeze > 0.8, "корабль задел — подушка сжалась")
	eq(d._made, EcoCushionDust.SHIP_N, "одно сжатие — один клуб из %d облачков" % EcoCushionDust.SHIP_N)
	var sum := Vector2.ZERO
	for p in _live(d):
		near(p.at.y, cu.base.y + EcoCushionDust.BASE_LIFT, 1e-4, "у дна, под облаком чернил")
		ok(p.at.y < cu.ink_c.y - 1.0, "ниже чернил")
		var v := Vector2(p.at.x - cu.base.x, p.at.z - cu.base.z)
		ok(absf(v.length() - EcoCushionDust.RING) <= EcoCushionDust.SCATTER + 1e-4,
				"кольцом вокруг основания (%.2f м)" % v.length())
		ok(v.length() > CushionView.SHAPE.x, "за краем подушки")
		near(p.scale, EcoCushionDust.SCALE, 1e-6, "доля размера подушки")
		ok(p.alpha > EcoCushionDust.SHIP_ALPHA * 0.7, "клуб густой (%.2f)" % p.alpha)
		ok(p.born <= w.time, "облачко уже встало")
		sum += v.normalized()
	ok(sum.length() < EcoCushionDust.SHIP_N * 0.5, "облачка обступают основание (%.2f)" % sum.length())


func test_no_dust_while_recharging() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var d := EcoCushionDust.new()
	d.update(_cu(w), w.time, w.ship.pos)
	_touch(w)
	_run(w, d, 20.0)
	eq(d._made, EcoCushionDust.SHIP_N, "корабль стоит над подушкой — пока набирает чернила, мути нет")
	_run(w, d, EcoCushion.RECHARGE - 20.0 + 1.0)
	eq(d._made, EcoCushionDust.SHIP_N * 2, "набрала и снова сжалась — снова клуб")


func test_fish_dive_weaker() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var cu := _cu(w).cushions[0]
	w.ship.pos = cu.base + Vector3(0, 10, 25)
	var d := EcoCushionDust.new()
	d.update(_cu(w), w.time, w.ship.pos)
	_cu(w).squeeze(w, cu, false)   # напуганная стая нырнула в подушку
	_run(w, d, 1.0)
	eq(d._made, EcoCushionDust.FISH_N, "стая — клуб меньше")
	for p in _live(d):
		ok(p.alpha <= EcoCushionDust.FISH_ALPHA * 1.21, "и слабее (%.2f)" % p.alpha)


func test_far_and_lite_make_no_dust() -> void:
	var w := _world()
	var cu := _cu(w).cushions[0]
	var d := EcoCushionDust.new()
	EcoGrazerDust.lite = false
	d.update(_cu(w), 0.0, FAR)
	cu.squeeze = 1.0
	d.update(_cu(w), 0.1, FAR)
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	var ship := cu.top + Vector3(2, 2, 0)
	EcoGrazerDust.lite = true
	cu.squeeze = 0.0
	d.update(_cu(w), 0.2, ship)
	cu.squeeze = 1.0
	d.update(_cu(w), 0.3, ship)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	cu.squeeze = 0.5
	d.update(_cu(w), 0.4, ship)
	cu.squeeze = 1.0
	d.update(_cu(w), 0.5, ship)
	eq(d._made, EcoCushionDust.SHIP_N, "выключатель вернули — муть есть")


## Корабль задевает подушку дважды — муть одна и та же при том же мире.
func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var d := EcoCushionDust.new()
		d.update(_cu(w), w.time, w.ship.pos)
		for r in 2:
			_touch(w)
			_run(w, d, 2.0)
			w.ship.pos = FAR
			_run(w, d, EcoCushion.RECHARGE)
		eq(d._made, EcoCushionDust.SHIP_N * 2, "два касания — два клуба")
		eq(d.dust.puffs.size(), EcoCushionDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var c := _cu(w)
	var cu := c.cushions[0]
	var view := CushionView.new(c)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть подушечника в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoCushionDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var ship := cu.top + Vector3(2, 2, 0)
	var info := EcoLink.ShipState.new()
	info.pos = ship
	view.sync(0.0, ship, info)
	c.squeeze(w, cu, true)
	view.sync(0.1, ship, info)
	view.sync(0.8, ship, info)
	var seen := 0
	for n in EcoCushionDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			ok(view.dust_buffer[i] <= EcoGrazerDust.SIZE_END * EcoCushionDust.SCALE + 1e-5, "облачко — с размером")
			near(view.dust_buffer[i + 12], EcoCushionDust.COLOR.r, 1e-5, "розово-бурый ил без луча")
	eq(seen, EcoCushionDust.SHIP_N, "подушка подняла муть")
	view.queue_free()
	await frames(1)
