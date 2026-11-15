extends TestCase
## `tools/clip_tip.gd` (#1753, заказ ANIM-005 #1766): скорость и ускорение конца серпа серпохвоста по клипам при
## 30 кадрах/с. По этой таблице заказан плавный удар серпом; при приёмке ANIM-005 тем же замером проверяют пределы.


func _measure(hz := 30.0) -> Dictionary:
	var tool: GDScript = load("res://tools/clip_tip.gd")
	var root := Node3D.new()
	tree.root.add_child(root)
	var res: Dictionary = tool.measure(root, tool.GLB, tool.BONE, tool.POINT, hz)
	root.free()
	return res


func test_all_clips_measured() -> void:
	var res := _measure()
	for n in ["Swim", "SwimFast", "Bite", "TailStrike"]:
		ok(res.has(n), "есть клип %s" % n)
	near(float(res["Swim"].len), 2.4, 0.01, "длина Swim")
	near(float(res["TailStrike"].len), 0.9, 0.01, "длина TailStrike (ANIM-005)")


## Плавание спокойное, бросок резче; удар серпом после ANIM-005 — плавный (≤ 60 м/с², было 177), но быстрый.
func test_strike_is_smooth_but_fast() -> void:
	var res := _measure()
	var swim: Dictionary = res["Swim"]
	var fast: Dictionary = res["SwimFast"]
	var strike: Dictionary = res["TailStrike"]
	ok(float(swim.amax) < 15.0, "плавание: макс. ускорение %.1f м/с²" % swim.amax)
	ok(float(fast.amax) > float(swim.amax) and float(fast.amax) < 60.0, "бросок: %.1f м/с²" % fast.amax)
	ok(float(strike.amax) <= 60.0, "удар ANIM-005: %.1f м/с² ≤ 60" % strike.amax)
	near(float(strike.at), 0.47, 0.05, "пик удара — между замахом и низом")
	ok(float(strike.vmax) > 7.0, "удар быстрый: %.1f м/с" % strike.vmax)


## Нет кости или файла — пусто, а не ошибка.
func test_missing_bone_is_empty() -> void:
	var tool: GDScript = load("res://tools/clip_tip.gd")
	var root := Node3D.new()
	tree.root.add_child(root)
	var res: Dictionary = tool.measure(root, tool.GLB, "NoSuchBone", tool.POINT, 30.0)
	root.free()
	eq(res.size(), 0, "нет кости — пустой итог")


func test_line_reads() -> void:
	var tool: GDScript = load("res://tools/clip_tip.gd")
	var s: String = tool.line("Swim", {"len": 2.4, "vmax": 2.0, "amed": 3.0, "amax": 10.3, "at": 1.73})
	ok(s.begins_with("Swim 2.40 с: скорость макс. 2.0 м/с") and s.contains("макс. 10.3 м/с² (1.73 с)"), s)


## `point_at`: в позе покоя точка остаётся на месте, при повёрнутой кости — на том же расстоянии от неё.
func test_point_at_rides_bone() -> void:
	var tool: GDScript = load("res://tools/clip_tip.gd")
	var sc: Node = (load(tool.GLB) as PackedScene).instantiate()
	tree.root.add_child(sc)
	var sk: Skeleton3D = sc.find_children("*", "Skeleton3D", true, false)[0]
	var b := sk.find_bone(tool.BONE)
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	var rest: Vector3 = tool.point_at(sk, b, tool.POINT)
	ok(rest.distance_to(tool.POINT) < 1e-3, "поза покоя: %s" % rest)
	var r0 := sk.get_bone_global_pose(b).origin.distance_to(rest)
	sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion(Vector3(1, 1, 0).normalized(), 0.6))
	sk.force_update_all_bone_transforms()
	var turned: Vector3 = tool.point_at(sk, b, tool.POINT)
	ok(turned.distance_to(rest) > 0.1, "кость повёрнута — точка ушла на %.2f м" % turned.distance_to(rest))
	near(sk.get_bone_global_pose(b).origin.distance_to(turned), r0, 1e-3, "плечо от кости то же")
	sc.free()
