extends TestCase
## Корпус снаружи по ART-001 (порт тестов pogrujenie HullPlanTests): детали, отсеки внутри, стекло, окна, двигатели.


func _of(piece: int) -> Array:
	return HullPlan.parts().filter(func(p: HullPlan.Part) -> bool: return p.piece == piece)


func test_28_parts_by_artist_table() -> void:
	eq(HullPlan.parts().size(), 28, "28 деталей")
	var expect := {
		HullPlan.Piece.BODY: 1, HullPlan.Piece.NOSE: 1, HullPlan.Piece.STERN: 1, HullPlan.Piece.GLASS: 1,
		HullPlan.Piece.LAB_WINDOW: 4, HullPlan.Piece.SHROUD: 2, HullPlan.Piece.ROTOR: 2, HullPlan.Piece.MOUNT: 2,
		HullPlan.Piece.RUDDER: 2, HullPlan.Piece.STABILIZER: 2, HullPlan.Piece.SEARCHLIGHT: 2,
		HullPlan.Piece.MANIPULATOR: 5, HullPlan.Piece.AIRLOCK: 1, HullPlan.Piece.COVER: 2,
	}
	for k in expect:
		eq(_of(k).size(), expect[k], "деталей вида %d" % k)


func test_rooms_entirely_inside_hull() -> void:
	var n := 0
	var all: Array = BridgePlan.parts() + ShipLayout.parts()
	for b in all:
		for c in b.corners():
			# снаружи у отсеков только оболочка мостика за окном — рама окна стоит на срезе носа, ей допуск
			if not ok(HullPlan.inside(c), "%s: угол %s торчит из корпуса" % [b.name, str(c)]):
				return
			n += 1
	ok(n > 300, "проверено углов: %d" % n)
	ok(not HullPlan.inside(Vector3(0, 1.6, -8)), "перед стеклом вода")
	ok(not HullPlan.inside(Vector3(7.5, 1.6, 10)), "за бортом вода")
	ok(not HullPlan.inside(Vector3(0, 1.6, 29.5)), "за кормой вода")


func test_rotate_unrotate() -> void:
	for p in HullPlan.parts():
		for v in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0.3, -0.5, 0.8)]:
			var r: Vector3 = p.rotate(v)
			near(r.length(), v.length(), 1e-5, "%s: поворот без растяжения" % p.name)
			ok(p.unrotate(r).distance_to(v) < 1e-5, "%s: обратный поворот" % p.name)
	# (90, 0, 0): ось y формы — вдоль +Z корабля
	var body: HullPlan.Part = _of(HullPlan.Piece.BODY)[0]
	ok(body.rotate(Vector3.UP).distance_to(Vector3(0, 0, 1)) < 1e-5, "капсула корпуса лежит вдоль корабля")
	ok(body.xform().basis.y.normalized().distance_to(Vector3(0, 0, 1)) < 1e-5, "xform поворачивает так же")


func test_glass_in_front_of_bridge_window() -> void:
	var g: HullPlan.Part = _of(HullPlan.Piece.GLASS)[0]
	ok(g.pos.z < -6.1, "стекло перед носовой стеной мостика")
	near(g.pos.z, HullPlan.NOSE_CUT, 0.05, "на срезе носа")
	ok(g.size.x / 2 >= BridgePlan.WINDOW_HALF, "стекло не уже окна")
	ok(g.pos.y - g.size.y / 2 <= BridgePlan.WINDOW_BOTTOM and g.pos.y + g.size.y / 2 >= BridgePlan.WINDOW_TOP, "по высоте окна")
	ok(g.rotate(Vector3.BACK).z < -0.99, "лицом вперёд")


func test_lab_windows_on_sides() -> void:
	for p in _of(HullPlan.Piece.LAB_WINDOW):
		ok(p.pos.z - p.size.x / 2 > 8 and p.pos.z + p.size.x / 2 < 14, "у лаборатории")
		var s := signf(p.pos.x)
		ok(HullPlan.inside(p.pos - Vector3(s * 0.1, 0, 0)), "лежит на борту")
		ok(not HullPlan.inside(p.pos + Vector3(s * 0.05, 0, 0)), "и смотрит в воду")
		near(p.rotate(Vector3.BACK).x, s, 1e-4, "лицом наружу")


func test_engines_behind_stern() -> void:
	for s in _of(HullPlan.Piece.SHROUD):
		ok(s.pos.z - s.size.y > 24.2, "кожух за кормой трюма")
		var r: HullPlan.Part = _of(HullPlan.Piece.ROTOR).filter(func(q): return signf(q.pos.x) == signf(s.pos.x))[0]
		near(r.pos.z, s.pos.z, 1e-4, "ротор в кожухе")
		ok(r.size.x / 2 < s.size.x * 0.42, "лопасти не задевают кожух")


func test_symmetric() -> void:
	for p in HullPlan.parts():
		if absf(p.pos.x) < 1e-3:
			continue
		var pair := HullPlan.parts().any(func(q): return q.piece == p.piece and absf(q.pos.x + p.pos.x) < 1e-3 and absf(q.pos.y - p.pos.y) < 1e-3 and absf(q.pos.z - p.pos.z) < 1e-3)
		ok(pair, "%s: есть пара на другом борту" % p.name)


func test_inside_world_follows_ship() -> void:
	var ship := Vector3(100, -30, 50)
	ok(HullPlan.inside_world(ship + Vector3(0, 1.6, 10), ship, 0.0), "кормовая часть по курсу 0")
	ok(not HullPlan.inside_world(ship + Vector3(0, 1.6, 20), ship, PI / 2), "повернули влево на 90° — там уже вода")
	ok(HullPlan.inside_world(ship + Vector3(20, 1.6, 0), ship, PI / 2), "а корма теперь на востоке")


func test_palette() -> void:
	eq(HullPlan.COLORS[HullPlan.Paint.METAL], Color("8C806B"), "металл")
	ok(not HullPlan.glows(HullPlan.Paint.METAL) and HullPlan.glows(HullPlan.Paint.WINDOW) and HullPlan.glows(HullPlan.Paint.LENS), "светятся окна и линза")
