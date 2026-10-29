extends TestCase
## Сценарий тестера: разбор, порядок команд, прогон в сцене без тапов по координатам.


func _run_all(q: QaScript, secs: float, dt: float = 0.05) -> Array:
	var all: Array = []
	for i in int(secs / dt):
		all.append_array(q.advance(dt))
	return all


func test_parse_skips_bad_steps() -> void:
	var q := QaScript.parse('[{"do":"wait","s":1},{"do":"swim"},{"do":"press","what":"nose"},{"do":"press","what":"pad"},{"do":"shot","name":"a"}]')
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


func test_level_switch_has_own_shot() -> void:   # 29-golos: худший кадр — смена уровня графики «Красиво» → «Обычно»
	var q := QaScript.parse(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	var seen := 0
	for i in q.steps.size():
		var st: Dictionary = q.steps[i]
		if st.get("do") != "press" or not str(st.get("what")) in ["g0", "g1", "g2"]:
			continue
		seen += 1
		var own := true   # до снимка — только ожидание, запись и «Назад»; конец сценария — тоже можно
		for j in range(i + 1, q.steps.size()):
			var nx: Dictionary = q.steps[j]
			if nx.get("do") == "shot":
				break
			if not nx.get("do") in ["wait", "log", "back"]:
				own = false
				break
		ok(own, "после смены уровня %s — свой снимок: её кадр не уходит в строку следующего экрана" % st.get("what"))
	ok(seen >= 3, "сценарий проходит три уровня графики")


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
	var comms_seen := false   # 31: плашка связи ART-040 со своим кодом
	var exposed_seen := false   # 31d: подделка разоблачена
	var no_answer := false   # 29f: экран адреса ART-039 дождался «Нет ответа»
	var windows_hidden: Array[String] = []   # конденсат 33/33a: окна не заслонены товарищами
	var crowded: Array[String] = []   # issue #602: на снимке товарищ вплотную к камере — кадр закрыт его головой
	var mate_weld_seen := false   # 26b: шов в кадре, его варит товарищ
	var field_known := false   # 32e2: импульс с площадки 08 поймал ритм поля (#833)
	var bones_seen := false   # 32g: сканер у Костей 04 — строка о минерализации (#840)
	var shell_known := false   # 32h: сонар и сканер у Раковины 03 — знание «осмотр 03» (#835)
	ok(not main.lore.knows(LayerLore.FIELD08), "до прогона поле 08 не замечено")
	for i in 5100:  # 170 с игры (сценарий идёт ~153 с)
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
		# Под тревогой карточка скрыта нарочно: у точки старта хищник может ударить на 12 % и пробить борт в первые
		# секунды нового забега (issue #506) — время ударов в прогоне зависит от настоящих кадров.
		var card_vis: bool = (main.role_card_panel.visible and main.role_card.a > 0.5) or main.alarms_on().has(true)
		var weld_at := -1.0
		if main.breach.active:
			var seam := main.ship.to_global(main.breach.active.p)
			if cam.is_position_in_frustum(seam):
				weld_at = cam.unproject_position(seam).y / cam.get_viewport().get_visible_rect().size.y
		var hot_vis := main.at_power and main.power_panel.visible and main.reactor.hot
		var cool_vis := not main.reactor.hot and main.reactor.scram == 0.0
		var comms_vis := main.comms_panel.visible and main.comms.a > 0.5
		var comms_line := main.comms.code_line()
		var comms_state := main.comms.state
		var near := INF
		for m: Crew.Member in main.crew:
			if m != main.me:
				near = minf(near, Vector2(m.walker.x - main.walker.x, m.walker.z - main.walker.z).length())
		var screens := 0   # стоящие товарищи в кадре перед камерой: на 33/33a они заслоняли окна (отчёт 2026-10-26-1233)
		for m: Crew.Member in main.crew:
			if m != main.me and not m.seated and cam.is_position_in_frustum(main.ship.to_global(m.joints()["head"])):
				screens += 1
		var mate_welds := false
		for m: Crew.Member in main.crew:
			mate_welds = mate_welds or (m != main.me and m.welding() and weld_at > 0.0)
		main.step(1.0 / 30.0)
		no_answer = no_answer or (main.address.open and main.address.hint() == AddressScreen.NO_ANSWER)
		sat = sat or main.pilot.seated
		field_known = field_known or main.lore.knows(LayerLore.FIELD08)
		bones_seen = bones_seen or main.eco.bones.inspected
		shell_known = shell_known or main.lore.knows(LayerLore.SHELL03)
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
			if qa.log_lines[k].begins_with("скриншот 33") and screens > 0:
				windows_hidden.append("%s %d" % [qa.log_lines[k].split(" ")[1], screens])
			if qa.log_lines[k].begins_with("скриншот ") and near < Crew.GAP * 0.75:
				crowded.append("%s (%.2f м)" % [qa.log_lines[k].split(" ")[1], near])
			if qa.log_lines[k].begins_with("скриншот 26b-mate-weld"):
				mate_weld_seen = mate_welds
			if qa.log_lines[k].begins_with("скриншот 31-svyaz"):
				comms_seen = comms_vis and comms_line == "Код: %s" % main.comms.code
			if qa.log_lines[k].begins_with("скриншот 31d-ne-nash"):
				exposed_seen = comms_vis and comms_state == Comms.Ask.EXPOSED
		shots = qa.log_lines.size()
		if qa.script_q.finished:
			break
	ok(qa.script_q.finished, "сценарий дошёл до конца")
	ok(power_hot, "на 08a-power-hot пульт открыт и реактор перегрет (ART-050)")
	ok(cooled, "шаг hot 0 остудил реактор: 09-sonar без перегрева и сброса")
	ok(weld_y > 0.3 and weld_y < 0.7, "на 16-breach-weld шов в середине кадра: %.2f высоты (#524)" % weld_y)
	eq(crowded, [] as Array[String], "на снимках товарищи не вплотную к камере (#602)")
	eq(windows_hidden, [] as Array[String], "на 33/33a окна не заслоняют товарищи (отчёт 2026-10-26-1233)")
	ok(mate_weld_seen, "на 26b-mate-weld товарищ варит шов в кадре (#602)")
	ok(sat, "по сценарию садились за штурвал")
	ok(field_known, "32e2: импульс у 08 — ритм поля, знание «поле 08»")
	ok(bones_seen, "32g: сканер у Костей 04 — строка о минерализации")
	ok(shell_known, "32h: сонар и сканер у Раковины 03 — знание «осмотр 03»")
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
	ok(comms_seen, "на снимке 31-svyaz — плашка связи с кодом забега (ART-040)")
	ok(exposed_seen, "на снимке 31d-ne-nash — «Это был не наш» (ART-040)")
	ok(main.comms.closing or not main.comms.active(), "«Понятно» закрыла плашку связи")
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


## Отчёт qa/2026-10-26-1620-novaya-c3f0473: шаг «wreck» ставит корпус 0 сам — в хронометраже это не «удар».
func test_wreck_step_not_a_hit() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.start_qa('[{"do": "wait", "s": 0.2}, {"do": "wreck"}, {"do": "wait", "s": 0.3}]')
	for i in 20:
		main.step(1.0 / 30.0)
	var text := ""
	for e: Array in main.timeline.events:
		text += "%s\n" % e[1]
	ok(text.contains("корпус задан: 0%"), "крушение из сценария помечено: %s" % text)
	ok(not text.contains("удар: корпус 0%"), "и не считается ударом: %s" % text)
	main.queue_free()
	await frames(1)


## Кампания (#824, часть 4б): шаг «save» кладёт место в память сохранения (файл прогона не пишется), «wreck» после
## него — загрузка этого места без облёта, а не подъём к началу спуска.
func test_save_then_wreck_loads_place() -> void:
	var q := QaScript.parse('[{"do": "save"}, {"do": "wreck"}, {"do": "save", "on": false}]')
	eq(q.errors.size(), 0, "шаг save известен")
	eq(q.advance(0.1).slice(0, 3), [["save", true], ["wreck"], ["save", false]], "команды сцене")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	eq(main.save.path, "", "прогон не пишет файл сохранения")
	main.start_qa('[{"do": "ship", "x": 40, "y": -30, "z": -30, "yaw": 0}, {"do": "save"}, {"do": "wait", "s": 0.2},'
		+ ' {"do": "ship", "x": 0, "y": -20, "z": 60}, {"do": "wreck"}, {"do": "wait", "s": 0.2}]')
	for i in 20:
		main.step(1.0 / 30.0)
	ok(main.has_saved_ship(), "место в памяти сохранения")
	eq(main.wreck_view.sub.text, Wreck.SUB_LOAD, "шторка обещает последнее сохранение")
	for i in int(Wreck.END * 30.0) + 10:
		main.step(1.0 / 30.0)
	ok(not main.wreck.active(), "шторка прошла")
	near(main.helm.pos.x, 40.0, 0.5, "корабль у сохранённого места (x)")
	near(main.helm.pos.z, -30.0, 0.5, "корабль у сохранённого места (z)")
	ok(not main.flyby.active(), "без облёта")
	main.start_qa('[{"do": "save", "on": false}, {"do": "wait", "s": 0.1}]')
	main.step(1.0 / 30.0)
	ok(not main.has_saved_ship(), "место забыто — меню без «Продолжить»")
	main.queue_free()
	await frames(1)


## Есть сохранённое место — в меню сверху «Продолжить», кнопки ниже: «crew»/«journal»/«dive» сценария жмут по
## текущему меню, а не по меню без «Продолжить» (иначе «Экипаж» попадал мимо, 29f не дожидался «Нет ответа»).
func test_menu_press_with_continue() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var qa := main.start_qa('[{"do": "wait", "s": 0.1}]')
	main.main_menu.open = true
	main.main_menu.can_continue = true
	var size := main.get_viewport().get_visible_rect().size
	for id in ["dive", "crew", "journal"]:
		eq(main.main_menu.hit(qa._point(id, Vector2.ZERO), size), id, "касание «%s» — по своей кнопке" % id)
	main.queue_free()
	await frames(1)


func test_silt_step() -> void:
	var q := QaScript.parse('[{"do": "silt"}, {"do": "silt", "on": false}]')
	eq(q.errors.size(), 0, "шаг silt известен")
	var out := q.advance(0.1)
	eq(out[0], ["silt", true], "ил вокруг корабля")
	eq(out[1], ["silt", false], "убрать ил")


## Отчёты тестера 0010…0215 26.10: на 32-kaustiki «ПРОБОИНА · МОСТИК» от случайного удара на шагах связи 31.
func test_breach_off_step() -> void:
	var q := QaScript.parse('[{"do": "breach", "n": 2}, {"do": "breach", "on": false}]')
	eq(q.errors.size(), 0, "шаг breach с on известен")
	var out := q.advance(0.1)
	eq(out[0], ["breach", 2], "пробоина в лаборатории")
	eq(out[1], ["breach", -1], "закрыть пробоину")


func test_close_breach_clears_state() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.open_breach(0)
	for i in 60:
		main.step(1.0 / 30.0)
	ok(main.breach.active != null and main.breach.water > 0.0, "пробоина открыта, вода пошла")
	main.close_breach()
	ok(main.breach.active == null, "пробоины нет")
	eq(main.breach.water, 0.0, "воды нет")
	eq(main.breach.status(), "", "в строке приборов о пробоине ничего")
	ok(not main.breach.on_hit(50, 100.0), "сразу после — удар борт не пробивает")
	main.queue_free()
	await frames(1)


func test_caustics_shot_starts_clean() -> void:
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	var closed := false
	var whole := false
	for st in steps:
		if st["do"] == "breach":
			closed = not bool(st.get("on", true))
		if st["do"] == "hull":
			whole = float(st["pct"]) >= 100.0
		if st["do"] == "shot" and st["name"] == "32-kaustiki":
			break
	ok(closed, "перед 32-kaustiki пробоина закрыта")
	ok(whole, "и корпус целый")


func test_sonar_card_shot_calm_and_clear() -> void:   # issue #882: укус хищника прятал карточку, камера — в товарище
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	var mates: Array[Vector2] = []
	var closed := false
	var look := {}
	var shot := false
	for st in steps:
		if st["do"] == "mate" and st.has("x"):
			mates.append(Vector2(float(st["x"]), float(st["z"])))
		if st["do"] == "press" and st.get("what", "") == "dive":
			closed = false   # новый забег: тревоги того забега не в счёт
			look = {}
		if st["do"] == "breach":
			closed = not bool(st.get("on", true))
		if st["do"] == "goto":
			look = st
		if st["do"] == "shot" and st["name"] == "30-kartochka-sonar":
			shot = true
			break
	ok(shot and not look.is_empty(), "снимок карточки после «Погрузиться» и подхода к посту")
	ok(closed, "пробоина закрыта перед снимком — под тревогой карточка прячется")
	var at := Vector2(float(look["x"]), float(look["z"]))
	ok(Deck.can_stand(at.x, at.y), "на месте можно стоять")
	var post := Deck.nearest(Deck.posts(), at.x, at.y)
	ok(post != null and post.id == "sonar", "ближайший пост — сонар")
	for p in mates:
		ok(p.distance_to(at) > 1.0, "товарищ %s не вплотную к камере (%.2f м)" % [p, p.distance_to(at)])


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
	var cq := QaScript.parse('[{"do": "charge", "units": 40}, {"do": "charge", "units": 500}]')
	eq(cq.errors.size(), 0, "шаг charge известен")
	var c := cq.advance(0.1)
	eq(c[0], ["charge", 40.0], "заряд 40 ед.")
	eq(c[1], ["charge", Vitals.MAX], "выше полного не бывает")


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


## Issue #609: «отрисовка 1466 мс» при худшем кадре 178 мс — замер движка запаздывал и приходился на чужой кадр.
## Теперь отрисовка — от frame_pre_draw до frame_post_draw того кадра, чьё время меряется; видеокарта больше кадра — не пишем.
func test_worst_frame_own_draw() -> void:
	var r := QaRunner.new()
	var t := 1000000
	r._measure(t)
	r.draw_ms = 4.0
	t += 20000
	r._measure(t)
	r.after_shot()
	r.draw_ms = 1466.0            # кадр снимка: сборка шейдеров уровня «Экономно» — его не считаем
	t += 1500000
	r._measure(t)
	r._step_label = "шаг 353 press"
	r.draw_ms = 3.0               # рывок кадра, отрисовка в нём мала
	t += 178000
	r._measure(t)
	r.draw_ms = 5.0
	t += 20000
	r._measure(t)
	eq(roundi(r.worst_ms), 178, "худший кадр 178 мс")
	ok(r.worst_at.contains("отрисовка 3 мс"), "отрисовка своего кадра, не кадра снимка: " + r.worst_at)
	ok(not r.worst_at.contains("1466"), "чужие 1466 мс не приписаны: " + r.worst_at)
	r._on_pre_draw()
	r._on_post_draw()
	ok(r.draw_ms >= 0.0 and r.draw_ms < 50.0, "замер отрисовки по сигналам: %.2f мс" % r.draw_ms)
	eq(QaRunner.worst_note("шаг 1 wait", 3.0, 2.0, 1466.0, 178.0), "шаг 1 wait, код 2 мс, отрисовка 3 мс",
		"видеокарта больше самого кадра — от другого кадра, не пишем")
	eq(QaRunner.worst_note("шаг 1 wait", 3.0, 2.0, 150.0, 178.0), "шаг 1 wait, код 2 мс, отрисовка 3 мс, видеокарта 150 мс",
		"видеокарта в пределах кадра — пишем")
	r.free()


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


## issue #445: каустики под трещинами на снимках прогона не разглядеть — шаги ship и fly дают вид вблизи дна.
func test_ship_and_fly_steps() -> void:
	var q := QaScript.parse('[{"do": "ship", "x": 38, "y": -20, "z": -25}, {"do": "fly", "y": -8, "pitch": -55}, ' \
		+ '{"do": "shot", "name": "k"}, {"do": "fly", "on": false}]')
	eq(q.errors.size(), 0, "шаги ship и fly известны")
	var out := q.advance(0.1)
	eq(out[0], ["ship", 38.0, -20.0, -25.0], "корабль в точку мира")
	eq(out[1], ["fly", true, -8.0, -55.0], "полёт: высота глаза и наклон")
	eq(out.size(), 2, "снимок — в следующем шаге, после кадра с новым местом")
	var out2 := q.advance(0.1)
	eq(out2[0], ["shot", "k"], "затем снимок")
	eq(out2[1], ["fly", false, Deck.Walker.EYE, 0.0], "назад на пол")


## Снимок 32-kaustiki смотрит на дно под шахтами света, глаз над дном, а не в грунте.
func test_caustics_shot_under_cracks() -> void:
	var raw := FileAccess.get_file_as_string("res://tools/qa/scenario.json")
	var steps: Array = JSON.parse_string(raw)
	var ship := {}
	var fly := {}
	for st in steps:   # корабль — последний перед полётом под днище (дальше в сценарии — другие стоянки)
		if st["do"] == "ship":
			ship = st
		if st["do"] == "fly" and st.get("on", true):
			fly = st
			break
	ok(not ship.is_empty() and not fly.is_empty(), "в сценарии есть вид на дно под трещинами")
	var at := Vector3(float(ship["x"]), 0.0, float(ship["z"]))
	ok(LightShafts.near(LightShafts.layout(), at, 25.0).size() > 0, "рядом шахты света — над дном трещины")
	var eye_y := float(ship["y"]) + float(fly["y"])
	var floor_y := Seabed.height(at.x, at.z)
	ok(eye_y > floor_y + 2.0, "глаз над дном (%.1f > %.1f)" % [eye_y, floor_y])
	ok(eye_y < float(ship["y"]) - 4.0, "глаз под днищем — корпус не закрывает дно")


## Шаг ship с курсом: курс — пятым числом (как у goto), без него — прежний (#729: вид на губку органа не зависит
## от того, куда повернул забег).
func test_ship_step_yaw() -> void:
	var q := QaScript.parse('[{"do": "ship", "x": 52, "y": -25, "z": 40, "yaw": 0}, {"do": "ship", "x": 1, "z": 2}]')
	eq(q.errors.size(), 0, "без ошибок")
	var out := q.advance(0.1)
	eq(out[0], ["ship", 52.0, -25.0, 40.0, 0.0], "курс задан")
	eq(out[1], ["ship", 1.0, -20.0, 2.0], "курс не задан — четыре числа")


## Снимки 32b/32c (выдох трубного органа, PR #729): корабль «в гуле» губки, курс задан, губка впереди и ниже
## глаза, глаз над дном и под днищем.
func test_organ_shot_at_organ() -> void:
	var raw := FileAccess.get_file_as_string("res://tools/qa/scenario.json")
	var steps: Array = JSON.parse_string(raw)
	var ship := {}
	var fly := {}
	var look := {}
	var shot := false
	for st in steps:
		if st["do"] == "ship":
			ship = st
			look = {}
		if st["do"] == "goto":
			look = st
		if st["do"] == "fly" and st.get("on", true):
			fly = st
		if st["do"] == "shot" and st["name"] == "32b-organ":
			shot = true
			break
	ok(shot and not ship.is_empty() and not fly.is_empty(), "в сценарии есть снимок органа после стоянки и полёта")
	ok(ship.has("yaw"), "курс корабля задан")
	ok(not look.is_empty() and is_zero_approx(float(look["yaw"])), "после стоянки взгляд по носу (goto yaw 0) — "
		+ "не остаётся от прошлого снимка")
	var at := Vector2(float(ship["x"]), float(ship["z"]))
	var spot := EcoOrgan.SPOTS[0]
	for s in EcoOrgan.SPOTS:
		if s.distance_to(at) < spot.distance_to(at):
			spot = s
	ok(spot.distance_to(at) < EcoOrgan.MASK_R, "корабль ближе %.0f м к губке — трубы дышат каждый такт" % EcoOrgan.MASK_R)
	var nose := Vector2(0, -1).rotated(-deg_to_rad(float(ship["yaw"])))
	ok(nose.dot((spot - at).normalized()) > 0.9, "губка впереди по носу")
	var eye_y := float(ship["y"]) + float(fly["y"])
	var floor_y := Seabed.height(at.x, at.y)
	ok(eye_y > floor_y + 2.0, "глаз над дном (%.1f > %.1f)" % [eye_y, floor_y])
	ok(eye_y > Seabed.height(spot.x, spot.y) + EcoOrgan.TOP_UP, "глаз выше устьев труб")
	ok(eye_y < float(ship["y"]) - 3.0, "глаз под днищем")


func test_park_at_and_toggle_noclip() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.helm.speed = 3.0
	main.park_at(Vector3(38, -20, -25))
	eq(main.helm.pos, Vector3(38, -20, -25), "корабль на месте")
	eq(main.helm.speed, 0.0, "и стоит")
	main.toggle_noclip()
	ok(main.walker.noclip, "полёт включён")
	main.toggle_noclip()
	ok(not main.walker.noclip, "полёт выключен")
	eq(main.walker.y, Deck.Walker.EYE, "глаз снова на высоте шага")
	main.queue_free()
	await frames(1)


## Отчёт #742: видеокарта 30–40 мс весь первый забег, 1–3 мс после страницы «Графика» — уровень графики и что он
## поставил на деле пишутся в лог при старте и при каждой смене.
func test_graphics_line() -> void:
	eq(QaRunner.graphics_line(Graphics.NORMAL, 2, 1.0, 2, "Adreno 740"),
		"графика «Обычно»: MSAA 2×, масштаб 1,00, тени 2 · видеокарта Adreno 740", "обычно")
	eq(QaRunner.graphics_line(Graphics.ECONOMY, 0, 0.75, 0, ""),
		"графика «Экономно»: MSAA выкл, масштаб 0,75, тени выкл · видеокарта —", "экономно, видеокарта неизвестна")


func test_graphics_logged_on_change() -> void:
	tree.root.msaa_3d = Viewport.MSAA_4X   # MSAA, оставленный прошлым «Красиво», — при старте его ставит уровень
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var qa := main.start_qa('[{"do":"wait","s":5}]')
	main.step(1.0 / 30.0)
	var first := Array(qa.log_lines).filter(func(l): return l.begins_with("графика «"))
	eq(first.size(), 1, "при старте — одна строка графики")
	ok(first[0].begins_with("графика «Обычно»: MSAA 2×, масштаб 1,00, тени 2"), "уровень по умолчанию: " + first[0])
	main.step(1.0 / 30.0)
	eq(Array(qa.log_lines).filter(func(l): return l.begins_with("графика «")).size(), 1, "без смены — не повторяется")
	main._apply_graphics(Graphics.BEAUTY)
	main.step(1.0 / 30.0)
	var all := Array(qa.log_lines).filter(func(l): return l.begins_with("графика «"))
	eq(all.size(), 2, "смена уровня — новая строка")
	ok(all[-1].begins_with("графика «Красиво»: MSAA 4×, масштаб 1,00, тени 4"), "красиво: " + all[-1])
	main._apply_graphics(Graphics.NORMAL)
	main.queue_free()
	await frames(1)
