extends TestCase
## Сценарий тестера: разбор, порядок команд, прогон в сцене без тапов по координатам.


func _run_all(q: QaScript, secs: float, dt: float = 0.05) -> Array:
	var all: Array = []
	for i in int(secs / dt):
		all.append_array(q.advance(dt))
	return all


func test_parse_skips_bad_steps() -> void:
	var q := QaScript.parse('[{"do":"wait","s":1},{"do":"fly"},{"do":"press","what":"nose"},{"do":"press","what":"pad"},{"do":"shot","name":"a"}]')
	eq(q.steps.size(), 2, "остались хорошие шаги")
	eq(q.errors.size(), 3, "три ошибки")
	ok(QaScript.parse("{}").errors.size() == 1, "не массив — ошибка")


func test_order_and_timing() -> void:
	var q := QaScript.parse('[{"do":"wait","s":1},{"do":"shot","name":"a"},{"do":"hold","what":"pad","dir":[0,1],"s":2},{"do":"log","note":"x"}]')
	var first := q.advance(0.5)
	eq(first.size(), 0, "ждём")
	var second := q.advance(0.6)
	eq(second[0], ["shot", "a"], "скриншот после секунды")
	eq(second[1][0], "begin", "и сразу держим крестовину")
	eq(second[1][2], "pad", "крестовина")
	var rest := _run_all(q, 3.0)
	var kinds := rest.map(func(c): return c[0])
	eq(kinds, ["end", "log", "done"], "отпустили, лог, конец")
	ok(q.finished, "сценарий закончен")


func test_shot_after_goto_waits_frame() -> void:   # issue #216: 09g-tablo снимал кадр до перехода
	var q := QaScript.parse('[{"do":"wait","s":0.1},{"do":"goto","x":0,"z":1.5,"yaw":0},{"do":"shot","name":"g"},{"do":"log","note":"x"},{"do":"goto","x":1,"z":1,"yaw":0},{"do":"wait","s":1}]')
	var first := q.advance(0.15)
	eq(first.map(func(c): return c[0]), ["goto"], "сначала только переход — кадр с новым местом")
	var second := q.advance(0.05)
	eq(second[0], ["shot", "g"], "снимок в следующем шаге")
	eq(second.map(func(c): return c[0]), ["shot", "log", "goto"], "дальше по порядку")
	var r := QaScript.parse('[{"do":"hold","what":"action","s":0.2},{"do":"shot","name":"h"}]')
	var held := _run_all(r, 0.3)
	eq(held.map(func(c): return c[0]), ["begin", "end", "shot", "done"], "после удержания снимок сразу — пар ещё в кадре")


func test_swipe_moves_full_distance() -> void:
	var q := QaScript.parse('[{"do":"swipe","dx":300,"dy":-40,"s":0.5}]')
	var sum := Vector2.ZERO
	for c in _run_all(q, 1.0, 1.0 / 30.0):
		if c[0] == "move":
			sum += c[2]
	ok(sum.distance_to(Vector2(300, -40)) < 0.01, "свайп прошёл всё расстояние: %s" % str(sum))


func test_scene_runs_scenario() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var qa := main.start_qa(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	eq(qa.script_q.errors.size(), 0, "сценарий из tools/qa без ошибок")
	var z0 := main.helm.pos.z
	var ahead := 0.0   # дальше всего ушли вперёд (шаг sample потом ставит корабль над образцом)
	var sat := false
	var table_seen := false
	var zap_seen := false
	var arc_seen := false   # 10a-zap-okno: дуга ART-068 у окна в кадре, пока видна
	var shots := 0
	var table: Node3D = main.bridge.props[BridgeProps.TABLE]
	var legs_seen := false
	var weld_y := -1.0   # issue #524: на 16-breach-weld шов в середине кадра по высоте (доля от верха)
	var card_seen := false   # 30: карточка роли ART-045 на экране
	var power_hot := false   # 08a: открытый пульт на перегреве (ART-050)
	var cooled := false      # к 09-sonar перегрев снят шагом hot 0
	var no_answer := false   # 29f: экран адреса ART-039 дождался «Нет ответа»
	for i in 3600:  # 120 с игры (сценарий идёт ~113 с)
		# снимок берёт уже нарисованный кадр — камеру до шага, в котором он снят
		var cam := main.camera
		var table_vis := cam.is_position_in_frustum(table.global_position + table.global_basis.y * 0.9)
		var zap_vis := cam.is_position_in_frustum(main.ship.to_global(Zap.LEVER_POS))
		var arc_t := Zap.arc_time(main.zap.flicker)
		var arc_at := (Zap.WINDOW_FROM + Zap.WINDOW_TO) / 2.0 + Vector3(maxf(arc_t, 0.0) * Zap.ARC_FLOW, 0.0, 0.0)
		var arc_vis := main.hull.zap_cards.visible and cam.is_position_in_frustum(main.ship.to_global(arc_at)) \
				and Zap.card_k(Zap.Card.WINDOW, arc_t) > 0.1
		var j: Dictionary = main.me.joints()
		var legs_vis := true
		for k in ["toe_l", "toe_r", "hand_l", "hand_r"]:
			legs_vis = legs_vis and cam.is_position_in_frustum(main.ship.to_global(j[k]))
		var card_vis: bool = main.role_card_panel.visible and main.role_card.a > 0.5
		var weld_at := -1.0
		if main.breach.active:
			var seam := main.ship.to_global(main.breach.active.p)
			if cam.is_position_in_frustum(seam):
				weld_at = cam.unproject_position(seam).y / cam.get_viewport().get_visible_rect().size.y
		var hot_vis := main.at_power and main.power_panel.visible and main.reactor.hot
		var cool_vis := not main.reactor.hot and main.reactor.scram == 0.0
		main.step(1.0 / 30.0)
		no_answer = no_answer or (main.address.open and main.address.hint() == AddressScreen.NO_ANSWER)
		sat = sat or main.pilot.seated
		ahead = maxf(ahead, z0 - main.helm.pos.z)
		for k in range(shots, qa.log_lines.size()):   # #48: на 09-sonar в кадре голостол, на 10-zap — рычаг
			if qa.log_lines[k].begins_with("скриншот 09-sonar"):
				table_seen = table_vis
				cooled = cool_vis
			if qa.log_lines[k].begins_with("скриншот 08a-power-hot"):
				power_hot = hot_vis
			if qa.log_lines[k].begins_with("скриншот 06b-own-legs"):
				legs_seen = legs_vis
			if qa.log_lines[k].begins_with("скриншот 16-breach-weld"):
				weld_y = weld_at
			if qa.log_lines[k].begins_with("скриншот 10-zap"):
				zap_seen = zap_vis
			if qa.log_lines[k].begins_with("скриншот 10a-zap-okno"):
				arc_seen = arc_vis
			if qa.log_lines[k].begins_with("скриншот 30-kartochka-sonar"):
				card_seen = card_vis
		shots = qa.log_lines.size()
		if qa.script_q.finished:
			break
	ok(qa.script_q.finished, "сценарий дошёл до конца")
	ok(power_hot, "на 08a-power-hot пульт открыт и реактор перегрет (ART-050)")
	ok(cooled, "шаг hot 0 остудил реактор: 09-sonar без перегрева и сброса")
	ok(weld_y > 0.3 and weld_y < 0.7, "на 16-breach-weld шов в середине кадра: %.2f высоты (#524)" % weld_y)
	ok(sat, "по сценарию садились за штурвал")
	ok(not main.pilot.seated, "и встали")
	ok(ahead > 20.0, "корабль прошёл вперёд: %.1f м" % ahead)
	ok(FileAccess.file_exists(QaRunner.OUT + "/done.txt"), "done.txt записан")
	var log := FileAccess.get_file_as_string(QaRunner.OUT + "/log.txt")
	ok(log.contains("сел за штурвал") and log.contains("за штурвалом"), "в логе есть состояние за штурвалом")
	ok(log.contains("прожектор погашен | ") and log.contains("свет выкл"), "по сценарию гасили прожектор")
	ok(main.light_on, "и зажгли снова")
	ok(log.contains("пульт энергии | ") and log.contains("у пульта энергии"), "по сценарию открывали пульт энергии")
	ok(not main.at_power, "и закрыли")
	ok(log.contains("реактор [25, 20, 25, 15, 10]"), "на пульте сняли 5 с двигателей")
	eq(main.reactor.share, Reactor.DEFAULTS, "после итога новый забег — доли как на старте (#265)")
	ok(not log.split("23-helm-busy")[-1].contains("сброс"), "в новом забеге нет аварийного сброса (#265)")
	ok(main.sonar.ping_time > 0.0, "у голостола дали импульс сонара")
	ok(main.zap.last > 0.0, "у рычага дали разряд")
	ok(table_seen, "на снимке 09-sonar голостол в кадре (#48)")
	ok(zap_seen, "на снимке 10-zap рычаг в кадре")
	ok(arc_seen, "на снимке 10a-zap-okno — дуга у носового окна (ART-068)")
	ok(card_seen, "на снимке 30-kartochka-sonar — карточка роли (ART-045)")
	ok(not main.role_card.on, "после — карточки выключены")
	ok(no_answer, "экран «Войти по адресу»: без хоста — «Нет ответа» (29f)")
	ok(not main.address.open, "«Назад» закрыл экран адреса")
	ok(legs_seen, "на снимке 06b-own-legs в кадре свои ступни и кисти (#49)")
	ok(log.contains("курс %d°" % Status.course_deg(main.helm.yaw)), "курс в логе — как на приборах, без минуса (#48)")
	ok(log.contains("вентиль: пар ART-071") and log.contains("реактор остывает | "), "в машинном держали вентиль")
	ok(log.contains("аварийный сброс щитком | ") and log.contains("° сброс"), "щитком заглушили реактор")
	ok(log.contains("пробоина на мостике: струя, вода, янтарная тревога; на слух — сирена и шум струи | ") and log.contains("ПРОБОИНА · МОСТИК · вода"),
		"пробоина на мостике — на приборах")
	# пробоину смотрим в строке «шов заварен», не в конце: в новом забеге из меню корабль снова могут ударить
	var welded := log.split("шов заварен")[-1].split("\n")[0] if log.contains("шов заварен") else "ПРОБОИНА"
	ok(log.contains("сварка: заплатка наполовину") and not welded.contains("ПРОБОИНА") and log.contains("Вода: мостик"),
		"заварили, вода откачивается")
	eq(main.samples.cargo.size(), 1, "лебёдкой подняли образец")
	ok(log.contains("лебёдка: захват тянется к образцу | ") and log.contains("лебёдка: образец в трюме | "), "лебёдка в логе")


func test_sample_step() -> void:
	var q := QaScript.parse('[{"do": "sample", "n": 8}]')
	eq(q.errors.size(), 0, "шаг sample известен")
	eq(q.advance(0.1)[0], ["sample", 8], "корабль над образцом 8")


func test_goto_and_hot_steps() -> void:
	var q := QaScript.parse('[{"do": "goto", "x": 2.2, "z": 17.2, "yaw": -90}, {"do": "hot", "heat": 75}]')
	eq(q.errors.size(), 0, "шаги понятны")
	var out := q.advance(0.1)
	eq(out[0], ["goto", 2.2, 17.2, -90.0], "переход")
	eq(out[1], ["hot", 75.0], "перегрев")
	var q2 := QaScript.parse('[{"do": "goto", "x": 0.9, "z": 0.0, "yaw": 37, "pitch": -35}]')
	eq(q2.advance(0.1)[0], ["goto", 0.9, 0.0, 37.0, -35.0], "переход с наклоном взгляда")


func test_mate_step() -> void:
	var q := QaScript.parse('[{"do": "mate", "x": 0.2, "z": -2.6, "yaw": 60, "role": 2, "look": 1}]')
	eq(q.errors.size(), 0, "шаг mate известен")
	eq(q.advance(0.1)[0], ["mate", 0.2, -2.6, 60.0, 2, 1, false], "член экипажа: место, курс, роль, внешность")
	var q2 := QaScript.parse('[{"do": "mate", "seated": true, "role": 1}]')
	eq(q2.advance(0.1)[0][6], true, "член экипажа за штурвалом")
	var q3 := QaScript.parse('[{"do": "mate", "x": 1.5, "z": 0.5, "role": 2, "walk": [0, 1, 1.5]}]')
	eq(q3.advance(0.1)[0].slice(7), [0.0, 1.0, 1.5], "идёт своим вводом: крестовина и секунды")


func test_act_step() -> void:   # товарищ жмёт свою кнопку действия
	var q := QaScript.parse('[{"do": "act"}]')
	eq(q.errors.size(), 0, "шаг act известен")
	eq(q.advance(0.1)[0], ["act"], "команда сцене")


func test_gone_step() -> void:   # товарищ отключился, как гость сети: у хоста плашка ART-043
	var q := QaScript.parse('[{"do": "gone"}]')
	eq(q.errors.size(), 0, "шаг gone известен")
	eq(q.advance(0.1)[0], ["gone"], "команда сцене")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.start_qa('[{"do": "mate", "x": -3.5, "z": -2.0, "yaw": 90, "role": 2, "look": 0}, {"do": "act"},'
		+ ' {"do": "wait", "s": 0.3}, {"do": "gone"}, {"do": "wait", "s": 0.3}]')
	for i in 30:
		main.step(1.0 / 30.0)
	eq(main.crew.size(), 1, "инженер ушёл с палубы")
	ok(Crew.holder(main.crew, main.me, "energy") == null, "пульт свободен")
	ok(main.notice.active(), "плашка у хоста")
	eq(main.notice.sub, "Роль свободна · пост освобождён", "держал пульт")
	main.queue_free()
	await frames(1)


func test_silt_step() -> void:
	var q := QaScript.parse('[{"do": "silt"}, {"do": "silt", "on": false}]')
	eq(q.errors.size(), 0, "шаг silt известен")
	var out := q.advance(0.1)
	eq(out[0], ["silt", true], "ил вокруг корабля")
	eq(out[1], ["silt", false], "убрать ил")


func test_drain_step() -> void:   # issue #131: тревога о стеклоусте видна в прогоне тестера
	var q := QaScript.parse('[{"do": "drain", "s": 2.5}]')
	eq(q.errors.size(), 0, "шаг drain известен")
	eq(q.advance(0.1)[0], ["drain", 2.5], "стеклоуст на корпусе 2,5 с")


func test_hull_step() -> void:   # следы повреждений ART-049 на виде с борта
	var q := QaScript.parse('[{"do": "hull", "pct": 30}, {"do": "hull", "pct": 140}]')
	eq(q.errors.size(), 0, "шаг hull известен")
	var out := q.advance(0.1)
	eq(out[0], ["hull", 30.0], "корпус 30 %")
	eq(out[1], ["hull", 100.0], "выше 100 % не бывает")


## issue #158: снимок полок трюма смотрел на правый стеллаж, а первая банка встаёт на левый.
func test_shelves_shot_sees_first_jar() -> void:
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	var at := {}
	for st in steps:
		if st["do"] == "goto":
			at = st
		if st["do"] == "shot" and st["name"] == "14b-hold-shelves":
			break
	ok(not at.is_empty(), "перед снимком полок — goto")
	var yaw := deg_to_rad(float(at["yaw"]))
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var jar: Vector3 = HoldShelves.cells()[0]
	var to := Vector2(jar.x - float(at["x"]), jar.z - float(at["z"]))
	ok(rad_to_deg(fwd.angle_to(to)) < 25.0, "первая банка перед камерой: %.0f°" % rad_to_deg(absf(fwd.angle_to(to))))
	ok(ShipLayout.new().can_stand(float(at["x"]), float(at["z"])), "тестер стоит на полу")


func test_fps_skips_shot_frame() -> void:   # issue #169: кадр скриншота не роняет средние кадр/с
	var r := QaRunner.new()
	var t := 1000000
	r._measure(t)                 # первый кадр после старта не считается
	for i in 30:                  # 30 кадров по 20 мс = 50 к/с
		t += 20000
		r._measure(t)
	eq(r.fps(), 50, "свои кадр/с: 30 кадров по 20 мс")
	eq(roundi(r.worst_ms), 20, "худший кадр 20 мс")
	r.worst_ms = 0.0              # как после _shot: сброс и пропуск кадра снимка
	r.frames = 0
	r.frames_us = 0
	r._skip_frame = true
	t += 900000                   # сам снимок — 0,9 с
	r._measure(t)
	for i in 10:
		t += 20000
		r._measure(t)
	eq(r.fps(), 50, "0,9 с снимка не считаются: 50 к/с, а не 10")
	eq(roundi(r.worst_ms), 20, "худший кадр без снимка")
	r.free()


## Issue #435: строка описания через 0,3 с после снимка — первые долгие кадры (видеокарта догоняет после чтения
## кадра) не роняют средние: пока своих кадров нет — «—»; дальше — только ровные кадры. Худший кадр их видит.
func test_fps_settles_after_shot() -> void:
	var r := QaRunner.new()
	var t := 1000000
	r._measure(t)
	for i in 30:
		t += 20000
		r._measure(t)
	eq(r.fps_text(), "50", "до снимка — 50 к/с")
	r.after_shot()
	t += 900000                   # сам снимок
	r._measure(t)
	for i in 2:                   # долгие кадры сразу после снимка
		t += 170000
		r._measure(t)
	eq(r.fps(), -1, "своих кадров ещё нет")
	eq(r.fps_text(), "—", "в строке описания — «—», а не 6 к/с")
	eq(roundi(r.worst_ms), 170, "худший кадр после снимка виден")
	t += 170000
	r._measure(t)
	for i in 10:
		t += 20000
		r._measure(t)
	eq(r.fps(), 50, "дальше — ровные кадры: 50 к/с")
	r.free()


func test_worst_frame_names_step() -> void:   # issue #217: в логе видно, на каком шаге худший кадр
	var r := QaRunner.new()
	r.script_q = QaScript.parse('[{"do": "wait", "s": 1}, {"do": "press", "what": "action"}, {"do": "wait", "s": 1}]')
	r.script_q.index = 1
	eq(QaRunner.step_label(r.script_q), "шаг 2 press", "подпись шага с единицы")
	var t := 1000000
	r._measure(t)
	r._step_label = "шаг 1 wait"
	t += 20000
	r._measure(t)
	r._step_label = "шаг 2 press"
	t += 700000                   # рывок на кадре шага press
	r._measure(t)
	r._step_label = "шаг 3 wait"
	t += 20000
	r._measure(t)
	eq(roundi(r.worst_ms), 700, "худший кадр 700 мс")
	ok(r.worst_at.begins_with("шаг 2 press, код "), "худший кадр отнесён к шагу press: " + r.worst_at)
	ok(r.worst_at.contains(" мс, отрисовка "), "и код, и отрисовка: " + r.worst_at)
	ok(r.worst_text().contains("худший кадр 700 мс (шаг 2 press"), "и попал в строку состояния")
	r.free()


func test_worst_note_code_and_gpu() -> void:   # issue #217, #281: отрисовка мала — код это или видеокарта
	eq(QaRunner.worst_note("шаг 54 press", 7.2, 5.4, 0.0), "шаг 54 press, код 5 мс, отрисовка 7 мс", "без замера видеокарты")
	eq(QaRunner.worst_note("шаг 54 press", 7.2, 5.4, 731.0), "шаг 54 press, код 5 мс, отрисовка 7 мс, видеокарта 731 мс",
		"видеокарта — когда драйвер замеряет")
	eq(QaRunner.worst_note("", 3.0), "отрисовка 3 мс", "без шага и кода — как раньше")


func test_fps_few_frames_without_shot() -> void:   # issue #281: 0,3 с после снимка — 2 кадра, а не среднее движка со снимком
	var r := QaRunner.new()
	var t := 1000000
	r._skip_frame = true
	r._measure(t)
	t += 170000
	r._measure(t)
	t += 170000
	r._measure(t)
	eq(r.frames, 2, "два своих кадра")
	eq(r.fps(), 6, "6 к/с по своим кадрам по 170 мс")
	r.free()
