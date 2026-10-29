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
