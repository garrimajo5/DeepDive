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
	ok(Warmup.frames() <= 19, "кадров прогрева немного: %d (issue #159; +1 — вид при всплытии, #519; +3 — первый взгляд по слоям, #424)" % Warmup.frames())
	ok(Deck.FOV > 60.0, "шаг 60° не оставляет щелей при поле зрения %.0f°" % Deck.FOV)
	near(Warmup.zap_radius(), 80.0, 1e-6, "разряд на пределе доли: 60 / 15 × 20 м")


## Issue #217: рывок при первом нажатии у пульта — прогрев смотрит и глазами у пульта (место и наклон, как после
## нажатия), за штурвалом сидя и у сканера.
func test_post_views() -> void:
	var power := false
	var seat := false
	for v in Warmup.POSTS:
		var at := Vector3(v[0], v[1], v[2])
		if at.distance_to(PowerScreen.cam_pos(Vector3(0.0, Deck.Walker.EYE, 0.0))) < 1e-4 \
				and absf(deg_to_rad(v[4]) - Main.POWER_PITCH) < 0.01 \
				and absf(deg_to_rad(v[3]) - PowerScreen.cam_yaw(PowerScreen.STAND_YAW)) < 1e-4:
			power = true
		if at.distance_to(Vector3(0.0, Deck.SEAT_EYE, Deck.SEAT_Z)) < 1e-4:
			seat = true
		ok(Deck.can_stand(v[0], v[2]) or v[1] == Deck.SEAT_EYE, "глаза у поста %s на палубе" % str(at))
	ok(power, "взгляд у пульта энергии, как после нажатия")
	ok(seat, "взгляд за штурвалом сидя")
	Warmup.enabled = true
	var w := Warmup.new()
	Warmup.enabled = false
	var eyes := []
	while w.outside() < 0 and w.active():
		eyes.append(w.eye())
		w.advance()
	eq(eyes.size(), Warmup.STAGES + Warmup.VIEWS.size() + Warmup.POSTS.size(), "взгляды с мостика: по слоям, из центра и у постов")
	eq(eyes[0], Warmup.EYE, "сначала из центра")
	eq(eyes[-1], Vector3(Warmup.POSTS[-1][0], Warmup.POSTS[-1][1], Warmup.POSTS[-1][2]), "потом у постов")


## Строка лога «по кадрам» (issue #159): тестер видит, какой взгляд прогрева дорогой.
func test_warm_line() -> void:
	var ms: Array[int] = [20, 24800, 7300, 400]
	eq(QaRunner.warm_line(ms), "до первого кадра 20; кадры: 24800, 7300, 400; худший — кадр 1 из 3")
	var none: Array[int] = []
	eq(QaRunner.warm_line(none), "—")
	var one: Array[int] = [85]
	eq(QaRunner.warm_line(one), "до первого кадра 85")


## Чисел кадров в строке «по кадрам» столько же, сколько в заголовке «N кадров» (отчёт qa/2026-10-21-2310:
## 15 чисел при 14 кадрах — первое число было сборкой сцены до прогрева).
func test_warm_line_matches_header() -> void:
	var ms: Array[int] = [85, 34687, 7481, 933, 37, 1335, 36, 28, 30, 25, 25, 25, 30, 25, 24]
	var line := QaRunner.warm_line(ms)
	var frames := line.split("кадры: ")[1].split(";")[0].split(", ")
	eq(frames.size(), 14, "14 кадров — 14 чисел")
	ok(line.ends_with("худший — кадр 1 из 14"), line)


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


## Issue #519: провал 211 мс на продувке при виде с борта у поверхности — прогрев смотрит и оттуда: кадр снаружи
## совпадает с концом облёта `Flyby.Kind.SURFACE` (камера под бортом, взгляд вверх), кадры начала облёта на месте.
func test_outside_surface() -> void:
	var f := Flyby.new()
	f.start(Flyby.Kind.SURFACE)
	f.t = f.length()
	var end := f.pose()
	var found := false
	for k in Warmup.OUTSIDE.size():
		var pose := Warmup.outside_pose(k)
		if pose.origin.distance_to(end.origin) < 1e-4 and (-pose.basis.z).dot(-end.basis.z) > 0.9999:
			found = true
	ok(found, "вид при всплытии в кадрах снаружи")
	var start := Warmup.outside_pose(0)
	near(start.origin.distance_to(Flyby.START_PATH[0]), 0.0, 1e-6, "первый кадр снаружи — начало облёта")
	ok((-start.basis.z).dot((Flyby.LOOK_AT - start.origin).normalized()) > 0.9999, "смотрит на корпус")


func test_scene_warmup() -> void:
	Warmup.enabled = true
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	Warmup.enabled = false
	ok(main.warming(), "при старте идёт прогрев")
	ok(main.curtain != null and main.curtain.visible, "экран под шторкой")
	eq(main.crew.size(), 1 + 2 * CrewRig.MODELS.size(), "каждая внешность экипажа в кадре — и материалом своего игрока")
	var qa := main.start_qa('[{"do": "wait", "s": 1}, {"do": "log", "note": "прогрев"}]')
	var torch: Node3D = main.crew_view.torches[0]
	var yaws := {}
	var steam: SteamView = main.rooms.steam
	ok(main.breach_view.jet_mm.visible and main.breach_view.spark_mm.visible, "частицы пробоины ART-072 в кадре прогрева — пустой карточкой")
	ok(steam.visible and steam.multimesh.visible_instance_count >= 1, "пар ART-071 в кадре прогрева — пустой карточкой")
	var outside := 0
	var up_view := false
	near(main.curtain.progress, 0.0, 1e-9, "заставка с 0 %")
	var prev := 0.0
	for i in Warmup.frames() - 1:   # первый взгляд показан при старте, дальше по кадру на взгляд
		main.step(1.0 / 60.0)
		ok(main.warming(), "кадр %d — ещё прогрев" % i)
		ok(main.curtain.progress > prev, "полоса заставки растёт по кадрам прогрева (ART-034)")
		prev = main.curtain.progress
		ok(main.vote_panel.visible, "панель решения экипажа под шторкой")
		ok(main.power_panel.visible and main.power_panel.reactor != null, "пульт энергии рисуется под шторкой (#217)")
		if main.warm.outside() >= 0:
			outside += 1
			ok(main.flyby_cam.current, "кадр снаружи — камера с борта")
			ok(main.flyby_cam.global_position.distance_to(main.ship.global_position) > 20.0, "камера вне корпуса")
			ok(main.wake_view.visible and main.wake_view.multimesh.visible_instance_count >= 1,
					"пузыри следа и продувки ART-063 в кадре снаружи — пустой карточкой (#519)")
			if -main.flyby_cam.global_basis.z.y > 0.05:   # снизу вверх: при облёте START камера смотрит вниз
				up_view = true
			continue
		near(main.camera.position.distance_to(main.warm.eye()), 0.0, 1e-6, "камера в центре мостика или у поста")
		yaws[roundi(rad_to_deg(main.camera.rotation.y))] = true
		ok(torch.visible, "скрытый резак показан на кадр")
		ok(main.zap_light.visible and main.zap_light.omni_range > 79.0, "вспышка разряда в сцене на весь радиус")
		ok(main.searchlight.spot.visible, "прожектор в сцене")
		eq(qa.time, 0.0, "сценарий тестера ждёт прогрева")
	main.step(1.0 / 60.0)
	ok(not main.warming(), "прогрев кончился")
	eq(outside, Warmup.OUTSIDE.size(), "были кадры снаружи")
	ok(up_view, "кадр снаружи снизу вверх — как при всплытии (#519)")
	ok(not main.wake_view.visible, "след снова скрыт — пузырей нет")
	ok(not steam.visible and not main.breach_view.jet_mm.visible, "частицы снова скрыты, пар скрыт")
	eq(main.breach_view.parts.count(), 0, "частиц пробоины прогрев не родил")
	eq(main.valve_steam.puffs.size(), 0, "клубов пара прогрев не родил")
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


## Issue #217: свой игрок нарисован отдельным материалом (`CrewView._own_mat`, отсечение граней — свой шейдер), а видно
## его только взглядом вниз у поста: без прогрева шейдер собирался при первом нажатии у пульта энергии.
func test_scene_warmup_own_material() -> void:
	Warmup.enabled = true
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	Warmup.enabled = false
	var cv: CrewView = main.crew_view
	var own_key := ShaderKey.of(cv._own_mat[main.me.look])
	var keys := {}
	for m in cv._own_mat.values():
		keys[ShaderKey.of(m)] = true
	for k in keys:
		var shown := false
		for i in cv.members.size():
			if cv.members[i] == main.me or ShaderKey.of(cv.meshes[i].material_override) != k:
				continue
			var at: Vector3 = cv.to_global(cv.shown[i]["hip"])
			if main.camera.is_position_in_frustum(at):
				shown = true
		ok(shown, "фигура с материалом своего игрока в первом кадре прогрева: %s" % k)
	ok(own_key in keys, "ключ своего игрока среди прогретых")
	for i in Warmup.frames():
		main.step(1.0 / 60.0)
	ok(not main.warming(), "прогрев кончился")
	eq(cv.as_own, [], "временные фигуры своим материалом ушли")
	main.step(1.0 / 60.0)
	eq(cv.meshes[0].material_override, cv._own_mat[main.me.look], "свой игрок — своим материалом")
	main.queue_free()
	await frames(1)


## Issue #217: в первом кадре прогрева каждая деталь корабля, отмели, ила и образцов видна и ей есть что рисовать.
## Рамка подсказки табло тревог была без меша до первой тревоги — прогрев её не рисовал, и её шейдер (без света,
## без отсечения граней) собирался, когда рамка у пульта энергии впервые попадала в кадр — на нажатии у пульта.
func test_scene_warmup_draws_every_mesh() -> void:
	Warmup.enabled = true
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	Warmup.enabled = false
	for i in Warmup.STAGES:   # первый взгляд по слоям (#424) — до кадра, где виден весь мир
		main.step(1.0 / 60.0)
	ok(main.warming() and main.warm.stage() == -1, "идёт прогрев, первый взгляд целиком")
	for root: Node in [main.ship, main.ocean, main.silt_view, main.samples_view]:
		for n in root.find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			ok(g.is_visible_in_tree(), "в кадре прогрева показано: %s" % g.name)
			if g is MeshInstance3D:
				ok((g as MeshInstance3D).mesh != null, "есть меш у %s" % g.name)
			elif g is MultiMeshInstance3D:
				var mm := (g as MultiMeshInstance3D).multimesh
				ok(mm != null and mm.mesh != null and mm.instance_count > 0, "есть что рисовать у %s" % g.name)
	main.queue_free()
	await frames(1)


## Issue #424: на холодном кэше кадр 1 прогрева собирал почти все шейдеры (8,3 с из 10,9 на эмуляторе), полоса заставки
## стояла. Первые Warmup.STAGES кадров — тот же первый взгляд, мир показывается слоями Main.warm_layers(): на кадре s
## видны слои 0…s, остальное скрыто только на этот кадр; дальше всё видно, как раньше.
func test_stage_order() -> void:
	Warmup.enabled = true
	var w := Warmup.new()
	Warmup.enabled = false
	for s in Warmup.STAGES:
		eq(w.stage(), s, "кадр %d — слой %d" % [s, s])
		eq(w.eye(), Warmup.EYE, "слой %d — из центра мостика" % s)
		near(w.yaw(), deg_to_rad(Warmup.VIEWS[0][0]), 1e-9, "слой %d — первым взглядом" % s)
		near(w.pitch(), deg_to_rad(Warmup.VIEWS[0][1]), 1e-9, "наклон первого взгляда")
		w.advance()
	eq(w.stage(), -1, "после слоёв — обычные кадры")
	near(w.pitch(), deg_to_rad(Warmup.VIEWS[0][1]), 1e-9, "первый взгляд целиком")
	w.advance()
	near(w.yaw(), deg_to_rad(Warmup.VIEWS[1][0]), 1e-9, "дальше — круг взглядов")


func test_scene_warm_layers() -> void:
	Warmup.enabled = true
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	Warmup.enabled = false
	var layers := main.warm_layers()
	eq(layers.size(), Warmup.STAGES + 1, "слоёв на один больше кадров по слоям: последний виден с первого полного кадра")
	eq(layers[0], [], "слой 0 — интерьер и всё, чего нет в других слоях")
	var seen := {}
	for s in Warmup.STAGES:
		eq(main.warm.stage(), s, "кадр по слоям %d" % s)
		for k in layers.size():
			for n: Node3D in layers[k]:
				if k > s:
					ok(not n.visible, "%s на кадре слоя %d скрыт" % [n.name, s])
				elif n.visible:
					seen[n] = true
		ok(main.bridge.visible and main.rooms.visible, "интерьер виден на каждом кадре")
		ok(main.camera.current, "камера мостика")
		main.step(1.0 / 60.0)
	eq(main.warm.stage(), -1, "слои кончились")
	for k in layers.size():
		for n: Node3D in layers[k]:   # ил (SiltView) скрыт до события — его слои не трогают
			ok(n.visible or not seen.has(n), "%s снова виден" % n.name)
	for n in [main.crew_view, main.hull, main.ocean]:   # живой мир — с первого полного кадра
		ok(seen.has(n), "%s показан на своём кадре" % n.name)
	ok(main.eco in layers[-1] and main.ocean in layers[-2], "вода и живой мир — последними (самые тяжёлые)")
	while main.warming():
		main.step(1.0 / 60.0)
	ok(main.ocean.visible and main.eco.visible and main.hull.visible and main.crew_view.visible, "после прогрева мир виден")
	main.queue_free()
	await frames(1)


## #752: прогрев на сцене вынесен из Main в WarmRunner (`main.warm_run`): состояние — у него, после прогрева пусто.
func test_scene_warm_runner() -> void:
	Warmup.enabled = true
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	Warmup.enabled = false
	ok(main.warm_run is WarmRunner and main.warm_run.main == main, "прогрев сцены — поле main.warm_run")
	ok(not ("_warm_shown" in main) and not ("_warm_mates" in main), "состояние прогрева больше не в Main")
	ok(main.warm_run._mates.size() == 2 * CrewRig.MODELS.size(), "члены экипажа каждой внешности — у WarmRunner")
	ok(main.warm_run._shown.size() > 0, "скрытое показано на кадр")
	eq(main.warm_layers(), main.warm_run.layers(), "Main.warm_layers — пересылка")
	while main.warming():
		main.step(1.0 / 60.0)
	main.step(1.0 / 60.0)
	ok(main.warm_run._mates.is_empty() and main.warm_run._shown.is_empty() and main.warm_run._hidden.is_empty()
		and main.warm_run._emit.is_empty(), "после прогрева у WarmRunner пусто")
	eq(main.crew, [main.me], "временные члены экипажа ушли")
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
