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
	near(float(res["TailStrike"].len), 0.6, 0.01, "длина TailStrike")


## Таблица заказа: плавание спокойное, бросок резче, удар серпом — самый резкий, пик в середине удара.
func test_strike_is_the_sharp_one() -> void:
	var res := _measure()
	var swim: Dictionary = res["Swim"]
	var fast: Dictionary = res["SwimFast"]
	var strike: Dictionary = res["TailStrike"]
	ok(float(swim.amax) < 15.0, "плавание: макс. ускорение %.1f м/с²" % swim.amax)
	ok(float(fast.amax) > float(swim.amax) and float(fast.amax) < 60.0, "бросок: %.1f м/с²" % fast.amax)
	ok(float(strike.amax) > 120.0, "удар ANIM-001: %.1f м/с² — резкий, заказ ANIM-005 ≤ 60" % strike.amax)
	near(float(strike.at), 0.33, 0.05, "пик удара — в середине клипа")
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
