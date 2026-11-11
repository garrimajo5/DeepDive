extends TestCase
## Задача места с действием (#1635): у 07, 03, 08 плашка цели, строка при входе и строка приборов говорят, что делать
## и на каком посту, пока действие не сделано; «ближе N м» по радиусам кода действия; копии радиусов потока Б.

const GATE := Vector2(-100.0, -240.0)


func _lore(keys: Array = []) -> LayerLore:
	var l := LayerLore.new()
	for k in keys:
		l.learn(k)
	return l


## Корабль над гнездом i 07 на 5 м — в радиусе чтения.
func _at_nest(i: int) -> Vector3:
	return GateDiag.nest_pos(i) + Vector3(0, 5, 0)


func test_table_posts_and_done() -> void:
	eq(PlaceTask.TASKS.keys(), ["gate", "shell", "field"], "три места с действием")
	for key in PlaceTask.TASKS:
		ok(Run.PLACES.has(key), "%s — место маршрута" % key)
		ok(ShipMap.CELLS.has(PlaceTask.TASKS[key]["icon"]), "%s: значок поста есть в атласе" % key)
		ok(not PlaceTask.done(key, _lore()), "%s: без знаний не сделано" % key)
	eq(PlaceTask.TASKS["gate"]["icon"], "scanner")
	eq(PlaceTask.TASKS["shell"]["icon"], "scanner", "у 03 — сканер")
	eq(PlaceTask.TASKS["field"]["icon"], "sonar")
	ok(not PlaceTask.done("gate", _lore([LayerLore.D07_RETURN, LayerLore.D07_RELAY])), "07: два гнезда из трёх")
	ok(PlaceTask.done("gate", _lore(LayerLore.DIAGNOSTICS)), "07: все три диагностики")
	ok(PlaceTask.done("shell", _lore([LayerLore.SHELL03])))
	ok(PlaceTask.done("field", _lore([LayerLore.FIELD08])))
	ok(PlaceTask.done("flower", _lore()), "у других мест задачи нет")


func test_radius_copies_match_flow_b() -> void:
	eq(PlaceTask.SHELL_SCAN_R, EcoShell.SCAN_R)
	eq(PlaceTask.SHELL_SCAN_UP, EcoShell.SCAN_UP)
	eq(PlaceTask.FIELD_SEE, EcoField.SEE)
	eq(Run.place_xz("shell"), EcoShell.CENTER, "середина Раковины — место 03")
	eq(Run.place_xz("field"), EcoField.CENTER, "середина поля — место 08")
	eq(Run.place_xz("gate"), EcoGate.CENTER)


func test_text_lengths() -> void:
	var l := _lore()
	for key in PlaceTask.TASKS:
		var ship := Vector3(Run.place_xz(key).x, 0, Run.place_xz(key).y)
		ship.y = Seabed.height(ship.x, ship.z) + 5.0
		var t := "%s · %s" % [Run.place_name(key), PlaceTask.what(key, l)]
		ok(t.length() <= PlaceTask.PLATE_MAX, "%s: плашка «%s» ≤ %d" % [key, t, PlaceTask.PLATE_MAX])
		ok(PlaceTask.line(key).length() <= Run.LINE_MAX, "%s: строка при входе ≤ %d" % [key, Run.LINE_MAX])
		var far := "%s · %s — ближе 99 м" % [Run.place_name(key), PlaceTask.TASKS[key]["post"]]
		ok(far.length() <= PlaceTask.NEAR_MAX, "%s: «%s» ≤ %d" % [key, far, PlaceTask.NEAR_MAX])


func test_gate_plate_counts_and_near() -> void:
	eq(PlaceTask.plate("gate", _at_nest(0), _lore()), "Терраса врат · сканер 0 / 3")
	eq(PlaceTask.plate("gate", _at_nest(1), _lore([LayerLore.D07_RETURN])), "Терраса врат · сканер 1 / 3")
	# у дальнего края круга 07 (40 м к западу) до гнёзд у правой опоры дальше READ_R
	var ship := Vector3(GATE.x - 40.0, 0, GATE.y)
	ship.y = Seabed.height(ship.x, ship.z) + 5.0
	var best := INF
	for i in 3:
		best = minf(best, ship.distance_to(GateDiag.nest_pos(i)))
	ok(best > GateDiag.READ_R, "постановка: гнёзда вне радиуса чтения")
	eq(PlaceTask.plate("gate", ship, _lore()), "Терраса врат · сканер — ближе %d м" % ceili(best - GateDiag.READ_R))


func test_shell_and_field_near() -> void:
	var c := Run.place_xz("shell")
	var low := Vector3(c.x, Seabed.height(c.x, c.y) + 10.0, c.y)
	eq(PlaceTask.plate("shell", low, _lore()), "Раковина древних · сканер и сонар")
	var high := low + Vector3(0, 22.5, 0)
	eq(PlaceTask.plate("shell", high, _lore()), "Раковина древних · сканер — ниже 8 м", "выше SCAN_UP на 7,5 м")
	var side := Vector3(c.x + 40.0, 0, c.y)
	side.y = Seabed.height(side.x, side.z) + 5.0
	eq(PlaceTask.plate("shell", side, _lore()), "Раковина древних · сканер — ближе 10 м")
	var f := Run.place_xz("field")
	eq(PlaceTask.plate("field", Vector3(f.x + 10.0, -30.0, f.y), _lore()), "Наблюдение поля · импульс сонара")
	eq(PlaceTask.plate("field", Vector3(f.x + 43.0, -30.0, f.y), _lore()), "Наблюдение поля · сонар — ближе 3 м")


func test_run_line_on_entry() -> void:
	var r := Run.new()
	r.begin(0.0, 0, 0, 0)
	r.choose(Run.MAIN)
	var l := _lore()
	r.update(Run.place_xz("flower").x, Run.place_xz("flower").y, l)
	eq(r.update(GATE.x, GATE.y, l), PlaceTask.line("gate"), "07 без диагностики — строка задачи")
	ok(r.visited.has("gate"), "точка маршрута засчитана")
	eq(r.update(GATE.x + 1.0, GATE.y, l), "", "строка — один раз на вход")
	eq(r.status(GATE.x, GATE.y, l), "Терраса врат: сканер 0 / 3", "строка приборов — задача")
	l.learn(LayerLore.D07_RETURN)
	eq(r.status(GATE.x, GATE.y, l), "Терраса врат: сканер 1 / 3")
	# с диагностикой — прежняя строка маршрута
	var r2 := Run.new()
	r2.begin(0.0, 0, 0, 0)
	r2.choose(Run.MAIN)
	var all := _lore(LayerLore.DIAGNOSTICS)
	r2.update(Run.place_xz("flower").x, Run.place_xz("flower").y, all)
	eq(r2.update(GATE.x, GATE.y, all), "Точка маршрута пройдена: Терраса врат. Дальше — Раковина древних")
	ok(r2.status(GATE.x, GATE.y, all).begins_with("Путь к спуску 2/5"), "сделано — строка маршрута")


func test_run_task_without_route() -> void:
	var r := Run.new()
	r.begin(0.0, 0, 0, 0)
	var f := Run.place_xz("field")
	eq(r.update(f.x, f.y, _lore()), PlaceTask.line("field"), "без маршрута — строка задачи тоже")
	eq(r.status(f.x, f.y, _lore()), "Наблюдение поля: импульс сонара")
	eq(r.update(f.x + 200.0, f.y, _lore()), "", "вышел — молча")
	eq(r.status(f.x, f.y), "", "без знаний (lore = null) — как раньше")


func test_goal_plate_task_then_learned() -> void:
	var r := Run.new()
	r.begin(0.0, 0, 0, 0)
	r.choose(5)   # «Поле у врат»: gate, field
	var l := _lore()
	var p := GoalPlate.new()
	var at := _at_nest(0)
	var xz := Vector2(at.x, at.z)
	p.update(0.1, r, 0.0, Vector2(GATE.x, GATE.y + 300.0), l, -30.0)
	ok(p.kind != GoalPlate.Kind.TASK, "вдали — цель, не задача")
	r.update(xz.x, xz.y, l)
	p.update(0.1, r, 0.0, xz, l, at.y)
	eq(p.kind, GoalPlate.Kind.ARRIVED, "сначала «на месте»")
	p.update(GoalPlate.ARRIVED_TIME, r, 0.0, xz, l, at.y)
	eq(p.kind, GoalPlate.Kind.TASK)
	eq(p.text, "Терраса врат · сканер 0 / 3")
	eq(p.task_icon(), "scanner")
	ok(p.has_icon())
	l.learn(LayerLore.D07_RETURN)
	p.update(0.1, r, 0.0, xz, l, at.y)
	eq(p.text, "Терраса врат · сканер 1 / 3")
	l.learn(LayerLore.D07_RELAY)
	l.learn(LayerLore.D07_AUTH)
	p.update(0.1, r, 0.0, xz, l, at.y)
	eq(p.kind, GoalPlate.Kind.ARRIVED, "все три — «узнано»")
	eq(p.text, "Терраса врат — узнано")
	eq(p.edge(), GoalPlate.AMBER)
	p.update(GoalPlate.ARRIVED_TIME, r, 0.0, xz, l, at.y)
	ok(p.text.contains("Наблюдение поля ·"), "затем следующая цель: «%s»" % p.text)
	ok(p.kind in [GoalPlate.Kind.AHEAD, GoalPlate.Kind.LEFT, GoalPlate.Kind.RIGHT, GoalPlate.Kind.BEHIND])
	eq(p.task_icon(), "")


func test_goal_plate_leaves_circle_silently() -> void:
	var r := Run.new()
	r.begin(0.0, 0, 0, 0)
	var l := _lore()
	var p := GoalPlate.new()
	var f := Run.place_xz("field")
	p.update(0.1, r, 0.0, f, l, -30.0)
	eq(p.kind, GoalPlate.Kind.TASK, "без маршрута — задача сразу")
	eq(p.task_icon(), "sonar")
	p.update(0.1, r, 0.0, f + Vector2(200, 0), l, -30.0)
	eq(p.kind, GoalPlate.Kind.NONE, "ушёл, не сделав, — молча к прежнему виду")
