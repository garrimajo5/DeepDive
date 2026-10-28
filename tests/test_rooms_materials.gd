extends TestCase
## Материалы машинного и трюма ART-055 (RoomsView.KITS, шейдер ship_surface): комплекты по z внутри тех же
## краски-поверхностей, что у мостика (без новых вызовов), отрезки совпадают с отсеками ShipLayout, кромка шлюза
## и коридор с лабораторией — заливкой, «Экономно» выключает рельеф.

const P := BridgePlan.Paint


func _surface(mesh: ArrayMesh, paint: int) -> int:
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var c: Color = m.get_shader_parameter("base_color") if m is ShaderMaterial else (m as StandardMaterial3D).albedo_color
		if c.is_equal_approx(BridgePlan.COLORS[paint]):
			return i
	return -1


func _mat(mesh: ArrayMesh, paint: int) -> ShaderMaterial:
	return mesh.surface_get_material(_surface(mesh, paint)) as ShaderMaterial


func _tex(m: ShaderMaterial, name: String) -> String:
	return (m.get_shader_parameter(name) as Texture2D).resource_path


func test_kits_by_room() -> void:
	var plain := BridgeView.build_mesh(ShipLayout.parts())
	var mesh := BridgeView.build_mesh(ShipLayout.parts(), RoomsView.KITS, RoomsView.KIT_DIR)
	eq(mesh.get_surface_count(), plain.get_surface_count(), "поверхностей (вызовов) не больше")
	var deck := _mat(mesh, P.DECK)
	ok(deck != null and deck.shader.resource_path == "res://shaders/ship_surface.gdshader", "пол — ship_surface")
	ok(_tex(deck, "side_albedo").ends_with("rooms/mash-pol-tsvet.png"), "пол машинного — рифлёный")
	ok(_tex(deck, "aft_normal").ends_with("rooms/tryum-pol-normali.png"), "пол трюма — свой")
	var metal := _mat(mesh, P.METAL)
	ok(_tex(metal, "side_orm").ends_with("rooms/mash-stena-orm.png"), "стены машинного")
	ok(_tex(metal, "aft_albedo").ends_with("rooms/tryum-stena-tsvet.png"), "стены трюма")
	ok(_tex(metal, "down_albedo").ends_with("rooms/otsek-potolok-tsvet.png"), "низ перемычек — потолок отсеков")
	ok(metal.get_shader_parameter("skip_up"), "кромка шлюза (грань вверх) — заливкой")
	ok(not deck.get_shader_parameter("skip_up"), "пол — с картами")
	var seam := _mat(mesh, P.SEAM)
	ok(seam.get_shader_parameter("down_kit") and not seam.get_shader_parameter("side_kit"), "потолок — общий комплект")
	for paint in [P.PLAFOND, P.SHADOW]:
		var i := _surface(mesh, paint)
		ok(i < 0 or mesh.surface_get_material(i) is StandardMaterial3D, "краска %d — прежняя" % paint)


func test_zones_match_rooms() -> void:
	var engine: Array = ShipLayout.ROOMS[ShipLayout.Room.ENGINE]
	var cargo: Array = ShipLayout.ROOMS[ShipLayout.Room.CARGO]
	var lab: Array = ShipLayout.ROOMS[ShipLayout.Room.LAB]
	var mesh := BridgeView.build_mesh(ShipLayout.parts(), RoomsView.KITS, RoomsView.KIT_DIR)
	for paint in [P.DECK, P.METAL]:
		var m := _mat(mesh, paint)
		var side: Vector2 = m.get_shader_parameter("side_z")
		var aft: Vector2 = m.get_shader_parameter("aft_z")
		near(side.x, engine[0], 1e-4, "машинное с переборки у лаборатории")
		near(side.y, engine[1], 1e-4, "до переборки трюма")
		near(aft.x, cargo[0], 1e-4, "трюм с переборки")
		ok(aft.y > float(cargo[1]) + 0.1, "и корма внутри")
		ok(side.x >= float(lab[1]), "лаборатория — без карт")
	var down: Vector2 = _mat(mesh, P.SEAM).get_shader_parameter("down_z")
	near(down.x, engine[0], 1e-4, "потолок — с машинного")
	# переборка между машинным и трюмом: передняя грань (z − 0,1) — машинное, задняя (z + 0,1) — трюм
	var z: float = ShipLayout.DOOR_Z[3]
	var sz: Vector2 = _mat(mesh, P.METAL).get_shader_parameter("side_z")
	var az: Vector2 = _mat(mesh, P.METAL).get_shader_parameter("aft_z")
	ok(z - 0.1 >= sz.x and z - 0.1 < sz.y, "передняя грань переборки — машинное")
	ok(z + 0.1 >= az.x and z + 0.1 < az.y and not (z + 0.1 < sz.y), "задняя — трюм")


func test_bridge_kits_whole_ship() -> void:
	var m := BridgeView.kit_material(P.METAL)
	eq(m.get_shader_parameter("side_z"), Vector2(-1e6, 1e6), "у мостика отрезок — весь корабль")
	ok(not m.get_shader_parameter("aft_kit"), "aft у мостика нет")
	ok(not m.get_shader_parameter("skip_up"), "грани вверх у мостика — с картами")


func test_maps_imported() -> void:
	for k in ["mash-pol", "mash-stena", "tryum-pol", "tryum-stena", "otsek-potolok"]:
		for c in ["tsvet", "normali", "orm"]:
			var t := load(RoomsView.KIT_DIR + "%s-%s.png" % [k, c]) as Texture2D
			ok(t != null and t.get_width() == 1024, "%s-%s 1024²" % [k, c])
			var cfg := ConfigFile.new()
			cfg.load(RoomsView.KIT_DIR + "%s-%s.png.import" % [k, c])
			ok(cfg.get_value("params", "mipmaps/generate", false), "%s-%s с mipmap" % [k, c])
			eq(cfg.get_value("params", "compress/mode", -1), 0 if c == "normali" else 2, "%s-%s сжатие как у мостика" % [k, c])


func test_scene_relief_toggle() -> void:
	var r := RoomsView.new()
	tree.root.add_child(r)
	await frames(1)
	var m := _mat(r.mesh, P.DECK)
	ok(m.get_shader_parameter("relief"), "по умолчанию рельеф")
	r.set_relief(false)
	ok(not m.get_shader_parameter("relief"), "«Экономно» — без нормалей и ORM")
	await frames(1)
	r.queue_free()
	await frames(1)
