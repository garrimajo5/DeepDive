extends TestCase
## Экраны пульта у штурвала ART-061 (#1568): ход, глубина и курс из `Helm.Ship`, свет, сонар и тревога —
## `ConsoleScreen` → uniform `shaders/console_screens.gdshader`, `BridgeView.set_readout` пишет только при смене.


func test_heading_wraps() -> void:
	eq(ConsoleScreen.values(0.0, 0.0, 0.0).x, 0.0, "нос в −Z — 0°")
	eq(ConsoleScreen.values(-PI / 2.0, 0.0, 0.0).x, 90.0, "поворот вправо (yaw убывает) — 90°")
	eq(ConsoleScreen.values(PI / 2.0, 0.0, 0.0).x, 270.0, "поворот влево — 270°")
	eq(ConsoleScreen.values(deg_to_rad(-245.0), 0.0, 0.0).x, 245.0)
	eq(ConsoleScreen.values(deg_to_rad(0.2), 0.0, 0.0).x, 0.0, "359,8° — показ 0°, не 360°")
	eq(ConsoleScreen.values(TAU * 3.0 - deg_to_rad(10.0), 0.0, 0.0).x, 10.0, "много оборотов")


func test_depth_and_speed() -> void:
	var v := ConsoleScreen.values(0.0, 120.4, 2.36)
	eq(v.y, 120.0, "глубина до метра")
	near(v.z, 2.4, 1e-5, "ход до 0,1")
	eq(ConsoleScreen.values(0.0, -3.0, 0.0).y, 0.0, "над нулём не уходит в минус")
	eq(ConsoleScreen.values(0.0, 1500.0, 0.0).y, float(ConsoleScreen.MAX_DEPTH), "три цифры")
	near(ConsoleScreen.values(0.0, 0.0, -1.27).z, -1.3, 1e-5, "задний ход — со знаком")
	eq(ConsoleScreen.values(0.0, 0.0, -0.03).z, 0.0, "«−0.0» не рисуем")


func test_status() -> void:
	eq(ConsoleScreen.status(true, true, false), Vector3(1, 1, 0))
	eq(ConsoleScreen.status(false, false, true), Vector3(0, 0, 1))


## Шейдер: минус заднего хода по знаку, яркость k гасит фон и цифры вместе, тревога — янтарь, без красного (#129).
func test_shader_draws_sign_and_dims() -> void:
	var src := (load("res://shaders/console_screens.gdshader") as Shader).code
	ok(src.contains("values.z < -0.05"), "минус — по знаку хода")
	ok(src.contains("ALBEDO = col * 0.55 * kk") and src.contains("EMISSION = col * 0.15 * kk"), "k = 0 — экран погас")
	ok(src.contains("vec3(1.0, 0.698, 0.349)"), "тревога — #FFB259")


## Глифы, которые берёт шейдер, есть в атласе: цифры 0–9, точка, «/», «−», «с» и плотные «м», «°».
func test_atlas_glyphs() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://docs/concept-art/ekrany-pultov-atlas.png"))
	eq(img.get_size(), Vector2i(1024, 512))
	for i in 16:
		if i == 11 or i == 12:
			continue
		ok(_ink(img, Rect2i(i * 64 + 12, 384, 40, 64)) > 20, "глиф %d в ячейке" % i)
	ok(_ink(img, Rect2i(716, 397, 40, 38)) > 20, "«м»")
	ok(_ink(img, Rect2i(789, 393, 22, 24)) > 20, "«°»")
	var game := Image.load_from_file(ProjectSettings.globalize_path("res://textures/ekrany/atlas.png"))
	eq(game.get_data(), img.get_data(), "в игре — принятый атлас")


func _ink(img: Image, r: Rect2i) -> int:
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return n


func test_readout_written_on_change() -> void:
	var v := BridgeView.new()
	tree.root.add_child(v)
	await frames(1)
	ok(v.screens_mat.get_shader_parameter("atlas") != null, "атлас в материале экранов")
	v.set_readout(Vector3(245, 120, 1.5), Vector3(1, 1, 0))
	eq(v.screens_mat.get_shader_parameter("values"), Vector3(245, 120, 1.5))
	v.screens_mat.set_shader_parameter("values", Vector3(9, 9, 9))
	v.set_readout(Vector3(245, 120, 1.5), Vector3(1, 1, 0))
	eq(v.screens_mat.get_shader_parameter("values"), Vector3(9, 9, 9), "тот же показ — не переписан")
	v.set_readout(Vector3(245, 120, 1.5), Vector3(1, 0, 0))
	eq(v.screens_mat.get_shader_parameter("values"), Vector3(245, 120, 1.5), "сонар на перезаряде — переписан")
	eq(v.screens_mat.get_shader_parameter("status"), Vector3(1, 0, 0))
	v.queue_free()
	await frames(1)


## В игре экраны показывают корабль: курс, глубина и ход из `Helm.Ship`, задний ход — со знаком.
func test_scene_shows_ship() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.helm.yaw = deg_to_rad(-245.0)
	main.helm.speed = -1.2
	main.step(0.0)
	var v: Vector3 = main.bridge.screens_mat.get_shader_parameter("values")
	eq(v.x, 245.0, "курс")
	eq(v.y, float(roundi(main.helm.depth())), "глубина")
	ok(v.z < 0.0, "задний ход — минус")
	var s: Vector3 = main.bridge.screens_mat.get_shader_parameter("status")
	eq(s.x, 1.0 if Searchlight.lit(main.light_on, main.reactor.k(Reactor.Sys.LAMP)) else 0.0, "свет")
	main.queue_free()
	await frames(1)
