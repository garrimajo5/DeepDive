extends TestCase
## Муть у волнолиста (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): луч разворачивает куст — листья стряхивают ил
## облачками у кончиков; стая у раскрытого куста клюёт моллюсков — облачка у моллюсков на дне; свёрнутый куст и
## стаи вдали мути не поднимают; дальние от корабля и «Экономно» — тоже; в сцене — свой MultiMesh на общем шейдере.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const STEP := 1.0 / 30.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Ровное дно, светляки, одна куртина волнолиста у дома стаи 0.
func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var home := EcoFish.HOMES[0]
	w.add(EcoFern.new(f, [Vector2(home.x + 20.0, home.z)] as Array[Vector2]))
	return w


func _fern(w: EcoWorld) -> EcoFern:
	return w.systems[1] as EcoFern


## Корабль над точкой p так, что она в середине луча (как в test_eco_hvaten).
func _aim(w: EcoWorld, p: Vector3, d: float = 12.0) -> void:
	var down := deg_to_rad(Searchlight.PITCH)
	var dir := Vector3(0, -sin(down), -cos(down))
	w.ship.yaw = 0.0
	w.ship.pos = p - dir * d - Searchlight.LAMP
	w.ship.light_on = true
	w.ship.light_range = Searchlight.BASE_RANGE


## Стаи — далеко от куртины и спокойны (их не тянет к кустам).
func _shoals_away(w: EcoWorld) -> void:
	for sh in _fern(w).fish.shoals:
		sh.center = Vector3(-300, -30, -300)
		sh.home = sh.center
		sh.goal = sh.center


## Остальные кусты куртины — в сторону (на 60 м): считаем облачка одного куста.
func _alone(w: EcoWorld) -> void:
	for fe in _fern(w).ferns:
		if fe.index > 0:
			fe.pos += Vector3(60, 0, 0)
			fe.top += Vector3(60, 0, 0)


func _run(w: EcoWorld, d: EcoFernDust, secs: float) -> void:
	var t := 0.0
	while t < secs - 1e-6:
		w.step(STEP)
		d.update(_fern(w), w.time, w.ship.pos, w.ground)
		t += STEP


func test_unfurl_shakes_silt_off_leaf_tips() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	_shoals_away(w)
	_alone(w)
	var fe := _fern(w).ferns[0]
	var d := EcoFernDust.new()
	d.update(_fern(w), w.time, w.ship.pos, w.ground)
	_aim(w, fe.top)
	_run(w, d, 0.5)
	eq(d._made, 0, "ещё не развернулся — мути нет")
	_run(w, d, 1.0)
	ok(fe.open >= EcoFernDust.UNFURL, "в луче развернулся (%.2f)" % fe.open)
	var mine := 0
	for p in d.dust.puffs:
		if p.born < 0.0:
			continue
		var r := Vector2(p.at.x - fe.pos.x, p.at.z - fe.pos.z).length()
		mine += 1
		ok(p.at.y > fe.pos.y + 0.4 * fe.scale, "у кончика листа, не на дне (%.2f м)" % (p.at.y - fe.pos.y))
		ok(r > 0.15 * fe.scale and r < 1.2 * fe.scale, "у кончика, у своего куста (%.2f м)" % r)
		ok(p.scale <= EcoFernDust.UNFURL_SCALE * 1.16, "облачко мелкое")
		ok(p.born <= w.time, "облачко уже встало")
	eq(mine, EcoFernDust.UNFURL_N, "один куст — %d облачка" % EcoFernDust.UNFURL_N)
	var before := d._made
	_run(w, d, 3.0)
	eq(d._made, before, "раскрытый куст снова ила не стряхивает")


func test_closed_fern_and_far_shoals_make_no_dust() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	_shoals_away(w)
	var fe := _fern(w).ferns[0]
	w.ship.pos = fe.pos + Vector3(0, 10, 30)
	var d := EcoFernDust.new()
	d.update(_fern(w), w.time, w.ship.pos, w.ground)
	_run(w, d, 3.0)
	eq(d._made, 0, "без луча куст свёрнут — мути нет")
	for f in _fern(w).ferns:
		f.open = 1.0
		f.lit_t = 100.0
	_run(w, d, 0.1)
	eq(d._made, _fern(w).ferns.size() * EcoFernDust.UNFURL_N, "развернулись — стряхнули ил")
	var before := d._made
	_run(w, d, 3.0)
	eq(d._made, before, "раскрыт, но рыб рядом нет — больше мути нет")


func test_shoal_pecks_mollusks() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var fern := _fern(w)
	_shoals_away(w)
	var fe := fern.ferns[0]
	w.ship.pos = fe.pos + Vector3(0, 10, 30)
	var d := EcoFernDust.new()
	fe.open = 1.0   # уже раскрыт: листья ил не стряхивают, муть — только от рыб
	d.update(fern, w.time, w.ship.pos, w.ground)
	var sh := fern.fish.shoals[0]
	var secs := 6.0
	var t := 0.0
	while t < secs - 1e-6:
		fe.open = 1.0
		fe.lit_t = 100.0
		sh.center = fe.top + Vector3(1.0, 0.5, 0.0)   # стая держится у куста
		w.step(STEP)
		sh.center = fe.top + Vector3(1.0, 0.5, 0.0)
		d.update(fern, w.time, w.ship.pos, w.ground)
		t += STEP
	ok(EcoFernDust.feeding(fern, fe), "стая у раскрытого куста клюёт")
	var n := 0
	for p in d.dust.puffs:
		if p.born < 0.0:
			continue
		var r := Vector2(p.at.x - fe.pos.x, p.at.z - fe.pos.z).length()
		if r > 1.0:
			continue
		n += 1
		near(p.at.y, FLAT + 0.02 + EcoFernDust.FEED_LIFT, 1e-4, "у моллюска на дне")
		near(r, EcoFern.SHELL_R * fe.scale, 1e-3, "там, где лежит моллюск")
		ok(p.alpha <= EcoFernDust.FEED_ALPHA * 1.21, "облачко слабое")
	var lo := int(secs / (EcoFernDust.FEED_EVERY * (1.0 + EcoFernDust.RATE_SPREAD))) - 1
	var hi := int(secs / (EcoFernDust.FEED_EVERY * (1.0 - EcoFernDust.RATE_SPREAD))) + 1
	ok(n >= lo and n <= hi, "клюют раз в ~%.1f с (%d за %.0f с)" % [EcoFernDust.FEED_EVERY, n, secs])
	sh.alarm = 1.0
	ok(not EcoFernDust.feeding(fern, fe), "стая в тревоге не клюёт")


func test_far_and_lite_make_no_dust() -> void:
	var w := _world()
	var fern := _fern(w)
	var fe := fern.ferns[0]
	var d := EcoFernDust.new()
	EcoGrazerDust.lite = false
	d.update(fern, 0.0, FAR)
	fe.open = 0.6
	d.update(fern, 0.1, FAR)
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	var ship := fe.pos + Vector3(0, 10, 25)
	EcoGrazerDust.lite = true
	fe.open = 0.2
	d.update(fern, 0.2, ship)
	fe.open = 0.6
	d.update(fern, 0.3, ship)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	fe.open = 0.2
	d.update(fern, 0.4, ship)
	fe.open = 0.6
	d.update(fern, 0.5, ship)
	eq(d._made, EcoFernDust.UNFURL_N, "выключатель вернули — муть есть")


## Корабль светит на куртину и уходит, снова светит — муть одна и та же при том же мире.
func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var fe := _fern(w).ferns[0]
		var d := EcoFernDust.new()
		d.update(_fern(w), w.time, w.ship.pos, w.ground)
		for r in 2:
			_aim(w, fe.top)
			_run(w, d, 2.0)
			w.ship.light_on = false
			_run(w, d, 12.0)
		ok(d._made >= EcoFernDust.UNFURL_N, "развернулся — муть (%d)" % d._made)
		eq(d.dust.puffs.size(), EcoFernDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var fern := _fern(w)
	var fe := fern.ferns[0]
	var view := FernView.new(fern, w.ground)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть волнолиста в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoFernDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var info := EcoLink.ShipState.new()
	info.pos = fe.pos + Vector3(0, 10, 25)
	view.sync(0.0, info)
	view.sync(0.1, info)
	fe.open = 0.6
	view.sync(0.2, info)
	view.sync(0.8, info)
	var seen := 0
	for n in EcoFernDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			near(view.dust_buffer[i + 12], EcoFernDust.COLOR.r, 1e-5, "зелёно-бурый ил без луча")
	eq(seen, EcoFernDust.UNFURL_N, "куст стряхнул ил (%d)" % seen)
	view.queue_free()
	await frames(1)
