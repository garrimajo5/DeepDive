extends TestCase
## Муть у дна от глазунов и монетников (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): бросок глазуна из песка —
## клуб кольцом у края тела; сонар рассыпал стайку — облачка из-под низко висевших рыбок, позади по ходу бегства;
## дальние от корабля и «Экономно» мути не поднимают; та же муть при том же мире; в сцене — свой MultiMesh на общем
## шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const SPOTS: Array[Vector3] = [Vector3(-60, FLAT, 0), Vector3(0, FLAT, 0), Vector3(60, FLAT, 0)]
const DT := 1.0 / 30.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var m := w.add(EcoMoss.new(SPOTS)) as EcoMoss
	w.add(EcoCoins.new(m, null, SPOTS))
	return w


func _c(w: EcoWorld) -> EcoCoins:
	return w.systems[1] as EcoCoins


## Корабль в 15 м над средней стайкой.
func _watch(w: EcoWorld) -> Vector3:
	return _c(w).schools[1].center + Vector3(0, 15, 6)


func _run(w: EcoWorld, d: EcoCoinsDust, secs: float) -> void:
	var t := 0.0
	while t < secs - 1e-6:
		w.step(DT)
		d.update(_c(w), w.time, w.ship.pos)
		t += DT


## Глазун gz стайки бросается: рыбка прямо над ним, голоден.
func _bait(c: EcoCoins, i: int) -> void:
	var sc := c.schools[i]
	var gz := sc.glazun
	gz.cd = 0.0
	var cn := sc.members[0]
	cn.pos = gz.pos + Vector3(0.3, 1.0, 0)
	cn.goal = cn.pos
	cn.goal_t = 10.0


func test_lunge_raises_sand_ring_around_body() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var c := _c(w)
	var d := EcoCoinsDust.new()
	w.ship.pos = _watch(w)
	d.update(c, w.time, w.ship.pos)
	_run(w, d, 0.5)
	eq(d.made, 0, "спокойно — мути нет")
	var gz := c.schools[1].glazun
	_bait(c, 1)
	_run(w, d, DT)
	ok(gz.lunge > 0.9, "бросился")
	eq(d.made, EcoCoinsDust.LUNGE_N, "бросок — клуб из %d облачков" % EcoCoinsDust.LUNGE_N)
	var sum := Vector2.ZERO
	var inv := Basis(Vector3.UP, gz.yaw).inverse()
	for i in EcoCoinsDust.LUNGE_N:
		var p := d.dust.puffs[i]
		var l := inv * Vector3(p.at.x - gz.pos.x, 0.0, p.at.z - gz.pos.z)
		var e := Vector2(l.x / EcoCoinsDust.RING.x, l.z / EcoCoinsDust.RING.y).length()
		ok(absf(e - 1.0) <= EcoCoinsDust.RING_SCATTER + 1e-3, "кольцом у края тела (%.2f)" % e)
		ok(Vector2(l.x / 0.45, l.z / 0.3).length() > 1.0, "снаружи тела")
		near(p.at.y, FLAT + EcoCoinsDust.BASE_LIFT, 1e-4, "у дна")
		near(p.scale, EcoCoinsDust.LUNGE_SCALE, 1e-6, "доля размера броска")
		ok(p.alpha > EcoCoinsDust.LUNGE_ALPHA * 0.79, "клуб густой (%.2f)" % p.alpha)
		ok(p.born >= w.time - DT - 1e-4 and p.born <= w.time + EcoCoinsDust.BURST_SPAN, "встают вразнобой сразу")
		sum += Vector2(l.x, l.z).normalized()
	ok(sum.length() < EcoCoinsDust.LUNGE_N * 0.5, "облачка обступают тело (%.2f)" % sum.length())
	_run(w, d, 2.0)
	eq(d.made, EcoCoinsDust.LUNGE_N, "бросок спадает — новой мути нет")


func test_lunge_far_or_lite_no_dust() -> void:
	var w := _world()
	var c := _c(w)
	var d := EcoCoinsDust.new()
	EcoGrazerDust.lite = false
	d.update(c, w.time, w.ship.pos)
	_bait(c, 1)
	_run(w, d, 0.5)
	ok(c.schools[1].glazun.lunge > 0.0, "бросился")
	eq(d.made, 0, "дальше 80 м от корабля мути нет")
	w.ship.pos = _watch(w)
	EcoGrazerDust.lite = true
	_bait(c, 0)
	c.schools[0].glazun.lunge = 0.0
	w.ship.pos = c.schools[0].center + Vector3(0, 15, 6)
	_run(w, d, 0.5)
	eq(d.made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	_bait(c, 2)
	w.ship.pos = c.schools[2].center + Vector3(0, 15, 6)
	_run(w, d, 0.5)
	eq(d.made, EcoCoinsDust.LUNGE_N, "выключатель вернули — муть есть")


func test_sonar_scatter_kicks_low_coins() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var c := _c(w)
	var d := EcoCoinsDust.new()
	w.ship.pos = _watch(w)
	_run(w, d, 1.0)
	var sc := c.schools[1]
	# две рыбки у самого мха, остальные высоко
	for k in sc.members.size():
		var cn := sc.members[k]
		cn.pos = sc.center + Vector3(-2.0 + k * 0.5, 0.5 if k < 2 else 2.5, 1.0)
		cn.goal = cn.pos
		cn.goal_t = 10.0
	var made := d.made
	w.ship.sonar_ping = true
	w.ship.sonar_range = 100.0
	w.step(DT)
	w.ship.sonar_ping = false
	d.update(c, w.time, w.ship.pos)
	ok(sc.scatter > 0.0, "рассыпалась")
	var mine: Array[EcoGrazerDust.Puff] = []
	for i in range(made, d.made):
		var p := d.dust.puffs[i % EcoCoinsDust.POOL]
		if Vector2(p.at.x - sc.center.x, p.at.z - sc.center.z).length() < 6.0:
			mine.append(p)
	eq(mine.size(), 2, "облачко из-под каждой рыбки у мха, высокие не пылят")
	for p in mine:
		near(p.at.y, FLAT + EcoCoinsDust.BASE_LIFT, 1e-4, "на дне")
		near(p.scale, EcoCoinsDust.KICK_SCALE, 1e-6, "мелкое облачко")
		ok(p.alpha <= EcoCoinsDust.KICK_ALPHA * 1.21, "слабее броска (%.2f)" % p.alpha)
	var cn0 := sc.members[0]
	var p0 := mine[0]
	var flat := Vector2(p0.at.x - cn0.pos.x, p0.at.z - cn0.pos.z)
	ok(flat.length() < EcoCoinsDust.KICK_BACK + 0.4, "под рыбкой (%.2f)" % flat.length())
	var to_threat := Vector2(sc.from.x - cn0.pos.x, sc.from.z - cn0.pos.z)
	ok(flat.dot(to_threat) > 0.0, "позади по ходу бегства")
	var after := d.made
	_run(w, d, 1.0)
	eq(d.made, after, "пока рассыпается — новой мути нет")


func test_kick_capped_per_school() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var c := _c(w)
	var d := EcoCoinsDust.new()
	w.ship.pos = _watch(w)
	_run(w, d, 0.5)
	var sc := c.schools[1]
	for cn in sc.members:
		cn.pos.y = sc.center.y + 0.5
	var made := d.made
	sc.scatter = EcoCoins.SCATTER_TIME
	sc.from = w.ship.pos
	d.update(c, w.time + DT, w.ship.pos)
	eq(d.made - made, EcoCoinsDust.KICK_MAX, "не больше %d на стайку" % EcoCoinsDust.KICK_MAX)


func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var c := _c(w)
		var d := EcoCoinsDust.new()
		w.ship.pos = _watch(w)
		d.update(c, w.time, w.ship.pos)
		_bait(c, 1)
		_run(w, d, 1.0)
		w.ship.sonar_ping = true
		w.ship.sonar_range = 100.0
		_run(w, d, DT)
		w.ship.sonar_ping = false
		_run(w, d, 2.0)
		eq(d.dust.puffs.size(), EcoCoinsDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	ok(runs[0][0][1] >= 0.0, "муть была")
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_new_run_resets() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var c := _c(w)
	var d := EcoCoinsDust.new()
	w.ship.pos = _watch(w)
	d.update(c, w.time, w.ship.pos)
	_run(w, d, 1.0)
	c.schools[1].glazun.lunge = 1.0   # будто бросок перед концом забега
	w.reset()
	d.update(c, w.time, w.ship.pos)
	eq(d.made, 0, "новый забег — первый шаг только запоминает")


func test_guest_sees_host_lunge() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var c := _c(w)
	var d := EcoCoinsDust.new()
	w.ship.pos = _watch(w)
	_run(w, d, 0.5)
	# кадр хоста: глазун средней стайки бросился, стайка рассыпается
	var host := _world()
	var hc := _c(host)
	hc.schools[1].glazun.lunge = 1.0
	hc.schools[1].scatter = EcoCoins.SCATTER_TIME
	for cn in hc.schools[1].members:
		cn.pos.y = hc.schools[1].center.y + 2.5   # высоко — не пылят
	var data := EcoLink.pack_world(host.agents, host.systems, hc.schools[1].center)
	ok(EcoLink.apply_coins(w.systems, data) >= 1, "кадр монетников принят")
	d.update(c, w.time + DT, w.ship.pos)
	eq(d.made, EcoCoinsDust.LUNGE_N, "у гостя бросок из кадра хоста — тот же клуб")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var c := _c(w)
	var view := CoinsView.new(c)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть глазунов в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoCoinsDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var info := EcoLink.ShipState.new()
	info.pos = _watch(w)
	view.sync(0.0, info)
	c.schools[1].glazun.lunge = 1.0
	view.sync(0.1, info)
	view.sync(0.5, info)
	var seen := 0
	for n in EcoCoinsDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			near(view.dust_buffer[i + 12], EcoCoinsDust.COLOR.r, 1e-5, "песок с илом без луча")
	eq(seen, EcoCoinsDust.LUNGE_N, "глазун поднял муть")
	view.sync(1.0)
	view.queue_free()
	await frames(1)
