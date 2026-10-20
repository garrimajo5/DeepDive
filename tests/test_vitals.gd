extends TestCase
## Корпус и заряд корабля: расход и накопление, удары существ и о дно, ремонт, разрушение.


func test_energy_budget() -> void:
	var v := Vitals.new()
	v.energy = 50.0
	for i in 100:
		v.update(0.1, 0.0, 0.0, false, 1.0)
	near(v.energy, 61.0, 1e-3, "стоим без света: +1,1 ед./с")
	for i in 100:
		v.update(0.1, 1.0, 1.0, true, 1.0)
	near(v.energy, 61.0 + (1.1 - 0.35 - 0.15 - 0.22) * 10.0, 1e-3, "полный ход, всплытие и свет — +0,38 ед./с")
	v.energy = 0.3
	ok(v.update(0.1, 1.0, 0.0, true, 1.0), "заряд кончился — прожектор гасить")


func test_drain_from_creatures() -> void:
	var v := Vitals.new()
	v.drain_ext = 3.2
	v.update(1.0, 0.0, 0.0, false, 1.0)
	near(v.energy, 100.0 - 2.1, 1e-4, "стеклоуст тянет 3,2 ед./с")
	v.update(1.0, 0.0, 0.0, false, 1.0)
	near(v.energy, 100.0 - 2.1 + 1.1, 1e-4, "отпустил — расход пропал")


func test_drain_alarm() -> void:   # issue #131: пока тянет заряд — тревога с подсказкой про рычаг
	var v := Vitals.new()
	eq(v.drain_alarm(), "", "без присоски тихо")
	v.drain("Стеклоуст", 0.0)
	eq(v.drain_alarm(), "", "нулевой расход — не тревога")
	v.drain("Стеклоуст", 3.2)
	eq(v.drain_alarm(), "Стеклоуст на корпусе пьёт энергию. Разряд — рычаг у левого борта", "тревога")
	v.update(0.3, 0.0, 0.0, false, 1.0)
	ok(v.drain_alarm() != "", "держится между событиями")
	v.drain("Стеклоуст", 3.2)
	v.update(0.3, 0.0, 0.0, false, 1.0)
	ok(v.drain_alarm() != "", "новое событие продлевает")
	v.update(0.3, 0.0, 0.0, false, 1.0)
	eq(v.drain_alarm(), "", "сбросили — гаснет через полсекунды")
	v.drain("Стеклоуст", 3.2)
	v.reset()
	eq(v.drain_alarm(), "", "новый спуск — без тревоги")


func test_lamp_flicker() -> void:   # js/ship.js: пока присоска на корпусе, свет × 0,15 в четверти кадров
	var v := Vitals.new()
	for i in 60:
		eq(v.lamp_k(i * 0.37), 1.0, "без присоски свет ровный")
	v.drain("Стеклоуст", 3.2)
	var dim := 0
	var n := 600
	for i in n:
		var t := i / Vitals.FLICKER_HZ + 0.05
		var k := v.lamp_k(t)
		ok(k == 1.0 or k == Vitals.FLICKER_DIM, "только ровно или провал")
		eq(v.lamp_k(t + 0.1), k, "в пределах доли 1/6 с свет не меняется")
		if k < 1.0:
			dim += 1
	near(float(dim) / n, Vitals.FLICKER_CHANCE, 0.06, "провалов около четверти (%d из %d)" % [dim, n])
	ok(Vitals.FLICKER_HZ / 2.0 <= 3.0, "не чаще 3 вспышек в секунду")
	v.update(0.6, 0.0, 0.0, false, 1.0)
	var flick := 0
	for i in 60:
		eq(v.lamp_k(i * 0.37), 1.0, "отпустил — свет ровный")
		if v.lamp_k(i * 0.37, true) < 1.0:
			flick += 1
	ok(flick > 0, "после разряда (extra) тоже мигает")


func test_hits_repair_and_destroy() -> void:
	var v := Vitals.new()
	var lost := [false]
	v.destroyed.connect(func() -> void: lost[0] = true)
	ok(v.hit(12, "Серпохвост"), "укус засчитан")
	near(v.hull, 88.0, 1e-6, "−12 %")
	ok(v.shake > 0.0 and v.flash > 0.0, "тряска и вспышка")
	for i in 100:
		v.update(0.1, 0.0, 0.0, false, 1.0)
	near(v.hull, 89.5, 1e-4, "жизнеобеспечение чинит 0,15 %/с")
	for i in 100:
		v.update(0.1, 0.0, 0.0, false, 0.0)
	near(v.hull, 89.5, 1e-4, "без доли не чинит")
	v.hit(95, "x")
	ok(v.lost() and lost[0], "разрушен")
	ok(not v.hit(5, "x"), "по разрушенному больше не бьют")


func test_scrape_on_bottom() -> void:
	var v := Vitals.new()
	near(v.scrape(3.0, 2.0), 2.0, 1e-9, "медленно — без удара")
	near(v.scrape(0.5, 6.0), 6.0, 1e-9, "пологий подъём — без удара")
	near(v.scrape(3.0, 6.0), -1.5, 1e-9, "на 6 м/с в крутой склон — отскок")
	near(v.hull, 100.0 - 8.0, 1e-6, "−8 % (скорость × 1,4)")
	near(v.scrape(3.0, 6.0), 6.0, 1e-9, "сразу второй раз не бьёт (1,2 с)")


func test_warning() -> void:
	var v := Vitals.new()
	eq(v.warning(), "", "всё хорошо")
	v.energy = 10
	ok(v.warning().begins_with("Мало энергии"), "мало энергии")
	v.hull = 20
	eq(v.warning(), "Корпус повреждён", "корпус важнее")


class HitEco:
	extends EcoView
	var send: Array[Dictionary] = []

	func step(_dt: float, _ship: EcoLink.ShipState) -> Array[Dictionary]:
		var out := send.duplicate()
		send.clear()
		return out


func test_scene_eco_hits_and_drain() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var fake := HitEco.new()
	main.eco.queue_free()
	main.eco = fake
	main.add_child(fake)
	main.breach.cd = Breach.COOLDOWN   # без пробоины: она — в test_breach
	fake.send = [EcoLink.hit("Серпохвост", 0.12, main.helm.pos)]
	main.step(0.1)
	near(main.vitals.hull, 88.0, 0.05, "укус −12 %")
	eq(main.message.text, "Серпохвост бьёт по корпусу: −12%", "на приборах")
	ok(Status.join(main.status_parts()).contains("корпус 88%"), Status.join(main.status_parts()))
	var e0 := main.vitals.energy
	for i in 2:   # мир шлёт DRAIN каждый шаг, пока присоска на стекле; расход учитывается в следующем шаге
		fake.send = [{"type": EcoLink.DRAIN, "by": "Стеклоуст", "units": 3.2}]
		main.step(1.0)
	ok(main.vitals.energy < e0 - 1.0, "стеклоуст тянет заряд")
	var line := Status.join(main.status_parts())
	ok(line.begins_with("Стеклоуст на корпусе пьёт энергию"), "тревога первой: " + line)
	ok(main.drain_sound.playing, "шипит тревога присоски")
	var seen := {}
	for i in 18:   # 3 с: плафоны мостика и отсеков и прожектор мигают вместе
		fake.send = [{"type": EcoLink.DRAIN, "by": "Стеклоуст", "units": 3.2}]
		main.step(1.0 / Vitals.FLICKER_HZ)
		var k: float = main.bridge.lamps[0].light_energy / BridgeView.LAMP_ENERGY
		near(main.rooms.lamps[0].light_energy, RoomsView.LAMP_ENERGY * k, 1e-5, "отсеки вместе с мостиком")
		near(main.searchlight.spot.light_energy, Searchlight.ENERGY * k, 1e-5, "прожектор вместе с плафонами")
		seen[snappedf(k, 0.01)] = true
	ok(seen.has(1.0) and seen.has(Vitals.FLICKER_DIM), "свет то горит, то проваливается: %s" % [seen.keys()])
	main.step(0.3)
	main.step(0.3)
	ok(not Status.join(main.status_parts()).contains("Стеклоуст"), "отпустил — тревога погасла")
	ok(not main.drain_sound.playing, "шипение смолкло")
	near(main.bridge.lamps[1].light_energy, BridgeView.LAMP_ENERGY, 1e-6, "свет снова ровный")
	fake.send = [EcoLink.hit("Серпохвост", 1.0, main.helm.pos)]
	main.step(0.1)
	near(main.vitals.hull, 100.0, 1e-6, "разрушен — корабль поднят с целым корпусом")
	eq(main.helm.pos, Helm.Ship.START, "у начала спуска")


func test_scene_scrape_into_slope() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.helm.ground = func(_x: float, z: float) -> float: return -42.0 + maxf(0.0, 90.0 - z) * 0.5   # стена-склон впереди
	main.helm.pos = Vector3(0, -39, 95)
	main.helm.speed = 6.5
	main.sit_at_helm()
	var r := main.overlay.router
	r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))
	var hit := false
	for i in 900:
		main.step(1.0 / 30.0)
		if main.vitals.hull < 100.0:
			hit = true
			break
	r.end(1)
	ok(hit, "на полном ходу в подъём дна — удар о дно")


func test_diving_onto_flat_bottom_is_not_a_hit() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.helm.ground = func(_x: float, _z: float) -> float: return -30.0
	main.sit_at_helm()
	var r := main.overlay.router
	r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))
	r.begin(2, r.layout.down.c)
	for i in 600:
		main.step(1.0 / 30.0)
	near(main.vitals.hull, 100.0, 1e-6, "полный ход и «Вниз» до ровного дна — корпус цел")
