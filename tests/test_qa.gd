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


## #1758: решение «глубже» у 10 (`34b-les-ekran`) — не в кадрах сразу после снимка `34a` (на эмуляторе они долгие,
## #435, `QaRunner.SETTLE_FRAMES` идут в худший кадр): иначе провал «узлы» кадра решения не отделить от снимка.
func test_descent_decision_not_right_after_shot() -> void:
	var q := QaScript.parse(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	var at := -1
	for i in q.steps.size():
		if q.steps[i].get("do") == "shot" and str(q.steps[i].get("name")) == "34a-spusk-panel":
			at = i
	ok(at >= 0, "снимок 34a-spusk-panel в сценарии")
	var gap := 0.0
	var found := false
	for j in range(at + 1, q.steps.size()):
		var st: Dictionary = q.steps[j]
		if st.get("do") == "hold":
			found = str(st.get("what")) == "pad" and Vector2(st["dir"][0], st["dir"][1]) == Vector2(0, -1)
			break
		if st.get("do") == "wait":
			gap += float(st["s"])
	ok(found, "после 34a — «вниз» на голостоле")
	ok(gap >= 0.2, "между снимком 34a и решением «глубже» — пауза ≥ 0,2 с (было 0)")


## #1765 обобщённо (#1350, 13.11): ни одно нажатие сценария (`press`/`hold`) не идёт в первые
## `QaRunner.SETTLE_FRAMES` после снимка — между снимком (`shot`/`play`) и первым действием за ним шаги длятся
## ≥ 0,2 с. Иначе худший кадр действия (открыть панель, нажать пост) сливается с долгими кадрами после снимка.
## Удержание, прерванное снимком (сварка, лебёдка, ход крестовиной), продолжается в том же кадре — нового нажатия
## нет, это не действие. Сообщение перечисляет все такие пары «снимок → действие».
func test_no_action_right_after_shot() -> void:
	var q := QaScript.parse(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	var bad: Array[String] = []
	var pairs := 0
	for i in q.steps.size():
		if not q.steps[i].get("do") in ["shot", "play"]:
			continue
		var held := ""   # удержание прямо перед снимком (без строк лога)
		for b in range(i - 1, -1, -1):
			if q.steps[b]["do"] != "log":
				held = str(q.steps[b]["what"]) if q.steps[b]["do"] == "hold" else ""
				break
		var gap := 0.0
		for j in range(i + 1, q.steps.size()):
			var st: Dictionary = q.steps[j]
			if st["do"] in ["shot", "play"]:
				break
			if st["do"] in ["press", "hold"]:
				if st["do"] == "hold" and gap == 0.0 and str(st["what"]) == held:
					break   # то же удержание продолжается
				pairs += 1
				if gap < 0.2 - 1e-6:
					bad.append("%s → %s %s (%.2f с)" % [q.steps[i].get("name", q.steps[i].get("n")), st["do"], st["what"], gap])
				break
			gap += QaScript.duration(st)
	ok(pairs > 50, "после снимков есть нажатия (%d)" % pairs)
	ok(bad.is_empty(), "нажатие сразу после снимка: " + ", ".join(bad))


func test_swipe_moves_full_distance() -> void:
	var q := QaScript.parse('[{"do":"swipe","dx":300,"dy":-40,"s":0.5}]')
	var sum := Vector2.ZERO
	for c in _run_all(q, 1.0, 1.0 / 30.0):
		if c[0] == "move":
			sum += c[2]
	ok(sum.distance_to(Vector2(300, -40)) < 0.01, "свайп прошёл всё расстояние: %s" % str(sum))


## Предел шагов сценового прогона при 30 кадрах/с: длина сценария с запасом 10 % и 20 с на снимки (каждый ждёт кадр)
## и прогрев. Раньше стояло число 7500 (250 с) — новые шаги тестера доводили сценарий до 240 с и роняли тест (#1379).
static func scene_frames(q: QaScript) -> int:
	return ceili((q.total_time() * 1.1 + 20.0) * 30.0)


## Кадр 36… (#1401): ряд каменщиков ближе всех к кусту огнецвета 0 — сколько венчиков спрятано, и горит ли куст;
## «присоска» — стеклоуст висит на стекле (корабль стоял в 15 м от его логова, тянул заряд и гасил прожектор к концу
## прогона, а бросок мимо ряда прятал венчики — main 1ca7c20).
static func _ognecvet(main: Main, shot: String) -> String:
	var eco: EcoView = main.eco
	var bush: EcoCoral.Bush = eco.coral.bushes[0]
	var row: EcoKamen.Row = null
	for r in eco.kamen.rows:
		if row == null or r.center.distance_to(bush.top) < row.center.distance_to(bush.top):
			row = r
	var hidden := eco.kamen.hidden_in(row)
	return "%s: %s %s%s" % [shot, "0" if hidden == 0 else "спрятаны", "погас" if bush.glow < EcoCoral.DARK else "свет",
			" присоска" if main.vitals.drain_left > 0.0 else ""]


func test_total_time() -> void:
	var q := QaScript.parse('[{"do": "wait", "s": 2}, {"do": "hold", "what": "pad", "dir": [0, 1], "s": 0.5},'
			+ ' {"do": "shot", "name": "a"}, {"do": "press", "what": "action"}, {"do": "swipe", "dx": 10, "dy": 0}]')
	near(q.total_time(), 2.0 + 0.5 + QaScript.PRESS_TIME + 0.5, 1e-6, "длина — сумма шагов: ожидание, удержание, нажатие, свайп")
	var full := QaScript.parse(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	ok(scene_frames(full) / 30.0 > full.total_time() + 20.0, "предел прогона длиннее сценария с запасом (#1379)")


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
	var reverse := 0.0   # 05c (#1568): задний ход — минус на левом экране пульта ART-061
	var dome: Array[String] = []   # 37/37a (#1350): купольник в кадре — клип ANIM-004 и створка по кадрам
	var dome_t := -1.0   # 37 (#837): время клипа OpenPetal на кадре — верхняя точка подъёма
	var dome_say := ""   # 37a (#837, отчёт 11.11 15:18): строка створки на приборах
	var task_say := ""   # 35-zadacha-07 (#1635, отчёт 11.11 12:19): строка 3 — задача места, не «Вы за штурвалом»
	var zamer: Array[String] = []   # 38/38a (#1498): режим хищника 0 и строка приборов на кадрах «замер» и «потерял»
	var zamer_hull: Array[float] = []   # 38 → 38a: удара нет
	var helm_silt := ""   # 39-shturval-il (#1708): за штурвалом в иле — ил, сидим, рамки у колеса нет
	var corridor: Array[String] = []   # 40/40a (#1722): из коридора при тревоге на мостике люк и указатель в кадре
	var lever := ""   # 40b (#1709): у рычага при стеклоусте — строка «жмите «Разряд»», указателя нет
	var ogon: Array[String] = []   # 36/36a/36b (#1401): спрятано венчиков у куста огнецвета 0 и его свечение по кадрам
	ok(not main.lore.knows(LayerLore.FIELD08), "до прогона поле 08 не замечено")
	for i in scene_frames(qa.script_q):   # предел — от длины сценария (#1379)
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
		var dome_vis := cam.is_position_in_frustum(main.eco.dome.pos + Vector3(0, 0.6, 0)) and main.eco.dome_view.visible
		var dome_line := "%s %s %.1f" % ["в кадре" if dome_vis else "не в кадре", main.eco.dome_view.playing,
				main.eco.dome.petal]
		var dome_at := main.eco.dome.t
		var say_now := main.message.text
		var pred_mode: String = EcoPred.Mode.keys()[main.eco.preds.all[0].mode]
		var silt_line := "ил %s, сидит %s, рамка %s" % [main.silt.inside != null, main.pilot.seated,
				main.alarm_board.hint.visible]
		var way := main.alarm_pointer
		var way_line := "нет указателя"
		if way != null:
			var hatch := Vector3(0.0, ShipLayout.DOOR_H * 0.5, AlarmWay.wall_span(way.door).y)
			way_line = "%s, отсек %s, люк %s, указатель %s" % [way.label(), AlarmWay.ROOMS[ShipLayout.room_at(main.walker.z)],
					"в кадре" if cam.is_position_in_frustum(main.ship.to_global(hatch)) else "не в кадре",
					"в кадре" if cam.is_position_in_frustum(main.ship.to_global(way.anchor)) else "не в кадре"]
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
			if qa.log_lines[k].begins_with("скриншот 05c-zadniy-hod"):
				reverse = (main.bridge.screens_mat.get_shader_parameter("values") as Vector3).z
			if qa.log_lines[k].begins_with("скриншот 10-zap"):
				zap_seen = zap_vis
			if qa.log_lines[k].begins_with("скриншот 10a-zap-okno"):
				arc_seen = arc_vis
			if qa.log_lines[k].begins_with("скриншот 37-kupolnik") or qa.log_lines[k].begins_with("скриншот 37a-kupolnik"):
				dome.append(dome_line)
				if qa.log_lines[k].begins_with("скриншот 37-kupolnik"):
					dome_t = dome_at
				else:
					dome_say = say_now
			if qa.log_lines[k].begins_with("скриншот 38-zamer") or qa.log_lines[k].begins_with("скриншот 38a-zamer"):
				zamer.append("%s: %s" % [qa.log_lines[k].split(" ")[1].trim_suffix(":"), pred_mode])
				zamer.append(say_now)
				zamer_hull.append(main.vitals.hull)
			if qa.log_lines[k].begins_with("скриншот 39-shturval-il"):
				helm_silt = silt_line
			if qa.log_lines[k].begins_with("скриншот 40-koridor") or qa.log_lines[k].begins_with("скриншот 40a-koridor"):
				corridor.append(way_line)
			if qa.log_lines[k].begins_with("скриншот 40b-rychag"):
				lever = "у рычага %s, %s, %s" % [main._at_lever(), AlarmWay.drain_line(main.vitals,
						ShipLayout.room_at(main.walker.z), main._at_lever()), way_line]
			if qa.log_lines[k].begins_with("скриншот 35-zadacha-07"):
				task_say = say_now
			if qa.log_lines[k].begins_with("скриншот 36"):
				ogon.append(_ognecvet(main, qa.log_lines[k].split(" ")[1].trim_suffix(":")))
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
	ok(reverse < -1.0, "на 05c-zadniy-hod задний ход — на экране пульта ход с минусом: %.1f (#1568)" % reverse)
	ok(field_known, "32e2: импульс у 08 — ритм поля, знание «поле 08»")
	ok(bones_seen, "32g: сканер у Костей 04 — строка о минерализации")
	ok(shell_known, "32h: сонар и сканер у Раковины 03 — знание «осмотр 03»")
	eq(dome.size(), 2, "37/37a: оба кадра купольника сняты")
	if dome.size() == 2:
		eq(dome[0], "в кадре OpenPetal 1.0", "37: купольник в кадре, клип OpenPetal, створка поднята")
		ok(absf(dome_t - EcoDome.LIFT.y) < 0.15,
				"37 (#837): кадр в верхней точке подъёма захвата (LIFT.y %.1f с): %.2f с" % [EcoDome.LIFT.y, dome_t])
		eq(dome[1], "в кадре Swim 1.0", "37a: створка поднята, купольник в кадре уходит клипом Swim")
	eq(task_say, PlaceTask.line("gate"),
			"35-zadacha-07 (#1635): на приборах строка задачи 07, не «%s»" % Main.SAT_MSG)
	eq(dome_say, EcoDome.PETAL_TEXT, "37a (#837): на приборах строка створки — знание забыто шагом dome")
	eq(ogon, ["36-ognecvet-do: 0 свет", "36a-ognecvet-prohod: спрятаны погас", "36b-ognecvet-posle: 0 свет"],
			"#1401: до прохода ряд раскрыт и куст горит, на проходе — спрятан и погас, после — снова раскрыт")
	eq(zamer.size(), 4, "38/38a (#1498): оба кадра «замера» сняты")
	if zamer.size() == 4:
		eq(zamer[0], "38-zamer: ALERT", "38 (#1498): хищник 0 в фазе «замер»")
		ok(zamer[1].contains("замер и смотрит на корабль — его манит свет"), "38: на приборах строка замера: «%s»" % zamer[1])
		eq(zamer[2], "38a-zamer-poteryal: RETREAT", "38a (#1498): свет погас — хищник отходит")
		ok(zamer[3].contains("потерял корабль и отворачивает"), "38a: на приборах строка отхода: «%s»" % zamer[3])
		ok(zamer_hull[1] >= zamer_hull[0], "38 → 38a: удара нет: корпус %.2f → %.2f" % [zamer_hull[0], zamer_hull[1]])
	var jerks: Array[String] = []   # шаг jerk (#1753): рывки серпохвоста числом — за 38 → 38a и на отходе со скелетом «Экономно»
	for l in qa.log_lines:
		if l.begins_with("рывки: "):
			jerks.append(l)
	eq(jerks.size(), 2, "#1753: две строки рывков серпохвоста в логе")
	if jerks.size() == 2:
		ok(jerks[0].contains("скелет полный") and jerks[0].contains("хвост в норме"), "38 → 38a: %s" % jerks[0])
		ok(jerks[1].contains("скелет «Экономно»") and jerks[1].contains("хвост в норме"), "отход: %s" % jerks[1])
	eq(helm_silt, "ил true, сидит true, рамка false",
			"39-shturval-il (#1708): корабль в иле, свой игрок за штурвалом, рамка-подсказка у колеса скрыта")
	eq(corridor, ["Утечка энергии · мостик, отсек коридор, люк в кадре, указатель в кадре",
			"Пробоина · мостик, отсек коридор, люк в кадре, указатель в кадре"],
			"40/40a (#1722; эффектом, без имени вида — #1709): из коридора лицом к носу при тревоге на мостике люк и указатель над ним в кадре")
	eq(lever, "у рычага true, УТЕЧКА ЭНЕРГИИ · жмите «Разряд», нет указателя",
			"40b (#1709): игрок у рычага при стеклоусте — строка ведёт к кнопке, указателя над люком нет")
	ok(not main.pilot.seated, "и встали")
	ok(ahead > 20.0, "корабль прошёл вперёд: %.1f м" % ahead)
	ok(FileAccess.file_exists(QaRunner.OUT + "/done.txt"), "done.txt записан")
	var log := FileAccess.get_file_as_string(QaRunner.OUT + "/log.txt")
	ok(log.contains("замер: хищник 0 nos, 26 м от корабля, замер 4.0 с, отход 20 с"), "38 (#1498): в логе у шага zamer — числа игры")
	ok(log.contains("купольник: OpenPetal 3.5 с · створка 07 "), "37 (#837): в логе у шага dome — было ли знание")
	ok(log.get_slice("\n", 0).contains("версия " + Main.version_text()), "#1350: первая строка лога — версия как на плашке")
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


func test_mate_same_role_replaces() -> void:   # #1162: второй «биолог» сценария встаёт вместо первого
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.start_qa('[{"do": "mate", "x": 0.9, "z": -2.3, "yaw": 90, "role": 3, "look": 0},'
		+ ' {"do": "mate", "x": 0.2, "z": -2.6, "yaw": 60, "role": 2, "look": 1},'
		+ ' {"do": "mate", "x": 1.85, "z": -0.75, "yaw": 90, "role": 3, "look": 0}, {"do": "wait", "s": 0.3}]')
	for i in 20:
		main.step(1.0 / 30.0)
	eq(main.crew.size(), 3, "свой игрок, инженер и один биолог")
	var bios := main.crew.filter(func(m: Crew.Member) -> bool: return m.role == Crew.Role.BIOLOGIST)
	eq(bios.size(), 1, "биолог один")
	eq((main.crew[-1] as Crew.Member).role, Crew.Role.BIOLOGIST, "новый — последним, его ведут act/gone")
	near((main.crew[-1] as Crew.Member).walker.z, -0.75, 0.3, "стоит на новом месте")
	main.queue_free()
	await frames(1)


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


## Предложение тестера (#1350, 08.11): брифинг прибытия #827 — шагом сценария, а не руками через adb.
func test_brief_step_pages_to_end() -> void:
	var q := QaScript.parse('[{"do": "brief"}, {"do": "press", "what": "brief"}, {"do": "brief", "on": false}]')
	eq(q.errors.size(), 0, "шаг brief и кнопка brief известны")
	eq(q.advance(0.01)[0], ["brief", true], "команда сцене")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.lore.learn(LayerLore.BRIEF)   # прочитан в прошлом забеге — шаг всё равно показывает с начала
	var steps := '{"do": "brief"}, {"do": "wait", "s": 0.8}'
	for i in ArrivalBrief.count():
		steps += ', {"do": "press", "what": "brief"}, {"do": "wait", "s": 0.8}'
	var qa := main.start_qa("[" + steps + "]")
	main.step(1.0 / 30.0)
	ok(main.arrival.active(), "брифинг идёт")
	ok(not main.lore.knows(LayerLore.BRIEF), "знание «прочитан» забыто")
	eq(main.arrival.screen, 0, "с первого экрана")
	var size := main.get_viewport().get_visible_rect().size
	ok(ArrivalBrief.box(size).has_point(qa._point("brief", Vector2.ZERO)), "касание — в плашке")
	for i in int((0.8 + ArrivalBrief.count() * (QaScript.PRESS_TIME + 0.8) + 0.5) * 10.0):   # шаг 0,1 с — втрое меньше кадров (#1350)
		main.step(0.1)
	ok(not main.arrival.active(), "пролистан до конца")
	ok(main.lore.knows(LayerLore.BRIEF), "прочитан — как от касаний игрока")
	main.queue_free()
	await frames(1)


func test_row3_line() -> void:   # #1429: строка 3 приборов в лог у шагов брифинга
	eq(QaRunner.row3_line([], "", ""), "строка 3: пусто", "пусто")
	eq(QaRunner.row3_line(["Из песка что-то схватило"], "Стайка рыбок", ""),
		"строка 3: «Из песка что-то схватило» · в очереди: «Стайка рыбок»", "видна и ждёт очереди")
	eq(QaRunner.row3_line([], "", "Стайка рыбок"), "строка 3: пусто · ждёт конца брифинга: «Стайка рыбок»",
		"отложена до конца брифинга")


func test_row2_line() -> void:   # фокус 2а: строка 2 приборов в лог у снимка
	eq(QaRunner.row2_line([]), "строка 2: пусто", "пусто")
	eq(QaRunner.row2_line(["до дна 12 м", "курс 90°"]), "строка 2: «до дна 12 м · курс 90°»", "части через точку")


## Фокус 2а (тестер, #1350, 13.11 09:23): строка снимка несёт тексты строк 2–3 приборов — знак, которого в кадре
## не разглядеть, проверяется по логу. Заметка `log` их не несёт (как раньше), снимок под скрытыми приборами — с пометкой.
func test_shot_logs_rows() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.say("Знак у логова")
	var qa := main.start_qa('[{"do": "wait", "s": 0.2}, {"do": "shot", "name": "a"}, {"do": "log", "note": "zametka"},'
		+ ' {"do": "hud", "on": false}, {"do": "wait", "s": 0.2}, {"do": "shot", "name": "b"}, {"do": "wait", "s": 5}]')
	for i in 30:
		main.step(1.0 / 30.0)
	var a := Array(qa.log_lines).filter(func(l): return l.begins_with("скриншот a"))
	eq(a.size(), 1, "строка снимка a")
	if a.size() == 1:
		ok("строка 2: «%s»" % " · ".join(PackedStringArray(main.status_rows()[1])) in a[0], "строка 2 как на приборах: " + a[0])
		ok("строка 3: «Знак у логова»" in a[0], "строка 3 — сообщение: " + a[0])
		ok(not "приборы скрыты" in a[0], "приборы на экране — без пометки")
	ok("строка 3" in qa.rows_now() and qa.state(true).ends_with(qa.rows_now()), "со снимком — строки в конце состояния")
	ok(not "строка 2" in qa.state(), "без снимка состояние прежнее")
	var note := Array(qa.log_lines).filter(func(l): return l.begins_with("zametka |"))
	ok(note.size() == 1 and not "строка 2" in note[0], "заметка — без строк приборов")
	var b := Array(qa.log_lines).filter(func(l): return l.begins_with("скриншот b"))
	ok(b.size() == 1 and b[0].ends_with("приборы скрыты"), "снимок без приборов помечен: %s" % [b])
	main.queue_free()
	await frames(1)


func test_petal_note() -> void:   # #1757: створка гнезда 07 в строке снимка числом
	eq(QaRunner.petal_note(0, 0.0), " · створка гнезда 1: закрыта", "закрыта")
	eq(QaRunner.petal_note(0, 1.0), " · створка гнезда 1: открыта (90°)", "открыта")
	eq(QaRunner.petal_note(2, 0.5), " · створка гнезда 3: поднята на 45° из 90°", "в пути — угол")
	eq(QaRunner.petal_note(0, 0.999), " · створка гнезда 1: открыта (90°)", "почти — открыта")
	eq(QaRunner.petal_note(0, 0.004), " · створка гнезда 1: закрыта", "меньше полградуса — закрыта")


## #1757 (тестер 13.11 22:22): поднятую створку на `37`/`37a` с 26 м не различить — строка снимка у арки 07 несёт её
## угол с узла модели; вдали от арки строки нет, строки приборов остаются в конце.
func test_shot_logs_petal_at_gate() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var qa := main.start_qa('[{"do": "wait", "s": 60}]')
	main.step(1.0 / 30.0)
	ok(not "створка" in qa.state(true), "вдали от арки — без створки: " + qa.state(true))
	main.helm.pos = Vector3(EcoGate.CENTER.x + 12.0, -58.0, EcoGate.CENTER.y + 30.0)
	main.gate_view.set_petal(EcoDome.NEST, 0.0)
	ok("створка гнезда 1: закрыта" in qa.state(true), "у арки — закрыта: " + qa.state(true))
	ok(not "створка" in qa.state(), "заметка без снимка — без створки")
	main.gate_view.set_petal(EcoDome.NEST, 0.4)
	ok("створка гнезда 1: поднята на 36° из 90°" in qa.state(true), "подъём — углом узла модели: " + qa.state(true))
	main.lore.learn(LayerLore.PETAL07)
	main.gate_petal()
	ok("створка гнезда 1: открыта (90°)" in qa.state(true), "открыта в кампании: " + qa.state(true))
	ok(qa.state(true).ends_with(qa.rows_now()), "строки приборов — по-прежнему в конце")
	main.queue_free()
	await frames(1)


func test_brief_logs_world_line() -> void:   # #1429: в логе видно, пришла строка мира до плашки или под ней
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main._world_say("Из песка что-то схватило круглую рыбку")
	var qa := main.start_qa('[{"do": "brief"}, {"do": "wait", "s": 0.5}, {"do": "log", "note": "02r"}, {"do": "wait", "s": 5}]')
	for i in 30:
		main.step(1.0 / 30.0)
	var on := Array(qa.log_lines).filter(func(l): return l.begins_with("брифинг вкл"))
	eq(on.size(), 1, "шаг brief пишет строку")
	if on.size() == 1:
		ok("строка 3: «Из песка что-то схватило круглую рыбку»" in on[0], "строка мира до плашки: " + on[0])
	var note := Array(qa.log_lines).filter(func(l): return l.begins_with("02r |"))
	eq(note.size(), 1, "заметка под брифингом")
	if note.size() == 1:
		ok("строка 3: пусто · ждёт конца брифинга: «Из песка что-то схватило круглую рыбку»" in note[0],
			"под плашкой строка мира отложена: " + note[0])
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
	var after: Array = []   # шаги между подходом к посту и снимком (#1018)
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
			after = []
		elif not look.is_empty() and st["do"] != "shot":
			after.append(st["do"])
		if st["do"] == "shot" and st["name"] == "30-kartochka-sonar":
			shot = true
			break
	ok(shot and not look.is_empty(), "снимок карточки после «Погрузиться» и подхода к посту")
	ok(after.has("breach") and after.has("cards") and after.has("drain") and after.has("silt"),
		"после подхода к посту — тревоги сняты и карточки с нуля: тревога по дороге не сворачивает карточку (#1018): %s" % [after])
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


## Issue #1013: кадры сразу после шага «ship» (выгрузка мест в видеокарту после переноса через отмель) не попадают
## в худший кадр — пишутся отдельно «после прыжка», а следующий провал виден как обычно.
func test_worst_frame_skips_ship_jump() -> void:
	var r := QaRunner.new()
	var t := 1000000
	r._measure(t)
	r._jump = QaRunner.JUMP_FRAMES   # так ставит шаг «ship»
	t += 180000                      # первая выгрузка места
	r._measure(t)
	for i in QaRunner.JUMP_FRAMES - 1:
		t += 20000
		r._measure(t)
	eq(roundi(r.worst_ms), 0, "кадр после прыжка не худший кадр")
	eq(roundi(r.jump_ms), 180, "он записан отдельно")
	t += 90000                       # провал уже после прыжка
	r._measure(t)
	eq(roundi(r.worst_ms), 90, "провал после окна виден")
	ok(r.worst_text().contains("худший кадр 90 мс") and r.worst_text().ends_with(" · после прыжка 180 мс"),
		"оба в строке скриншота: " + r.worst_text())
	r.after_shot()
	eq(roundi(r.jump_ms), 0, "после снимка сброс")
	r.free()


## Issue #1204: корабль возвращается к 10 посреди тёмного экрана кат-сцены «глубже» — кадр выгрузки мест у 10
## под закрытой шторкой не худший кадр, а «после прыжка»; провал, когда шторка уже открывается, виден как обычно.
func test_worst_frame_skips_dark_trip() -> void:
	var r := QaRunner.new()
	r.trip = DescentTrip.new()
	r.trip.start()
	var t := 1000000
	r._measure(t)
	t += 70000                       # затемнение ещё идёт — кадр виден
	r._measure(t)
	eq(roundi(r.worst_ms), 70, "кадр в затемнении — худший")
	r.trip.update(DescentTrip.SINK + DescentTrip.HOLD * 0.5)   # возвращение корабля: шторка закрыта
	ok(QaRunner.dark_trip(r.trip), "шторка закрыта")
	t += 186000                      # мир и места у 10 разом
	r._measure(t)
	eq(roundi(r.worst_ms), 70, "кадр под шторкой не худший")
	eq(roundi(r.jump_ms), 186, "он записан «после прыжка»")
	r.trip.update(DescentTrip.HOLD * 0.5 + 0.1)   # шторка открывается
	ok(not QaRunner.dark_trip(r.trip), "шторка открывается")
	t += 90000
	r._measure(t)
	eq(roundi(r.worst_ms), 90, "провал при открытой шторке виден")
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


func test_worst_note_pipelines() -> void:   # issue #983: провал отрисовки — сборка шейдеров или нет
	eq(QaRunner.pipes_note(PackedInt32Array([0, 0, 0, 0, 0])), "", "сборок нет — молчим")
	eq(QaRunner.pipes_note(PackedInt32Array([0, 0, 2, 1, 0])), "сборок шейдеров 3: поверхности 2, при отрисовке 1")
	eq(QaRunner.worst_note("шаг 595 wait", 338.0, 12.0, 2.0, 352.0, "", PackedInt32Array([1, 0, 0, 4, 0])),
		"шаг 595 wait, код 12 мс, отрисовка 338 мс (сборок шейдеров 5: 2D 1, при отрисовке 4), видеокарта 2 мс")
	eq(QaRunner.worst_note("шаг 54 press", 7.2, 5.4, 0.0), "шаг 54 press, код 5 мс, отрисовка 7 мс", "без счётчиков — как раньше")
	var r := QaRunner.new()
	r._on_post_draw()
	r._on_post_draw()
	eq(r.pipes, PackedInt32Array([0, 0, 0, 0, 0]), "между двумя пустыми кадрами сборок нет — счёт за кадр, не накопленный")
	r.free()


func test_worst_note_code_and_gpu() -> void:   # issue #217, #281: отрисовка мала — код это или видеокарта
	eq(QaRunner.worst_note("шаг 54 press", 7.2, 5.4, 0.0), "шаг 54 press, код 5 мс, отрисовка 7 мс", "без замера видеокарты")
	eq(QaRunner.worst_note("шаг 54 press", 7.2, 5.4, 731.0), "шаг 54 press, код 5 мс, отрисовка 7 мс, видеокарта 731 мс",
		"видеокарта — когда драйвер замеряет")
	eq(QaRunner.worst_note("", 3.0), "отрисовка 3 мс", "без шага и кода — как раньше")


## #519 (тестер в #1350, 10.11): `21a-vent` 107 мс при коде 18 и отрисовке 19 — остаток кадра делим на части движка.
func test_worst_rest_parts() -> void:
	# кадр 1 000 000…1 107 000 мкс: код 18 мс, отрисовка 1 020 000…1 039 000, физика с 1 100 000, узлы с 1 104 000
	var parts := QaRunner.rest_parts(1000000, 1107000, 18.0, 1020000, 1039000, 1100000, 1104000)
	near(parts["между кадрами"], 61.0, 0.01, "от конца отрисовки до первого такта физики")
	near(parts["физика"], 4.0, 0.01, "такты физики до обработки узлов")
	near(parts["узлы"], 5.0, 0.01, "узлы до кода (2) и после начала обработки (3)")
	eq(QaRunner.worst_note("шаг 341 hold", 19.0, 18.0, 4.0, 107.0, "", PackedInt32Array(), parts),
		"шаг 341 hold, код 18 мс, отрисовка 19 мс, видеокарта 4 мс, вне шага 70 мс (между кадрами 61, узлы 5, физика 4)")
	var calm := QaRunner.rest_parts(1000000, 1107000, 18.0, 1020000, 1039000, 1030000, 1104000)
	eq(calm["физика"], 0.0, "такт физики раньше отрисовки — тактов в кадре не было")
	near(calm["между кадрами"], 65.0, 0.01, "тогда между кадрами — до обработки узлов")
	eq(QaRunner.rest_parts(1000000, 1107000, 18.0, 0, 0, 0, 0), {}, "без отрисовки (headless) — меток нет")
	eq(QaRunner.rest_parts(1000000, 1107000, 18.0, 990000, 995000, 0, 1104000), {}, "отрисовка прошлого кадра — не делим")
	eq(QaRunner.rest_note(99.0, 18.0, 19.0, parts), "", "кадр короче 100 мс — без остатка")
	eq(QaRunner.rest_note(107.0, 50.0, 25.0, parts), "", "код и отрисовка — больше половины кадра, остаток 32 мс: виновник уже в строке")
	# `09f-deeper` 112 мс: код 21 + отрисовка 37 — больше половины, но 54 мс без виновника (#1350, 13.11)
	eq(QaRunner.rest_note(112.0, 21.0, 37.0, {"между кадрами": 48.0, "узлы": 4.0}),
		"вне шага 54 мс (между кадрами 48, узлы 4, прочее 2)", "остаток от 40 мс расписан и при коде с отрисовкой больше половины")
	eq(QaRunner.rest_note(112.0, 40.0, 33.0, parts), "", "остаток 39 мс при коде с отрисовкой больше половины — молчит")
	eq(QaRunner.rest_note(120.0, 10.0, 10.0, {"между кадрами": 90.0, "физика": 0.2, "узлы": 0.0}),
		"вне шага 100 мс (между кадрами 90, прочее 10)", "доли меньше 1 мс молчат, не разложенное — «прочее»")


## Метки ставят сигналы дерева: первый такт физики после отрисовки, начало обработки узлов.
func test_worst_rest_marks() -> void:
	var r := QaRunner.new()
	r._on_pre_draw()
	r._on_post_draw()
	r._on_physics_frame()
	var first := r._phys_us
	OS.delay_usec(1000)
	r._on_physics_frame()
	eq(r._phys_us, first, "второй такт в том же кадре метку не двигает")
	r._on_process_frame()
	ok(r._post_us <= r._phys_us and r._phys_us <= r._proc_us, "метки по порядку кадра")
	r._on_post_draw()
	OS.delay_usec(1000)
	r._on_physics_frame()
	ok(r._phys_us > r._post_us, "после новой отрисовки — новый первый такт")
	r.free()


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


func test_layer_shots_look_out_window() -> void:   # issue #967: 32i–32m снимали стену сканера, строку костей перебивал «Новый вид»
	var raw := FileAccess.get_file_as_string("res://tools/qa/scenario.json")
	var steps: Array = JSON.parse_string(raw)
	var look := {}
	var fly := false
	var held := false
	var waited := 0.0
	var since_ship := 0.0
	var hot := false
	var cooled := false
	var seen := []
	for st in steps:
		match st["do"]:
			"goto":
				look = st
				held = false
				waited = 0.0
			"fly":
				fly = st.get("on", true)
			"hold":
				held = true
			"wait":
				waited += float(st["s"])
				since_ship += float(st["s"])
			"ship":
				since_ship = 0.0
			"hot":
				cooled = hot and float(st["heat"]) <= 0.0
			"shot":
				var name: String = st["name"]
				if name == "32g-kosti-skan":
					ok(is_equal_approx(float(look["x"]), 3.5) and is_equal_approx(float(look["z"]), -2.0), "32g — у сканера")
					ok(not held, "32g — кнопку не держат: «Новый вид» не перебивает строку костей")
					ok(waited > EcoBones.INSPECT_TIME and waited < EcoBones.INSPECT_TIME + Status.MESSAGE_SECONDS,
						"32g — стоим дольше осмотра (%.1f с), строка ещё на приборах" % waited)
				if name in ["32i-kurilshchik-znak", "32j-kurilshchik-veerniki", "32k-stekloust-glaz",
						"32l-cvetok-gasnet", "32m-cvetok-rif"]:
					seen.append(name)
					ok(not fly, "%s — с мостика" % name)
					ok(float(look["z"]) < -2.5 and absf(float(look["x"])) < 1.5 and is_zero_approx(float(look["yaw"])),
						"%s — у носового окна, взгляд по носу" % name)
				if name == "32j-kurilshchik-veerniki":
					hot = true
					# issue #982: строка мира перед строкой веера держит её в очереди до MIN_SHOW — снимок после
					ok(since_ship > EcoFan.VENT_DWELL + Status.Message.MIN_SHOW + 0.25
							and since_ship < EcoFan.VENT_DWELL + Status.MESSAGE_SECONDS,
						"32j — строка веера на приборах и после очереди (%.1f с)" % since_ship)
				if name == "33-kondensat-obychno":
					ok(cooled, "33 — реактор остужен после курильщика (нагрев сушит конденсат)")
	eq(seen.size(), 5, "все снимки 32i–32m на месте")


func test_shell_shot_through_window() -> void:   # отчёт 2026-10-31-0330: каустики на камне (#1047) — Раковина в окне, а не стена сканера
	var raw := FileAccess.get_file_as_string("res://tools/qa/scenario.json")
	var steps: Array = JSON.parse_string(raw)
	var ship := {}
	var look := {}
	var fly := {}
	var shot := false
	for st in steps:
		match st["do"]:
			"ship":
				ship = st
				look = {}
			"goto":
				look = st
			"fly":
				fly = st if st.get("on", true) else {}
			"shot":
				if st["name"] == "32h2-rakovina-okno":
					shot = true
					break
	ok(shot, "в сценарии есть снимок Раковины в окно")
	# отчёт 2026-10-31-0430 (#1052): с роста игрока низ Раковины закрыт пультом пилота — глаз поднят над пультом
	ok(not fly.is_empty() and float(fly["y"]) >= 2.0 and float(fly["pitch"]) < -10.0,
			"глаз над пультом пилота, взгляд вниз в окно")
	ok(not look.is_empty() and float(look["z"]) < -2.5 and absf(float(look["x"])) < 1.5
			and is_zero_approx(float(look["yaw"])), "у носового окна, взгляд по носу")
	var at := Vector2(float(ship["x"]), float(ship["z"]))
	var p: Dictionary = LayerMap.POINTS["03"]
	var shell := Vector2(float(p["x"]), float(p["z"]))
	ok(at.distance_to(shell) < 30.0, "Раковина близко (%.0f м)" % at.distance_to(shell))
	var nose := Vector2(0, -1).rotated(-deg_to_rad(float(ship["yaw"])))
	ok(nose.dot((shell - at).normalized()) > 0.95, "Раковина впереди по носу")


func test_crust_shot_beam_on_floor() -> void:   # отчёт 2026-10-31-0330: у 10 в окно дна в луче не видно (#1045) — снимок из-под днища
	var raw := FileAccess.get_file_as_string("res://tools/qa/scenario.json")
	var steps: Array = JSON.parse_string(raw)
	var ship := {}
	var fly := {}
	var shot := false
	for st in steps:
		match st["do"]:
			"ship":
				ship = st
			"fly":
				fly = st if st.get("on", true) else {}
			"shot":
				if st["name"] == "34d2-korka-luch":
					shot = true
					break
	ok(shot and not fly.is_empty(), "в сценарии есть снимок дна у 10 полётом")
	var at := Vector2(float(ship["x"]), float(ship["z"]))
	var p: Dictionary = LayerMap.POINTS["10"]
	ok(at.distance_to(Vector2(float(p["x"]), float(p["z"]))) < 60.0, "у Спуска 10")
	var floor_y := Seabed.height(at.x, at.y)
	var eye_y := maxf(float(ship["y"]), floor_y + Helm.Ship.CLEARANCE) + float(fly["y"])   # корабль не ниже дна + зазор
	ok(eye_y > floor_y + 2.5, "глаз над дном (%.1f > %.1f + 2,5) — пятно луча впереди, а не под носом" % [eye_y, floor_y])
	# отчёт 2026-10-31-0430 (#1052): с 12 м пятна на дне в кадре не видно — глаз ближе ко дну
	ok(eye_y < floor_y + 6.0, "глаз у дна (%.1f < %.1f + 6) — пятно луча яркое и крупное" % [eye_y, floor_y])
	ok(float(fly["pitch"]) < -10.0, "взгляд вниз — на пятно луча")
	# отчёты 2026-11-01 (#1052): носом на восток склон уходит вниз круче луча — пятно лишь краем конуса, тусклое.
	# Носом вдоль склона: дно в 30 м впереди по ходу почти на той же высоте
	var yaw := deg_to_rad(float(ship.get("yaw", 0.0)))
	var ahead := at + Vector2(-sin(yaw), -cos(yaw)) * 30.0   # yaw = 0 — нос к −Z, растёт — влево
	ok(absf(Seabed.height(ahead.x, ahead.y) - floor_y) < 4.0,
			"дно впереди не уходит из-под луча (%.1f м на 30 м)" % (Seabed.height(ahead.x, ahead.y) - floor_y))
	ok(EcoBrink.share(at.x, at.y) > 0.3, "за границей корки — цвет дна #1045 виден")


func test_count_note() -> void:   # issue #1156: узлы и объекты в строке скриншота — видно, копится ли что-то за забег
	eq(QaRunner.count_note(4210, 18344), " · узлы 4210, объекты 18344")
	eq(QaRunner.count_note(4210, 18344, 3), " · узлы 4210, объекты 18344 (сирот 3)", "сироты — только если есть")


func test_draw_note() -> void:   # #822: вызовы и треугольники кадра снимка — сверить бюджет у 10 и на отмели
	eq(QaRunner.draw_note(168, 290787), " · вызовов 168, треуг. 291 тыс.")
	eq(QaRunner.draw_note(0, 0), "", "нет замера (headless) — ничего")


## Корабль и полёт перед снимком name в сценарии: [ship, fly] (fly — {} без полёта); нет снимка — [].
static func _before_shot(name: String) -> Array:
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	var ship := {}
	var fly := {}
	for st in steps:
		match st["do"]:
			"ship":
				ship = st
			"fly":
				fly = st if st.get("on", true) else {}
			"shot":
				if st["name"] == name:
					return [ship, fly]
	return []


## #1757 (уровни и ГД, 13.11 23:35/23:42): кадр гнезда и купольника из достижимого места — без тестового полёта,
## глазами у носового окна. Корабль шага `ship` стоит законно: выше нижнего предела хода всем днищем, корпус по всей
## длине вне арки, нос — на гнездо купольника; корабль на 12 м ближе к гнезду, чем в `37` (там глаз вынесен за нос полётом).
func test_gate_window_shot_is_reachable() -> void:
	var b := _before_shot("37b-okno-gnezdo")
	ok(not b.is_empty() and not b[0].is_empty(), "снимок гнезда из носового окна есть в сценарии")
	if b.is_empty() or b[0].is_empty():
		return
	ok(b[1].is_empty(), "без тестового полёта: глаз игрока на палубе")
	var pos := Vector3(float(b[0]["x"]), float(b[0]["y"]), float(b[0]["z"]))
	var yaw := deg_to_rad(float(b[0]["yaw"]))
	var h := Helm.Ship.new()
	h.ground = func(x: float, z: float) -> float: return Seabed.height(x, z)
	var low: float = h.floor_at(pos, yaw)
	ok(pos.y >= low + 0.5, "корабль выше нижнего предела хода с запасом: %.1f при пределе %.1f" % [pos.y, low])
	ok(not GateArch.hits(pos, yaw), "корпус по всей длине вне опор и плеч арки")
	var n := GateDiag.nest_pos(EcoDome.NEST)
	var to := Vector2(n.x - pos.x, n.z - pos.z)
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	ok(fwd.dot(to.normalized()) > cos(deg_to_rad(3.0)), "нос — на гнездо купольника")
	ok(to.length() < 30.0, "гнездо ближе 30 м от центра корабля: %.1f" % to.length())
	var was := _before_shot("37-kupolnik-stvorka")
	ok(to.length() < Vector2(n.x - float(was[0]["x"]), n.z - float(was[0]["z"])).length() - 10.0, "ближе, чем корабль кадра 37")


func test_slope_shots_edge_and_rocks() -> void:   # отчёт #1182: склон 06→10 (#832) сценарий не проходил — нечего проверить
	var edge := _before_shot("34e-kraj-06")
	ok(not edge.is_empty() and not edge[1].is_empty(), "снимок Края отмели 06 из-под днища")
	var at := Vector2(float(edge[0]["x"]), float(edge[0]["z"]))
	ok(at.x < EcoDrop.BROW_X and at.x > EcoDrop.BROW_X - 40.0, "на плато перед бровкой (x %.0f)" % at.x)
	ok(at.y > EcoDrop.Z_FROM and at.y < EcoDrop.Z_TO, "напротив клиньев (z %.0f)" % at.y)
	near(float(edge[0]["yaw"]), -90.0, 1e-6, "носом на восток — на бровку")
	var slope := _before_shot("34f-sklon")
	ok(not slope.is_empty() and not slope[1].is_empty(), "снимок склона из-под днища")
	var p := Vector2(float(slope[0]["x"]), float(slope[0]["z"]))
	ok(Seabed.Slope.open(p.x, p.y), "корабль в проходе склона, а не в стене")
	var floor_y := Seabed.height(p.x, p.y)
	ok(floor_y < -130.0 and floor_y > -250.0, "середина склона (дно %.0f м)" % floor_y)
	var eye_y := maxf(float(slope[0]["y"]), floor_y + Helm.Ship.CLEARANCE) + float(slope[1]["y"])
	ok(eye_y > floor_y + 2.5 and eye_y < floor_y + 10.0, "глаз у дна (%.1f над дном) — пятно луча на скале" % (eye_y - floor_y))
	var yaw := deg_to_rad(float(slope[0].get("yaw", 0.0)))
	var ahead := p + Vector2(-sin(yaw), -cos(yaw)) * 30.0
	ok(absf(Seabed.height(ahead.x, ahead.y) - floor_y) < 15.0,
			"носом вдоль склона: дно впереди не уходит из-под луча (%.1f м на 30 м)" % (Seabed.height(ahead.x, ahead.y) - floor_y))


## #1481: шаги «floor» и «outside» — корабль на нижнем пределе хода над рельефом, камера с борта стоит над кормой,
## пока сценарий её не уберёт; снимок ждёт кадра. Свой ровный грунт — тест не опирается на рельеф у старта.
func test_floor_and_outside_steps() -> void:
	var q := QaScript.parse('[{"do": "floor"}, {"do": "outside", "at": 0.5}, {"do": "shot", "name": "k"}, ' \
		+ '{"do": "outside", "on": false}, {"do": "outside", "at": 3}]')
	eq(q.errors.size(), 0, "шаги floor и outside известны")
	var out := q.advance(0.1)
	eq(out, [["floor"], ["outside", true, 0.5, false]], "снимок — после кадра с камерой снаружи")
	var out2 := q.advance(0.1)
	eq(out2[0], ["shot", "k"], "затем снимок")
	eq(out2[1], ["outside", false, 1.0, false], "камера назад на мостик")
	eq(out2[2], ["outside", true, 1.0, false], "точка облёта не дальше кормы")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.helm.ground = func(_x: float, _z: float) -> float: return -100.0
	main.start_qa('[{"do": "ship", "x": 50, "y": -40, "z": 20, "yaw": 0}, {"do": "floor"}, ' \
		+ '{"do": "outside", "at": 1.0}, {"do": "wait", "s": 1.0}]')
	for i in 20:
		main.step(1.0 / 30.0)
	var low := main.helm.floor_at(main.helm.pos, main.helm.yaw)
	ok(low > -100.0, "предел хода выше грунта")
	near(main.helm.pos.y, low, 0.05, "корабль на нижнем пределе хода")
	ok(main.flyby.active() and main.flyby.still, "камера с борта стоит")
	ok(main.flyby_cam.current, "кадр — с борта")
	ok(main.flyby_cam.transform.origin.is_equal_approx(Flyby.START_PATH[2]), "над кормой: %s" % main.flyby_cam.transform.origin)
	ok(main.flyby_cam.get_node_or_null(QaRunner.LAMP_NAME) == null, "без lamp — без света тестера")
	main.start_qa('[{"do": "outside", "on": false}, {"do": "wait", "s": 0.2}]')
	for i in 3:
		main.step(1.0 / 30.0)
	ok(not main.flyby.active(), "камера убрана")
	ok(main.camera.current, "глаза на мостике")
	main.queue_free()
	await frames(1)


## #1481: у 10 на 300 м корпус снаружи чёрный — шаг «outside» с "lamp" ставит у камеры с борта свет тестера, который
## светит только отмель и корпус (слой мира, не мостик), и убирает его вместе с камерой.
func test_outside_lamp() -> void:
	var q := QaScript.parse('[{"do": "outside", "at": 1.0, "lamp": true}]')
	eq(q.advance(0.1)[0], ["outside", true, 1.0, true], "lamp разобран")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.helm.ground = func(_x: float, _z: float) -> float: return -400.0
	main.start_qa('[{"do": "ship", "x": 50, "y": -300, "z": 20, "yaw": 0}, {"do": "outside", "at": 1.0, "lamp": true}, ' \
		+ '{"do": "wait", "s": 1.0}]')
	for i in 10:
		main.step(1.0 / 30.0)
	var lamp := main.flyby_cam.get_node_or_null(QaRunner.LAMP_NAME) as OmniLight3D
	ok(lamp != null, "у камеры с борта — свет тестера")
	if lamp:
		eq(lamp.light_cull_mask, OceanView.LIT_WORLD, "светит корпус и дно, не мостик")
		ok(lamp.omni_range >= 60.0, "дотягивается от камеры над кормой до носа и грунта: %.0f м" % lamp.omni_range)
	main.start_qa('[{"do": "outside", "on": false}, {"do": "wait", "s": 0.2}]')
	for i in 3:
		main.step(1.0 / 30.0)
	await frames(1)
	ok(main.flyby_cam.get_node_or_null(QaRunner.LAMP_NAME) == null, "камера убрана — света нет")
	main.queue_free()
	await frames(1)


## #1400 (отчёт qa/2026-11-11-0010-svezhaya-b946a31): цену тени прожектора на «Обычно» тестер меряет на устройстве —
## шаг «luch_ten» гасит тень, true возвращает её по уровню графики («Экономно» — без тени и после true).
func test_luch_ten_step() -> void:
	var q := QaScript.parse('[{"do": "luch_ten", "on": false}, {"do": "luch_ten"}]')
	eq(q.errors.size(), 0, "шаг luch_ten известен")
	eq(q.advance(0.1).slice(0, 2), [["luch_ten", false], ["luch_ten", true]], "команды сцене")
	var probe := QaScript.parse(FileAccess.get_file_as_string("res://tools/qa/luch-ten.json"))
	eq(probe.errors.size(), 0, "сценарий пробы tools/qa/luch-ten.json без ошибок: %s" % ", ".join(probe.errors))
	# #1606: перед каждым снимком корабль ставится в одну и ту же точку — течение за 5 с сносит его на ~1 м
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/qa/luch-ten.json"))
	var pose = null
	var placed := false
	var shots := 0
	for st in steps:
		if st["do"] == "ship":
			var p := [st["x"], st["y"], st["z"], st["yaw"]]
			if pose == null:
				pose = p
			eq(p, pose, "одна поза у всех трёх кадров")
			placed = true
		elif st["do"] == "shot":
			ok(placed, "перед %s корабль поставлен заново" % st["name"])
			placed = false
			shots += 1
	eq(shots, 3, "три кадра")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main._apply_graphics(Graphics.NORMAL)
	ok(main.searchlight.spot.shadow_enabled, "на «Обычно» прожектор с тенью")
	main.start_qa('[{"do": "luch_ten", "on": false}, {"do": "wait", "s": 0.2}]')
	for i in 3:
		main.step(1.0 / 30.0)
	ok(not main.searchlight.spot.shadow_enabled, "после шага — без тени")
	QaRunner.luch_ten(main, true)
	ok(main.searchlight.spot.shadow_enabled, "true — тень по уровню графики")
	main._apply_graphics(Graphics.ECONOMY)
	QaRunner.luch_ten(main, true)
	ok(not main.searchlight.spot.shadow_enabled, "на «Экономно» тени нет и после true")
	main.queue_free()
	await frames(1)
