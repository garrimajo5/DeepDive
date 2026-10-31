extends TestCase
## Каустики на местах-ориентирах (Б1): камень ловит сеть света сквозь лёд, как дно; сила — по глубине корабля той же
## кривой, что у дна; «Экономно» гасит числом; нового шейдера нет.


func test_stone_takes_caustic() -> void:
	EcoCaustic.set_lite(false)
	EcoCaustic.set_depth(20.0)
	var m := EcoShaders.stone(Color.CYAN, 0.3, 0.9, 0.2)
	ok(m.shader.code.contains("uniform float caustic"), "в шейдере камня есть каустики")
	near(float(m.get_shader_parameter("caustic")), EcoCaustic.for_depth(20.0), 1e-6, "новый камень — с текущей силой")
	ok(EcoCaustic.for_depth(20.0) > 0.1, "на отмели каустики заметны")
	var m2 := EcoShaders.stone(Color.RED, 0.2, 0.9, 0.2)
	eq(m2.shader, m.shader, "шейдер камня один — нового не прибавилось")


func test_strength_follows_seabed_curve() -> void:
	for d in [10.0, 40.0, 120.0, 285.0]:
		near(EcoCaustic.for_depth(d), EcoCaustic.GAIN * Seabed.Water.caustic(d), 1e-6, "кривая дна на %d м" % d)
	ok(EcoCaustic.for_depth(285.0) < EcoCaustic.for_depth(20.0), "глубже — слабее")
	var m := EcoShaders.stone(Color.CYAN, 0.3, 0.9, 0.2)
	EcoCaustic.set_depth(285.0)
	near(float(m.get_shader_parameter("caustic")), EcoCaustic.for_depth(285.0), 1e-6, "корабль ушёл вниз — камень темнее")
	var before := float(m.get_shader_parameter("caustic"))
	EcoCaustic.set_depth(285.01)
	near(float(m.get_shader_parameter("caustic")), before, 1e-9, "мелкое изменение uniform не переписывает")


func test_lite_zeroes() -> void:
	EcoCaustic.set_depth(20.0)
	var m := EcoShaders.stone(Color.CYAN, 0.3, 0.9, 0.2)
	var key := ShaderKey.of(m)
	EcoCaustic.set_lite(true)
	near(float(m.get_shader_parameter("caustic")), 0.0, 1e-6, "«Экономно» — каустик на камне нет")
	var late := EcoShaders.stone(Color.CYAN, 0.3, 0.9, 0.2)
	near(float(late.get_shader_parameter("caustic")), 0.0, 1e-6, "и у камня, собранного после")
	eq(ShaderKey.of(m), key, "шейдер тот же")
	EcoCaustic.set_lite(false)
	near(float(m.get_shader_parameter("caustic")), EcoCaustic.for_depth(20.0), 1e-6, "вернулись")


func test_pattern_is_thin_net() -> void:
	# Сеть: яркие нити — малая доля площади, остальное тёмное; узор бежит со временем.
	var bright := 0
	var changed := 0
	var n := 0
	for i in 40:
		for j in 40:
			var x := i * 0.37
			var z := j * 0.41
			var c := EcoCaustic.pattern(x, z, 3.0)
			ok(c >= 0.0 and c <= 1.0, "яркость в 0…1")
			if c > 0.5:
				bright += 1
			if absf(c - EcoCaustic.pattern(x, z, 6.0)) > 0.2:
				changed += 1
			n += 1
	var share := float(bright) / n
	ok(share > 0.02 and share < 0.4, "нити — малая доля площади (%.2f)" % share)
	ok(changed > n / 20, "узор движется со временем")


func test_only_top_faces() -> void:
	near(EcoCaustic.facing(1.0), 1.0, 1e-6, "верх камня — полностью")
	near(EcoCaustic.facing(0.0), 0.0, 1e-6, "бок — нет")
	near(EcoCaustic.facing(-1.0), 0.0, 1e-6, "низ — нет")


func test_scene_stones_tracked() -> void:
	EcoCaustic.set_lite(false)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.1)
	var stones := 0
	for gi in main.eco.find_children("*", "GeometryInstance3D", true, false):
		for m in EcoRim.materials(gi as GeometryInstance3D):
			if m is ShaderMaterial and (m as ShaderMaterial).shader == EcoShaders.shader(EcoShaders.STONE):
				stones += 1
				near(float((m as ShaderMaterial).get_shader_parameter("caustic")), EcoCaustic.applied(), 1e-6,
					"камень %s под каустиками" % gi.name)
	ok(stones >= 3, "места-ориентиры на камне есть (%d)" % stones)
	ok(EcoCaustic.applied() > 0.0, "на отмели сила не ноль")
	main.eco.set_lite(true)
	near(EcoCaustic.applied(), 0.0, 1e-6, "уровень «Экономно» мира гасит каустики")
	main.eco.set_lite(false)
	main.queue_free()
	await frames(1)
