extends TestCase
## Слои воды по ART-069 (`WaterLayers`, `shaders/water_layers.gdshaderinc`): аналитический интеграл слоя вдоль луча,
## взгляд вверх и вниз с одной глубины разный, база ART-059 без добавки не меняется, пределы и ил; материалы дна,
## льда и дальней воды получают числа из OceanView, «Экономно» выключает слои.

const INC := "res://shaders/water_layers.gdshaderinc"


## Численный интеграл профиля вдоль отрезка — для сверки с аналитикой.
func _numeric(ya: float, yb: float, len: float, lo: float, hi: float, e: float) -> float:
	var n := 4000
	var s := 0.0
	for i in n:
		var y := lerpf(ya, yb, (i + 0.5) / n)
		s += WaterLayers.band(y, lo, hi, e)
	return s / n * len


func test_soft_integral_matches_smoothstep() -> void:
	for y in [-2.0, -0.7, 0.0, 0.4, 1.0, 3.5]:
		var n := 4000
		var s := 0.0
		var a := -1.0
		if y > a:
			for i in n:
				s += smoothstep(-1.0, 1.0, lerpf(a, y, (i + 0.5) / n))
			s *= (y - a) / n
		near(WaterLayers.soft_integral(y, -1.0, 1.0), s, 0.001, "∫ smoothstep до y = %s" % y)


func test_band_length_matches_numeric() -> void:
	var cases := [
		[-20.0, -40.0, 30.0], [-40.0, -20.0, 30.0], [-29.0, -30.0, 100.0], [-10.0, -10.0, 50.0],
		[-30.0, -30.0, 50.0], [-2.0, -12.0, 40.0], [-31.0, -60.0, 80.0],
	]
	for c in cases:
		var got := WaterLayers.band_length(c[0], c[1], c[2], -31.5, -28.5, 1.0)
		near(got, _numeric(c[0], c[1], c[2], -31.5, -28.5, 1.0), 0.02, "длина в термоклине %s" % [c])
	# отрезок целиком внутри — вся длина
	near(WaterLayers.band_length(-29.8, -30.2, 50.0, -31.5, -28.5, 1.0), 50.0, 0.001, "внутри слоя — вся длина")


func test_up_and_down_differ() -> void:
	# камера на 25 м: вниз на 40 м луч проходит термоклин, вверх на 15 м — подлёдную муть, в сторону — ничего
	var cam := Vector3(0, -25, 0)
	var down: Array = WaterLayers.add(cam, Vector3(0, -40, 30), 100.0, 100.0)
	var up: Array = WaterLayers.add(cam, Vector3(0, -10, 30), 100.0, 100.0)
	var side: Array = WaterLayers.add(cam, Vector3(0, -25, 30), 100.0, 100.0)
	ok(float(down[0]) > 0.01, "вниз сквозь термоклин — добавка есть")
	ok(float(up[0]) == 0.0 and float(side[0]) == 0.0, "вверх до 10 м и вбок на 25 м — слоёв нет")
	var c: Color = down[1]
	var t: Color = WaterLayers.THERMO.color.srgb_to_linear()
	near(c.b, t.b, 0.001, "вниз — цвет термоклина")
	var top: Array = WaterLayers.add(cam, Vector3(0, -1, 30), 100.0, 100.0)
	var ci: Color = WaterLayers.ICE.color.srgb_to_linear()
	ok(float(top[0]) > 0.0 and (top[1] as Color).g > ci.g * 0.9, "вверх до льда — подлёдная муть")


func test_base_unchanged_without_layers() -> void:
	var base := Color(0.05, 0.2, 0.25)
	var cam := Vector3(0, -15, 0)
	var p := Vector3(0, -15, 60)    # горизонтально между слоями, далеко от дна
	var r: Array = WaterLayers.fog(cam, p, 50.0, 50.0, base, 0.02, WaterLayers.GAIN_NORMAL)
	near(float(r[0]), 1.0 - exp(-60.0 * 0.02), 0.00001, "без слоёв — альфа базы ART-059")
	near((r[1] as Color).g, base.g, 0.00001, "без слоёв — цвет базы")
	var off: Array = WaterLayers.fog(cam, Vector3(0, -40, 30), 50.0, 50.0, base, 0.02, WaterLayers.GAIN_LITE)
	near(float(off[0]), 1.0 - exp(-cam.distance_to(Vector3(0, -40, 30)) * 0.02), 0.00001, "«Экономно» — только база")


func test_caps_and_silt() -> void:
	var base := Color(0.05, 0.2, 0.25)
	# у самого дна в термоклине, длинный луч вдоль дна: все слои в пределах, сумма ≤ 0,16
	var cam := Vector3(0, -30, 0)
	var p := Vector3(0, -30, 300)
	var r: Array = WaterLayers.add(cam, p, 1.0, 0.0)
	ok(float(r[0]) <= WaterLayers.ICE.cap + WaterLayers.THERMO.cap + WaterLayers.DUST.cap + 0.0001, "каждый слой не выше своего предела")
	var f: Array = WaterLayers.fog(cam, p, 1.0, 0.0, base, 0.0, 1.0)
	near(float(f[0]), WaterLayers.TOTAL_CAP, 0.00001, "сумма слоёв не больше 0,16 (база 0 → альфа = предел)")
	ok(WaterLayers.gain(WaterLayers.GAIN_NORMAL, 1.0) < WaterLayers.GAIN_NORMAL * 0.2, "в иле слои почти гаснут")
	near(WaterLayers.gain(WaterLayers.GAIN_BEAUTIFUL, 0.0), 0.9, 0.0001, "«Красиво» — 0,9")


func test_soft_cap_smooth() -> void:
	near(WaterLayers.soft_cap(0.001, 0.1), 1.0 - exp(-0.001), 0.00001, "тонкий слой — как 1 − exp(−τ)")
	ok(WaterLayers.soft_cap(50.0, 0.1) <= 0.1, "не выше предела")
	# без излома: приращения у бывшего порога (τ ≈ 0,105) меняются плавно
	var d1 := WaterLayers.soft_cap(0.11, 0.1) - WaterLayers.soft_cap(0.10, 0.1)
	var d2 := WaterLayers.soft_cap(0.12, 0.1) - WaterLayers.soft_cap(0.11, 0.1)
	ok(d2 > 0.0 and d2 / d1 > 0.85, "у предела нет излома (линии у горизонта)")


func test_dust_protected_near_camera() -> void:
	var cam := Vector3(0, -40, 0)
	var near_p: Array = WaterLayers.add(cam, Vector3(0, -41.5, 8), 1.5, 0.0)
	var far_p: Array = WaterLayers.add(cam, Vector3(0, -41.5, 60), 1.5, 0.0)
	ok(float(near_p[0]) == 0.0, "ближе 12 м пыль не прячет дно (пятно прожектора)")
	ok(float(far_p[0]) > 0.05, "вдали у дна — придонная муть")


## Числа шейдера совпадают с WaterLayers — двойник проверяет то же, что рисуется.
func test_shader_numbers_match() -> void:
	var src := FileAccess.get_file_as_string(INC)
	for s in ["-6.0, 0.0, wl_edge(1.5, dist)", "-31.5 + w, -28.5 + w, wl_edge(1.0, dist)", "clamp((dist - 60.0) * 0.1, 0.0, 30.0)", "0.0, 3.0, 1.0", "0.11 * (1.0 - exp(-li * 0.008 / 0.11))",
			"0.10 * (1.0 - exp(-lt * 0.017 / 0.10))", "0.10 * (1.0 - exp(-ld * 0.035 / 0.10))", "smoothstep(12.0, 45.0, dist)", "0.0, 0.16)", "0.12 * sin(p.x * 0.09 + t * 0.25)",
			"sin(p.z * 0.07 - t * 0.15)"]:
		ok(src.contains(s), "в шейдере есть «%s»" % s)
	ok(not src.contains("source_color"), "цвета слоёв без source_color (их переводит OceanView)")
	eq(WaterLayers.ICE.y, Vector2(-6, 0), "подлёдный слой 0…6 м")
	eq(WaterLayers.THERMO.y, Vector2(-31.5, -28.5), "термоклин 28,5…31,5 м")
	for path in ["res://shaders/seabed.gdshader", "res://shaders/ice.gdshader", "res://shaders/far_water.gdshader"]:
		var sh := FileAccess.get_file_as_string(path)
		ok(sh.contains("water_layers.gdshaderinc") and sh.contains("FOG = water_layers_fog("), "%s пишет слои в FOG" % path)


func test_ocean_materials_get_layers() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var o := main.ocean
	main.ocean.apply_water(main.env, 30.0, Vector3.ZERO, 0.0)
	for m in o.layer_mats():
		near(float(m.get_shader_parameter("layer_gain")), WaterLayers.GAIN_NORMAL, 0.0001, "«Обычно» — 0,6")
		near(float(m.get_shader_parameter("layer_density")), main.env.fog_density, 0.00001, "база — плотность тумана сцены")
		# цвета линейные и без source_color: в Compatibility подсказка vec3 не переводит, снимки из облака врали бы
		var c: Vector3 = m.get_shader_parameter("layer_base")
		near(c.y, main.env.fog_light_color.srgb_to_linear().g, 0.0001, "база — цвет тумана сцены, линейный")
		var ct: Vector3 = m.get_shader_parameter("layer_thermo_color")
		near(ct.z, WaterLayers.THERMO.color.srgb_to_linear().b, 0.0001, "цвет термоклина, линейный")
	main.ocean.apply_water(main.env, 30.0, Vector3.ZERO, 1.0)
	ok(float(o.seabed_mat.get_shader_parameter("layer_gain")) < 0.1, "в иле слои гаснут")
	o.set_layers_lite(true)
	for m in o.layer_mats():
		eq(float(m.get_shader_parameter("layer_gain")), 0.0, "«Экономно» — слои выключены")
	o.set_layers_lite(false)
	main.ocean.apply_water(main.env, 30.0, Vector3.ZERO, 0.0)
	near(float(o.ice_mat.get_shader_parameter("layer_gain")), WaterLayers.GAIN_NORMAL, 0.0001, "снова «Обычно»")
	# высота камеры над дном — для придонной пыли
	o.set_layers_camera(Vector3(5, Seabed.mesh_height(5, 7) + 2.0, 7))
	near(float(o.far_mat.get_shader_parameter("layer_cam_above")), 2.0, 0.001, "камера в 2 м над дном")
	main.queue_free()
	await frames(1)


## Issue #516: у горизонта дальняя вода (сфера 380 м) давала ровную линию — луч с 20 м дотягивался до слоя на
## конце отрезка в узком угле (край 1 м на 380 м ≈ 0,3°), выше линии муть, ниже нет. Края слоя вдали шире
## (`WaterLayers.edge`): от угла к углу (0,1° ≈ 1 px на 6" экране) добавка меняется плавно, переход — несколько градусов.
func test_far_wall_no_line_at_horizon() -> void:
	for depth in [20.0, 29.0, 45.0]:
		var cam := Vector3(0, -depth, 0)
		var prev := -1.0
		var worst := 0.0
		var lo := 1.0
		var hi := 0.0
		for i in range(-120, 121):   # −12…+12° от горизонта, шаг 0,1°
			var a := deg_to_rad(i * 0.1)
			var p := cam + Vector3(0, sin(a), -cos(a)) * 380.0
			var above := 30.0 + p.y - cam.y   # дно в 30 м под камерой; ниже пыли дальнюю воду закрывает дно
			if p.y > 0.0 or above < 4.0:
				continue
			var t := float(WaterLayers.add(cam, p, 30.0, above)[0])
			lo = minf(lo, t)
			hi = maxf(hi, t)
			if prev >= 0.0:
				worst = maxf(worst, absf(t - prev))
			prev = t
		ok(hi - lo > 0.02, "на %d м слои у горизонта видны (%.3f…%.3f)" % [depth, lo, hi])
		ok(worst < 0.006, "на %d м нет ступени у горизонта: худший шаг %.4f на 0,1°" % [depth, worst])


## Вблизи края слоя прежние: дно и лёд в нескольких метрах видят слой той же толщины.
func test_edge_widens_only_far() -> void:
	near(WaterLayers.edge(1.0, 0.0), 1.0, 0.0001, "у камеры край как в ART-069")
	near(WaterLayers.edge(1.0, 60.0), 1.0, 0.0001, "до 60 м край прежний — дно и лёд рядом как в ART-069")
	ok(WaterLayers.edge(1.0, 380.0) >= 10.0, "у дальней воды край шире 10 м")
	near(WaterLayers.edge(1.0, 5000.0), WaterLayers.edge(1.0, 1000.0), 0.0001, "предел расширения")
	# толщина слоя (интеграл профиля) не меняется — та же муть, только размыта по высоте
	near(_numeric(-80.0, 20.0, 100.0, -31.5, -28.5, WaterLayers.edge(1.0, 380.0)), 3.0, 0.01, "интеграл профиля = толщине")
