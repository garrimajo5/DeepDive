extends TestCase
## Замер по кадрам `tools/probe_frames.gd` (#1379): разбор провала кадра (#519) не с нуля. Ключи, строка таблицы,
## итог цикла — и что каждая последовательность запускает своё событие на настоящей сцене (переименованный метод
## `Main` молча ломал бы инструмент).

const Probe := preload("res://tools/probe_frames.gd")

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_parse_defaults_and_unknown_seq() -> void:
	var kv := Probe.parse(PackedStringArray(["seq=ping", "warm=0", "out.txt"]))
	eq(kv["seq"], "ping", "последовательность из ключа")
	eq(kv["warm"], "0", "без прогрева")
	eq(kv["cycles"], "2", "по умолчанию два цикла")
	ok(not kv.has("error"), "ping — есть")
	ok(Probe.parse(PackedStringArray(["seq=нет"])).has("error"), "неизвестная последовательность — ошибка")
	ok(not Probe.parse(PackedStringArray([])).has("pre"), "по умолчанию — без кадров до цикла")
	ok(Probe.SEQS.has(Probe.parse(PackedStringArray([]))["seq"]), "по умолчанию — известная")


func test_rest_and_row() -> void:
	near(Probe.rest_ms(30.0, 10.0, 15.0), 5.0, 1e-6, "остаток — вне шага и отрисовки")
	eq(Probe.rest_ms(10.0, 8.0, 5.0), 0.0, "не меньше нуля")
	var r := Probe.row(1, 3, "наверх", 10.0, 15.0, 30.0, "мир 8")
	ok(r.contains("наверх") and r.contains("5.0") and r.ends_with("мир 8"), "строка: событие, остаток, части: " + r)
	ok(Probe.row(1, 3, "", 1.0, 1.0, 2.0).ends_with("2.0"), "без частей — без хвоста")


func test_summary_counts_event_frame() -> void:
	var fr := [{"step": 1.0, "draw": 400.0, "total": 500.0},   # кадр события: сборка шейдеров без прогрева
		{"step": 10.0, "draw": 20.0, "total": 40.0}, {"step": 30.0, "draw": 5.0, "total": 90.0}]
	var s := Probe.summary(1, fr)
	ok(s.contains("3 кадров") and s.contains("кадр 0 500.0"), "худший — кадр события: " + s)
	ok(s.contains("шаг 30.0") and s.contains("отрисовка 400.0") and s.contains("остаток 99.0"), "максимумы частей: " + s)
	ok(Probe.summary(1, []).contains("нет кадров"), "пусто — нечего сравнивать")


func test_shown_rows() -> void:
	ok(Probe.shown(0, 1.0, 50.0, false), "первые кадры — всегда")
	ok(not Probe.shown(Probe.HEAD, 1.0, 50.0, false), "дальше — только долгие")
	ok(Probe.shown(Probe.HEAD, 60.0, 50.0, false), "долгий — в таблице")
	ok(Probe.shown(Probe.HEAD, 1.0, 50.0, true), "all=1 — все")


func test_slow_threshold() -> void:
	eq(Probe.slow_ms({"slow": "50"}, []), 50.0, "slow= — как задан")
	eq(Probe.slow_ms({}, [{"total": 900.0}]), INF, "без прошлых кадров — нет долгих")
	var fr := [{"total": 900.0}, {"total": 100.0}, {"total": 300.0}]
	near(Probe.slow_ms({}, fr), Probe.SLOW_K * 200.0, 1e-6, "от среднего прошлых без первого")


func test_scene_each_sequence_fires() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	for seq: String in Probe.SEQS:
		eq(Probe.event(main, seq, 1), "", "%s: событие только на первом кадре" % seq)
		ok(Probe.event(main, seq, 0) != "", "%s: подпись события" % seq)
		main.step(Probe.DT)
		match seq:
			"surface":
				ok(main.flyby.kind == Flyby.Kind.SURFACE, "наверх — вид с борта")
				ok(main.run.ended, "забег кончен")
			"start":
				ok(main.flyby.kind == Flyby.Kind.START, "облёт")
			"ping":
				ok(main.sonar.count > 0, "импульс ушёл")
		Probe.reset(main)
		ok(not main.flyby.active(), "%s: после цикла вид с борта погашен" % seq)
		ok(not main.run.ended, "%s: новый забег" % seq)


## seq=qa (#1350): кусок сценария тестера — постановка с последнего «ship», окно замера от снимка from= до to=,
## снимков и выхода в куске нет.
func test_qa_plan_window() -> void:
	var steps := [{"do": "shot", "name": "a"}, {"do": "ship", "x": 0, "y": -30, "z": 0}, {"do": "wait", "s": 1},
		{"do": "shot", "name": "b"}, {"do": "wait", "s": 2}, {"do": "log", "note": "x"}, {"do": "shot", "name": "c"},
		{"do": "quit"}]
	eq(Probe.qa_find(steps, "b"), 3, "снимок по имени")
	eq(Probe.qa_find(steps, "4"), 4, "шаг по номеру")
	eq(Probe.qa_find(steps, "нет"), -1, "нет снимка")
	var plan := Probe.qa_plan(steps, {"from": "b", "to": "c"})
	eq(plan["start"], 1, "постановка — с последнего ship до from")
	eq(plan["steps"].size(), 4, "ship, wait, wait, log — без снимков")
	eq(plan["w0"], 2, "замер — с шага после снимка from")
	eq(plan["w1"], 4, "до снимка to")
	eq(Probe.qa_plan(steps, {"from": "b"})["w1"], 4, "без to — до конца, quit выброшен")
	eq(Probe.qa_plan(steps, {"from": "b", "start": "a"})["start"], 0, "start= — своя постановка")
	ok(Probe.qa_plan(steps, {}).has("error"), "без from — ошибка")
	ok(Probe.qa_plan(steps, {"from": "c", "to": "b"}).has("error"), "to раньше from — ошибка")
	ok(Probe.qa_plan(steps, {"from": "b", "start": "c"}).has("error"), "start позже from — ошибка")
	ok(not Probe.parse(PackedStringArray(["seq=qa", "from=b"])).has("error"), "qa — известная последовательность")


## Снимок по префиксу имени до «-» (#1350, 11.11): from=32i — 32i-…; префикс двух снимков — ошибка со списком,
## номер шага — «#N» или число без такого префикса.
func test_qa_find_prefix() -> void:
	var steps := [{"do": "ship", "x": 0, "y": -30, "z": 0}, {"do": "shot", "name": "32i-kurilshchik-znak"},
		{"do": "wait", "s": 1}, {"do": "shot", "name": "32j-kurilshchik-veerniki"}, {"do": "shot", "name": "1-odin"},
		{"do": "shot", "name": "32ia-drugoj"},
		{"do": "shot", "name": "32-kamni"}, {"do": "shot", "name": "32-kochki"}]
	eq(Probe.qa_find(steps, "32i"), 1, "префикс до «-»: не 32ia-…")
	eq(Probe.qa_find(steps, "32j-kurilshchik-veerniki"), 3, "полное имя")
	eq(Probe.qa_find(steps, "32ia"), 5, "свой префикс")
	var amb := Probe.qa_match(steps, "32")
	ok(amb.has("error") and amb["error"].contains("32-kamni") and amb["error"].contains("32-kochki"),
		"префикс двух снимков — ошибка со списком: %s" % amb)
	eq(Probe.qa_find(steps, "1"), 4, "число с таким префиксом — снимок")
	eq(Probe.qa_find(steps, "#1"), 1, "#N — номер шага")
	eq(Probe.qa_find(steps, "2"), 2, "число без префикса — номер шага")
	eq(Probe.qa_find(steps, "#9"), -1, "нет шага")
	eq(Probe.qa_find(steps, "#7"), 7, "#N и у неоднозначного префикса")
	var plan := Probe.qa_plan(steps, {"from": "32i", "to": "32j"})
	eq([plan["from"], plan["to"]], [1, 3], "окно по префиксам: %s" % plan)
	ok(Probe.qa_plan(steps, {"from": "32"})["error"].contains("несколько"), "неоднозначный from — ошибка")


func test_qa_event_label() -> void:
	var q := QaScript.parse('[{"do": "wait", "s": 1}, {"do": "ping"}]')
	eq(Probe.qa_event(q), "wait", "текущий шаг")
	q.index = 1
	eq(Probe.qa_event(q), "ping", "следующий")
	q.index = 2
	eq(Probe.qa_event(q), "конец", "за концом")


func test_qa_stats_max_and_mean() -> void:
	var acc := {}
	Probe.qa_add(acc, 10.0, {"мир": 6.0}, {"EcoFish": 4.0}, "мир 6")
	Probe.qa_add(acc, 30.0, {"мир": 20.0, "виды": 2.0}, {"EcoFish": 2.0, "EcoKamen": 12.0}, "мир 20")
	Probe.qa_add(acc, 5.0, {"мир": 3.0}, {}, "")
	eq(acc["n"], 3, "три кадра")
	eq(acc["worst_at"], 1, "худший — второй кадр")
	eq(acc["subs"]["EcoFish"][0], 4.0, "максимум подчасти")
	near(acc["subs"]["EcoFish"][1] / 3.0, 2.0, 1e-6, "среднее по всем кадрам, без подчасти — 0")
	eq(acc["subs"]["EcoKamen"][2], 1, "кадр максимума")
	var lines := Probe.qa_lines(1, acc)
	ok(lines[0].contains("3 кадров") and lines[0].contains("30.0") and lines[0].ends_with("мир 20"), "итог: " + lines[0])
	var kamen := lines.find(lines.filter(func(l): return l.contains("мир/EcoKamen"))[0])
	var fish := lines.find(lines.filter(func(l): return l.contains("мир/EcoFish"))[0])
	ok(kamen >= 0 and kamen < fish, "подчасти — по убыванию максимума")
	ok(lines.any(func(l): return l.contains("виды") and not l.contains("мир/")), "части шага — тоже")
	ok(Probe.qa_lines(1, {})[0].contains("нет кадров"), "пустое окно")


func test_qa_quiet_runner_steps_scene() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var plan := Probe.qa_plan([{"do": "ship", "x": 10, "y": -30, "z": 10}, {"do": "shot", "name": "a"},
		{"do": "wait", "s": 0.5}, {"do": "shot", "name": "b"}], {"from": "a", "to": "b"})
	var q := Probe.QuietRunner.new()
	q.main = main
	q.script_q = QaScript.parse(JSON.stringify(plan["steps"]))
	main.add_child(q)
	main.qa = q
	var n := 0
	for i in 40:
		if q.script_q.index >= plan["w1"]:
			break
		if q.script_q.index >= plan["w0"]:
			n += 1
		main.step(Probe.DT)
	ok(Vector2(main.helm.pos.x - 10, main.helm.pos.z - 10).length() < 2.0, "шаг ship выполнен: %s" % main.helm.pos)
	ok(n >= 14 and n <= 17, "окно — полсекунды кадров: %d" % n)
	main.qa = null
	q.queue_free()
