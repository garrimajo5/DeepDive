extends TestCase
## Муть у дна от шипоежей (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): ёж, что грызёт ленту, поднимает у стебля
## маленькие облачка, ползущий — слабее позади, бредущий — реже; съеденный и стоящий — нет; облачка втрое меньше,
## чем у скребуна; дальние от корабля и «Экономно» мути не поднимают; в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const SPOTS: Array[Vector3] = [Vector3(0, FLAT, 0), Vector3(60, FLAT, 0)]
const SHIP := Vector3(0, -30, -20)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world(ship: Vector3 = SHIP) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = ship
	w.add(EcoKelp.new(null, SPOTS))
	return w


func _kelp(w: EcoWorld) -> EcoKelp:
	return w.systems[0] as EcoKelp


## Поставить ежа u рядом с лентой k своей рощи на расстоянии dist (по −X от ленты).
func _at_stalk(kelp: EcoKelp, u: EcoKelp.Urchin, k: int, dist: float) -> EcoKelp.Stalk:
	var s := kelp.groves[u.grove].stalks[k]
	u.alive = true
	u.goal = k
	u.pos = Vector3(s.pos.x - dist, FLAT + EcoKelp.UP, s.pos.z)
	return s


## Только муть (мир стоит): ежи держат место и цель, время идёт шагом 0,05 с.
func _tick(d: EcoUrchinDust, kelp: EcoKelp, ship: Vector3, t0: float, secs: float) -> float:
	var t := t0
	while t < t0 + secs - 1e-6:
		t += EcoWorld.MAX_STEP
		d.update(kelp, t, ship)
	return t


## Все ежи, кроме u, съедены — мутит только он.
func _only(kelp: EcoKelp, u: EcoKelp.Urchin) -> void:
	for o in kelp.urchins:
		if o != u:
			o.alive = false
			o.respawn = 999.0


func test_mode_by_what_urchin_does() -> void:
	var kelp := _kelp(_world())
	var u := kelp.urchins[0]
	_at_stalk(kelp, u, 3, 0.2)
	eq(EcoUrchinDust.mode(kelp, u), 3, "у ленты — грызёт")
	_at_stalk(kelp, u, 3, 2.0)
	eq(EcoUrchinDust.mode(kelp, u), 2, "лента далеко — ползёт к ней")
	var s := _at_stalk(kelp, u, 3, 0.2)
	s.f = EcoKelp.F_MIN
	eq(EcoUrchinDust.mode(kelp, u), 0, "лента объедена до стебля — грызть нечего")
	u.goal = -1
	u.wander = u.pos + Vector3(3, 0, 0)
	eq(EcoUrchinDust.mode(kelp, u), 1, "без цели — бредёт")
	u.wander = u.pos
	eq(EcoUrchinDust.mode(kelp, u), 0, "добрёл и стоит — мути нет")
	u.wander = u.pos + Vector3(3, 0, 0)
	u.alive = false
	eq(EcoUrchinDust.mode(kelp, u), 0, "съеденный — мути нет")


func test_eating_puffs_at_stalk_small() -> void:
	EcoGrazerDust.lite = false
	var kelp := _kelp(_world())
	var u := kelp.urchins[0]
	_only(kelp, u)
	var s := _at_stalk(kelp, u, 5, 0.3)
	var d := EcoUrchinDust.new()
	_tick(d, kelp, SHIP, 0.0, 6.0)
	ok(d._made >= 3 and d._made <= 5, "грызёт — облачко раз в ~1,5 с (%d за 6 с)" % d._made)
	var p: EcoGrazerDust.Puff = null
	for q in d.dust.puffs:
		if p == null or q.born > p.born:
			p = q
	ok(p.at.x > u.pos.x, "облачко у стебля, а не позади ежа")
	ok(p.at.x < s.pos.x + EcoUrchinDust.SCATTER, "не дальше ленты")
	near(p.at.y, FLAT + EcoUrchinDust.BASE_LIFT, 1e-4, "у самого дна")
	near(p.scale, EcoUrchinDust.SCALE, 1e-6, "облачко ежа — малое")
	near(EcoGrazerDust.size(p, p.born + EcoGrazerDust.LIFE), EcoGrazerDust.SIZE_END * EcoUrchinDust.SCALE, 1e-4,
		"растёт до доли размера облачка скребуна")
	near(p.alpha, EcoUrchinDust.EAT_ALPHA, EcoUrchinDust.EAT_ALPHA * 0.21, "у стебля — гуще")


func test_crawl_behind_and_rarer() -> void:
	EcoGrazerDust.lite = false
	var kelp := _kelp(_world())
	var u := kelp.urchins[0]
	_only(kelp, u)
	_at_stalk(kelp, u, 5, 3.0)
	var d := EcoUrchinDust.new()
	_tick(d, kelp, SHIP, 0.0, 9.0)
	ok(d._made >= 3 and d._made <= 5, "ползёт — облачко раз в ~2,2 с (%d за 9 с)" % d._made)
	for q in d.dust.puffs:
		if q.born > 0.0:
			ok(q.at.x < u.pos.x, "из-под игл позади ежа")
			ok(q.alpha < EcoUrchinDust.EAT_ALPHA * 0.8, "слабее, чем у стебля")


func test_far_and_lite_make_no_dust() -> void:
	var kelp := _kelp(_world())
	var u := kelp.urchins[0]
	_only(kelp, u)
	_at_stalk(kelp, u, 5, 0.3)
	var d := EcoUrchinDust.new()
	EcoGrazerDust.lite = false
	var t := _tick(d, kelp, Vector3(500, -30, 500), 0.0, 5.0)
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	EcoGrazerDust.lite = true
	t = _tick(d, kelp, SHIP, t, 5.0)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	_tick(d, kelp, SHIP, t, 3.0)
	ok(d._made > 0, "выключатель вернули — муть есть")


func test_world_run_bounded_and_same_every_run() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var d := EcoUrchinDust.new()
		var t := 0.0
		while t < 40.0:
			w.step(EcoWorld.MAX_STEP)
			d.update(_kelp(w), w.time, w.ship.pos)
			t += EcoWorld.MAX_STEP
		ok(d._made > EcoUrchinDust.POOL, "14 ежей мутят, старые уступают новым (%d)" % d._made)
		eq(d.dust.puffs.size(), EcoUrchinDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_grazer_puff_size_unchanged() -> void:
	var d := EcoGrazerDust.new(1)
	var p := d.add(Vector3.ZERO, 0.0, 0.5, 1)
	near(p.scale, 1.0, 1e-6, "облачко скребуна — в полный размер")
	near(EcoGrazerDust.size(p, EcoGrazerDust.LIFE), EcoGrazerDust.SIZE_END, 1e-5, "как было")
	near(EcoGrazerDust.pos(p, EcoGrazerDust.LIFE, Vector3.ZERO).y, EcoGrazerDust.RISE, 1e-5, "подъём как был")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var kelp := _kelp(w)
	var v := KelpView.new(kelp)
	tree.root.add_child(v)
	await frames(1)
	var dust := v.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть ежей в сцене"):
		v.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoUrchinDust.POOL, "один MultiMesh на пул")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	for i in 100:
		w.step(EcoWorld.MAX_STEP)
		v.sync(w.time, w.ship, Vector3.ZERO)
	var seen := 0
	for n in EcoUrchinDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if v.dust_buffer[i + 15] > 0.0:
			seen += 1
			ok(v.dust_buffer[i] > 0.0 and v.dust_buffer[i] <= EcoGrazerDust.SIZE_END * EcoUrchinDust.SCALE + 1e-5,
				"видимое облачко — малое, с размером")
			near(v.dust_buffer[i + 12], EcoUrchinDust.COLOR.r, 1e-5, "бурый ил без луча")
	ok(seen > 0, "ежи подняли муть (%d)" % seen)
	v.queue_free()
	await frames(1)
