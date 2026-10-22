extends TestCase
## Каустики на дне (shaders/seabed.gdshader): узор включён, а свет по глубине гаснет — глубже и в иле темнее.
## Эффект виден вживую/в снимке; тест ловит отключение каустик и обрыв связи глубины со светом.


func test_caustics_on_and_light_by_depth() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var mat := main.ocean.seabed_mat
	ok(mat != null, "у дна есть ShaderMaterial")
	ok(float(mat.get_shader_parameter("caustic")) > 0.0, "каустики включены")

	# мелко: много света сквозь лёд — каустики ярче
	main.ocean.apply_water(main.env, 0.0, Vector3.ZERO, 0.0)
	var shallow: float = float(mat.get_shader_parameter("light"))
	# глубоко: света меньше — каустики тусклее
	main.ocean.apply_water(main.env, 260.0, Vector3.ZERO, 0.0)
	var deep: float = float(mat.get_shader_parameter("light"))
	ok(shallow > deep, "на глубине света сквозь лёд меньше — каустики тусклее")

	# в облаке ила свет рассеивается — каустики почти гаснут
	main.ocean.apply_water(main.env, 0.0, Vector3.ZERO, 1.0)
	var silted: float = float(mat.get_shader_parameter("light"))
	ok(silted < shallow, "в иле свет рассеивается — каустик меньше")

	main.queue_free()
	await frames(1)
