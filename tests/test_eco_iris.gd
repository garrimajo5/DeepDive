extends TestCase
## Переливы чешуи живого мира (Б2): оттенок плёнки меняется по углу к взгляду, соседи переливаются вразнобой;
## новых шейдеров нет, пестрянки на том же шейдере без перелива, «Экономно» гасит перелив числом.


func test_film_changes_with_angle() -> void:
	var face := EcoIris.film(1.0, 0.0)
	var side := EcoIris.film(0.2, 0.0)
	ok(_diff(face, side) > 0.3, "в лоб и по касательной — разный оттенок")
	for ndv in [0.0, 0.3, 0.7, 1.0]:
		var c := EcoIris.film(ndv, 0.17)
		for ch in [c.r, c.g, c.b]:
			ok(ch >= 0.0 and ch <= 1.0, "каналы в 0…1")
	# три канала — сдвиг на треть оборота: средняя яркость ровная (перелив меняет цвет, не яркость)
	for ndv in [0.0, 0.5, 1.0]:
		var c := EcoIris.film(ndv, 0.0)
		near((c.r + c.g + c.b) / 3.0, 0.5, 1e-3, "средняя яркость плёнки постоянна")
	ok(_diff(EcoIris.film(0.6, EcoIris.shift_of(0.0)), EcoIris.film(0.6, EcoIris.shift_of(0.5))) > 0.3,
			"особи с разной фазой — разный оттенок под тем же углом")


func test_weight_grows_to_edge() -> void:
	near(EcoIris.weight(1.0), EcoIris.BASE, 1e-6, "в лоб — слабее")
	near(EcoIris.weight(0.0), EcoIris.BASE + EcoIris.EDGE, 1e-6, "к краю — сильнее")
	ok(EcoIris.weight(0.3) > EcoIris.weight(0.8), "растёт к краю")


func test_glsl_twin_numbers() -> void:
	var g := EcoIris.glsl()
	ok(g.contains("vec3 iris_film(float ndv, float shift)") and g.contains("float iris_weight(float ndv)"),
			"кусок шейдера с плёнкой и весом")
	ok(g.contains(EcoIris._f(EcoIris.SPAN)) and g.contains(EcoIris._f(EcoIris.BASE))
			and g.contains(EcoIris._f(EcoIris.EDGE)), "числа двойника в шейдере")
	for code in [FishView.shader_code(), RaduzhView.body_code()]:
		ok(code.contains("uniform float iris") and code.contains("iris_film(") and not code.contains("%s"),
				"шейдер вида берёт перелив, числа подставлены")


func test_fish_and_pestr_share_shader() -> void:
	EcoIris.set_lite(false)
	var fish_mat := FishView.build_mesh().surface_get_material(0) as ShaderMaterial
	near(float(fish_mat.get_shader_parameter("iris")), EcoIris.FISH, 1e-6, "светляки переливаются")
	var pestr := ShaderMaterial.new()
	pestr.shader = EcoShaders.shader(FishView.shader_code())
	ok(pestr.shader == fish_mat.shader, "пестрянки — тот же шейдер (без нового прогрева)")
	near(_iris(pestr), 0.0, 1e-6, "у пестрянок перелива нет")
	var body := RaduzhView.build_body().material as ShaderMaterial
	near(float(body.get_shader_parameter("iris")), EcoIris.RADUZH, 1e-6, "гребневики переливаются")


func test_lite_keeps_shader() -> void:
	EcoIris.set_lite(false)
	var mat := FishView.build_mesh().surface_get_material(0) as ShaderMaterial
	var body := RaduzhView.build_body().material as ShaderMaterial
	var key := ShaderKey.of(mat)
	EcoIris.set_lite(true)
	near(float(mat.get_shader_parameter("iris")), 0.0, 1e-6, "«Экономно» — перелив погашен")
	near(float(body.get_shader_parameter("iris")), 0.0, 1e-6, "и у гребневиков")
	eq(ShaderKey.of(mat), key, "шейдер тот же — меняется только число")
	EcoIris.set_lite(false)
	near(float(mat.get_shader_parameter("iris")), EcoIris.FISH, 1e-6, "вернулся")
	near(float(body.get_shader_parameter("iris")), EcoIris.RADUZH, 1e-6, "и у гребневиков")
	ok(not EcoIris.apply(EcoShaders.stone(Color.RED, 0.3, 0.9, 0.2), 1.0), "чужой шейдер без uniform iris не тронут")


func test_scene_lite_switch() -> void:
	EcoIris.set_lite(false)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.1)
	var ev: EcoView = main.eco
	var fish := ev.fish_view.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	near(float(fish.get_shader_parameter("iris")), EcoIris.FISH, 1e-6, "светляки в мире переливаются")
	ev.set_lite(true)
	near(float(fish.get_shader_parameter("iris")), 0.0, 1e-6, "«Экономно» мира гасит переливы")
	ev.set_lite(false)
	near(float(fish.get_shader_parameter("iris")), EcoIris.FISH, 1e-6, "и возвращает")
	main.queue_free()
	await frames(2)


func _diff(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## Сила перелива материала: не заданный uniform — значение по умолчанию в шейдере (0).
func _iris(m: ShaderMaterial) -> float:
	var v: Variant = m.get_shader_parameter("iris")
	return 0.0 if v == null else float(v)
