extends SceneTree
## Голодный серпохвост у 01, когда вся добыча рядом в укрытии (#1400, п. 2 (ю) из `docs/roles/dev-b.md`). Разбор (р)
## (PR #1878): в мире одной кроны голодный хищник 20–75 с ходит по краю рифа (36–40 м от оси, внутри
## `EcoFish.CROWN_ALARM`) и снова прячет крону. Здесь — бывает ли это в сцене: мир целиком (`EcoView`, как в
## tools/mid_calm.gd `make`), тёмная стоянка у 00, свет и проход 00 → середина (стоянка) → 01, затем долгая стоянка у
## 01 (33; −22) со светом. Headless, без узлов сцены; облачный расчёт, не телефонный.
##   godot --headless --path . -s tools/crown_wait.gd [-- seeds=16 stay=<с> dark=<с> mid=<с>]
## По зерну на стоянке у 01: сколько секунд стаи кроны в тревоге (`Shoal.alarm`), сколько эпизодов тревоги и самый
## долгий, строк кроны «flee» на шине; «залипание» — тревога кроны, пока ближайший к оси серпохвост голоден
## (> `EcoPred.HUNT_HUNGER`) и внутри `CROWN_ALARM`: самый долгий такой отрезок и на каком расстоянии от оси хищник
## держался; прятались ли в это время и стаи рифа у 01 (не крона, дом ближе REEF_HOME м от оси). Строка зерна —
## сразу, как посчитано. Ещё — тревога кроны за первые FIRST с стоянки (столько стоит экипаж в сцене) и чем занят
## залипший хищник: режимы (`EcoPred.Mode`, с) и сколько секунд его цель (`agent.goal`) внутри CROWN_ALARM.

const MidCalm := preload("res://tools/mid_calm.gd")
const DT := 1.0 / 30.0
const DARK := 30.0
const MID := 25.0
const STAY := 120.0
const SPEED := 5.0
## Стая рифа у 01 — дом ближе этого к оси кроны (м, по горизонтали).
const REEF_HOME := 45.0
## Залипание длиннее этого — «да» в итоге (с).
const LONG := 20.0
## Первые секунды стоянки у 01 — столько стоит экипаж в сцене (как стоянка STOP в tools/mid_calm.gd, с).
const FIRST := 25.0
static var dark := DARK
static var mid := MID
static var stay := STAY
## Печатать строки сразу (`_init`; тесты собирают молча).
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
	live = true
	report(seeds)
	quit()


static func put(lines: Array[String], line: String) -> void:
	lines.append(line)
	if live:
		print(line)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Один проход: {alarm (с), episodes, longest (с), lines, stuck (с, самый долгий отрезок), stuck_r ([мин, макс] м),
## reef_hid (с, стаи рифа прятались во время залипания), hunger (макс. голод ближайшего за стоянку), nearest (м),
## first (с тревоги за первые FIRST с), modes (режим → с залипания), goal_in (с залипания с целью внутри CROWN_ALARM)}.
static func run(seed_value: int) -> Dictionary:
	var ev: EcoView = MidCalm.make(seed_value)
	var w := ev.world
	var ship := EcoLink.ShipState.new()
	ship.pos = MidCalm.ship_at(MidCalm.PATH[0])
	var crown: Array = []
	var reef: Array = []
	for sh in ev.fish.shoals:
		if sh.crown:
			crown.append(sh)
	var axis: Vector3 = crown[0].axis
	for sh in ev.fish.shoals:
		if not sh.crown and _flat(sh.home, axis) < REEF_HOME:
			reef.append(sh)
	var r := {"alarm": 0.0, "episodes": 0, "longest": 0.0, "lines": 0, "stuck": 0.0, "stuck_r": [INF, 0.0],
		"reef_hid": 0.0, "hunger": 0.0, "nearest": INF, "reef": reef.size(), "first": 0.0, "modes": {}, "goal_in": 0.0}
	var stood := [0.0]
	var at_01 := [false]
	var listen := func(e: EcoBus.Event) -> void:
		if at_01[0] and e.species == EcoFish.ID and e.note == "flee" and _flat(e.pos, axis) < EcoFish.CROWN_RING.y + 6.0:
			r["lines"] += 1
	w.bus.emitted.connect(listen)
	# Ноги: куда, сколько стоять. Тёмная стоянка — без света у 00.
	var legs: Array = [[MidCalm.PATH[0], dark, false], [MidCalm.PATH[1], mid, true], [MidCalm.PATH[2], stay, true]]
	var leg := 0
	var left: float = legs[0][1]
	var run_alarm := 0.0
	var run_stuck := 0.0
	var was := false
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
		at_01[0] = leg == 2 and d.length() < 0.5
		w.step(DT)
		w.take_link()
		if not at_01[0]:
			continue
		stood[0] += DT
		var hidden := false
		for sh in crown:
			hidden = hidden or sh.alarm > 0.0
		var pr: EcoPred.Pred = null
		var pd := INF
		for p: EcoPred.Pred in ev.preds.all:
			var q := _flat(p.agent.p, axis)
			if q < pd:
				pd = q
				pr = p
		r["nearest"] = minf(r["nearest"], pd)
		if pr and pd < EcoFish.CROWN_ALARM:
			r["hunger"] = maxf(r["hunger"], pr.hunger)
		if hidden and stood[0] <= FIRST + DT * 0.5:
			r["first"] += DT
		if hidden:
			r["alarm"] += DT
			run_alarm += DT
			if not was:
				r["episodes"] += 1
			r["longest"] = maxf(r["longest"], run_alarm)
		else:
			run_alarm = 0.0
		was = hidden
		if hidden and pr and pd < EcoFish.CROWN_ALARM and pr.hunger > EcoPred.HUNT_HUNGER:
			run_stuck += DT
			r["stuck"] = maxf(r["stuck"], run_stuck)
			r["stuck_r"][0] = minf(r["stuck_r"][0], pd)
			r["stuck_r"][1] = maxf(r["stuck_r"][1], pd)
			var rh := false
			for sh in reef:
				rh = rh or sh.alarm > 0.0
			if rh:
				r["reef_hid"] += DT
			var mn: String = EcoPred.Mode.keys()[pr.mode]
			r["modes"][mn] = float(r["modes"].get(mn, 0.0)) + DT
			if _flat(pr.agent.goal, axis) < EcoFish.CROWN_ALARM:
				r["goal_in"] += DT
		else:
			run_stuck = 0.0
	ev.free()
	return r


static func seed_line(s: int, r: Dictionary) -> String:
	var sr: Array = r["stuck_r"]
	var modes := ""
	for k in r["modes"]:
		modes += "%s%s %.1f" % [", " if modes != "" else "", String(k).to_lower(), r["modes"][k]]
	return "  зерно %2d: крона в тревоге %5.1f с (за первые %.0f с — %4.1f), эпизодов %d, самый долгий %5.1f с, строк кроны %d; залипание %5.1f с%s, цель внутри %.1f с, режимы [%s], стаи рифа (%d) прятались %4.1f с; голод у рифа до %.2f, ближе всего %.1f м" % [
		s, r["alarm"], FIRST, r["first"], r["episodes"], r["longest"], r["lines"], r["stuck"],
		(" (%.1f–%.1f м от оси)" % [sr[0], sr[1]]) if r["stuck"] > 0.0 else "", r["goal_in"], modes, r["reef"],
		r["reef_hid"], r["hunger"], r["nearest"]]


static func report(seeds: int) -> Array[String]:
	var lines: Array[String] = []
	put(lines, "== голодный серпохвост у 01, вся добыча в укрытии: тёмная стоянка %.0f с, стоянка у середины %.0f с, у 01 (33; −22) со светом %.0f с, %d зёрен" % [
		dark, mid, stay, seeds])
	var alarmed := 0
	var stuck := 0
	var long := 0
	var firsts: Array = []
	var longest: Array = []
	var stucks: Array = []
	for s in seeds:
		var r := run(s)
		put(lines, seed_line(s, r))
		firsts.append(r["first"])
		if r["alarm"] > 0.0:
			alarmed += 1
			longest.append(r["longest"])
		if r["stuck"] > 0.0:
			stuck += 1
			stucks.append(r["stuck"])
		if r["stuck"] > LONG:
			long += 1
	longest.sort()
	stucks.sort()
	firsts.sort()
	put(lines, "== итог: крона в тревоге в %d/%d зёрнах (самый долгий эпизод — медиана %s, макс %s с; за первые %.0f с — медиана %s с); залипание голодного в %d/%d (макс %s с), дольше %.0f с — %d/%d" % [
		alarmed, seeds, _med(longest), _max(longest), FIRST, _med(firsts), stuck, seeds, _max(stucks), LONG, long, seeds])
	return lines


static func _med(v: Array) -> String:
	return "—" if v.is_empty() else "%.1f" % v[v.size() / 2]


static func _max(v: Array) -> String:
	return "—" if v.is_empty() else "%.1f" % v[-1]
