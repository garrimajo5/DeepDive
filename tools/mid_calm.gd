extends SceneTree
## Спокойная середина 00 → 01 (#1400): что ещё зажигает луч, пока экипаж смотрит цепочку «прожектор → волнолист →
## моллюски». Гейм-дизайнер (08.11): в середине не накладывать зов хищника гребневиками. Мир целиком (`EcoView`, дно
## `Seabed.mesh_height`), headless, без узлов сцены; облачный расчёт, не телефонный.
##   godot --headless --path . -s tools/mid_calm.gd [-- seeds=16 raduzh=1:80,5 lim=<с> dark=<с> probe=1 answer=1 delay=<с> hold=<с>
##   start0=<x>,<z> band0=<x0>,<x1>,<z0>,<z1> fish=<номер>:<x>,<z>]
## fish=<номер>:<x>,<z> — дом стаи рифа (светляки, `EcoFish.home_at`; дом на HOME_LIFT над `Seabed.height`) на пробу в
## другом месте (#1400, гейм-дизайнер и уровни 12.11: стая 0 (15; 76) → (100; 90)); несколько — через «;». Печатает
## разброс стаи WATCH_SHOAL (рыбы дальше всего от дома, ближе всего к выходу 00 и к пути середины) и погони всех
## серпохвостов (HUNT): ближе всего к выходу 00 и к пути середины, на какие стаи.
## band0= — проба целей патруля №0 (#1400, уровни и гейм-дизайнер 12.11, вариант 1): цели «у дома» стай светляков 0 и 1
## — в прямоугольнике x0…x1, z0…z1 (`EcoPred.home_band`); печатает цели №0 и отрезки между ними против пути середины.
## start0= — старт серпохвоста №0 на пробу в другом месте (как `EcoPred.STARTS[0]`: та же высота над дном, #1400, 12.11).
## raduzh=<номер>:<x>,<z> — дом стаи радужников с этим номером на пробу в другом месте (`EcoRaduzh._homes` до сброса
## мира; несколько — через «;»). Проход как `late` в tools/patrol.gd: 30 с без света у 00 (пауза хищников после сброса
## кончилась), затем свет и ход 5 м/с по оси PATH на 7 м над дном, стоянка STOP с у середины, дальше к 01.
## Печатает по зерну и итогом: когда раскрылся волнолист у прохода, вспыхнула ли в середине стая радужников (какая,
## на каком расстоянии от корабля), «betray» — серпохвост заметил вспышку и плывёт к кораблю. Угрозы — события шины
## THREATS в слышимости экипажа (`EcoBus.HEARING`), удары и присоски (HIT, DRAIN), серпохвост в «замере» или броске
## (ALERT, CHARGE) и ближе всего к кораблю — раздельно для середины и подхода к 01.
## «Середина» — от выхода из 00 до конца стоянки; дальше подход к 01 (там своя цепочка угрозы).

## Угрозы кораблю в ленте экипажа: вид → заметки событий шины (песчаная засада, охота серпохвоста, стеклоуст,
## эхоловец).
const THREATS := {
	"glazun": ["ambush", "eyes"],
	"pred": ["alert", "ship", "ping", "hear", "bite"],
	"eel": ["latch", "zap"],
	"echo": ["lure", "strike", "reveal"],
}
const PATH: Array[Vector2] = [Vector2(4.0, 80.0), Vector2(20.0, 22.5), Vector2(33.0, -22.0)]
const FLOOR := 7.0
const SPEED := 5.0
const DT := 1.0 / 30.0
const DARK := 30.0
const STOP := 25.0
## Предел прохода после тёмной стоянки, с.
const LIMIT := 120.0
static var limit := LIMIT
## Тёмная стоянка этого прогона, с (`dark=`, по умолчанию DARK; короче 20 с — пауза хищников не кончилась, только для
## проверки инструмента).
static var dark := DARK
## Переносы домов радужников этого прогона: номер → (x, z).
static var moves := {}
## Проба тихого круга серпохвоста #1400 (`EcoPred.probe`, `probe=1`).
static var probe := false
## Ответ экипажа (`answer=1`, как `answer=alert` в tools/patrol.gd): услышав «замер» серпохвоста, через `delay=` с
## (по умолчанию DELAY — реакция людей) гасит свет и стоит без хода `hold=` с (HOLD), затем свет и путь дальше.
const DELAY := 1.5
const HOLD := 25.0
static var answer := false
static var delay := DELAY
static var hold := HOLD
## Старт серпохвоста №0 этого прогона (`start0=`), не задан — INF: как в игре.
static var start0 := Vector2.INF
## Полоса целей патруля №0 у домов стай BAND_HOMES (`band0=`), пустая — как в игре.
const BAND_HOMES := [0, 1]
static var band0 := Rect2()
## Порядок событий середины (гейм-дизайнер, #1400, 12.11): свет → раскрытие волнолиста → видимая реакция моллюсков
## (раскрыт на `EcoFern.FEED_OPEN` — моллюски под листьями видны; «рыбы приплыли» — `EcoFern` "mollusk" у куртины
## прохода) → первый «замер» серпохвоста. Путь №0 — старт, затем точки раз в TRACK_EVERY с первые TRACK_FOR с после света.
## Стая, разброс которой печатает расчёт (`fish=`), и подъём дома над дном (как `tools/quiet_map.gd`).
const WATCH_SHOAL := 0
const HOME_LIFT := 3.5
## Переносы домов стай рифа этого прогона: номер → (x, z).
static var fish_moves := {}
const TRACK_EVERY := 5.0
const TRACK_FOR := 60.0


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var seeds := int(kv.get("seeds", "16"))
	limit = float(kv.get("lim", str(LIMIT)))
	dark = float(kv.get("dark", str(DARK)))
	probe = kv.get("probe", "0") == "1"
	answer = kv.get("answer", "0") == "1"
	delay = float(kv.get("delay", str(DELAY)))
	hold = float(kv.get("hold", str(HOLD)))
	if kv.has("start0"):
		var xz: PackedStringArray = kv["start0"].split(",")
		start0 = Vector2(float(xz[0]), float(xz[1]))
	if kv.has("band0"):
		band0 = parse_band(kv["band0"])
	if kv.has("raduzh"):
		moves = parse_moves(kv["raduzh"])
	if kv.has("fish"):
		fish_moves = parse_moves(kv["fish"])
	for line in report(seeds):
		print(line)
	quit()


## "1:80,5;2:-70,-60" → {1: (80, 5), 2: (−70, −60)}.
static func parse_moves(s: String) -> Dictionary:
	var out := {}
	for part in s.split(";", false):
		var kz := part.split(":")
		var xz := kz[1].split(",")
		out[int(kz[0])] = Vector2(float(xz[0]), float(xz[1]))
	return out


## "-75,-45,20,76" → Rect2 x −75…−45, z 20…76.
static func parse_band(s: String) -> Rect2:
	var v := s.split(",")
	var x0 := float(v[0])
	var z0 := float(v[2])
	return Rect2(x0, z0, float(v[1]) - x0, float(v[3]) - z0)


## Ближе всего отрезок a–b (x, z) к пути середины PATH[0] → PATH[1], м.
static func to_mid_path(a: Vector2, b: Vector2) -> float:
	var c := Geometry2D.get_closest_points_between_segments(a, b, PATH[0], PATH[1])
	return c[0].distance_to(c[1])


static func ship_at(xz: Vector2) -> Vector3:
	return Vector3(xz.x, Seabed.mesh_height(xz.x, xz.y) + FLOOR, xz.y)


static func make(seed_value: int) -> EcoView:
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	if not moves.is_empty():
		var homes: Array[Vector2] = EcoRaduzh.HOMES.duplicate()
		for k in moves:
			homes[k] = moves[k]
		ev.raduzh._homes = homes
	for k in fish_moves:
		var xz: Vector2 = fish_moves[k]
		ev.fish.home_at[k] = Vector3(xz.x, Seabed.height(xz.x, xz.y) + HOME_LIFT, xz.y)
	ev.preds.probe = probe
	if band0.has_area():
		ev.preds.home_band = {0: {"homes": BAND_HOMES, "rect": band0}}
	ev.world.reset(seed_value)
	if start0.is_finite():
		move_pred(ev.preds.all[0], start0)
	return ev


## Серпохвост pr — со старта xz, как если бы он стоял там в `EcoPred.STARTS` (высота — как в `EcoPred.reset`).
static func move_pred(pr: EcoPred.Pred, xz: Vector2) -> void:
	var p := Vector3(xz.x, minf(Seabed.mesh_height(xz.x, xz.y) + 8.0, EcoPred.GOAL_CEILING), xz.y)
	pr.agent.p = p
	pr.start = p


## Событие шины — угроза в слышимости экипажа: «вид:заметка», иначе "".
static func threat_key(e: EcoBus.Event, ship: Vector3) -> String:
	if e.note in (THREATS.get(e.species, []) as Array) and e.pos.distance_to(ship) <= EcoBus.HEARING:
		return "%s:%s" % [e.species, e.note]
	return ""


## Один проход: {fern_t, flare (стая → {t, d}), betray_mid, betray_01, threat_mid/threat_01 («вид:заметка» → раз),
## pred_mid (ближе всего серпохвост к кораблю в середине, м)}.
static func run(seed_value: int) -> Dictionary:
	var ev := make(seed_value)
	var w := ev.world
	var ship := EcoLink.ShipState.new()
	ship.pos = ship_at(PATH[0])
	ship.light_on = false
	ship.speed = 0.0
	var born: Vector3 = ev.preds.all[0].agent.p
	var t := 0.0
	var goals: Array = []   # цели патруля №0 (x, z) по порядку, с первой после сброса мира
	var path0 := {"near": INF, "hunt": 0.0}  # №0 ближе всего к пути середины (x, z) и секунд охоты на рыб, пока корабль в середине
	var was := {"mode": ev.preds.all[0].mode, "goal": ev.preds.all[0].agent.goal}
	# Цель выбрана патрулем — сменилась, когда №0 и до шага, и после шага в PATROL (цель охоты или «замера»,
	# оставшаяся при возврате в патруль, — не выбор цели).
	var track := func() -> void:
		var pr: EcoPred.Pred = ev.preds.all[0]
		if pr.mode == EcoPred.Mode.PATROL and was["mode"] == EcoPred.Mode.PATROL \
				and (was["goal"] as Vector3).distance_to(pr.agent.goal) > 0.01:
			goals.append(Vector2(pr.agent.goal.x, pr.agent.goal.z))
		was["mode"] = pr.mode
		was["goal"] = pr.agent.goal
	# Стая WATCH_SHOAL и погони (`fish=`): весь проход, и в тёмные секунды у 00.
	var spread := {"far": 0.0, "exit": INF, "path": INF, "hunt_exit": INF, "hunt_path": INF, "prey": {}}
	var flock: Array[EcoFish.Fish] = []
	for f in ev.fish.all:
		if f.shoal.index == WATCH_SHOAL:
			flock.append(f)
	var home_w: Vector3 = ev.fish.shoals[WATCH_SHOAL].home
	var watch := func() -> void:
		for f in flock:
			var q := Vector2(f.agent.p.x, f.agent.p.z)
			spread["far"] = maxf(spread["far"], q.distance_to(Vector2(home_w.x, home_w.z)))
			spread["exit"] = minf(spread["exit"], q.distance_to(PATH[0]))
			spread["path"] = minf(spread["path"], to_mid_path(q, q))
		for pr in ev.preds.all:
			if pr.mode != EcoPred.Mode.HUNT:
				continue
			var q := Vector2(pr.agent.p.x, pr.agent.p.z)
			spread["hunt_exit"] = minf(spread["hunt_exit"], q.distance_to(PATH[0]))
			spread["hunt_path"] = minf(spread["hunt_path"], to_mid_path(q, q))
			if pr.prey != null:
				var who: Dictionary = spread["prey"]
				var key := "№%d→%d" % [pr.index, pr.prey.shoal.index]
				who[key] = who.get(key, 0) + 1
	while t < dark:
		w.ship = ship
		w.step(DT)
		w.take_link()
		t += DT
		track.call()
		watch.call()
		if ev.preds.all[0].mode == EcoPred.Mode.HUNT:
			path0["hunt"] += DT
		var q := Vector2(ev.preds.all[0].agent.p.x, ev.preds.all[0].agent.p.z)
		path0["near"] = minf(path0["near"], to_mid_path(q, q))
	ship.light_on = true
	ship.light_range = Searchlight.BASE_RANGE
	var mode_lit: String = EcoPred.Mode.keys()[ev.preds.all[0].mode]
	var r := {"mode0_lit": mode_lit, "fern_t": -1.0, "flare": {}, "betray_mid": 0, "betray_01": 0, "threat_mid": {}, "threat_01": {},
		"pred_mid": INF, "answers": 0, "mollusk_t": -1.0, "alert_t": -1.0, "alert_who": -1, "alert_d": 0.0,
		"track0": [], "near0": INF, "near0_t": 0.0, "lit_t": -1.0, "born0": Vector2(born.x, born.z),
		"fish_t": -1.0}
	var heard: Array = []   # [«вид:заметка», расстояние до корабля] за шаг
	var listen := func(e: EcoBus.Event) -> void:
		if e.species == EcoFern.ID and e.note == "mollusk" and r["fish_t"] < 0.0 \
				and Vector2(e.pos.x, e.pos.z).distance_to(EcoFern.ROUTE_CLUSTER) < 6.0:
			r["fish_t"] = w.time - dark
		var k := threat_key(e, w.ship.pos)
		if k != "":
			heard.append([k, e.pos.distance_to(w.ship.pos)])
	w.bus.emitted.connect(listen)
	var leg := 1
	var stop := STOP
	var cue := -1.0     # когда экипаж услышал «замер» (ответ через delay)
	var hushed := -1.0  # с какого времени стоит без света и хода
	var mid := true
	var lit := {}
	while leg < PATH.size() and t < dark + limit:
		var tg := PATH[leg]
		var d := Vector2(tg.x - ship.pos.x, tg.y - ship.pos.z)
		if cue >= 0.0 and t - cue >= delay - DT * 0.5:
			cue = -1.0
			hushed = t
			r["answers"] += 1
		if hushed >= 0.0 and t - hushed >= hold:
			hushed = -1.0
		ship.light_on = hushed < 0.0
		if hushed >= 0.0:
			ship.speed = 0.0
		elif d.length() < 0.5 and leg == 1 and stop > 0.0:
			stop -= DT
			ship.speed = 0.0
		elif d.length() < 0.5:
			leg += 1
			mid = false
			continue
		else:
			ship.yaw = atan2(-d.x, -d.y)
			ship.speed = SPEED
			var mv := d.normalized() * minf(SPEED * DT, d.length())
			ship.pos = ship_at(Vector2(ship.pos.x + mv.x, ship.pos.z + mv.y))
		w.ship = ship
		heard.clear()
		w.step(DT)
		t += DT
		var got: Dictionary = r["threat_mid" if mid else "threat_01"]
		for e in w.take_link():
			if e["type"] == EcoLink.OBSERVE and e.get("species", "") == EcoRaduzh.ID and e.get("note", "") == "betray":
				r["betray_mid" if mid else "betray_01"] += 1
			elif e["type"] == EcoLink.HIT or e["type"] == EcoLink.DRAIN:
				heard.append(["%s:%s" % [e["by"], e["type"]], 0.0])
		track.call()
		watch.call()
		var p0: EcoPred.Pred = ev.preds.all[0]
		var d0 := p0.agent.p.distance_to(ship.pos)
		if mid:
			if p0.mode == EcoPred.Mode.HUNT:
				path0["hunt"] += DT
			var q0 := Vector2(p0.agent.p.x, p0.agent.p.z)
			path0["near"] = minf(path0["near"], to_mid_path(q0, q0))
		if d0 < r["near0"]:
			r["near0"] = d0
			r["near0_t"] = t - dark
		if t - dark <= TRACK_FOR + DT * 0.5 and (r["track0"] as Array).size() < int((t - dark) / TRACK_EVERY + 1e-4) + 1:
			(r["track0"] as Array).append([Vector2(p0.agent.p.x, p0.agent.p.z), d0])
		for pr in ev.preds.all:
			var dp := pr.agent.p.distance_to(ship.pos)
			if pr.mode == EcoPred.Mode.ALERT and r["alert_t"] < 0.0:
				r["alert_t"] = t - dark
				r["alert_who"] = pr.index
				r["alert_d"] = dp
			if pr.mode == EcoPred.Mode.ALERT or pr.mode == EcoPred.Mode.CHARGE:
				heard.append(["pred%d:%s" % [pr.index, EcoPred.Mode.keys()[pr.mode].to_lower()], dp])
			if mid:
				r["pred_mid"] = minf(r["pred_mid"], dp)
		for h in heard:
			if answer and h[0] == "pred:alert" and cue < 0.0 and hushed < 0.0:
				cue = t
			if not got.has(h[0]):
				got[h[0]] = {"n": 0, "t": t - dark, "d": h[1]}
			got[h[0]]["n"] += 1
		if r["fern_t"] < 0.0:
			for fe in ev.ferns.ferns:
				if Vector2(fe.pos.x, fe.pos.z).distance_to(EcoFern.ROUTE_CLUSTER) >= 6.0:
					continue
				if fe.lit and r["lit_t"] < 0.0:
					r["lit_t"] = t - dark
				if fe.open > EcoFern.FEED_OPEN:
					r["fern_t"] = t - dark
					r["mollusk_t"] = t - dark   # раскрыт на FEED_OPEN — моллюски под листьями видны
		if mid:
			for sw in ev.raduzh.swarms:
				if sw.glow > EcoRaduzh.FLARE_ON and not lit.has(sw.index):
					lit[sw.index] = {"t": t - dark, "d": sw.c.distance_to(ship.pos)}
	r["flare"] = lit
	r["goals0"] = goals
	r["path0"] = path0["near"]
	r["hunt0"] = path0["hunt"]
	r["spread"] = spread
	w.bus.emitted.disconnect(listen)
	ev.free()
	return r


static func report(seeds: int) -> Array[String]:
	var lines: Array[String] = []
	var homes: Array[Vector2] = EcoRaduzh.HOMES.duplicate()
	for k in moves:
		homes[k] = moves[k]
	var band := ("цели №0 у стай %s — x %.0f…%.0f, z %.0f…%.0f" % [str(BAND_HOMES), band0.position.x, band0.end.x, band0.position.y, band0.end.y]) if band0.has_area() else "цели №0 как в игре"
	var fh: Array[Vector3] = EcoFish.HOMES.duplicate()
	for k in fish_moves:
		fh[k] = Vector3(fish_moves[k].x, 0.0, fish_moves[k].y)
	lines.append("== дома радужников %s, старт серпохвоста №0 %s, %s, тихий круг серпохвоста %s, ответ экипажа %s, %d зёрен, путь %s, стоянка %.0f с у середины" % [str(homes), str(start0 if start0.is_finite() else EcoPred.STARTS[0]), band, "вкл" if probe else "выкл", ("через %.1f с, %.0f с без света" % [delay, hold]) if answer else "нет", seeds, str(PATH), STOP])
	lines.append("== дом стаи светляков %d (%.0f; %.0f), тёмная стоянка %.0f с" % [WATCH_SHOAL, fh[WATCH_SHOAL].x, fh[WATCH_SHOAL].z, dark])
	for k in fish_moves:
		lines.append(site_line("перенос стаи %d" % k, fish_moves[k]))
		lines.append(site_line("прежний дом стаи %d" % k, Vector2(EcoFish.HOMES[k].x, EcoFish.HOMES[k].z)))
	var order := {"done": 0, "mollusk": [], "alert": [], "near0": [], "goal": [], "seg": [], "path0": []}
	var sp := {"far": [], "exit": [], "path": [], "hunt_exit": [], "hunt_path": [], "prey": {}, "exit20": 0}
	var fern := 0
	var flared := {}
	var betray_mid := 0
	var betray_01 := 0
	var threats_mid := {}
	var threats_01 := {}
	var pred_near := INF
	for s in seeds:
		var r := run(20261018 + s * 7919)
		var parts: Array[String] = []
		if r["fern_t"] >= 0.0:
			fern += 1
			parts.append("волнолист раскрыт на %.1f с" % r["fern_t"])
		else:
			parts.append("волнолист у прохода не раскрылся")
		for k in r["flare"]:
			flared[k] = flared.get(k, 0) + 1
			parts.append("стая %d вспыхнула на %.1f с в %.0f м" % [k, r["flare"][k]["t"], r["flare"][k]["d"]])
		if r["betray_mid"] > 0:
			betray_mid += 1
			parts.append("зов хищника в середине ×%d" % r["betray_mid"])
		if r["betray_01"] > 0:
			betray_01 += 1
		for side in ["mid", "01"]:
			var got: Dictionary = r["threat_" + side]
			var tot: Dictionary = threats_mid if side == "mid" else threats_01
			if not got.is_empty():
				parts.append("угрозы %s: %s" % ["в середине" if side == "mid" else "у 01", _keys(got)])
			for k in got:
				tot[k] = tot.get(k, 0) + 1
		pred_near = minf(pred_near, r["pred_mid"])
		if r["answers"] > 0:
			parts.append("ответов %d" % r["answers"])
		parts.append(chain_line(r))
		var gs := goal_stats(r)
		parts.append(goal_line(gs))
		var rs: Dictionary = r["spread"]
		parts.append(spread_line(rs))
		for k in ["far", "exit", "path", "hunt_exit", "hunt_path"]:
			if is_finite(rs[k]):
				sp[k].append(rs[k])
		if rs["hunt_exit"] < EXIT_NEAR:
			sp["exit20"] += 1
		for k in rs["prey"]:
			sp["prey"][k] = sp["prey"].get(k, 0) + 1
		order["goal"].append(gs["goal"])
		order["seg"].append(gs["seg"])
		order["path0"].append(r["path0"])
		if chain_done(r):
			order["done"] += 1
		if r["mollusk_t"] >= 0.0:
			order["mollusk"].append(r["mollusk_t"])
		if r["alert_t"] >= 0.0:
			order["alert"].append(r["alert_t"])
		order["near0"].append(r["near0"])
		lines.append("  зерно %d: %s" % [s, ", ".join(parts)])
	var fl: Array[String] = []
	for k in homes.size():
		fl.append("стая %d — %d/%d" % [k, flared.get(k, 0), seeds])
	lines.append("итог: волнолист %d/%d; вспышки в середине: %s; зов хищника вспышкой в середине %d/%d, на подходе к 01 %d/%d" \
		% [fern, seeds, ", ".join(fl), betray_mid, seeds, betray_01, seeds])
	lines.append("угрозы в середине (зёрен из %d): %s; серпохвост ближе всего %.0f м" \
		% [seeds, _keys(threats_mid) if not threats_mid.is_empty() else "нет", pred_near])
	lines.append("угрозы на подходе к 01 (зёрен из %d): %s" % [seeds, _keys(threats_01) if not threats_01.is_empty() else "нет"])
	lines.append("порядок: моллюски до первого «замера» %d/%d; реакция моллюсков %s; первый «замер» %s; №0 ближе всего (медиана) %.0f м" \
		% [order["done"], seeds, _spread(order["mollusk"], seeds), _spread(order["alert"], seeds), _median(order["near0"])])
	lines.append("путь середины %s → %s: ближе всего цель №0 %s; отрезок между целями %s; сам №0, пока корабль в середине, %s" \
		% [str(PATH[0]), str(PATH[1]), _metres(order["goal"]), _metres(order["seg"]), _metres(order["path0"])])
	lines.append("стая %d: дальше всего от дома %s; ближе всего к выходу 00 %s, к пути середины %s" \
		% [WATCH_SHOAL, _metres_max(sp["far"]), _metres(sp["exit"]), _metres(sp["path"])])
	lines.append("погони (HUNT, все серпохвосты): ближе всего к выходу 00 %s (ближе %.0f м — %d/%d зёрен), к пути середины %s; кто → стая (зёрен): %s" \
		% [_metres(sp["hunt_exit"]), EXIT_NEAR, sp["exit20"], seeds, _metres(sp["hunt_path"]), _keys(sp["prey"]) if not sp["prey"].is_empty() else "погонь нет"])
	return lines


## Среда у дома (уровни, #1400, 12.11: «проверить грунт/кораллы и свободный объём стаи»): глубина дна, вода до льда,
## уклон и грунт [песок, ил, галька] (`Seabed.Ground.weights`), ближайший куст огнецвета (`EcoCoral.BASES`) и что из
## живого мира стоит ближе SITE_R м (объекты систем с полем pos — счёт по системам, мир зерна 20261018).
const SITE_R := 25.0
static func site_line(label: String, xz: Vector2) -> String:
	var y := Seabed.mesh_height(xz.x, xz.y)
	var e := 1.0
	var n := Vector3(Seabed.mesh_height(xz.x - e, xz.y) - Seabed.mesh_height(xz.x + e, xz.y), 2.0 * e,
		Seabed.mesh_height(xz.x, xz.y - e) - Seabed.mesh_height(xz.x, xz.y + e)).normalized()
	var w: Array = Seabed.Ground.weights(xz.x, xz.y, n.y, -y)
	var bush := INF
	for b in EcoCoral.BASES:
		bush = minf(bush, b.distance_to(xz))
	var rough := 0.0   # перепад дна в круге 15 м, м
	for k in 16:
		var a := TAU * k / 16.0
		var q := xz + Vector2(cos(a), sin(a)) * 15.0
		rough = maxf(rough, absf(Seabed.mesh_height(q.x, q.y) - y))
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	ev.world.reset(20261018)
	var near := {}
	for sys in ev.world.systems:
		for prop in sys.get_property_list():
			if prop["type"] != TYPE_ARRAY:
				continue
			var arr = sys.get(prop["name"])
			if not (arr is Array):
				continue
			for it in arr:
				if not (it is Object) or not ("pos" in it):
					continue
				var pv = it.get("pos")
				var q2: Vector2 = Vector2(pv.x, pv.z) if pv is Vector3 else (pv as Vector2 if pv is Vector2 else Vector2.INF)
				if q2.distance_to(xz) < SITE_R:
					var key := "%s.%s" % [sys.get_script().get_global_name(), prop["name"]]
					near[key] = near.get(key, 0) + 1
	ev.free()
	return "== %s (%.0f; %.0f): дно %.1f м, уклон %.2f, перепад в 15 м %.1f м, грунт песок %.2f / ил %.2f / галька %.2f, огнецвет в %.0f м; ближе %.0f м: %s" \
		% [label, xz.x, xz.y, y, 1.0 - n.y, rough, w[0], w[1], w[2], bush, SITE_R, _keys(near) if not near.is_empty() else "ничего"]


## Погоня ближе EXIT_NEAR м к выходу 00 — «охота через выход» в итоге.
const EXIT_NEAR := 20.0


## «стая 0: до 22 м от дома, к выходу 00 9 м, к пути середины 12 м; погони: к выходу 4 м, к пути 3 м (№0→0 ×120)».
static func spread_line(rs: Dictionary) -> String:
	return "стая %d: до %.0f м от дома, к выходу 00 %.0f м, к пути середины %.0f м; погони: к выходу %s, к пути %s (кадров погони: %s)" \
		% [WATCH_SHOAL, rs["far"], rs["exit"], rs["path"], ("%.0f м" % rs["hunt_exit"]) if is_finite(rs["hunt_exit"]) else "нет",
		("%.0f м" % rs["hunt_path"]) if is_finite(rs["hunt_path"]) else "нет", _keys(rs["prey"]) if not rs["prey"].is_empty() else "погонь нет"]


## «макс 30 м, медиана 22 м» по зёрнам.
static func _metres_max(v: Array) -> String:
	var s := v.duplicate()
	s.sort()
	return "макс %.0f м, медиана %.0f м" % [s[-1], _median(s)] if not s.is_empty() else "нет"


## «мин 12 м, медиана 40 м» по зёрнам.
static func _metres(v: Array) -> String:
	var s := v.duplicate()
	s.sort()
	return "мин %.0f м, медиана %.0f м" % [s[0], _median(s)] if not s.is_empty() else "нет"


## Цели патруля №0 прохода r против пути середины: {n, band (в полосе band0), goal, seg — ближе всего цель и отрезок
## между соседними целями к пути PATH[0] → PATH[1], м; seg_at — номер цели, с которой начинается ближний отрезок}.
static func goal_stats(r: Dictionary) -> Dictionary:
	var gl: Array = r["goals0"]
	var out := {"n": gl.size(), "band": 0, "goal": INF, "seg": INF, "seg_at": -1}
	for k in gl.size():
		var g: Vector2 = gl[k]
		if band0.has_area() and band0.grow(0.01).has_point(g):
			out["band"] += 1
		out["goal"] = minf(out["goal"], to_mid_path(g, g))
		if k > 0:
			var d := to_mid_path(gl[k - 1], g)
			if d < out["seg"]:
				out["seg"] = d
				out["seg_at"] = k - 1
	return out


## «цели №0: 9 (в полосе 4), ближе к пути середины: цель 51 м, отрезок 3 м (цели 2→3), сам №0 18 м».
static func goal_line(gs: Dictionary) -> String:
	var seg := ("отрезок %.0f м (цели %d→%d)" % [gs["seg"], gs["seg_at"], gs["seg_at"] + 1]) if gs["seg_at"] >= 0 else "отрезков нет"
	return "цели №0: %d (в полосе %d), ближе к пути середины: цель %.0f м, %s" % [gs["n"], gs["band"], gs["goal"], seg]


## Наблюдение цепочки закончено до вынужденного ответа: моллюски показались, а «замера» не было или он позже.
static func chain_done(r: Dictionary) -> bool:
	return r["mollusk_t"] >= 0.0 and (r["alert_t"] < 0.0 or r["mollusk_t"] < r["alert_t"])


## «свет 0 → луч на волнолисте 2,0 с → моллюски видны 3,1 с (рыбы нет) → замер №0 12,0 с в 30 м; путь №0: старт
## (−60; 20), 0 с (−18; 13) 70 м, …; №0 ближе всего 4 м на 20,1 с».
static func chain_line(r: Dictionary) -> String:
	var t := "свет 0 → луч на волнолисте %s → моллюски видны %s (рыбы %s) → замер %s" % [_t(r["lit_t"]),
		_t(r["mollusk_t"]), _t(r["fish_t"]),
		("№%d %.1f с в %.0f м" % [r["alert_who"], r["alert_t"], r["alert_d"]]) if r["alert_t"] >= 0.0 else "нет"]
	var tr: Array[String] = ["старт (%.0f; %.0f)" % [r["born0"].x, r["born0"].y]]
	for k in (r["track0"] as Array).size():
		var pt: Array = r["track0"][k]
		tr.append("%d с (%.0f; %.0f) %.0f м" % [roundi(k * TRACK_EVERY), pt[0].x, pt[0].y, pt[1]])
	return t + "; путь №0 (при свете — %s): " % r.get("mode0_lit", "?") + ", ".join(tr) \
		+ "; №0 ближе всего %.0f м на %.1f с, к пути середины %.0f м, охота на рыб %.0f с" % [r["near0"], r["near0_t"], r.get("path0", INF), r.get("hunt0", 0.0)]


static func _t(v: float) -> String:
	return "%.1f с" % v if v >= 0.0 else "нет"


## «в 12/16, 3,1–9,8 с, медиана 5,2 с».
static func _spread(v: Array, seeds: int) -> String:
	if v.is_empty():
		return "в 0/%d" % seeds
	var s := v.duplicate()
	s.sort()
	return "в %d/%d, %.1f–%.1f с, медиана %.1f с" % [s.size(), seeds, s[0], s[-1], _median(s)]


static func _median(v: Array) -> float:
	if v.is_empty():
		return INF
	var s := v.duplicate()
	s.sort()
	var m := s.size() / 2
	return float(s[m]) if s.size() % 2 == 1 else (float(s[m - 1]) + float(s[m])) * 0.5


## {ключ → раз} или {ключ → {n, t, d}} строкой: «ключ ×n» или «ключ ×n с t с в d м» (для режима — кадров).
static func _keys(d: Dictionary) -> String:
	var out: Array[String] = []
	for k in d:
		var v = d[k]
		if v is Dictionary:
			out.append("%s ×%d с %.1f с в %.0f м" % [k, v["n"], v["t"], v["d"]])
		else:
			out.append("%s ×%d" % [k, v])
	return ", ".join(out)
