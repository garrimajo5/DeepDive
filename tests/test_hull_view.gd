extends TestCase
## Корпус снаружи (HullMesh, HullView): формы лицом наружу, детали одной краски — одним мешем, роторы и рули
## движутся за пилотом, корпус на слое отмели и в бюджете телефона.


func _faces_out(b: HullMesh.Builder) -> bool:
	for t in b.triangles():
		var a := b.pos[b.idx[t * 3]]
		var c1 := b.pos[b.idx[t * 3 + 1]]
		var c2 := b.pos[b.idx[t * 3 + 2]]
		var n := b.nor[b.idx[t * 3]] + b.nor[b.idx[t * 3 + 1]] + b.nor[b.idx[t * 3 + 2]]
		if (c1 - a).cross(c2 - a).dot(n) > 1e-9:   # по CLAUDE.md (b − a) × (c − a) смотрит внутрь
			return false
	return true


func test_unit_forms_face_out() -> void:
	for f in HullPlan.Form.values():
		var b := HullMesh.unit(f)
		ok(b.triangles() > 0, "форма %d построена" % f)
		ok(_faces_out(b), "форма %d: лицевые стороны наружу" % f)
	# у выпуклых форм нормали смотрят от центра
	for f in [HullPlan.Form.CUBE, HullPlan.Form.SPHERE, HullPlan.Form.CAPSULE, HullPlan.Form.CYLINDER, HullPlan.Form.FRUSTUM]:
		var b := HullMesh.unit(f)
		var good := true
		for i in b.pos.size():
			good = good and (b.pos[i].length() < 1e-6 or b.nor[i].dot(b.pos[i]) > -1e-6)
		ok(good, "форма %d: нормали от центра" % f)


func test_unit_sizes() -> void:
	var cube := HullMesh.unit(HullPlan.Form.CUBE)
	var box := AABB(cube.pos[0], Vector3.ZERO)
	for p in cube.pos:
		box = box.expand(p)
	ok(box.size.is_equal_approx(Vector3.ONE), "куб 1 м")
	var dome := HullMesh.unit(HullPlan.Form.DOME)
	var low := INF
	for p in dome.pos:
		low = minf(low, p.y)
	near(low, -0.25, 1e-4, "купол срезан на y = −0,25")


func test_paints_and_parts() -> void:
	var count := 0
	for part in HullPlan.parts():
		if HullMesh.drawn(part):
			count += 1
	eq(count, 27, "все детали ART-001, кроме крышки шлюза (её рисует RoomsView)")
	var total := 0
	for paint in HullMesh.paints():
		var b := HullMesh.paint_builder(paint)
		ok(_faces_out(b), "краска %d: собранный меш лицом наружу" % paint)
		total += b.triangles()
	for part in HullPlan.parts():
		if HullMesh.moving(part):
			total += HullMesh.part_builder(part).triangles()
	ok(total < 12000, "корпус легче 12 тыс. треугольников: %d" % total)
	ok(HullMesh.glow(HullPlan.Paint.WINDOW) > 0.0 and HullMesh.glow(HullPlan.Paint.METAL) == 0.0, "окна светятся, металл — нет")


func test_body_mesh_matches_plan() -> void:
	# меш основных объёмов лежит на поверхности форм HullPlan (по ним существа обходят корабль):
	# чуть внутрь от середины треугольника — внутри детали, чуть наружу — снаружи
	for part in HullPlan.parts():
		if not (part.piece in [HullPlan.Piece.BODY, HullPlan.Piece.NOSE, HullPlan.Piece.STERN]):
			continue
		var b := HullMesh.Builder.new()
		b.merge(HullMesh.unit(part.form), part.xform())
		var good := 0
		for t in b.triangles():
			var i := t * 3
			var c := (b.pos[b.idx[i]] + b.pos[b.idx[i + 1]] + b.pos[b.idx[i + 2]]) / 3.0
			var n := (b.nor[b.idx[i]] + b.nor[b.idx[i + 1]] + b.nor[b.idx[i + 2]]).normalized()
			if part.contains(c - n * 0.03) and not part.contains(c + n * 0.3):   # снаружи — с запасом на прогиб хорды
				good += 1
		ok(good > b.triangles() * 0.9, "%s: меш на поверхности формы (%d из %d)" % [part.name, good, b.triangles()])


func test_motion() -> void:
	var m := HullMesh.Motion.new()
	for i in 90:
		m.update(1.0 / 30.0, 1.0, 1.0, 1.0)
	ok(m.spin > 0.9 and m.spin <= 1.0, "роторы раскрутились за тягой: %.2f" % m.spin)
	ok(m.pitch > 24.0, "рули встали на всплытие: %.1f°" % m.pitch)
	ok(m.rotor_angle_of(-1.0) == -m.rotor_angle, "роторы бортов навстречу")
	for i in 150:
		m.update(1.0 / 30.0, 1.0, 0.0, 0.0)
	ok(m.spin < 0.01, "без энергии двигателей роторы встали")
	ok(absf(m.pitch) < 0.5, "рули вернулись")


func test_scene_hull() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var hull := main.hull
	ok(hull != null and hull.get_parent() == main.ship, "корпус едет с кораблём")
	eq(hull.body.layers, OceanView.LAYER_WORLD, "корпус на слое отмели: его освещают лёд и прожектор")
	eq(hull.body.mesh.get_surface_count(), HullMesh.paints().size(), "по поверхности на краску")
	eq(hull.rotors.size(), 2, "два ротора")
	eq(hull.rudders.size(), 2, "два руля глубины")
	main.sit_at_helm()
	var rudder := hull.rudders[0]
	var tail := func() -> float: return (rudder.global_transform * Vector3(0, 0, 0.9)).y - rudder.global_position.y
	var tail0: float = tail.call()
	var b0 := hull.rotors[0].basis
	var r := main.overlay.router
	r.begin(1, r.layout.up.c)   # «Всплыть» и полный ход крестовиной
	r.begin(2, r.layout.pad.c)
	r.moved(2, r.layout.pad.c + Vector2(0, -r.layout.pad.r))
	for i in 60:
		main.step(1.0 / 30.0)
	ok(not hull.rotors[0].basis.is_equal_approx(b0), "ротор повернулся")
	ok(tail.call() > tail0 + 0.2, "при всплытии задняя кромка руля поднята: %.2f → %.2f" % [tail0, tail.call()])
	ok(hull_rotor_turns(main), "двигатели на ходу")
	r.end(1)
	r.end(2)


func hull_rotor_turns(main: Main) -> bool:
	return main.hull_motion.spin > 0.5
