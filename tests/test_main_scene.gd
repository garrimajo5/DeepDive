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
	near(main.camera.position.z, main.walker.z, 1e-4, "камера за игроком")


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
	main.walker.z = -3.6
	await frames(1)
	eq(main.overlay.action_label, "Штурвал", "у кресла кнопка — штурвал")
	main.walker.z = 1.0
	await frames(1)
	eq(main.overlay.action_label, "", "у люка кнопка пустая")
