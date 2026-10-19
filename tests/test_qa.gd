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
	for i in 1200:  # 40 с игры
		main.step(1.0 / 30.0)
		sat = sat or main.pilot.seated
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
