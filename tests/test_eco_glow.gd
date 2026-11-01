extends TestCase
## Биолюминесценция живого мира — один приём свечения (Б1, часть 1): своё свечение тел со светом идёт через
## eco_bio (uniform bio), общая яркость — одна ручка EcoGlow.set_gain; шейдеров не прибавилось.


func test_gain_moves_shader_and_standard() -> void:
	EcoGlow.set_gain(EcoGlow.GAIN)
	var own := ShaderMaterial.new()
	own.shader = EcoShaders.shader(RayView.SHADER)
	ok(EcoGlow.track(own), "шейдер ледокрыла берёт общий приём")
	var std := StandardMaterial3D.new()
	std.emission_enabled = true
	std.emission_energy_multiplier = 1.5
	ok(EcoGlow.track(std), "модель со свечением тронута")
	var dark := StandardMaterial3D.new()
	ok(not EcoGlow.track(dark), "без свечения — мимо")
	var plain := ShaderMaterial.new()
	plain.shader = EcoShaders.shader(EcoShaders.MIST)
	ok(not EcoGlow.track(plain), "прозрачное без свечения (MIST) — мимо")
	var spot := ShaderMaterial.new()
	spot.shader = EcoShaders.shader(EcoShaders.SPOT)
	ok(EcoGlow.track(spot), "светлые точки (SPOT) — общий приём (часть 2)")
	EcoGlow.set_gain(2.0)
	near(float(own.get_shader_parameter("bio")), 2.0, 1e-6, "ручка — в uniform")
	near(float(spot.get_shader_parameter("bio")), 2.0, 1e-6, "и у светлых точек")
	near(std.emission_energy_multiplier, 3.0, 1e-6, "у модели — от своей энергии")
	EcoGlow.track(std)
	near(std.emission_energy_multiplier, 3.0, 1e-6, "повторный учёт не умножает дважды")
	near(EcoGlow.bio(Color(0.5, 0.25, 1.0)).b, 2.0, 1e-6, "двойник eco_bio")
	EcoGlow.set_gain(EcoGlow.GAIN)
	near(float(own.get_shader_parameter("bio")), 1.0, 1e-6, "вернулось")
	near(std.emission_energy_multiplier, 1.5, 1e-6, "у модели — своя энергия")


func test_shader_code_routes_emission() -> void:
	var codes := {"ледокрыл": RayView.SHADER, "светляки": FishView.shader_code(), "цветок": FlowerView.SHADER,
		"огнецвет": CoralView.SHADER, "камень": EcoShaders.STONE, "растения": EcoShaders.PLANT}
	var spot := EcoShaders.SPOT
	ok(spot.contains("uniform float bio") and spot.contains("ALBEDO = eco_bio("), "светлые точки: цвет через eco_bio")
	for who in codes:
		var code: String = codes[who]
		ok(code.contains("uniform float bio"), "%s: общий приём свечения" % who)
		for line in code.split("\n"):
			if line.strip_edges().begins_with("EMISSION ="):
				ok(line.contains("eco_bio("), "%s: свечение через eco_bio — %s" % [who, line.strip_edges()])


func test_scene_glow_is_one_knob() -> void:
	EcoGlow.set_gain(EcoGlow.GAIN)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.1)
	var ev: EcoView = main.eco
	var shaders := 0
	for gi in ev.find_children("*", "GeometryInstance3D", true, false):
		for m in EcoRim.materials(gi as GeometryInstance3D):
			var sm := m as ShaderMaterial
			if sm == null or sm.shader == null:
				continue
			var code := sm.shader.code
			if code.contains("unshaded") or not code.contains("EMISSION ="):
				continue
			# новое тело со своим свечением без общего приёма — сюда
			ok(EcoGlow.has_uniform(sm), "%s: свечение через eco_bio" % gi.name)
			shaders += 1
	ok(shaders >= 6, "тела со свечением найдены (%d)" % shaders)
	EcoGlow.set_gain(1.5)
	var ray: ShaderMaterial = ev.find_child("Ледокрылы", true, false).multimesh.mesh.surface_get_material(0)
	near(float(ray.get_shader_parameter("bio")), 1.5, 1e-6, "ручка доходит до ледокрыла в мире")
	var spots := 0   # часть 2: гребневики, планктон и споры — той же ручкой
	for gi in ev.find_children("*", "GeometryInstance3D", true, false):
		for m in EcoRim.materials(gi as GeometryInstance3D):
			var sm := m as ShaderMaterial
			if sm != null and sm.shader != null and sm.shader.code.contains("blend_add") and EcoGlow.has_uniform(sm):
				near(float(sm.get_shader_parameter("bio")), 1.5, 1e-6, "%s: ручка у светлых точек" % gi.name)
				spots += 1
	ok(spots >= 2, "светлые точки в мире найдены (%d)" % spots)
	EcoGlow.set_gain(EcoGlow.GAIN)
	near(float(ray.get_shader_parameter("bio")), 1.0, 1e-6, "и обратно")
	main.queue_free()
	await frames(1)
