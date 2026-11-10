extends TestCase
## Взвесь за бортом по ART-058: доли кадров атласа, размеры по семьям, затухания, «Экономно», узел в OceanView.


func test_shares_by_family() -> void:
	var c := MarineSnow.cdf()
	eq(c.size(), 15, "15 ячеек, пустая 15-я не выбирается")
	near(c[14], 1.0, 1e-6, "доли в сумме — 1")
	var fam := {}
	for i in 15:
		var f := MarineSnow.family(i)
		fam[f] = fam.get(f, 0.0) + MarineSnow.share(i)
	near(fam[MarineSnow.Family.FLAKE], 0.54, 1e-5, "хлопья 54 %")
	near(fam[MarineSnow.Family.THREAD], 0.12, 1e-5, "нити 12 %")
	near(fam[MarineSnow.Family.DUST], 0.30, 1e-5, "пыль 30 %")
	near(fam[MarineSnow.Family.BUBBLE], 0.04, 1e-5, "пузыри 4 %")
	eq(MarineSnow.share(15), 0.0, "пустой кадр")


func test_cell_of_uniform_r() -> void:
	var counts := {}
	var n := 3000
	for k in n:
		var cell := MarineSnow.cell_of((k + 0.5) / n)
		ok(cell >= 0 and cell <= 14, "ячейка в атласе")
		counts[cell] = counts.get(cell, 0) + 1
	eq(MarineSnow.cell_of(0.0), 0, "r = 0 — первый хлопок")
	eq(MarineSnow.cell_of(0.9999), 14, "r → 1 — последний пузырь")
	near(counts[0] / float(n), 0.09, 0.002, "хлопок 9 %")
	near(counts[9] / float(n), 0.10, 0.002, "пылинка 10 %")
	near(counts[12] / float(n), 0.04 / 3.0, 0.002, "пузырь ~1,3 %")
	eq(MarineSnow.cell_uv(6), Vector2(0.5, 0.25), "UV ячейки 6 — третья в второй строке")


func test_card_sizes() -> void:
	near(MarineSnow.card_size(0, 0.0), 0.025 / 0.78, 1e-6, "хлопья от 2,5 см формы")
	near(MarineSnow.card_size(3, 1.0), 0.07 / 0.78, 1e-6, "до 7 см")
	near(MarineSnow.card_size(10, 1.0), 0.018 / 0.55, 1e-6, "пыль до 1,8 см")
	ok(MarineSnow.card_size(7, 1.0) > MarineSnow.card_size(10, 1.0), "нить больше пылинки")


func test_fade() -> void:
	eq(MarineSnow.fade(0.0, 10.0), 0.0, "только родилась — не видна")
	eq(MarineSnow.fade(0.5, 10.0), 1.0, "середина жизни — видна")
	eq(MarineSnow.fade(1.0, 10.0), 0.0, "к концу жизни гаснет")
	eq(MarineSnow.fade(0.5, 0.4), 0.0, "у самой камеры не видна")


func test_ocean_snow_node() -> void:
	var o := OceanView.new()
	tree.root.add_child(o)
	await frames(1)
	eq(o.snow.amount, MarineSnow.AMOUNT, "420 частиц")
	eq(o.snow.emission_box_extents, MarineSnow.EXTENTS, "объём 56 × 28 × 56 м")
	ok(not o.snow.local_coords, "мировые координаты — корабль плывёт сквозь взвесь")
	ok(o.snow_mat.shader.resource_path.ends_with("marine_snow.gdshader"), "шейдер взвеси")
	ok(o.snow_mat.get_shader_parameter("atlas") != null, "атлас ART-058")
	eq(o.snow.anim_offset_max, 1.0, "случайное r 0…1 для кадра")
	o.set_snow_lite(true)
	eq(o.snow.amount, MarineSnow.AMOUNT_LITE, "«Экономно» — 180")
	eq(o.snow_mat.get_shader_parameter("spin_k"), 0.0, "«Экономно» — без вращения")
	o.set_snow_lite(false)
	eq(o.snow.amount, MarineSnow.AMOUNT, "обратно 420")
	o.queue_free()
	await frames(1)
