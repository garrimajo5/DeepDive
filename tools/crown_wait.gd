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
## Разбор тревоги кроны по причине (п. 2 (аж), #1400): «транзит» — ближайший серпохвост внутри CROWN_ALARM патрулирует
## к цели вне CROWN_ALARM (огибает риф по пути, `reef_steer`), «цель у рифа» — патруль к цели внутри CROWN_ALARM,
## «чистка» — внутри CROWN_ALARM плывёт на чистку или чистится (`Mode.CLEAN`, п. 2 (ак): отдельно от «охоты», чтобы
## путь к станции не путали с охотой в числах (э)/(аж)), «охота» — внутри CROWN_ALARM в другом режиме (не патруль и
## не чистка), «ушёл» — внутри CROWN_ALARM серпохвоста нет (тревога спадает).
## В итоге — суммы по зёрнам, эпизоды «спряталась → вернулась», зёрна без подхода серпохвоста внутрь CROWN_ALARM,
## доля транзита в тревоге и самый долгий отрезок транзита.
## Разбор «охоты» (п. 2 (аз), #1400): за кем и чем занят ближайший серпохвост в эти секунды — ключ `prey_key`
## (охота: крона / стая рифа / другая стая с номером; не охота — режим), сколько секунд добыча внутри
## `EcoPred.REEF_KEEP` и сколько секунд это стая рифа или крона (кольцо кроны — внутри рифа). У «чистки» — на каком
## расстоянии от оси станция чистки (`EcoLeech.Station.top`), к которой он плывёт.
## Чистка за весь проход (вариант 2 (аз): станцию в кольце `EcoPred.REEF_KEEP` хищник не выбирает): сколько чисток
## закончено (событие `cleaned`) и у скольких из них станция снаружи кольца, сколько секунд серпохвосты (все) плыли
## на чистку к станции внутри кольца — чтобы нулевая «чистка» у 01 не скрыла потерю чистки вообще.

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
## Причины тревоги кроны (ключи `why` в итоге зерна) — в этом порядке и в строках.
const WHY: Array[String] = ["transit", "goal_in", "hunt", "clean", "away"]
const WHY_RU := {"transit": "транзит", "goal_in": "цель у рифа", "hunt": "охота", "clean": "чистка", "away": "ушёл"}
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
## first (с тревоги за первые FIRST с), modes (режим → с залипания), goal_in (с залипания с целью внутри CROWN_ALARM),
## why (причина → с тревоги кроны, сумма — alarm), transit (с, самый долгий отрезок транзита), transit_r ([мин, макс] м
## от оси на транзите), prey (ключ `prey_key` → с «охоты»), prey_in (с «охоты» с добычей внутри REEF_KEEP),
## prey_home (с «охоты» за кроной или стаей рифа), clean_r ([мин, макс] м от оси до станции чистки в «чистке»)}.
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
		"reef_hid": 0.0, "hunger": 0.0, "nearest": INF, "reef": reef.size(), "first": 0.0, "modes": {}, "goal_in": 0.0,
		"why": {}, "transit": 0.0, "transit_r": [INF, 0.0], "prey": {}, "prey_in": 0.0, "prey_home": 0.0,
		"clean_r": [INF, 0.0], "cleaned": 0, "cleaned_out": 0, "clean_in": 0.0}
	for k in WHY:
		r["why"][k] = 0.0
	var stood := [0.0]
	var at_01 := [false]
	var listen := func(e: EcoBus.Event) -> void:
		if at_01[0] and e.species == EcoFish.ID and e.note == "flee" and _flat(e.pos, axis) < EcoFish.CROWN_RING.y + 6.0:
			r["lines"] += 1
		if e.species == EcoLeech.ID and e.note == "cleaned":
			r["cleaned"] += 1
			if _flat(e.pos, axis) >= EcoPred.REEF_KEEP:
				r["cleaned_out"] += 1
	w.bus.emitted.connect(listen)
	# Ноги: куда, сколько стоять. Тёмная стоянка — без света у 00.
	var legs: Array = [[MidCalm.PATH[0], dark, false], [MidCalm.PATH[1], mid, true], [MidCalm.PATH[2], stay, true]]
	var leg := 0
	var left: float = legs[0][1]
	var run_alarm := 0.0
	var run_stuck := 0.0
	var run_transit := 0.0
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
		for p: EcoPred.Pred in ev.preds.all:
			if p.mode == EcoPred.Mode.CLEAN and ev.leeches and p.station >= 0 and p.station < ev.leeches.stations.size() \
					and _flat(ev.leeches.stations[p.station].top, axis) < EcoPred.REEF_KEEP:
				r["clean_in"] += DT
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
		var why := cause(pr, pd, axis) if hidden else ""
		if why != "":
			r["why"][why] += DT
		if why == "hunt":
			var pk := prey_key(pr, axis)
			r["prey"][pk] = float(r["prey"].get(pk, 0.0)) + DT
			if pr.mode == EcoPred.Mode.HUNT and pr.prey:
				if _flat(pr.prey.agent.p, axis) < EcoPred.REEF_KEEP:
					r["prey_in"] += DT
				if pk == "крона" or pk == "риф":
					r["prey_home"] += DT
		if why == "clean":
			if ev.leeches and pr.station >= 0 and pr.station < ev.leeches.stations.size():
				var sd := _flat(ev.leeches.stations[pr.station].top, axis)
				r["clean_r"][0] = minf(r["clean_r"][0], sd)
				r["clean_r"][1] = maxf(r["clean_r"][1], sd)
		if why == "transit":
			run_transit += DT
			r["transit"] = maxf(r["transit"], run_transit)
			r["transit_r"][0] = minf(r["transit_r"][0], pd)
			r["transit_r"][1] = maxf(r["transit_r"][1], pd)
		else:
			run_transit = 0.0
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


## Причина тревоги кроны по ближайшему к оси серпохвосту `pr` (на `pd` м от оси `axis`): ключ из WHY.
static func cause(pr: EcoPred.Pred, pd: float, axis: Vector3) -> String:
	if pr == null or pd >= EcoFish.CROWN_ALARM:
		return "away"
	if pr.mode == EcoPred.Mode.CLEAN:
		return "clean"
	if pr.mode != EcoPred.Mode.PATROL:
		return "hunt"
	return "goal_in" if _flat(pr.agent.goal, axis) < EcoFish.CROWN_ALARM else "transit"


## За кем «охота» ближайшего серпохвоста `pr`: в режиме HUNT — «крона», «риф» (дом стаи ближе REEF_HOME к оси
## `axis`), «стая N» или «без добычи»; в другом режиме — имя режима строчными (`eat`, `investigate`…).
static func prey_key(pr: EcoPred.Pred, axis: Vector3) -> String:
	if pr.mode != EcoPred.Mode.HUNT:
		return String(EcoPred.Mode.keys()[pr.mode]).to_lower()
	if pr.prey == null or pr.prey.shoal == null:
		return "без добычи"
	var sh: EcoFish.Shoal = pr.prey.shoal
	if sh.crown:
		return "крона"
	if _flat(sh.home, axis) < REEF_HOME:
		return "риф"
	return "стая %d" % sh.index


static func _prey_text(prey: Dictionary) -> String:
	var keys := prey.keys()
	keys.sort_custom(func(a, b) -> bool: return float(prey[a]) > float(prey[b]))
	var t := ""
	for k in keys:
		t += "%s%s %.1f" % [", " if t != "" else "", k, prey[k]]
	return t


static func seed_line(s: int, r: Dictionary) -> String:
	var sr: Array = r["stuck_r"]
	var modes := ""
	for k in r["modes"]:
		modes += "%s%s %.1f" % [", " if modes != "" else "", String(k).to_lower(), r["modes"][k]]
	var why := ""
	for k in WHY:
		why += "%s%s %.1f" % [", " if why != "" else "", WHY_RU[k], r["why"][k]]
	var tr: Array = r["transit_r"]
	var cr: Array = r["clean_r"]
	return "  зерно %2d: крона в тревоге %5.1f с (за первые %.0f с — %4.1f), эпизодов %d, самый долгий %5.1f с, строк кроны %d; залипание %5.1f с%s, цель внутри %.1f с, режимы [%s], стаи рифа (%d) прятались %4.1f с; голод у рифа до %.2f, ближе всего %.1f м; причины [%s], транзит самый долгий %.1f с%s; охота [%s], добыча внутри рифа %.1f с%s; чисток за проход %d (снаружи кольца %d), к станции в кольце %.1f с" % [
		s, r["alarm"], FIRST, r["first"], r["episodes"], r["longest"], r["lines"], r["stuck"],
		(" (%.1f–%.1f м от оси)" % [sr[0], sr[1]]) if r["stuck"] > 0.0 else "", r["goal_in"], modes, r["reef"],
		r["reef_hid"], r["hunger"], r["nearest"], why, r["transit"],
		(" (%.1f–%.1f м от оси)" % [tr[0], tr[1]]) if r["transit"] > 0.0 else "", _prey_text(r["prey"]),
		r["prey_in"], (", станция чистки %.1f–%.1f м от оси" % [cr[0], cr[1]]) if cr[0] < INF else "",
		r["cleaned"], r["cleaned_out"], r["clean_in"]]


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
	var why := {}
	for k in WHY:
		why[k] = 0.0
	var total := 0.0
	var episodes := 0
	var transits: Array = []
	var transit_seeds := 0
	var no_visit := 0
	var prey := {}
	var prey_in := 0.0
	var prey_home := 0.0
	var cleaned := 0
	var cleaned_out := 0
	var clean_in := 0.0
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
		total += r["alarm"]
		if r["nearest"] >= EcoFish.CROWN_ALARM:
			no_visit += 1
		episodes += r["episodes"]
		for k in WHY:
			why[k] += r["why"][k]
		for k in r["prey"]:
			prey[k] = float(prey.get(k, 0.0)) + float(r["prey"][k])
		prey_in += r["prey_in"]
		prey_home += r["prey_home"]
		cleaned += r["cleaned"]
		cleaned_out += r["cleaned_out"]
		clean_in += r["clean_in"]
		if r["transit"] > 0.0:
			transit_seeds += 1
			transits.append(r["transit"])
	longest.sort()
	stucks.sort()
	firsts.sort()
	transits.sort()
	var parts := ""
	for k in WHY:
		parts += "%s%s %.0f с (%s)" % [", " if parts != "" else "", WHY_RU[k], why[k], _pct(why[k], total)]
	put(lines, "== причины тревоги кроны, сумма %d зёрен: всего %.0f с, эпизодов %d, зёрен без подхода серпохвоста ближе %.0f м — %d; %s; транзит в %d/%d зёрнах, самый долгий отрезок — медиана %s, макс %s с" % [
		seeds, total, episodes, EcoFish.CROWN_ALARM, no_visit, parts, transit_seeds, seeds, _med(transits), _max(transits)])
	put(lines, "== охота у рифа, сумма %d зёрен: всего %.0f с; [%s]; добыча внутри REEF_KEEP %.0f м — %.0f с, крона или стая рифа — %.0f с" % [
		seeds, why["hunt"], _prey_text(prey), EcoPred.REEF_KEEP, prey_in, prey_home])
	put(lines, "== чистка за весь проход, сумма %d зёрен: закончено %d (станция снаружи REEF_KEEP — %d), к станции в кольце %.0f с" % [
		seeds, cleaned, cleaned_out, clean_in])
	put(lines, "== итог: крона в тревоге в %d/%d зёрнах (самый долгий эпизод — медиана %s, макс %s с; за первые %.0f с — медиана %s с); залипание голодного в %d/%d (макс %s с), дольше %.0f с — %d/%d" % [
		alarmed, seeds, _med(longest), _max(longest), FIRST, _med(firsts), stuck, seeds, _max(stucks), LONG, long, seeds])
	return lines


static func _pct(a: float, b: float) -> String:
	return "—" if b <= 0.0 else "%.0f %%" % (100.0 * a / b)


static func _med(v: Array) -> String:
	return "—" if v.is_empty() else "%.1f" % v[v.size() / 2]


static func _max(v: Array) -> String:
	return "—" if v.is_empty() else "%.1f" % v[-1]
