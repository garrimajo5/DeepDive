extends TestCase
## Лучи сквозь трещины льда по ART-052 (`LightShafts`, `OceanView.shafts`): раскладка группами без решётки,
## размеры по заказу, гашение по глубине, вдали, у камеры, у дна и у Края; один MultiMesh; внутри корпуса света нет.


func test_strength_by_depth_and_distance() -> void:
	near(LightShafts.intensity(0.0), 0.14, 1e-6, "у льда")
	ok(LightShafts.intensity(5.0) > LightShafts.intensity(30.0) * 4.0, "глубже — заметно слабее")
	ok(LightShafts.intensity(30.0) < 0.02, "на 30 м едва видно")
	near(LightShafts.intensity(-3.0), 0.14, 1e-6, "над льдом не ярче, чем у льда")
	near(LightShafts.far_k(10.0), 1.0, 1e-6, "рядом — полная сила")
	near(LightShafts.far_k(95.0), 0.0, 1e-6, "дальше 95 м — гаснут")
	near(LightShafts.near_k(0.3), 0.0, 1e-6, "у самой камеры не заливают стекло")
	near(LightShafts.near_k(2.0), 1.0, 1e-6)
	near(LightShafts.floor_k(-20.0, -20.0), 0.0, 1e-6, "у дна обрываются")
	near(LightShafts.floor_k(-16.0, -20.0), 1.0, 1e-6, "выше дна на 3+ м — полная сила")
	near(LightShafts.edge_k(100.0), 1.0, 1e-6, "на отмели — полная сила")
	near(LightShafts.edge_k(LightShafts.EDGE_X), 0.0, 1e-6, "у Края — гаснут, без световой стены")


func test_layout_groups_sizes() -> void:
	var all := LightShafts.layout()
	var cells := int(Seabed.SIZE / LightShafts.CELL)
	ok(all.size() > 150 and all.size() < cells * cells / 2, "шахт %d: группами, не в каждой клетке" % all.size())
	eq(LightShafts.layout().size(), all.size(), "раскладка детерминирована")
	var min_gap := INF
	for a in all:
		ok(a.top.x < LightShafts.EDGE_X, "за Краем шахт нет")
		near(a.top.y, Seabed.ICE_Y, 1e-6, "верх — у льда")
		ok(a.length <= LightShafts.LEN_MAX + 1e-4, "длина ≤ 42 м")
		ok(a.length <= (Seabed.ICE_Y - a.floor_y) / 1.0 / cos(deg_to_rad(LightShafts.TILT_MAX)) + LightShafts.FLOOR_FADE + 1e-3,
			"не уходит глубоко под дно")
		ok(a.r_top * 2.0 >= 0.8 - 1e-4 and a.r_top * 2.0 <= 2.0 + 1e-4, "диаметр у льда 0,8–2 м")
		ok(a.r_bot * 2.0 >= 5.0 - 1e-4 and a.r_bot * 2.0 <= 13.0 + 1e-4, "внизу 5–13 м")
		ok(a.power > 0.0 and a.power <= 1.0, "сила 0…1")
		var tilt := rad_to_deg(a.axis.angle_to(Vector3.DOWN))
		ok(tilt <= LightShafts.TILT_MAX + 0.01, "наклон до 8°")
		for b in all:
			if a != b and absf(a.top.x - b.top.x) < 30.0 and absf(a.top.z - b.top.z) < 30.0:
				min_gap = minf(min_gap, Vector2(a.top.x - b.top.x, a.top.z - b.top.z).length())
	ok(min_gap >= 12.0, "между центрами не меньше 12 м (%.1f)" % min_gap)
	var start := LightShafts.near(all, Helm.Ship.START, 95.0)
	ok(start.size() >= 4, "у старта видно хотя бы группу шахт (%d)" % start.size())


func test_instance_xform_points_down_axis() -> void:
	var s := LightShafts.Shaft.new()
	s.top = Vector3(3, 0, -4)
	s.axis = Vector3(0.1, -1, 0).normalized()
	var t := LightShafts.instance_xform(s)
	var bottom := t * Vector3(0, -10, 0)
	ok(bottom.distance_to(s.top + s.axis * 10.0) < 1e-3, "локальная −Y идёт вдоль оси шахты")
	ok(absf(t.basis.determinant() - 1.0) < 1e-4, "без растяжения и зеркала")


func test_cone_mesh_winding_outward() -> void:
	var arr := LightShafts.cone_arrays()
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	eq(idx.size(), LightShafts.SEGMENTS * LightShafts.RINGS * 6, "открытый конус без торцов")
	for i in range(0, idx.size(), 6 * 5):
		var a := pos[idx[i]]
		var b := pos[idx[i + 1]]
		var c := pos[idx[i + 2]]
		var n := (b - a).cross(c - a)
		var mid := (a + b + c) / 3.0
		ok(n.dot(Vector3(mid.x, 0, mid.z)) < 0.0, "по часовой снаружи: (b − a) × (c − a) смотрит внутрь")
	eq((arr[Mesh.ARRAY_COLOR] as PackedColorArray).size(), pos.size(), "белый цвет вершин — под цвет экземпляра")


func test_no_light_inside_ship() -> void:
	ok(LightShafts.in_ship(Vector3(0, 1.6, 0)), "мостик — внутри")
	ok(LightShafts.in_ship(Vector3(0, 1.6, 20)), "трюм — внутри")
	ok(not LightShafts.in_ship(Vector3(0, 1.6, -12)), "перед носовым окном — снаружи")
	ok(not LightShafts.in_ship(Vector3(9, 1.6, 10)), "за бортом — снаружи")
	ok(not LightShafts.in_ship(Vector3(0, 7, 10)), "над корпусом — снаружи")


func test_scene_one_multimesh() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var node := main.ocean.shafts
	ok(node != null and node.multimesh != null, "лучи — MultiMeshInstance3D")
	eq(node.multimesh.instance_count, LightShafts.layout().size(), "все шахты в одном MultiMesh")
	eq(node.layers, OceanView.LAYER_WORLD, "слой отмели")
	var m := main.ocean.shafts_mat
	ok(m.render_priority < 0, "рисуются раньше снега и стекла")
	near(float(m.get_shader_parameter("depth_scale")), LightShafts.DEPTH_SCALE, 1e-6)
	near(float(m.get_shader_parameter("gain")), LightShafts.GAIN, 1e-6)
	ok(m.get_shader_parameter("mask_tex") is Texture2D and m.get_shader_parameter("noise_tex") is Texture2D, "маска и шум ART-052")
	# туман берётся из воды: глубже — гуще, шахты гаснут вместе с ним
	main.ocean.apply_water(main.env, 5.0, Vector3.ZERO, 0.0)
	near(float(m.get_shader_parameter("fog_density")), main.env.fog_density, 1e-6, "туман шахт = туман сцены")
	# корабль сдвинулся — шейдер знает, где корпус
	main.ocean.set_ship(Vector3(10, -20, 30), 0.5)
	var inv: Projection = m.get_shader_parameter("ship_inv")
	var t := Transform3D(Basis(Vector3.UP, 0.5), Vector3(10, -20, 30))
	var p := t * Vector3(0, 1.6, 5)
	var local := Transform3D(inv) * p
	ok(local.distance_to(Vector3(0, 1.6, 5)) < 1e-3, "ship_inv переводит мир в оси корабля")
	main.queue_free()
	await frames(1)
