extends TestCase
## Прогрев шейдеров при старте (issue #50): шторка, камера оглядывает корабль, скрытое показано на кадр,
## вспышка разряда на наибольший радиус, кадры без прожектора, каждая внешность экипажа.


func test_views_cover_circle_and_lamp_off() -> void:
	var yaws := {}
	var lamp_off := 0
	for v in Warmup.VIEWS:
		if v[1] > -30.0 and v[1] < 30.0:
			yaws[int(v[0]) % 360] = true
		if not v[2]:
			lamp_off += 1
	for y in range(0, 360, 60):
		ok(yaws.has(y), "взгляд на курс %d°" % y)
	ok(lamp_off >= 2, "есть кадры без прожектора")
	ok(Deck.FOV > 60.0, "шаг 60° не оставляет щелей при поле зрения %.0f°" % Deck.FOV)
	near(Warmup.zap_radius(), 80.0, 1e-6, "разряд на пределе доли: 60 / 15 × 20 м")


func test_sweep_order() -> void:
	Warmup.enabled = true
	var w := Warmup.new()
	ok(w.active(), "включён")
	var ends := 0
	for i in Warmup.VIEWS.size():
		ok(w.active(), "взгляд %d" % i)
		if w.advance():
			ends += 1
	eq(ends, 1, "конец сообщается один раз")
	ok(not w.active() and w.lamp(), "после прогрева прожектор как в игре")
	ok(not w.advance(), "дальше ничего")
	Warmup.enabled = false
	ok(not Warmup.new().active(), "выключен — сразу готов")


func test_scene_warmup() -> void:
	Warmup.enabled = true
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	Warmup.enabled = false
	ok(main.warming(), "при старте идёт прогрев")
	ok(main.curtain != null and main.curtain.visible, "экран под шторкой")
	eq(main.crew.size(), 1 + CrewRig.MODELS.size(), "каждая внешность экипажа в кадре")
	var qa := main.start_qa('[{"do": "wait", "s": 1}, {"do": "log", "note": "прогрев"}]')
	var torch: Node3D = main.crew_view.torches[0]
	var lamp_off_seen := false
	var yaws := {}
	for i in Warmup.VIEWS.size() - 1:   # первый взгляд показан при старте, дальше по кадру на взгляд
		main.step(1.0 / 60.0)
		ok(main.warming(), "кадр %d — ещё прогрев" % i)
		near(main.camera.position.distance_to(Warmup.EYE), 0.0, 1e-6, "камера в центре мостика")
		yaws[roundi(rad_to_deg(main.camera.rotation.y))] = true
		ok(torch.visible, "скрытый резак показан на кадр")
		ok(main.zap_light.visible and main.zap_light.omni_range > 79.0, "вспышка разряда на весь радиус")
		if not main.searchlight.spot.visible:
			lamp_off_seen = true
		eq(qa.time, 0.0, "сценарий тестера ждёт прогрева")
	main.step(1.0 / 60.0)
	ok(not main.warming(), "прогрев кончился")
	ok(yaws.size() >= 6, "камера обошла круг: %s" % str(yaws.keys()))
	ok(lamp_off_seen, "был кадр без прожектора")
	ok(main.curtain == null, "шторка снята")
	eq(main.crew, [main.me], "временные члены экипажа ушли")
	ok(not torch.visible, "резак снова скрыт")
	ok(not main.zap_light.visible, "вспышка погашена")
	ok(main.searchlight.spot.visible, "прожектор горит")
	near(main.camera.position.distance_to(main.pilot.eye(main.walker) + main.me.eye_offset()), 0.0, 1e-3, "камера в голове игрока")
	main.step(1.0 / 60.0)
	ok(qa.time > 0.0, "сценарий пошёл")
	ok(qa.log_lines[1].begins_with("прогрев шейдеров: %d кадров" % (Warmup.VIEWS.size() - 1)), "в логе тестера: %s" % qa.log_lines[1])
	main.queue_free()
	await frames(1)
