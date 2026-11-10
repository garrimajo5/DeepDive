extends TestCase
## Декали дна по ART-066 (`Seabed.Marks`, материал «Дна» `shaders/seabed.gdshader`): атлас 4×4 проекцией world.xz,
## штампы по клеткам 4 × 4 м в двух слоях, места по грунту и уклону, разряды не в фоне, затухания, «Экономно».

const D := Seabed.Marks


func test_atlas_imported() -> void:
	var t: Texture2D = load(D.ATLAS)
	ok(t != null, D.ATLAS)
	var img := t.get_image()
	eq(img.get_width(), 1024, "атлас 1024²")
	ok(img.has_mipmaps(), "с mipmap")
	ok(img.detect_alpha() != Image.ALPHA_NONE, "форма — в альфе")
	ok(FileAccess.get_file_as_bytes(D.ATLAS).size() < 1024 * 1024, "PNG ≤ 1 МБ")


func test_deterministic_and_fraction() -> void:
	var acc := 0
	var n := 0
	var cats := [0, 0, 0, 0, 0]
	for iz in 60:
		for ix in 60:
			var x := (ix - 30) * D.CELL + 1.3
			var z := (iz - 30) * D.CELL + 2.1
			for layer in D.LAYERS:
				var c := D.candidate(x, z, layer)
				var c2 := D.candidate(x, z, layer)
				eq(c, c2, "одно и то же место — тот же штамп")
				n += 1
				if c.accept:
					acc += 1
				cats[c.cat] += 1
				ok(not D.SCORCH.has(c.index), "разряды в фон не идут")
				ok(c.index >= 0 and c.index <= 12, "ячейка фона 0…12")
				ok(c.size >= D.SIZE.x and c.size <= D.SIZE.y, "размер 1,55…2,4 м")
	near(float(acc) / n, D.ACCEPT, 0.03, "доля клеток со штампом ≈ 0,72")
	near(float(cats[D.Cat.TRACK]) / n, 0.27, 0.03, "следы 27 %")
	near(float(cats[D.Cat.DENT]) / n, 0.13, 0.03, "вмятины 13 %")
	near(float(cats[D.Cat.SILT]) / n, 0.27, 0.03, "ил 27 %")
	near(float(cats[D.Cat.SHELL]) / n, 0.18, 0.03, "ракушечник 18 %")
	near(float(cats[D.Cat.MOSS]) / n, 0.15, 0.03, "мох 15 %")
	ok(D.candidate(1.0, 1.0, 0).cell != D.candidate(1.0, 1.0, 1).cell
			or D.candidate(1.0, 1.0, 0).centre != D.candidate(1.0, 1.0, 1).centre, "слои не совпадают")


## Повёрнутый квадрат с наибольшим сдвигом остаётся в своей клетке — шейдер смотрит только её.
func test_stamp_inside_cell() -> void:
	var reach := D.SIZE.y * 0.5 * sqrt(2.0) + D.JITTER
	ok(reach < D.CELL * 0.5, "полудиагональ + сдвиг < полклетки: %.2f" % reach)
	var c := D.candidate(10.3, -7.9, 0)
	var st := D.stamp_uv(c.centre.x, c.centre.y, c)
	ok(st.is_equal_approx(Vector2(0.5, 0.5)), "центр штампа — середина ячейки атласа")
	ok(D.atlas_uv(5, Vector2(0.5, 0.5)).is_equal_approx(Vector2(1.5, 1.5) / 4.0), "ячейка 5 — второй ряд, второй столбец")
	ok(D.atlas_uv(13, Vector2.ZERO).is_equal_approx(Vector2(0.25, 0.75)), "ячейка 13 — нижний ряд")


func test_habitat_and_fade() -> void:
	near(D.habitat(D.Cat.TRACK, [1.0, 0.0, 0.0], 1.0, 0.0, 0.0), 1.0, 1e-6, "следы — на ровном песке")
	near(D.habitat(D.Cat.TRACK, [1.0, 0.0, 0.0], 0.8, 0.0, 0.0), 0.0, 1e-6, "на уклоне следов нет")
	near(D.habitat(D.Cat.SILT, [1.0, 0.0, 0.0], 1.0, 0.0, 0.0), 0.3, 1e-6, "ил на песке слабее")
	near(D.habitat(D.Cat.SILT, [0.0, 1.0, 0.0], 1.0, 0.0, 0.0), 1.0, 1e-6, "ил — в карманах ила")
	near(D.habitat(D.Cat.SHELL, [0.0, 0.0, 1.0], 1.0, 0.0, 0.0), 1.0, 1e-6, "ракушечник — на гальке")
	near(D.habitat(D.Cat.DENT, [0.0, 0.0, 1.0], 1.0, 0.0, 0.0), 0.0, 1e-6, "вмятин на гальке нет")
	near(D.fade(5.0, 1.0), 1.0, 1e-6, "вблизи полные")
	near(D.fade(45.0, 1.0), 0.0, 1e-6, "к 45 м гаснут")
	near(D.fade(5.0, 0.4), 0.0, 1e-6, "на стене не лежат")
	near(D.fade(25.0, 1.0, true), 0.0, 1e-6, "«Экономно» — к 25 м")
	ok(D.fade(20.0, 1.0) > 0.5, "обычно на 20 м ещё видны")


## Видная декаль в точке: альфа атласа × место (ровный песок) × сила.
func _visible(x: float, z: float, img: Image, lite: bool) -> bool:
	for s in D.at(x, z, lite):
		var uv: Vector2 = D.atlas_uv(s.index, s.st)
		var a := img.get_pixel(clampi(int(uv.x * 1024.0), 0, 1023), clampi(int(uv.y * 1024.0), 0, 1023)).a
		var hab := D.habitat(s.cat, [1.0, 0.0, 0.0], 1.0, x, z)
		if a * hab * D.STRENGTH > 0.3:
			return true
	return false


## Плотность поднята против ART-066 (один слой): в пятне прожектора вплотную (круг 2,5 м) обычно есть декаль.
func test_spot_has_mark() -> void:
	var img: Image = (load(D.ATLAS) as Texture2D).get_image()
	img.decompress()
	var spots := 0
	var hit := 0
	var hit_lite := 0
	for j in 12:
		for i in 12:
			var cx := -150.0 + i * 23.7
			var cz := -140.0 + j * 21.3
			spots += 1
			var seen := false
			var seen_lite := false
			for v in 21:
				for u in 21:
					var x := cx + (u - 10) * 0.25
					var z := cz + (v - 10) * 0.25
					if (x - cx) * (x - cx) + (z - cz) * (z - cz) > 2.5 * 2.5:
						continue
					if not seen and _visible(x, z, img, false):
						seen = true
					if not seen_lite and _visible(x, z, img, true):
						seen_lite = true
			if seen:
				hit += 1
			if seen_lite:
				hit_lite += 1
	var k := float(hit) / spots
	print("  пятен с декалью: %.2f, «Экономно» %.2f" % [k, float(hit_lite) / spots])
	ok(k >= 0.7, "в пятне 2,5 м обычно есть декаль: %.2f" % k)
	ok(float(hit_lite) / spots < k, "«Экономно» — реже")


## Шейдер считает те же числа, что Seabed.Marks.
func test_shader_mirrors_core() -> void:
	var src := FileAccess.get_file_as_string("res://shaders/seabed.gdshader")
	ok(src.contains("ice_hash2(c.x + 9973 * k, c.y - 7919 * k)"), "тот же хеш клетки")
	for t in ["pick < 0.27", "pick < 0.40", "pick < 0.67", "pick < 0.85"]:
		ok(src.contains(t), "границы категорий: " + t)
	for cat in D.CATS:
		ok(cat[0] in [0.27, 0.40, 0.67, 0.85, 1.0], "доли категорий по ART-066")
	ok(src.contains("ice_value(p * 0.03 + vec2(7.0, 0.0))"), "маска мха")
	ok(src.contains("decal_atlas : hint_default_white, filter_linear_mipmap, repeat_disable"),
			"атлас — данные без sRGB, без анизотропии (не тянет соседнюю ячейку)")
	ok(src.contains("smoothstep(0.0, decal_edge, min(e.x, e.y))"), "края квадрата гаснут — рамки нет")


## Края квадрата лежат в пустом поле ячейки: гашение рамки не трогает рисунок.
func test_edge_in_padding() -> void:
	ok(D.EDGE < 20.0 / 256.0, "гашение уже поля 20 px")
	var img: Image = (load(D.ATLAS) as Texture2D).get_image()
	img.decompress()
	var worst := 0.0
	for cell in 16:
		var ox := (cell % 4) * 256
		var oy := (cell / 4) * 256
		for t in 256:
			for d in 18:
				for p in [Vector2i(ox + t, oy + d), Vector2i(ox + t, oy + 255 - d), Vector2i(ox + d, oy + t), Vector2i(ox + 255 - d, oy + t)]:
					worst = maxf(worst, img.get_pixelv(p).a)
	ok(worst < 0.05, "у края ячейки атлас пуст: альфа ≤ %.3f" % worst)


func test_scene_material() -> void:
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	await frames(1)
	var m := ocean.seabed_mat
	ok(m.get_shader_parameter("decal_atlas") != null, "атлас в материале дна")
	near(float(m.get_shader_parameter("decals")), 1.0, 1e-6, "декали включены")
	near(float(m.get_shader_parameter("decal_cell")), D.CELL, 1e-6)
	near(float(m.get_shader_parameter("decal_layers")), 2.0, 1e-6, "два слоя")
	near(float(m.get_shader_parameter("decal_accept")), D.ACCEPT, 1e-6)
	eq(m.get_shader_parameter("decal_fade"), D.FADE)
	near(float(m.get_shader_parameter("decal_edge")), D.EDGE, 1e-6)
	eq(ocean.seabed.mesh.get_surface_count(), 1, "тот же меш — без новых вызовов")
	ocean.set_decals_lite(true)
	near(float(m.get_shader_parameter("decal_layers")), 1.0, 1e-6, "«Экономно» — один слой")
	near(float(m.get_shader_parameter("decal_accept")), D.LITE_ACCEPT, 1e-6, "и реже")
	eq(m.get_shader_parameter("decal_fade"), D.LITE_FADE, "и ближе")
	ocean.queue_free()
	await frames(1)
