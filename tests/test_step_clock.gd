extends TestCase
## Части шага игры для лога тестера (issue #627): «код 112 мс» худшего кадра на сканере — что из шага тормозит.


func test_laps_and_top() -> void:
	var c := StepClock.new()
	c.start(1000000, 1.0 / 30.0)
	c.lap("корабль", 1005000)    # 5 мс
	c.lap("мир", 1085000)        # 80 мс
	c.lap("виды", 1105000)       # 20 мс
	c.lap("интерфейс", 1105400)  # 0,4 мс — меньше MIN_MS, не пишем
	c.lap("мир", 1107000)        # то же имя складывается: мир 81,6
	near(c.parts["мир"], 81.6, 1e-6, "части с одним именем складываются")
	eq(c.top(), "мир 82, виды 20, корабль 5", "долгие части по убыванию")
	eq(c.top(1), "мир 82", "сколько частей — n")
	eq(c.note(), "мир 82, виды 20, корабль 5", "обычный шаг времени не пишем")


func test_big_dt_and_restart() -> void:
	var c := StepClock.new()
	c.start(0, 0.2)
	c.lap("мир", 30000)
	eq(c.note(), "мир 30; шаг 200 мс", "большой шаг времени — в подписи: мир дробит его на подшаги")
	c.start(50000, 1.0 / 30.0)
	eq(c.top(), "", "новый шаг — части с нуля")
	c.lap("мир", 40000)
	near(c.parts["мир"], 0.0, 1e-6, "время назад не уходит в минус")


func test_worst_note_with_parts() -> void:
	eq(QaRunner.worst_note("шаг 242 hold", 7.0, 112.0, 2.0, 197.0, "мир 80, виды 20"),
		"шаг 242 hold, код 112 мс (мир 80, виды 20), отрисовка 7 мс, видеокарта 2 мс", "долгий код — с частями")
	eq(QaRunner.worst_note("шаг 5 wait", 7.0, 5.0, 0.0, 30.0, "мир 3"), "шаг 5 wait, код 5 мс, отрисовка 7 мс",
		"короткий код — без частей, как раньше")


func test_scene_step_parts() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.step(1.0 / 30.0)
	for k in ["корабль", "мир", "события мира", "виды", "интерфейс", "метки и сеть"]:
		ok(main.clock.parts.has(k), "часть шага «%s» отмечена: %s" % [k, str(main.clock.parts.keys())])
	near(main.clock.dt, 1.0 / 30.0, 1e-9, "шаг времени запомнен")
	var sum := 0.0
	for k in main.clock.parts:
		sum += float(main.clock.parts[k])
	ok(sum > 0.0, "части шага — не нули: %.2f мс" % sum)
	main.queue_free()
	await frames(1)


## Issue #662: замер кадра идёт внутри нового шага, после `start` — части и шаг времени нужны прошлого шага.
func test_last_step_kept() -> void:
	var c := StepClock.new()
	c.start(0, 0.1)
	c.lap("мир", 40000)
	c.lap("виды", 52000)
	c.start(60000, 1.0 / 30.0)   # новый шаг начался — части прошлого не пропали
	eq(c.note(), "", "у нового шага частей ещё нет")
	eq(c.last_note(), "мир 40, виды 12; шаг 100 мс", "части и шаг времени прошлого шага")
	c.lap("корабль", 65000)
	c.start(70000, 1.0 / 30.0)
	eq(c.last_note(), "корабль 5", "прошлый — это последний законченный шаг")


## Issue #662: в логе тестера «код 68 мс (шаг 100 мс)» без частей — `_measure` читал части нового, пустого шага.
func test_worst_frame_has_last_parts() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var r := QaRunner.new()
	r.main = main
	main.clock.start(0, 0.1)
	main.clock.lap("мир", 50000)        # прошлый шаг: мир 50 мс
	main.step_ms = 60.0
	main.clock.start(60000, 1.0 / 30.0) # новый шаг начался, в нём и идёт замер (qa.tick)
	r._measure(1000000)
	r._measure(1100000)
	ok(r.worst_at.contains("код 60 мс (мир 50; шаг 100 мс)"), "части прошлого шага в подписи: " + r.worst_at)
	r.free()
	main.queue_free()
	await frames(1)


## Issue #745: «интерфейс 45» в худшем кадре — какая из подчастей (подсказки, карточка роли, связь, рация).
func test_sub_parts() -> void:
	var c := StepClock.new()
	c.start(0, 1.0 / 30.0)
	c.lap("мир", 30000)                    # 30 мс
	c.lap("интерфейс/подсказки", 32000)    # 2 мс
	c.lap("интерфейс/связь", 72000)        # 40 мс
	c.lap("интерфейс/рация", 72500)        # 0,5 мс — меньше MIN_MS
	c.lap("интерфейс", 75000)              # 2,5 мс без подчасти — в часть
	near(c.parts["интерфейс"], 45.0, 1e-6, "подчасти и остаток складываются в часть")
	eq(c.note(), "интерфейс 45 [связь 40, подсказки 2], мир 30", "долгая часть — с долгими подчастями")
	c.start(80000, 1.0 / 30.0)
	eq(c.last_note(), "интерфейс 45 [связь 40, подсказки 2], мир 30", "подчасти прошлого шага не пропали")
	c.lap("интерфейс/связь", 85000)
	eq(c.note(), "интерфейс 5", "короткая часть (< SUB_MS) — без подчастей")
	c.start(90000, 1.0 / 30.0)
	c.lap("интерфейс/связь", 90000)
	eq(c.last_note(), "интерфейс 5", "подчасти — свои у каждого шага")


## Issue #745: шаг игры отмечает подчасти интерфейса.
func test_scene_ui_sub_parts() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.step(1.0 / 30.0)
	for k in ["маршрут", "приборы", "подсказки", "карточка роли", "связь", "рация"]:
		ok(main.clock.subs.get("интерфейс", {}).has(k), "подчасть интерфейса «%s»: %s" % [k, str(main.clock.subs)])
	main.queue_free()
	await frames(1)


## Issue #759: `step()` разбит на шаги по системам — части кадра в логе тестера те же, что до разбиения.
func test_main_step_parts() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.step(1.0 / 30.0)
	var parts: Array = main.clock.parts.keys()
	parts.sort()
	var want := ["виды", "интерфейс", "корабль", "метки и сеть", "мир", "события мира"]
	eq(parts, want, "части шага: %s" % [parts])
	var subs: Array = main.clock.subs.get("интерфейс", {}).keys()
	subs.sort()
	eq(subs, ["карточка роли", "маршрут", "подсказки", "приборы", "рация", "связь"], "подчасти интерфейса")
	main.queue_free()
	await frames(1)
