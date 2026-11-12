extends SceneTree
## Спокойная середина 00 → 01 (#1400): что ещё зажигает луч, пока экипаж смотрит цепочку «прожектор → волнолист →
## моллюски». Гейм-дизайнер (08.11): в середине не накладывать зов хищника гребневиками. Мир целиком (`EcoView`, дно
## `Seabed.mesh_height`), headless, без узлов сцены; облачный расчёт, не телефонный.
##   godot --headless --path . -s tools/mid_calm.gd [-- seeds=16 raduzh=1:80,5 lim=<с> dark=<с>]
## raduzh=<номер>:<x>,<z> — дом стаи радужников с этим номером на пробу в другом месте (`EcoRaduzh._homes` до сброса
## мира; несколько — через «;»). Проход как `late` в tools/patrol.gd: 30 с без света у 00 (пауза хищников после сброса
## кончилась), затем свет и ход 5 м/с по оси PATH на 7 м над дном, стоянка STOP с у середины, дальше к 01.
## Печатает по зерну и итогом: когда раскрылся волнолист у прохода, вспыхнула ли в середине стая радужников (какая,
## на каком расстоянии от корабля), «betray» — серпохвост заметил вспышку и плывёт к кораблю.
## «Середина» — от выхода из 00 до конца стоянки; дальше подход к 01 (там своя цепочка угрозы).

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


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var seeds := int(kv.get("seeds", "16"))
	limit = float(kv.get("lim", str(LIMIT)))
	dark = float(kv.get("dark", str(DARK)))
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
	ev.world.reset(seed_value)
	return ev


## Один проход: {fern_t, flare (стая → {t, d}), betray_mid, betray_01, mid_end}.
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
	var r := {"fern_t": -1.0, "flare": {}, "betray_mid": 0, "betray_01": 0}
	var leg := 1
	var stop := STOP
	var mid := true
	var lit := {}
	while leg < PATH.size() and t < dark + limit:
		var tg := PATH[leg]
		var d := Vector2(tg.x - ship.pos.x, tg.y - ship.pos.z)
		if d.length() < 0.5 and leg == 1 and stop > 0.0:
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
		w.step(DT)
		t += DT
		for e in w.take_link():
			if e["type"] == EcoLink.OBSERVE and e.get("species", "") == EcoRaduzh.ID and e.get("note", "") == "betray":
				r["betray_mid" if mid else "betray_01"] += 1
		if r["fern_t"] < 0.0:
			for fe in ev.ferns.ferns:
				if fe.open > EcoFern.FEED_OPEN and Vector2(fe.pos.x, fe.pos.z).distance_to(EcoFern.ROUTE_CLUSTER) < 6.0:
					r["fern_t"] = t - dark
		if mid:
			for sw in ev.raduzh.swarms:
				if sw.glow > EcoRaduzh.FLARE_ON and not lit.has(sw.index):
					lit[sw.index] = {"t": t - dark, "d": sw.c.distance_to(ship.pos)}
	r["flare"] = lit
	ev.free()
	return r


static func report(seeds: int) -> Array[String]:
	var lines: Array[String] = []
	var homes: Array[Vector2] = EcoRaduzh.HOMES.duplicate()
	for k in moves:
		homes[k] = moves[k]
	lines.append("== дома радужников %s, %d зёрен, путь %s, стоянка %.0f с у середины" % [str(homes), seeds, str(PATH), STOP])
	var fern := 0
	var flared := {}
	var betray_mid := 0
	var betray_01 := 0
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
		lines.append("  зерно %d: %s" % [s, ", ".join(parts)])
	var fl: Array[String] = []
	for k in homes.size():
		fl.append("стая %d — %d/%d" % [k, flared.get(k, 0), seeds])
	lines.append("итог: волнолист %d/%d; вспышки в середине: %s; зов хищника вспышкой в середине %d/%d, на подходе к 01 %d/%d" \
		% [fern, seeds, ", ".join(fl), betray_mid, seeds, betray_01, seeds])
	return lines
