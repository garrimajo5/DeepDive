extends TestCase
## Главная сцена: собирается, игрок ходит крестовиной и смотрит свайпом.

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


func test_scene_builds() -> void:
	ok(main.camera != null and main.camera.is_current(), "камера включена")
	var paints := {}
	for part in BridgePlan.parts():
		paints[part.paint] = true
	eq(main.bridge.mesh_instance.mesh.get_surface_count(), paints.size(), "по поверхности на краску")
	ok(main.overlay != null, "экранное управление")


func test_pad_walks_forward() -> void:
	var r := main.overlay.router
	var z0 := main.walker.z
	r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))
	await frames(20)
	r.end(1)
	ok(main.walker.z < z0 - 0.1, "прошли к носу")
	near(main.camera.position.z, main.pilot.eye(main.walker).z, 1e-4, "камера за игроком")


func test_swipe_turns_camera() -> void:
	var r := main.overlay.router
	r.begin(2, Vector2(800, 300))
	r.moved(2, Vector2(900, 300))
	await frames(1)
	r.end(2)
	ok(main.walker.yaw < 0.0, "повернулись вправо")
	near(main.camera.rotation.y, main.walker.yaw, 1e-4, "камера повернулась")


func test_action_label_at_helm() -> void:
	main.walker.x = 0.0
	main.walker.z = Deck.STAND_Z
	await frames(1)
	eq(main.overlay.action_label, "Штурвал", "у кресла кнопка — штурвал")
	main.walker.x = 2.0
	main.walker.z = 0.0
	await frames(1)
	eq(main.overlay.action_label, "", "посреди мостика кнопка пустая")
	main.walker.x = 0.0
	main.walker.z = 1.5
	await frames(1)
	eq(main.overlay.action_label, "Люк", "у кормы — люк")


func test_models_on_bridge() -> void:
	for name in [BridgeProps.CHAIR, BridgeProps.TABLE, BridgeProps.STAND, BridgeProps.CONSOLE, BridgeProps.SCREENS, BridgeProps.WHEEL]:
		var n: Node3D = main.bridge.props.get(name)
		if not ok(n != null, "модель %s на мостике" % name):
			continue
		ok(not n.find_children("*", "MeshInstance3D", true, false).is_empty(), "у %s есть меш" % name)
	near(main.bridge.wheel.global_position.distance_to(main.ship.to_global(Vector3(0, BridgeProps.WHEEL_Y, BridgeProps.WHEEL_Z))), 0.0, 1e-3, "колесо на месте")


func test_sit_drive_and_stand() -> void:
	var r := main.overlay.router
	main.walker.z = Deck.STAND_Z
	r.begin(1, r.layout.action.c)
	r.end(1)
	await frames(1)
	ok(main.pilot.seated, "сели за штурвал")
	ok(r.pilot_buttons, "кнопки пилота включены")
	near(main.camera.position.z, Deck.SEAT_Z, 1e-4, "глаза над креслом")
	var z0 := main.helm.pos.z
	r.begin(2, r.layout.pad.c + Vector2(r.layout.pad.r * 0.5, -r.layout.pad.r * 0.5))
	for i in 120:  # 4 с игры с ровным шагом: в headless кадры идут без пауз
		main.step(1.0 / 30.0)
	r.end(2)
	ok(main.helm.pos.z < z0 - 0.5, "корабль пошёл к носу")
	ok(main.helm.yaw < 0.0, "и повернул вправо")
	ok(main.bridge.wheel.rotation_degrees.z < 0.0, "колесо повернулось")
	near(main.ship.position.z, main.helm.pos.z, 1e-4, "корабль в сцене там же, где в расчёте")
	r.begin(3, r.layout.action.c)
	r.end(3)
	await frames(1)
	ok(not main.pilot.seated, "встали")
	ok(not r.pilot_buttons, "кнопки пилота скрыты")
	ok(main.walker.z > BridgeProps.CHAIR_Z, "за креслом")


func test_walking_does_not_move_ship() -> void:
	var r := main.overlay.router
	main.walker.z = 1.0
	var p0 := main.helm.pos
	r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))
	await frames(30)
	r.end(1)
	ok(main.helm.pos.distance_to(p0) < 1.0, "ходьба по мостику не двигает корабль (только течение)")


func test_water_darkens_with_depth() -> void:
	main.helm.pos.y = -10.0
	await frames(1)
	var c1 := main.env.background_color
	main.helm.pos.y = -90.0
	await frames(1)
	ok(main.env.background_color.v < c1.v, "в глубине вода темнее")
	ok(main.env.fog_enabled, "туман включён")
