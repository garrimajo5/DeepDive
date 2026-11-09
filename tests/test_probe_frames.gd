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
