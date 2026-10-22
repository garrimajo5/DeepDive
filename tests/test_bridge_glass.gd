extends TestCase
## Стекло носовых окон ART-057 (BridgeView.glass_*, шейдер window_glass): участки по стойкам, отражения карты,
## центр окна чистый, муть у рамы, «Экономно» выключает нормали.


func test_split_by_mullions() -> void:
	var s := BridgeView.glass_split()
	near(s.x, 0.328947, 1e-5, "левая стойка")
	near(s.y, 0.671053, 1e-5, "правая стойка")


func test_glass_uv_mirrors() -> void:
	var s := BridgeView.glass_split()
	var l := BridgeView.glass_uv(Vector2(0.0, 0.2))
	near(l.x, 0.0, 1e-5, "левое: край квада — край карты")
	near(l.y, 0.2, 1e-5, "левое: v как есть")
	eq(Vector2(l.z, l.w), Vector2(1, 1), "левое: нормали как есть")
	var m := BridgeView.glass_uv(Vector2(s.x + 1e-4, 0.2))
	near(m.x, 1.0, 1e-3, "среднее отражено по U")
	eq(Vector2(m.z, m.w), Vector2(-1, 1), "среднее: нормаль x инвертирована")
	var r := BridgeView.glass_uv(Vector2(1.0, 0.2))
	near(r.x, 1.0, 1e-5, "правое: край квада — край карты")
	near(r.y, 0.8, 1e-5, "правое отражено по V")
	eq(Vector2(r.z, r.w), Vector2(1, -1), "правое: нормаль y инвертирована")
	for c in [s.x / 2.0, (s.x + s.y) / 2.0, (s.y + 1.0) / 2.0]:
		var w := BridgeView.glass_uv(Vector2(c, 0.5))
		near(w.x, 0.5, 1e-4, "центр окна — центр карты (u)")
		near(w.y, 0.5, 1e-4, "центр окна — центр карты (v)")


func _mask() -> Image:
	var img: Image = (load(BridgeView.KIT_DIR + "steklo-maska.png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	return img


func _alpha(img: Image, quad_uv: Vector2) -> float:
	var w := BridgeView.glass_uv(quad_uv)
	var x := clampi(int(w.x * img.get_width()), 0, img.get_width() - 1)
	var y := clampi(int(w.y * img.get_height()), 0, img.get_height() - 1)
	return img.get_pixel(x, y).a


func test_center_clean_frame_dirty() -> void:
	var img := _mask()
	var s := BridgeView.glass_split()
	for c in [s.x / 2.0, (s.x + s.y) / 2.0, (s.y + 1.0) / 2.0]:
		ok(_alpha(img, Vector2(c, 0.5)) < 0.02, "центр окна %.2f чистый" % c)
	# у рамы каждого окна грязнее, чем в центре: среднее по краю
	for edge in [[0.0, s.x], [s.x, s.y], [s.y, 1.0]]:
		var sum := 0.0
		for i in 20:
			var u: float = lerpf(edge[0], edge[1], (i + 0.5) / 20.0)
			sum += _alpha(img, Vector2(u, 0.01)) + _alpha(img, Vector2(u, 0.99))
		ok(sum / 40.0 > 0.05, "у рамы окна %.2f…%.2f муть (%.3f)" % [edge[0], edge[1], sum / 40.0])


func test_material_and_economy() -> void:
	var m := BridgeView.glass_material()
	eq(m.shader.resource_path, "res://shaders/window_glass.gdshader", "свой шейдер стекла")
	ok(m.get_shader_parameter("mask") != null and m.get_shader_parameter("normal_map") != null, "маска и нормали")
	var v := BridgeView.new()
	tree.root.add_child(v)
	await frames(1)
	ok(v.glass_mat.get_shader_parameter("relief"), "рельеф включён")
	v.set_relief(false)
	ok(not v.glass_mat.get_shader_parameter("relief"), "«Экономно» — стекло без нормалей")
	v.set_lamps(0.2)
	ok(not v.glass_mat.get_shader_parameter("relief"), "мигание не трогает материал стекла (альфа остаётся)")
	v.queue_free()
	await frames(1)
