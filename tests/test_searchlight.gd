extends TestCase
## Прожектор: числа как в браузере, луч достаёт дна отмели, кнопка «Свет» за штурвалом.


func test_numbers_as_browser() -> void:
	near(Searchlight.pitch_deg(), 18.0, 0.1, "вниз на 18°")
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
	ok(dir.y < -0.25 and dir.z < -0.9, "луч вперёд и вниз: %s" % str(dir))
