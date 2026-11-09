extends SceneTree
## Сравнение расстановки серпохвостов на сцене 00 → 01 (#1400): как есть и проба `EcoPred.probe` (тихий круг у
## спокойной остановки + дуга хищника №1 за внешней стороной 01). Мир целиком (`EcoView`, дно `Seabed.mesh_height`),
## headless, без узлов сцены. Облачный расчёт, не телефонный.
##   godot --headless --path . -s tools/patrol.gd [-- seeds=8 csv=<файл> move=4,1 stop=23,13 only=now probe=1 res=0]
## res=0 — без расчёта «корабль далеко».
## move — дома стай рифа с этими номерами переносятся к рифам `tools/quiet_map.gd` (`EcoFish.home_at`), stop — другая
## точка стоянки на пути вместо середины, only=now — без пробы `EcoPred.probe`, probe=1 — только с ней.
## Печатает по каждому проходу: первый сигнал экипажу (строка мира о хищнике или реакции на него) → бросок → укус, с
## координатами; доли времени хищников в тихом круге и в окне угрозы перед рифом; входы в круг по режимам.
## Проходы: base — сразу после сброса мира (у всех 20 с паузы), late — после 30 с тихой стоянки у 00 (пауза кончилась),
## ping — late + импульс сонара на стоянке, retreat — late, но по первому сигналу свет гаснет и корабль уходит к 00,
## stop — спокойное наблюдение без выхода из 00: 30 с без света на самой стоянке, затем свет, стоянка и путь к 01
## arrive — встреча у 01 (#1400): 30 с без света на стоянке, затем свет и без остановки к 01, там 40 с стоянки
## со светом; печатает, кто из трёх хищников подошёл ближе всех и когда (`modes=` — какие проходы считать).
## Ответ экипажа (#1498) — `answer=signal|charge|alert` (`answer_now`): свет гаснет, корабль встаёт без хода (не
## шумит) через `delay=` с после повода, через ANSWER_HOLD с свет снова горит и путь идёт дальше; `alert=<с>` — проба фазы «замер» `EcoPred.alert`.
## По каждому проходу ещё — когда хищник впервые в луче (ближе дальности света и в конусе `Searchlight.HALF_ANGLE`)
## и сколько секунд от сигнала до броска и от броска до укуса.

const SHIP_SPEED := 5.0
const STOP := 25.0
const DT := 1.0 / 30.0
const WAIT_LATE := 30.0
## Стоянка у 01 в проходе arrive.
const HOLD_01 := 40.0
## Путь: выход из 00 → середина (стоянка) → подход к 01 (точки `scena=`, tools/shot_setup.gd).
const PATH: Array[Vector2] = [Vector2(4.0, 80.0), Vector2(20.0, 22.5), Vector2(33.0, -22.0)]
const FLOOR := 7.0
## Путь этого прогона (PATH, стоянка — `stop=`) и переносы домов стай (`move=`).
static var path: Array[Vector2] = PATH.duplicate()
static var move := {}
## Окно угрозы перед рифом: z между серединой и кольцом рифа (#1400, расчёт 08.11).
const WIN_Z := Vector2(-20.0, 10.0)
## Слова строки мира, что про хищника (вид «pred» или реакции на него).
const THREAT_NOTES := ["ship", "ping", "hear", "bite", "fade", "alarm", "pred", "flee", "reef", "alert"]
## Сколько стоит корабль без света и хода после ответа экипажа (answer=).
const ANSWER_HOLD := 25.0
## Ответ экипажа этого прогона ("" — нет) и фаза «замер» хищника, с (0 — как в игре).
static var answer := ""
## Через сколько секунд после повода экипаж гасит свет (реакция людей, `delay=`).
static var delay := 0.0
static var alert := 0.0


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var seeds := int(kv.get("seeds", "8"))
	answer = kv.get("answer", "")
	delay = float(kv.get("delay", "0"))
	alert = float(kv.get("alert", "0"))
	if kv.has("stop"):
		var xz: PackedStringArray = kv["stop"].split(",")
		path[1] = Vector2(float(xz[0]), float(xz[1]))
	if kv.has("move"):
		var reefs: Dictionary = QuietMap.REEF_FOR
		for k in kv["move"].split(","):
			move[int(k)] = reefs[int(k)]
	var modes: PackedStringArray = kv.get("modes", "base,late,ping,retreat,stop").split(",")
	var probes := [false] if kv.get("only", "") == "now" else [false, true]
	if kv.has("probe"):
		probes = [kv["probe"] == "1"]
	var lines: Array[String] = []
	if not move.is_empty() or kv.has("stop") or answer != "" or alert > 0.0:
		lines.append("== переносы %s, стоянка %s, ответ «%s» через %.1f с, замер %.1f с" % [str(move), str(path[1]), answer, delay, alert])
		print(lines[0])
	for probe in probes:
		for mode in modes:
			var bites := 0
			var charges := 0
			var warned := 0
			var by := [0, 0, 0]
			var at01 := [0, 0, 0]
			var beam_first := 0
			var reached := 0
			var answers := 0
			var gaps_wc: Array[float] = []
			var gaps_cb: Array[float] = []
			for s in seeds:
				var r := run(probe, mode, 20261018 + s * 7919)
				bites += 1 if r["bite"] else 0
				charges += 1 if r["charge"] else 0
				warned += 1 if r["warn_before"] else 0
				if r["charge"]:
					by[r["by"]] += 1
				at01[0] += 1 if r["seen01"] else 0
				at01[1] += 1 if r["warn01"] else 0
				at01[2] += 1 if r["charge01"] else 0
				beam_first += 1 if r["beam_before"] else 0
				reached += 1 if r["reached"] else 0
				answers += int(r["answers"])
				if r["wc"] >= 0.0:
					gaps_wc.append(r["wc"])
				if r["cb"] >= 0.0:
					gaps_cb.append(r["cb"])
				var line := "%s %-7s зерно %d: %s" % ["проба" if probe else "сейчас", mode, s, r["text"]]
				print(line)
				lines.append(line)
			var sum := "== %s %s: бросок %d/%d (№0 %d, №1 %d, №2 %d), укус %d/%d, сигнал до броска %d/%d" % [
				"проба" if probe else "сейчас", mode, charges, seeds, by[0], by[1], by[2], bites, seeds, warned, seeds]
			sum += "; в луче до броска %d/%d; сигнал→бросок %s; бросок→укус %s; дошёл до 01 %d/%d, ответов %d" % [
				beam_first, seeds, span(gaps_wc), span(gaps_cb), reached, seeds, answers]
			if mode == "arrive":
				sum += "; на стоянке у 01: хищник ближе %.0f м %d/%d, сигнал %d/%d, бросок %d/%d" % [
					EcoPred.REACH, at01[0], seeds, at01[1], seeds, at01[2], seeds]
			print(sum)
			lines.append(sum)
	for probe in probes if kv.get("res", "1") != "0" else []:
		var res := residency(probe, seeds)
		print(res)
		lines.append(res)
	if kv.has("csv"):
		var f := FileAccess.open(kv["csv"], FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
	quit()


## Строка без вида (EcoLink.message: у заметки нет записи в журнале) — про хищника по тексту.
static func threat_text(txt: String) -> bool:
	var low := txt.to_lower()
	return low.contains("серпохвост") or low.contains("хищник")


## «мин…макс с (n)» или «—».
static func span(v: Array[float]) -> String:
	if v.is_empty():
		return "—"
	return "%.1f…%.1f с (%d)" % [v.min(), v.max(), v.size()]


## Хищник в луче прожектора: ближе дальности света и внутри конуса по курсу корабля.
static func in_beam(ship: EcoLink.ShipState, p: Vector3) -> bool:
	if not ship.light_on:
		return false
	var to := p - ship.pos
	var d := to.length()
	if d > ship.light_range or d < 0.01:
		return false
	var fwd := Vector3(-sin(ship.yaw), 0.0, -cos(ship.yaw))
	return fwd.angle_to(to) < Searchlight.HALF_ANGLE


static func ship_at(xz: Vector2) -> Vector3:
	return Vector3(xz.x, Seabed.mesh_height(xz.x, xz.y) + FLOOR, xz.y)


static func make(probe: bool, seed_value: int) -> EcoView:
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	ev.preds.probe = probe
	ev.preds.alert = alert
	for k in move:
		ev.fish.home_at[k] = QuietMap.home_of(move[k])
	ev.world.reset(seed_value)
	return ev


## Шаг мира без узлов сцены (как EcoView.step, без _sync рисования).
static func tick(ev: EcoView, ship: EcoLink.ShipState, dt: float) -> Array[Dictionary]:
	ev.world.ship = ship
	ev.world.step(dt)
	return ev.world.take_link()


static func fmt_xz(p: Vector3) -> String:
	return "(%d; %d)" % [roundi(p.x), roundi(p.z)]


## Один проход; итог — {bite, charge, warn_before, text}.
static func run(probe: bool, mode: String, seed_value: int) -> Dictionary:
	var ev := make(probe, seed_value)
	var w := ev.world
	var ship := EcoLink.ShipState.new()
	ship.pos = ship_at(path[1] if mode == "stop" or mode == "arrive" else path[0])
	var t := 0.0
	if mode != "base":  # тихая стоянка у 00: без света и хода, пауза хищников кончается
		ship.light_on = false
		for i in int(WAIT_LATE / DT):
			tick(ev, ship, DT)
		t = 0.0
	ship.light_on = true
	ship.light_range = 40.0
	var leg := 0
	var stop_left := 0.0 if mode == "arrive" else STOP
	var hold_left := HOLD_01 if mode == "arrive" else 0.0
	## Ближе всех к кораблю после выхода со стоянки: у каждого хищника — расстояние и время.
	var closest := [INF, INF, INF]
	var closest_t := [0.0, 0.0, 0.0]
	var t_at01 := -1.0
	## У 01 (стоянка arrive): первый хищник ближе REACH и первый сигнал экипажу там.
	var seen01 := {}
	var warn01 := {}
	var pinged := false
	var retreating := false
	var warn := {}
	var charge := {}
	var bite := {}
	var seen_pred := {}
	var dmg := 0.0
	var limit := 200.0
	var beam := {}
	var hushed := -1.0
	var answers := 0
	var cue := -1.0
	while t < limit:
		ship.sonar_ping = false
		if hushed >= 0.0:  # ответ экипажа: без света и хода; через ANSWER_HOLD — свет и путь дальше
			if t - hushed > ANSWER_HOLD:
				hushed = -1.0
				ship.light_on = true
			else:
				ship.speed = 0.0
				_watch(ev, w, ship, tick(ev, ship, DT), t, warn, charge, bite, seen_pred)
				t += DT
				continue
		var target: Vector2
		if retreating:
			target = path[0]
		elif leg < path.size() - 1:
			target = path[leg + 1]
		elif hold_left > 0.0:
			target = path[leg]
		else:
			break
		var at := Vector2(ship.pos.x, ship.pos.z)
		var stopping := not retreating and leg == 1 and stop_left > 0.0 and at.distance_to(path[1]) < 0.5
		var holding := not retreating and leg == path.size() - 1
		if holding:
			ship.speed = 0.0
			hold_left -= DT
			if t_at01 < 0.0:
				t_at01 = t
		elif stopping:
			ship.speed = 0.0
			stop_left -= DT
			if mode == "ping" and not pinged:
				ship.sonar_ping = true
				ship.sonar_range = 150.0
				pinged = true
		else:
			var to := target - at
			if to.length() < SHIP_SPEED * DT:
				ship.pos = ship_at(target)
				if retreating:
					break
				leg += 1
				if leg == 1:
					continue
			else:
				var d := to.normalized()
				var nxt := at + d * SHIP_SPEED * DT
				ship.pos = ship_at(nxt)
				ship.yaw = atan2(-d.x, -d.y)
				ship.speed = SHIP_SPEED
		var evs := tick(ev, ship, DT)
		t += DT
		for e in evs:
			var ty: String = e["type"]
			if ty == EcoLink.HIT and e["by"] != "" and bite.is_empty():
				dmg += float(e["damage"])
			if ty == EcoLink.NEAR and e["species"] == EcoPred.ID and seen_pred.is_empty():
				seen_pred = {"t": t, "ship": ship.pos, "at": e["pos"]}
			if (ty == EcoLink.OBSERVE or ty == EcoLink.MESSAGE) and warn.is_empty():
				var txt: String = e.get("text", "")
				var sp: String = e.get("species", "")
				var nt: String = e.get("note", "")
				if sp == EcoPred.ID or threat_text(txt) or (nt in THREAT_NOTES and sp != ""):
					warn = {"t": t, "ship": ship.pos, "text": txt}
		for e in evs:
			if holding and warn01.is_empty() and (e["type"] == EcoLink.OBSERVE or e["type"] == EcoLink.MESSAGE):
				var tx: String = e.get("text", "")
				if tx.contains("хищник") or tx.to_lower().contains("серпохвост"):
					warn01 = {"t": t, "text": tx}
		for pr in ev.preds.all:
			var dd := pr.agent.p.distance_to(ship.pos)
			if holding and seen01.is_empty() and dd < EcoPred.REACH:
				seen01 = {"t": t, "n": pr.index, "d": dd}
			if leg >= 1 and dd < closest[pr.index]:
				closest[pr.index] = dd
				closest_t[pr.index] = t
			if beam.is_empty() and in_beam(ship, pr.agent.p):
				beam = {"t": t, "n": pr.index, "d": dd}
			if pr.mode == EcoPred.Mode.CHARGE and charge.is_empty():
				charge = {"t": t, "ship": ship.pos, "at": pr.agent.p, "n": pr.index,
					"d": pr.agent.p.distance_to(ship.pos), "why": lure_of(ev, ship)}
			if pr.bit_at > 0.0 and bite.is_empty() and w.time - pr.bit_at < DT * 2:
				bite = {"t": t, "ship": ship.pos, "n": pr.index}
		if mode == "retreat" and not retreating and (not warn.is_empty() or not charge.is_empty()):
			retreating = true
			ship.light_on = false
		if answer != "" and hushed < 0.0 and cue < 0.0 and answer_now(ev, answer, answers, warn):
			cue = t
		if cue >= 0.0 and t - cue >= delay - DT * 0.5:
			cue = -1.0
			hushed = t
			answers += 1
			ship.light_on = false
			ship.speed = 0.0
	var parts: Array[String] = []
	if not seen_pred.is_empty():
		parts.append("сонар %.0f с корабль %s зверь %s" % [seen_pred["t"], fmt_xz(seen_pred["ship"]), fmt_xz(seen_pred["at"])])
	if not warn.is_empty():
		parts.append("сигнал %.0f с у %s «%s»" % [warn["t"], fmt_xz(warn["ship"]), warn["text"]])
	if not charge.is_empty():
		parts.append("бросок №%d %.0f с у %s с %.0f м (%s)" % [charge["n"], charge["t"], fmt_xz(charge["ship"]),
			charge["d"], charge["why"]])
	if not beam.is_empty():
		parts.append("в луче №%d %.0f с с %.0f м" % [beam["n"], beam["t"], beam["d"]])
	if answers > 0:
		parts.append("ответов %d" % answers)
	var reached := leg >= path.size() - 1
	parts.append(("до 01 за %.0f с" % (t_at01 if t_at01 >= 0.0 else t)) if reached \
		else "не дошёл до 01 за %.0f с, у %s" % [t, fmt_xz(ship.pos)])
	if not bite.is_empty():
		parts.append("укус №%d %.0f с у %s" % [bite["n"], bite["t"], fmt_xz(bite["ship"])])
	if parts.is_empty():
		parts.append("тихо")
	if mode == "arrive":
		var near: Array[String] = []
		for i in 3:
			near.append("№%d %.0f м на %.0f с" % [i, closest[i], closest_t[i]])
		parts.append("у 01 с %.0f с; ближе всех: %s" % [t_at01, ", ".join(near)])
		if not seen01.is_empty():
			parts.append("у 01 виден №%d на %.0f с (%.0f м)" % [seen01["n"], seen01["t"], seen01["d"]])
		if not warn01.is_empty():
			parts.append("у 01 сигнал %.0f с «%s»" % [warn01["t"], warn01["text"]])
	var before := not warn.is_empty() and (charge.is_empty() or float(warn["t"]) < float(charge["t"]))
	var wc := float(charge["t"]) - float(warn["t"]) if before and not charge.is_empty() else -1.0
	var cb := float(bite["t"]) - float(charge["t"]) if not bite.is_empty() and not charge.is_empty() else -1.0
	var beam_before := not beam.is_empty() and (charge.is_empty() or float(beam["t"]) <= float(charge["t"]))
	ev.free()
	return {"wc": wc, "cb": cb, "beam_before": beam_before, "reached": reached, "answers": answers,"bite": not bite.is_empty(), "charge": not charge.is_empty(), "warn_before": before,
		"by": int(charge.get("n", 0)), "seen01": not seen01.is_empty(), "warn01": not warn01.is_empty(),
		"charge01": not charge.is_empty() and t_at01 >= 0.0 and float(charge["t"]) >= t_at01,
		"text": "; ".join(parts)}


## Что манит в миг броска: свет, ход быстрее EcoPred.HEAR_SPEED, след планктона (`EcoPlankton.betrays`).
static func lure_of(ev: EcoView, ship: EcoLink.ShipState) -> String:
	var why: Array[String] = []
	if ship.light_on:
		why.append("свет")
	if absf(ship.speed) > EcoPred.HEAR_SPEED:
		why.append("ход")
	if ev.preds.plankton != null and ev.preds.plankton.betrays():
		why.append("след планктона")
	return ", ".join(why) if not why.is_empty() else "—"


## Пора ли экипажу гасить свет: signal — один раз, по первому сигналу; charge — хищник в броске; alert — хищник
## в «замере» или броске (каждый раз, после ANSWER_HOLD корабль снова со светом идёт дальше).
static func answer_now(ev: EcoView, how: String, answers: int, warn: Dictionary) -> bool:
	if how == "signal":
		return answers == 0 and not warn.is_empty()
	for pr in ev.preds.all:
		if pr.mode == EcoPred.Mode.CHARGE or (how == "alert" and pr.mode == EcoPred.Mode.ALERT):
			return true
	return false


## Шаг после ответа экипажа: только сигнал, бросок и укус (корабль стоит, путь не идёт).
static func _watch(ev: EcoView, w: EcoWorld, ship: EcoLink.ShipState, evs: Array[Dictionary], t: float,
		warn: Dictionary, charge: Dictionary, bite: Dictionary, seen_pred: Dictionary) -> void:
	for e in evs:
		if (e["type"] == EcoLink.OBSERVE or e["type"] == EcoLink.MESSAGE) and warn.is_empty() \
				and (e.get("species", "") == EcoPred.ID or threat_text(e.get("text", ""))):
			warn.merge({"t": t, "ship": ship.pos, "text": e.get("text", "")})
		if e["type"] == EcoLink.NEAR and e["species"] == EcoPred.ID and seen_pred.is_empty():
			seen_pred.merge({"t": t, "ship": ship.pos, "at": e["pos"]})
	for pr in ev.preds.all:
		if pr.mode == EcoPred.Mode.CHARGE and charge.is_empty():
			charge.merge({"t": t, "ship": ship.pos, "at": pr.agent.p, "n": pr.index,
				"d": pr.agent.p.distance_to(ship.pos), "why": lure_of(ev, ship)})
		if pr.bit_at > 0.0 and bite.is_empty() and w.time - pr.bit_at < DT * 2:
			bite.merge({"t": t, "ship": ship.pos, "n": pr.index})


## Где бывают хищники, когда корабль далеко (у 00, без света, 400 с на зерно): доля времени хотя бы одного в тихом
## круге и в окне угрозы перед рифом (полоса z WIN_Z у прохода), входы в круг по режимам, у каждого хищника.
static func residency(probe: bool, seeds: int) -> String:
	var q := Vector3(EcoPred.QUIET.x, 0.0, EcoPred.QUIET.y)
	var in_q := 0
	var in_win := 0
	var total := 0
	var per := [0, 0, 0]
	var entries := {}
	for s in seeds:
		var ev := make(probe, 20261018 + s * 7919)
		var ship := EcoLink.ShipState.new()
		ship.pos = ship_at(Vector2(-150, 150))
		var was := [false, false, false]
		for i in int(400.0 / (DT * 3)):
			tick(ev, ship, DT * 3)
			total += 1
			var any_q := false
			var any_w := false
			for pr in ev.preds.all:
				var p := pr.agent.p
				var inside := EcoPred._flat_dist(p, q) < EcoPred.QUIET_R
				if inside:
					any_q = true
					per[pr.index] += 1
					if not was[pr.index]:
						var k: String = EcoPred.Mode.keys()[pr.mode]
						entries[k] = int(entries.get(k, 0)) + 1
				was[pr.index] = inside
				if p.z > WIN_Z.x and p.z < WIN_Z.y and p.x > 0.0 and p.x < 70.0:
					any_w = true
			in_q += 1 if any_q else 0
			in_win += 1 if any_w else 0
		ev.free()
	return "== %s, корабль далеко: в тихом круге %d %% времени (№0 %d %%, №1 %d %%, №2 %d %%), в окне перед рифом %d %%, входы в круг %s" % [
		"проба" if probe else "сейчас", 100 * in_q / total, 100 * per[0] / total, 100 * per[1] / total,
		100 * per[2] / total, 100 * in_win / total, str(entries)]
