extends TestCase
## Снимок места слоя 1 одной командой — `shot.gd place=NN` (#1358): корабль у ориентира носом к нему, камера вне корпуса.

const ShotSetup := preload("res://tools/shot_setup.gd")


func test_every_place_camera_outside_hull() -> void:
	for id: String in LayerMap.POINTS:
		for kind: String in ShotSetup.PLACE_CAM:
			var p: Dictionary = ShotSetup.place_pose(id, kind)
			ok(not p.is_empty(), "поза есть: " + id)
			ok(not HullPlan.inside_world(p["cam"], p["ship"], p["yaw"]), "камера вне корпуса: %s %s" % [id, kind])
			ok(p["cam"].y > Seabed.height(p["cam"].x, p["cam"].z), "камера над дном: %s %s" % [id, kind])
			ok(p["ship"].y >= Seabed.height(p["ship"].x, p["ship"].z) + ShotSetup.PLACE_FLOOR - 1e-3, "корабль над дном: " + id)


func test_nose_points_at_landmark() -> void:
	for id: String in LayerMap.POINTS:
		var p: Dictionary = ShotSetup.place_pose(id)
		var to := LayerMap.xz(id) - Vector2(p["ship"].x, p["ship"].z)
		near(to.length(), ShotSetup.PLACE_DIST, 1e-3, "в PLACE_DIST от ориентира: " + id)
		var nose := Vector2(-sin(p["yaw"]), -cos(p["yaw"]))
		near(nose.dot(to.normalized()), 1.0, 1e-4, "нос к ориентиру: " + id)
		var look: Vector3 = p["look"] - p["cam"]
		ok(Vector2(look.x, look.z).dot(to) > 0.0, "камера смотрит к ориентиру: " + id)


func test_key_and_side() -> void:
	eq(ShotSetup.place_pose("shell"), ShotSetup.place_pose("03"), "ключ Run.PLACES — то же место")
	ok(ShotSetup.place_pose("нет").is_empty(), "нет места — пусто")
	var p: Dictionary = ShotSetup.place_pose("05", "front", 20.0, 0.0)   # с юга: корабль на +z от ориентира
	ok(p["ship"].is_equal_approx(Vector3(-170.0, p["ship"].y, -50.0)), "place_side=0 — с юга")
	near(p["yaw"], 0.0, 1e-6, "носом на север (−z)")


func test_scene_camera_at_pose() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ShotSetup.apply(main, {"place": "07"})
	var p: Dictionary = ShotSetup.place_pose("07")
	ok(main.helm.pos.is_equal_approx(p["ship"]), "корабль у места")
	await frames(1)
	var cam := main.get_viewport().get_camera_3d()
	ok(cam.global_position.is_equal_approx(p["cam"]), "текущая камера — ракурс места")
	main.queue_free()
	await frames(1)
