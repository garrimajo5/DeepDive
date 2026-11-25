extends TestCase
## Рябь на песке и крупные пятна тона дна (#2108, `Seabed.Ripple`, материал «Дна» `shaders/seabed.gdshader`):
## полосы от течения на плоском дне (гаснут 20…80 м), пятна тона ~40 м (держатся до 170 м), гребень полосы в
## микрорельефе гаснет вместе с `relief` («Экономно»). Шейдер считает то же двойником `HashNoise` (`ice_fbm2`).

const R := Seabed.Ripple


## Полоса детерминирована и в пределах −1…1; на транзекте 120 м есть и гребни, и впадины, и десятки смен знака
## (полосы с длиной волны WAVE, а не редкие пятна).
func test_band_deterministic_and_stripes() -> void:
	var sign_changes := 0
	var prev := 0.0
	var hi := -1.0
	var lo := 1.0
	for i in 240:
		var x := -60.0 + i * 0.5
		var z := 40.0 + i * 0.13
		var b := R.band(x, z)
		near(b, R.band(x, z), 0.0, "детерминировано")
		ok(b >= -1.0 and b <= 1.0, "полоса в −1…1")
		hi = maxf(hi, b)
		lo = minf(lo, b)
		if i > 0 and signf(b) != 0.0 and signf(b) != signf(prev):
			sign_changes += 1
		prev = b
	ok(hi > 0.5 and lo < -0.5, "гребни и впадины полные: %.2f…%.2f" % [lo, hi])
	ok(sign_changes > 15, "полосы частые, не редкие пятна: %d смен знака на 120 м" % sign_changes)


## Направление полос меняется медленно: на соседних метрах почти то же, за десятки метров — заметно другое.
func test_dir_slow() -> void:
	var near_dots := 0.0
	var n := 0
	for i in 20:
		var x := -150.0 + i * 17.3
		var z := -90.0 + i * 11.1
		near_dots += R.dir_at(x, z).dot(R.dir_at(x + 2.0, z + 1.3))
		n += 1
	ok(near_dots / n > 0.9, "за 2 м направление почти то же: %.2f" % (near_dots / n))
	var a := R.dir_at(0.0, 0.0)
	var far_min := 1.0
	for i in 12:
		far_min = minf(far_min, a.dot(R.dir_at(i * 131.7 + 3.1, i * 57.9 - 8.3)))
	ok(far_min < 0.6, "за сотни метров направление заметно другое: %.2f" % far_min)


## Пятна тона: в пределах ±0,5, на паре метров почти те же, на десятках метров — разные (ячейка ~40 м).
func test_patch_scale() -> void:
	for i in 50:
		var p := R.patch(-200.0 + i * 9.7, 150.0 - i * 7.1)
		ok(absf(p) <= 0.5 + 1e-6, "пятно в ±0,5")
	var close := 0.0
	var far := 0.0
	var n := 0
	for i in 30:
		var x := -250.0 + i * 13.7
		var z := 120.0 + i * 5.3
		close += absf(R.patch(x, z) - R.patch(x + 2.0, z + 0.9))
		far += absf(R.patch(x, z) - R.patch(x + 47.0, z + 31.0))
		n += 1
	ok(close / n < 0.1, "на 2 м пятно то же: %.3f" % (close / n))
	ok(far / n > 0.15, "на 50+ м пятно другое: %.3f" % (far / n))


func test_fades() -> void:
	near(R.fade(18.0), 1.0, 1e-6, "рябь вблизи полная")
	near(R.fade(100.0), 0.0, 1e-6, "рябь к 100 м ушла")
	near(R.patch_fade(0.0), 1.0, 1e-6)
	near(R.patch_fade(170.0), 0.0, 1e-6, "пятна держатся до 170 м")
	ok(R.fade(50.0) > 0.0, "на середине окна рябь ещё есть")
	ok(R.patch_fade(60.0) > R.fade(60.0), "пятна дальше ряби")
	near(R.slope_k(1.0), 1.0, 1e-6, "на ровном рябь есть")
	near(R.slope_k(0.78), 0.0, 1e-6, "на склоне 1 − ny ≥ 0,22 — скала без ряби")


## Привязка: числа материала дна — из `Seabed.Ripple` (шейдер читает те же имена), гребень гаснет с relief.
func test_scene_seabed_material() -> void:
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	await frames(1)
	var m := ocean.seabed_mat
	for p in ["ripple_wave", "ripple_gain", "ripple_bump", "ripple_fade", "ripple_dir_scale", "ripple_dir_shift",
			"ripple_wiggle", "ripple_wiggle_phase", "ripple_slope", "patch_scale", "patch_shift", "patch_gain",
			"patch_fade"]:
		ok(m.get_shader_parameter(p) != null, p)
	near(float(m.get_shader_parameter("ripple_wave")), R.WAVE, 1e-6)
	near(float(m.get_shader_parameter("ripple_gain")), R.GAIN, 1e-6)
	near(float(m.get_shader_parameter("ripple_bump")), R.BUMP, 1e-6)
	eq(m.get_shader_parameter("ripple_fade"), R.FADE)
	near(float(m.get_shader_parameter("ripple_dir_scale")), R.DIR_SCALE, 1e-6)
	eq(m.get_shader_parameter("ripple_dir_shift"), R.DIR_SHIFT)
	near(float(m.get_shader_parameter("ripple_wiggle")), R.WIGGLE, 1e-6)
	near(float(m.get_shader_parameter("ripple_wiggle_phase")), R.WIGGLE_PHASE, 1e-6)
	eq(m.get_shader_parameter("ripple_slope"), R.SLOPE)
	near(float(m.get_shader_parameter("patch_scale")), R.PATCH_SCALE, 1e-6)
	eq(m.get_shader_parameter("patch_shift"), R.PATCH_SHIFT)
	near(float(m.get_shader_parameter("patch_gain")), R.PATCH_GAIN, 1e-6)
	near(float(m.get_shader_parameter("patch_fade")), R.PATCH_FADE, 1e-6)
	var src: String = m.shader.code
	ok("ripple_wave" in src and "patch_gain" in src, "шейдер читает параметры")
	ok(wrapi(src.find("wrip"), 0, 1 << 30) < src.find("NORMAL ="), "гребень ряби — в нормали до записи NORMAL")
	ocean.queue_free()
	await frames(1)
