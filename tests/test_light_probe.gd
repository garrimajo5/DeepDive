extends TestCase
## Проба света сцены 00 → 01 (#1400, черновая PR): три варианта на одном месте и позе — `LightProbe`,
## шаг сценария `svet`, ключ снимка `svet=`, сценарий тестера tools/qa/svet-1400.json.


func test_numbers_by_designer() -> void:   # решение гейм-дизайнера 10.11 в #1400
	LightProbe.set_kind(LightProbe.Kind.BASE)
	eq(LightProbe.water_k(), 1.0, "исходное — без множителей")
	eq(LightProbe.ambient_k(), 1.0)
	eq(LightProbe.tilt(), 0.0, "исходное — без перелива")
	eq(LightProbe.spot_energy(), Searchlight.ENERGY, "прожектор как в main")
	LightProbe.set_kind(LightProbe.Kind.WATER)
	near(LightProbe.water_k(), 0.72, 1e-6, "вода ×0,72")
	near(LightProbe.ambient_k(), 0.8, 1e-6, "рассеянный ×0,8")
	eq(LightProbe.spot_energy(), Searchlight.ENERGY, "вода отдельно от прожектора")
	ok(LightProbe.tilt() > 0.0, "перелив включён")
	LightProbe.set_kind(LightProbe.Kind.WATER_SPOT)
	near(LightProbe.water_k(), 0.72, 1e-6, "вода та же")
	near(LightProbe.spot_energy(), 5.0, 1e-6, "прожектор 5")
	var r := LightProbe.rev
	LightProbe.set_kind(LightProbe.Kind.WATER_SPOT)
	eq(LightProbe.rev, r, "тот же вариант — воду заново не писать")
	LightProbe.set_kind(9)
	eq(LightProbe.kind, LightProbe.Kind.WATER_SPOT, "вне 0…2 — к краю")
	LightProbe.set_kind(LightProbe.Kind.BASE)


func test_tilt_is_smooth_without_horizon_line() -> void:   # перелив без стены и полосы горизонта
	var cam := Vector3(0, -30, 0)
	near(WaterLayers.tilt_k(cam, Vector3(0, -30, 100), 0.3), 1.0, 1e-6, "у горизонта — цвет тумана как был")
	ok(WaterLayers.tilt_k(cam, Vector3(0, 0, 50), 0.3) > 1.0, "ко льду светлее")
	ok(WaterLayers.tilt_k(cam, Vector3(0, -60, 50), 0.3) < 1.0, "вниз темнее")
	near(WaterLayers.tilt_k(cam, Vector3(0, 70, 0), 0.3), 1.3, 1e-6, "прямо вверх — +TILT")
	eq(WaterLayers.tilt_k(cam, Vector3(0, 70, 0), 0.0), 1.0, "без перелива — 1")
	var worst := 0.0   # по наклону луча через горизонт: шаг 0,5° — без скачка
	var last := WaterLayers.tilt_k(cam, cam + Vector3(0, sin(deg_to_rad(-30.0)), cos(deg_to_rad(-30.0))) * 150.0, 0.3)
	for i in range(1, 121):
		var a := deg_to_rad(-30.0 + i * 0.5)
		var k := WaterLayers.tilt_k(cam, cam + Vector3(0, sin(a), cos(a)) * 150.0, 0.3)
		ok(k > last, "монотонно светлее вверх")
		worst = maxf(worst, k - last)
		last = k
	ok(worst < 0.003, "за 0,5° наклона цвет меняется меньше 0,3 %%: %.4f" % worst)
	# одна точка — один цвет у дна, льда и дальней воды: множитель зависит только от луча
	var f: Array = WaterLayers.fog(cam, Vector3(10, -50, 80), 20.0, 0.0, Color(0.1, 0.2, 0.3), 0.02, 0.6, 0.0, 0.3)
	var g: Array = WaterLayers.fog(cam, Vector3(10, -50, 80), 20.0, 0.0, Color(0.1, 0.2, 0.3), 0.02, 0.6, 0.0, 0.0)
	var k0 := WaterLayers.tilt_k(cam, Vector3(10, -50, 80), 0.3)
	near(f[0], g[0], 1e-6, "плотность тумана перелив не меняет")
	near((f[1] as Color).b, (g[1] as Color).b * k0, 1e-6, "цвет × tilt_k")


func test_shader_twin() -> void:   # двойник в шейдере слоёв воды — дно, лёд, дальняя вода и арка 07
	var src := FileAccess.get_file_as_string("res://shaders/water_layers.gdshaderinc")
	ok(src.contains("uniform float layer_tilt = 0.0"), "в шейдере по умолчанию перелива нет")
	ok(src.contains("vec4(layer_base * wl_tilt(cam, p, dist), a0)"), "«Экономно» — тоже с переливом")
	ok(src.contains("vec4(c * wl_tilt(cam, p, dist), a)"), "со слоями — тоже")
	ok(OceanView.LAYER_PARAMS.has("layer_tilt"), "арка врат получает перелив, как дно")


func test_scene_apply_water() -> void:
	var ov := OceanView.new()
	tree.root.add_child(ov)
	await frames(1)
	var env := Environment.new()
	ov.apply_water(env, 30.0, Vector3.ZERO)
	var base := env.fog_light_color
	var amb := env.ambient_light_energy
	LightProbe.set_kind(LightProbe.Kind.WATER)
	ov.apply_water(env, 30.0, Vector3.ZERO)   # глубина та же — вариант сменился, вода пишется заново
	near(env.fog_light_color.b, base.b * 0.72, 1e-5, "туман ×0,72")
	ok(env.background_color.is_equal_approx(env.fog_light_color), "фон — того же цвета")
	near(env.ambient_light_energy, amb * 0.8, 1e-5, "рассеянный ×0,8")
	near(float(ov.seabed_mat.get_shader_parameter("layer_tilt")), LightProbe.TILT, 1e-6, "перелив у дна")
	near(float(ov.far_mat.get_shader_parameter("layer_tilt")), LightProbe.TILT, 1e-6, "и у дальней воды")
	LightProbe.set_kind(LightProbe.Kind.BASE)
	ov.apply_water(env, 30.0, Vector3.ZERO)
	ok(env.fog_light_color.is_equal_approx(base), "исходное возвращается")
	ov.queue_free()
	await frames(1)


func test_scene_spot() -> void:
	var v := SearchlightView.new()
	tree.root.add_child(v)
	await frames(1)
	v.apply(true, 1.0)
	near(v.spot.light_energy, Searchlight.ENERGY, 1e-6, "исходное — 10")
	LightProbe.set_kind(LightProbe.Kind.WATER_SPOT)
	v.refresh()
	near(v.spot.light_energy, 5.0, 1e-6, "вариант 2 — прожектор 5")
	LightProbe.set_kind(LightProbe.Kind.BASE)
	v.refresh()
	v.queue_free()
	await frames(1)


func test_tester_scenario() -> void:   # tools/qa/svet-1400.json: три кадра одной позы на каждом месте
	var q := QaScript.parse(FileAccess.get_file_as_string("res://tools/qa/svet-1400.json"))
	eq(q.errors.size(), 0, "без ошибок: %s" % ", ".join(q.errors))
	var shots := {}
	for st in q.steps:
		if st["do"] == "shot":
			shots[st["name"]] = true
	for place in ["1", "2", "3", "3b"]:
		for k in 3:
			ok(shots.has("svet-%s-v%d" % [place, k]), "кадр svet-%s-v%d" % [place, k])
	ok(shots.has("svet-2-vverh-v1") and shots.has("svet-2-vniz-v1"), "наклон камеры — с переливом")
	eq(q.steps[-1], {"do": "quit"}, "в конце — выход")
