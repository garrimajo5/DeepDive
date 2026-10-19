extends TestCase
## Сонар на голостоле: дальность от доли, отметки из событий живого мира, кнопка у голостола.


func test_range_and_power() -> void:
	var s := Sonar.new()
	eq(s.ping(0.0, 0.0), "Сонар обесточен", "без энергии не стреляет")
	eq(s.ping(0.0, 1.0), "Сонар: импульс", "импульс")
	near(s.range_m, 110.0, 1e-6, "110 м при штатной доле")
	eq(s.ping(1.0, 1.0), "", "через секунду — ещё перезарядка")
	s.ping(5.0, 1.5)
	near(s.range_m, 165.0, 1e-6, "доля ×1,5 — дальность ×1,5")


func test_contacts_from_near_events() -> void:
	var s := Sonar.new()
	s.ping(0.0, 1.0)
	var ship := Vector3(0, -20, 95)
	var ev := [
		EcoLink.near("serpohvost", "серпохвост", ship + Vector3(30, 0, 0), ship),
		EcoLink.near("svetlyak", "светляк", ship + Vector3(0, -5, -60), ship),
		EcoLink.near("svetlyak", "светляк", ship + Vector3(200, 0, 0), ship),   # дальше 110 м
		EcoLink.message("шум"),
	]
	s.take_contacts(ev, ship)
	eq(s.blips.size(), 2, "две отметки в дальности")
	eq(s.blips[0]["species"], "serpohvost", "ближняя первой")
	eq(s.blips[0]["color"], Color("ff5d6c"), "хищник красный")
	near(s.blip_alpha(6.0), 0.5, 1e-6, "через 6 с — вполовину")
	near(s.blip_alpha(13.0), 0.0, 1e-6, "через 12 с гаснут")


func test_bathymetry_darker_deeper() -> void:
	var img := Sonar.bathymetry(32)
	# запад плато (x −120) мельче восточного склона (x 200)
	var west := img.get_pixel(int((350 - 120) / 700.0 * 32), 16).v
	var east := img.get_pixel(int((350 + 200) / 700.0 * 32), 16).v
	ok(west > east, "на склоне темнее: %.2f > %.2f" % [west, east])


class FakeEco:
	extends EcoView
	var pinged := false

	func step(_dt: float, ship: EcoLink.ShipState) -> Array[Dictionary]:
		if not ship.sonar_ping:
			return []
		pinged = true
		return [EcoLink.near("serpohvost", "серпохвост", ship.pos + Vector3(20, 0, -20), ship.pos)]


func test_scene_ping_at_holotable() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var fake := FakeEco.new()
	main.eco.queue_free()
	main.eco = fake
	main.add_child(fake)
	main.walker.x = 0.0
	main.walker.z = 0.2
	main.step(0.1)
	eq(main.overlay.action_label, "Сонар", "у голостола — кнопка «Сонар»")
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	r.end(1)
	main.step(0.1)
	ok(fake.pinged, "мир получил импульс")
	eq(main.sonar.blips.size(), 1, "одна отметка")
	eq(main.message.text, "Сонар: контактов 1", "на приборах")
	ok(not main.eco_ship.sonar_ping, "импульс — только один шаг")
	var m := main.sonar_view.mat
	eq(m.get_shader_parameter("blip_count"), 1, "отметка на голограмме")
	main.reactor.set_share(Reactor.Sys.SONAR, 0)
	main.step(4.0)
	r.begin(2, r.layout.action.c)
	r.end(2)
	main.step(0.1)
	eq(main.message.text, "Сонар обесточен", "без доли — не стреляет")
