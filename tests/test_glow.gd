extends TestCase
## Голубые огни текстур светятся, остальное — нет.


func _image(model: String) -> Image:
	var scene: PackedScene = load("res://models/%s.glb" % model)
	var node := scene.instantiate()
	var mi: MeshInstance3D = node.find_children("*", "MeshInstance3D", true, false)[0]
	var img := (mi.get_active_material(0) as BaseMaterial3D).albedo_texture.get_image()
	node.free()
	if img.is_compressed():
		img.decompress()
	return img


func test_mask_colors() -> void:
	ok(TextureGlow.glows(Color("67DDEB")), "голубой огонь #67DDEB светится")
	ok(not TextureGlow.glows(Color("8C806B")), "металл не светится")
	ok(not TextureGlow.glows(Color("0B1C24")), "тёмный не светится")
	ok(not TextureGlow.glows(Color("2A6A75")), "тусклый бирюзовый не светится")


func test_lights_found_only_on_lit_models() -> void:
	for m in TextureGlow.MODELS:
		var sh := TextureGlow.share(_image(m))
		ok(sh > 0.002 and sh < 0.05, "%s: огни — малая доля текстуры (%.2f%%)" % [m, sh * 100])
	for m in ["kreslo-pilota", "shturval-koleso", "lyuk-rama"]:
		near(TextureGlow.share(_image(m)), 0.0, 0.0005, "%s без огней" % m)


func test_bridge_models_use_glow_shader() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	for name in [BridgeProps.TABLE, BridgeProps.CONSOLE]:
		var mi: MeshInstance3D = main.bridge.props[name].find_children("*", "MeshInstance3D", true, false)[0]
		var sm := mi.material_override as ShaderMaterial
		ok(sm != null and sm.shader == BridgeView.GLOW_SHADER, "%s — шейдер огней" % name)
		if sm:
			ok(sm.get_shader_parameter("albedo_tex") != null and sm.get_shader_parameter("mask_tex") != null, "%s — текстура на месте" % name)
	var chair: MeshInstance3D = main.bridge.props[BridgeProps.CHAIR].find_children("*", "MeshInstance3D", true, false)[0]
	ok(chair.material_override == null, "кресло без шейдера огней")
