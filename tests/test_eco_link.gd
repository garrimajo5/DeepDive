extends TestCase
## Связь живого мира с кораблём (EcoLink): корабль отдаёт состояние, события мира доходят до приборов.


class FakeEco:
	extends EcoView
	var got: EcoLink.ShipState
	var send: Array[Dictionary] = []

	func step(_dt: float, ship: EcoLink.ShipState) -> Array[Dictionary]:
		got = ship
		var out := send.duplicate()
		send.clear()
		return out


func test_ship_state_and_events() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var fake := FakeEco.new()
	main.eco.queue_free()
	main.eco = fake
	main.add_child(fake)
	main.step(0.1)
	ok(fake.got != null, "мир получил состояние корабля")
	eq(fake.got.pos, main.helm.pos, "где корабль")
	ok(fake.got.light_on and fake.got.light_range > 100.0, "прожектор горит, 120 м")
	ok(fake.got.nose().z < -0.99, "нос на север")
	fake.send = [EcoLink.hit("Серпохвост", 0.3, main.helm.pos), EcoLink.message("Стая светляков рядом")]
	main.step(0.1)
	ok(main.message.text == "Стая светляков рядом", "сообщение мира на приборах")
	main.toggle_light()
	main.step(0.1)
	ok(not fake.got.light_on, "погасили — мир знает")
	ok(main.eco.get_parent() == main, "мир — в сцене мира, не в корабле")


func test_observe_to_journal() -> void:
	# EcoLink.OBSERVE: наблюдение в журнал (handleEvents в js/game.js), текст — на приборы.
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var fake := FakeEco.new()
	main.eco.queue_free()
	main.eco = fake
	main.add_child(fake)
	fake.send = [EcoLink.observe("fish", "flee")]
	main.step(0.1)
	eq(main.scanner.seen_of("fish"), ["flee"] as Array[String], "наблюдение записано")
	eq(main.message.text, "Новое наблюдение: мелкая рыба", "новое без текста — подпись")
	main.say("—")
	fake.send = [EcoLink.observe("fish", "flee"), EcoLink.observe("fish", "nope")]
	main.step(0.1)
	eq(main.message.text, "—", "повтор и чужой ключ — молча")
	eq(main.scanner.seen_of("fish").size(), 1, "повтор не пишется")
	main.scanner.scanned["pred"] = true
	fake.send = [EcoLink.observe("pred", "ping", "Серпохвост плывёт на звук сонара")]
	main.step(0.1)
	eq(main.message.text, "Серпохвост плывёт на звук сонара", "текст события — как MESSAGE")
	eq(main.scanner.seen_of("pred"), ["ping"] as Array[String], "и в журнал")
	main.queue_free()
	await frames(1)


func test_live_world_observation_reaches_journal() -> void:
	# По issue #92: событие шины с заметкой вида рядом с кораблём приходит как OBSERVE и пишется в журнал.
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var w: EcoWorld = main.eco.world
	w.emit("fish", "flee", main.helm.pos + Vector3(0, 0, 20), func(): return "Стая уходит в кораллы")
	w.emit("fish", "flee", main.helm.pos + Vector3(0, 0, 500), func(): return "далеко")
	main.step(0.05)
	eq(main.scanner.seen_of("fish"), ["flee"] as Array[String], "наблюдение из живого мира в журнале")
	eq(main.message.text, "Стая уходит в кораллы", "текст события на приборах")
	main.queue_free()
	await frames(1)


func test_eel_drain_reaches_battery() -> void:
	# Стеклоуст на стекле: мир шлёт одно EcoLink.DRAIN 3,2 ед./с за шаг, корабль тянет заряд на 3,2 · dt больше.
	near(EcoLink.drain("Стеклоуст", -1.0)["units"], 0.0, 1e-9, "не отрицательный")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.vitals.energy = 50.0
	for i in 20:
		main.step(0.1)
	var free_loss := 50.0 - main.vitals.energy
	var eels: EcoEel = main.eco.eels
	var e := eels.eels[0]
	e.mode = EcoEel.Mode.LATCHED
	eels.latched = e
	main.step(0.1)   # корабль берёт расход из событий прошлого шага
	main.vitals.energy = 50.0
	for i in 20:
		main.step(0.1)
	var loss := 50.0 - main.vitals.energy
	near(loss - free_loss, EcoEel.DRAIN * 2.0, 0.05, "за 2 с — на 6,4 единицы больше")
	main.queue_free()
	await frames(1)


func test_remora_drag_event() -> void:
	# Присоски на корпусе: мир шлёт одно EcoLink.DRAG за шаг — сколько их и добавку к сопротивлению воды (+0,025
	# за каждую, js/ship.js); корабль прибавляет k к Helm.Ship.DRAG, пока событие приходит (поток А, issue).
	var d := EcoLink.drag("Присоска", -2, -1.0)
	eq(d["type"], EcoLink.DRAG)
	eq(d["count"], 0, "не отрицательное число")
	near(d["k"], 0.0, 1e-9, "не отрицательная добавка")
	var view := EcoView.new()
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(400, -30, 400)
	var drags := func(events: Array[Dictionary]) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for e in events:
			if e["type"] == EcoLink.DRAG:
				out.append(e)
		return out
	eq((drags.call(view.step(0.1, ship)) as Array).size(), 0, "прилипалы на скатах — тормоза нет")
	for k in 2:
		view.remoras.remoras[k].mode = EcoRemora.Mode.HULL
		view.remoras.remoras[k].slot = k
	var got: Array = drags.call(view.step(0.1, ship))
	eq(got.size(), 1, "одно событие за шаг из двух подшагов")
	eq(got[0]["by"], "Присоска")
	eq(got[0]["count"], 2)
	near(got[0]["k"], 0.05, 1e-6, "две прилипалы — +0,05")
	ship.zap = true
	eq((drags.call(view.step(0.1, ship)) as Array).size(), 0, "разряд сбросил — тормоза нет")
	view.free()


func test_remora_drag_slows_ship() -> void:   # issue #270: корабль принимает EcoLink.DRAG
	var h := Helm.Ship.new()
	h.extra_drag = 0.05
	h.in_thrust = 1.0
	for i in 600:
		h.update(1.0 / 30.0)
	near(h.speed, Helm.Ship.FORWARD / (Helm.Ship.DRAG + 0.05), 0.02, "две присоски — предельный ход ниже")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.on_eco_event(EcoLink.drag("Присоска", 2, 0.05))
	near(main.helm.extra_drag, 0.05, 1e-9, "событие — добавка к сопротивлению")
	main.helm.pos = Vector3(400, -30, 400)
	main.step(1.0 / 30.0)
	near(main.helm.extra_drag, 0.0, 1e-9, "шаг мира без события — тормоза нет")
	for k in 2:
		main.eco.remoras.remoras[k].mode = EcoRemora.Mode.HULL
		main.eco.remoras.remoras[k].slot = k
	main.step(1.0 / 30.0)
	near(main.helm.extra_drag, 0.05, 1e-6, "две присоски на корпусе — +0,05 к сопротивлению")
	main.helm.reset()
	near(main.helm.extra_drag, 0.0, 1e-9, "новый забег — без тормоза")
	main.queue_free()
	await frames(1)


func test_hit_clamped() -> void:
	near(EcoLink.hit("x", 3.0, Vector3.ZERO)["damage"], 1.0, 1e-9, "урон 0…1")


## Модуль-проба: одна цель видна всем, одну сонар не видит, одна спряталась.
class Probe:
	extends EcoSystem
	func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
		out.append(EcoWorld.target("pred", Vector3(0, 0, -30), 2.5))
		out.append(EcoWorld.target("grazer", Vector3(10, 0, 0), 1.4, false))
		out.append(EcoWorld.target("fish", Vector3(0, 0, 5), 2.5, true, true))


## Стая: много целей одного вида — сканеру нужна только ближняя (#738).
class Crowd:
	extends EcoSystem
	func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
		for i in 40:
			out.append(EcoWorld.target("fish", Vector3(0, 0, 50.0 - i), 1.0))
		out.append(EcoWorld.target("grazer", Vector3(20, 0, 0), 1.4, false))
		out.append(EcoWorld.target("grazer", Vector3(5, 0, 0), 1.4, false))


static func _near(events: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["type"] == EcoLink.NEAR:
			out.append(e)
	return out


static func _live_world() -> EcoWorld:
	var w := EcoWorld.new()
	var fish := w.add(EcoFish.new()) as EcoFish
	var moss := w.add(EcoMoss.new()) as EcoMoss
	w.add(EcoGrazer.new(moss))
	w.add(EcoPred.new(fish))
	return w


func test_near_on_sonar_ping() -> void:
	var w := _live_world()
	w.ship.pos = Vector3(0, -20, 60)
	w.step(0.1)
	eq(_near(w.take_link()).size(), 0, "без импульса и сканера NEAR нет")
	w.ship.sonar_ping = true
	w.ship.sonar_range = 110.0
	w.step(0.1)
	w.ship.sonar_ping = false
	var got := _near(w.take_link())
	var want := 0
	for t in w.scan_targets():
		var p: Vector3 = t["pos"]
		if Vector2(p.x, p.z - 60.0).length() < 110.0:
			want += 1
	ok(want >= 8, "рядом стаи, скребуны и серпохвост (%d)" % want)
	eq(got.size(), want, "по отметке на каждое существо ближе дальности")
	var kinds := {}
	for i in got.size():
		var e := got[i]
		ok(e["sonar"] and not e["scan"], "это отметки сонара")
		ok(Vector2(e["pos"].x, e["pos"].z - 60.0).length() < 110.0, "ближе дальности по горизонтали")
		ok(i == 0 or got[i - 1]["dist"] <= e["dist"], "ближние первыми")
		eq(e["name"], Species.called(e["species"], Species.Case.NOM, false), "имя описательное, вид не изучен")
		kinds[e["species"]] = true
	ok(kinds.has("fish") and kinds.has("grazer") and kinds.has("pred"), "все три вида на сонаре")
	w.step(0.1)
	eq(_near(w.take_link()).size(), 0, "импульс прошёл — отметок больше нет")


func test_near_short_range_and_scanned_name() -> void:
	var w := _live_world()
	w.scanned = func(sp: String) -> bool: return sp == "fish"
	w.ship.pos = Vector3(0, -20, 60)
	w.ship.sonar_ping = true
	w.ship.sonar_range = 30.0
	w.step(0.05)
	var got := _near(w.take_link())
	for e in got:
		ok(Vector2(e["pos"].x, e["pos"].z - 60.0).length() < 30.0, "слабый сонар — только ближние")
		if e["species"] == "fish":
			eq(e["name"], Species.called("fish", Species.Case.NOM, true), "изученный вид — настоящим именем")


func test_near_sonar_hidden_and_scanner() -> void:
	var w := EcoWorld.new()
	w.add(Probe.new())
	w.ship.sonar_ping = true
	w.ship.sonar_range = 100.0
	w.step(0.05)
	var got := _near(w.take_link())
	eq(got.size(), 2, "сонар не видит невидимого сонару, спрятавшегося — видит")
	eq(got[0]["species"], "fish", "ближняя первой")
	eq(got[1]["species"], "pred", "вторая")
	w.ship.sonar_ping = false
	w.ship.scan_range = 80.0
	for i in 2:
		w.step(0.05)
		got = _near(w.take_link())
		eq(got.size(), 2, "сканер каждый шаг: всё, кроме спрятавшегося")
		eq(got[0]["species"], "grazer", "ближняя первой")
		ok(got[0]["scan"] and not got[0]["sonar"], "для сканера, не для сонара")
		near(got[0]["r"], 1.4, 1e-6, "размер цели для прицела")
		near(got[0]["dist"], 10.0, 1e-4, "до корабля")
	w.ship.sonar_ping = true
	w.step(0.05)
	got = _near(w.take_link())
	eq(got.size(), 3, "импульс при сканере: одно существо — одно событие")
	var flags := {}
	for e in got:
		flags[e["species"]] = [e["sonar"], e["scan"]]
	eq(flags["fish"], [true, false], "спрятавшаяся — только сонару")
	eq(flags["grazer"], [false, true], "невидимая сонару — только сканеру")
	eq(flags["pred"], [true, true], "обычная — обоим")
	w.ship.scan_range = 10.0
	w.ship.sonar_ping = false
	w.step(0.05)
	eq(_near(w.take_link()).size(), 1, "дальность прицела 10 м: только скребун")


## Всплеск шага мира у сканера (#738): раньше сканер получал NEAR на каждое существо ближе 80 м (сотня событий
## в шаг) — теперь одно на вид, ближнее. Импульс сонара по-прежнему отмечает всех.
func test_scanner_gets_nearest_per_species() -> void:
	var w := EcoWorld.new()
	w.add(Crowd.new())
	w.ship.scan_range = 80.0
	w.step(0.05)
	var got := _near(w.take_link())
	eq(got.size(), 2, "одно событие на вид")
	eq(got[0]["species"], "grazer", "ближняя первой")
	near(got[0]["dist"], 5.0, 1e-4, "ближний скребун")
	near(got[1]["dist"], 11.0, 1e-4, "ближняя рыба стаи")
	for e in got:
		ok(e["scan"] and not e["sonar"], "только сканеру")
	w.ship.sonar_ping = true
	w.ship.sonar_range = 100.0
	w.step(0.05)
	got = _near(w.take_link())
	var sonar := 0
	var scan := 0
	for e in got:
		sonar += int(e["sonar"])
		scan += int(e["scan"])
	eq(sonar, 40, "импульс: все рыбы стаи на сонаре")
	eq(scan, 2, "сканеру — по одной на вид")
	eq(got.size(), 41, "одно существо — одно событие (скребун сонару не виден, дальний — не нужен)")
	ok(got[0]["scan"] and got[0]["species"] == "grazer", "ближний скребун — прицелу")


func test_species_info_shared() -> void:
	ok(Species.info("fish") == Species.info("fish"), "обёртка вида одна — названия не создают объектов каждый шаг")
	eq(Species.info("нет такого"), null)


func test_near_reaches_sonar_table() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	# у стаи 1 и первого серпохвоста: голостол держит 32 ближних отметки, серпохвост должен попасть в них
	main.helm.pos = Vector3(-40, -20, 30)
	main.step(0.1)
	main.ping_sonar()
	main.step(0.1)
	ok(main.sonar.blips.size() >= 8, "на голостоле отметки живого мира (%d)" % main.sonar.blips.size())
	var kinds := {}
	for b in main.sonar.blips:
		kinds[b["species"]] = true
	ok(kinds.has("fish") and kinds.has("pred"), "стаи и серпохвост на сонаре")
	main.queue_free()
	await frames(1)


## Чутьё хищников растёт с каждым спуском (js/run.js R.predK): мир узнаёт номер спуска из ShipState.dive.
func test_dive_sharpens_predators() -> void:
	var s := EcoLink.ShipState.new()
	eq(s.dive, 0, "первый спуск")
	near(s.pred_k(), 1.0, 1e-6, "первый спуск — обычное чутьё")
	s.dive = 2
	near(s.pred_k(), 1.3, 1e-6, "третий спуск — +30 %")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var fake := FakeEco.new()
	main.eco.queue_free()
	main.eco = fake
	main.add_child(fake)
	main.step(0.1)
	eq(fake.got.dive, 0, "мир знает: первый спуск")
	main.complete_route()
	main.decide("deep")
	main.step(0.1)
	eq(fake.got.dive, 1, "решили «глубже» — мир знает: второй спуск")
	near(fake.got.pred_k(), 1.15, 1e-6, "хищники чутче на 15 %")
	main.queue_free()
	await frames(1)


## Кража образцов скальником (#201): мир видит захват лебёдки и может сорвать образец с захвата и бросить.
func test_claw_steal_and_drop() -> void:
	eq([EcoLink.CLAW_IDLE, EcoLink.CLAW_REACH, EcoLink.CLAW_BACK],
		[Samples.State.IDLE, Samples.State.REACH, Samples.State.BACK], "состояния захвата совпадают с Samples.State")
	eq(EcoLink.steal("Скальник", 4), {"type": EcoLink.STEAL, "by": "Скальник", "sample": 4})
	eq(EcoLink.drop(4, Vector3(1, 2, 3)), {"type": EcoLink.DROP, "sample": 4, "at": Vector3(1, 2, 3)})
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var fake := FakeEco.new()
	main.eco.queue_free()
	main.eco = fake
	main.add_child(fake)
	main.park_over_sample(8)
	main.step(0.05)
	eq(fake.got.claw_state, EcoLink.CLAW_IDLE, "захват в покое")
	eq(fake.got.claw_sample, -1)
	var xf := Samples.ship_xform(main.helm.pos, main.helm.yaw)
	ok(fake.got.claw.distance_to(xf * Samples.REST) < 1e-3, "захват в трюме над шлюзом")
	var lock := Samples.lock_point(xf)
	for i in 10:
		main.samples.hold(lock, 0.05)
		main.step(0.05)
	eq(fake.got.claw_state, EcoLink.CLAW_REACH, "тянется")
	eq(fake.got.claw_sample, 8, "к образцу 8")
	eq(fake.got.claw_target, main.samples.all[8].pos, "где лежит цель")
	ok(fake.got.claw.y < lock.y, "захват ниже шлюза")
	fake.send = [EcoLink.steal("Скальник", 8)]
	main.step(0.05)
	eq(main.samples.state, Samples.State.REACH, "пока тянется — не сорвать")
	for i in 30:
		main.samples.hold(lock, 0.05)
		main.step(0.05)
		if main.samples.state == Samples.State.BACK:
			break
	main.step(0.05)
	eq(fake.got.claw_state, EcoLink.CLAW_BACK, "поднимает")
	fake.send = [EcoLink.steal("Скальник", 8)]
	main.step(0.05)
	eq(main.samples.state, Samples.State.IDLE, "сорван — захват пуст")
	ok(main.message.text.begins_with("Образец украден: Скальник"), "сообщение на приборах")
	for i in 40:
		main.step(0.05)
	eq(main.samples.cargo.size(), 0, "в трюм не лёг")
	var at := main.samples.all[8].pos + Vector3(3, 0, 0)
	fake.send = [EcoLink.drop(8, at)]
	main.step(0.05)
	ok(not main.samples.all[8].taken, "брошен — снова на дне")
	near(main.samples.all[8].pos.x, at.x, 1e-5, "там, где бросил")
	main.queue_free()
	await frames(1)


## Сквозь связь (#201): настоящий скальник у образца 8 срывает его с поднимающегося захвата, уносит и бросает
## у дома — лебёдка пустеет, в груз образец не ложится, потом снова лежит на дне.
func test_skalnik_steals_from_real_winch() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.park_over_sample(8)
	var smp: Samples.Sample = main.samples.all[8]
	var sk: EcoSkalnik.Octo = main.eco.skalnik.octo
	ok(sk != null, "скальник в мире")
	sk.home = smp.pos + Vector3(4, 0, 0)
	sk.home.y = Seabed.height(sk.home.x, sk.home.z)
	sk.pos = sk.home
	sk.cur_cd = 999.0   # не отвлекаться на тихий корабль
	var lock := Samples.lock_point(Samples.ship_xform(main.helm.pos, main.helm.yaw))
	var stolen := false
	for i in 400:
		if main.samples.state != Samples.State.IDLE or i == 0:
			main.samples.hold(lock, 0.05)
		main.step(0.05)
		if main.samples.stolen.has(8):
			stolen = true
			break
	ok(stolen, "образец сорван с захвата (состояние скальника %d)" % sk.state)
	eq(main.samples.state, Samples.State.IDLE, "захват пуст")
	eq(main.samples.cargo.size(), 0, "в груз не лёг")
	for i in 300:
		main.step(0.05)
		if not main.samples.stolen.has(8):
			break
	ok(not main.samples.stolen.has(8), "брошен")
	ok(not smp.taken, "снова на дне")
	near(Vector2(smp.pos.x, smp.pos.z).distance_to(Vector2(sk.home.x, sk.home.z)), EcoSkalnik.STASH, 1e-3, "у дома")
	main.queue_free()
	await frames(1)


func test_pack_near_for_guest() -> void:   # существа рядом для гостя сетевого забега: ближние первыми, в радиусе
	var w := EcoWorld.new()
	var far := w.spawn("pred", Vector3(200, -30, 0))
	var a := w.spawn("pred", Vector3(10, -30, 0))
	var b := w.spawn("fish", Vector3(2, -30, 0))
	a.v = Vector3(1, 2, 3)
	a.set_state(EcoAgent.State.HUNT)
	b.alive = false
	var d := EcoLink.pack_near(w.agents, Vector3(0, -30, 0))
	eq(d.size(), 2 * EcoLink.NET_STRIDE, "дальний не едет")
	eq(int(d[0]), 2, "ближний первым")
	eq(int(d[EcoLink.NET_STRIDE]), 1)
	eq(EcoLink.pack_near(w.agents, Vector3(0, -30, 0), EcoLink.NET_R, 1).size(), EcoLink.NET_STRIDE, "не больше limit")
	# мир гостя: те же существа, но в других местах
	var g := EcoWorld.new()
	g.spawn("pred", far.p)
	var ga := g.spawn("pred", Vector3.ZERO)
	var gb := g.spawn("fish", Vector3.ZERO)
	eq(EcoLink.apply_near(g.agents, d), 2, "оба поставлены")
	eq(ga.p, a.p, "место как у хоста")
	eq(ga.v, a.v, "скорость как у хоста")
	eq(ga.state, EcoAgent.State.HUNT, "состояние как у хоста")
	ok(ga.alive and not gb.alive, "неживое неживым")
	# миры разошлись: на номере другой вид — не трогаем
	var x := EcoWorld.new()
	x.spawn("pred", far.p)
	var xa := x.spawn("fish", Vector3.ZERO)
	eq(EcoLink.apply_near(x.agents, d), 0, "чужой вид и номер за концом списка пропускаются")
	eq(xa.p, Vector3.ZERO)


func _moss_world() -> EcoWorld:   # мир с мхом трёх видов: общий (с монетками на нём), у рёбер и у колодца
	var w := EcoWorld.new()
	var m := w.add(EcoMoss.new()) as EcoMoss
	w.add(EcoCoins.new(m))
	w.add(EcoBones.new())
	w.add(EcoWell.new())
	return w


func test_moss_rides_to_guest() -> void:   # еда пятен мха рядом с кораблём едет гостю вместе с существами
	var h := _moss_world()
	var all := EcoLink.mosses(h.systems)
	eq(all.size(), 3, "общий мох, у рёбер и у колодца — без повтора общего у монеток")
	var spot: EcoMoss.Patch = all[0].patches[0]
	spot.food = 0.1   # объели у хоста
	var fish := h.spawn("fish", spot.pos + Vector3(1, 2, 0))
	var d := EcoLink.pack_world(h.agents, h.systems, spot.pos)
	var g := _moss_world()
	g.spawn("fish", Vector3.ZERO)
	var gs: EcoMoss.Patch = EcoLink.mosses(g.systems)[0].patches[0]
	ok(gs.food > 0.5, "у гостя мох свой — не объеден")
	ok(EcoLink.apply_world(g.agents, g.systems, d) >= 1, "пятно поставлено")
	near(gs.food, 0.1, 1e-4, "еда как у хоста")
	near(EcoMoss.glow_of(gs.food), spot.glow(), 1e-4, "свет пятна как у хоста")
	eq(g.agents[0].p, fish.p, "существа рядом по-прежнему ставятся")
	# мох вдали не едет; пакет без мха (старый) — только существа
	var far := EcoLink.pack_world(h.agents, h.systems, Vector3(5000, 0, 5000))
	ok(not far.has(float(EcoLink.NET_MOSS)), "вдали мха нет")
	eq(EcoLink.apply_world(g.agents, g.systems, EcoLink.pack_near(h.agents, spot.pos)), 0, "старый пакет — без мха")
	# мох у рёбер тоже едет
	var bp: EcoMoss.Patch = all[1].patches[0]
	bp.food = 0.0
	var gb: EcoMoss.Patch = EcoLink.mosses(g.systems)[1].patches[0]
	EcoLink.apply_world(g.agents, g.systems, EcoLink.pack_world(h.agents, h.systems, bp.pos))
	near(gb.food, 0.0, 1e-4, "мох у рёбер как у хоста")


func _fish_world(world_seed: int = EcoRandom.WORLD_SEED) -> EcoWorld:   # мир со светляками на настоящем дне
	var w := EcoWorld.new(world_seed)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	w.add(EcoFish.new())
	return w


func _live_center(sh: EcoFish.Shoal) -> Vector3:
	var s := Vector3.ZERO
	var n := 0
	for f: EcoFish.Fish in sh.members:
		if f.agent.alive:
			s += f.agent.p
			n += 1
	return s / n


func test_shoals_ride_to_guest() -> void:   # стая рядом едет гостю целиком: центр, цель, таймер, тревога
	var h := _fish_world()
	var hf := EcoLink.fish_of(h.systems)
	var sh: EcoFish.Shoal = hf.shoals[0]
	for f: EcoFish.Fish in sh.members:   # у хоста стая ушла на 6 м
		f.agent.p += Vector3(6, 0, 0)
	sh.center = _live_center(sh)
	sh.velocity = Vector3(1, 0, 0)
	sh.goal = sh.center + Vector3(10, 1, -4)
	sh.goal_timer = 3.5
	sh.alarm = 1.25
	var d := EcoLink.pack_world(h.agents, h.systems, sh.center)
	ok(d.has(float(EcoLink.NET_SHOAL)), "стаи в пакете")
	# только часть стай — без поштучных существ: все рыбки стаи свободны, центр — хостовый
	var g := _fish_world()
	var gs: EcoFish.Shoal = EcoLink.fish_of(g.systems).shoals[0]
	ok(_live_center(gs).distance_to(sh.center) > 5.0, "у гостя стая на старом месте")
	ok(EcoLink.apply_shoals(g.agents, g.systems, _shoals_only(d)) >= 1, "стая поставлена")
	near(_live_center(gs).distance_to(sh.center), 0.0, 1e-3, "центр живых — хостовый")
	eq(gs.goal, sh.goal, "цель как у хоста")
	near(gs.goal_timer, 3.5, 1e-4)
	near(gs.alarm, 1.25, 1e-4, "тревога как у хоста")
	eq(gs.velocity, sh.velocity)
	# полный пакет: поштучные рыбки — точно на местах хоста, центр всё равно хостовый
	var g2 := _fish_world()
	var gs2: EcoFish.Shoal = EcoLink.fish_of(g2.systems).shoals[0]
	EcoLink.apply_world(g2.agents, g2.systems, d)
	eq(gs2.members[0].agent.p, sh.members[0].agent.p, "ближняя рыбка — как у хоста")
	near(_live_center(gs2).distance_to(sh.center), 0.0, 1e-3)
	# вдали стай нет; старый пакет — стаи не трогает
	ok(not EcoLink.pack_world(h.agents, h.systems, Vector3(5000, 0, 5000)).has(float(EcoLink.NET_SHOAL)), "вдали стай нет")
	eq(EcoLink.apply_shoals(g.agents, g.systems, EcoLink.pack_near(h.agents, sh.center)), 0, "старый пакет — без стай")


func test_shoal_section_without_moss() -> void:   # стаи сразу за существами: существа не читают стаи как существ
	var h := _fish_world()
	var sh: EcoFish.Shoal = EcoLink.fish_of(h.systems).shoals[0]
	var d := EcoLink.pack_world(h.agents, h.systems, sh.center)
	ok(not d.has(float(EcoLink.NET_MOSS)), "мха в мире нет")
	var g := _fish_world()
	eq(EcoLink.apply_near(g.agents, d), EcoLink.NET_MAX, "поставлены только существа")
	eq(EcoLink.apply_world(g.agents, g.systems, d), 0, "мха нет")


func _shoals_only(d: PackedFloat32Array) -> PackedFloat32Array:   # пакет без поштучных существ (рядом тесно)
	var k := 0
	while k < d.size() and int(d[k]) >= 0:
		k += EcoLink.NET_STRIDE
	return d.slice(k)


func test_guest_shoal_follows_host() -> void:   # миры разошлись: с кадрами хоста стая гостя идёт за стаей хоста,
	# даже когда её рыбки не попали в NET_MAX ближних существ
	var h := _fish_world()
	var g := _fish_world(EcoRandom.WORLD_SEED + 7)   # другой случай — другие цели
	var hs: EcoFish.Shoal = EcoLink.fish_of(h.systems).shoals[0]
	var gs: EcoFish.Shoal = EcoLink.fish_of(g.systems).shoals[0]
	var worst := 0.0
	for i in 600:   # 20 с по 1/30, кадр хоста — каждый третий шаг
		h.step(1.0 / 30.0)
		g.step(1.0 / 30.0)
		if i % 3 == 0:
			EcoLink.apply_world(g.agents, g.systems, _shoals_only(EcoLink.pack_world(h.agents, h.systems, hs.center)))
		if i > 30:
			worst = maxf(worst, _live_center(gs).distance_to(_live_center(hs)))
	ok(worst < 1.0, "центр стаи гостя рядом с хостовым: %.2f м" % worst)


func test_coins_ride_to_guest() -> void:   # стайка монетников рядом едет гостю целиком: бегство, глазун, каждая рыбка
	var h := _moss_world()
	var hc := EcoLink.coins_of(h.systems)
	var sc: EcoCoins.School = hc.schools[0]
	sc.scatter = 1.5
	sc.from = sc.center + Vector3(3, 0, 0)
	sc.glazun.lunge = 0.6
	sc.glazun.cd = 17.0
	var dead := sc.members[0]
	dead.alive = false
	dead.respawn = 12.0
	var c1 := sc.members[1]
	c1.pos += Vector3(1, 0.5, -1)
	c1.vel = Vector3(0.3, 0, 0.2)
	c1.goal = c1.pos + Vector3(2, 0, 0)
	c1.goal_t = 4.0
	var d := EcoLink.pack_world(h.agents, h.systems, sc.center)
	ok(d.has(float(EcoLink.NET_COINS)), "монетники в пакете")
	var g := _moss_world()
	var gc: EcoCoins.School = EcoLink.coins_of(g.systems).schools[0]
	ok(gc.members[0].alive, "у гостя рыбка жива")
	eq(EcoLink.apply_coins(g.systems, d), 1 + _schools_near(hc, sc.center), "стайки рядом поставлены")
	ok(not gc.members[0].alive, "съеденная — съеденная")
	near(gc.members[0].respawn, 12.0, 1e-4)
	eq(gc.members[1].pos, c1.pos, "место как у хоста")
	eq(gc.members[1].vel, c1.vel)
	eq(gc.members[1].goal, c1.goal, "цель как у хоста")
	near(gc.members[1].goal_t, 4.0, 1e-4)
	near(gc.scatter, 1.5, 1e-4, "бегство как у хоста")
	eq(gc.from, sc.from)
	near(gc.glazun.lunge, 0.6, 1e-4, "бросок глазуна как у хоста")
	near(gc.glazun.cd, 17.0, 1e-4)
	# мох в том же пакете по-прежнему ставится; вдали монетников нет; старый пакет их не трогает
	ok(EcoLink.apply_world(g.agents, g.systems, d) >= 1, "мох рядом поставлен")
	ok(not EcoLink.pack_world(h.agents, h.systems, Vector3(5000, 0, 5000)).has(float(EcoLink.NET_COINS)), "вдали нет")
	eq(EcoLink.apply_coins(g.systems, EcoLink.pack_near(h.agents, sc.center)), 0, "старый пакет — без монетников")


func _schools_near(c: EcoCoins, p: Vector3) -> int:   # сколько других стаек тоже ближе NET_R
	var n := -1
	for s in c.schools:
		if s.center.distance_to(p) <= EcoLink.NET_R:
			n += 1
	return n


func test_guest_coins_follow_host() -> void:   # миры разошлись: с кадрами хоста монетники гостя там же, где у хоста
	var h := _moss_world()
	var g := _moss_world()
	g.reset(EcoRandom.WORLD_SEED + 7)   # другой случай — другие цели
	var hc := EcoLink.coins_of(h.systems)
	var gc := EcoLink.coins_of(g.systems)
	var worst := 0.0
	for i in 600:   # 20 с по 1/30, кадр хоста — каждый третий шаг
		h.step(1.0 / 30.0)
		g.step(1.0 / 30.0)
		if i % 3 == 0:
			EcoLink.apply_world(g.agents, g.systems, EcoLink.pack_world(h.agents, h.systems, hc.schools[0].center))
		if i > 30:
			for k in hc.coins.size():
				if hc.coins[k].alive and gc.coins[k].alive \
						and hc.schools[hc.coins[k].school].center.distance_to(hc.schools[0].center) <= EcoLink.NET_R:
					worst = maxf(worst, hc.coins[k].pos.distance_to(gc.coins[k].pos))
	ok(worst < 0.6, "монетник гостя рядом с хостовым: %.2f м" % worst)


func _kelp_world(seed_value: int = EcoRandom.WORLD_SEED) -> EcoWorld:   # две рощи ленточника с ежами, свои места
	var w := EcoWorld.new()
	var spots: Array[Vector3] = [Vector3(0, -20, 0), Vector3(40, -20, 0)]
	w.add(EcoKelp.new(null, spots))
	w.reset(seed_value)
	return w


func test_kelp_rides_to_guest() -> void:   # роща рядом едет гостю целиком: густота лент и каждый ёж
	var h := _kelp_world()
	var hk := EcoLink.kelp_of(h.systems)
	var gr: EcoKelp.Grove = hk.groves[0]
	gr.stalks[3].f = 0.2   # объели у хоста
	var dead: EcoKelp.Urchin = hk.urchins[0]
	hk.kill(dead, 25.0)
	var u: EcoKelp.Urchin = hk.urchins[1]
	u.pos += Vector3(1, 0, -0.5)
	u.goal = 5
	gr.stalks[5].eater = u.index
	u.wander_t = 3.0
	u.graze_cd = 11.0
	var d := EcoLink.pack_world(h.agents, h.systems, gr.center)
	ok(d.has(float(EcoLink.NET_KELP)), "ленточник в пакете")
	var g := _kelp_world(EcoRandom.WORLD_SEED + 7)
	var gk := EcoLink.kelp_of(g.systems)
	eq(EcoLink.apply_kelp(g.systems, d), 2, "обе рощи ближе NET_R поставлены")
	near(gk.groves[0].stalks[3].f, 0.2, 1e-4, "объеденная лента объедена и у гостя")
	ok(not gk.urchins[0].alive, "съеденный ёж — съеденный")
	near(gk.urchins[0].respawn, 25.0, 1e-4)
	eq(gk.urchins[1].pos, u.pos, "место как у хоста")
	eq(gk.urchins[1].goal, 5, "цель как у хоста")
	eq(gk.groves[0].stalks[5].eater, u.index, "ленту ест тот же ёж")
	near(gk.urchins[1].graze_cd, 11.0, 1e-4)
	ok(not EcoLink.pack_world(h.agents, h.systems, Vector3(5000, 0, 5000)).has(float(EcoLink.NET_KELP)), "вдали нет")
	eq(EcoLink.apply_kelp(g.systems, EcoLink.pack_near(h.agents, gr.center)), 0, "старый пакет — без ленточника")


func test_guest_urchins_follow_host() -> void:   # миры разошлись: с кадрами хоста ежи и ленты гостя как у хоста
	var h := _kelp_world()
	var g := _kelp_world(EcoRandom.WORLD_SEED + 7)
	var hk := EcoLink.kelp_of(h.systems)
	var gk := EcoLink.kelp_of(g.systems)
	var worst := 0.0
	var worst_f := 0.0
	for i in 900:   # 30 с по 1/30, кадр хоста — каждый третий шаг
		h.step(1.0 / 30.0)
		g.step(1.0 / 30.0)
		if i % 3 == 0:
			EcoLink.apply_world(g.agents, g.systems, EcoLink.pack_world(h.agents, h.systems, hk.groves[0].center))
		if i > 30:
			for k in hk.urchins.size():
				if hk.urchins[k].alive and gk.urchins[k].alive:
					worst = maxf(worst, hk.urchins[k].pos.distance_to(gk.urchins[k].pos))
			for k in hk.groves[0].stalks.size():
				worst_f = maxf(worst_f, absf(hk.groves[0].stalks[k].f - gk.groves[0].stalks[k].f))
	ok(worst < 0.1, "ёж гостя рядом с хостовым: %.3f м" % worst)
	ok(worst_f < 0.01, "густота лент как у хоста: %.4f" % worst_f)


func _flash_world() -> EcoWorld:   # стая радужников и облако планктона, свои места; дно не задано (высота — потолок)
	var w := EcoWorld.new()
	var rd_homes: Array[Vector2] = [Vector2(0, 0), Vector2(300, 300)]
	var pl_homes: Array[Vector2] = [Vector2(0, 40), Vector2(-300, 300)]
	w.add(EcoRaduzh.new(rd_homes))
	w.add(EcoPlankton.new(null, null, pl_homes))
	w.reset()
	return w


func test_flashes_ride_to_guest() -> void:   # вспышка стаи и светящиеся клетки облака рядом едут гостю как у хоста
	var h := _flash_world()
	h.run(30.0)
	var hr := EcoLink.raduzh_of(h.systems)
	var hp := EcoLink.plankton_of(h.systems)
	var sw: EcoRaduzh.Swarm = hr.swarms[0]
	sw.glow = 0.8
	sw.lit = true
	var cl: EcoPlankton.Cloud = hp.clouds[0]
	cl.cut_at = h.time - 0.3
	cl.lit_at[5] = h.time - 0.3
	cl.by[5] = EcoPlankton.By.SHIP
	cl.lit_at[7] = h.time - 1.2
	cl.by[7] = EcoPlankton.By.PRED
	cl.lit_at[9] = h.time - 5.0   # давно погасла
	cl.by[9] = EcoPlankton.By.SHIP
	cl.ship = 0.6
	cl.pred_lit = 9
	var d := EcoLink.pack_world(h.agents, h.systems, Vector3(0, -10, 20), EcoLink.NET_R, h.time)
	ok(d.has(float(EcoLink.NET_RADUZH)), "радужники в пакете")
	ok(d.has(float(EcoLink.NET_PLANKTON)), "светящееся облако в пакете")
	near(EcoLink.net_time(d), h.time, 1e-3, "время мира хоста в пакете")
	var g := _flash_world()
	g.run(2.0)   # гость вошёл позже — своё время другое
	EcoLink.apply_world(g.agents, g.systems, d, g)
	near(g.time, h.time, 1e-3, "время гостя — хостовое (разница больше TIME_SNAP — сразу)")
	var gr := EcoLink.raduzh_of(g.systems)
	var gp := EcoLink.plankton_of(g.systems)
	near(gr.swarms[0].glow, 0.8, 1e-4, "вспышка стаи как у хоста")
	ok(gr.swarms[0].lit, "луч задевает стаю и у гостя")
	near(gr.flare, 0.8, 1e-4, "самая яркая вспышка — для хищников гостя")
	ok(gr.swarms[0].c.distance_to(sw.c) < 0.01, "стая там же, где у хоста")
	eq(gr.swarms[1].glow, 0.0, "дальняя стая не пришла")
	var gc: EcoPlankton.Cloud = gp.clouds[0]
	for k in [5, 7, 9, 100]:
		near(EcoPlankton.glow(gc, k, g.time), EcoPlankton.glow(cl, k, h.time), 0.03, "яркость клетки %d" % k)
	eq(gc.by[5], EcoPlankton.By.SHIP, "клетку 5 зажёг корабль")
	eq(gc.by[7], EcoPlankton.By.PRED, "клетку 7 — серпохвост")
	near(gc.ship, 0.6, 1e-4, "след корабля как у хоста")
	near(gp.wake, 0.6, 1e-4)
	eq(gc.pred_lit, 9)
	near(gc.cut_at, cl.cut_at, 1e-3)
	ok(gc.c.distance_to(cl.c) < 0.01, "облако там же, где у хоста")
	cl.cut_at = h.time - 3.0   # облако погасло — больше не едет
	ok(not EcoLink.pack_world(h.agents, h.systems, Vector3(0, -10, 20), EcoLink.NET_R, h.time)
		.has(float(EcoLink.NET_PLANKTON)), "погасшее облако не едет")
	ok(not EcoLink.pack_world(h.agents, h.systems, Vector3(5000, 0, 5000)).has(float(EcoLink.NET_RADUZH)), "вдали нет")
	eq(EcoLink.net_time(EcoLink.pack_near(h.agents, Vector3.ZERO)), -1.0, "старый пакет — без времени")


func test_synced_time() -> void:   # время гостя тянется к хостовому без рывков назад
	eq(EcoLink.synced_time(5.0, -1.0), 5.0, "без времени хоста — своё")
	eq(EcoLink.synced_time(5.0, 40.0), 40.0, "далеко — сразу хостовое")
	near(EcoLink.synced_time(10.0, 10.2), 10.05, 1e-5, "близко — на четверть разницы")


func test_guest_flashes_follow_host() -> void:   # гость вошёл позже: с кадрами хоста стаи, облака и вспышки как у хоста
	var h := _flash_world()
	var g := _flash_world()
	g.run(40.0)   # время гостя ушло на 40 с — без времени хоста стаи и облака дрейфовали бы в другом месте
	var hr := EcoLink.raduzh_of(h.systems)
	var gr := EcoLink.raduzh_of(g.systems)
	var hp := EcoLink.plankton_of(h.systems)
	var gp := EcoLink.plankton_of(g.systems)
	var worst_c := 0.0
	var worst_g := 0.0
	var worst_cell := 0.0
	var lit_max := 0.0
	var cut_cells := 0
	for i in 600:   # 20 с по 1/30, кадр хоста — каждый третий шаг
		var s := h.ship
		s.yaw = 0.0
		s.speed = 3.0   # режет облако быстрее WAKE_SPEED
		s.pos = Vector3(0, -10, 60) + Vector3(0, 0, -s.speed * i / 30.0)
		s.light_on = true
		s.light_range = Searchlight.BASE_RANGE
		for sh: EcoLink.ShipState in [g.ship]:   # корабль гостя — по кадру хоста
			sh.pos = s.pos
			sh.yaw = s.yaw
			sh.speed = s.speed
			sh.light_on = s.light_on
			sh.light_range = s.light_range
		h.step(1.0 / 30.0)
		g.step(1.0 / 30.0)
		if i % 3 == 0:
			EcoLink.apply_world(g.agents, g.systems, EcoLink.pack_world(h.agents, h.systems, s.pos, EcoLink.NET_R,
				h.time), g)
		if i > 3 and i % 3 == 0:   # сразу после кадра хоста: между кадрами новые клетки гость узнаёт кадром позже
			for k in hr.swarms.size():
				worst_c = maxf(worst_c, hr.swarms[k].c.distance_to(gr.swarms[k].c))
				worst_g = maxf(worst_g, absf(hr.swarms[k].glow - gr.swarms[k].glow))
				lit_max = maxf(lit_max, hr.swarms[k].glow)
			var hc: EcoPlankton.Cloud = hp.clouds[0]
			var gc: EcoPlankton.Cloud = gp.clouds[0]
			worst_c = maxf(worst_c, hc.c.distance_to(gc.c))
			for k in EcoPlankton.PER_CLOUD:
				var a := EcoPlankton.glow(hc, k, h.time)
				if a > 0.0:
					cut_cells += 1
				worst_cell = maxf(worst_cell, absf(a - EcoPlankton.glow(gc, k, g.time)))
	ok(lit_max > 0.5, "стая вспыхивала в луче у хоста: %.2f" % lit_max)
	ok(cut_cells > 0, "корабль зажигал клетки облака")
	ok(worst_c < 0.1, "стаи и облако гостя там же, где у хоста: %.3f м" % worst_c)
	ok(worst_g < 0.15, "вспышка стаи как у хоста: %.3f" % worst_g)
	ok(worst_cell < 0.15, "яркость клеток как у хоста: %.3f" % worst_cell)


func test_voice_reaches_comms() -> void:   # голос мира (эхоловец) — на плашке связи ART-040, подделка без кода
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var e := EcoLink.voice(Crew.Role.PILOT, "Дайте импульс", true, "ping")
	eq(e["type"], EcoLink.VOICE, "тип события")
	eq([e["role"], e["text"], e["fake"], e["ask"], e["silent"]], [0, "Дайте импульс", true, "ping", false], "поля")
	eq(EcoLink.voice(9, "x")["role"], 3, "роль в пределах 0…3")
	main.on_eco_event(e)
	main.step(0.1)
	ok(main.comms.cur != null, "сообщение на плашке")
	eq(main.comms.title(), "Пилот", "заявленная роль")
	eq(main.comms.code_line(), "Код: …", "подделка — без кодового слова")
	eq(main.comms.cur.ask, "ping", "просьба сохранена, корабль её не исполняет")
	eq(main.sonar.count, 0, "импульса сам корабль не дал")
	main.queue_free()
	await frames(1)


func test_echo_fake_reaches_comms() -> void:   # подделка эхоловца из живого мира — на плашке связи, без кода и с молчанием
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var e := main.eco.echo
	ok(e != null and e.preds == main.eco.preds, "эхоловец знает серпохвостов сцены")
	e.fake(main.eco.world, EcoEcho.ASK_PING)
	main.step(0.1)
	ok(main.comms.cur != null, "ложный вызов на плашке")
	eq(main.comms.title(), "Сонарщик", "заявленная роль")
	eq(main.comms.code_line(), "Код: …", "без кодового слова")
	eq(main.comms.cur.ask, EcoEcho.ASK_PING, "просит импульс")
	eq(main.comms.cur.reply, "", "первый спуск — молчит на «Спросить код»")
	eq(main.sonar.count, 0, "импульса корабль сам не дал")
	main.queue_free()
	await frames(1)


func test_world_packet_parsed_once() -> void:   # #850: гость размечает пакет один раз, не по разу на каждую часть
	var h := _moss_world()
	h.add(EcoFish.new())
	var spots: Array[Vector3] = [Vector3(0, -20, 0)]
	h.add(EcoKelp.new(null, spots))
	var rd_homes: Array[Vector2] = [Vector2(0, 0)]
	var pl_homes: Array[Vector2] = [Vector2(0, 10)]
	h.add(EcoRaduzh.new(rd_homes))
	var pl := h.add(EcoPlankton.new(null, null, pl_homes)) as EcoPlankton
	h.reset()
	h.run(5.0)
	pl.clouds[0].cut_at = h.time - 0.2   # облако светится — едет
	var spot := EcoLink.mosses(h.systems)[0].patches[0].pos
	var d := EcoLink.pack_world(h.agents, h.systems, Vector3(spot.x, -20, spot.z), 5000.0, h.time)
	var at := EcoLink.parts(d)
	for m in [EcoLink.NET_MOSS, EcoLink.NET_SHOAL, EcoLink.NET_COINS, EcoLink.NET_KELP, EcoLink.NET_RADUZH,
			EcoLink.NET_PLANKTON, EcoLink.NET_TIME]:
		var from: int = at[-2 * m]
		var to: int = at[-2 * m + 1]
		ok(from > 0 and to > from, "часть %d в пакете" % m)
		eq(int(d[from - 1]), m, "перед частью %d — её метка" % m)
		eq((to - from) % EcoLink._stride(m), 0, "в части %d целые записи" % m)
		ok(to == d.size() or int(d[to]) < 0, "часть %d кончается меткой или концом" % m)
	near(EcoLink.net_time(d, at), h.time, 1e-3, "время из разметки")
	var g := _moss_world()
	g.add(EcoFish.new())
	g.add(EcoKelp.new(null, spots))
	g.add(EcoRaduzh.new(rd_homes))
	g.add(EcoPlankton.new(null, null, pl_homes))
	g.reset(EcoRandom.WORLD_SEED + 3)
	var before := EcoLink.scans
	ok(EcoLink.apply_world(g.agents, g.systems, d, g) > 0, "мох поставлен")
	eq(EcoLink.scans - before, 1, "пакет размечен один раз")
	eq(EcoLink.parts(PackedFloat32Array())[-2 * EcoLink.NET_MOSS], -1, "пустой пакет — частей нет")


func test_world_packet_has_no_empty_parts() -> void:   # метка без записей снимается — пакет как прежде
	var h := _moss_world()
	var d := EcoLink.pack_world(h.agents, h.systems, Vector3(5000, 0, 5000))
	eq(d.size(), 0, "вдали — пустой пакет, без голых меток")


func test_field_rhythm_learns_08() -> void:   # #833: ритм поля из мира — знание «поле 08» и строка на приборах
	var e := EcoLink.field(2.4, "ритм")
	eq([e["type"], e["period"], e["text"]], [EcoLink.FIELD, 2.4, "ритм"], "поля события")
	near(float(EcoLink.field(-1.0, "")["period"]), 0.0, 1e-6, "период не отрицательный")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(not main.lore.knows(LayerLore.FIELD08), "до события поле не замечено")
	main.on_eco_event(e)
	ok(main.lore.knows(LayerLore.FIELD08), "событие ставит знание")
	eq(main.message.text, "ритм", "строка мира на приборах")
	main.queue_free()
	await frames(1)


func test_shell_inspected_learns_03() -> void:   # #835: Раковина осмотрена сканером и сонаром — знание «осмотр 03»
	var e := EcoLink.shell("постройка")
	eq([e["type"], e["text"]], [EcoLink.SHELL, "постройка"], "поля события")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(not main.lore.knows(LayerLore.SHELL03), "до события Раковина не осмотрена")
	main.on_eco_event(e)
	ok(main.lore.knows(LayerLore.SHELL03), "событие ставит знание")
	eq(main.message.text, "постройка", "строка мира на приборах")
	main.queue_free()
	await frames(1)
