extends TestCase
## Разряд по корпусу: стоимость, радиус от доли, откат, живой мир узнаёт о разряде.


func test_fire_rules() -> void:
	var z := Zap.new()
	var v := Vitals.new()
	eq(z.fire(0.0, 0.0, v), "Разряд обесточен", "без доли нет")
	eq(z.fire(0.0, 1.0, v), "Разряд по корпусу", "разряд")
	near(v.energy, 85.0, 1e-6, "−15 единиц")
	near(z.radius, 20.0, 1e-6, "20 м при штатной доле")
	eq(z.fire(1.0, 1.0, v), "Разряд копится", "откат 2 с")
	v.energy = 10.0
	ok(z.fire(5.0, 2.0, v).begins_with("Мало энергии"), "мало заряда")
	v.energy = 50.0
	z.fire(9.0, 2.0, v)
	near(z.radius, 40.0, 1e-6, "доля ×2 — радиус ×2")
	ok(z.flicker > 0.0, "свет мигает")
	z.update(1.0)
	near(z.flicker, 0.0, 1e-9, "и перестаёт через 0,8 с")


class ZapEco:
	extends EcoView
	var zapped := false
	var radius := 0.0

	func step(_dt: float, ship: EcoLink.ShipState) -> Array[Dictionary]:
		if ship.zap:
			zapped = true
			radius = ship.zap_radius
		return []


func test_scene_lever() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var fake := ZapEco.new()
	main.eco.queue_free()
	main.eco = fake
	main.add_child(fake)
	main.walker.x = Zap.POST_AT.x
	main.walker.z = Zap.POST_AT.y
	main.step(0.1)
	eq(main.overlay.action_label, "Разряд", "у рычага — кнопка «Разряд»")
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	r.end(1)
	main.step(0.1)
	ok(fake.zapped, "живой мир узнал о разряде")
	near(fake.radius, 20.0, 1e-6, "радиус 20 м")
	ok(not main.eco_ship.zap, "разряд — один шаг")
	ok(main.bridge.zap_lever.rotation.x > 0.5, "рычаг опущен")
	ok(main.zap_light.visible, "вспышка за бортом")
	near(main.vitals.energy, 100.0 - 15.0, 0.5, "заряд потрачен")
	for i in 10:
		main.step(0.1)
	ok(main.bridge.zap_lever.rotation.x == 0.0 and not main.zap_light.visible, "через секунду всё вернулось")


## Issue #50: первый разряд не должен собирать шейдеры — вспышка горит почти без света первые шаги после старта.
func test_scene_light_warmup() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	ok(main.zap_light.visible, "при старте вспышка включена — шейдеры со светом соберутся сразу")
	ok(main.zap_light.light_energy < 0.01, "но почти без света")
	near(main.zap_light.omni_range, Zap.BASE_RADIUS, 1e-6, "на весь радиус разряда")
	ok(main.zap_light.light_cull_mask == OceanView.LAYER_WORLD, "светит только за бортом")
	for i in Main.ZAP_WARM_STEPS:
		main.step(1.0 / 60.0)
	ok(not main.zap_light.visible, "после прогрева погашена")
	main.queue_free()
	await frames(1)
