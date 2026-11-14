extends SceneTree
## Строки мира почти разом на приборах (#1400, п. 2 (э) из `docs/roles/dev-b.md`). У `Status.Message` одно место в
## очереди (`next`): строка мира, пришедшая, пока текущая видна меньше `MIN_SHOW`, ждёт; третья за это время сменяет
## ждущую — та не видна вовсе. Здесь — бывает ли это в сцене: мир целиком (`EcoView`, как в tools/mid_calm.gd `make`),
## тот же проход, что в tools/crown_wait.gd (тёмная стоянка у 00, свет, стоянка у середины, долгая стоянка у 01
## (33; −22) со светом), каждая строка с `EcoWorld.take_link` — на `Status.Message` так же, как `Main._world_say`
## (`say(…, wait = true, urgent, keep)`). Headless, без узлов сцены; облачный расчёт, не телефонный.
##   godot --headless --path . -s tools/lines_01.gd [-- seeds=16 stay=<с> turn=<с> dark=<с> mid=<с>]
## `turn` — смена течения (`EcoCurrent.timer`) через столько секунд стоянки у 01 (−1 — своим ходом, `PERIOD`).
## По зерну и участку: сколько строк пришло, сколько из них «потеряно» (видна меньше MIN_SHOW), и какие (вид/заметка);
## «тройка» — три строки за MIN_SHOW.

const MidCalm := preload("res://tools/mid_calm.gd")
const DT := 1.0 / 30.0
const DARK := 30.0
const MID := 25.0
const STAY := 120.0
const SPEED := 5.0
const LEGS: Array[String] = ["00", "mid", "01"]
## Сколько секунд после прихода строка может ждать и показываться (MESSAGE_SECONDS и запас на очередь).
const WINDOW := Status.MESSAGE_SECONDS + 2.0 * Status.Message.MIN_SHOW
static var dark := DARK
static var mid := MID
static var stay := STAY
## Секунда стоянки у 01, когда повернуть течение; < 0 — своим ходом.
static var turn := -1.0
static var live := false


func _init() -> void:
	var seeds := 16
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"seeds": seeds = int(kv[1])
			"stay": stay = float(kv[1])
			"dark": dark = float(kv[1])
			"mid": mid = float(kv[1])
			"turn": turn = float(kv[1])
	live = true
	report(seeds)
	quit()


static func put(lines: Array[String], line: String) -> void:
	lines.append(line)
	if live:
		print(line)


## Метка строки: вид/заметка события шины с тем же текстом, «?» — не нашли.
static func _label(text: String, evs: Array) -> String:
	for ev: EcoBus.Event in evs:
		if ev.text() == text:
			return "%s/%s" % [ev.species, ev.note]
	return "?"


## Один проход: по участку {got, lost, lost_what (метка → число), triples}; ещё turn_at (с стоянки у 01, когда
## течение повернуло; −1 — не повернуло) и shown — все показы у 01 ([с, метка, сколько видна]).
static func run(seed_value: int) -> Dictionary:
	var ev: EcoView = MidCalm.make(seed_value)
	var w := ev.world
	var ship := EcoLink.ShipState.new()
	ship.pos = MidCalm.ship_at(MidCalm.PATH[0])
	var r := {"turn_at": -1.0, "shown": []}
	for k in LEGS:
		r[k] = {"got": 0, "lost": 0, "lost_what": {}, "triples": 0}
	var legs: Array = [[MidCalm.PATH[0], dark, false], [MidCalm.PATH[1], mid, true], [MidCalm.PATH[2], stay, true]]
	var leg := 0
	var left: float = legs[0][1]
	var msg := Status.Message.new()
	# Пришедшие строки: [текст, метка, участок, когда, сколько видна].
	var got: Array = []
	var stood := 0.0
	var t := 0.0
	var turned := false
	var turns0 := ev.current.turns
	while leg < legs.size():
		var tg: Vector2 = legs[leg][0]
		ship.light_on = legs[leg][2]
		var d := Vector2(tg.x - ship.pos.x, tg.y - ship.pos.z)
		if d.length() < 0.5:
			ship.speed = 0.0
			if left <= 0.0:
				leg += 1
				if leg < legs.size():
					left = legs[leg][1]
				continue
			left -= DT
		else:
			ship.yaw = atan2(-d.x, -d.y)
			ship.speed = SPEED
			var mv := d.normalized() * minf(SPEED * DT, d.length())
			ship.pos = MidCalm.ship_at(Vector2(ship.pos.x + mv.x, ship.pos.z + mv.y))
		w.ship = ship
		var at_01 := leg == 2 and d.length() < 0.5
		if at_01:
			if turn >= 0.0 and not turned and stood >= turn:
				ev.current.timer = 0.01
				turned = true
			stood += DT
		w.step(DT)
		t += DT
		if at_01 and float(r["turn_at"]) < 0.0 and ev.current.turns != turns0:
			r["turn_at"] = stood
		turns0 = ev.current.turns
		var evs := w.bus.pending.duplicate()
		var leg_key: String = LEGS[leg]
		var arrived := []
		for e in w.take_link():
			if e.get("type") != EcoLink.MESSAGE and e.get("type") != EcoLink.OBSERVE:
				continue
			var text := String(e.get("text", ""))
			if text == "":
				continue
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)))
			got.append([text, _label(text, evs), leg_key, t, 0.0])
			arrived.append(t)
			r[leg_key]["got"] += 1
		msg.update(DT)
		if msg.text != "":
			# Видна — всем недавним приходам той же строки: повтор того же текста не теряет первый.
			for i in range(got.size() - 1, -1, -1):
				if t - float(got[i][3]) > WINDOW:
					break
				if got[i][0] == msg.text:
					got[i][4] += DT
	# Итог по пришедшим: потеряна — за WINDOW после прихода видна меньше MIN_SHOW; тройка — третья за MIN_SHOW.
	for i in got.size():
		var g: Array = got[i]
		var lk: String = g[2]
		if lk == "01":
			r["shown"].append([float(g[3]), g[1], float(g[4])])
		if float(g[4]) < Status.Message.MIN_SHOW - DT * 1.5:
			r[lk]["lost"] += 1
			r[lk]["lost_what"][g[1]] = int(r[lk]["lost_what"].get(g[1], 0)) + 1
		if i >= 2 and float(g[3]) - float(got[i - 2][3]) < Status.Message.MIN_SHOW:
			r[lk]["triples"] += 1
	ev.free()
	return r


static func seed_line(s: int, r: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in LEGS:
		var a: Dictionary = r[k]
		var what := PackedStringArray()
		for lab in a["lost_what"]:
			what.append("%s ×%d" % [lab, a["lost_what"][lab]])
		parts.append("%s: строк %d, потеряно %d%s, троек %d" % [k, a["got"], a["lost"],
			(" (%s)" % ", ".join(what)) if what.size() > 0 else "", a["triples"]])
	return "  зерно %2d: %s; течение у 01 повернуло %s" % [s, "; ".join(parts),
		("на %.1f с" % r["turn_at"]) if float(r["turn_at"]) >= 0.0 else "—"]


static func report(seeds: int) -> Array[String]:
	var lines: Array[String] = []
	put(lines, "== строки мира почти разом: тёмная стоянка %.0f с у 00, середина %.0f с, у 01 (33; −22) со светом %.0f с, течение %s, %d зёрен" % [
		dark, mid, stay, ("через %.0f с стоянки у 01" % turn) if turn >= 0.0 else "своим ходом", seeds])
	var tot := {}
	for k in LEGS:
		tot[k] = {"got": 0, "lost": 0, "seeds_lost": 0, "triples": 0, "what": {}}
	for s in seeds:
		var r := run(s)
		put(lines, seed_line(s, r))
		for k in LEGS:
			var a: Dictionary = r[k]
			tot[k]["got"] += a["got"]
			tot[k]["lost"] += a["lost"]
			tot[k]["triples"] += a["triples"]
			if a["lost"] > 0:
				tot[k]["seeds_lost"] += 1
			for lab in a["lost_what"]:
				tot[k]["what"][lab] = int(tot[k]["what"].get(lab, 0)) + int(a["lost_what"][lab])
	var parts := PackedStringArray()
	for k in LEGS:
		var what := PackedStringArray()
		for lab in tot[k]["what"]:
			what.append("%s ×%d" % [lab, tot[k]["what"][lab]])
		parts.append("%s — строк %d, потеряно %d в %d/%d зёрнах%s, троек %d" % [k, tot[k]["got"], tot[k]["lost"],
			tot[k]["seeds_lost"], seeds, (" (%s)" % ", ".join(what)) if what.size() > 0 else "", tot[k]["triples"]])
	put(lines, "== итог: %s" % "; ".join(parts))
	return lines
