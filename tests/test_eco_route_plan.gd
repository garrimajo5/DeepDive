extends TestCase
## Основной маршрут слоя 1 с габаритом корпуса (#1374, `tools/route_plan.gd`): стена за краем отмели, корпус в
## грунте, высокая флора у самого места — отдельно.

const Plan := preload("res://tools/route_plan.gd")


func test_hull_matches_hull_plan() -> void:
	near(Plan.HULL_BACK - Plan.HULL_FRONT, 34.2, 0.05, "длина корпуса от носового среза до кормы")
	near(Plan.HULL_HALF_W * 2.0, HullPlan.NOSE_W, 1e-4, "ширина — носовая оболочка")
	ok(Plan.HULL_LOW < 0.0 and Plan.HULL_TOP > 0.0, "днище ниже точки хода, верх выше")


func test_straight_06_10_hits_wall_and_gap_does_not() -> void:
	var flora: Array[Dictionary] = []
	var straight := Plan.leg_report("06", LayerMap.xz("06"), "10", LayerMap.xz("10"), flora)
	var walls := 0
	for st in straight["stations"]:
		walls += 1 if st["wall"] else 0
	ok(walls > 0, "прямая 06 → 10 упирается в стену за краем отмели")
	var gap := Vector2(Seabed.Slope.X_IN, Seabed.Slope.GAP_Z)
	for leg in [Plan.leg_report("06", LayerMap.xz("06"), "проход", gap, flora),
			Plan.leg_report("проход", gap, "10", LayerMap.xz("10"), flora)]:
		for st in leg["stations"]:
			ok(not st["wall"], "через проход склона стены нет (%s → %s, %.0f м)" % [leg["from"], leg["to"], st["s"]])


func test_station_needs_lift_on_slope() -> void:
	# На склоне за проходом корабль без наклона: корма над более высоким грунтом — нужен ход выше нижнего предела.
	var st := Plan.station(Vector2(450.0, 200.0), Vector2(1.0, 0.0), 0.0)
	ok(not st["wall"], "в проходе")
	ok(st["foot"] > st["gc"] + 5.0, "под кормой грунт выше, чем под центром")
	ok(st["dig"] > 0.0, "на нижнем пределе корпус в грунте")
	near(st["need"], st["foot"] - Plan.HULL_LOW - st["gc"], 1e-4, "нужный ход — днище над самым высоким грунтом")


func test_flora_at_place_is_marked() -> void:
	var a := Vector2(0.0, 100.0)
	var b := Vector2(0.0, 0.0)
	var flora: Array[Dictionary] = []
	for z in [5.0, 50.0]:
		var gy := Seabed.mesh_height(3.0, z)
		flora.append({"kind": "ленточник", "x": 3.0, "z": z, "ground": gy, "top": gy + 20.0, "reach": 0.0})
	var leg := Plan.leg_report("а", a, "б", b, flora)
	eq(leg["flora"].size(), 2, "обе в объёме")
	var by_z := {}
	for f in leg["flora"]:
		by_z[int(f["z"])] = f
	ok(by_z[5]["end"], "у самого места б")
	ok(not by_z[50]["end"], "середина отрезка — не у места")
	ok(by_z[50]["hull"], "3 м от оси — в полосе корпуса")
