extends TestCase
## Блики воды в мостике ART-067 (`WaterGlints`, `BridgeView.set_glints`, `docs/concept-art/bliki-vody.md`).


func test_strength_by_depth() -> void:
	near(WaterGlints.strength(3.0), 0.12, 1e-6, "у льда — как на 8 м")
	near(WaterGlints.strength(8.0), 0.12, 1e-6, "8 м — 0,12")
	near(WaterGlints.strength(14.0), 0.09, 1e-6, "между 8 и 20 — линейно")
	near(WaterGlints.strength(20.0), 0.06, 1e-6, "20 м — 0,06")
	near(WaterGlints.strength(45.0), 0.002, 1e-6, "45 м — 0,002")
	near(WaterGlints.strength(90.0), 0.0, 1e-6, "90 м — нет")
	eq(WaterGlints.strength(140.0), 0.0, "глубже — нет")
	var prev := 1.0
	for d in range(0, 100, 5):
		var s := WaterGlints.strength(float(d))
		ok(s <= prev + 1e-9, "не растёт с глубиной (%d м)" % d)
		prev = s


func test_tint_is_water_without_red() -> void:
	for d: float in [5.0, 20.0, 45.0, 90.0]:
		var c := WaterGlints.tint(d)
		near(maxf(c.r, maxf(c.g, c.b)), 1.0, 1e-5, "%d м: max RGB — 1" % d)
		ok(c.b >= c.g and c.g > c.r, "%d м: голубой, без красного (%s)" % [d, c])
		ok(c.r >= WaterGlints.WHITE - 1e-5, "%d м: 65 %% белого" % d)


func test_silt_alarm_lamps_lite() -> void:
	var g := WaterGlints.new()
	near(g.k(12.0, 0.0, 1.0), WaterGlints.strength(12.0), 1e-6, "чистая вода — по глубине")
	near(g.k(12.0, 1.0, 1.0), WaterGlints.strength(12.0) * 0.02, 1e-6, "ил гасит ×0,02")
	near(g.k(12.0, 0.0, 0.5), WaterGlints.strength(12.0) * 0.5, 1e-6, "× мигание плафонов")
	eq(g.k(12.0, 0.0, 0.0), 0.0, "шторка погасила — нет бликов")
	eq(g.k(95.0, 0.0, 1.0), 0.0, "в глубине — нет (маска не читается)")
	g.step(WaterGlints.ALARM_TAU, true)
	near(g.alarm, 1.0 - exp(-1.0), 1e-5, "огибающая 0,3 с: за τ — 63 %")
	for i in 30:
		g.step(0.1, true)
	near(g.k(12.0, 0.0, 1.0), WaterGlints.strength(12.0) * 0.1, 1e-4, "авария — ×0,1, не мигалка")
	var a := g.alarm
	g.step(0.05, false)
	ok(g.alarm < a and g.alarm > 0.5, "заварили — гаснет плавно, без скачка")
	g.lite = true
	eq(g.k(12.0, 0.0, 1.0), 0.0, "«Экономно» — выкл")


func test_zone_and_facing() -> void:
	eq(WaterGlints.zone(-8.0), 0.0, "перед окнами — нет")
	near(WaterGlints.zone(-3.0), 1.0, 1e-6, "середина мостика — полная")
	ok(WaterGlints.zone(1.0) > 0.0 and WaterGlints.zone(1.0) < 1.0, "к корме гаснет")
	eq(WaterGlints.zone(3.5), 0.0, "в отсеках — нет")
	eq(WaterGlints.facing(-1.0), 1.0, "потолок ×1")
	eq(WaterGlints.facing(1.0), 0.6, "пол ×0,6")
	eq(WaterGlints.facing(0.0), 0.0, "стены — нет")


func test_mask_tiles_and_flows() -> void:
	var mask: Image = load("res://textures/bridge/bliki-maska.png").get_image()
	if mask.is_compressed():
		mask.decompress()
	eq(mask.get_size(), Vector2i(512, 512), "маска 512²")
	# Плитка 3,2 м: тот же узор через плитку, течение непрерывно и сдвигает узор.
	var p := Vector2(0.7, -2.3)
	near(WaterGlints.pattern(mask, p, 4.0), WaterGlints.pattern(mask, p + Vector2(3.2, 3.2), 4.0), 0.02, "плитка 3,2 м")
	var moved := 0
	var lo := 1.0
	var hi := 0.0
	for i in 64:
		var q := Vector2(i * 0.05, i * 0.031)
		var v := WaterGlints.pattern(mask, q, 0.0)
		lo = minf(lo, v)
		hi = maxf(hi, v)
		if absf(v - WaterGlints.pattern(mask, q, 8.0)) > 0.02:
			moved += 1
	ok(hi - lo > 0.15, "узор есть: %.2f…%.2f" % [lo, hi])
	ok(moved > 16, "за 8 с узор сдвинулся (%d из 64)" % moved)
	var uv := WaterGlints.flow(Vector2.ZERO, 10.0)
	near((uv[0] * WaterGlints.TILE).length() / 10.0, 0.044, 0.002, "течение ≈ 0,04 м/с")


func test_scene_bridge_glints() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var mats := main.bridge.surface_materials()
	ok(mats.size() >= 2, "пол и потолок мостика — материалы ship_surface")
	main.helm.pos.y = -12.0
	main.step(0.1)
	for m in mats:
		ok(m.get_shader_parameter("glint_mask") != null, "маска в материале")
		near(m.get_shader_parameter("glint_k"), WaterGlints.strength(12.0), 1e-5, "12 м — сила по глубине")
		near(m.get_shader_parameter("glint_time"), main.time, 1e-5, "часы течения — время игры")
	for i in main.rooms.mesh_instance.mesh.get_surface_count():
		var rm := main.rooms.mesh_instance.mesh.surface_get_material(i) as ShaderMaterial
		if rm:
			eq(rm.get_shader_parameter("glint_k"), null, "отсеки бликов не получают")
	main.glints.lite = true
	main.step(0.1)
	eq(mats[0].get_shader_parameter("glint_k"), 0.0, "«Экономно» — выкл")
	main.glints.lite = false
	main.helm.pos.y = -12.0
	main.on_eco_event({"type": EcoLink.HIT, "damage": 0.12, "by": "Серпохвост"})
	for i in 20:
		main.step(0.1)
	ok(main.glints.alarm > 0.95, "пробоина — огибающая тревоги")
	ok(mats[0].get_shader_parameter("glint_k") < WaterGlints.strength(12.0) * 0.2, "в аварии блики приглушены")
	main.queue_free()
	await frames(1)
