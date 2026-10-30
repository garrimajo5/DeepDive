extends TestCase
## Шум и рельеф совпадают с браузерной версией: числа сняты из js/ прототипа (node, util.js и world.js).


func test_noise_as_browser() -> void:
	near(HashNoise.value(0.0, 0.0), 0.0, 1e-9, "noise(0,0)")
	near(HashNoise.value(0.5, 0.25), 0.326249829522, 1e-9, "noise(0.5,0.25)")
	near(HashNoise.value(-3.7, 12.2), 0.492614037677, 1e-9, "noise(-3.7,12.2)")
	near(HashNoise.value(123.4, -56.7), 0.574988821539, 1e-9, "noise(123.4,-56.7)")
	near(HashNoise.value(-250.0, 300.0), 0.076521619707, 1e-9, "noise(-250,300)")


func test_fbm_as_browser() -> void:
	near(HashNoise.fbm(0.0, 0.0, 4), 0.332220742818, 1e-9, "fbm(0,0)")
	near(HashNoise.fbm(123.4 * 0.006, -56.7 * 0.006, 4), 0.558210456168, 1e-9, "fbm(123.4,-56.7)")
	near(HashNoise.fbm(-250.0 * 0.006, 300.0 * 0.006, 4), 0.539113016285, 1e-9, "fbm(-250,300)")


func test_height_as_browser() -> void:
	near(Seabed.height(0, 95), -42.382790764, 1e-6, "старт корабля")
	near(Seabed.height(-10, -10), -44.238212313, 1e-6, "центр плато")
	near(Seabed.height(200, 0), -89.143968672, 1e-6, "склон на востоке")
	near(Seabed.height(-120, 40), -38.740821353, 1e-6, "гряды")
	near(Seabed.height(320, -10), -79.489483570, 1e-6, "край карты")
	near(Seabed.height(60, -200), -54.042696514, 1e-6, "юг")


func test_bottom_never_reaches_ice() -> void:
	for i in 40:
		var x := -350.0 + i * 17.5
		for j in 40:
			ok(Seabed.height(x, -350.0 + j * 17.5) <= Seabed.TOP, "дно выше %.0f м" % Seabed.TOP)


func test_grid_faces_up_and_colors() -> void:
	var a := Seabed.build_arrays(8, 80.0)
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	eq(pos.size(), 81, "вершины 9×9")
	eq(idx.size(), 8 * 8 * 6, "индексы")
	# Godot: лицевая сторона — по часовой при взгляде на неё; сверху нормаль треугольника (b−a)×(c−a) смотрит вниз
	for t in range(0, idx.size(), 3):
		var n := (pos[idx[t + 1]] - pos[idx[t]]).cross(pos[idx[t + 2]] - pos[idx[t]])
		if not ok(n.y < 0.0, "треугольник %d смотрит вниз" % (t / 3)):
			break
	var col: PackedColorArray = a[Mesh.ARRAY_COLOR]
	ok(col[40].r > 0.0 and col[40].r < 1.0, "цвет дна в 0..1")


func test_water_darker_with_depth() -> void:
	ok(Seabed.Water.fog_color(90.0).v < Seabed.Water.fog_color(5.0).v, "в глубине темнее")
	ok(Seabed.Water.fog_density(90.0) > Seabed.Water.fog_density(5.0), "туман гуще")
	near(Seabed.Water.k(5.0), 0.0, 1e-9, "у льда k = 0")
	near(Seabed.Water.k(120.0), 1.0, 1e-9, "в глубине k = 1")


func test_seabed_uses_detail_shader() -> void:
	var ov := OceanView.new()
	tree.root.add_child(ov)
	await frames(1)
	var mat := ov.seabed.mesh.surface_get_material(0)
	ok(mat is ShaderMaterial, "материал дна — шейдер детализации, не плоский цвет вершин")
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader:
		ok((mat as ShaderMaterial).shader.code.contains("Дно отмели"), "назначен шейдер дна")
	ov.queue_free()


## ART-059: ключи таблицы совпадают с принятым `voda-glubina.json` и стоят как есть.
func test_water_keys_from_art059() -> void:
	var f := FileAccess.open("res://docs/concept-art/voda-glubina.json", FileAccess.READ)
	ok(f != null, "voda-glubina.json читается")
	var keys: Array = JSON.parse_string(f.get_as_text())
	eq(keys.size(), Seabed.Water.ART059, "десять ключей ART-059 — первые в таблице")
	for key in keys:
		var d: float = key["depth"]
		var c := Color(key["fog"])
		ok(Seabed.Water.fog_color(d).is_equal_approx(c), "цвет на %d м" % d)
		near(Seabed.Water.fog_density(d), key["density"], 1e-6, "плотность на %d м" % d)
		near(Seabed.Water.ambient(d), key["ambient"], 1e-6, "рассеянный на %d м" % d)
		near(Seabed.Water.sun(d), key["sun"], 1e-6, "солнце на %d м" % d)
		near(Seabed.Water.exposure(d), key["exposure"], 1e-6, "экспозиция на %d м" % d)


func test_water_smooth_and_clamped() -> void:
	var prev_v := 2.0
	var prev_amb := 2.0
	var worst := 0.0
	var d := 0.0
	while d <= 320.0:
		var c := Seabed.Water.fog_color(d)
		ok(c.v <= prev_v + 1e-6, "цвет не светлеет вглубь (%.1f м)" % d)
		ok(Seabed.Water.ambient(d) <= prev_amb + 1e-9, "рассеянный не растёт (%.1f м)" % d)
		if prev_v < 2.0:
			worst = maxf(worst, prev_v - c.v)
		prev_v = c.v
		prev_amb = Seabed.Water.ambient(d)
		d += 0.5
	ok(worst < 0.02, "без скачков: шаг яркости за 0,5 м %.4f" % worst)
	near(Seabed.Water.sun(400.0), Seabed.Water.sun(300.0), 1e-9, "ниже 300 м — как на 300")
	near(Seabed.Water.ambient(400.0), Seabed.Water.ambient(300.0), 1e-9, "рассеянный ниже 300 м — как на 300")
	near(Seabed.Water.ambient(-3.0), Seabed.Water.ambient(0.0), 1e-9, "выше льда — как у льда")
	# цвет между ключами смешан в линейном свете: середина темнее, чем среднее sRGB
	var a := Seabed.Water.fog_color(90.0)
	var b := Seabed.Water.fog_color(60.0)
	var mid := Seabed.Water.fog_color(75.0)
	near(mid.srgb_to_linear().b, (a.srgb_to_linear().b + b.srgb_to_linear().b) / 2.0, 1e-4, "середина — в линейном")


## #822: склон до 300 м — вода темнеет и дальше 120 м (раньше там стоял clamp), плавно и без красного.
func test_water_below_120() -> void:
	ok(Seabed.Water.fog_color(300.0).v < Seabed.Water.fog_color(120.0).v - 0.02, "на 300 м туман темнее, чем на 120")
	ok(Seabed.Water.ambient(300.0) < Seabed.Water.ambient(120.0) * 0.5, "рассеянный на 300 м слабее вдвое")
	ok(Seabed.Water.ambient(200.0) < Seabed.Water.ambient(120.0), "на 200 м уже темнее, чем на 120")
	ok(Seabed.Water.fog_density(300.0) > Seabed.Water.fog_density(120.0), "вода гуще")
	ok(Seabed.Water.fog_density(300.0) < 0.03, "прожектор ещё достаёт склон: плотность < 0,03")
	near(Seabed.Water.sun(300.0), 0.0, 1e-9, "солнца на 300 м нет")
	var c := Seabed.Water.fog_color(300.0)
	ok(c.b >= c.g and c.g >= c.r and c.v > 0.0, "оттенок тот же — синий, не серый и не чёрный ноль")
	var keys: Array = Seabed.Water.KEYS
	eq(keys[keys.size() - 1][0], 300.0, "последний ключ — 300 м")


## OceanView.apply_water ставит конечные значения без прежних множителей 0,9 / 0,7 / 1,2.
func test_apply_water_final_values() -> void:
	var ov := OceanView.new()
	tree.root.add_child(ov)
	await frames(1)
	var env := Environment.new()
	for depth in [8.0, 20.0, 45.0, 90.0]:
		ov.apply_water(env, depth, Vector3.ZERO)
		near(env.fog_density, Seabed.Water.fog_density(depth), 1e-6, "туман на %d м" % depth)
		near(env.ambient_light_energy, Seabed.Water.ambient(depth), 1e-6, "рассеянный на %d м" % depth)
		near(env.tonemap_exposure, Seabed.Water.exposure(depth), 1e-6, "экспозиция на %d м" % depth)
		near(ov.sun.light_energy, Seabed.Water.sun(depth), 1e-6, "солнце на %d м" % depth)
	ov.apply_water(env, 20.0, Vector3.ZERO, 1.0)
	near(env.fog_density, Seabed.Water.fog_density(20.0) + 0.03, 1e-6, "ил гуще на 0,03 (ART-048)")
	ok(env.fog_light_color.is_equal_approx(Seabed.Water.fog_color(20.0).lerp(Silt.FAR_COLOR, 0.75)), "ил главнее цвета глубины")
	ov.queue_free()
	await frames(1)


## #832: за границей корки у Спуска 10 дно меняет цвет — западнее как было, к востоку серая порода и бледные пятна.
func test_crust_color_at_brink() -> void:
	var base := Color(0.08, 0.13, 0.22)
	eq(Seabed.crust_tint(base, 300.0, 200.0), base, "проход 60 м — цвет как был")
	var z := 200.0
	var b := EcoBrink.border_x(z)
	eq(Seabed.crust_tint(base, b - 1.0, z), base, "западнее границы — без корки")
	var far := Seabed.crust_tint(base, b + EcoBrink.FULL + 5.0, z)
	ok(far.get_luminance() > base.get_luminance() + 0.02, "за границей дно светлее тёмной глубины")
	ok(absf(far.b - far.r) < absf(base.b - base.r), "порода серее синей глубины")
	# пятна корки бледнее голой породы
	var lit := 0
	var bare := 0
	for i in 60:
		var x := b + EcoBrink.FULL + 2.0 + i * 1.5
		var p := EcoBrink.patch(x, z)
		var c := Seabed.crust_tint(base, x, z)
		if p > 0.9:
			lit += 1
			ok(c.get_luminance() > Seabed.CRUST_ROCK.get_luminance() * 0.9, "пятно корки бледнее")
		elif p < 0.05:
			bare += 1
	ok(lit + bare > 0, "есть и пятна, и голая порода на участке")
	# в цвете вершин сетки (color_at) корка тоже есть
	var y := Seabed.height(b + EcoBrink.FULL + 10.0, z)
	var with := Seabed.color_at(b + EcoBrink.FULL + 10.0, y, z, 1.0)
	ok(with.b - with.r < 0.14 * 1.12, "color_at за границей — не синяя глубина")
