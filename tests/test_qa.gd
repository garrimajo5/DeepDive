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
	var sat := false
	var table_seen := false
	var zap_seen := false
	var shots := 0
	var table: Node3D = main.bridge.props[BridgeProps.TABLE]
	var legs_seen := false
	for i in 1500:  # 50 с игры
		# снимок берёт уже нарисованный кадр — камеру до шага, в котором он снят
		var cam := main.camera
		var table_vis := cam.is_position_in_frustum(table.global_position + table.global_basis.y * 0.9)
		var zap_vis := cam.is_position_in_frustum(main.ship.to_global(Zap.LEVER_POS))
		var j: Dictionary = main.me.joints()
		var legs_vis := true
		for k in ["toe_l", "toe_r", "hand_l", "hand_r"]:
			legs_vis = legs_vis and cam.is_position_in_frustum(main.ship.to_global(j[k]))
		main.step(1.0 / 30.0)
		sat = sat or main.pilot.seated
		for k in range(shots, qa.log_lines.size()):   # #48: на 09-sonar в кадре голостол, на 10-zap — рычаг
			if qa.log_lines[k].begins_with("скриншот 09-sonar"):
				table_seen = table_vis
			if qa.log_lines[k].begins_with("скриншот 06b-own-legs"):
				legs_seen = legs_vis
			if qa.log_lines[k].begins_with("скриншот 10-zap"):
				zap_seen = zap_vis
		shots = qa.log_lines.size()
		if qa.script_q.finished:
			break
	ok(qa.script_q.finished, "сценарий дошёл до конца")
	ok(sat, "по сценарию садились за штурвал")
	ok(not main.pilot.seated, "и встали")
	ok(main.helm.pos.z < z0 - 20.0, "корабль прошёл вперёд: %.1f м" % (z0 - main.helm.pos.z))
	ok(FileAccess.file_exists(QaRunner.OUT + "/done.txt"), "done.txt записан")
	var log := FileAccess.get_file_as_string(QaRunner.OUT + "/log.txt")
	ok(log.contains("сел за штурвал") and log.contains("за штурвалом"), "в логе есть состояние за штурвалом")
	ok(log.contains("прожектор погашен | ") and log.contains("свет выкл"), "по сценарию гасили прожектор")
	ok(main.light_on, "и зажгли снова")
	ok(log.contains("пульт энергии | ") and log.contains("у пульта энергии"), "по сценарию открывали пульт энергии")
	ok(not main.at_power, "и закрыли")
	eq(main.reactor.share[Reactor.Sys.ENGINES], 25, "на пульте сняли 5 с двигателей")
	ok(main.sonar.ping_time > 0.0, "у голостола дали импульс сонара")
	ok(main.zap.last > 0.0, "у рычага дали разряд")
	ok(table_seen, "на снимке 09-sonar голостол в кадре (#48)")
	ok(zap_seen, "на снимке 10-zap рычаг в кадре")
	ok(legs_seen, "на снимке 06b-own-legs в кадре свои ступни и кисти (#49)")
	ok(log.contains("курс %d°" % Status.course_deg(main.helm.yaw)), "курс в логе — как на приборах, без минуса (#48)")
	ok(log.contains("вентиль: пар, реактор остывает | "), "в машинном держали вентиль")
	ok(main.reactor.scram > 0.0 and log.contains("аварийный сброс щитком | ") and log.contains("° сброс"),
		"щитком заглушили реактор")


func test_goto_and_hot_steps() -> void:
	var q := QaScript.parse('[{"do": "goto", "x": 2.2, "z": 17.2, "yaw": -90}, {"do": "hot", "heat": 75}]')
	eq(q.errors.size(), 0, "шаги понятны")
	var out := q.advance(0.1)
	eq(out[0], ["goto", 2.2, 17.2, -90.0], "переход")
	eq(out[1], ["hot", 75.0], "перегрев")
	var q2 := QaScript.parse('[{"do": "goto", "x": 0.9, "z": 0.0, "yaw": 37, "pitch": -35}]')
	eq(q2.advance(0.1)[0], ["goto", 0.9, 0.0, 37.0, -35.0], "переход с наклоном взгляда")
