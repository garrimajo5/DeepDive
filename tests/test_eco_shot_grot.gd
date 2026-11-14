extends TestCase
## Ключи `tools/shot.gd grot=`/`grot_t=`/`grot_cam=` (#1400, кадры дрейфа гротовика): круг, путь гротовика и поза корабля.

const ShotSetup := preload("res://tools/shot_setup.gd")


func after() -> void:
	EcoGrot.route = EcoGrot.ROUTE


func test_route_parses_and_falls_back() -> void:
	var r := ShotSetup.grot_route("43,75;55,65;55,49;43,39")
	eq(r.size(), 4, "четыре точки")
	eq(r[2], Vector2(55, 49), "третья точка")
	eq(ShotSetup.grot_route("1,2"), EcoGrot.ROUTE, "одна точка — не круг, прежний")


## Поза: корабль в dist от тела с нужной стороны курса, нос к телу, не в грунте и выше тела.
func test_pose_sides_and_nose() -> void:
	var gr := EcoGrot.Walker.new()
	gr.p = Vector3(40, -40, 50)
	gr.body_y = -39.0
	for yaw in [0.0, 1.1, -2.4]:
		gr.yaw = yaw
		var f := Vector2(sin(yaw), cos(yaw))
		var right := -Vector2(cos(yaw), -sin(yaw))
		for kind in ["bok", "nos", "korma"]:
			var pose := ShotSetup.grot_pose(gr, kind, 18.0)
			var s: Vector3 = pose["ship"]
			var d := Vector2(s.x - gr.p.x, s.z - gr.p.z)
			near(d.length(), 18.0, 1e-3, "%s — в 18 м" % kind)
			var want: Vector2 = {"bok": right, "nos": f, "korma": -f}[kind]
			if kind == "bok":   # с той стороны, откуда спину видно ниже
				near(absf(d.normalized().dot(want)), 1.0, 1e-3, "bok — сбоку")
				var other := ShotSetup._grot_spot(gr, Vector2(gr.p.x, gr.p.z) - d)
				ok(pose["down"] <= other["down"] + 1e-4, "bok — сторона с меньшим углом")
			else:
				near(d.normalized().dot(want), 1.0, 1e-3, "%s — с той стороны курса" % kind)
			var nose := Vector2(-sin(pose["yaw"]), -cos(pose["yaw"]))
			near(nose.dot(-d.normalized()), 1.0, 1e-3, "%s — нос к телу" % kind)
			ok(s.y >= Seabed.mesh_height(s.x, s.z) + ShotSetup.GROT_FLOOR - 1e-3, "не в грунте")
			near(pose["down"], atan2(s.y - gr.body_y - EcoGrot.BACK_UP, 18.0), 1e-4, "%s — угол на спину" % kind)
			ok(s.y >= gr.body_y + ShotSetup.GROT_UP - 1e-3, "выше тела")
			var back := gr.body_y + EcoGrot.BACK_UP
			for i in range(1, ShotSetup.GROT_RAYS):
				var q := Vector3(gr.p.x, back, gr.p.z).lerp(s, float(i) / ShotSetup.GROT_RAYS)
				ok(q.y >= Seabed.mesh_height(q.x, q.z) + ShotSetup.GROT_CLEAR - 1e-3, "%s — гребень не закрывает спину" % kind)
	var mid := ShotSetup.grot_pose(gr, "mid", 18.0)
	eq(Vector2(mid["ship"].x, mid["ship"].z), ShotSetup.SCENA[1], "mid — стоянка середины сцены")


## grot_walk: гротовик заново с первой точки и идёт по кругу пробы, как в `tools/mid_calm.gd` (тот же шаг) —
## через 84 с на отрезке (55; 49) → (43; 39) у предела наклона; стая рифа — на спине.
func test_walk_reaches_slope_leg() -> void:
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	ev.world.reset(20261018)
	EcoGrot.route = ShotSetup.grot_route("43,75;55,65;55,49;43,39")
	var host := _Host.new()
	host.eco = ev
	ShotSetup.grot_walk(host, 84.0)
	var gr := ev.grot.grot
	eq(gr.wp, 3, "идёт к (43; 39)")
	ok(Vector2(gr.p.x, gr.p.z).distance_to(Vector2(51, 46)) < 3.0, "на отрезке у (51; 46): %s" % str(gr.p))
	ok(maxf(absf(gr.tilt.x), absf(gr.tilt.y)) > EcoGrot.TILT_MAX - 0.02, "у предела наклона")
	var sh := ev.grot.shoal
	if sh:
		for f: EcoFish.Fish in sh.members:
			ok(f.agent.p.distance_to(sh.home) < EcoGrot.RANGE + 2.0, "светляк на спине")
	ev.free()


class _Host:
	extends RefCounted
	var eco: EcoView
