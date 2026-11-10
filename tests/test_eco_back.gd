extends TestCase
## Просвет листвы и щупалец живого мира (Б2): тонкие растения светятся против огня своим цветом; трубы органа —
## нет; щупальце к кончику просвечивает сильнее; новых шейдеров нет, «Экономно» гасит просвет числом.


func test_table() -> void:
	eq(EcoBack.BACK.size(), EcoShaders.Plant.size(), "доля просвета у каждого вида растений")
	for kind in [EcoShaders.Plant.KELP, EcoShaders.Plant.LEAF, EcoShaders.Plant.FAN, EcoShaders.Plant.TENTACLE]:
		var b := EcoBack.of(kind)
		ok(b.x > 0.0 and b.y > 0.0 and b.z > 0.0, "вид %d просвечивает" % kind)
		ok(b.x <= 1.0 and b.y <= 1.0 and b.z <= 1.0, "просвет не ярче прямого света")
	eq(EcoBack.of(EcoShaders.Plant.ORGAN), Vector3.ZERO, "трубы органа толстые — без просвета")
	ok(EcoBack.of(EcoShaders.Plant.KELP).x > EcoBack.of(EcoShaders.Plant.FAN).x, "лента тоньше известкового веера")


func test_twin() -> void:
	EcoBack.set_lite(false)
	var c := EcoBack.through(Color(0.5, 0.8, 0.4), EcoShaders.Plant.KELP)
	var b := EcoBack.of(EcoShaders.Plant.KELP)
	near(c.r, 0.5 * b.x, 1e-6, "просвет — доля альбедо")
	near(c.g, 0.8 * b.y, 1e-6, "по каналам")
	var foot := EcoBack.through(Color.WHITE, EcoShaders.Plant.TENTACLE, 0.0)
	var tip := EcoBack.through(Color.WHITE, EcoShaders.Plant.TENTACLE, 1.0)
	ok(tip.r > foot.r, "щупальце к кончику тоньше — просвечивает сильнее")
	near(tip.r / foot.r, EcoBack.TENTACLE_TIP / EcoBack.TENTACLE_FOOT, 1e-5, "основание и кончик")


func test_shader_twin_numbers() -> void:
	var code := EcoShaders.PLANT
	ok(code.contains("uniform vec3 back") and code.contains("uniform float back_k"), "uniform просвета")
	ok(code.contains("BACKLIGHT = ALBEDO * b;"), "встроенный просвет Godot")
	ok(code.contains("mix(%s, %s, COLOR.a)" % [EcoBack.TENTACLE_FOOT, EcoBack.TENTACLE_TIP]),
			"числа щупальца — как у двойника")


func test_views_get_back() -> void:
	EcoBack.set_lite(false)
	var meshes := {
		EcoShaders.Plant.KELP: KelpView.build_stalk(),
		EcoShaders.Plant.TENTACLE: HvatenView.build_tentacle(),
	}
	for kind in meshes:
		var mat := (meshes[kind] as Mesh).surface_get_material(0) as ShaderMaterial
		eq(mat.get_shader_parameter("back"), EcoBack.of(kind), "вид %d — просвет из таблицы" % kind)
		near(float(mat.get_shader_parameter("back_k")), 1.0, 1e-6, "просвет включён")
		ok(mat.shader == EcoShaders.shader(EcoShaders.PLANT), "тот же общий шейдер растений")
	var own := EcoShaders.plant(EcoShaders.Plant.LEAF, {"back": Vector3(0.1, 0.2, 0.3)})
	eq(own.get_shader_parameter("back"), Vector3(0.1, 0.2, 0.3), "свой просвет вида не перетирается")


func test_lite_keeps_shader() -> void:
	EcoBack.set_lite(false)
	var mat := EcoShaders.plant(EcoShaders.Plant.KELP)
	var key := ShaderKey.of(mat)
	ok(EcoBack.count() > 0, "материал растения в списке просвета")
	EcoBack.set_lite(true)
	near(float(mat.get_shader_parameter("back_k")), 0.0, 1e-6, "«Экономно» — просвет погашен")
	eq(EcoBack.through(Color.WHITE, EcoShaders.Plant.KELP), Color(0, 0, 0), "двойник — тоже")
	eq(ShaderKey.of(mat), key, "шейдер тот же — меняется только число")
	var later := EcoShaders.plant(EcoShaders.Plant.LEAF)
	near(float(later.get_shader_parameter("back_k")), 0.0, 1e-6, "новое растение на «Экономно» — сразу без просвета")
	EcoBack.set_lite(false)
	near(float(mat.get_shader_parameter("back_k")), 1.0, 1e-6, "вернулся")


func test_eco_view_lite_switch() -> void:
	var ev := EcoView.new()
	ev.set_lite(true)
	ok(EcoBack.lite, "общий выключатель мира гасит просвет")
	ev.set_lite(false)
	ok(not EcoBack.lite, "и возвращает")
	ev.free()
