extends TestCase
## Лёд снизу по ART-056 (`IceSheet`, «Лёд» в `OceanView`, `shaders/ice.gdshader`): карты по world.xz / 16, сеть трещин
## открыта крупным мировым шумом (рвёт повтор плитки), свечение — слабый фон и трещины вместо ровной 0,35, гаснет
## по глубине; альбедо уходит в цвет воды, нормали гаснут к 35 м; «Экономно» — без нормалей.


func test_glow_by_depth() -> void:
	near(IceSheet.glow(0.0, 0.0, 1.0), IceSheet.GLOW_BASE, 1e-6, "толща без трещин — слабый фон")
	near(IceSheet.glow(0.0, 1.0, 1.0), 0.10, 1e-6, "трещина в открытом месте — фон + 0,08")
	near(IceSheet.glow(0.0, 1.0, 0.0), IceSheet.GLOW_BASE, 1e-6, "закрытая шумом сеть не светит")
	near(IceSheet.glow(9.0, 1.0, 1.0), 0.10 / exp(1.0), 1e-6, "по глубине — exp(−depth/9)")
	ok(IceSheet.glow(30.0, 1.0, 1.0) < 0.004, "на 30 м лёд почти погас")
	near(IceSheet.glow(-2.0, 1.0, 1.0), IceSheet.glow(0.0, 1.0, 1.0), 1e-6, "над льдом не ярче")
	ok(IceSheet.glow(0.0, 1.0, 1.0) < 0.35 / 3.0, "не выбеливает окно — в разы тусклее прежней ровной 0,35")
	ok(IceSheet.GLOW_BASE >= 0.015 and IceSheet.GLOW_BASE <= 0.025, "фон 0,015–0,025 по ART-056")


func test_contrast_and_relief() -> void:
	near(IceSheet.contrast(0.0), 1.0, 1e-6, "у поверхности — свой цвет льда")
	near(IceSheet.contrast(8.0), 1.0, 1e-6)
	near(IceSheet.contrast(38.0), 0.0, 1e-6, "с 38 м — цвет воды")
	ok(IceSheet.contrast(20.0) > 0.0 and IceSheet.contrast(20.0) < 1.0, "между — плавно")
	near(IceSheet.relief(0.0), IceSheet.NORMAL_DEPTH, 1e-6, "у льда — полная сила нормалей")
	near(IceSheet.relief(35.0), 0.0, 1e-6, "к 35 м нормали гаснут")
	near(IceSheet.relief(80.0), 0.0, 1e-6)
	ok(IceSheet.NORMAL_DEPTH >= 0.25 and IceSheet.NORMAL_DEPTH <= 0.5, "сила 0,25–0,5")


## Шум открывает сеть трещин участками: светит не везде и не по сетке плиток 16 м.
func test_gate_breaks_tiling() -> void:
	var open := 0
	var total := 0
	var differ := 0
	for j in 60:
		for i in 60:
			var x := -300.0 + i * 10.0 + 0.37
			var z := -300.0 + j * 10.0 + 0.61
			var g := IceSheet.gate(x, z)
			ok(g >= 0.0 and g <= 1.0, "0…1")
			total += 1
			if g > 0.5:
				open += 1
			if absf(g - IceSheet.gate(x + IceSheet.TILE, z)) > 0.05:
				differ += 1
	var share := float(open) / total
	ok(share > 0.1 and share < 0.6, "сеть открыта участками, не везде (%.2f)" % share)
	ok(differ > total / 10, "соседние плитки светят по-разному — повтор рвётся (%d из %d)" % [differ, total])
	eq(IceSheet.uv(16.0, -32.0), Vector2(1.0, -2.0), "UV — world.xz / 16")


func test_maps_imported() -> void:
	for f in ["tsvet", "normali", "treshchiny"]:
		var t: Texture2D = load("res://textures/ice/%s.png" % f)
		ok(t != null, f)
		var img := t.get_image()
		eq(img.get_width(), 1024, "%s 1024²" % f)
		ok(img.has_mipmaps(), "%s с mipmap — без ряби вдали" % f)


func test_scene_ice_material() -> void:
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	await frames(1)
	var m := ocean.ice.material_override as ShaderMaterial
	ok(m != null, "лёд — шейдер ART-056, не ровная эмиссия")
	eq(m.shader.resource_path, "res://shaders/ice.gdshader")
	ok(m.get_shader_parameter("color_tex") != null and m.get_shader_parameter("normal_tex") != null
		and m.get_shader_parameter("crack_tex") != null, "три карты")
	near(float(m.get_shader_parameter("tile")), IceSheet.TILE, 1e-6)
	near(float(m.get_shader_parameter("gate_scale")), IceSheet.GATE_SCALE, 1e-6, "шум шейдера — как IceSheet.gate")
	eq(m.get_shader_parameter("gate_edge"), IceSheet.GATE_EDGE)
	eq(ocean.ice.layers, OceanView.LAYER_WORLD, "слой отмели")
	var env := Environment.new()
	ocean.apply_water(env, 18.0, Vector3.ZERO, 0.0)
	near(float(m.get_shader_parameter("glow_k")), exp(-18.0 / IceSheet.GLOW_DEPTH), 1e-5, "свечение по глубине")
	near(float(m.get_shader_parameter("contrast")), IceSheet.contrast(18.0), 1e-5)
	near(float(m.get_shader_parameter("relief")), IceSheet.relief(18.0), 1e-5)
	eq(m.get_shader_parameter("water"), env.fog_light_color, "альбедо уходит в цвет воды")
	ocean.set_relief(false)
	near(float(m.get_shader_parameter("relief")), 0.0, 1e-6, "«Экономно» — без нормалей")
	ocean.apply_water(env, 2.0, Vector3.ZERO, 0.0)
	near(float(m.get_shader_parameter("relief")), 0.0, 1e-6, "и вода их не включает обратно")
	ocean.queue_free()
	await frames(1)
