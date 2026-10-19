extends TestCase
## Прожектор: числа как в браузере, луч достаёт дна отмели, кнопка «Свет» за штурвалом.


func test_numbers_as_browser() -> void:
	near(Searchlight.pitch_deg(), 14.0, 0.1, "вниз на 14° (#47: при 18° пятно под пультом)")
	near(Searchlight.spot_angle_deg() * 2.0, 51.57, 0.05, "раскрытие ≈ 52°")
	near(Searchlight.range_m(1.0), 120.0, 1e-6, "120 м при штатной доле")
	near(Searchlight.range_m(0.04), 60.0, 1e-6, "при малой доле не меньше половины")
	ok(not Searchlight.lit(true, 0.0), "без энергии не светит")
	ok(not Searchlight.lit(false, 1.0), "выключен — не светит")
	near(Searchlight.beam_shade(0.0), 0.0, 1e-6, "у самой линзы конус погашен (не кольцо в окне)")
	ok(Searchlight.beam_shade(0.15) > 0.6, "сразу за линзой ярко")
	near(Searchlight.beam_shade(1.0), 0.0, 1e-6, "на конце гаснет")


func test_beam_reaches_bottom_from_start() -> void:
	# отчёт тестера в pogrujenie: луч 32 м под 15° не доставал дна в 22 м под кораблём
	var lamp := Helm.Ship.START + Searchlight.LAMP
	var d := Searchlight.floor_hit(lamp, 0.0, Searchlight.pitch_deg(), Searchlight.BASE_RANGE)
	ok(d > 0.0 and d < Searchlight.BASE_RANGE * 0.8, "луч касается дна на %.1f м — в пределах дальности" % d)


func test_beam_mesh_points_forward() -> void:
	var a := Searchlight.beam_arrays(8, 2)
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	eq(pos.size(), 9 * 3, "вершины колец")
	near(pos[pos.size() - 1].z, -Searchlight.BEAM_LENGTH, 1e-4, "конец луча впереди (−Z)")


func test_light_button_toggles() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var sl := main.searchlight
	ok(sl.spot.visible and sl.beam.visible, "на старте прожектор горит")
	eq(sl.spot.light_cull_mask, OceanView.LAYER_WORLD, "светит только на отмель")
	ok(sl.spot.spot_attenuation < 0.5, "свет не гаснет к дну как обратный квадрат")
	var r := main.overlay.router
	r.begin(1, r.layout.light.c)
	r.end(1)
	main.step(0.1)
	ok(sl.spot.visible, "не за штурвалом «Свет» не работает (это свайп)")
	main.sit_at_helm()
	r.begin(2, r.layout.light.c)
	r.end(2)
	main.step(0.1)
	ok(not sl.spot.visible and not sl.beam.visible, "за штурвалом «Свет» гасит прожектор")
	ok(not main.overlay.light_on, "кнопка показывает «Свет выкл»")
	r.begin(3, r.layout.light.c)
	r.end(3)
	main.step(0.1)
	ok(sl.spot.visible and main.overlay.light_on, "и снова зажигает")
	var dir := -sl.spot.global_transform.basis.z
	ok(dir.y < -0.2 and dir.z < -0.9, "луч вперёд и вниз: %s" % str(dir))


## Самая высокая точка модели перед глазами: наименьший угол ниже горизонта до её вершин, градусы.
func _top_angle(eye: Vector3, node: Node) -> float:
	var best := INF
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in m.mesh.get_surface_count():
			for v in m.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				var w: Vector3 = m.global_transform * v
				var ahead := eye.z - w.z   # нос корабля в −Z, корабль на курсе 0
				if ahead > 0.05:
					best = minf(best, rad_to_deg(atan2(eye.y - w.y, ahead)))
	return best


func test_spot_seen_over_console() -> void:
	# #47: на 29 м, до дна ≈ 13 м пятна из кресла не было видно — середина луча уходила под колесо и пульт
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.sit_at_helm()
	main.helm.pos = Vector3(0.0, -29.0, 95.0)
	main._place_ship()
	main._place_camera()
	await frames(1)
	var sl := main.searchlight
	var lamp := sl.global_position
	var dir := -sl.spot.global_transform.basis.z
	var hit := Vector3.INF
	var t := 0.5
	while t < Searchlight.BASE_RANGE:
		var q := lamp + dir * t
		if q.y <= Seabed.height(q.x, q.z):
			hit = q
			break
		t += 0.5
	ok(hit != Vector3.INF, "середина луча достаёт дна")
	ok(t < 70.0, "пятно ближе 70 м (дальше его съедает туман): %.0f м" % t)
	var eye := main.camera.global_position
	var spot := rad_to_deg(atan2(eye.y - hit.y, eye.z - hit.z))
	var console := _top_angle(eye, main.bridge.props[BridgeProps.CONSOLE])
	var wheel := _top_angle(eye, main.bridge.props[BridgeProps.WHEEL])
	ok(spot < console - 0.5, "середина пятна над кромкой пульта: %.1f° ниже горизонта, пульт — %.1f°" % [spot, console])
	ok(spot + Searchlight.spot_angle_deg() * 0.5 > wheel,
		"под колесом прячется только середина конуса: колесо %.1f°" % wheel)
	ok(sl.spot.light_energy >= 8.0 and sl.spot.spot_angle_attenuation <= 1.0, "свет ярче рассеянного, край мягкий")
