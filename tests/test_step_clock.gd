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
	eq(c.note(), "интерфейс 45 [связь 40, подсказки 2, без отметки 3], мир 30", "долгая часть — с долгими подчастями")
	c.start(80000, 1.0 / 30.0)
	eq(c.last_note(), "интерфейс 45 [связь 40, подсказки 2, без отметки 3], мир 30", "подчасти прошлого шага не пропали")
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
	eq(subs, ["карточка роли", "маршрут", "подсказки", "приборы", "рация", "связь", "цель маршрута"], "подчасти интерфейса")
	var views: Array = main.clock.subs.get("виды", {}).keys()   # отчёт #1182: «виды 57» у колодца 05 — что внутри
	views.sort()
	eq(views, ["голограммы", "корабль и камера", "отсеки и экраны", "ползунки и люк", "свет", "экипаж", "экипаж: сборка",
		"экипаж: снаряжение"], "подчасти видов")
	near(float(main.clock.parts["виды"]), _sum(main.clock.subs["виды"]), 0.001, "виды — ровно сумма подчастей")
	var world: Dictionary = main.clock.subs.get("мир", {})   # #1020: модули и виды живого мира
	ok(world.has("существа") and world.has("связь") and world.has("вид: рыбы, хищники") \
		and world.has("вид: планктон, эхо, дальние"), "подчасти мира: %s" % [world.keys()])
	ok(world.size() > 10, "модули мира по именам: %d" % world.size())
	main.queue_free()
	await frames(1)


## Issue #1020: «мир 78» в худшем кадре не говорит, что внутри. Живой мир отмечает подчасти в идущем шаге
## (`StepClock.active`), не зная `Main`: модуль мира по имени класса и существа.
func test_world_marks_subparts() -> void:
	var c := StepClock.new()
	c.start(Time.get_ticks_usec())
	ok(StepClock.active == c, "идущий шаг — последний start")
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return -40.0
	w.ship.pos = Vector3(500, -10, 500)
	w.add(EcoPred.new())
	w.step(0.2)
	c.lap("мир", Time.get_ticks_usec())
	var of: Dictionary = c.subs.get("мир", {})
	ok(of.has("существа"), "подчасть «существа» — шаг агентов")
	ok(of.has("EcoPred"), "подчасть модуля по имени его класса")
	ok(c.parts.has("мир") and not c.parts.has("EcoPred"), "подчасти идут в часть «мир», отдельной части нет")
	StepClock.active = null
	StepClock.mark("мир/ничего")   # без идущего шага — тихо
	ok(not c.subs["мир"].has("ничего"), "без идущего шага отметка ничего не пишет")


## Issue #1020: «мир 91 [EcoFringe 15, EcoFish 13]» — 63 мс «мира» не видно; прочие подчасти идут одной суммой.
func test_sub_rest() -> void:
	var c := StepClock.new()
	c.start(0, 0.093)
	var t := 0
	for p in [["EcoFringe", 15], ["EcoFish", 13], ["существа", 9], ["EcoDome", 7], ["EcoCoins", 6], ["связь", 5]]:
		t += int(p[1]) * 1000
		c.lap("мир/" + p[0], t)
	c.lap("мир", t + 4000)   # 4 мс «мира» вне подчастей
	near(c.parts["мир"], 59.0, 1e-6, "мир — сумма подчастей и остатка")
	eq(c.note(), "мир 59 [EcoFringe 15, EcoFish 13, существа 9, ещё 3: 18, без отметки 4]; шаг 93 мс",
		"три долгие подчасти, остальные одной суммой и время вне отметок")
	c.start(t + 4000, 0.03)
	c.lap("мир/EcoFish", t + 16000)
	c.lap("мир/связь", t + 16200)
	eq(c.note(), "мир 12 [EcoFish 12]", "короткий остаток (< MIN_MS) не пишем")


## Issue #1020: импульс сонара и события мира — свои подчасти «мира», не в «существах» и не в первой группе видов.
func test_scene_world_sub_parts() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.eco_ship.sonar_ping = true
	main.step(1.0 / 30.0)
	var w: Dictionary = main.clock.subs.get("мир", {})
	for k in ["события", "существа", "связь"]:
		ok(w.has(k), "подчасть мира «%s»: %s" % [k, str(w.keys())])
	main.queue_free()
	await frames(1)


## Issue #1020: «мир 113 [… ещё 43: 61]» — виновник или весь шаг разом медленнее. Худший кадр сравнивается
## с обычным временем частей: долгая часть — «обычно N», подчасти — «×N».
func test_usual_times() -> void:
	var c := StepClock.new()
	var t := 0
	for i in StepClock.USUAL_FROM + 2:   # обычные шаги: мир 12 = EcoFish 3 + EcoKelp 2 + 4 модуля по 1 + 3 вне отметок
		c.start(t, 1.0 / 30.0)
		for p in [["EcoFish", 3], ["EcoKelp", 2], ["a", 1], ["b", 1], ["c", 1], ["d", 1]]:
			t += int(p[1]) * 1000
			c.lap("мир/" + p[0], t)
		t += 3000
		c.lap("мир", t)
	ok(c.usual_ready(), "обычное время готово")
	near(c.usual["мир"], 12.0, 1e-3, "обычный мир")
	c.start(t, 1.0 / 30.0)   # всплеск: EcoFish ×10, прочие ×2
	for p in [["EcoFish", 30], ["EcoKelp", 4], ["a", 2], ["b", 2], ["c", 2], ["d", 2]]:
		t += int(p[1]) * 1000
		c.lap("мир/" + p[0], t)
	t += 3000
	c.lap("мир", t)
	c.start(t, 1.0 / 30.0)
	eq(c.last_note(), "мир 45 (обычно 12) [EcoFish 30 ×10, EcoKelp 4 ×2, a 2 ×2, ещё 3: 6 ×2, без отметки 3]",
		"всплеск — с обычным временем, виновник ×10 среди ×2")
	near(c.usual["мир"], 12.0, 1e-3, "худший шаг ещё не в среднем — сравнивается не с собой")


func test_usual_not_before_warm() -> void:
	var c := StepClock.new()
	c.start(0, 1.0 / 30.0)
	c.lap("мир/EcoFish", 30000)
	c.start(30000, 1.0 / 30.0)
	eq(c.last_note(), "мир 30 [EcoFish 30]", "мало шагов — без «обычно»")
	eq(StepClock.slower(5.0, 0.05), "", "обычное ~0 — подчасть по событию, без ×")
	eq(StepClock.slower(3.0, 2.0), "", "меньше SLOW раз — без ×")
	eq(StepClock.slower(9.0, 2.0), " ×5", "×N округляется")


## Обычный шаг мира: EcoFish 3, EcoKelp 2, EcoVent 1, a 1, b 1 — и всё (#1174).
func _warm_world(c: StepClock, t: int) -> int:
	for i in StepClock.USUAL_FROM + 2:
		c.start(t, 1.0 / 30.0)
		for p in [["EcoFish", 3], ["EcoKelp", 2], ["EcoVent", 1], ["a", 1], ["b", 1]]:
			t += int(p[1]) * 1000
			c.lap("мир/" + p[0], t)
	return t


## Issue #1174: в провале эмулятора раздуты все подчасти разом (даже EcoVent в три строки) — лог говорит «заминка»,
## а не ищет вид-виновник; один виновник среди ×1–×2 — без «заминки».
func test_stall_all_parts_at_once() -> void:
	var c := StepClock.new()
	var t := _warm_world(c, 0)
	c.start(t, 1.0 / 30.0)   # всё ×12 разом
	for p in [["EcoFish", 36], ["EcoKelp", 24], ["EcoVent", 12], ["a", 12], ["b", 12]]:
		t += int(p[1]) * 1000
		c.lap("мир/" + p[0], t)
	c.start(t, 1.0 / 30.0)
	eq(c.last_note(), "мир 96 (обычно 8) [EcoFish 36 ×12, EcoKelp 24 ×12, EcoVent 12 ×12, ещё 2: 24 ×12]"
		+ " — разом ×12, заминка", "все подчасти ×12 — заминка машины")
	c.start(t, 1.0 / 30.0)   # виновник: EcoFish ×20, прочие как обычно
	for p in [["EcoFish", 60], ["EcoKelp", 2], ["EcoVent", 1], ["a", 1], ["b", 1]]:
		t += int(p[1]) * 1000
		c.lap("мир/" + p[0], t)
	c.start(t, 1.0 / 30.0)
	ok(not c.last_note().contains("заминка"), "один виновник — не заминка: " + c.last_note())
	eq(StepClock.stall({"a": 12.0, "b": 12.0}, {"a": 1.0, "b": 1.0}), 0, "две подчасти — мало для вывода")
	eq(StepClock.stall({"a": 12.0, "b": 12.0, "c": 12.0}, {"a": 1.0, "b": 1.0, "c": 0.01}), 0,
		"подчасть по событию (обычное ~0) не считается — осталось две")


## Отчёт тестера `2026-11-05-0315` (#1253, `33a-kondensat-krasivo`, шаг 133 мс): после #1255 мир за кадр идёт
## одним подшагом ≤ `EcoWorld.SLOW_STEP`, остаток — в долг. Порог заминки ещё умножали на два подшага долгого шага
## (×10), и «флора ×7, EcoPred ×6, EcoCoins ×15» не отмечались заминкой — разбор искал виновника в мире.
func test_stall_long_step_one_world_substep() -> void:
	var x7 := {"a": 7.0, "b": 6.0, "c": 15.0}
	var one := {"a": 1.0, "b": 1.0, "c": 1.0}
	eq(StepClock.stall(x7, one), 7, "медиана ×7 — заминка, какой бы долгий ни был шаг")
	eq(StepClock.stall({"a": 4.0, "b": 4.0, "c": 4.0}, one), 0, "×4 — меньше STALL_K — не заминка")
	var c := StepClock.new()
	var t := _warm_world(c, 0)
	c.start(t, 0.133)
	for p in [["EcoFish", 56], ["EcoKelp", 42], ["EcoVent", 7], ["a", 7], ["b", 7]]:
		t += int(p[1]) * 1000
		c.lap("мир/" + p[0], t)
	c.start(t, 1.0 / 30.0)
	ok(c.last_note().ends_with("— разом ×7, заминка; шаг 133 мс"), "шаг 133 мс, всё ×7 — заминка: " + c.last_note())
	c.start(t, 0.133)   # виновник в долгом шаге: EcoFish ×20, прочие как обычно
	for p in [["EcoFish", 80], ["EcoKelp", 3], ["EcoVent", 1], ["a", 1], ["b", 1]]:
		t += int(p[1]) * 1000
		c.lap("мир/" + p[0], t)
	c.start(t, 1.0 / 30.0)
	ok(not c.last_note().contains("заминка"), "один виновник в долгом шаге — не заминка: " + c.last_note())


## Отчёт тестера `2026-11-05-0415` (#1253, `32o-mol-steklo`): «мир 230 (обычно 16) [EcoFish 79 ×40, рыбы 21 ×11,
## EcoDome 19 ×41, ещё 43: 111 ×10]» — раздуто всё, но медиану тянули вниз мелкие подчасти ×2, и заминка не
## отмечалась. Без двух самых долгих остальные вместе ×N — это заминка; два виновника среди ×1 — нет.
func test_stall_by_rest_sum() -> void:
	var sub := {"EcoFish": 79.0, "рыбы": 21.0, "EcoDome": 19.0}
	var us := {"EcoFish": 2.0, "рыбы": 2.0, "EcoDome": 0.46}
	for i in 5:
		sub["big%d" % i] = 18.0
		us["big%d" % i] = 1.5
	for i in 10:
		sub["small%d" % i] = 0.4
		us["small%d" % i] = 0.2
	ok(StepClock.stall(sub, us) >= int(StepClock.STALL_K), "остальные вместе ×11 — заминка: %d" % StepClock.stall(sub, us))
	var two := {"EcoFish": 80.0, "EcoKelp": 40.0, "a": 1.0, "b": 1.0, "c": 1.2}
	var one := {"EcoFish": 2.0, "EcoKelp": 2.0, "a": 1.0, "b": 1.0, "c": 1.0}
	eq(StepClock.stall(two, one), 0, "два виновника, остальные как обычно — не заминка")
	eq(StepClock.rest_stall({"a": 50.0, "b": 50.0, "c": 50.0}, {"a": 1.0, "b": 1.0, "c": 1.0}), 0,
		"без двух долгих осталась одна подчасть — мало для вывода")


## Отчёт тестера `2026-11-08-1715` (#1317, `32h-rakovina-osmotr`): «мир 51 (обычно 10) [EcoKelp 9 ×24, EcoCoins 9
## ×44, EcoGrazer 9 ×80, ещё 44: 24 ×3]» — три несвязанных модуля по 9 мс разом, остальные ×3, и заминка не
## отмечалась: тестер снова искал виновника в мире. Три подчасти ×10 и дольше в кадре без импульса — заминка, весь
## замер ×6; в кадре импульса или с двумя такими — нет.
func test_stall_three_spikes() -> void:
	var sub := {"EcoKelp": 9.0, "EcoCoins": 9.0, "EcoGrazer": 9.0}
	var us := {"EcoKelp": 0.375, "EcoCoins": 0.2, "EcoGrazer": 0.11}
	for i in 44:
		sub["m%d" % i] = 24.0 / 44.0
		us["m%d" % i] = 8.0 / 44.0
	eq(StepClock.rest_stall(sub, us), 0, "по сумме остальных — ×4, раньше заминки не было")
	eq(StepClock.stall(sub, us), 6, "три модуля ×24…×80 разом — заминка, весь мир ×6")
	var ping := sub.duplicate()
	ping[StepClock.PING_MARK] = 0.5
	var ping_us := us.duplicate()
	ping_us[StepClock.PING_MARK] = 0.2
	eq(StepClock.stall(ping, ping_us), 0, "в кадре импульса модули вправе дорожать разом — не заминка")
	var two := sub.duplicate()
	two["EcoGrazer"] = 0.2
	eq(StepClock.stall(two, us), 0, "два виновника — не заминка")


static func _sum(of: Dictionary) -> float:
	var t := 0.0
	for k in of:
		t += float(of[k])
	return t


## Issue #1518: «экипаж 37 ×35» на итоге забега — пересборка фигуры, снаряжение или поза. Сборка — своей подчастью,
## отметки вне шага игры (новый товарищ, прогрев) в законченный шаг не ложатся.
func test_crew_sub_parts() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var mate := main.add_mate(0.9, -2.3, 90.0, Crew.Role.ENGINEER, 0)
	main.step(1.0 / 30.0)
	main.step(1.0 / 30.0)
	var idle: float = main.clock.subs["виды"]["экипаж: сборка"]
	mate.look = 1   # внешность сменилась — фигура пересобирается в этом шаге
	main.step(1.0 / 30.0)
	var views: Dictionary = main.clock.subs.get("виды", {})
	ok(views.has("экипаж: сборка") and views.has("экипаж: снаряжение"), "подчасти экипажа: %s" % [views.keys()])
	ok(float(views["экипаж: сборка"]) > idle * 10.0 and float(views["экипаж: сборка"]) > 0.5,
		"пересборка фигуры — в своей подчасти: %.3f мс (без смены — %.3f): %s" % [views["экипаж: сборка"], idle, views])
	var before := _sum(views)
	main.crew_view.apply()   # вне шага — без отметок
	eq(_sum(main.clock.subs["виды"]), before, "вне шага подчасти не растут")
	main.queue_free()
	await frames(1)
