extends TestCase
## Муть у дна от светляков-полосников (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): стая всполошилась —
## облачка из-под хвостов рыбок, что шли у дна; забилась в коралл у дома — клуб у дна под домом; стаи кроны,
## высокий дом, дальние от корабля и «Экономно» мути не поднимают; та же муть при том же мире; у гостя — по тревоге
## из кадра хоста; в сцене — свой MultiMesh на общем шейдере мира.

## Дно под домом первой стаи рифа (дом — на 3,5 м выше).
const FLAT := -36.5888
const FAR := Vector3(500, -30, 500)
const DT := 1.0 / 30.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoFish.new())
	return w


func _f(w: EcoWorld) -> EcoFish:
	return w.systems[0] as EcoFish


## Стаю sh увести от дома на 10 м вбок; рыбок — на высоту lift над дном.
func _move(sh: EcoFish.Shoal, lift: float, dx := 10.0) -> void:
	for f: EcoFish.Fish in sh.members:
		f.agent.p = Vector3(sh.home.x + dx + (f.slot % 5) * 0.6, FLAT + lift, sh.home.z + (f.slot / 5) * 0.6)
		f.agent.v = Vector3(1.0, 0.0, 0.0)
	_center(sh)


static func _center(sh: EcoFish.Shoal) -> void:
	var c := Vector3.ZERO
	for f: EcoFish.Fish in sh.members:
		c += f.agent.p
	sh.center = c / sh.members.size()


func test_alarm_kicks_low_fish() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var fish := _f(w)
	var sh := fish.shoals[0]
	var d := EcoFishDust.new()
	_move(sh, 1.0)
	var ship := sh.center + Vector3(0, 12, 0)
	d.update(fish, 0.0, ship, _flat)
	d.update(fish, DT, ship, _flat)
	eq(d.made, 0, "спокойно — мути нет")
	sh.alarm = 3.0
	d.update(fish, 2.0 * DT, ship, _flat)
	eq(d.made, EcoFishDust.KICK_MAX, "всполошились у дна — по облачку из-под хвоста, не больше %d" % EcoFishDust.KICK_MAX)
	for i in d.made:
		var p := d.dust.puffs[i]
		near(p.at.y, FLAT + EcoFishDust.BASE_LIFT, 1e-4, "у дна")
		var f: EcoFish.Fish = sh.members[i]
		near(p.at.x, f.agent.p.x - EcoFishDust.KICK_BACK, 1e-4, "позади рыбки против хода")
		near(p.at.z, f.agent.p.z, 1e-4, "под рыбкой")
		ok(p.born >= 2.0 * DT - 1e-6 and p.born <= 2.0 * DT + EcoFishDust.KICK_SPAN, "бьют хвостом вразнобой")
		ok(p.scale < EcoFishDust.KICK_SCALE * 1.16, "облачко маленькое")
	d.update(fish, 3.0 * DT, ship, _flat)
	eq(d.made, EcoFishDust.KICK_MAX, "тревога держится — новой мути нет")
	sh.alarm = 0.0
	d.update(fish, 4.0 * DT, ship, _flat)
	sh.alarm = 1.5
	d.update(fish, 5.0 * DT, ship, _flat)
	eq(d.made, 2 * EcoFishDust.KICK_MAX, "успокоились и снова всполошились — снова муть")


func test_high_fish_no_kick() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var fish := _f(w)
	var sh := fish.shoals[0]
	var d := EcoFishDust.new()
	_move(sh, EcoFishDust.KICK_H + 0.5)
	var ship := sh.center + Vector3(0, 12, 0)
	d.update(fish, 0.0, ship, _flat)
	sh.alarm = 3.0
	d.update(fish, DT, ship, _flat)
	eq(d.made, 0, "высоко над дном — хвостом ила не достать")


func test_hide_in_coral_raises_ring() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var fish := _f(w)
	var sh := fish.shoals[0]
	var d := EcoFishDust.new()
	_move(sh, 4.0)
	var ship := sh.home + Vector3(0, 15, 0)
	d.update(fish, 0.0, ship, _flat)
	sh.alarm = 3.0
	d.update(fish, DT, ship, _flat)
	eq(d.made, 0, "всполошились высоко и далеко от дома — мути нет")
	for f: EcoFish.Fish in sh.members:
		f.agent.p.x -= 10.0
	_center(sh)
	ok(EcoFishDust.hiding(sh), "добрались до дома")
	d.update(fish, 2.0 * DT, ship, _flat)
	eq(d.made, EcoFishDust.HIDE_N, "забились в коралл — клуб из %d облачков" % EcoFishDust.HIDE_N)
	var sum := Vector2.ZERO
	for i in EcoFishDust.HIDE_N:
		var p := d.dust.puffs[i]
		var r := Vector2(p.at.x - sh.home.x, p.at.z - sh.home.z)
		ok(absf(r.length() / EcoFishDust.RING - 1.0) <= EcoFishDust.RING_SCATTER + 1e-3,
				"кольцом под домом (%.2f м)" % r.length())
		near(p.at.y, FLAT + EcoFishDust.BASE_LIFT, 1e-4, "у дна")
		near(p.scale, EcoFishDust.HIDE_SCALE, 1e-6, "доля размера клуба")
		ok(p.alpha > EcoFishDust.HIDE_ALPHA * 0.79, "клуб гуще облачков из-под хвоста")
		sum += r.normalized()
	ok(sum.length() < 1.2, "кольцом, а не кучкой с одного бока (%.2f)" % sum.length())
	d.update(fish, 3.0 * DT, ship, _flat)
	eq(d.made, EcoFishDust.HIDE_N, "сидят в укрытии — новой мути нет")


func test_crown_and_high_home_no_ring() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var fish := _f(w)
	var crown: EcoFish.Shoal = null
	for sh in fish.shoals:
		if sh.crown:
			crown = sh
			break
	if not ok(crown != null, "есть стая у кроны"):
		return
	var d := EcoFishDust.new()
	var ship := crown.home + Vector3(0, 10, 0)
	d.update(fish, 0.0, ship, _flat)
	crown.alarm = 3.0
	crown.center = crown.home
	ok(not EcoFishDust.hiding(crown), "стая кроны прячется в чаше, не у дна")
	d.update(fish, DT, ship, _flat)
	eq(d.made, 0, "стая кроны ила у дна не поднимает")
	var sh := fish.shoals[0]
	var top := sh.home.y - EcoFishDust.HIDE_H - 1.0   # число, не стая: дно агент запоминает — без цикла ссылок
	var high := func(_x: float, _z: float) -> float: return top
	var d2 := EcoFishDust.new()
	_move(sh, 8.0, 0.0)
	_center(sh)
	sh.center = sh.home
	d2.update(fish, 0.0, sh.home, high)
	sh.alarm = 3.0
	d2.update(fish, DT, sh.home, high)
	eq(d2.made, 0, "дом высоко над дном — до ила не достать")


func test_far_or_lite_no_dust() -> void:
	var w := _world()
	var fish := _f(w)
	var sh := fish.shoals[0]
	_move(sh, 1.0)
	var d := EcoFishDust.new()
	d.update(fish, 0.0, FAR, _flat)
	sh.alarm = 3.0
	d.update(fish, DT, FAR, _flat)
	eq(d.made, 0, "дальше %d м от корабля мути нет" % int(EcoGrazerDust.NEAR))
	EcoGrazerDust.lite = true
	var d2 := EcoFishDust.new()
	var ship := sh.center + Vector3(0, 12, 0)
	sh.alarm = 0.0
	d2.update(fish, 0.0, ship, _flat)
	sh.alarm = 3.0
	d2.update(fish, DT, ship, _flat)
	EcoGrazerDust.lite = false
	eq(d2.made, 0, "«Экономно» — мути нет")
	var d3 := EcoFishDust.new()
	sh.alarm = 0.0
	d3.update(fish, 0.0, ship)
	sh.alarm = 3.0
	d3.update(fish, DT, ship)
	eq(d3.made, 0, "дна не знаем — мути нет")


## В мире: корабль проносится мимо стаи у дна — стая шарахается и пылит; тот же мир — та же муть.
func _run_pass() -> EcoFishDust:
	EcoGrazerDust.lite = false
	var w := _world()
	var fish := _f(w)
	var sh := fish.shoals[0]
	_move(sh, 1.3)
	var d := EcoFishDust.new()
	w.ship.pos = sh.center + Vector3(-40, 2, 0)
	w.ship.speed = 0.0
	d.update(fish, w.time, w.ship.pos, _flat)
	for i in 3:
		w.step(DT)
		d.update(fish, w.time, w.ship.pos, _flat)
	eq(d.made, 0, "корабль далеко и стоит — мути нет")
	w.ship.pos = sh.center + Vector3(-6, 2, 0)
	w.ship.speed = 3.0
	w.step(DT)
	d.update(fish, w.time, w.ship.pos, _flat)
	ok(sh.alarm > 0.0, "корабль пронёсся рядом — стая всполошилась")
	return d


func test_same_world_same_dust() -> void:
	var a := _run_pass()
	var b := _run_pass()
	ok(a.made > 0, "у дна — муть есть")
	eq(a.made, b.made, "столько же облачков")
	for i in a.made:
		ok(a.dust.puffs[i].at.is_equal_approx(b.dust.puffs[i].at), "там же")
		near(a.dust.puffs[i].born, b.dust.puffs[i].born, 1e-6, "тогда же")


func test_new_run_resets() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var fish := _f(w)
	var d := EcoFishDust.new()
	var ship := fish.shoals[0].home + Vector3(0, 10, 0)
	d.update(fish, 0.0, ship, _flat)
	d.update(fish, 5.0, ship, _flat)
	fish.shoals[0].alarm = 3.0   # будто тревога перед концом забега
	w.reset()
	fish.shoals[0].alarm = 3.0
	d.update(fish, 0.0, ship, _flat)
	eq(d.made, 0, "новый забег — первый шаг только запоминает")


func test_guest_sees_host_alarm() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var fish := _f(w)
	var sh := fish.shoals[0]
	_move(sh, 1.0)
	var d := EcoFishDust.new()
	var ship := sh.center + Vector3(0, 12, 0)
	d.update(fish, 0.0, ship, _flat)
	# кадр хоста: та же стая всполошилась
	var host := _world()
	var hsh := _f(host).shoals[0]
	_move(hsh, 1.0)
	hsh.alarm = 3.0
	var data := EcoLink.pack_world(host.agents, host.systems, hsh.center)
	ok(EcoLink.apply_shoals(w.agents, w.systems, data) >= 1, "кадр стай принят")
	d.update(fish, DT, ship, _flat)
	eq(d.made, EcoFishDust.KICK_MAX, "у гостя тревога из кадра хоста — та же муть")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var fish := _f(w)
	var view := FishView.new(fish)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть светляков в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoFishDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var sh := fish.shoals[0]
	_move(sh, 1.0)
	var info := EcoLink.ShipState.new()
	info.pos = sh.center + Vector3(0, 12, 0)
	view.sync(0.0, info, Vector3.ZERO, _flat)
	sh.alarm = 3.0
	view.sync(0.1, info, Vector3.ZERO, _flat)
	view.sync(0.6, info, Vector3.ZERO, _flat)
	var seen := 0
	for n in EcoFishDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			near(view.dust_buffer[i + 12], EcoFishDust.COLOR.r, 1e-5, "бурый ил без луча")
	eq(seen, EcoFishDust.KICK_MAX, "стая подняла муть")
	view.sync(1.0)
	view.queue_free()
	await frames(1)
