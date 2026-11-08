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
	eq(img.get_size(), Vector2i(48, 32), "по x — шире: отмель и склон за восточным краем (#829)")
	# запад плато (x −120) мельче восточного склона (x 200)
	var west := img.get_pixel(_px(-120.0, 48), 16).v
	var east := img.get_pixel(_px(200.0, 48), 16).v
	ok(west > east, "на склоне темнее: %.2f > %.2f" % [west, east])
	var deep := img.get_pixel(_px(560.0, 48), int((200.0 + 350.0) / 700.0 * 32)).v
	ok(deep < west, "у места 10 на склоне за краем — рельеф есть, глубже плато: %.2f" % deep)


func _px(x: float, nx: int) -> int:
	return int((x - Sonar.MAP_RECT.position.x) / Sonar.MAP_RECT.size.x * nx)


## #829: точка мира на карте рельефа — одна и та же в сонаре и на столе брифинга (те же uniform шейдера).
func test_map_rect_covers_slope() -> void:
	ok(Sonar.MAP_RECT.encloses(Seabed.EAST), "склон Seabed.EAST — внутри карты")
	ok(Sonar.MAP_RECT.has_point(LayerMap.xz("10")), "и место 10")
	var src := FileAccess.get_file_as_string("res://shaders/sonar_holo.gdshader")
	ok(not src.contains("map_size"), "в шейдере нет квадрата 700 м")


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


## #847: голограмма пишет в шейдер только изменившееся — в тихом кадре без отметок только время и возраст импульса,
## погасшие отметки не переписываются, скрытый брифинг не трогает номера и иконки.
func test_view_writes_only_changes() -> void:
	var sv := SonarView.new()
	tree.root.add_child(sv)
	await frames(1)
	var s := Sonar.new()
	var ship := Vector3(0, -20, 95)
	sv.show_state(s, ship, 0.0, 1.0, true)
	sv.show_briefing(0.0, Run.new(), ship)
	sv.show_waypoint(Vector2.INF)
	var w := sv.writes
	sv.show_state(s, ship, 0.0, 1.0, true)
	sv.show_briefing(0.0, Run.new(), ship)
	sv.show_waypoint(Vector2.INF)
	eq(sv.writes, w, "тот же кадр — ни одной записи")
	sv.show_state(s, ship, 0.0, 1.5, true)
	eq(sv.writes - w, 2, "идёт время — только time и ping_age")
	# импульс и отметки: пока гаснут — пишутся, погасли — нет
	s.ping(2.0, 1.0)
	s.take_contacts([EcoLink.near("serpohvost", "серпохвост", ship + Vector3(30, 0, 0), ship)], ship)
	sv.show_state(s, ship, 0.0, 3.0, true)
	eq(sv.mat.get_shader_parameter("blip_count"), 1, "отметка в шейдере")
	var data: PackedVector4Array = sv.mat.get_shader_parameter("blips")
	near(data[0].w, s.blip_alpha(3.0), 1e-6, "яркость отметки")
	sv.show_state(s, ship, 0.0, 20.0, true)
	near(sv.mat.get_shader_parameter("blips")[0].w, 0.0, 1e-6, "через 12 с погасла")
	w = sv.writes
	sv.show_state(s, ship, 0.0, 21.0, true)
	eq(sv.writes - w, 2, "погасшие отметки не переписываются")
	# новый импульс с теми же числами всё равно обновляет
	s.ping(30.0, 1.0)
	sv.show_state(s, ship, 0.0, 30.0, true)
	eq(sv.mat.get_shader_parameter("blip_count"), 0, "новый импульс — отметки сброшены")
	# брифинг: показан — номера видны, скрыт — спрятаны и больше не трогаются
	var run := Run.new()
	sv.show_briefing(1.0, run, ship)
	ok(sv.numbers[0].visible, "брифинг — номера видны")
	sv.show_briefing(0.0, run, ship)
	ok(not sv.numbers[0].visible, "брифинг скрыт — номера спрятаны")
	sv.numbers[0].visible = true
	sv.show_briefing(0.0, run, ship)
	ok(sv.numbers[0].visible, "повторно скрытый брифинг номера не перебирает")
	sv.queue_free()
