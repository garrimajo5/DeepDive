extends TestCase
## Склон до 300 м за восточным краем отмели (#822, часть 1, `Seabed.Slope`): проход в стене не уже 60 м, дно без щели
## и ступенек, внизу — не мельче 293 м (место 10, ориентир 290 м, корабль на `Helm.Ship.CLEARANCE` над дном), по оси
## прохода от Края отмели 06 корабль спускается без касаний.

const S := Seabed.Slope


func test_passage_60_wide_in_wall() -> void:
	# В стене (x 285…350, там дно прежней отмели поднимается к ~35 м) полоса ±30 м у оси — глубже 100 м.
	var x := 285.0
	while x <= 350.0:
		var z := S.GAP_Z - 30.0
		while z <= S.GAP_Z + 30.0:
			ok(Seabed.height(x, z) < -100.0, "проход у (%.0f, %.0f): %.0f м" % [x, z, Seabed.height(x, z)])
			z += 5.0
		x += 5.0
	# А в стороне от прохода стена стоит, как была.
	for q: Vector2 in [Vector2(330, S.GAP_Z - 160.0), Vector2(330, S.GAP_Z + 140.0)]:
		eq(Seabed.height(q.x, q.y), minf(Seabed.base(q.x, q.y), Seabed.TOP), "стена в %s" % q)


func test_bottom_at_least_293() -> void:
	# Внизу склона, у оси: дно не мельче 293 м — корабль встанет на 290 м с запасом `CLEARANCE`.
	var x := S.X_BOTTOM - 30.0
	while x <= S.X_BOTTOM + 30.0:
		var z := S.GAP_Z - 20.0
		while z <= S.GAP_Z + 20.0:
			ok(Seabed.height(x, z) <= -290.0 - Helm.Ship.CLEARANCE, "дно внизу (%.0f, %.0f): %.0f м" % [x, z,
					Seabed.height(x, z)])
			z += 10.0
		x += 10.0


func test_axis_descends_without_touching() -> void:
	# От Края отмели 06 к проходу и по оси вниз: корабль, что держится на 3 м над дном, нигде не поднимается больше
	# чем на 2 м за 10 м пути (не упирается в скалу), а всего уходит вниз до 300 м.
	var path: Array[Vector2] = [LayerMap.xz("06"), Vector2(S.X_IN, S.GAP_Z), Vector2(S.X_BOTTOM, S.GAP_Z)]
	var prev := INF
	var lowest := INF
	for k in path.size() - 1:
		var a := path[k]
		var b := path[k + 1]
		var n := int(a.distance_to(b) / 10.0)
		for i in n + 1:
			var q := a.lerp(b, float(i) / n)
			var h := Seabed.height(q.x, q.y)
			if prev < INF and q.x > S.X_IN:
				ok(h - prev < 2.0, "подъём %.1f м у %s" % [h - prev, q])
			prev = h
			lowest = minf(lowest, h)
	ok(lowest < -300.0, "склон уходит до 300 м: %.0f" % lowest)


func test_no_gap_or_step() -> void:
	# Дно на стыке со старой отмелью и по краям котловины — без щели и ступеньки: через 1 м не круче 11 м (стена
	# 300 м на 40 м края — крутой скальный бок, но без вертикали), высота везде конечна и не выше `TOP`.
	var x := S.X_IN - 10.0
	while x < S.X_END + 10.0:
		var z := S.GAP_Z - S.BASIN_HALF - S.FADE - 10.0
		while z < S.GAP_Z + S.BASIN_HALF + S.FADE + 10.0:
			var h := Seabed.height(x, z)
			ok(is_finite(h) and h <= Seabed.TOP, "дно в (%.0f, %.0f)" % [x, z])
			for d: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
				var step := absf(Seabed.height(x + d.x, z + d.y) - h)
				ok(step < 11.0, "ступенька %.1f м у (%.0f, %.0f)" % [step, x, z])
			z += 3.0
		x += 3.0


func test_only_lowers_and_old_map_west_untouched() -> void:
	for i in 30:
		for j in 30:
			var x := 200.0 + i * 17.0
			var z := -150.0 + j * 17.0
			ok(S.cut(x, z, -50.0) <= -50.0, "склон только опускает (%.0f, %.0f)" % [x, z])
	# Западнее начала склона — ровно прежнее дно слоя.
	for q: Vector2 in [LayerMap.xz("06"), Vector2(S.X_IN, S.GAP_Z), Vector2(240, 300)]:
		eq(S.cut(q.x, q.y, -77.0), -77.0, "не тронуто в %s" % q)


func test_east_mesh_seams_with_map() -> void:
	# #822, часть 2: участок сетки за краем — в той же поверхности, узлы на x = 350 совпадают с краем карты по высоте и
	# нормали (стык без щели и без шва света), а `mesh_height` за краем идёт по его клеткам.
	var arr := Seabed.map_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var main_n := (Seabed.SEGMENTS + 1) * (Seabed.SEGMENTS + 1)
	ok(vs.size() > main_n, "участок за краем добавлен")
	eq((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() % 3, 0, "треугольники целые")
	var edge := {}
	for v in main_n:
		if is_equal_approx(vs[v].x, Seabed.SIZE / 2.0):
			edge[roundi(vs[v].z)] = v
	var shared := 0
	for v in range(main_n, vs.size()):
		if is_equal_approx(vs[v].x, Seabed.EAST.position.x) and edge.has(roundi(vs[v].z)):
			var m: int = edge[roundi(vs[v].z)]
			near(vs[v].y, vs[m].y, 0.001, "высота на стыке z = %.0f" % vs[v].z)
			ok(ns[v].distance_to(ns[m]) < 0.001, "нормаль на стыке z = %.0f" % vs[v].z)
			shared += 1
	eq(shared, int(Seabed.EAST.size.y / (Seabed.SIZE / Seabed.SEGMENTS)) + 1, "весь край участка на узлах карты")
	for q: Vector2 in [Vector2(400, 200), Vector2(560, 210), Vector2(620, 150)]:
		near(Seabed.mesh_height(q.x, q.y), Seabed.height(q.x, q.y), 4.0, "сетка за краем в %s" % q)
	near(Seabed.mesh_height(560, 200), Seabed.height(560, 200), 4.0, "низ склона")
	ok(Seabed.mesh_height(560, 200) < -290.0, "сетка видит дно склона: %.0f" % Seabed.mesh_height(560, 200))


func _ship_at(p: Vector3, yaw: float) -> Helm.Ship:
	var s := Helm.Ship.new()
	s.ground = Seabed.height
	s.pos = p
	s.yaw = yaw
	return s


func test_ship_goes_down_to_10() -> void:
	# От Края отмели на восток по оси прохода и вниз: корабль проходит стену, спускается к 300 м (место 10 — 290 м) и
	# по дороге не бьётся о скалы (подъём дна под ним за шаг — меньше метра).
	var s := _ship_at(Vector3(LayerMap.xz("06").x, -100.0, S.GAP_Z), -PI / 2.0)
	s.in_thrust = 1.0
	s.in_vert = -1.0
	var worst := 0.0
	for i in 2400:
		s.update(0.05)
		worst = maxf(worst, s.bump)
	ok(s.pos.x > S.X_BOTTOM - 40.0, "дошёл до низа склона: x = %.0f" % s.pos.x)
	ok(s.pos.x <= Helm.Ship.EAST_END, "не дальше восточной стены")
	ok(s.depth() > 290.0, "глубина у 10: %.0f м" % s.depth())
	ok(worst < 1.0, "без ударов о скалы: %.2f м" % worst)


func test_wall_beside_passage_holds() -> void:
	# В стороне от прохода край отмели стоит, как был: на x = 300 дальше не пускает.
	for z: float in [0.0, -200.0, S.GAP_Z - 150.0, S.GAP_Z + 110.0]:
		var s := _ship_at(Vector3(290.0, -60.0, z), -PI / 2.0)
		s.in_thrust = 1.0
		for i in 400:
			s.update(0.05)
		ok(s.pos.x <= Helm.Ship.EDGE + 0.001, "стена у z = %.0f: x = %.1f" % [z, s.pos.x])


func test_save_keeps_ship_on_slope() -> void:
	var d := SaveGame.ship_read({"x": 560.0, "y": -295.0, "z": 200.0, "yaw": 0.0, "hull": 80.0, "energy": 50.0})
	eq(d["pos"], Vector3(560.0, -295.0, 200.0), "место на склоне читается как есть")
	var w := SaveGame.ship_read({"x": 560.0, "y": -40.0, "z": 0.0, "yaw": 0.0, "hull": 80.0, "energy": 50.0})
	eq(w["pos"].x, Helm.Ship.EDGE, "в стене за краем — на край отмели")
