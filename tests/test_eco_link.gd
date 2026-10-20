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
	main.helm.pos = Vector3(0, -20, 60)
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
