extends TestCase
## Горизонт без тёмной полосы (issue #456): между дальним краем дна и льда кадр видел чистый фон окружения,
## а на Forward Mobile он темнее тумана на геометрии. Дальний фон `OceanView.backdrop` — сфера цвета тумана вокруг
## корабля, ближе дальней плоскости камер: щель закрыта геометрией, которую туманит тот же путь, что дно и лёд.

const CAMERA_FAR := 400.0   ## Main: camera.far, flyby_cam.far


## Дальше всего от корабля отходит камера облёта.
func _flyby_reach() -> float:
	var r := 0.0
	for p in Flyby.START_PATH + Flyby.SURFACE_PATH:
		r = maxf(r, (p as Vector3).length())
	return r


func test_backdrop_inside_camera_far() -> void:
	ok(OceanView.BACKDROP_R + _flyby_reach() < CAMERA_FAR,
		"сфера фона (%.0f м) + отход облёта (%.0f м) ближе дальней плоскости" % [OceanView.BACKDROP_R, _flyby_reach()])
	var corner := Vector2(Seabed.SIZE / 2.0, Seabed.SIZE / 2.0).length()
	ok(OceanView.BACKDROP_R < corner, "фон ближе угла карты — край дна и льда в кадр не выходит")
	# туман у сферы почти полный — дальнее дно сходится с ней плавно
	ok(1.0 - exp(-Seabed.Water.fog_density(0.0) * OceanView.BACKDROP_R) > 0.9, "у сферы туман > 90 % даже у льда")


func test_backdrop_follows_water() -> void:
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	await frames(1)
	ok(ocean.backdrop != null and ocean.backdrop.is_inside_tree(), "дальний фон в сцене")
	eq(ocean.backdrop.layers, OceanView.LAYER_WORLD, "слой отмели — виден из окон и снаружи")
	eq(ocean.backdrop.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "теней не отбрасывает")
	var s := ocean.backdrop.mesh as SphereMesh
	ok(s != null and s.flip_faces, "сфера видна изнутри")
	near(s.radius, OceanView.BACKDROP_R, 1e-4)
	var m := ocean.backdrop_mat
	eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "свет на фон не ложится")
	var env := Environment.new()
	ocean.apply_water(env, 20.0, Vector3(30, -20, -40), 0.0)
	eq(m.albedo_color, env.fog_light_color, "цвет фона = цвет тумана")
	eq(env.background_color, env.fog_light_color)
	ok(ocean.backdrop.position.distance_to(Vector3(30, -20, -40)) < 1e-4, "сфера идёт за кораблём")
	ocean.apply_water(env, 20.0, Vector3.ZERO, 1.0)
	eq(m.albedo_color, env.fog_light_color, "в иле — муть того же цвета")
	ocean.queue_free()
	await frames(1)
