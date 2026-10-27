extends TestCase
## Состояние корабля для живого мира — одна функция `Main._fill_ship_state` у хоста и гостя (#765).

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


func after() -> void:
	main.queue_free()
	await frames(1)


## Хост: всё, включая шум, сканер и захват; гость: общее, а поля хоста не трогает.
func test_host_full_guest_common() -> void:
	main.helm.pos = Vector3(5.0, -40.0, 20.0)
	main.helm.yaw = 0.7
	main.helm.speed = 4.0
	main.at_scanner = true
	var s := main._fill_ship_state(true)
	ok(s == main.eco_ship, "пишет в eco_ship")
	eq(s.pos, main.helm.pos)
	near(s.yaw, 0.7, 1e-6)
	near(s.speed, 4.0, 1e-6)
	eq(s.dive, main.run.depth)
	near(s.scan_range, Scanner.RANGE, 1e-6, "у поста «Сканер» — цели сканера")
	near(s.hull_noise, main.engine.noise(4.0 / 6.7), 1e-6, "шум хода")
	eq(s.claw, main.samples.hook_world(Samples.ship_xform(main.helm.pos, main.helm.yaw)), "захват лебёдки")
	eq(s.claw_state, main.samples.state)
	eq(s.light_on, Searchlight.lit(main.light_on, main.reactor.k(Reactor.Sys.LAMP)))
	# Гость: место и ход новые, шум, сканер и захват — как были (их берёт кадр хоста).
	s.scan_range = 0.0
	s.hull_noise = 0.0
	s.claw_sample = -1
	main.helm.pos = Vector3(1.0, -30.0, 2.0)
	main.helm.speed = -2.0
	main._fill_ship_state(false)
	eq(s.pos, Vector3(1.0, -30.0, 2.0), "гость: место")
	near(s.speed, -2.0, 1e-6, "гость: ход")
	near(s.scan_range, 0.0, 1e-6, "гость: мир не считает цели сканера")
	near(s.hull_noise, 0.0, 1e-6)
	eq(s.claw_sample, -1)
