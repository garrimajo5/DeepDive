extends TestCase
## Арка врат 07 — модель MOD-023 в сцене (#1757; до неё — временные блоки, #826): габарит, проход 48 × 22 м,
## блоки коллизии по силуэту модели, LOD, гнёзда снаружи, корабль не проходит сквозь опору, но проходит проходом.


func _c(dx: float, y: float, dz: float) -> Vector3:
	return Vector3(EcoGate.CENTER.x + dx, y, EcoGate.CENTER.y + dz)


func test_size_and_top_under_ice() -> void:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for b: AABB in GateArch.boxes():
		lo = lo.min(b.position)
		hi = hi.max(b.end)
	near(hi.x - lo.x, 120.0, 0.01, "ширина 120 м")
	near(hi.z - lo.z, 23.0, 0.01, "глубина 23 м")
	near(hi.y, GateArch.HEIGHT, 0.01, "рост модели")
	near(GateArch.floor_y(), Seabed.Layer.TROUGH_FLOOR, 0.5, "пол — дно жёлоба, 66 м")
	near(GateArch.floor_y() + hi.y, -GateArch.TOP_DEPTH, 0.5, "верх на 8 м")
	ok(GateArch.floor_y() + hi.y < Helm.Ship.CEILING, "верх ниже потолка хода")


## Проход модели 48 × 22 м пуст, выше него — плечи опор; свод проёма между плечами — до перемычки.
func test_passage_free() -> void:
	var f := GateArch.floor_y()
	eq(GateArch.PASS_HALF, 24.0, "полуширина прохода по модели")
	eq(GateArch.PASS_TOP, 22.0, "высота прохода по модели")
	for x in [-23.5, -12.0, 0.0, 12.0, 23.5]:
		for y in [0.5, 11.0, 21.5]:
			for z in [-11.0, 0.0, 11.0]:
				ok(not GateArch.inside(_c(x, f + y, z)), "проход пуст: %s %s %s" % [x, y, z])
	ok(GateArch.inside(_c(45.0, f + 10.0, 0.0)), "правая опора твёрдая")
	ok(GateArch.inside(_c(-45.0, f + 10.0, 0.0)), "левая опора твёрдая")
	ok(GateArch.inside(_c(-20.0, f + 25.0, 0.0)), "левое плечо над проходом")
	ok(GateArch.inside(_c(24.0, f + 25.0, 0.0)), "правое плечо над проходом")
	ok(not GateArch.inside(_c(3.0, f + 35.0, 0.0)), "проём между плечами пуст")
	ok(GateArch.inside(_c(3.0, f + 43.0, 0.0)), "перемычка над проёмом")


## Блоки идут по силуэту модели: в каждом блоке есть её вершины (не пустой объём), и не меньше 85 % вершин LOD0
## выше пола лежат в блоках с запасом 2,5 м (фактура Meshy бугристая).
func test_boxes_follow_model() -> void:
	var n: Node3D = (load(GateArch.MODEL) as PackedScene).instantiate()
	var mi := n.get_node("LOD0/LOD0_Mineral") as MeshInstance3D
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var boxes := GateArch.boxes()
	var filled: Array[int] = []
	filled.resize(boxes.size())
	var total := 0
	var covered := 0
	for i in range(0, v.size(), 7):
		var p: Vector3 = mi.transform * v[i]
		total += 1
		var got := false
		for k in boxes.size():
			if boxes[k].has_point(p):
				filled[k] += 1
			if boxes[k].grow(2.5).has_point(p):
				got = true
		if got:
			covered += 1
	for k in boxes.size():
		ok(filled[k] > 0, "в блоке %d есть модель" % k)
	ok(covered >= total * 0.85, "вершин модели в блоках: %d из %d" % [covered, total])
	n.free()


## Запас по высоте — корпус: под плечом (низ на 22 м от пола) центр корабля проходит не выше 22 − 4,8 м.
func test_hull_height_under_shoulder() -> void:
	var f := GateArch.floor_y()
	ok(not GateArch.hits(_c(-18.0, f + 22.0 - GateArch.SHIP_UP - 0.2, 0.0), 0.0), "под плечом корпус проходит")
	ok(GateArch.hits(_c(-18.0, f + 22.0 - GateArch.SHIP_UP + 0.2, 0.0), 0.0), "рубка задевает плечо")
	ok(GateArch.hits(_c(0.0, f + 41.0 - 2.0, 0.0), 0.0), "под перемычкой рубка задевает её")
	ok(not GateArch.hits(_c(3.0, f + 33.0, 0.0), 0.0), "середина проёма между плечами свободна")


func test_lod_ranges_no_gaps() -> void:
	for lite in [false, true]:
		var at := 0.0
		for i in 3:
			var r := GateArch.ranges(i, lite)
			if r.x < 0.0:
				continue
			near(r.x, at, 0.001, "LOD %d начинается, где кончился прежний (lite %s)" % [i, lite])
			at = r.y
		eq(at, 0.0, "последний LOD — без предела")
	ok(GateArch.ranges(0, true).x < 0.0, "«Экономно» — без LOD0")
	ok(GateArch.ranges(0, false).y > 100.0, "обычно LOD0 — вблизи")


func test_nests_outside_arch_and_dome_home_free() -> void:
	for i in GateDiag.NESTS.size():
		ok(not GateArch.inside(GateDiag.nest_pos(i) + Vector3.UP * 0.5), "гнездо %d перед аркой" % i)
	var h := EcoGate.CENTER + EcoDome.HOME_OFF
	ok(not GateArch.inside(Vector3(h.x, GateArch.floor_y() + 5.0, h.y)), "ниша купольника свободна")


func test_ship_through_passage_not_through_pillar() -> void:
	var ship := Helm.Ship.new()
	ship.ground = Seabed.height
	ship.solid = GateArch.hits
	ship.pos = _c(0.0, -58.0, 55.0)   # в жёлобе на проектных 58 м (#1757): выше — плечи арки
	ship.yaw = 0.0   # нос к −Z — вдоль прохода
	ship.in_thrust = 1.0
	for i in 600:
		ship.update(1.0 / 30.0)
	ok(ship.pos.z < EcoGate.CENTER.y - 20.0, "проходом прошёл насквозь: z %.1f" % ship.pos.z)
	var s2 := Helm.Ship.new()
	s2.ground = Seabed.height
	s2.solid = GateArch.hits
	s2.pos = _c(45.0, -52.0, 60.0)   # над склоном жёлоба, на высоте правой опоры (выше 28 м от пола там пусто)
	s2.yaw = 0.0
	s2.in_thrust = 1.0
	for i in 600:
		s2.update(1.0 / 30.0)
		ok(not GateArch.inside(s2.pos), "середина корабля не в опоре")
	ok(s2.pos.z > EcoGate.CENTER.y + GateArch.HALF_DEPTH, "в опору не вошёл: z %.1f" % s2.pos.z)


func test_without_solid_no_change() -> void:
	var ship := Helm.Ship.new()
	ship.ground = Seabed.height
	ship.pos = _c(45.0, -35.0, 60.0)
	ship.in_thrust = 1.0
	for i in 600:
		ship.update(1.0 / 30.0)
	ok(ship.pos.z < EcoGate.CENTER.y - 20.0, "без solid опора не мешает (прежний ход)")


func test_scene_has_arch_and_helm_solid() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ok(main.gate_view != null and main.gate_view.is_inside_tree(), "арка в сцене")
	ok(main.helm.solid.is_valid(), "ход знает арку")
	var gv: GateView = main.gate_view
	eq(gv.get_parent(), main.ocean, "арка под океаном")
	near(gv.model.position.y, GateArch.floor_y(), 0.001, "модель стоит на полу жёлоба")
	near(gv.model.position.x, EcoGate.CENTER.x, 0.001, "в середине террасы по X")
	near(gv.model.position.z, EcoGate.CENTER.y, 0.001, "в середине террасы по Z")
	near(gv.model.rotation.y, 0.0, 0.001, "подход с +Z — как в файле")
	eq(gv.nests.mesh.get_surface_count(), 1, "чаши гнёзд — временные")
	for i in 3:
		for mi: MeshInstance3D in gv.lod_meshes(i):
			eq(mi.layers, OceanView.LAYER_WORLD, "%s на слое отмели" % mi.name)
			var r := GateArch.ranges(i, main.gate_view.lite)
			near(mi.visibility_range_begin, maxf(r.x, 0.0), 0.001, "%s: начало LOD" % mi.name)
			near(mi.visibility_range_end, maxf(r.y, 0.0), 0.001, "%s: конец LOD" % mi.name)
	for n in GateView.HIDDEN:
		ok(not (gv.model.get_node(n) as Node3D).visible, "%s скрыта до гнёзд" % n)
	main._apply_graphics(Graphics.ECONOMY)
	ok(gv.lite, "«Экономно» дошло до арки")
	for mi: MeshInstance3D in gv.lod_meshes(0):
		ok(not mi.visible, "«Экономно»: LOD0 не рисуется")
	for mi: MeshInstance3D in gv.lod_meshes(1):
		near(mi.visibility_range_begin, 0.0, 0.001, "«Экономно»: LOD1 вблизи")
	main.queue_free()
	await frames(1)


## Отчёт тестера c8b38fa, п. 4: со старта в окне вдали тёмный силуэт арки. Штатный туман давал ей базовый цвет ART-059
## (темнее воды со слоями ART-069 вокруг) — материалы арки пишут FOG слоями воды, как дно, и получают их числа.
func test_arch_fog_uses_water_layers() -> void:
	var sh := FileAccess.get_file_as_string("res://shaders/gate_arch.gdshader")
	ok(sh.contains("water_layers.gdshaderinc") and sh.contains("FOG = water_layers_fog("), "шейдер арки пишет слои в FOG")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var gv: GateView = main.gate_view
	var o: OceanView = main.ocean
	var all: Array = gv.model.find_children("*", "MeshInstance3D", true, false)
	all.append(gv.nests)
	eq(gv.mats.size(), 4, "минерал, кабель, полипы и чаши — по материалу на все LOD")
	for mi: MeshInstance3D in all:
		var m := mi.get_surface_override_material(0) as ShaderMaterial
		ok(m != null, "%s — свой шейдер, не StandardMaterial3D" % mi.name)
		if m == null:
			continue
		ok(gv.mats.has(m), "%s: материал общий" % mi.name)
		ok(o.layer_mats().has(m), "%s: материал в слоях воды" % mi.name)
		near(float(m.get_shader_parameter("layer_density")), main.env.fog_density, 0.00001, "плотность — как туман сцены")
		var c: Vector3 = m.get_shader_parameter("layer_ice_color")
		near(c.z, WaterLayers.ICE.color.srgb_to_linear().b, 0.0001, "цвета слоёв переданы")
	o.apply_water(main.env, 45.0, Vector3.ZERO, 0.0)
	var mineral := gv.lod_meshes(0)[0] as MeshInstance3D
	for mi: MeshInstance3D in gv.lod_meshes(0):
		if String(mi.name).ends_with("Mineral"):
			mineral = mi
	var m0 := mineral.get_surface_override_material(0) as ShaderMaterial
	if m0:
		ok(m0.get_shader_parameter("albedo_tex") != null, "минерал — с картой цвета модели")
		ok(m0.get_shader_parameter("normal_tex") != null, "и с нормалями")
		near(float(m0.get_shader_parameter("layer_density")), main.env.fog_density, 0.00001, "новая глубина — новый туман")
		near(float(m0.get_shader_parameter("layer_gain")), float(o.seabed_mat.get_shader_parameter("layer_gain")), 0.00001,
			"сила слоёв как у дна")
	eq(o.layer_mats().size(), 7, "дно, лёд, дальняя вода и четыре материала арки — без повторов")
	main.queue_free()
	await frames(1)
