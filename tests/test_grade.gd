extends TestCase
## Виньетка и цветокоррекция по глубине ART-065 (`Grade`, `GradeView`, `docs/concept-art/vinyetka.md`).


func _mat(m: Grade.Mix) -> Array:   # строки M из столбцов Basis
	return [[m.m.x.x, m.m.y.x, m.m.z.x], [m.m.x.y, m.m.y.y, m.m.z.y], [m.m.x.z, m.m.y.z, m.m.z.z]]


func test_presets_match_json() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/concept-art/vinyetka-lut.json"))
	eq(data.size(), 4, "четыре таблицы")
	for key: String in data:
		var d: Dictionary = data[key]
		var m := Grade.preset(key)
		var rows := _mat(m)
		for i in 3:
			for j in 3:
				near(rows[i][j], float(d.matrix[i][j]), 1e-6, "%s: M[%d][%d]" % [key, i, j])
			near(m.off[i], float(d.offset[i]), 1e-6, "%s: смещение" % key)
		near(m.strength, float(d.vignette), 1e-6, "%s: сила" % key)


func test_lut_matches_artist_png() -> void:
	# Наша LUT из чисел совпадает с таблицами художника до квантования RGB8.
	for key: String in ["mel", "sredniy", "glubina", "il"]:
		var art := Image.load_from_file("res://docs/concept-art/vinyetka-lut-%s.png" % key)
		eq(art.get_size(), Vector2i(256, 16), "%s: 256×16" % key)
		var ours := Grade.lut_image(Grade.preset(key))
		var worst := 0.0
		for y in 16:
			for x in 256:
				var a := art.get_pixel(x, y)
				var b := ours.get_pixel(x, y)
				worst = maxf(worst, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
		ok(worst <= 1.5 / 255.0, "%s: узлы совпадают (%.4f)" % [key, worst])


func test_blend_by_depth_and_silt() -> void:
	var mel := Grade.preset("mel")
	var mid := Grade.preset("sredniy")
	var deep := Grade.preset("glubina")
	near(Grade.blend(0.0).strength, 0.18, 1e-6, "у льда — мель")
	near(Grade.blend(10.0).strength, 0.18, 1e-6, "до 10 м — мель")
	near(Grade.blend(25.0).strength, 0.26, 1e-6, "на 25 м — средний")
	near(Grade.blend(45.0).strength, 0.34, 1e-6, "на 45 м — глубина")
	near(Grade.blend(90.0).strength, 0.34, 1e-6, "и глубже")
	near(Grade.blend(17.5).strength, lerpf(mel.strength, mid.strength, 0.5), 1e-6, "середина 10…25 — пополам")
	near(Grade.blend(35.0).m.x.x, lerpf(mid.m.x.x, deep.m.x.x, 0.5), 1e-6, "середина 25…45 — пополам")
	near(Grade.blend(45.0, 1.0).strength, 0.38, 1e-6, "в иле — иловая")
	near(Grade.blend(8.0, 0.5).strength, lerpf(0.18, 0.38, 0.5), 1e-6, "ил поверх глубины")
	# без скачков: шаг 0,1 м меняет смесь мало
	var prev := Grade.blend(0.0)
	for i in 1000:
		var cur := Grade.blend(i * 0.1)
		ok(absf(cur.strength - prev.strength) < 0.002, "плавно на %.1f м" % (i * 0.1))
		prev = cur


func test_identity_is_identity() -> void:
	var id := Grade.Mix.new()
	var img := Grade.lut_image(id)
	near(img.get_pixel(16 * 5 + 3, 7).r, roundf(3.0 / 15.0 * 255.0) / 255.0, 1e-6, "нейтральная LUT — тождество (r)")
	near(img.get_pixel(16 * 5 + 3, 7).b, roundf(5.0 / 15.0 * 255.0) / 255.0, 1e-6, "тождество (b)")


func test_centre_open_edges_colder() -> void:
	var m := Grade.blend(45.0)
	var grey := Color(0.2, 0.22, 0.25)
	near(Grade.edge(Vector2(0.5, 0.5)), 0.0, 1e-6, "центр открыт")
	near(Grade.edge(Vector2(0.0, 0.0)), 1.0, 1e-6, "в углу — полная сила")
	var c := Grade.shade(grey, Vector2(0.5, 0.5), m)
	ok(Grade.luma(Vector3(c.r, c.g, c.b)) >= Grade.luma(Vector3(grey.r, grey.g, grey.b)) - 1e-5, "в центре не темнее")
	var k := Grade.shade(grey, Vector2(0.0, 0.0), m)
	ok(k.r < c.r and k.g < c.g and k.b < c.b, "угол темнее")
	ok(k.r / c.r < k.b / c.b, "и холоднее: красный гаснет сильнее синего")
	ok(c.r <= grey.r + 0.02, "без красного (#129)")


func test_lights_and_black_protected() -> void:
	var m := Grade.blend(45.0)
	var corner := Vector2(0.02, 0.05)
	var white := Color(0.95, 0.95, 0.9)
	var w := Grade.shade(white, corner, m)
	near(w.r, white.r, 1e-5, "пятно прожектора не тускнеет")
	var glow := Color("67DDEB")   # голубые огни пультов, биолюм
	var g := Grade.shade(glow, corner, m)
	near(g.g, glow.g, 1e-5, "голубые огни не тускнеют")
	near(g.b, glow.b, 1e-5, "голубые огни не тускнеют (b)")
	var black := Color(0.005, 0.006, 0.008)
	var b := Grade.shade(black, corner, m)
	ok(absf(b.r - black.r) < 0.01 and absf(b.b - black.b) < 0.03, "чёрное не получает рамку")


func test_lite_only_oval() -> void:
	var m := Grade.blend(45.0)
	var grey := Color(0.2, 0.22, 0.25)
	var c := Grade.shade(grey, Vector2(0.5, 0.5), m, true)
	ok(c.is_equal_approx(grey), "«Экономно»: в центре без LUT — исходный цвет")
	var k := Grade.shade(grey, Vector2(0.0, 0.0), m, true)
	near(k.r, grey.r * (1.0 - Grade.LITE), 1e-5, "в углу — овал 0,10")
	var white := Color(0.9, 0.9, 0.9)   # «Экономно» — умножение кадра без чтения: яркое тоже под овалом (#842)
	var kw := Grade.shade(white, Vector2(0.0, 0.0), m, true)
	near(kw.r, white.r * (1.0 - Grade.LITE), 1e-5, "яркое в углу — тот же множитель")


func test_view_in_scene() -> void:
	var m: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	await frames(2)
	var v := m.grade
	ok(v != null and v.get_parent() == m, "узел в сцене")
	eq(v.layer, -1, "слой −1")
	var ui := m.get_node("Интерфейс") as CanvasLayer
	ok(ui.layer > v.layer, "интерфейс рисуется после прохода")
	eq(v.rect.mouse_filter, Control.MOUSE_FILTER_IGNORE, "касания проходят насквозь")
	eq(v.tex.get_size(), Vector2(256, 16), "одна активная LUT 256×16")
	var before := v.rebuilds
	m._place_camera()
	m._place_camera()
	eq(v.rebuilds, before, "на месте LUT не пересобирается")
	m.helm.pos.y = -60.0
	m._place_ship()
	m._place_camera()
	ok(v.rebuilds > before, "глубже — пересобрана")
	near(float(v.mat.get_shader_parameter("strength")), 0.34, 1e-4, "сила по глубине камеры")
	near(v.mix.m.x.x, 0.82, 1e-3, "LUT собрана из глубинной таблицы")
	m.silt.k = 1.0
	m._place_camera()
	near(float(v.mat.get_shader_parameter("strength")), 0.38, 1e-4, "в иле — иловая")
	v.set_lite(true)
	near(float(v.mat.get_shader_parameter("strength")), Grade.LITE, 1e-6, "«Экономно» — 0,10")
	m.queue_free()
	await frames(1)
