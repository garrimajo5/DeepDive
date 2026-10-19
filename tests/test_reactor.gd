extends TestCase
## Реактор и пульт энергии (js/power.js): доли, сила систем, перегрев, аварийный сброс.


func test_defaults_and_k() -> void:
	var r := Reactor.new()
	eq(r.used(), 100, "по умолчанию всё роздано")
	near(r.k(Reactor.Sys.ENGINES), 1.0, 1e-9, "базовая доля — сила 1")
	r.set_share(Reactor.Sys.ENGINES, 0)
	near(r.k(Reactor.Sys.ENGINES), 0.0, 1e-9, "обесточены")


func test_set_rounds_and_limits() -> void:
	var r := Reactor.new()
	eq(r.set_share(Reactor.Sys.ENGINES, 47), 30, "свободных нет — больше не дать")
	r.set_share(Reactor.Sys.ZAP, 0)
	eq(r.free_units(), 15, "сняли разряд — 15 свободно")
	eq(r.set_share(Reactor.Sys.ENGINES, 47), 45, "округление до 5 и не больше свободных")
	r.set_share(Reactor.Sys.LAMP, 0)
	r.set_share(Reactor.Sys.SONAR, 0)
	eq(r.set_share(Reactor.Sys.ENGINES, 100), 60, "не больше 60 на систему")


func test_overheat_scram_and_cool() -> void:
	var r := Reactor.new()
	var msgs: Array[String] = []
	r.message.connect(func(t: String, _x: String) -> void: msgs.append(t))
	r.start_hot(false)
	eq(r.limit(), 60, "при перегреве безопасно 60")
	for i in 2000:
		r.update(0.05, false)
		if r.scram > 0.0:
			break
	ok(r.scram > 0.0, "100 при пределе 60 — дошло до аварийного сброса")
	near(r.k(Reactor.Sys.ENGINES), 0.0, 1e-9, "при сбросе всё обесточено")
	ok(r.alert().begins_with("АВАРИЙНЫЙ СБРОС"), r.alert())
	for i in 400:
		r.update(0.05, false)
	ok(r.scram == 0.0 and msgs.has("Реактор перезапущен"), "через 12 с перезапуск")
	for s in [Reactor.Sys.ZAP, Reactor.Sys.LAMP]:
		r.set_share(s, 0)
	r.set_share(Reactor.Sys.LIFE, 10)
	ok(r.used() <= 60, "урезали нагрузку до %d" % r.used())
	for i in 3000:
		r.update(0.05, false)
		if not r.hot:
			break
	ok(not r.hot and msgs.has("Реактор остыл"), "остыл")


func test_vent_starts_overheat() -> void:
	var r := Reactor.new()
	ok(Reactor.near_vent(-126, 60), "у курильщика")
	ok(not Reactor.near_vent(0, 95), "на старте далеко")
	r.update(0.1, true)
	ok(r.hot, "у курильщика перегрев сразу")


func test_console_nav_and_repeat() -> void:
	var r := Reactor.new()
	var c := Reactor.Console.new()
	c.nav(r, Vector2i(0, -1), 0.0)
	eq(c.sel, 1, "вниз — сонар")
	c.nav(r, Vector2i.ZERO, 0.1)
	eq(c.nav(r, Vector2i(-1, 0), 0.0), -5, "влево — снять 5")
	eq(c.nav(r, Vector2i(-1, 0), 0.2), 0, "держим — повтор не сразу")
	eq(c.nav(r, Vector2i(-1, 0), 0.25), -5, "через 0,4 с — повтор")
	eq(r.share[Reactor.Sys.SONAR], 10, "сонар 10")


func test_scene_power_panel_drives_engines() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.reactor.set_share(Reactor.Sys.ZAP, 0)
	main.walker.x = -3.9
	main.walker.z = -2.0
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	r.end(1)
	main.step(0.1)
	ok(main.at_power, "у пульта")
	r.begin(2, r.layout.pad.c + Vector2(r.layout.pad.r * 0.7, 0))   # вправо: двигатели +5, держим
	for i in 20:
		main.step(0.1)
	r.end(2)
	eq(main.reactor.share[Reactor.Sys.ENGINES], 45, "двигатели подняли до 45 (весь резерв)")
	var s0: float = main.bridge.sliders[0].position.y
	ok(s0 > main.bridge.sliders[1].position.y, "ползунок двигателей выше")
	main.walker.x = 0.0
	main.walker.z = Deck.STAND_Z
	main.close_power()
	main.sit_at_helm()
	main.helm.in_thrust = 1.0
	r.begin(3, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))
	for i in 600:
		main.step(1.0 / 30.0)
	r.end(3)
	near(main.helm.speed, Helm.Ship.FORWARD * 1.5 / Helm.Ship.DRAG, 0.05, "тяга ×1,5 — полный ход 10 м/с")
