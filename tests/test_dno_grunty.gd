extends TestCase
## Грунты дна по ART-060 (`Seabed.Ground`, материал «Дна» `shaders/seabed.gdshader`): песок, ил и галька по world.xz / 2,
## веса по уклону, глубине и шуму, цвет — множитель вокруг серого, нормали в мировом базисе, затухания вдали;
## «Экономно» — только цвет.

const G := Seabed.Ground


func test_weights_sum_and_range() -> void:
	for j in 30:
		for i in 30:
			var x := -300.0 + i * 20.0 + 0.3
			var z := -300.0 + j * 20.0 + 0.7
			for ny in [1.0, 0.95, 0.85, 0.7, 0.5]:
				for depth in [8.0, 25.0, 60.0, 100.0]:
					var w: Array = G.weights(x, z, ny, depth)
					near(w[0] + w[1] + w[2], 1.0, 1e-6, "сумма весов 1")
					ok(w[0] >= -1e-6 and w[1] >= -1e-6 and w[2] >= -1e-6, "веса ≥ 0")


## Ил — карманы на ровном дне 18–55 м, галька — умеренный уклон, песок — остальное; границы плавные.
func test_weights_by_place() -> void:
	var silt_deep := 0.0
	var silt_shallow := 0.0
	var pebble_slope := 0.0
	var pebble_flat := 0.0
	var sand_flat := 0.0
	var n := 0
	for j in 40:
		for i in 40:
			var x := -200.0 + i * 10.0 + 0.41
			var z := -200.0 + j * 10.0 + 0.13
			silt_deep += G.weights(x, z, 0.99, 35.0)[1]
			silt_shallow += G.weights(x, z, 0.99, 8.0)[1]
			pebble_slope += G.weights(x, z, 0.75, 35.0)[2]
			pebble_flat += G.weights(x, z, 0.99, 35.0)[2]
			sand_flat += G.weights(x, z, 0.99, 8.0)[0]
			n += 1
	ok(silt_deep / n > 0.12, "на 35 м ил карманами есть: %.2f" % (silt_deep / n))
	ok(silt_deep / n < 0.7, "но не сплошь: %.2f" % (silt_deep / n))
	ok(silt_deep > silt_shallow * 1.5, "на глубине ила больше, чем на мели")
	ok(pebble_slope > pebble_flat * 1.5, "галька — на склоне больше, чем на ровном")
	ok(sand_flat / n > 0.6, "мель на ровном — больше песок: %.2f" % (sand_flat / n))
	var w_steep: Array = G.weights(10.3, 20.7, 0.3, 35.0)
	near(w_steep[1], 0.0, 1e-6, "ил на крутом не лежит")
	near(G.detail_k(0.3), 0.0, 1e-6, "на крутом склоне детали гаснут — скальный цвет")
	near(G.detail_k(1.0), 1.0, 1e-6)


func test_fades() -> void:
	near(G.normal_fade(0.0), 1.0, 1e-6)
	near(G.normal_fade(8.0), 1.0, 1e-6, "вблизи нормали полные")
	near(G.normal_fade(35.0), 0.0, 1e-6, "к 35 м гаснут")
	near(G.color_fade(12.0), 1.0, 1e-6)
	near(G.color_fade(55.0), 0.0, 1e-6, "цвет деталей — к 55 м")
	ok(G.color_fade(30.0) > G.normal_fade(30.0), "цвет держится дальше нормалей")


func test_tint_around_grey() -> void:
	var base := Color(0.6, 0.5, 0.4)
	eq(G.tint(base, Color(0.5, 0.5, 0.5), 1.0), base, "серый 50 % — цвет как был (палитру даёт color_at)")
	eq(G.tint(base, Color(0.9, 0.1, 0.5), 0.0), base, "сила 0 — без изменений")
	near(G.tint(base, Color(0.6, 0.5, 0.5), 1.0).r, 0.6 * 1.2, 1e-6, "2·tsvet — множитель")


## Базис нормалей мировой: на ровном дне T = +X, B = −Z; +Y карты — к −Z мира, UV — world.xz / 2.
func test_basis_and_uv() -> void:
	var b: Basis = G.basis(Vector3.UP)
	ok(b.x.is_equal_approx(Vector3.RIGHT), "T — +X")
	ok(b.y.is_equal_approx(Vector3(0, 0, -1)), "B — к −Z")
	var slope := Vector3(0.4, 0.8, 0.3).normalized()
	var bs: Basis = G.basis(slope)
	near(bs.x.dot(slope), 0.0, 1e-6, "T на поверхности")
	near(bs.y.dot(slope), 0.0, 1e-6, "B на поверхности")
	near(bs.x.length(), 1.0, 1e-6)
	ok(G.uv(4.0, 6.0, 0).is_equal_approx(Vector2(2.0, 3.0)), "песок — без сдвига, плитка 2 м")
	ok(not G.uv(4.0, 6.0, 1).is_equal_approx(G.uv(4.0, 6.0, 2)), "у грунтов свой сдвиг — повтор не совпадает")
	near(G.TILE, 2.0, 1e-6)
	eq(G.NORMAL_K, [0.42, 0.25, 0.55], "сила нормалей по ART-060")


func test_maps_imported() -> void:
	for kind in 3:
		for map in 3:
			var p: String = G.path(kind, map)
			var t: Texture2D = load(p)
			ok(t != null, p)
			var img := t.get_image()
			eq(img.get_width(), 1024, "%s 1024²" % p)
			ok(img.has_mipmaps(), "%s с mipmap" % p)


func test_scene_seabed_material() -> void:
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	await frames(1)
	var m := ocean.seabed_mat
	eq(m.shader.resource_path, "res://shaders/seabed.gdshader")
	for name in ["sand", "silt", "pebble"]:
		for map in ["tsvet", "normali", "orm"]:
			ok(m.get_shader_parameter("%s_%s" % [name, map]) != null, "%s_%s" % [name, map])
	near(float(m.get_shader_parameter("ground")), 1.0, 1e-6, "грунты включены")
	near(float(m.get_shader_parameter("tile")), G.TILE, 1e-6)
	eq(m.get_shader_parameter("off_silt"), G.OFFSET[1])
	eq(m.get_shader_parameter("off_pebble"), G.OFFSET[2])
	eq(G.OFFSET[0], Vector2.ZERO, "песок в шейдере — без сдвига")
	near(float(m.get_shader_parameter("silt_scale")), G.SILT_SCALE, 1e-6, "шум ила — как Seabed.Ground")
	near(float(m.get_shader_parameter("pebble_scale")), G.PEBBLE_SCALE, 1e-6)
	near(float(m.get_shader_parameter("bump")), G.BUMP, 1e-6, "процедурный рельеф ослаблен")
	eq(ocean.seabed.mesh.get_surface_count(), 1, "один меш, одна поверхность — один вызов")
	near(float(m.get_shader_parameter("relief")), 1.0, 1e-6)
	ocean.set_relief(false)
	near(float(m.get_shader_parameter("relief")), 0.0, 1e-6, "«Экономно» — без нормалей и ORM")
	near(float(m.get_shader_parameter("ground")), 1.0, 1e-6, "цвет грунтов остаётся")
	ocean.queue_free()
	await frames(1)
