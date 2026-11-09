extends SceneTree
class_name QuietMap
## Где на существующем проходе 00 → 01 есть тихое место для спокойного наблюдения (#1400, ответ гейм-дизайнера
## 09.11): мир целиком (`EcoView`, дно `Seabed.mesh_height`), headless, корабль далеко — хищников он не зовёт. По
## точкам пути через 5 м — доля времени, когда хоть один серпохвост ближе SEE м (видит свет корабля, `EcoPred`), и
## кто. Варианты — дома стай рифа на месте и перенос ближайших домов к существующим рифам (`EcoFish.home_at`,
## кораллы `EcoCoral.BASES`). Чувства, скорости и патруль не меняются. Облачный расчёт, не телефонный.
## Первые warm с мира не считаются: стартовая пауза хищников (20 с) и их места появления — не обычный ход отмели.
##   godot --headless --path . -s tools/quiet_map.gd [-- seeds=8 time=300 warm=60 csv=<файл>]

const DT := 1.0 / 30.0
const STEP := DT * 3.0
const SEE := 32.0
const FLOOR := 7.0
## Путь: выход из 00 → середина → подход к 01 (точки `scena=`, tools/shot_setup.gd), как tools/patrol.gd.
const PATH: Array[Vector2] = [Vector2(4.0, 80.0), Vector2(20.0, 22.5), Vector2(33.0, -22.0)]
const EVERY := 5.0
## Дом стаи на столько выше дна (EcoFish.HOMES — 3,5 м над Seabed.height).
const HOME_LIFT := 3.5


## Куда переносить дом стаи рифа (номер → существующий риф EcoCoral.BASES): стаю (56; 6) — к рифу (55; −69) к
## юго-востоку от 01, стаю (−26; 24) — к рифу (−57; 23) к западу от середины.
const REEF_FOR := {4: EcoCoral.BASES[2], 1: EcoCoral.BASES[0]}


## Варианты: имя → {номер стаи: куда (x; z)}.
static func variants() -> Array[Dictionary]:
	var reef_se: Vector2 = REEF_FOR[4]
	var reef_w: Vector2 = REEF_FOR[1]
	return [
		{"name": "как есть", "move": {}},
		{"name": "стая (56;6) → риф (55;−69)", "move": {4: reef_se}},
		{"name": "стая (56;6) → риф (55;−69), стая (−26;24) → риф (−57;23)", "move": {4: reef_se, 1: reef_w}},
	]


## Точки пути через EVERY м; вне кольца рифа 01 (там хищник не бывает и стоянки нет).
static func route_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in PATH.size() - 1:
		var a := PATH[i]
		var b := PATH[i + 1]
		var n := maxi(1, int(a.distance_to(b) / EVERY))
		for k in n + (1 if i == PATH.size() - 2 else 0):
			out.append(a.lerp(b, float(k) / n))
	return out


static func home_of(xz: Vector2) -> Vector3:
	return Vector3(xz.x, Seabed.height(xz.x, xz.y) + HOME_LIFT, xz.y)


## Доли времени по точкам: [{"p": Vector2, "any": 0…1, "who": [три доли]}].
static func measure(move: Dictionary, seeds: int, time: float, warm := 0.0) -> Array[Dictionary]:
	var pts := route_points()
	var hit: Array[int] = []
	var who: Array = []
	hit.resize(pts.size())
	for i in pts.size():
		who.append([0, 0, 0])
	var total := 0
	for s in seeds:
		var ev := EcoView.new()
		ev.ground = Seabed.mesh_height
		for k in move:
			ev.fish.home_at[k] = home_of(move[k])
		ev.world.reset(20261018 + s * 7919)
		var ship := EcoLink.ShipState.new()
		ship.pos = Vector3(-150, Seabed.mesh_height(-150, 150) + FLOOR, 150)
		for t in int((warm + time) / STEP):
			ev.world.ship = ship
			ev.world.step(STEP)
			ev.world.take_link()
			if t * STEP < warm:
				continue
			total += 1
			for i in pts.size():
				var any := false
				for pr in ev.preds.all:
					var p := pr.agent.p
					if Vector2(p.x, p.z).distance_to(pts[i]) < SEE:
						any = true
						who[i][pr.index] += 1
				hit[i] += 1 if any else 0
		ev.free()
	var out: Array[Dictionary] = []
	for i in pts.size():
		out.append({"p": pts[i], "any": float(hit[i]) / total,
			"who": [float(who[i][0]) / total, float(who[i][1]) / total, float(who[i][2]) / total]})
	return out


static func fmt(r: Dictionary) -> String:
	var p: Vector2 = r["p"]
	return "(%d; %d) %d %% (№0 %d, №1 %d, №2 %d)" % [roundi(p.x), roundi(p.y), roundi(100.0 * r["any"]),
		roundi(100.0 * r["who"][0]), roundi(100.0 * r["who"][1]), roundi(100.0 * r["who"][2])]


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var seeds := int(kv.get("seeds", "8"))
	var time := float(kv.get("time", "300"))
	var warm := float(kv.get("warm", "60"))
	var lines: Array[String] = []
	for v in variants():
		var rows := measure(v["move"], seeds, time, warm)
		lines.append("== %s (%d зёрен × %d с после %d с), хищник ближе %d м — доля времени по точкам пути 00 → 01:" % [
			v["name"], seeds, int(time), int(warm), int(SEE)])
		var best := rows[0]
		for r in rows:
			lines.append("  " + fmt(r))
			if float(r["any"]) < float(best["any"]):
				best = r
		lines.append("  самая тихая точка: " + fmt(best))
		print("\n".join(lines.slice(lines.size() - rows.size() - 2)))
	if kv.has("csv"):
		var f := FileAccess.open(kv["csv"], FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
	quit()
