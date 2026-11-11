extends TestCase
## Ореол силуэта крупных существ (Б4): край тела светится цветом воды и без огней, в глубине сильнее, вдали гаснет;
## «Экономно» снимает проход.


func test_strength_grows_with_depth() -> void:
	near(EcoSilhouette.strength(0.0), EcoSilhouette.SHALLOW, 1e-6, "у льда — слабый")
	near(EcoSilhouette.strength(200.0), EcoSilhouette.DEEP, 1e-6, "в темноте — полный")
	ok(EcoSilhouette.strength(30.0) > EcoSilhouette.strength(10.0), "глубже — сильнее")


func test_color_keeps_water_hue_in_dark() -> void:
	var shallow := EcoSilhouette.color(5.0)
	var deep := EcoSilhouette.color(280.0)
	near(maxf(deep.r, maxf(deep.g, deep.b)), EcoSilhouette.LEVEL, 1e-5, "на склоне не гаснет с водой")
	near(maxf(shallow.r, maxf(shallow.g, shallow.b)), EcoSilhouette.LEVEL, 1e-5, "яркость одна")
	ok(deep.b > deep.r and shallow.b > shallow.r, "оттенок воды — сине-зелёный")


func test_edge_and_fade() -> void:
	near(EcoSilhouette.edge(1.0), 0.0, 1e-6, "лицом к взгляду — без ореола")
	near(EcoSilhouette.edge(0.0), 1.0, 1e-6, "по касательной — полный")
	ok(EcoSilhouette.edge(0.3) > EcoSilhouette.edge(0.7), "к краю ярче")
	near(EcoSilhouette.fade(0.0, 0.02), 1.0, 1e-6, "вблизи — весь")
	ok(EcoSilhouette.fade(100.0, 0.02) < 0.15, "за 100 м почти погас")


func test_halo_only_on_lit_bodies() -> void:
	EcoSilhouette.set_lite(false)
	var body := StandardMaterial3D.new()
	ok(EcoSilhouette.halo(body), "тело — с ореолом")
	eq(body.next_pass, EcoSilhouette.halo_material(), "второй проход — общий материал")
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ok(not EcoSilhouette.halo(glow) and glow.next_pass == null, "огонёк — без ореола")
	var see := StandardMaterial3D.new()
	see.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ok(not EcoSilhouette.halo(see), "прозрачное — без ореола")
	EcoSilhouette.set_lite(true)
	ok(body.next_pass == null, "«Экономно» — проход снят")
	EcoSilhouette.set_lite(false)
	eq(body.next_pass, EcoSilhouette.halo_material(), "вернулся")


func test_depth_sets_uniforms() -> void:
	EcoSilhouette.set_depth(150.0)
	var m := EcoSilhouette.halo_material()
	near(float(m.get_shader_parameter("halo")), EcoSilhouette.strength(150.0), 1e-6, "сила по глубине")
	near(float(m.get_shader_parameter("density")), Seabed.Water.fog_density(150.0), 1e-6, "плотность воды")
	EcoSilhouette.set_depth(20.0)


func test_scene_serpohvost_has_halo() -> void:
	EcoSilhouette.set_lite(false)
	var ev := EcoView.new()
	tree.root.add_child(ev)
	await frames(2)
	var bodies := 0
	for gi in EcoShadows.casters(ev.pred_view):
		for m in EcoRim.materials(gi):
			if m is BaseMaterial3D and (m as BaseMaterial3D).next_pass == EcoSilhouette.halo_material():
				bodies += 1
	ok(bodies > 0, "тела серпохвостов — с ореолом")
	var others := 0
	for c in ev.get_children():
		if c == ev.pred_view:
			continue
		for gi in EcoShadows.casters(c):
			for m in EcoRim.materials(gi):
				if m is BaseMaterial3D and (m as BaseMaterial3D).next_pass == EcoSilhouette.halo_material():
					others += 1
	eq(others, 0, "мелочь и места — без ореола")
	ev.set_lite(true)
	for gi in EcoShadows.casters(ev.pred_view):
		for m in EcoRim.materials(gi):
			if m is BaseMaterial3D:
				ok((m as BaseMaterial3D).next_pass == null, "«Экономно» — без прохода")
	ev.set_lite(false)
	ev.queue_free()
	await frames(1)
