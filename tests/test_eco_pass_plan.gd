extends TestCase
## План и сечение прохода 00 → 01 (#1400, `tools/pass_plan.gd`): ось по точкам `scena=`, сторона и отступ от оси,
## высокая флора и что входит в свободный объём.

const Plan := preload("res://tools/pass_plan.gd")
const Setup := preload("res://tools/shot_setup.gd")


func test_path_follows_scena_points() -> void:
	eq(Plan.PATH.size(), 3, "три точки")
	for i in Plan.PATH.size():
		eq(Plan.PATH[i], Setup.SCENA[i], "точка %d — как scena=%d" % [i, i + 1])


func test_side_sign_follows_ship_axes() -> void:
	# Первый отрезок идёт от 00 на север (−Z) и чуть на восток: справа по ходу — восток (+X).
	var mid: Vector2 = (Plan.PATH[0] + Plan.PATH[1]) * 0.5
	var east := Plan.project(mid + Vector2(10.0, 0.0))
	var west := Plan.project(mid + Vector2(-10.0, 0.0))
	ok(east["side"] > 9.0, "восток — справа")
	ok(west["side"] < -9.0, "запад — слева")
	ok(not east["edge"], "внутри пути")
	near(east["s"] + west["s"], Plan.PATH[0].distance_to(Plan.PATH[1]), 0.5, "середина первого отрезка")


func test_beyond_ends_is_edge() -> void:
	ok(Plan.project(Plan.PATH[0] + Vector2(0.0, 20.0))["edge"], "за 00 — не в проходе")
	ok(Plan.project(Plan.PATH[2] + Vector2(0.0, -20.0))["edge"], "за концом у 01 — не в проходе")


func test_along_hits_points() -> void:
	for i in Plan.PATH.size():
		var a: Vector2 = Plan.along(Plan.arc_at(i))["at"]
		near(a.distance_to(Plan.PATH[i]), 0.0, 0.01, "s точки %d" % i)


func test_low_cover_is_not_tall() -> void:
	var out: Array[Dictionary] = []
	var p := Vector3(10.0, Seabed.mesh_height(10.0, 50.0), 50.0)
	Plan.add(out, "мох", p, p.y + Plan.TALL * 0.5, 0.0)
	eq(out.size(), 0, "низкий покров не считается")
	Plan.add(out, "ленточник", p, p.y + 5.0, 0.0)
	eq(out.size(), 1, "высокая — в списке")


func test_station_profile_spans_both_sides() -> void:
	var st := Plan.station(10.0)
	var prof: Array = st["profile"]
	near(prof[0][0], -Plan.REPORT, 0.01, "слева до края")
	near(prof[-1][0], Plan.REPORT, 0.01, "справа до края")
	near(st["axis_g"], Seabed.mesh_height(st["x"], st["z"]), 1e-4, "грунт оси — видимое дно")
