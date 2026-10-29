extends TestCase
## Рельеф слоя 1 под карту #818 (#821, часть 2): гребень с террасой врат 07 и наблюдением поля 08, проходы по
## маршрутам `LayerMap` не уже 60 м и не ниже 30 м свободной воды, карманы разворота у 01, 07 и 09.

## Свободная вода прохода по высоте, м: от дна до льда (`Seabed.ICE_Y`), как «плато 30–60 м» на карте.
const LANE_HIGH := 30.0
## Полуширина прохода, м (60 м поперёк).
const LANE_HALF := 30.0
## Радиус кармана разворота, м (≈ 90 м поперёк, карта — 80–100 м).
const POCKET_R := 45.0


## Самое мелкое дно на отрезке a→b в полосе ±half (выборка 4 м вдоль и поперёк): [высота, точка].
func _highest(a: Vector2, b: Vector2, half: float) -> Array:
	var d := b - a
	var n := Vector2(-d.y, d.x).normalized()
	var top := -INF
	var at := Vector2.ZERO
	var t := 0.0
	while t <= d.length():
		var o := -half
		while o <= half:
			var q := a + d.normalized() * t + n * o
			var h := Seabed.height(q.x, q.y)
			if h > top:
				top = h
				at = q
			o += 4.0
		t += 4.0
	return [top, at]


func test_ridge_lifts_terrace_and_field() -> void:
	# Карта: ориентир 35 м на мелком гребне, дно около 45–50 м (было −62 и −67).
	for id: String in ["07", "08"]:
		var p := LayerMap.xz(id)
		var h := Seabed.height(p.x, p.y)
		ok(h <= -44.0 and h >= -52.0, "дно под %s около 45–50 м: %.1f" % [id, h])
		ok(Seabed.base(p.x, p.y) < -55.0, "%s было глубже — гребень поднят" % id)


func test_ship_fits_under_new_points() -> void:
	# Глубина точки — уровень корабля: дно ниже на клиренс корабля с запасом, лёд выше потолка.
	# Шесть ориентиров ART-005 стоят на дне как были, корабль смотрит на них сбоку; здесь — старт, колодец,
	# край отмели и новые места слоя (спуск к лесу — отдельная задача про склон).
	for id: String in ["00", "05", "06", "07", "08", "09"]:
		var p: Dictionary = LayerMap.POINTS[id]
		var h := Seabed.height(p["x"], p["z"])
		var ship := -float(p["depth"])
		ok(h <= ship - Helm.Ship.CLEARANCE - 3.0, "под %s дно %.1f — ниже корабля на %.0f м с запасом" % [id, h, ship])
		ok(ship <= Helm.Ship.CEILING, "%s ниже потолка подо льдом" % id)


func test_lanes_60_wide_30_high() -> void:
	var lanes := 0
	for s: Array in LayerMap.segments():
		if s.has("10"):
			continue
		lanes += 1
		var r := _highest(LayerMap.xz(s[0]), LayerMap.xz(s[1]), LANE_HALF)
		ok(float(r[0]) <= Seabed.ICE_Y - LANE_HIGH,
			"проход %s→%s: дно %.1f у %s — свободно меньше 30 м" % [s[0], s[1], r[0], r[1]])
	eq(lanes, 11, "все проходы слоя, кроме спуска к лесу")


func test_turn_pockets() -> void:
	for id: String in ["01", "07", "09"]:
		var c := LayerMap.xz(id)
		var top := -INF
		for i in range(-45, 46, 3):
			for j in range(-45, 46, 3):
				if Vector2(i, j).length() <= POCKET_R:
					top = maxf(top, Seabed.height(c.x + i, c.y + j))
		ok(top <= Seabed.ICE_Y - LANE_HIGH, "карман у %s: дно не выше %.1f" % [id, top])


func test_plateau_30_to_60() -> void:
	# Плато под 00–05 и 09: дно 30–60 м.
	for id: String in ["00", "01", "02", "03", "04", "05", "09"]:
		var p := LayerMap.xz(id)
		var h := Seabed.height(p.x, p.y)
		ok(h <= -30.0 and h >= -60.0, "плато под %s: %.1f" % [id, h])


func test_far_from_layer_unchanged() -> void:
	# Вне гребня и проходов рельеф — прежний (js/world.js): склон на востоке, края, юг.
	for q: Vector2 in [Vector2(200, 0), Vector2(320, -10), Vector2(60, -200), Vector2(250, 250), Vector2(-300, 250)]:
		eq(Seabed.height(q.x, q.y), minf(Seabed.base(q.x, q.y), Seabed.TOP), "не тронуто в %s" % q)


func test_cuts_only_lower_and_ridge_only_raises() -> void:
	for i in 36:
		for j in 36:
			var x := -350.0 + i * 20.0
			var z := -350.0 + j * 20.0
			var b := Seabed.base(x, z)
			var r := Seabed.Layer.ridge(x, z, b)
			ok(r >= b, "гребень только поднимает (%.0f, %.0f)" % [x, z])
			ok(r <= maxf(b, Seabed.Layer.RIDGE_FLOOR + 3.0), "гребень не выше своего дна (%.0f, %.0f)" % [x, z])
			ok(Seabed.Layer.lanes(x, z, r) <= r, "проход только срезает (%.0f, %.0f)" % [x, z])


func test_relief_smooth() -> void:
	# Без ступенек на краях гребня и проходов: через 1 м склон круче прежнего не больше чем на 1 м. Склон за
	# восточным краем (#822) — свой тест, `test_slope`.
	for i in 140:
		for j in 140:
			var x := -350.0 + i * 5.0
			var z := -350.0 + j * 5.0
			if x > Seabed.Slope.X_IN - 2.0 and Seabed.Slope.mask(x + 2.0, z) + Seabed.Slope.mask(x, z + 2.0) > 0.0:
				continue
			var h := Seabed.height(x, z)
			var b := minf(Seabed.base(x, z), Seabed.TOP)
			for d: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
				var step := absf(Seabed.height(x + d.x, z + d.y) - h)
				var was := absf(minf(Seabed.base(x + d.x, z + d.y), Seabed.TOP) - b)
				ok(step < was + 1.0, "ступенька %.1f м у (%.0f, %.0f)" % [step, x, z])
