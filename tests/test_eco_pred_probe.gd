extends TestCase
## Проба расстановки серпохвостов сцены 00 → 01 (#1400, `EcoPred.probe`): дуга хищника №1 за внешней стороной 01,
## цели патруля вне тихого круга у спокойной остановки. Выключено — расстановка как была.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world(probe: bool) -> Array:
	var w := EcoWorld.new()
	w.ground = _flat
	var ps := EcoPred.new()
	ps.probe = probe
	w.add(ps)
	w.ship.pos = Vector3(-300, -30, 300)   # корабль далеко — не манит
	return [w, ps]


func test_off_keeps_starts() -> void:
	var ps: EcoPred = _world(false)[1]
	for i in EcoPred.STARTS.size():
		var p := ps.all[i].agent.p
		near(p.x, EcoPred.STARTS[i].x, 1e-4, "№%d на старом месте по x" % i)
		near(p.z, EcoPred.STARTS[i].y, 1e-4, "№%d на старом месте по z" % i)


func test_probe_spawns_arc_pred_at_arc() -> void:
	var ps: EcoPred = _world(true)[1]
	var p := ps.all[EcoPred.ARC_PRED].agent.p
	near(p.x, EcoPred.ARC[0].x, 1e-4, "появился в начале дуги")
	near(p.z, EcoPred.ARC[0].y, 1e-4, "появился в начале дуги")
	near(ps.all[0].agent.p.x, EcoPred.STARTS[0].x, 1e-4, "остальные — на своих местах")


func test_arc_goes_there_and_back() -> void:
	var pr := EcoPred.Pred.new()
	var got: Array[Vector2] = []
	for i in 6:
		got.append(EcoPred.arc_next(pr))
	var a := EcoPred.ARC
	eq(got, [a[1], a[2], a[1], a[0], a[1], a[2]] as Array[Vector2], "туда и обратно по тем же отрезкам")


## Без светляков патруль №1 — у точек дуги, остальные — вне тихого круга.
func test_probe_patrol_goals() -> void:
	var r := _world(true)
	var w: EcoWorld = r[0]
	var ps: EcoPred = r[1]
	var q := Vector3(EcoPred.QUIET.x, 0.0, EcoPred.QUIET.y)
	var arc_goals := 0
	for i in 3000:
		w.step(0.1)
		for pr in ps.all:
			if pr.mode != EcoPred.Mode.PATROL:
				continue
			var g := pr.agent.goal
			ok(EcoPred._flat_dist(g, q) >= EcoPred.QUIET_R - 1e-3,
				"цель №%d вне тихого круга: %.1f м" % [pr.index, EcoPred._flat_dist(g, q)])
			if pr.index == EcoPred.ARC_PRED:
				var best := INF
				for p2 in EcoPred.ARC:
					best = minf(best, Vector2(g.x, g.z).distance_to(p2))
				ok(best <= EcoPred.ARC_JITTER * sqrt(2.0) + 1e-3, "цель №1 у точки дуги: %.1f м" % best)
				arc_goals += 1
		if arc_goals > 200:
			break
	ok(arc_goals > 0, "№1 ходил по дуге")


## Отчёт сравнения tools/patrol.gd собирается и считает проход (по нему решают, включать ли пробу).
func test_patrol_tool_runs() -> void:
	var tool: GDScript = load("res://tools/patrol.gd")
	var r: Dictionary = tool.run(true, "base", 20261018)
	ok(r.has("bite") and r.has("charge") and r.has("warn_before"), "итог прохода полный")
	ok(String(r["text"]) != "", "строка прохода есть")
