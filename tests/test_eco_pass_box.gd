extends TestCase
## Локальный габарит 20×30 прохода 00 → 01 (#1400, `tools/pass_box.gd`): H — максимум грунта под следом корпуса,
## низ/верх/ход от H, плавный ход не ниже H+7 и не круче SLOPE.

const Box := preload("res://tools/pass_box.gd")
const Route := preload("res://tools/route_plan.gd")


func test_numbers_follow_level_decision() -> void:
	near(Box.HALF * 2.0, 20.0, 1e-4, "ширина 20 м")
	near(Box.HEIGHT, 30.0, 1e-4, "высота 30 м")
	near(Route.HULL_BACK - Route.HULL_FRONT, 34.2, 0.01, "след корпуса 34,2 м по HullPlan")
	near(Box.RIDE + Route.HULL_LOW, Box.LOW + 3.4, 0.01, "днище на 3,4 м выше низа (H+5,4)")


func test_foot_covers_nose_and_stern() -> void:
	# Нос впереди по курсу: у станции на севере (−Z) — грунт севернее точки на 7,2 м входит, южнее 27 м — тоже.
	var at := Vector2(20.0, 22.5)
	var dir := Vector2(0.0, -1.0)
	var h := Box.foot_max(at, dir, Box.HALF)
	ok(h >= Seabed.mesh_height(at.x, at.y - 7.0), "под носом")
	ok(h >= Seabed.mesh_height(at.x, at.y + 26.0), "под кормой")
	ok(h >= Seabed.mesh_height(at.x + 9.5, at.y), "у края коридора")
	ok(h >= Box.foot_max(at, dir, Route.HULL_HALF_W), "коридор шире корпуса")


func test_station_levels_from_h() -> void:
	var t := Box.station(30.0)
	near(t["low"], t["h"] + 2.0, 1e-4, "низ H+2")
	near(t["top"], t["h"] + 32.0, 1e-4, "верх H+32")
	near(t["ride"], t["h"] + 7.0, 1e-4, "ход H+7")
	ok(t["h"] >= t["axis_g"], "H не ниже грунта оси")


func test_smooth_is_above_and_gentle() -> void:
	var st: Array[Dictionary] = []
	for i in 20:
		var h := 10.0 if i == 10 else 0.0
		st.append({"s": i * 2.0, "ride": h + Box.RIDE})
	Box.smooth(st)
	for i in st.size():
		ok(st[i]["smooth"] >= st[i]["ride"] - 1e-4, "не ниже H+7 на %d" % i)
		if i > 0:
			ok(absf(st[i]["smooth"] - st[i - 1]["smooth"]) <= Box.SLOPE * 2.0 + 1e-4, "уклон на %d" % i)
	near(st[10]["smooth"], 17.0, 1e-4, "гребень не срезан")
