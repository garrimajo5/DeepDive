extends TestCase
## Муть у дна от броска серпохвоста (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): быстрый хищник у самого дна
## взбивает хвостом ил позади тела, ниже — гуще и чаще; патруль, высоко над дном, вдали от корабля и «Экономно» —
## мути нет; в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world(ship: Vector3 = FAR) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = ship
	w.add(EcoPred.new())
	return w


func _preds(w: EcoWorld) -> EcoPred:
	return w.systems[0] as EcoPred


## Поставить хищника pr на высоту h над дном, плывущим по +X со скоростью speed.
func _put(pr: EcoPred.Pred, h: float, speed: float) -> void:
	pr.agent.p = Vector3(0, FLAT + h, 0)
	pr.agent.v = Vector3(speed, 0, 0)
	pr.look = Vector3(1, 0, 0)


## Только муть (мир стоит): хищник держит место и скорость, время идёт шагом 0,05 с.
func _tick(d: EcoPredDust, pr_sys: EcoPred, ship: Vector3, t0: float, secs: float) -> float:
	var t := t0
	while t < t0 + secs - 1e-6:
		t += EcoWorld.MAX_STEP
		d.update(pr_sys, t, ship, _flat)
	return t


func _newest(d: EcoPredDust) -> EcoGrazerDust.Puff:
	var best: EcoGrazerDust.Puff = null
	for p in d.dust.puffs:
		if best == null or p.born > best.born:
			best = p
	return best


func test_strength_fast_and_low_only() -> void:
	var w := _world()
	var pr := _preds(w).all[0]
	_put(pr, 2.0, EcoPred.PATROL_SPEED)
	eq(EcoPredDust.strength(pr, _flat), 0.0, "патруль у дна — мути нет")
	_put(pr, 7.0, EcoPred.CHARGE_SPEED)
	eq(EcoPredDust.strength(pr, _flat), 0.0, "бросок высоко над дном — мути нет")
	_put(pr, pr.agent.clearance, EcoPred.CHARGE_SPEED)
	near(EcoPredDust.strength(pr, _flat), 1.0, 1e-5, "бросок у самого дна — в полную силу")
	_put(pr, EcoPredDust.LOW - 0.01, EcoPred.HUNT_SPEED)
	near(EcoPredDust.strength(pr, _flat), EcoPredDust.MIN_K, 0.01, "у верхней границы — слабо")
	eq(EcoPredDust.strength(pr, Callable()), 0.0, "без дна — мути нет")


func test_low_charge_makes_dust_behind() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var ps := _preds(w)
	var pr := ps.all[0]
	_put(pr, pr.agent.clearance, EcoPred.CHARGE_SPEED)
	var d := EcoPredDust.new()
	var ship := pr.agent.p + Vector3(20, 0, 0)
	_tick(d, ps, ship, 0.0, 2.0)
	ok(d._made >= 8 and d._made <= 13, "у самого дна облачко раз в ~0,2 с (%d за 2 с)" % d._made)
	var p := _newest(d)
	near(p.alpha, EcoPredDust.ALPHA, EcoPredDust.ALPHA * 0.21, "густо")
	ok(p.at.x < pr.agent.p.x - EcoPredDust.TAIL + EcoPredDust.SCATTER * 1.5, "позади тела, у хвоста")
	near(p.at.y, FLAT + EcoPredDust.BASE_LIFT, 1e-4, "на дне, а не у тела")
	var sides := {}
	for q in d.dust.puffs:
		if q.born > 0.0:
			sides[signf(q.at.z)] = true
	ok(sides.has(1.0) and sides.has(-1.0), "по обе стороны следа")

	var d2 := EcoPredDust.new()
	_put(pr, EcoPredDust.LOW - 0.3, EcoPred.CHARGE_SPEED)
	_tick(d2, ps, ship, 0.0, 2.0)
	ok(d2._made < d._made, "выше над дном — реже (%d < %d)" % [d2._made, d._made])
	ok(_newest(d2).alpha < p.alpha, "и бледнее")


func test_patrol_high_far_lite_no_dust() -> void:
	var w := _world()
	var ps := _preds(w)
	var pr := ps.all[0]
	var d := EcoPredDust.new()
	EcoGrazerDust.lite = false
	_put(pr, 2.0, EcoPred.PATROL_SPEED)
	_tick(d, ps, pr.agent.p, 0.0, 2.0)
	eq(d._made, 0, "патруль у дна не пылит")
	_put(pr, 2.0, EcoPred.CHARGE_SPEED)
	_tick(d, ps, FAR, 2.0, 2.0)
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	EcoGrazerDust.lite = true
	_tick(d, ps, pr.agent.p, 4.0, 2.0)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	_tick(d, ps, pr.agent.p, 6.0, 1.0)
	ok(d._made > 0, "выключатель вернули — муть есть")


## В живом мире: корабль у самого дна светит — голодный хищник бросается на него, ныряет к дну и пылит хвостом.
func test_charge_to_low_ship_stirs_silt() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var ps := _preds(w)
		var pr := ps.all[0]
		pr.hunger = 0.5
		pr.cooldown = 0.0
		pr.agent.p.y = FLAT + 4.5   # хищник уже у дна (охотился за стаей у грунта)
		w.ship.pos = Vector3(pr.agent.p.x + 30.0, FLAT + 2.5, pr.agent.p.z)
		w.ship.light_on = true
		var d := EcoPredDust.new()
		var t := 0.0
		var low := false
		while t < 10.0 and w.hits == 0:
			w.step(EcoWorld.MAX_STEP)
			d.update(ps, w.time, w.ship.pos, w.ground)
			low = low or EcoPredDust.strength(pr, w.ground) > 0.0
			t += EcoWorld.MAX_STEP
		eq(w.hits, 1, "бросок дошёл до корабля")
		ok(low, "у дна в броске")
		ok(d._made > 0, "и поднял муть (%d)" % d._made)
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_pool_bounded() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var ps := _preds(w)
	var pr := ps.all[0]
	_put(pr, pr.agent.clearance, EcoPred.CHARGE_SPEED)
	var d := EcoPredDust.new()
	_tick(d, ps, pr.agent.p, 0.0, 10.0)
	ok(d._made > EcoPredDust.POOL, "старые уступают новым (%d)" % d._made)
	eq(d.dust.puffs.size(), EcoPredDust.POOL, "пул не растёт")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var ps := _preds(w)
	var v := PredView.new(ps)
	tree.root.add_child(v)
	await frames(1)
	var dust := v.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть серпохвостов в сцене"):
		v.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoPredDust.POOL, "один MultiMesh на пул")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var pr := ps.all[0]
	var state := EcoLink.ShipState.new()
	for i in 20:
		_put(pr, pr.agent.clearance, EcoPred.CHARGE_SPEED)
		state.pos = pr.agent.p + Vector3(20, 0, 0)
		v.sync(0.05 * (i + 1), state.pos, state, Vector3.ZERO, _flat)
	var seen := 0
	for n in EcoPredDust.POOL:
		if v.dust_buffer[n * GrazerView.DUST_STRIDE + 15] > 0.0:
			seen += 1
			near(v.dust_buffer[n * GrazerView.DUST_STRIDE + 12], EcoPredDust.COLOR.r, 1e-5, "тёмный ил без луча")
	ok(seen > 0, "бросок у дна поднял муть (%d)" % seen)
	v.queue_free()
	await frames(1)
