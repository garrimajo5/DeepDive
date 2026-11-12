extends SceneTree
## Спокойная середина 00 → 01 (#1400): что ещё зажигает луч, пока экипаж смотрит цепочку «прожектор → волнолист →
## моллюски». Гейм-дизайнер (08.11): в середине не накладывать зов хищника гребневиками. Мир целиком (`EcoView`, дно
## `Seabed.mesh_height`), headless, без узлов сцены; облачный расчёт, не телефонный.
##   godot --headless --path . -s tools/mid_calm.gd [-- seeds=16 raduzh=1:80,5 lim=<с> dark=<с> probe=1 answer=1 delay=<с> hold=<с>]
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
	if kv.has("raduzh"):
		moves = parse_moves(kv["raduzh"])
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
	ev.preds.probe = probe
	ev.world.reset(seed_value)
	return ev


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
	var t := 0.0
	while t < dark:
		w.ship = ship
		w.step(DT)
		w.take_link()
		t += DT
	ship.light_on = true
	ship.light_range = Searchlight.BASE_RANGE
	var r := {"fern_t": -1.0, "flare": {}, "betray_mid": 0, "betray_01": 0, "threat_mid": {}, "threat_01": {},
		"pred_mid": INF, "answers": 0}
	var heard: Array = []   # [«вид:заметка», расстояние до корабля] за шаг
	var listen := func(e: EcoBus.Event) -> void:
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
		for pr in ev.preds.all:
			var dp := pr.agent.p.distance_to(ship.pos)
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
				if fe.open > EcoFern.FEED_OPEN and Vector2(fe.pos.x, fe.pos.z).distance_to(EcoFern.ROUTE_CLUSTER) < 6.0:
					r["fern_t"] = t - dark
		if mid:
			for sw in ev.raduzh.swarms:
				if sw.glow > EcoRaduzh.FLARE_ON and not lit.has(sw.index):
					lit[sw.index] = {"t": t - dark, "d": sw.c.distance_to(ship.pos)}
	r["flare"] = lit
	w.bus.emitted.disconnect(listen)
	ev.free()
	return r


static func report(seeds: int) -> Array[String]:
	var lines: Array[String] = []
	var homes: Array[Vector2] = EcoRaduzh.HOMES.duplicate()
	for k in moves:
		homes[k] = moves[k]
	lines.append("== дома радужников %s, тихий круг серпохвоста %s, ответ экипажа %s, %d зёрен, путь %s, стоянка %.0f с у середины" % [str(homes), "вкл" if probe else "выкл", ("через %.1f с, %.0f с без света" % [delay, hold]) if answer else "нет", seeds, str(PATH), STOP])
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
		lines.append("  зерно %d: %s" % [s, ", ".join(parts)])
	var fl: Array[String] = []
	for k in homes.size():
		fl.append("стая %d — %d/%d" % [k, flared.get(k, 0), seeds])
	lines.append("итог: волнолист %d/%d; вспышки в середине: %s; зов хищника вспышкой в середине %d/%d, на подходе к 01 %d/%d" \
		% [fern, seeds, ", ".join(fl), betray_mid, seeds, betray_01, seeds])
	lines.append("угрозы в середине (зёрен из %d): %s; серпохвост ближе всего %.0f м" \
		% [seeds, _keys(threats_mid) if not threats_mid.is_empty() else "нет", pred_near])
	lines.append("угрозы на подходе к 01 (зёрен из %d): %s" % [seeds, _keys(threats_01) if not threats_01.is_empty() else "нет"])
	return lines


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
