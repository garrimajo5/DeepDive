extends TestCase
## «Корабль устал» внутри по ART-074: потеря прочности, порог маски, чистые места, встройка в материал.

func test_target_from_hull() -> void:
	near(CabinWear.target(100.0), 0.0, 1e-6, "целый корпус — сухо")
	near(CabinWear.target(15.0), 0.85, 1e-6, "15 % — потеря 0,85")
	near(CabinWear.target(-5.0), 1.0, 1e-6, "ниже нуля — не больше 1")


func test_step_eases_in_and_back() -> void:
	var w := CabinWear.new()
	w.step(0.15, 0.0)
	near(w.loss, 0.5, 1e-5, "скачок до разрушения — половина за 0,15 с")
	w.step(0.15, 0.0)
	near(w.loss, 1.0, 1e-5, "весь за 0,3 с")
	w.step(1.0, 100.0)
	near(w.loss, 0.0, 1e-5, "ремонт — обратно по тому же весу")


func test_gate_by_threshold() -> void:
	near(CabinWear.gate(0.5, 0.4), 0.0, 1e-6, "до порога — сухо")
	near(CabinWear.gate(0.5, 0.64), 1.0, 1e-6, "порог + 0,14 — в полную силу")
	var low := Color(1.0, 1.0, 0.37)
	var p := Vector3(-4.9, 2.6, -3.0)
	near(CabinWear.amount(p, CabinWear.Face.WALL, low, CabinWear.target(70.0)), 0.0, 1e-6, "при 70 % сухо")
	ok(CabinWear.amount(p, CabinWear.Face.WALL, low, CabinWear.target(15.0)) > 0.9, "при 15 % потёк на стене")


func test_clean_posts_window_and_rooms() -> void:
	var d := Color(1.0, 1.0, 0.37)
	var l := 1.0
	for q: Vector2 in CabinWear.POSTS:
		near(CabinWear.amount(Vector3(q.x, 2.6, q.y), CabinWear.Face.WALL, d, l), 0.0, 1e-6, "у поста (%.1f; %.1f) сухо" % [q.x, q.y])
	near(CabinWear.amount(Vector3(-4.9, 2.6, -5.75), CabinWear.Face.WALL, d, l), 0.0, 1e-6, "рамка носового окна чистая")
	near(CabinWear.amount(Vector3(-1.5, 2.6, 8.0), CabinWear.Face.WALL, d, l), 0.0, 1e-6, "коридор и лаборатория — без износа")
	near(CabinWear.amount(Vector3(-2.9, 2.6, 22.0), CabinWear.Face.WALL, d, l), 0.0, 1e-6, "трюм — без износа")
	ok(CabinWear.amount(Vector3(-2.9, 2.6, 15.0), CabinWear.Face.WALL, d, l) > 0.9, "машинное — потёк")


func test_floor_wet_by_walls_only() -> void:
	var d := Color(1.0, 1.0, 0.37)
	ok(CabinWear.amount(Vector3(-4.8, 0.0, -3.4), CabinWear.Face.FLOOR, d, 1.0) > 0.9, "у борта мостика мокро")
	near(CabinWear.amount(Vector3(-1.5, 0.0, -3.4), CabinWear.Face.FLOOR, d, 1.0), 0.0, 1e-6, "проход сухой")
	near(CabinWear.amount(Vector3(-4.9, 0.6, -3.0), CabinWear.Face.WALL, d, 1.0), 0.0, 1e-6, "потёки гаснут к низу стены")
	near(CabinWear.amount(Vector3(-4.8, 2.9, -3.0), CabinWear.Face.CEILING, d, 1.0), 0.6, 1e-3, "потолок у борта — 0,6")


func test_mask_is_seamless_data() -> void:
	var img := CabinWear.MASK.get_image()
	if img.is_compressed():
		img.decompress()
	eq(img.get_width(), 512, "маска 512²")
	var lo := 1.0
	for i in 64:
		lo = minf(lo, img.get_pixel((i * 97) % 512, (i * 31) % 512).b)
	ok(lo > 0.3, "порог B не ниже 0,3 — шейдер не читает маску при потере < 0,36: %.2f" % lo)


func test_scene_sets_wear_on_bridge_and_rooms() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.vitals.hull = 15.0
	for i in 20:
		main.step(1.0 / 30.0)
	var want := CabinWear.target(main.vitals.hull)
	ok(want > 0.8, "корпус слабый")
	near(main.wear.loss, want, 1e-4, "потеря дошла до корпуса")
	var mats: Array[ShaderMaterial] = main.bridge.surface_materials()
	ok(not mats.is_empty(), "у мостика материалы ship_surface")
	for m in mats:
		near(float(m.get_shader_parameter("wear_loss")), want, 1e-4, "мостик получил потерю")
		ok(m.get_shader_parameter("wear_mask") is Texture2D, "и маску")
	var room := main.rooms.mesh
	var seen := 0
	for i in room.get_surface_count():
		var m := room.surface_get_material(i) as ShaderMaterial
		if m:
			seen += 1
			near(float(m.get_shader_parameter("wear_loss")), want, 1e-4, "отсеки получили потерю")
	ok(seen > 0, "у отсеков материалы ship_surface")
	main.queue_free()
	await frames(1)


## Issue #535: CLEARCOAT в шейдере включает второй блик на каждый огонь во всём материале (мостик и отсеки целиком,
## даже при целом корпусе) — на устройстве видеокарта 2–3 → 40–60 мс. Лак износа — через SPECULAR.
func test_no_clearcoat_in_shaders() -> void:
	for f: String in DirAccess.get_files_at("res://shaders"):
		if not f.ends_with(".gdshader") and not f.ends_with(".gdshaderinc"):
			continue
		var code := FileAccess.get_file_as_string("res://shaders/" + f)
		var lines := PackedStringArray()
		for line: String in code.split("\n"):
			lines.append(line.split("//")[0])
		ok(not "\n".join(lines).contains("CLEARCOAT"), "%s не пишет CLEARCOAT" % f)
