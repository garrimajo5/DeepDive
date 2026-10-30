extends TestCase
## Купольник у террасы врат 07 (#837, часть 1): ждёт в нише, корабль у террасы — выходит к гнезду, поднимает
## створку (раз), уходит; на пути корабля стоит; не вид бестиария; диагностика от него не зависит.

const DT := 0.1


func _world(ship_at: Vector3) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = ship_at
	return w


func _far() -> Vector3:
	return Vector3(0.0, -30.0, 95.0)   # старт 00


## Корабль у террасы, но в стороне от пути ниша → гнездо (к югу от середины, на подходе).
func _near() -> Vector3:
	return Vector3(EcoGate.CENTER.x, -35.0, EcoGate.CENTER.y + 60.0)


func _run(w: EcoWorld, d: EcoDome, secs: float) -> int:
	var opens := 0
	var tt := 0.0
	while tt < secs:
		w.time += DT
		d.step(w, DT)
		if d.just_opened:
			opens += 1
		tt += DT
	return opens


func test_waits_in_niche_until_ship_comes() -> void:
	var w := _world(_far())
	var d := EcoDome.new()
	d.reset(w)
	var start := d.pos
	_run(w, d, 60.0)
	eq(d.state, EcoDome.State.WAIT, "корабль далеко — ждёт")
	near(d.pos.distance_to(start), 0.0, 1e-5, "стоит в нише")
	ok(Vector2(start.x, start.z).distance_to(EcoGate.CENTER) > 60.0, "ниша вне террасы")
	near(d.glow, EcoDome.GLOW_REST, 1e-5, "фотофоры в покое")


func test_goes_opens_once_and_leaves() -> void:
	var w := _world(_far())
	var d := EcoDome.new()
	d.reset(w)
	w.ship.pos = _near()
	_run(w, d, 0.2)
	eq(d.state, EcoDome.State.GO, "корабль у террасы — выходит")
	var peak := 0.0
	for i in 10:
		w.time += DT
		d.step(w, DT)
		peak = maxf(peak, d.glow)
	ok(peak > 0.6, "импульс фотофоров — команда")
	var opens := _run(w, d, 200.0)
	eq(opens, 1, "створка открылась один раз")
	ok(d.opened, "створка открыта")
	near(d.petal, 1.0, 1e-4, "поднята целиком и остаётся")
	eq(d.state, EcoDome.State.GONE, "ушёл в нишу")
	ok(not d.shown(), "после ухода не виден")
	eq(_run(w, d, 120.0), 0, "второй раз не открывает")
	w.ship.pos = _far()
	_run(w, d, 5.0)
	w.ship.pos = _near()
	eq(_run(w, d, 120.0), 0, "корабль вернулся — купольник больше не выходит")


func test_stands_at_nest_while_opening() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var guard := 0
	while d.state != EcoDome.State.OPEN and guard < 3000:
		w.time += DT
		d.step(w, DT)
		guard += 1
	eq(d.state, EcoDome.State.OPEN, "дошёл до гнезда")
	var n := GateDiag.nest_pos(EcoDome.NEST)
	ok(Vector2(d.pos.x, d.pos.z).distance_to(Vector2(n.x, n.z)) < 2.0, "у первого гнезда")
	near(d.pos.y - Seabed.height(d.pos.x, d.pos.z), EcoDome.AT_NEST, 0.2, "у дна, на уровне гнезда")
	eq(d.clip(), "OpenPetal", "клип открытия")
	_run(w, d, 1.0)
	near(d.petal, 0.0, 1e-4, "сначала держит обод — створка ещё закрыта")
	_run(w, d, 1.7)
	ok(d.petal > 0.2 and d.petal < 0.9, "поднимает по направляющей плавно")


func test_path_stays_above_floor() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var low := INF
	var guard := 0
	while d.state != EcoDome.State.GONE and guard < 4000:
		w.time += DT
		d.step(w, DT)
		low = minf(low, d.pos.y - Seabed.height(d.pos.x, d.pos.z))
		guard += 1
	eq(d.state, EcoDome.State.GONE, "весь путь пройден")
	ok(low > 0.4, "не уходит в дно (ниже всего %.2f м)" % low)


func test_ship_in_the_way_waits() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	_run(w, d, 20.0)
	eq(d.state, EcoDome.State.GO, "в пути")
	w.ship.pos = d.pos + Vector3(0.0, 4.0, 10.0)   # корабль у самого купольника
	var at := d.pos
	_run(w, d, 15.0)
	near(d.pos.distance_to(at), 0.0, 1e-4, "корабль на пути — стоит")
	eq(d.clip(), "Idle", "не плывёт")
	w.ship.pos = _near()
	_run(w, d, 5.0)
	ok(d.pos.distance_to(at) > 1.0, "пропустили — плывёт дальше")


func test_does_not_close_in_on_ship() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	w.ship.pos = d.stand() + Vector3(0.0, 8.0, 8.0)   # корабль завис у самого гнезда
	var closest := INF
	_run(w, d, 0.1)
	for i in 3000:
		w.time += DT
		d.step(w, DT)
		closest = minf(closest, d.pos.distance_to(w.ship.pos))
	ok(closest >= EcoDome.KEEP - 0.5, "ближе KEEP к кораблю не подходит (%.1f м)" % closest)
	ok(not d.opened, "пока корабль у гнезда — створку не открыл")


func test_not_a_bestiary_target_and_ignores_light() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var out: Array[Dictionary] = []
	d.targets(w, out)
	eq(out.size(), 0, "не цель сканера и сонара")
	w.ship.light_on = true
	w.ship.light_range = 60.0
	var lit := EcoDome.new()
	var w2 := _world(_near())
	lit.reset(w2)
	_run(w, d, 40.0)
	_run(w2, lit, 40.0)
	near(d.pos.distance_to(lit.pos), 0.0, 1e-5, "прожектор путь не меняет")


func test_diagnostics_do_not_need_dome() -> void:
	var g := GateDiag.new()
	var lore := LayerLore.new()
	var n := GateDiag.nest_pos(EcoDome.NEST)
	g.aim(n + Vector3(0.0, 10.0, 20.0), lore)
	eq(g.nest, EcoDome.NEST, "гнездо читается и при закрытой створке")


func test_scene_has_dome_at_gate() -> void:
	var v := EcoView.new()
	tree.root.add_child(v)
	await frames(1)
	ok(v.dome != null and v.world.systems.has(v.dome), "купольник в мире")
	eq(v.dome.state, EcoDome.State.WAIT, "на старте ждёт в нише")
	v.queue_free()
	await frames(1)
