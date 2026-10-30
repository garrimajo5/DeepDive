extends TestCase
## Временная арка врат 07 (#826, часть 2): габарит ART-079, свободный проход, гнёзда снаружи, корабль не проходит
## сквозь опору, но проходит проходом.


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
	ok(GateArch.floor_y() + hi.y <= -GateArch.TOP_DEPTH + 0.01, "верх не выше 8 м")
	ok(GateArch.floor_y() + hi.y < Helm.Ship.CEILING, "верх ниже потолка хода")


func test_passage_free() -> void:
	var f := GateArch.floor_y()
	for x in [-29.0, -15.0, 0.0, 15.0, 29.0]:
		for y in [0.5, 18.0, 35.5]:
			for z in [-11.0, 0.0, 11.0]:
				ok(not GateArch.inside(_c(x, f + y, z)), "проход пуст: %s %s %s" % [x, y, z])
	ok(GateArch.inside(_c(45.0, f + 10.0, 0.0)), "правая опора твёрдая")
	ok(GateArch.inside(_c(-45.0, f + 10.0, 0.0)), "левая опора твёрдая")
	ok(GateArch.inside(_c(0.0, f + 38.0, 0.0)), "перемычка над проходом")


func test_nests_outside_arch_and_dome_home_free() -> void:
	for i in GateDiag.NESTS.size():
		ok(not GateArch.inside(GateDiag.nest_pos(i) + Vector3.UP * 0.5), "гнездо %d перед аркой" % i)
	var h := EcoGate.CENTER + EcoDome.HOME_OFF
	ok(not GateArch.inside(Vector3(h.x, GateArch.floor_y() + 5.0, h.y)), "ниша купольника свободна")


func test_ship_through_passage_not_through_pillar() -> void:
	var ship := Helm.Ship.new()
	ship.ground = Seabed.height
	ship.solid = GateArch.hits
	ship.pos = _c(0.0, -35.0, 60.0)
	ship.yaw = 0.0   # нос к −Z — вдоль прохода
	ship.in_thrust = 1.0
	for i in 600:
		ship.update(1.0 / 30.0)
	ok(ship.pos.z < EcoGate.CENTER.y - 20.0, "проходом прошёл насквозь: z %.1f" % ship.pos.z)
	var s2 := Helm.Ship.new()
	s2.ground = Seabed.height
	s2.solid = GateArch.hits
	s2.pos = _c(45.0, -35.0, 60.0)
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
	eq(main.gate_view.mesh.get_surface_count(), 2, "арка и гнёзда")
	main.queue_free()
	await frames(1)
