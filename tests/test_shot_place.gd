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


func test_scena_poses_nose_to_flower() -> void:   # scena=1|2|3 — ракурсы сцены 00 → 01 (#1400)
	for n in range(1, ShotSetup.SCENA.size() + 1):
		var p: Dictionary = ShotSetup.scena_pose(n)
		ok(not p.is_empty(), "ракурс есть: %d" % n)
		var at: Vector2 = ShotSetup.SCENA[n - 1]
		near(p["ship"].y, Seabed.mesh_height(at.x, at.y) + ShotSetup.SCENA_FLOOR, 1e-4, "над видимым дном: %d" % n)
		ok(p["ship"].y < 0.0, "подо льдом: %d" % n)
		var to := LayerMap.xz("01") - at
		var nose := Vector2(-sin(p["yaw"]), -cos(p["yaw"]))
		near(nose.dot(to.normalized()), 1.0, 1e-4, "нос к 01: %d" % n)
	ok(ShotSetup.scena_pose(0).is_empty() and ShotSetup.scena_pose(4).is_empty(), "нет ракурса — пусто")


func test_scena_ride_sources() -> void:   # высота хода scena=: плавный ход по умолчанию, dno, руками (#1400)
	const Box := preload("res://tools/pass_box.gd")
	const Plan := preload("res://tools/pass_plan.gd")
	for n in range(1, ShotSetup.SCENA.size() + 1):
		var r: Dictionary = ShotSetup.scena_ride(n)
		var s := Plan.arc_at(n - 1)
		var t := Box.station(s)
		ok(r["y"] >= t["ride"] - 1e-4, "не ниже H+7 в точке %d" % n)
		for u in Box.stations():
			ok(r["y"] >= u["ride"] - Box.SLOPE * absf(u["s"] - s) - 1e-4, "огибающая станций: %d, s=%.0f" % [n, u["s"]])
		ok(r["y"] < Seabed.ICE_Y, "подо льдом: %d" % n)
		ok(String(r["src"]).contains("pass_box"), "источник — pass_box: %d" % n)
	var at: Vector2 = ShotSetup.SCENA[1]
	near(ShotSetup.scena_ride(2, "dno")["y"], Seabed.mesh_height(at.x, at.y) + ShotSetup.SCENA_FLOOR, 1e-4, "dno — 7 м над дном")
	var hand: Dictionary = ShotSetup.scena_ride(2, "-30.5")
	near(hand["y"], -30.5, 1e-4, "руками")
	ok(String(hand["src"]).contains("scena_y=-30.5"), "источник — руками")


func test_scene_scena_at_helm() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ShotSetup.apply(main, {"scena": "2"})
	var p: Dictionary = ShotSetup.scena_pose(2)
	var at: Vector2 = ShotSetup.SCENA[1]
	ok(Vector2(main.helm.pos.x, main.helm.pos.z).is_equal_approx(at), "корабль в точке ракурса")
	near(main.helm.pos.y, ShotSetup.scena_ride(2)["y"], 1e-4, "без scena_y — плавный ход tools/pass_box.gd")
	var line := ShotSetup.scena_line(main)
	ok(line.contains("плавный ход tools/pass_box.gd"), "в подписи — источник высоты: " + line)
	ok(line.contains("y корабля " + ShotSetup._num(main.helm.pos.y)), "в подписи — фактический y: " + line)
	near(main.helm.yaw, p["yaw"], 1e-6, "курс к 01")
	ok(main.pilot.seated, "штатная камера пилота — за штурвалом")
	main.queue_free()
	await frames(1)


func test_scene_scena_motion_holds_ship() -> void:   # scena_t=<с> — мир идёт, корабль висит в точке ракурса (#1400)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var t0: float = main.time
	ShotSetup.apply(main, {"scena": "2", "scena_yaw": "-20", "scena_t": "2", "scena_y": "dno"})
	var p: Dictionary = ShotSetup.scena_pose(2)
	near(main.time - t0, 2.0, 0.05, "игра прошла 2 с")
	ok(main.helm.pos.is_equal_approx(p["ship"]), "корабль не унесло течением (scena_y=dno — 7 м над дном)")
	ok(ShotSetup.scena_line(main).contains("scena_y=dno"), "в подписи — источник dno")
	near(main.helm.yaw, p["yaw"] - deg_to_rad(20.0), 1e-3, "курс правее на 20°")
	ok(main.pilot.seated, "за штурвалом")
	main.queue_free()
	await frames(1)


func test_ground_hit_flat_floor() -> void:   # грунт в окне (#1400): луч до дна
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var d := Vector3(0, -1, -1).normalized()
	near(ShotSetup.ground_hit(Vector3(0, 7, 0), d, flat), 7.0 * sqrt(2.0), 0.01, "под 45° с 7 м — 9,9 м вдоль луча")
	ok(ShotSetup.ground_hit(Vector3(0, 7, 0), Vector3(0, 0.1, -1).normalized(), flat) == INF, "луч вверх — дна нет")
	ok(ShotSetup.ground_hit(Vector3(0, 7, 0), Vector3(0, -0.001, -1).normalized(), flat) == INF, "дальше GROUND_FAR — дна нет")


func test_blocked_front_face_only() -> void:   # заслон — лицевая сторона по часовой, изнанка не заслоняет
	var front := PackedVector3Array([Vector3(-1, -1, -5), Vector3(0, 1, -5), Vector3(1, -1, -5)])
	var back := PackedVector3Array([Vector3(-1, -1, -5), Vector3(1, -1, -5), Vector3(0, 1, -5)])
	var occ := func(f: PackedVector3Array) -> Array:
		var box := AABB(f[0], Vector3.ZERO)
		for p in f:
			box = box.expand(p)
		return [{"aabb": box, "faces": f}]
	var dir := Vector3(0, 0, -1)
	ok(ShotSetup.blocked(Vector3.ZERO, dir, 10.0, occ.call(front)), "лицевая сторона на пути — заслон")
	ok(not ShotSetup.blocked(Vector3.ZERO, dir, 10.0, occ.call(back)), "изнанка — не заслон")
	ok(not ShotSetup.blocked(Vector3.ZERO, dir, 4.0, occ.call(front)), "дно ближе заслона — видно")
	ok(not ShotSetup.blocked(Vector3(3, 0, 0), dir, 10.0, occ.call(front)), "мимо треугольника")


func test_scene_scena_ground_in_window() -> void:   # scena=n печатает, с какого расстояния виден грунт в окне (#1400)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ShotSetup.apply(main, {"scena": "1"})
	await frames(1)
	var cam: Camera3D = main.get_viewport().get_camera_3d()
	var occ := ShotSetup.occluders([main.bridge, main.hull])
	ok(not occ.is_empty(), "мостик заслоняет")
	var r := ShotSetup.ground_ahead(cam, 0.5, occ, Seabed.mesh_height)
	ok(not r.is_empty(), "грунт по центру виден")
	var bottom := int(main.get_viewport().get_visible_rect().size.y) - 1
	ok(r["row"] < bottom, "низ кадра закрыт пультом и штурвалом — кромка выше")
	ok(r["dist"] > ShotSetup.SCENA_FLOOR and r["dist"] < ShotSetup.GROUND_FAR, "грунт впереди дальше высоты над дном: %.1f" % r["dist"])
	var px := Vector2(main.get_viewport().get_visible_rect().size.x * 0.5, bottom)
	var o := cam.project_ray_origin(px)
	var d := cam.project_ray_normal(px)
	ok(ShotSetup.blocked(o, d, ShotSetup.ground_hit(o, d, Seabed.mesh_height), occ), "нижний луч упирается в мостик")
	ok(ShotSetup.ground_line(main).begins_with("грунт в окне (#1400): слева "), "строка для лога")
	main.queue_free()
	await frames(1)
