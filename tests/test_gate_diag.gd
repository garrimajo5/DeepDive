extends TestCase
## Диагностика 07 с борта (#826, часть 1): три гнезда — три факта в любом порядке, повтор не новый, без купольника
## доступна, коды не чинят питание.

const OVER := Vector3(-100.0, -35.0, -240.0)   ## корабль над серединой террасы 07 на 35 м


func _read_all(g: GateDiag, lore: LayerLore, ship: Vector3) -> String:
	g.aim(ship, lore)
	var f := g.fact()
	for i in int(GateDiag.READ_TIME * 30.0) + 2:
		g.hold(1.0 / 30.0, lore)
		g.update(1.0 / 30.0)
	return f


func test_nests_on_terrace_bottom() -> void:
	for i in GateDiag.NESTS.size():
		var p := GateDiag.nest_pos(i)
		near(p.y, Seabed.height(p.x, p.z), 1e-3, "гнездо %d на дне" % i)
		ok(Vector2(p.x, p.z).distance_to(EcoGate.CENTER) < EcoGate.POCKET, "гнездо %d в кармане арки, обвязка дальше" % i)
		ok(OVER.distance_to(p) < GateDiag.READ_R, "с 35 м над серединой гнездо %d читается" % i)
	var facts: Array = GateDiag.NESTS.map(func(n): return n["fact"])
	facts.sort()
	var want := LayerLore.DIAGNOSTICS.duplicate()
	want.sort()
	eq(facts, want, "у каждого факта диагностики своё гнездо")


func test_far_away_no_target() -> void:
	var g := GateDiag.new()
	var lore := LayerLore.new()
	g.aim(Vector3(0.0, -30.0, 95.0), lore)
	ok(not g.active(), "у старта гнезда не в прицеле")
	g.hold(5.0, lore)
	ok(lore.facts.is_empty(), "удержание вдали ничего не читает")


func test_three_facts_separately_any_order() -> void:
	for order in [[0, 1, 2], [2, 0, 1], [1, 2, 0]]:
		var g := GateDiag.new()
		var lore := LayerLore.new()
		var got: Array[String] = []
		g.read.connect(func(f: String) -> void: got.append(f))
		for i: int in order:
			var p := GateDiag.nest_pos(i)
			var f := _read_all(g, lore, Vector3(p.x, -35.0, p.z))   # над гнездом — оно ближе всех
			eq(f, GateDiag.NESTS[i]["fact"], "над гнездом %d в прицеле оно" % i)
			eq(got.size(), lore.facts.size(), "факт приходит один, сразу после чтения")
		var want: Array[String] = []
		for i: int in order:
			want.append(GateDiag.NESTS[i]["fact"])
		eq(got, want, "три факта по отдельности, в порядке чтения %s" % str(order))
		eq(lore.unread_diagnostics(), [] as Array[String], "все три прочитаны")


func test_one_read_takes_time() -> void:
	var g := GateDiag.new()
	var lore := LayerLore.new()
	g.aim(OVER, lore)
	ok(g.active(), "над серединой — гнездо в прицеле")
	g.hold(GateDiag.READ_TIME * 0.5, lore)
	eq(lore.facts.size(), 0, "полвремени — ещё перевод")
	ok(g.label(lore).begins_with("Перевод "), g.label(lore))
	g.update(0.1)
	g.update(GateDiag.READ_TIME)   # отпустил надолго — прогресс спал
	eq(g.progress, 0.0, "без удержания перевод спадает")


func test_unread_nest_preferred() -> void:
	var g := GateDiag.new()
	var lore := LayerLore.new()
	var first := _read_all(g, lore, OVER)
	g.aim(OVER, lore)
	ok(g.fact() != first, "с того же места прицел берёт непрочитанное гнездо")


func test_repeat_visit_not_new() -> void:
	var g := GateDiag.new()
	var lore := LayerLore.new()
	for i in 3:
		_read_all(g, lore, OVER)
	var saved := lore.snapshot()
	var again := LayerLore.new()
	again.apply(saved)   # загрузка: знания из файла
	var g2 := GateDiag.new()
	var got := []
	g2.read.connect(func(f: String) -> void: got.append(f))
	_read_all(g2, again, OVER)
	eq(got, [], "повторный визит новых фактов не даёт")
	g2.aim(OVER, again)
	eq(g2.label(again), "Гнездо 07 · прочитано", "прочитанное так и подписано")
	eq(g2.press_text(again), GateDiag.TEXT[g2.fact()], "нажатие повторяет перевод")


func test_creature_closer_keeps_scanner() -> void:
	var g := GateDiag.new()
	var lore := LayerLore.new()
	g.aim(OVER, lore, 5.0)
	ok(not g.active(), "существо в 5 м — сканер на нём")
	g.aim(OVER, lore, 200.0)
	ok(g.active(), "существо дальше гнезда — переводим гнездо")


func test_codes_do_not_fix_power() -> void:
	var codes := GateDiag.effect(GateDiag.Act.CODES)
	eq(codes, [LayerLore.AUTH07] as Array[String], "коды — только авторизация этого терминала")
	ok(not codes.has(LayerLore.D07_RELAY), "питание ретранслятора кодами не чинится")
	eq(GateDiag.effect(GateDiag.Act.POWER), [] as Array[String], "ремонта питания в слое 1 нет")
	var g := GateDiag.new()
	var lore := LayerLore.new()
	for i in 3:
		_read_all(g, lore, OVER)
	ok(not lore.knows(LayerLore.AUTH07), "диагностика сама не авторизует")


func test_scene_scanner_reads_gate() -> void:   # без купольника: створку никто не открывал
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.helm.pos = OVER
	main.helm.speed = 0.0
	main.walker.x = 3.85   # у поста «Сканер»
	main.walker.z = -2.0
	main.step(1.0 / 30.0)
	main.step(1.0 / 30.0)
	ok(main.gate.active(), "у 07 сканер берёт гнездо: цель %s" % str(main.scanner.target.get("species", "")))
	ok(main.bridge.scanner_text.text.begins_with("ДИАГНОСТИКА 07"), main.bridge.scanner_text.text)
	var r := main.overlay.router
	r.begin(5, r.layout.action.c)
	for i in int(GateDiag.READ_TIME * 30.0) + 5:
		main.step(1.0 / 30.0)
	r.end(5)
	main.step(1.0 / 30.0)
	eq(main.lore.facts.size(), 1, "держали больше READ_TIME — один факт")
	ok(main.message.text.begins_with("Диагностика 07: "), main.message.text)
	ok(main.bridge.scanner_text.text.contains(GateDiag.SHORT[main.lore.facts[0]]), "перевод на экране мостика")
	eq(main.scanner.scanned.size(), 0, "вид при этом не сканировали")
	main.queue_free()
	await frames(1)
