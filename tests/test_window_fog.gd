extends TestCase
## Конденсат и иней на окнах мостика ART-077 (WindowFog, BridgeView.set_fog): по глубине, корпусу и нагреву реактора,
## сглажено на CPU; центр окна всегда чист; одна выборка, без экранного буфера.


func test_targets_from_acceptance() -> void:
	near(WindowFog.wet_target(8.0, 100.0, 0.0), 0.0168, 1e-4, "8 м, целый корпус — 0,0168 (слоя нет)")
	near(WindowFog.wet_target(45.0, 100.0, 0.0), 0.56, 1e-4, "45 м, целый — 0,56")
	near(WindowFog.wet_target(45.0, 30.0, 0.0), 1.0, 1e-4, "45 м, корпус 30 % — 1,0")
	near(WindowFog.wet_target(45.0, 30.0, 1.0), 0.2, 1e-4, "полный обогрев — 0,2")
	near(WindowFog.ice_target(45.0, 1.0), 0.0, 1e-6, "обогрев растапливает иней")
	near(WindowFog.ice_target(5.0, 0.0), 0.0, 1e-6, "на мели инея нет")
	near(WindowFog.ice_target(30.0, 0.0), WindowFog.cold(30.0), 1e-6)
	near(WindowFog.ice_target(8.0, 0.0), 0.0, 1e-6, "повреждение не создаёт мороз в тёплой воде")
	near(WindowFog.warm_target(20.0, 0.0), 0.0, 1e-6)
	near(WindowFog.warm_target(85.0, 0.0), 1.0, 1e-6, "перегрев 85 — полный обогрев")
	near(WindowFog.warm_target(85.0, 3.0), 0.0, 1e-6, "при сбросе реактора обогрева нет")


func test_smoothing() -> void:
	var f := WindowFog.new()
	f.snap(2.0, 100.0, 0.0, 0.0)
	ok(f.humidity < 0.02 and f.ice_k == 0.0, "на старте у поверхности окна сухие")
	f.step(1.0, 45.0, 100.0, 0.0, 0.0)
	ok(f.humidity > 0.0 and f.humidity < 0.1, "влажность копится медленно (τ 30 с): %.3f" % f.humidity)
	for i in 600:
		f.step(0.5, 45.0, 100.0, 0.0, 0.0)
	near(f.humidity, 0.56, 1e-3, "к установившейся 0,56")
	near(f.ice_k, 1.0, 1e-3, "иней на 45 м полный")
	var ice := f.ice_k
	f.step(1.0 / 30.0, 45.0, 100.0, 85.0, 0.0)
	ok(f.ice_k > ice - 0.05, "перегрев не сносит иней за один кадр")
	for i in 300:
		f.step(0.5, 45.0, 100.0, 85.0, 0.0)
	ok(f.ice_k < 0.05, "за пару минут нагрева иней растаял: %.3f" % f.ice_k)
	ok(f.warm > 0.95, "обогрев вышел на полный")


func test_mask_twins() -> void:
	var c := Color(0.8, 0.2, 0.9, 0.2)
	near(WindowFog.gate(0.2, 0.1), 0.0, 1e-6, "ниже порога — сухо")
	near(WindowFog.gate(0.2, 0.38), 1.0, 1e-6)
	near(WindowFog.drops(c, 1.0), 0.8, 1e-6)
	near(WindowFog.frost(c, 1.0, 0.5), 0.45, 1e-6)
	near(WindowFog.alpha(0.1, 0.0, 0.0), 0.1, 1e-6, "без слоя стекло ART-057 как было")
	ok(WindowFog.alpha(0.1, 1.0, 1.0) > 0.1 and WindowFog.alpha(0.1, 1.0, 1.0) < 0.7, "иней не глухой")
	ok(WindowFog.ICE_COLOR.b >= WindowFog.ICE_COLOR.r, "иней холодный")


func test_mask_center_clean() -> void:
	var t: Texture2D = load(WindowFog.MASK)
	ok(t != null, "маска грузится")
	var img := t.get_image()
	eq(img.get_width(), 256)
	ok(not img.is_compressed(), "без потерного сжатия")
	ok(img.has_mipmaps(), "с mipmap — капли сливаются на расстоянии")
	var src := Image.load_from_file(ProjectSettings.globalize_path(WindowFog.MASK))
	var bad := 0
	for y in range(int(256 * 0.22) + 1, int(256 * 0.78) - 1, 3):
		for x in range(int(256 * 0.22) + 1, int(256 * 0.78) - 1, 3):
			var p := src.get_pixel(x, y)
			if p.r > 0.0 or p.g > 0.0 or p.b > 0.0 or p.a < 1.0:
				bad += 1
	eq(bad, 0, "центр 56 × 56 % чист при любой влажности")
	var frame := 0.0
	for y in 256:
		frame = maxf(frame, src.get_pixel(2, y).b)
	ok(frame > 0.3, "у рамы есть иней")


func test_shader() -> void:
	var src: String = (load("res://shaders/window_glass.gdshader") as Shader).code
	ok(src.contains("condensation") and src.contains("humidity") and src.contains("ice_k"), "маска и сила в стекле")
	ok(not src.contains("hint_screen_texture"), "без экранного буфера")
	ok(not src.contains("CLEARCOAT"), "без CLEARCOAT (#535)")


func test_scene_fog_follows_depth() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var m: ShaderMaterial = main.bridge.glass_mat
	ok(m.get_shader_parameter("condensation") is Texture2D, "маска ART-077 в материале стекла")
	main.helm.pos.y = -2.0
	main.window_fog.snap(2.0, 100.0, 0.0, 0.0)
	main.step(1.0 / 30.0)
	ok(float(m.get_shader_parameter("humidity")) < 0.02, "у поверхности окна чистые")
	main.helm.pos.y = -45.0
	for i in 300:
		main.step(1.0 / 10.0)
	ok(float(m.get_shader_parameter("humidity")) > 0.3, "на 45 м запотели: %.2f" % float(m.get_shader_parameter("humidity")))
	ok(float(m.get_shader_parameter("ice_k")) > 0.5, "и иней в углах")
	near(m.get_shader_parameter("humidity"), main.window_fog.humidity, 1e-4, "в стекле — сглаженная влажность")
	main.queue_free()
	await frames(1)
