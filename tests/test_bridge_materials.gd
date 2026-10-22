extends TestCase
## Материалы мостика ART-054 (BridgeView.KITS, шейдер ship_surface): метровые планарные UV, касательные,
## карты на DECK/METAL/SEAM без новых поверхностей, «Экономно» выключает рельеф.


func test_planar_uv() -> void:
	var p := Vector3(1.5, 2.0, -3.25)
	eq(BridgeView.planar_uv(p, Vector3.UP), Vector2(1.5, -3.25), "пол: (x, z) в метрах")
	eq(BridgeView.planar_uv(p, Vector3.DOWN), Vector2(1.5, -3.25), "потолок: короба вдоль z")
	eq(BridgeView.planar_uv(p, Vector3.RIGHT), Vector2(-3.25, -2.0), "борт: вдоль корабля, v вниз")
	eq(BridgeView.planar_uv(p, Vector3.LEFT), Vector2(-3.25, -2.0), "левый борт так же")
	eq(BridgeView.planar_uv(p, Vector3.BACK), Vector2(1.5, -2.0), "переборка: (x, −y)")
	var slope := Vector3(0, -0.89, 0.45).normalized()   # скос потолка снизу
	eq(BridgeView.planar_uv(p, slope), Vector2(1.5, -3.25), "скос — как потолок")


func _surface(mesh: ArrayMesh, paint: int) -> int:
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var c: Color = m.get_shader_parameter("base_color") if m is ShaderMaterial else (m as StandardMaterial3D).albedo_color
		if c.is_equal_approx(BridgePlan.COLORS[paint]):
			return i
	return -1


func test_kits_on_bridge_only() -> void:
	var plain := BridgeView.build_mesh(BridgePlan.parts())
	var kits := BridgeView.build_mesh(BridgePlan.parts(), BridgeView.KITS)
	eq(kits.get_surface_count(), plain.get_surface_count(), "поверхностей (вызовов) не больше")
	for paint in [BridgePlan.Paint.DECK, BridgePlan.Paint.METAL, BridgePlan.Paint.SEAM]:
		var i := _surface(kits, paint)
		ok(i >= 0, "краска %d есть" % paint)
		var m := kits.surface_get_material(i) as ShaderMaterial
		ok(m != null and m.shader.resource_path == "res://shaders/ship_surface.gdshader", "краска %d — ship_surface" % paint)
		ok(m.get_shader_parameter("relief"), "рельеф включён")
	var deck := kits.surface_get_material(_surface(kits, BridgePlan.Paint.DECK)) as ShaderMaterial
	ok(deck.get_shader_parameter("side_kit") and not deck.get_shader_parameter("down_kit"), "пол — комплект сверху")
	ok((deck.get_shader_parameter("side_albedo") as Texture2D).resource_path.ends_with("bridge/pol-tsvet.png"), "пол — решётка")
	var metal := kits.surface_get_material(_surface(kits, BridgePlan.Paint.METAL)) as ShaderMaterial
	ok(metal.get_shader_parameter("side_kit") and metal.get_shader_parameter("down_kit"), "стены и скос в одном материале")
	ok((metal.get_shader_parameter("down_orm") as Texture2D).resource_path.ends_with("bridge/potolok-orm.png"), "скос — потолок")
	var seam := kits.surface_get_material(_surface(kits, BridgePlan.Paint.SEAM)) as ShaderMaterial
	ok(not seam.get_shader_parameter("side_kit"), "подложки плафонов — заливкой")
	ok(seam.get_shader_parameter("down_kit"), "потолок — с картами")
	for paint in [BridgePlan.Paint.PLAFOND, BridgePlan.Paint.SHADOW]:
		var i := _surface(kits, paint)
		ok(i < 0 or kits.surface_get_material(i) is StandardMaterial3D, "краска %d — прежняя" % paint)
	for i in plain.get_surface_count():
		ok(plain.surface_get_material(i) is StandardMaterial3D, "без kits (отсеки) — заливка")


func test_metric_uv_and_tangents() -> void:
	var mesh := BridgeView.build_mesh(BridgePlan.parts(), BridgeView.KITS)
	var a := mesh.surface_get_arrays(_surface(mesh, BridgePlan.Paint.DECK))
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var tan: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
	ok(uv.size() == pos.size() and tan.size() == pos.size() * 4, "UV и касательные у каждой вершины")
	var good := true
	var span := Rect2(uv[0], Vector2.ZERO)
	for i in pos.size():
		good = good and uv[i].is_equal_approx(BridgeView.planar_uv(pos[i], nor[i]))
		span = span.expand(uv[i])
	ok(good, "UV — метры по грани")
	ok(span.size.x >= 9.9, "пол 10 м — 10 плиток поперёк")
	var flat := true
	for i in pos.size():
		var t := Vector3(tan[i * 4], tan[i * 4 + 1], tan[i * 4 + 2])
		flat = flat and t.length() > 0.9 and absf(t.dot(nor[i])) < 0.01
	ok(flat, "касательные в плоскости грани")


func test_maps_imported() -> void:
	for k in ["pol", "stena", "potolok"]:
		for c in ["tsvet", "normali", "orm"]:
			var t := load(BridgeView.KIT_DIR + "%s-%s.png" % [k, c]) as Texture2D
			ok(t != null and t.get_width() == 1024, "%s-%s 1024²" % [k, c])
			var cfg := ConfigFile.new()
			cfg.load(BridgeView.KIT_DIR + "%s-%s.png.import" % [k, c])
			ok(cfg.get_value("params", "mipmaps/generate", false), "%s-%s с mipmap" % [k, c])


func test_scene_relief_toggle() -> void:
	var b := BridgeView.new()
	tree.root.add_child(b)
	await frames(1)
	var m := b.mesh_instance.mesh.surface_get_material(_surface(b.mesh_instance.mesh, BridgePlan.Paint.METAL)) as ShaderMaterial
	ok(m.get_shader_parameter("relief"), "по умолчанию рельеф")
	b.set_relief(false)
	ok(not m.get_shader_parameter("relief"), "«Экономно» — без нормалей и ORM")
	await frames(1)
	b.queue_free()
	await frames(1)
