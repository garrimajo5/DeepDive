extends TestCase
## Ободок и затенение щелей корпуса ART-076 (HullMesh.rim_*, contact, occlusion; HullView.set_rim): кромка по глубине
## из LUT, гаснет в иле и при «Корпус разрушен», уступает разряду; AO — шов и примыкания, на «Экономно» — только шов.


func test_rim_row_by_depth() -> void:
	near(HullMesh.rim_row(0.0), 0.0, 1e-6, "у поверхности — строка 0")
	near(HullMesh.rim_row(-3.0), 0.0, 1e-6, "выше поверхности — тоже 0")
	near(HullMesh.rim_row(8.0), 1.0, 1e-6, "8 м — строка 1")
	near(HullMesh.rim_row(14.0), 2.0, 1e-6, "14 м — строка 2")
	near(HullMesh.rim_row(20.0), 3.0, 1e-6, "20 м — строка 3")
	near(HullMesh.rim_row(32.5), 4.0, 1e-6, "32,5 м — строка 4")
	near(HullMesh.rim_row(45.0), 5.0, 1e-6, "45 м — строка 5")
	near(HullMesh.rim_row(90.0), 6.0, 1e-6, "90 м — строка 6")
	near(HullMesh.rim_row(300.0), 6.0, 1e-6, "глубже 90 м — строка 6, строка ила не берётся")
	var prev := -1.0
	for d in range(0, 120, 3):
		var r := HullMesh.rim_row(float(d))
		ok(r >= prev, "строка не убывает с глубиной (%d м)" % d)
		prev = r
	for i in HullMesh.RIM_ROWS_M.size():
		near(HullMesh.rim_row(HullMesh.RIM_ROWS_M[i]), float(i), 1e-6, "глубина строки %d совпадает с LUT" % i)
	near(HullMesh.rim_v(5.0), 5.5 / 8.0, 1e-6, "V — центр текселя строки")


func test_rim_alive_and_k() -> void:
	near(HullMesh.rim_alive(-1.0), 1.0, 1e-6, "без шторки кромка есть")
	near(HullMesh.rim_alive(0.0), 1.0, 1e-6)
	ok(HullMesh.rim_alive(Wreck.DARK_AT * 0.5) < 1.0, "шторка гасит кромку")
	near(HullMesh.rim_alive(Wreck.DARK_AT), 0.0, 1e-6, "к DARK_AT — темно")
	near(HullMesh.rim_alive(Wreck.RESTART_AT - 0.01), 0.0, 1e-6, "до перезапуска — нет")
	near(HullMesh.rim_alive(Wreck.END), 1.0, 1e-6, "к концу шторки вернулась")
	near(HullMesh.rim_k(1.0, 0.0, false), 1.0, 1e-6)
	near(HullMesh.rim_k(1.0, 1.0, false), 0.0, 1e-6, "в иле кромки нет")
	near(HullMesh.rim_k(1.0, 0.5, false), 0.5, 1e-6)
	near(HullMesh.rim_k(1.0, 0.0, true), HullMesh.RIM_LITE, 1e-6, "«Экономно» — 0,65")
	near(HullMesh.rim_zap(-1.0, Zap.FLICKER), 1.0, 1e-6, "вне разряда не гаснет")
	near(HullMesh.rim_zap(Zap.FLICKER * 0.5, Zap.FLICKER), 1.0 - HullMesh.RIM_ZAP, 1e-6, "в середине разряда — ×0,45")


func test_contacts() -> void:
	near(HullMesh.contact(HullMesh.AO_MOUNT), 1.0, 1e-6, "внутри крепления правого двигателя — полное примыкание")
	var left := Vector3(-HullMesh.AO_MOUNT.x, HullMesh.AO_MOUNT.y, HullMesh.AO_MOUNT.z)
	near(HullMesh.contact(left), 1.0, 1e-6, "и левого — по модулю x")
	near(HullMesh.contact(Vector3(0.0, 4.0, -6.0)), 0.0, 1e-3, "на носу примыканий нет")
	near(HullMesh.contact(Vector3(0.0, 0.0, 10.0)), 0.0, 1e-3, "в середине корпуса — нет")
	ok(HullMesh.contact(HullMesh.AO_STAB_UP) > 0.99, "корень верхнего стабилизатора")
	ok(HullMesh.contact(Vector3(3.95, 2.6, 24.6)) > 0.99 and HullMesh.contact(Vector3(-3.95, 2.6, 24.6)) > 0.99,
		"корни обоих рулей")
	var near_mount := HullMesh.contact(HullMesh.AO_MOUNT + Vector3(0, HullMesh.AO_MOUNT_HALF.y + 0.18, 0))
	near(near_mount, exp(-1.0), 1e-4, "у крепления спадает по exp(−d/0,18)")


func test_occlusion() -> void:
	near(HullMesh.occlusion(0.0, 0.0, 0.0), 1.0, 1e-6, "гладкий металл не темнеет")
	near(HullMesh.occlusion(1.0, 0.0, 0.0), 0.82, 1e-6, "шов — 0,82")
	near(HullMesh.occlusion(1.0, 1.0, 0.0), HullMesh.AO_MIN, 1e-6, "шов у примыкания — до минимума 0,55")
	ok(HullMesh.occlusion(1.0, 1.0, 1.0) > HullMesh.occlusion(1.0, 1.0, 0.0), "на следах ART-049 щели светлее")
	near(HullMesh.occlusion(0.0, 1.0, 0.0), 0.66, 1e-6, "примыкание — 0,66")


func test_rim_lut() -> void:
	var t: Texture2D = load(HullMesh.RIM_TEX)
	ok(t != null, "LUT ободка загружается")
	eq(t.get_width(), 256, "256 по углу")
	eq(t.get_height(), HullMesh.RIM_ROWS, "8 строк")
	var img := t.get_image()
	ok(not img.is_compressed(), "LUT без потерного сжатия")
	ok(not img.has_mipmaps(), "LUT без mipmap")
	for x in [0, 64, 128, 192, 255]:
		near(img.get_pixel(x, 7).a, 0.0, 1e-3, "строка ила — без кромки (x = %d)" % x)
	for y in 7:
		ok(img.get_pixel(20, y).a < 0.02, "строка %d: в лоб кромки нет" % y)
		ok(img.get_pixel(255, y).a > img.get_pixel(128, y).a, "строка %d: к краю кромка сильнее" % y)
	ok(img.get_pixel(255, 5).a > img.get_pixel(255, 0).a and img.get_pixel(255, 5).a > img.get_pixel(255, 6).a,
		"сильнее всего на 45 м")
	for y in 7:
		var c := img.get_pixel(255, y)
		ok(c.b >= c.r and c.g >= c.r, "строка %d: палитра холодная, без тёплого (#129)" % y)


func test_shader_has_rim() -> void:
	var src: String = (load("res://shaders/hull_plating.gdshader") as Shader).code
	for u in ["rim_tex", "rim_row", "rim_k", "ao_contacts", "AO_LIGHT_AFFECT", "EMISSION = emit"]:
		ok(src.contains(u), "в шейдере обшивки: %s" % u)
	ok(src.contains("normalize(ln)), 0.0)") or src.contains("vec4(normalize(ln), 0.0)"),
		"кромка по геометрической нормали, не по рельефу")


func test_scene_rim_follows_depth_silt_wreck() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var sm: ShaderMaterial = main.hull.body_material(HullPlan.Paint.METAL)
	ok(sm.get_shader_parameter("rim_tex") is Texture2D, "LUT ART-076 в материале обшивки")
	eq(main.hull.body.mesh.get_surface_count(), HullMesh.paints().size(), "без новых поверхностей и вызовов")
	main.helm.pos.y = -45.0
	main.step(1.0 / 30.0)
	near(sm.get_shader_parameter("rim_row"), HullMesh.rim_row(main.helm.depth()), 1e-3, "строка по глубине корабля")
	ok(float(sm.get_shader_parameter("rim_row")) > 4.5, "на 45 м — строка около 5")
	near(sm.get_shader_parameter("rim_k"), 1.0, 1e-3, "вне ила кромка полная")
	main.silt.k = 1.0
	main.step(1.0 / 30.0)
	ok(float(sm.get_shader_parameter("rim_k")) < 0.5, "ил гасит кромку")
	main.silt.k = 0.0
	main.step(1.0 / 30.0)
	main.wreck.t = Wreck.DARK_AT + 0.1
	main.step(1.0 / 30.0)
	near(sm.get_shader_parameter("rim_k"), 0.0, 1e-3, "«Корпус разрушен» — кромки нет")
	main.wreck.t = -1.0
	main.hull.set_relief(false)
	main.step(1.0 / 30.0)
	ok(not bool(sm.get_shader_parameter("ao_contacts")), "«Экономно» — щели только по шву")
	ok(float(sm.get_shader_parameter("rim_k")) <= HullMesh.RIM_LITE + 1e-3, "«Экономно» — кромка 0,65")
	main.hull.set_relief(true)
	ok(bool(sm.get_shader_parameter("ao_contacts")), "рельеф снова — примыкания считаются")
	main.queue_free()
	await frames(1)
