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


## Шахты ART-052 стоят на трещинах льда: маска выше 0,70 там, где шум открыл сеть (ART-056).
func test_shafts_stand_on_cracks() -> void:
	var all := LightShafts.layout()
	ok(all.size() > 150, "шахт %d" % all.size())
	for s in all:
		ok(IceSheet.crack(s.top.x, s.top.z) > IceSheet.SHAFT_MASK, "верх шахты на трещине (%.1f, %.1f)" % [s.top.x, s.top.z])
		ok(IceSheet.gate(s.top.x, s.top.z) > 0.0, "там, где сеть трещин открыта")
	var start := LightShafts.near(all, Helm.Ship.START, 60.0)
	ok(start.size() >= 3, "у старта видно 3+ шахты (%d)" % start.size())
	ok(IceSheet.crack(0.3, 0.3) >= 0.0 and IceSheet.crack(0.3, 0.3) <= 1.0, "маска 0…1")
	near(IceSheet.crack(3.1, -5.2), IceSheet.crack(3.1 + IceSheet.TILE, -5.2 - IceSheet.TILE), 1e-6, "та же плитка 16 м")


func test_caustics_under_cracks() -> void:
	near(IceSheet.caustic(0.0), IceSheet.CAUSTIC, 1e-6, "у льда — полная сила")
	near(IceSheet.caustic(IceSheet.CAUSTIC_DEPTH), IceSheet.CAUSTIC / exp(1.0), 1e-6, "exp(−глубина дна / CAUSTIC_DEPTH)")
	ok(IceSheet.caustic(60.0) < IceSheet.caustic(30.0), "глубже — слабее")
	near(IceSheet.caustic_net(0.0), 0.6, 1e-6, "сеть без трещины — как была")
	ok(IceSheet.caustic_net(1.0) >= 3.0 * IceSheet.caustic_net(0.0), "под трещиной сеть втрое ярче")
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	await frames(1)
	var m := ocean.seabed_mat
	eq((m.get_shader_parameter("crack_tex") as Texture2D).resource_path, IceSheet.CRACK_MASK, "дно — та же маска трещин")
	near(float(m.get_shader_parameter("gate_scale")), IceSheet.GATE_SCALE, 1e-6, "и тот же шум открытости")
	near(float(m.get_shader_parameter("crack_caustic")), IceSheet.CAUSTIC, 1e-6)
	near(float(m.get_shader_parameter("crack_depth")), IceSheet.CAUSTIC_DEPTH, 1e-6)
	near(float(m.get_shader_parameter("crack_net")), IceSheet.CAUSTIC_NET, 1e-6, "шейдер — та же сила сети")
	ocean.queue_free()
	await frames(1)


## #445: свет под трещинами виден на настоящем дне отмели (30…47 м подо льдом), а не только у льда. При прежних
## 0,06·exp(−d/12) на медиане дна было 0,002 — тестер не видел каустик.
func test_caustics_visible_on_shallows_floor() -> void:
	var hs: Array[float] = []
	for x in range(-150, 151, 25):
		for z in range(-150, 151, 25):
			hs.append(Seabed.ICE_Y - Seabed.height(x, z))
	hs.sort()
	var median := hs[hs.size() / 2]
	ok(median > 30.0, "дно отмели глубоко подо льдом (%.0f м)" % median)
	ok(IceSheet.caustic(median) >= 0.04, "на медиане дна свет трещин ≥ 0,04 (%.4f)" % IceSheet.caustic(median))
	ok(IceSheet.caustic(hs[-1]) >= 0.025, "и на самом глубоком месте рядом виден (%.4f)" % IceSheet.caustic(hs[-1]))
	ok(IceSheet.caustic(0.0) <= 0.15, "у самого льда не выбеливает дно")


## ART-075: строка LUT по глубине — ключи 0/8/20/45/90 м → строки 0/3/7/11/15, между ними линейно.
func test_reflect_row() -> void:
	near(IceSheet.row(0.0), 0.0, 1e-6)
	near(IceSheet.row(8.0), 3.0, 1e-6)
	near(IceSheet.row(20.0), 7.0, 1e-6)
	near(IceSheet.row(45.0), 11.0, 1e-6)
	near(IceSheet.row(90.0), 15.0, 1e-6)
	near(IceSheet.row(4.0), 1.5, 1e-6, "между ключами — линейно")
	near(IceSheet.row(32.5), 9.0, 1e-6, "строка 9 таблицы — 32,5 м")
	near(IceSheet.row(-3.0), 0.0, 1e-6, "над льдом — строка поверхности")
	near(IceSheet.row(200.0), 15.0, 1e-6, "глубже 90 м — последняя строка")


## Окно Снелля: вне окна (вдоль льда) зеркало, сверху прозрачно; глубже — слабее; шершавая грань мягчит границу.
func test_snell_lut() -> void:
	var t: Texture2D = load(IceSheet.REFLECT_LUT)
	var img := t.get_image()
	eq(img.get_size(), Vector2i(256, 16), "LUT 256×16")
	ok(not img.has_mipmaps(), "LUT без mipmap")
	var a := func(mu: float, depth: float) -> float:
		var lk := IceSheet.lookup(mu, 1.0)
		return img.get_pixel(int(round(lk * 255.0)), int(round(IceSheet.row(depth)))).a
	ok(a.call(0.2, 0.0) > 0.85, "вдоль льда у поверхности — почти зеркало")
	ok(a.call(1.0, 0.0) < 0.05, "прямо вверх — окно, сквозь лёд")
	ok(a.call(0.2, 20.0) < a.call(0.2, 8.0) and a.call(0.2, 8.0) < a.call(0.2, 0.0), "затухание по глубине уже в A")
	ok(a.call(0.2, 45.0) < 0.03, "на 45 м почти незаметно")
	near(a.call(0.2, 90.0), 0.0, 1e-3, "на 90 м нет")
	near(IceSheet.lookup(IceSheet.CRIT_COS, 0.0), IceSheet.CRIT_COS, 1e-6, "критический угол на месте")
	ok(IceSheet.lookup(1.0, 0.0) < IceSheet.lookup(1.0, 1.0), "шершавая грань прижимает к границе окна")
	near(IceSheet.lookup(0.0, 1.0), 0.0, 1e-6, "гладкая — без сдвига")
	var m: Texture2D = load(IceSheet.SMOOTH_MASK)
	eq(m.get_image().get_width(), 512, "маска гладкости 512²")
	ok(m.get_image().has_mipmaps(), "маска с mipmap")


## Доля отражения: трещины пропускают, ил гасит, «Экономно» — константа гладкости и × 0,55.
func test_mirror_share() -> void:
	near(IceSheet.mirror(0.9, 1.0, 0.0, 1.0, 1.0, 0.0), 0.9, 1e-6, "гладкая целая грань — вся доля таблицы")
	near(IceSheet.mirror(0.9, 0.0, 0.0, 1.0, 1.0, 0.0), 0.27, 1e-6, "шершавая — 30 %")
	near(IceSheet.mirror(0.9, 1.0, 1.0, 1.0, 1.0, 0.0), 0.0, 1e-6, "открытая трещина не зеркалит")
	near(IceSheet.mirror(0.9, 1.0, 1.0, 0.0, 1.0, 0.0), 0.9, 1e-6, "закрытая шумом сеть — зеркалит")
	near(IceSheet.mirror(0.9, 1.0, 0.0, 1.0, 1.0, 1.0), 0.0, 1e-6, "в густом иле отражения нет")
	near(IceSheet.mirror(0.9, 0.0, 0.0, 1.0, 1.0, 0.0, true), 0.9 * (0.30 + 0.70 * 0.55) * 0.55, 1e-6, "«Экономно»")


func test_scene_ice_reflection() -> void:
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	await frames(1)
	var m := ocean.ice.material_override as ShaderMaterial
	ok(m.get_shader_parameter("reflect_lut") != null and m.get_shader_parameter("smooth_tex") != null, "LUT и маска")
	near(float(m.get_shader_parameter("crit_cos")), IceSheet.CRIT_COS, 1e-6)
	var env := Environment.new()
	ocean.apply_water(env, 20.0, Vector3.ZERO, 0.4)
	near(float(m.get_shader_parameter("reflect_row")), 7.0, 1e-5, "строка по глубине корабля")
	near(float(m.get_shader_parameter("silt_k")), 0.4, 1e-6, "ил — в лёд")
	near(float(m.get_shader_parameter("reflect_lite")), 0.0, 1e-6)
	ocean.set_relief(false)
	near(float(m.get_shader_parameter("reflect_lite")), 1.0, 1e-6, "«Экономно» — без маски")
	ocean.set_relief(true)
	near(float(m.get_shader_parameter("reflect_lite")), 0.0, 1e-6)
	ocean.queue_free()
