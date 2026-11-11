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
## Проходы в тестах короткие (`lim=`, `limit`): проверяют сам инструмент, полный путь — у расчётов для решений.
const LIM := 20.0
## Тихая стоянка перед проходом в тестах (`late=`, `wait_late`): пауза хищников на старте — 20 с, хватает 21 с
## вместо 30 (WAIT_LATE расчётов).
const LATE := 21.0
## Предел прохода arrive: путь от середины до 01 (≈46 м на 5 м/с) — 9,3 с, стоянке у 01 хватает 2,7 с —
## итог «у 01» и ближайшие хищники уже в строке (было 20 с, #1350 11.11).
const LIM_ARRIVE := 12.0
## Предел прохода с ответом экипажа: сигнал «замер» на этом зерне — на 8-й с прохода, запас 4 с (было 20 с, #1350).
const LIM_ANSWER := 12.0


## Короткая стоянка тестов всё ещё дольше паузы хищников после сброса мира: проходы late/arrive — после паузы.
func test_late_outlasts_pred_pause() -> void:
	var tool: GDScript = load("res://tools/patrol.gd")
	var ev: EcoView = tool.make(false, 20261018)
	var pause := 0.0
	for pr in ev.preds.all:
		pause = maxf(pause, pr.cooldown)
	ev.free()
	ok(pause > 0.0, "на старте у хищников пауза")
	ok(LATE > pause, "стоянка тестов %.0f с дольше паузы %.0f с" % [LATE, pause])
	ok(LATE < tool.WAIT_LATE, "и короче стоянки расчётов")
	eq(tool.get("wait_late"), tool.WAIT_LATE, "стоянка прогона настраивается (`late=`), по умолчанию — WAIT_LATE")


func test_patrol_tool_runs() -> void:
	var tool: GDScript = load("res://tools/patrol.gd")
	tool.set("limit", LIM)
	var r: Dictionary = tool.run(true, "base", 20261018)
	tool.set("limit", tool.LIMIT)
	ok(r.has("bite") and r.has("charge") and r.has("warn_before"), "итог прохода полный")
	ok(String(r["text"]) != "", "строка прохода есть")


## Проход arrive (встреча у 01, #1400): корабль доходит до 01, стоит там и печатает ближайшего из трёх хищников.
func test_patrol_tool_arrive() -> void:
	var tool: GDScript = load("res://tools/patrol.gd")
	ok(tool.get("limit") != null and tool.get("wait_late") != null, "предел и стоянка прохода настраиваются")
	tool.set("limit", LIM_ARRIVE)
	tool.set("wait_late", LATE)
	var r: Dictionary = tool.run(false, "arrive", 20261018)
	tool.set("limit", tool.LIMIT)
	tool.set("wait_late", tool.WAIT_LATE)
	var text := String(r["text"])
	ok(bool(r["reached"]) and float(r["to01"]) < LIM_ARRIVE - 1.0, "корабль дошёл до 01 и постоял: %s" % text)
	ok(text.contains("у 01 с ") and not text.contains("у 01 с -1"), "время у 01 в итоге: %s" % text)
	ok(text.contains("№0") and text.contains("№1") and text.contains("№2"), "все три хищника в итоге: %s" % text)
	ok(int(r["by"]) >= 0 and int(r["by"]) < 3, "номер бросившегося")


# ---------- Проба #1498: фаза «замер» перед броском ----------

## Голодный хищник №0 готов напасть, корабль со светом — в 25 м по +X; фаза «замер» — alert с.
func _alerted(alert: float) -> Array:
	var r := _world(false)
	var w: EcoWorld = r[0]
	var ps: EcoPred = r[1]
	ps.alert = alert
	ps.alert_leave = 0.0   # отход — отдельно (alert_leave = 20 ниже)
	var pr := ps.all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(25, 0, 0)
	w.ship.light_on = true
	return [w, pr, ps]


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
	for i in 150:   # 5 с: корабль тёмный — пауза, не бросается
		w.step(EcoWorld.MAX_STEP)
		ok(pr.mode != EcoPred.Mode.CHARGE and pr.mode != EcoPred.Mode.ALERT, "тёмный корабль — не замирает и не бросается")


## Свет снова рядом сразу после «потерял корабль» — новый «замер», а не скрытая неуязвимость паузы (#1498).
func test_alert_relit_close_alerts_again() -> void:
	var r := _alerted(2.0)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	w.step(EcoWorld.MAX_STEP)
	w.ship.light_on = false
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL)
	ok(pr.cooldown > 0.0 and pr.wary > 0.0, "пауза идёт, хищник насторожен")
	w.ship.light_on = true
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "свет снова в чутье — новый замер, пауза не спасает")
	for i in 75:
		w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "свет так и горит — бросок")
	eq(pr.wary, 0.0, "бросок сбрасывает настороженность")


## Строка «замер» — с причиной: что убрать экипажу.
func test_alert_line_names_lure() -> void:
	var r := _alerted(2.0)
	var w: EcoWorld = r[0]
	w.step(EcoWorld.MAX_STEP)
	var text := ""
	for ev in w.bus.pending:
		if ev.species == EcoPred.ID and ev.note == "alert":
			text = ev.text()
	ok(text.ends_with("его манит свет"), text)
	ok(EcoPred.alert_fmt(EcoPred.Lure.NOISE).contains("двигатели"), "шум — двигатели")
	ok(EcoPred.alert_fmt(EcoPred.Lure.PING).contains("сонар"), "импульс — сонар")


## Замер начинается, откуда бы хищник ни подошёл: сбоку и сзади корабля тоже (не конус луча).
func test_alert_from_behind() -> void:
	var r := _alerted(2.0)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	w.ship.pos = pr.agent.p + Vector3(0, 0, -25)   # нос корабля в −Z: хищник за кормой
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "сзади — тоже замер")


## Импульс сонара в «замере» не начинает фазу заново проверкой звука.
func test_ping_keeps_alert() -> void:
	var r := _alerted(2.0)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	var ps: EcoPred = r[2]
	w.step(EcoWorld.MAX_STEP)
	var left := pr.agent.timer
	ps.on_ping(w, w.ship.pos)
	eq(pr.mode, EcoPred.Mode.ALERT, "замер держится")
	near(pr.agent.timer, left, 1e-4, "таймер фазы не сброшен")


## Отход после «потерял корабль» (#1498, `alert_leave`): уходит прочь, а не кружит рядом, и не бросается в отходе.
func test_alert_lost_then_leaves() -> void:
	var r := _alerted(2.0)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	(r[2] as EcoPred).alert_leave = 20.0
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT)
	w.ship.light_on = false
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.RETREAT, "потерял — отходит")
	ok(_has_note(w, "lost"), "строка «потерял корабль»")
	ok(pr.cooldown >= 20.0 + EcoPred.ALERT_LOSE_CD - 0.1, "пауза на весь отход и после")
	var d0 := pr.agent.distance_to(w.ship.pos)
	for i in 300:   # 10 с в темноте — уходит прочь
		w.step(EcoWorld.MAX_STEP)
		ok(pr.mode != EcoPred.Mode.CHARGE and pr.mode != EcoPred.Mode.ALERT, "в отходе не замирает и не бросается")
	var d1 := pr.agent.distance_to(w.ship.pos)
	ok(d1 > d0 + 15.0, "ушёл прочь: %.0f → %.0f м" % [d0, d1])
	ok(d1 > EcoPred.REACH, "за 10 с — дальше чутья на свет")
	w.ship.light_on = true   # свет снова горит, хищник далеко — отход идёт
	for i in 30:
		w.step(EcoWorld.MAX_STEP)
	ok(pr.mode != EcoPred.Mode.ALERT and pr.mode != EcoPred.Mode.CHARGE, "далеко — свет не манит")
	w.ship.pos = pr.agent.p + Vector3(20, 0, 0)   # корабль со светом догнал отходящего
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "свет снова в чутье во время отхода — новый замер")


## tools/patrol.gd с ответом экипажа и замером (#1498): по сигналу свет гаснет, итог с промежутками и лучом.
func test_patrol_tool_answer() -> void:
	var tool: GDScript = load("res://tools/patrol.gd")
	tool.set("answer", "signal")
	tool.set("alert", 2.5)
	tool.set("limit", LIM_ANSWER)
	tool.set("wait_late", LATE)
	var r: Dictionary = tool.run(false, "late", 20261018)
	tool.set("answer", "")
	tool.set("alert", 0.0)
	tool.set("limit", tool.LIMIT)
	tool.set("wait_late", tool.WAIT_LATE)
	ok(r.has("wc") and r.has("cb") and r.has("beam_before"), "итог с промежутками и лучом")
	var text := String(r["text"])
	ok(text.contains("ответов ") or text == "тихо", "по сигналу — ответ экипажа: %s" % text)
	eq(int(r["answers"]), 1, "сигнал за короткий проход есть — ответ один: %s" % text)


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
