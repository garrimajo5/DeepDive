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
