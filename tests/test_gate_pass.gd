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


## #1757 (уровни и ГД 13.11, фокус 14.11): стоянка кадра `37b-okno-gnezdo` — не только законное место, но и
## достижимое ходом: с гребня в жёлоб, разворот на оси, носом к гнезду — корабль встаёт в точку шага `ship` сценария
## без удара, упора, отката поворота и сдвига вдоль опоры, и задним ходом возвращается на гребень.
func test_stand_37b_reached_by_helm() -> void:
	var ship := {}
	for st: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://tools/qa/scenario.json")):
		if st["do"] == "ship":
			ship = st
		elif st["do"] == "shot" and st["name"] == "37b-okno-gnezdo":
			break
	ok(not ship.is_empty(), "шаг ship перед кадром 37b есть")
	var want := Pass.world(Pass.STAND[0], Pass.STAND[1], Pass.STAND[2])
	near(want.x, float(ship["x"]), 0.01, "стоянка инструмента — место шага сценария, x")
	near(want.y, float(ship["y"]), 0.01, "глубина")
	near(want.z, float(ship["z"]), 0.01, "z")
	near(Pass.STAND[3], float(ship["yaw"]), 0.01, "курс")
	var r := Pass.drive(Pass.RUNS["к стоянке 37b"])
	ok(r["done"], "все точки взяты: подход, стоянка, отход задним ходом")
	eq(r["bumps"], 0, "без ударов о дно")
	near(r["stuck"], 0.0, 0.05, "без упоров")
	eq(r["held"], 0, "поворот нигде не откатился у твёрдого")
	eq(r["slid"], 0, "корпус не скользил вдоль опоры")
	ok(r["min_arch"] > 2.0, "контур корпуса с выступами не ближе 2 м к арке (%.1f)" % r["min_arch"])
	ok(r["min_ground"] > 1.39, "грунт под днищем не ближе зазора (%.2f)" % r["min_ground"])
	eq(r["stands"].size(), 1, "встал на стоянку")
	if r["stands"].size() != 1:
		return
	var st: Dictionary = r["stands"][0]
	var at: Vector3 = st["at"]
	ok(Vector2(at.x - want.x, at.z - want.z).length() < Pass.PARK, "центр — в точке кадра")
	near(-at.y, Pass.STAND[2], Pass.DEPTH_OK, "глубина кадра")
	near(rad_to_deg(st["yaw"]), Pass.STAND[3], 1.5, "курс кадра")
	ok(not GateArch.hits(at, st["yaw"]), "корпус вне арки")
	var nest := GateDiag.nest_pos(EcoDome.NEST)
	var to_nest := Vector2(nest.x - at.x, nest.z - at.z).length()
	ok(to_nest > 26.0 and to_nest < 30.0, "гнездо в окне: 26–30 м от центра (%.1f)" % to_nest)
	ok(GateArch.local(r["end"]).z > 95.0, "задним ходом вышел на гребень")
	# разворот на месте со стоянки круг не замыкает: корма (29 м) упирается в правую опору, курс откатывается (#1847)
	var left := Pass.swing(at, st["yaw"], 1.0)
	var right := Pass.swing(at, st["yaw"], -1.0)
	ok(left > 90.0 and left < 359.0, "влево — до опоры (%.0f°)" % left)
	ok(right > 90.0 and right < 359.0, "вправо — до опоры (%.0f°)" % right)
	near(Pass.swing(Pass.world(0.0, 140.0, 20.0), 0.0, 1.0), 360.0, 0.5, "над гребнем круг свободен")


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


## Промер шага прогона (`Sounding`) — те же числа, что отдельные проходы: предел хода `Helm.Ship.floor_at` и зазор
## `ground_gap`; на склоне жёлоба, у опоры и на гребне, с разным курсом. Прогон берёт предел и зазор из него.
func test_sounding_matches_floor_and_gap() -> void:
	var probe := Pass.Sounding.new()
	var ship := Pass.make_ship()
	for p: Array in [[0.0, 140.0, 30.0, 0.0], [0.0, 60.0, 50.0, 0.4], [23.1, 24.5, 62.0, -1.1], [-150.0, 30.0, 35.0, 2.6]]:
		var pos := Pass.world(p[0], p[1], p[2])
		probe.at(pos, p[3])
		eq(probe.floor_y, ship.floor_at(pos, p[3]), "предел хода в (%.0f; %.0f)" % [p[0], p[1]])
		eq(probe.gap, Pass.ground_gap(pos, p[3]), "зазор грунта в (%.0f; %.0f)" % [p[0], p[1]])
	ok(probe.gap < 100.0, "зазор посчитан")
