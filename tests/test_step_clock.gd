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
