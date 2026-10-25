extends TestCase
## Товарищ держит кнопку действия (`Crew.Pad.hold`): варит пробоину, держит вентиль, сканер — как свой игрок.
## «Чините пробоины вместе» (ART-046): без этого гость сети только нажимал, но не мог держать.

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


func after() -> void:
	main.queue_free()
	await frames(1)


func test_pad_hold_goes_over_net() -> void:
	var p := Crew.Pad.new()
	p.hold = true
	var s := p.snapshot()
	ok(s.get("hold", false), "в снимке ввода")
	var q := Crew.Pad.new()
	q.apply(s)
	ok(q.hold, "хост принял удержание")
	s["hold"] = false
	q.apply(s)
	ok(not q.hold, "отпустил — не держит (это состояние, а не нажатие)")
	q.hold = true
	q.clear()
	ok(not q.hold, "clear отпускает")


func test_mate_welds_breach() -> void:
	main.open_breach(0)
	var s: Breach.Spot = main.breach.all[0]
	main.walker.x = 3.0   # свой игрок далеко — варит только товарищ
	main.walker.z = 0.5
	var m := main.add_mate(s.at.x, s.at.y, 0.0, Crew.Role.ENGINEER, 0)
	m.walker.x = s.at.x
	m.walker.z = s.at.y
	main.step(0.1)
	eq(main.breach.weld, 0.0, "не держит — шов не растёт")
	ok(not m.welding(), "резака нет")
	m.pad.hold = true
	for i in 10:
		main.step(0.1)
	ok(main.breach.weld > 0.2, "товарищ варит: %.2f" % main.breach.weld)
	ok(m.welding(), "резак у товарища")
	ok(not main.me.welding() and not main.visor.visible, "свой экран не затемнён — варит не он")
	ok(main.breach_view.spark_mm.visible, "искры летят")
	m.pad.hold = false
	var w := main.breach.weld
	main.step(0.1)
	eq(main.breach.weld, w, "отпустил — шов стоит")
	ok(not m.welding(), "резак убрал")


func test_mate_and_me_weld_not_twice_faster() -> void:
	main.open_breach(0)
	var s: Breach.Spot = main.breach.all[0]
	main.walker.x = s.at.x
	main.walker.z = s.at.y
	var m := main.add_mate(s.at.x, s.at.y, 0.0, Crew.Role.ENGINEER, 0)
	m.walker.x = s.at.x
	m.walker.z = s.at.y
	main.step(0.0)   # место поста «Сварка» встало к пробоине
	m.pad.hold = true
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	main.step(0.1)
	near(main.breach.weld, 0.1 * Breach.WELD_RATE, 1e-4, "двое у одного шва — скорость одна")
	r.end(1)
	main.step(0.0)


func test_busy_mate_does_not_weld() -> void:   # сидит за штурвалом — его удержание не варит
	main.open_breach(0)
	var m := main.add_mate(0.0, Deck.SEAT_Z, 0.0, Crew.Role.PILOT, 0, true)
	m.pad.hold = true
	main.step(0.1)
	eq(main.breach.weld, 0.0, "занятый постом не держит")


func test_mate_holds_valve() -> void:
	main.reactor.start_hot(false)
	main.reactor.heat = 70.0
	var m := main.add_mate(EngineRoom.VALVE_POST.x, EngineRoom.VALVE_POST.y, 0.0, Crew.Role.ENGINEER, 0)
	m.walker.x = EngineRoom.VALVE_POST.x
	m.walker.z = EngineRoom.VALVE_POST.y
	m.pad.hold = true
	for i in 30:
		main.step(1.0 / 30.0)
	ok(main.engine.venting, "пар идёт")
	ok(main.reactor.heat < 70.0 - 2.0, "товарищ держит — реактор остывает (%.1f°)" % main.reactor.heat)
	ok(m.hands[0].is_finite() and m.hands[1].is_finite(), "руки на маховике")
	m.pad.hold = false
	main.step(1.0 / 30.0)
	ok(not main.engine.venting, "отпустил — пар не идёт")
	ok(not m.hands[0].is_finite(), "руки свободны")


func test_mate_at_scanner_gets_targets() -> void:   # мир шлёт цели и товарищу у сканера
	var post: Deck.Post = Deck.posts()[2]
	eq(post.id, "scanner", "третий пост — сканер")
	var m := main.add_mate(post.at.x, post.at.y, -PI / 2.0, Crew.Role.BIOLOGIST, 1)
	m.walker.x = post.at.x
	m.walker.z = post.at.y
	main.walker.x = 0.0
	main.walker.z = 0.5
	main.step(0.1)
	ok(main.at_scanner, "сканер ищет цели")
	near(main.eco_ship.scan_range, Scanner.RANGE, 1e-6, "мир шлёт цели в радиусе сканера")
	m.pad.hold = true
	main.step(0.1)
	ok(m.hands[0].is_finite() or m.hands[1].is_finite(), "руки на сканере")
