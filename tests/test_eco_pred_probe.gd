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


## Проход arrive (встреча у 01, #1400): корабль доходит до 01, стоит там и печатает ближайшего из трёх хищников.
func test_patrol_tool_arrive() -> void:
	var tool: GDScript = load("res://tools/patrol.gd")
	var r: Dictionary = tool.run(false, "arrive", 20261018)
	var text := String(r["text"])
	ok(text.contains("у 01 с "), "корабль дошёл до 01: %s" % text)
	ok(text.contains("№0") and text.contains("№1") and text.contains("№2"), "все три хищника в итоге: %s" % text)
	ok(int(r["by"]) >= 0 and int(r["by"]) < 3, "номер бросившегося")


# ---------- Проба #1498: фаза «замер» перед броском ----------

## Голодный хищник №0 готов напасть, корабль со светом — в 25 м по +X; фаза «замер» — alert с.
func _alerted(alert: float) -> Array:
	var r := _world(false)
	var w: EcoWorld = r[0]
	var ps: EcoPred = r[1]
	ps.alert = alert
	var pr := ps.all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(25, 0, 0)
	w.ship.light_on = true
	return [w, pr]


func _has_note(w: EcoWorld, note: String) -> bool:
	for ev in w.bus.pending:
		if ev.species == EcoPred.ID and ev.note == note:
			return true
	return false


func test_alert_off_charges_at_once() -> void:
	var r := _alerted(0.0)
	(r[0] as EcoWorld).step(EcoWorld.MAX_STEP)
	eq((r[1] as EcoPred.Pred).mode, EcoPred.Mode.CHARGE, "без пробы — бросок сразу, как в игре")


func test_alert_then_charge_if_light_stays() -> void:
	var r := _alerted(2.0)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "сначала замер")
	ok(_has_note(w, "alert"), "строка экипажу «замер и смотрит»")
	var d0 := pr.agent.distance_to(w.ship.pos)
	for i in 30:   # ~1 с
		w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "замер держится до конца фазы")
	ok(d0 - pr.agent.distance_to(w.ship.pos) < 2.5, "в замере почти не подходит")
	for i in 45:
		w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "свет так и горит — бросок")


func test_alert_cancels_when_light_goes_out() -> void:
	var r := _alerted(2.0)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT)
	w.ship.light_on = false   # экипаж погасил свет, корабль стоит — не шумит
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "манящее пропало — отворачивает")
	ok(pr.cooldown >= EcoPred.ALERT_LOSE_CD - 0.1, "пауза перед новым замером")
	ok(_has_note(w, "lost"), "строка «потерял корабль»")
	for i in 150:   # 5 с: свет снова горит, но пауза ещё идёт
		if i == 30:
			w.ship.light_on = true
		w.step(EcoWorld.MAX_STEP)
		ok(pr.mode != EcoPred.Mode.CHARGE, "в паузе не бросается")


## tools/patrol.gd с ответом экипажа и замером (#1498): по сигналу свет гаснет, итог с промежутками и лучом.
func test_patrol_tool_answer() -> void:
	var tool: GDScript = load("res://tools/patrol.gd")
	tool.set("answer", "signal")
	tool.set("alert", 2.5)
	var r: Dictionary = tool.run(false, "late", 20261018)
	tool.set("answer", "")
	tool.set("alert", 0.0)
	ok(r.has("wc") and r.has("cb") and r.has("beam_before"), "итог с промежутками и лучом")
	var text := String(r["text"])
	ok(text.contains("ответов ") or text == "тихо", "по сигналу — ответ экипажа: %s" % text)


## Бросок во время ответа экипажа (корабль стоит без света) — в итоге с тем, что манило (`_watch`, `lure_of`).
func test_patrol_tool_charge_while_hushed() -> void:
	var tool: GDScript = load("res://tools/patrol.gd")
	var ev: EcoView = tool.make(false, 20261018)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(4, -30, 80)
	ev.preds.all[0].mode = EcoPred.Mode.CHARGE
	var charge := {}
	tool._watch(ev, ev.world, ship, [] as Array[Dictionary], 1.0, {}, charge, {}, {})
	ev.free()
	eq(charge.get("n", -1), 0, "бросок замечен")
	eq(String(charge.get("why", "")), "—", "без света и хода манит только след: %s" % charge.get("why", ""))
