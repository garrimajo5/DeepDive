extends TestCase
## Прогрев шейдеров при старте (issue #50): шторка, камера оглядывает корабль, скрытое показано на кадр,
## каждая внешность экипажа. Прожектор и вспышка разряда всегда в сцене (issue #159): набор огней один.


func test_views_cover_circle() -> void:
	var yaws := {}
	for v in Warmup.VIEWS:
		if v[1] > -30.0 and v[1] < 30.0:
			yaws[int(v[0]) % 360] = true
	for y in range(0, 360, 60):
		ok(yaws.has(y), "взгляд на курс %d°" % y)
	ok(Warmup.frames() <= 12, "кадров прогрева немного: %d (issue #159)" % Warmup.frames())
	ok(Deck.FOV > 60.0, "шаг 60° не оставляет щелей при поле зрения %.0f°" % Deck.FOV)
	near(Warmup.zap_radius(), 80.0, 1e-6, "разряд на пределе доли: 60 / 15 × 20 м")


## Строка лога «по кадрам» (issue #159): тестер видит, какой взгляд прогрева дорогой.
func test_warm_line() -> void:
	var ms: Array[int] = [20, 24800, 7300, 400]
	eq(QaRunner.warm_line(ms), "20, 24800, 7300, 400; худший — кадр 1")
	var none: Array[int] = []
	eq(QaRunner.warm_line(none), "—")


## Вспышка разряда гаснет энергией к концу мигания; погашенный свет — Searchlight.DARK, не 0 (issue #159).
func test_flash_energy() -> void:
	near(Zap.flash_energy(Zap.FLICKER), 4.0, 1e-6, "на пике 4")
	near(Zap.flash_energy(Zap.FLICKER * 0.5), 2.0, 1e-6, "к концу слабее")
	near(Zap.flash_energy(0.0), 0.0, 1e-6, "мигание кончилось")
	ok(Searchlight.DARK > 0.0 and Searchlight.DARK < 0.01, "погашенный свет почти без энергии, но не 0")


func test_sweep_order() -> void:
	Warmup.enabled = true
	var w := Warmup.new()
	ok(w.active(), "включён")
	var ends := 0
	var outside := 0
	for i in Warmup.frames():
		ok(w.active(), "взгляд %d" % i)
		if w.outside() >= 0:
			outside += 1
		if w.advance():
			ends += 1
	eq(ends, 1, "конец сообщается один раз")
	eq(outside, Warmup.OUTSIDE.size(), "кадры снаружи — после мостика")
	eq(w.outside(), -1, "после прогрева снаружи не смотрим")
	ok(not w.active(), "прогрев кончился")
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
	var yaws := {}
	var steam: CPUParticles3D = main.rooms.steam
	ok(steam.emitting and main.breach_view.spray.emitting, "частицы корабля выпущены на прогрев")
	var outside := 0
	for i in Warmup.frames() - 1:   # первый взгляд показан при старте, дальше по кадру на взгляд
		main.step(1.0 / 60.0)
		ok(main.warming(), "кадр %d — ещё прогрев" % i)
		ok(main.vote_panel.visible, "панель решения экипажа под шторкой")
		ok(main.power_panel.visible and main.power_panel.reactor != null, "пульт энергии рисуется под шторкой (#217)")
		if main.warm.outside() >= 0:
			outside += 1
			ok(main.flyby_cam.current, "кадр снаружи — камера с борта")
			ok(main.flyby_cam.global_position.distance_to(main.ship.global_position) > 20.0, "камера вне корпуса")
			continue
		near(main.camera.position.distance_to(Warmup.EYE), 0.0, 1e-6, "камера в центре мостика")
		yaws[roundi(rad_to_deg(main.camera.rotation.y))] = true
		ok(torch.visible, "скрытый резак показан на кадр")
		ok(main.zap_light.visible and main.zap_light.omni_range > 79.0, "вспышка разряда в сцене на весь радиус")
		ok(main.searchlight.spot.visible, "прожектор в сцене")
		eq(qa.time, 0.0, "сценарий тестера ждёт прогрева")
	main.step(1.0 / 60.0)
	ok(not main.warming(), "прогрев кончился")
	eq(outside, Warmup.OUTSIDE.size(), "были кадры снаружи")
	ok(not steam.emitting and not main.breach_view.spray.emitting, "частицы снова не идут")
	near(steam.preprocess, 0.0, 1e-9, "preprocess пара вернулся")
	ok(not main.vote_panel.visible, "панель решения снова скрыта")
	ok(not main.power_panel.visible, "пульт энергии снова скрыт")
	ok(main.camera.current, "глаза на мостике")
	ok(yaws.size() >= 6, "камера обошла круг: %s" % str(yaws.keys()))
	ok(main.curtain == null, "шторка снята")
	eq(main.crew, [main.me], "временные члены экипажа ушли")
	ok(not torch.visible, "резак снова скрыт")
	ok(main.zap_light.visible and main.zap_light.light_energy < 0.01, "вспышка в сцене, но погашена")
	ok(main.zap_light.omni_range > 79.0, "радиус вспышки прежний — набор огней на отмели не меняется")
	ok(main.searchlight.spot.visible and main.searchlight.spot.light_energy > 1.0, "прожектор горит")
	near(main.camera.position.distance_to(main.pilot.eye(main.walker) + main.me.eye_offset()), 0.0, 1e-3, "камера в голове игрока")
	main.step(1.0 / 60.0)
	ok(qa.time > 0.0, "сценарий пошёл")
	ok(qa.log_lines[1].begins_with("прогрев шейдеров: %d кадров" % (Warmup.frames() - 1)), "в логе тестера: %s" % qa.log_lines[1])
	ok(qa.log_lines[2].begins_with("прогрев по кадрам, мс: ") and qa.log_lines[2].contains("худший — кадр"),
		"в логе тестера время каждого кадра прогрева: %s" % qa.log_lines[2])
	main.queue_free()
	await frames(1)


## Облёт с борта в начале забега ждёт конца прогрева: под шторкой смотрят глаза на мостике.
func test_scene_flyby_waits() -> void:
	Warmup.enabled = true
	Main.intro = true
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	Warmup.enabled = false
	Main.intro = false
	for i in Warmup.frames() - 1:
		main.step(0.5)
		if main.warm.outside() < 0:
			ok(main.camera.current, "кадр %d прогрева — камера мостика" % i)
	near(main.flyby.t, 0.0, 1e-9, "облёт не начался")
	main.step(0.5)
	ok(not main.warming() and main.flyby.active(), "прогрев кончился — облёт")
	ok(main.flyby_cam.current, "камера с борта")
	main.queue_free()
	await frames(1)
