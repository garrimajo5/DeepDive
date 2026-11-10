extends TestCase
## Дальняя вода (issue #456): у горизонта шла чёрная полоса — в щели между краем льда и дна был виден фон BG_COLOR,
## на Forward Mobile он темнее тумана на геометрии. Сфера цвета тумана вокруг камеры закрывает щель.


func test_far_wall_closes_gap() -> void:
	ok(OceanView.FAR_WALL < 400.0, "сфера ближе дальности камер (400 м) — иначе её отрежет и фон вернётся")
	# щель: дно у края карты не выше Seabed.TOP, лёд — на ICE_Y; луч к горизонту уходит дальше края карты
	ok(OceanView.FAR_WALL > Seabed.SIZE * 0.5, "дальше края карты от середины — сама сфера мир не закрывает")
	var residual := exp(-Seabed.Water.fog_density(0.0) * OceanView.FAR_WALL)
	ok(residual < 0.06, "на радиусе сферы туман почти полный даже у льда: %.3f" % residual)


func test_scene_far_wall() -> void:
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.global_position = Vector3(120.0, -30.0, -80.0)
	cam.current = true
	await frames(2)
	ok(ocean.far_wall != null, "дальняя вода в сцене")
	ok(ocean.far_wall.global_position.is_equal_approx(cam.global_position), "сфера идёт за камерой")
	eq(ocean.far_wall.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "теней не бросает")
	eq(ocean.far_wall.layers, OceanView.LAYER_WORLD)
	eq(ocean.far_mat.shader.resource_path, "res://shaders/far_water.gdshader")
	var env := Environment.new()
	ocean.apply_water(env, 20.0, Vector3.ZERO, 0.0)
	eq(ocean.far_mat.get_shader_parameter("water"), env.background_color, "цвет — как фон и туман")
	ocean.apply_water(env, 30.0, Vector3.ZERO, 0.8)
	eq(ocean.far_mat.get_shader_parameter("water"), env.fog_light_color, "и в иле")
	cam.queue_free()
	ocean.queue_free()
	await frames(1)
