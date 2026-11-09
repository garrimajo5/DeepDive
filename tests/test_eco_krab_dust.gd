extends TestCase
## Муть у дна от кольчужника (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): в норе мути нет, идущий краб
## поднимает облачка позади из-под ног, удирающий — чаще и гуще, раскалывая ежа — плотные облачка у клешней впереди;
## дальние от корабля и «Экономно» мути не поднимают; в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const SPOTS: Array[Vector3] = [Vector3(-60, FLAT, 0), Vector3(0, FLAT, 0)]
## Корабль в 40 м от норы: краб его видит, но нору не охраняет (GUARD_R 12 м).
const SHIP := Vector3(-20, -30, -35)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world(ship: Vector3 = SHIP) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = ship
	var k := w.add(EcoKelp.new(null, SPOTS)) as EcoKelp
	w.add(EcoKrab.new(k))
	return w


func _krab(w: EcoWorld) -> EcoKrab:
	return w.systems[1] as EcoKrab


## Прогон мира и мути шагом 0,05 с; done — когда остановиться.
func _run(w: EcoWorld, d: EcoKrabDust, secs: float, done: Callable = Callable()) -> void:
	var t := 0.0
	while t < secs:
		w.step(EcoWorld.MAX_STEP)
		d.update(_krab(w), w.time, w.ship.pos)
		t += EcoWorld.MAX_STEP
		if done.is_valid() and done.call():
			return


func _newest(d: EcoKrabDust) -> EcoGrazerDust.Puff:
	var best: EcoGrazerDust.Puff = null
	for p in d.dust.puffs:
		if best == null or p.born > best.born:
			best = p
	return best


func test_den_no_dust() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var d := EcoKrabDust.new()
	_run(w, d, 10.0)
	eq(_krab(w).crab.state, EcoKrab.State.DEN, "сытый сидит в норе")
	eq(d._made, 0, "в норе мути нет")


func test_walk_behind_crack_at_claws() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var cr := _krab(w).crab
	cr.hunger = 1.1
	var d := EcoKrabDust.new()
	_run(w, d, 3.0)
	if not ok(cr.state == EcoKrab.State.HUNT, "голодный вышел на охоту"):
		return
	ok(d._made >= 4 and d._made <= 7, "идёт: облачко раз в ~0,55 с (%d за 3 с)" % d._made)
	var p := _newest(d)
	near(p.alpha, EcoKrabDust.WALK_ALPHA, EcoKrabDust.WALK_ALPHA * 0.21, "из-под ног — слабая")
	var to := Vector2(p.at.x - cr.pos.x, p.at.z - cr.pos.z)
	ok(to.dot(Vector2(cr.dir.x, cr.dir.z)) < 0.0, "из-под ног — позади панциря")
	near(p.at.y, FLAT + EcoKrabDust.BASE_LIFT, 1e-3, "у самого дна")
	_run(w, d, 60.0, func() -> bool: return cr.state == EcoKrab.State.CRACK)
	if not ok(cr.state == EcoKrab.State.CRACK, "дошёл до ежа и колет"):
		return
	var n0 := d._made
	_run(w, d, 2.0)
	ok(d._made - n0 >= 5 and d._made - n0 <= 7, "колет: облачко раз в ~0,35 с (%d за 2 с)" % (d._made - n0))
	p = _newest(d)
	near(p.alpha, EcoKrabDust.CRACK_ALPHA, EcoKrabDust.CRACK_ALPHA * 0.21, "у клешней — гуще")
	var claw := cr.pos + Vector3(cr.dir.x, 0, cr.dir.z).normalized() * EcoKrabDust.CLAW
	ok(Vector2(p.at.x - claw.x, p.at.z - claw.z).length() <= EcoKrabDust.SCATTER * 1.5, "у клешней, впереди по курсу")


func test_scared_runs_dustier() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var kr := _krab(w)
	var cr := kr.crab
	cr.hunger = 1.1
	var d := EcoKrabDust.new()
	_run(w, d, 6.0)
	kr.scare(10.0)
	_run(w, d, 0.2)
	if not ok(cr.state == EcoKrab.State.HOME and cr.moving, "напуганный удирает в нору"):
		return
	var n0 := d._made
	_run(w, d, 1.5, func() -> bool: return not cr.moving)
	ok(d._made - n0 >= 3, "удирает — облачка чаще (%d за 1,5 с)" % (d._made - n0))
	near(_newest(d).alpha, EcoKrabDust.RUN_ALPHA, EcoKrabDust.RUN_ALPHA * 0.21, "и гуще")


func test_far_and_lite_make_no_dust() -> void:
	var w := _world(Vector3(500, -30, 500))
	_krab(w).crab.hunger = 1.1
	var d := EcoKrabDust.new()
	EcoGrazerDust.lite = false
	_run(w, d, 6.0)
	ok(_krab(w).crab.moving, "краб идёт")
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	w.ship.pos = SHIP
	EcoGrazerDust.lite = true
	_run(w, d, 4.0)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	_run(w, d, 2.0)
	ok(d._made > 0, "выключатель вернули — муть есть")


func test_pool_bounded_and_same_every_run() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		_krab(w).crab.hunger = 1.1
		var d := EcoKrabDust.new()
		_run(w, d, 30.0)
		ok(d._made > EcoKrabDust.POOL, "старые уступают новым (%d)" % d._made)
		eq(d.dust.puffs.size(), EcoKrabDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var kr := _krab(w)
	kr.crab.hunger = 1.1
	var v := KrabView.new(kr)
	tree.root.add_child(v)
	await frames(1)
	var dust := v.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть кольчужника в сцене"):
		v.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoKrabDust.POOL, "один MultiMesh на пул")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	for i in 60:
		w.step(EcoWorld.MAX_STEP)
		v.sync(w.time, w.ship, Vector3.ZERO)
	var seen := 0
	for n in EcoKrabDust.POOL:
		if v.dust_buffer[n * GrazerView.DUST_STRIDE + 15] > 0.0:
			seen += 1
			ok(v.dust_buffer[n * GrazerView.DUST_STRIDE] > 0.0, "видимое облачко — с размером")
			near(v.dust_buffer[n * GrazerView.DUST_STRIDE + 12], EcoKrabDust.COLOR.r, 1e-5, "бурая муть краба без луча")
	ok(seen > 0, "идущий краб поднял муть (%d)" % seen)
	v.queue_free()
	await frames(1)


## Сетка дна между вершинами бывает выше точного дна мира: облачко поднимается над ней, чтобы нижняя половина
## не пряталась под дном (видно на снимке у норы кольчужника).
func test_puff_above_visible_floor() -> void:
	near(EcoGrazerDust.above(-41.0, 1.0, -42.0), -41.0, 1e-6, "высоко над дном — как было")
	near(EcoGrazerDust.above(-41.0, 1.0, -41.2), -41.2 + EcoGrazerDust.CLEAR, 1e-6, "у дна — над сеткой на долю размера")
	var d := EcoGrazerDust.new(1)
	d.add(Vector3(3, -41.0, 4), 0.0, 0.4, 1)
	var high := func(_x: float, _z: float) -> float: return -40.9
	var buf := GrazerView.pack_dust(d, 1.0, Vector3.ZERO, null, EcoKrabDust.COLOR, EcoKrabDust.LIT, high)
	var s := EcoGrazerDust.size(d.puffs[0], 1.0)
	near(buf[7], -40.9 + s * EcoGrazerDust.CLEAR, 1e-5, "в буфере — над видимым дном")
	var free := GrazerView.pack_dust(d, 1.0, Vector3.ZERO)
	near(free[7], EcoGrazerDust.pos(d.puffs[0], 1.0, Vector3.ZERO).y, 1e-5, "без сетки дна — как поднято")
