extends TestCase
## Муть у дна от эхоловца (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): импульс сонара выдал затаившегося — он
## стряхивает ил, вокруг тела встаёт клуб; пока раскрыт, новый импульс мути не поднимает; удар по корпусу на
## выпрошенный импульс — облачка под головой; дальние от корабля и «Экономно» мути не поднимают; в сцене — свой
## MultiMesh на общем шейдере мира.

const FLAT := -46.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var b := w.add(EcoBones.new()) as EcoBones
	w.add(EcoEcho.new(b))
	return w


func _ec(w: EcoWorld) -> EcoEcho:
	return w.systems[1] as EcoEcho


## Шаг мира с импульсом сонара из точки at (корабль там).
func _ping(w: EcoWorld, d: EcoEchoDust, at: Vector3) -> void:
	w.ship.pos = at
	w.ship.sonar_ping = true
	w.ship.sonar_range = 150.0
	w.step(1.0 / 30.0)
	w.ship.sonar_ping = false
	d.update(_ec(w), w.time, w.ship.pos)


func _run(w: EcoWorld, d: EcoEchoDust, secs: float) -> void:
	var t := 0.0
	while t < secs - 1e-6:
		w.step(1.0 / 30.0)
		d.update(_ec(w), w.time, w.ship.pos)
		t += 1.0 / 30.0


func _live(d: EcoEchoDust) -> Array[EcoGrazerDust.Puff]:
	var out: Array[EcoGrazerDust.Puff] = []
	for p in d.dust.puffs:
		if p.born >= 0.0:
			out.append(p)
	return out


func _near_ship(w: EcoWorld) -> Vector3:
	return _ec(w).echo.p + Vector3(20, 10, 20)


func test_reveal_shakes_off_silt_around_body() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var ec := _ec(w).echo
	var d := EcoEchoDust.new()
	d.update(_ec(w), w.time, w.ship.pos)
	_run(w, d, 0.5)
	eq(d._made, 0, "затаился — мути нет")
	_ping(w, d, _near_ship(w))
	_run(w, d, 1.0)
	ok(ec.is_revealed(), "импульс выдал эхоловца")
	eq(d._made, EcoEchoDust.REVEAL_N, "раскрылся — один клуб из %d облачков" % EcoEchoDust.REVEAL_N)
	var inv := ec.xform().affine_inverse()
	var sum := Vector2.ZERO
	for p in _live(d):
		near(p.at.y, FLAT + EcoEchoDust.BASE_LIFT, 1e-3, "у дна под телом")
		var l := inv * Vector3(p.at.x, ec.p.y, p.at.z)
		var e := Vector2(l.x / EcoEchoDust.RING.x, l.z / EcoEchoDust.RING.y).length()
		ok(absf(e - 1.0) <= EcoEchoDust.SCATTER + 1e-3, "овалом вокруг тела (%.2f)" % e)
		ok(absf(l.x) > EchoView.FRONT[1].x or absf(l.z) > 1.5, "за краем тела")
		near(p.scale, EcoEchoDust.SCALE, 1e-6, "доля размера эхоловца")
		ok(p.alpha > EcoEchoDust.REVEAL_ALPHA * 0.7, "клуб густой (%.2f)" % p.alpha)
		ok(p.born <= w.time, "облачко уже встало")
		sum += Vector2(l.x, l.z).normalized()
	ok(sum.length() < EcoEchoDust.REVEAL_N * 0.5, "облачка обступают тело (%.2f)" % sum.length())


func test_no_new_dust_while_revealed() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var d := EcoEchoDust.new()
	d.update(_ec(w), w.time, w.ship.pos)
	_ping(w, d, _near_ship(w))
	_run(w, d, 10.0)
	_ping(w, d, _near_ship(w))
	_run(w, d, 1.0)
	eq(d._made, EcoEchoDust.REVEAL_N, "уже раскрыт — второй импульс ила не поднимает")
	_run(w, d, EcoEcho.REVEAL_T)
	ok(not _ec(w).echo.is_revealed(), "снова затаился")
	_ping(w, d, _near_ship(w))
	_run(w, d, 0.5)
	eq(d._made, EcoEchoDust.REVEAL_N * 2, "затаился и снова выдан — снова клуб")


func test_strike_raises_dust_under_head() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var sys := _ec(w)
	var ec := sys.echo
	var d := EcoEchoDust.new()
	w.ship.pos = _near_ship(w)
	d.update(sys, w.time, w.ship.pos)
	sys.fake(w, EcoEcho.ASK_PING)
	w.take_link()
	_ping(w, d, w.ship.pos)
	_run(w, d, 1.0)
	eq(ec.strikes, 1, "выпрошенный импульс — удар по корпусу")
	ok(not ec.is_revealed(), "удар не раскрывает")
	eq(d._made, EcoEchoDust.STRIKE_N, "удар — %d облачка" % EcoEchoDust.STRIKE_N)
	var inv := ec.xform().affine_inverse()
	for p in _live(d):
		var l := inv * Vector3(p.at.x, ec.p.y, p.at.z)
		ok(l.z > 1.5, "впереди тела, под головой (%.2f)" % l.z)
		ok(absf(l.x) <= EcoEchoDust.SPREAD + 1e-3, "вразброс вбок (%.2f)" % l.x)
		ok(p.alpha <= EcoEchoDust.STRIKE_ALPHA * 1.21, "слабее раскрытия (%.2f)" % p.alpha)


func test_far_and_lite_make_no_dust() -> void:
	var w := _world()
	var sys := _ec(w)
	var d := EcoEchoDust.new()
	EcoGrazerDust.lite = false
	d.update(sys, 0.0, FAR)
	sys.echo.revealed = 10.0
	d.update(sys, 0.1, FAR)
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	var ship := _near_ship(w)
	EcoGrazerDust.lite = true
	sys.echo.revealed = 0.0
	d.update(sys, 0.2, ship)
	sys.echo.revealed = 10.0
	d.update(sys, 0.3, ship)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	sys.echo.revealed = 0.0
	d.update(sys, 0.4, ship)
	sys.echo.revealed = 10.0
	d.update(sys, 0.5, ship)
	eq(d._made, EcoEchoDust.REVEAL_N, "выключатель вернули — муть есть")


func test_same_world_same_dust() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var d := EcoEchoDust.new()
		d.update(_ec(w), w.time, w.ship.pos)
		for r in 2:
			_ping(w, d, _near_ship(w))
			_run(w, d, EcoEcho.REVEAL_T + 1.0)
		eq(d._made, EcoEchoDust.REVEAL_N * 2, "два раскрытия — два клуба")
		eq(d.dust.puffs.size(), EcoEchoDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var sys := _ec(w)
	var view := EchoView.new(sys)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть эхоловца в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoEchoDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var ship := _near_ship(w)
	var info := EcoLink.ShipState.new()
	info.pos = ship
	view.sync(0.0, ship, info)
	sys.echo.revealed = EcoEcho.REVEAL_T
	view.sync(0.1, ship, info)
	view.sync(0.8, ship, info)
	var seen := 0
	for n in EcoEchoDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			ok(view.dust_buffer[i] <= EcoGrazerDust.SIZE_END * EcoEchoDust.SCALE + 1e-5, "облачко — с размером")
			near(view.dust_buffer[i + 12], EcoEchoDust.COLOR.r, 1e-5, "серо-зелёный ил без луча")
	eq(seen, EcoEchoDust.REVEAL_N, "эхоловец поднял муть")
	view.queue_free()
	await frames(1)
