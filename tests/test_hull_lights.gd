extends TestCase
## Огни корпуса снаружи ART-070 (HullLights, HullView.lights): места и цвета по таблице приёмки, проблеск маяка,
## размер и сдвиг по камере, гашение по заряду, миганию и шторке, «Экономно»; в сцене — один MultiMesh, изнутри скрыт.


func test_places_and_colors() -> void:
	eq(HullLights.count(), 6, "шесть огней")
	eq(HullLights.IDS.size(), 6)
	eq(HullLights.COLORS.size(), 6)
	eq(HullLights.KINDS.size(), 6)
	near(HullLights.POS[0].distance_to(Vector3(-6.78, 1.6, -2.0)), 0.0, 1e-5, "ЛН по таблице")
	near(HullLights.POS[5].distance_to(Vector3(0.0, 4.92, -2.0)), 0.0, 1e-5, "М на рубке")
	for i in [0, 2]:
		var j: int = i + 1
		near(HullLights.POS[i].x, -HullLights.POS[j].x, 1e-5, "борта симметричны")
		eq(HullLights.COLORS[i], Color("#B8D9E8"), "левый борт — #B8D9E8")
		eq(HullLights.COLORS[j], Color("#67DDEB"), "правый борт — #67DDEB")
		ok(HullLights.halo(i).y > HullLights.halo(i).x, "левый ореол вытянут вверх")
		eq(HullLights.halo(j), Vector2(1.3, 1.3), "правый — круглый")
	for c in HullLights.COLORS:
		ok(not (c.r > c.g + 0.2 and c.r > c.b + 0.2), "красного нет (#129)")
	for p in HullLights.POS:   # в шаге наружу (вбок от борта, вверх от верха) камера уже снаружи корпуса
		var out := Vector3(signf(p.x) * 1.5, 0.0, 0.0) if absf(p.x) > 1.0 else Vector3(0.0, 1.5, 0.0)
		ok(HullLights.shown(p + out), "у огня %s снаружи — корпус" % str(p))


func test_beacon_pulse() -> void:
	near(HullLights.pulse(0.0), 0.0, 1e-6, "начало периода — темно")
	near(HullLights.pulse(0.17), 1.0, 1e-6, "между входом и выходом — полный")
	ok(HullLights.pulse(0.05) > 0.0 and HullLights.pulse(0.05) < 1.0, "вход 0–0,10 с плавный")
	ok(HullLights.pulse(0.3) > 0.0 and HullLights.pulse(0.3) < 1.0, "выход 0,25–0,35 с плавный")
	near(HullLights.pulse(0.36), 0.0, 1e-6, "после 0,35 с погас")
	near(HullLights.pulse(1.5), 0.0, 1e-6, "до конца периода темно")
	near(HullLights.pulse(2.4 + 0.17), 1.0, 1e-6, "период 2,4 с")
	var lit := 0
	for k in 240:
		if HullLights.pulse(k * 0.01) > 0.5:
			lit += 1
	ok(lit >= 18 and lit <= 26, "горит ≈ 0,2 с из 2,4: %d сотых" % lit)


func test_scale_and_card() -> void:
	near(HullLights.scale_at(45.0), 1.0, 1e-6, "на 45 м — размер таблицы")
	near(HullLights.scale_at(5.0), 0.3, 1e-6, "вблизи — не меньше 0,3")
	near(HullLights.scale_at(300.0), 1.5, 1e-6, "вдали — не больше 1,5")
	var cam := Vector3(36.0, 1.6, 37.0)   # камера приёмки: 45 м от (0; 1,6; 10)
	var c := HullLights.card(1, cam, false)
	var p := HullLights.POS[1]
	near(c.origin.distance_to(p), HullLights.TOWARD, 1e-4, "центр сдвинут к камере на 1,3 м")
	near((c.origin - p).normalized().dot((cam - p).normalized()), 1.0, 1e-5, "вдоль луча к камере")
	var s := HullLights.scale_at(cam.distance_to(p))
	near(c.basis.x.length(), 1.3 * s, 1e-4, "ширина по дистанции")
	near(HullLights.card(0, cam, false).basis.y.length(), 1.7 * HullLights.scale_at(cam.distance_to(HullLights.POS[0])), 1e-4)
	near(HullLights.card(1, cam, true).basis.x.length(), 1.3 * s * HullLights.LITE_SIZE, 1e-4, "«Экономно» — меньше")
	var close := HullLights.card(1, p + Vector3(1.0, 0, 0), false)
	ok(close.origin.distance_to(p) <= 0.5 + 1e-5, "камера у самого огня — сдвиг не за камеру")


func test_alpha() -> void:
	var t := 0.17   # маяк в полной силе
	near(HullLights.alpha(0, t, 100.0, 1.0, -1.0, false), 1.0, 1e-6, "борт горит")
	near(HullLights.alpha(5, t, 100.0, 1.0, -1.0, false), 1.0, 1e-6, "маяк в проблеске")
	near(HullLights.alpha(5, 1.0, 100.0, 1.0, -1.0, false), 0.0, 1e-6, "маяк между проблесками")
	near(HullLights.alpha(5, 1.0, 100.0, 1.0, -1.0, true), HullLights.LITE_BEACON, 1e-6, "«Экономно» — маяк ровный")
	var low := Vitals.LOW_ENERGY - 1.0
	near(HullLights.alpha(5, t, low, 1.0, -1.0, false), 0.0, 1e-6, "мало заряда — маяк гаснет")
	near(HullLights.alpha(4, t, low, 1.0, -1.0, false), HullLights.LOW_TOP, 1e-6, "верх кормы 0,35")
	near(HullLights.alpha(1, t, low, 1.0, -1.0, false), HullLights.LOW_SIDE, 1e-6, "борта 0,25")
	for i in HullLights.count():
		near(HullLights.alpha(i, t, 0.0, 1.0, -1.0, false), 0.0, 1e-6, "заряд 0 — всё гаснет")
	near(HullLights.alpha(0, t, 100.0, Vitals.FLICKER_DIM, -1.0, false), Vitals.FLICKER_DIM, 1e-6, "мигание света — × lamp_k")
	near(HullLights.alpha(0, t, 100.0, 1.0, 0.15, false), 0.5, 1e-6, "шторка: за 0,3 с гаснут")
	near(HullLights.alpha(0, t, 100.0, 1.0, 1.0, false), 0.0, 1e-6, "шторка — темно")
	near(HullLights.alpha(0, t, 100.0, 1.0, Wreck.RESTART_AT + 0.1, false), 1.0, 1e-6, "после перезапуска горят")


func test_scene_lights() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var l := main.hull.lights
	ok(l != null and l.get_parent() == main.hull, "огни едут с корпусом")
	eq(l.name, &"Огни корпуса")
	eq(l.multimesh.instance_count, HullLights.count(), "шесть карточек одним MultiMesh")
	eq(l.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(l.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var m: StandardMaterial3D = l.material_override
	eq(m.billboard_mode, BaseMaterial3D.BILLBOARD_ENABLED, "лицом к камере")
	ok(m.billboard_keep_scale, "размер карточки сохраняется")
	eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "без света — Light3D не нужен")
	main.step(1.0 / 30.0)
	ok(not HullLights.shown(main.hull.to_local(main.camera.global_position)), "глаза на мостике — внутри корпуса")
	ok(not l.visible, "изнутри огней не видно")
	var cam := Camera3D.new()   # камера снаружи, как облёт или снимок view=
	main.ship.add_child(cam)
	cam.position = Vector3(36.0, 1.6, 37.0)
	cam.make_current()
	main.time = 0.17
	main.step(1.0 / 30.0)
	ok(l.visible, "снаружи огни видны")
	var c := main.hull.light_cards[1]   # MultiMesh в headless не отдаёт экземпляры назад — копия карточек в HullView
	near(c.origin.distance_to(HullLights.POS[1]), HullLights.TOWARD, 1e-3, "карточка по камере в кадре")
	near(main.hull.light_alpha[0], 1.0, 1e-3, "борт горит")
	main.hull.set_lights(cam.position, main.time, 0.0, 1.0, -1.0)
	ok(not l.visible, "заряд 0 — огни погасли, узел скрыт")
	main.hull.set_lights(cam.position, main.time, 100.0, 1.0, -1.0)
	ok(l.visible, "заряд вернулся — горят")
	main.vitals.energy = 100.0
	main.wreck.t = 1.0
	main.hull.set_lights(cam.position, main.time, main.vitals.energy, 1.0, main.wreck.t)
	ok(not l.visible, "«Корпус разрушен» — погасли")
	cam.queue_free()
	main.queue_free()
	await frames(1)
