extends TestCase
## След полного корпуса у арки врат 07 (#1757, шаг 3в, `tools/gate_pass.gd`): корабль своим шагом проходит арку
## низом и обратно задним ходом, уходит к 08 и возвращается — без ударов о дно, упоров и касаний арки контуром
## корпуса с выступами. И корма: `GateArch.hits` считает корпус по всей длине, не только ±18,5 м от центра.

const Pass := preload("res://tools/gate_pass.gd")


func _c(dx: float, y: float, dz: float) -> Vector3:
	return Vector3(EcoGate.CENTER.x + dx, y, EcoGate.CENTER.y + dz)


## Без исправления падает: корабль в проходе поперёк, конец кормы (27 м от центра) — в теле правой опоры, а прежние
## точки (центр и ±13 м с запасом 5,5) кончались на 18,5 м.
func test_stern_hits_pillar() -> void:
	var y := GateArch.floor_y() + 12.0   # высота опоры (4…22 м от пола)
	var yaw := PI / 2.0   # нос к −X, корма к +X
	var pos := _c(10.0, y, 0.0)   # корма до dx 39: в опоре x 35…58; прежний счёт доставал до dx 28,5
	ok(GateArch.inside(pos + Vector3(27.0, 0.0, 0.0)), "точка кормы в опоре")
	ok(GateArch.hits(pos, yaw), "корма в опоре — корпус задевает арку")
	ok(not GateArch.hits(_c(0.0, y, 0.0), 0.0), "по оси прохода корпус свободен")
	ok(not GateArch.hits(_c(0.0, y, 40.0), PI / 2.0), "поперёк в 40 м перед аркой — свободен")
	# нос короче кормы: носом к опоре корабль подходит ближе, чем кормой
	ok(not GateArch.hits(_c(14.0, y, 0.0), -PI / 2.0), "нос (9 м) до опоры не достаёт")
	ok(GateArch.hits(_c(30.0, y, 0.0), -PI / 2.0), "нос в опоре")


func test_points_cover_hull_length() -> void:
	near(GateArch.SHIP_PTS[0] - GateArch.SHIP_R, Pass.HULL_FRONT, 0.01, "первая точка — до носа с выступами")
	near(GateArch.SHIP_PTS[-1] + GateArch.SHIP_R, HullPlan.STERN_END, 0.01, "последняя — до кормы")
	for i in range(1, GateArch.SHIP_PTS.size()):
		ok(GateArch.SHIP_PTS[i] - GateArch.SHIP_PTS[i - 1] < GateArch.SHIP_R * 1.5, "без щели между точками")


func test_low_pass_and_back() -> void:
	var r := Pass.drive(Pass.RUNS["низом"])
	_clean(r, "низом")
	var deep := INF
	var north := INF
	for s: Dictionary in r["samples"]:
		var q := GateArch.local(s["at"])
		north = minf(north, q.z)
		# корпус под аркой (от носа у южного лица до кормы у северного) — на проектном сечении
		if q.z > -GateArch.HALF_DEPTH - Pass.HULL_BACK and q.z < GateArch.HALF_DEPTH - Pass.HULL_FRONT:
			deep = minf(deep, -s["at"].y)
	near(deep, Pass.PASS_DEPTH, 0.7, "под аркой центр на 58 м")
	ok(north < -40.0, "прошёл насквозь: dz %.1f" % north)
	ok(r["min_arch"] > 15.0, "до опор на высоте корпуса %.1f м" % r["min_arch"])
	var end := GateArch.local(r["end"])
	ok(end.z > 95.0, "задним ходом вышел на гребень: dz %.1f" % end.z)


func test_turn_to_field_and_back() -> void:
	var out := Pass.drive(Pass.RUNS["07 → 08"])
	_clean(out, "07 → 08")
	ok(Vector2(out["end"].x, out["end"].z).distance_to(LayerMap.xz("08")) < Pass.ARRIVE + 5.5, "дошёл до 08")
	var back := Pass.drive(Pass.RUNS["08 → 07"])
	_clean(back, "08 → 07")
	ok(GateArch.local(back["end"]).z < -40.0, "от 08 прошёл арку насквозь")


func test_outline_and_gaps() -> void:
	var pts := Pass.outline(Vector3.ZERO, 0.0)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	near(lo.y, Pass.HULL_FRONT, 0.01, "нос впереди — к −Z")
	near(hi.y, Pass.HULL_BACK, 0.21, "корма")
	near(hi.x - lo.x, HullPlan.NOSE_W, 0.01, "ширина")
	var y := GateArch.floor_y() + 12.0
	ok(Pass.arch_gap(_c(22.0, y, 0.0), PI / 2.0) < 0.0, "корма в опоре — зазор отрицательный")
	near(Pass.arch_gap(_c(0.0, y, 0.0), 0.0), GateArch.PASS_HALF - Pass.HULL_HALF_W + 3.0, 0.6, "по оси — до опор ≈ 20 м")
	ok(Pass.arch_gap(_c(0.0, y, 300.0), 0.0) == INF, "далеко от арки — без счёта")
	near(Pass.ground_gap(_c(0.0, -58.0, 0.0), 0.0), 66.0 - 58.0 - 1.6, 0.6, "грунт под днищем на 58 м в жёлобе")


func _clean(r: Dictionary, what: String) -> void:
	ok(r["done"], "«%s»: все точки взяты" % what)
	eq(r["bumps"], 0, "«%s»: без ударов о дно" % what)
	near(r["stuck"], 0.0, 0.05, "«%s»: без упоров" % what)
	ok(r["min_arch"] > 3.0, "«%s»: контур корпуса не ближе 3 м к арке (%.1f)" % [what, r["min_arch"]])
	ok(r["min_ground"] > 1.39, "«%s»: грунт под днищем не ближе зазора (%.2f)" % [what, r["min_ground"]])
