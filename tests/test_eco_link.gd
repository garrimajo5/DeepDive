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
