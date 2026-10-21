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
