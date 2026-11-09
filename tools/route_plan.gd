extends SceneTree
## Основной маршрут слоя 1 целиком (#1374, фокус потока Б 09.11): 00 → 01 → 07 → 03 → 06 → 10 прямыми между местами
## `LayerMap.MAIN_ROUTE` (точка 10 — (560, 200), 290 м), полный габарит корпуса по `HullPlan`. Headless, без узлов:
## дно `Seabed.mesh_height`, мир (`EcoView`) после сброса — высокая флора, как в tools/pass_plan.gd. Облачный расчёт,
## не телефонный. Ничего не переставляет — только отчёт для дизайнера уровней.
##   godot --headless --path . -s tools/route_plan.gd [-- seed=<n> json=<файл> route=full]
## route=full — полный исследовательский обход из схемы `docs/urovni/sloj-1.md` (`FULL_ROUTE`): транзиты 01 → 00 и
## 08 → 07 считаются отдельными отрезками (корпус несимметричен — нос и корма над разным грунтом).
## По каждому отрезку через STEP м: корпус на нижнем пределе хода (`Helm.Ship.CLEARANCE` над дном под центром) —
## насколько грунт под всем корпусом выше днища (до #1481 — корпус в грунте; теперь корабль сам держит всё днище
## над грунтом, `Helm.Ship.floor_at`, — это подъём хода над пределом по центру); поместится ли корпус над этим грунтом под льдом
## (`Helm.Ship.CEILING`); выход за край отмели вне прохода склона (`Helm.Ship.east_ok`) — корабль там не пройдёт;
## опоры арки 07 (`GateArch.hits`); грунт сбоку выше низа объёма 60×30 (как в pass_plan.gd); высокая флора в объёме.
## json= — то же для картинок (план слоя с сеткой дна GRID м и профили отрезков).

const Plan := preload("res://tools/pass_plan.gd")

## Корпус в осях корабля (нос в −Z): по `HullPlan` — носовой срез, корма, полуширина носовой оболочки, низ и верх.
const HULL_FRONT := HullPlan.NOSE_CUT
const HULL_BACK := HullPlan.BODY_Z + HullPlan.BODY_HALF
const HULL_HALF_W := HullPlan.NOSE_W * 0.5
const HULL_LOW := HullPlan.CENTER_Y - HullPlan.NOSE_H * 0.5
const HULL_TOP := HullPlan.CENTER_Y + HullPlan.NOSE_H * 0.5
const STEP := 5.0
const GRID := 10.0
## Ход в объёме 60×30 — корабль на этой высоте над грунтом оси (как в pass_plan.gd).
const FLOOR := Plan.FLOOR
## Флора ближе этого к концу отрезка — у самого места (сам ориентир, остановка), считается отдельно.
const END_R := 30.0
## Полный исследовательский обход по существующим связям (`docs/urovni/sloj-1.md`, «Бюджет»): повторные 00 и 07 —
## транзит.
const FULL_ROUTE: Array[String] = ["00", "01", "00", "09", "02", "05", "04", "07", "08", "07", "03", "06", "10"]


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	ev.world.reset(int(kv.get("seed", "20261018")))
	var flora := Plan.collect(ev)
	var full: bool = kv.get("route", "") == "full"
	var route: Array[String] = FULL_ROUTE if full else LayerMap.MAIN_ROUTE
	print("%s %s прямыми между местами LayerMap. Корпус %.1f × %.1f м, днище %.1f м от точки хода, верх +%.1f м." % [
			"Полный обход" if full else "Основной маршрут", " → ".join(route), HULL_BACK - HULL_FRONT, HULL_HALF_W * 2.0, HULL_LOW, HULL_TOP])
	print("Нижний предел хода — %.0f м над дном под центром, верхний — y = %.0f (лёд). Объём %.0f×%.0f м от грунта оси + %.0f м." % [
			Helm.Ship.CLEARANCE, Helm.Ship.CEILING, Plan.WIDTH, Plan.HEIGHT, Plan.LOW])
	var out := {"full": full, "route": [], "legs": [], "hull": [HULL_FRONT, HULL_BACK, HULL_HALF_W, HULL_LOW, HULL_TOP],
			"ceiling": Helm.Ship.CEILING, "grid": grid(), "grid_step": GRID}
	for id in route:
		var p := LayerMap.xz(id)
		out["route"].append([id, p.x, p.y, LayerMap.POINTS[id]["depth"], Seabed.mesh_height(p.x, p.y)])
	var total := 0.0
	for i in route.size() - 1:
		var leg := leg_report(route[i], LayerMap.xz(route[i]), route[i + 1], LayerMap.xz(route[i + 1]), flora)
		leg["transit"] = route.slice(0, i + 1).has(route[i + 1])   # место уже пройдено — обратный ход
		out["legs"].append(leg)
		print_leg(leg)
		total += leg["length"]
	print("\nСумма прямых: %.0f м (с 06 → 10 по прямой, которой нет)." % total)
	# Прямая 06 → 10 упирается в стену за краем отмели: для сравнения — через начало прохода склона (ось z = GAP_Z).
	var gap := Vector2(Seabed.Slope.X_IN, Seabed.Slope.GAP_Z)
	print("\nДля сравнения — 06 → 10 через начало прохода склона (%d; %d), не путь игры:" % [gap.x, gap.y])
	for leg in [leg_report("06", LayerMap.xz("06"), "проход", gap, flora), leg_report("проход", gap, "10", LayerMap.xz("10"), flora)]:
		leg["detour"] = true
		out["legs"].append(leg)
		print_leg(leg)
	if full:
		# Прямая 07 → 08 идёт вдоль западной опоры арки 07: для сравнения — сначала из прохода на сторону подхода (+Z).
		var out_gate := arch_exit()
		print("\nДля сравнения — 07 → 08 через выход из прохода арки на сторону подхода (%d; %d), не путь игры:" % [out_gate.x, out_gate.y])
		for leg in [leg_report("07", LayerMap.xz("07"), "выход арки", out_gate, flora),
				leg_report("выход арки", out_gate, "08", LayerMap.xz("08"), flora)]:
			leg["detour"] = true
			out["legs"].append(leg)
			print_leg(leg)
	if kv.has("json"):
		var f := FileAccess.open(kv["json"], FileAccess.WRITE)
		f.store_string(JSON.stringify(out))
	quit()


## Точка перед проходом арки 07 со стороны подхода (+Z): корпус, повёрнутый поперёк, уже не задевает опоры —
## полглубины арки, запас корпуса и полдлины корпуса.
static func arch_exit() -> Vector2:
	return EcoGate.CENTER + Vector2(0.0, GateArch.HALF_DEPTH + GateArch.SHIP_R + GateArch.SHIP_HALF_LEN)


## Отрезок a → b: станции и сводка помех.
static func leg_report(a_id: String, a: Vector2, b_id: String, b: Vector2, flora: Array[Dictionary]) -> Dictionary:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var stations: Array = []
	var s := 0.0
	while s <= length + 0.01:
		stations.append(station(a + dir * minf(s, length), dir, minf(s, length)))
		s += STEP
	var near: Array = []
	var right := Vector2(-dir.y, dir.x)
	for it in flora:
		var q := Vector2(it["x"], it["z"]) - a
		var along := q.dot(dir)
		var side := q.dot(right)
		if along < 0.0 or along > length or absf(side) - it["reach"] > Plan.WIDTH * 0.5:
			continue
		var gy := Seabed.mesh_height(a.x + dir.x * along, a.y + dir.y * along)
		if it["top"] <= gy + Plan.LOW:
			continue
		near.append({"kind": it["kind"], "s": along, "side": side, "x": it["x"], "z": it["z"],
				"over_axis": it["top"] - gy, "hull": absf(side) - it["reach"] < HULL_HALF_W,
				"end": minf(along, length - along) < END_R})
	return {"from": a_id, "to": b_id, "length": length, "stations": stations, "flora": near}


## Корпус в точке at с носом по dir.
static func station(at: Vector2, dir: Vector2, s: float) -> Dictionary:
	var right := Vector2(-dir.y, dir.x)
	var gc := Seabed.mesh_height(at.x, at.y)
	var foot := -INF
	var wall := false
	var lz := HULL_FRONT
	while lz <= HULL_BACK + 0.01:
		var lx := -HULL_HALF_W
		while lx <= HULL_HALF_W + 0.01:
			var q := at + right * lx - dir * lz   # нос в −Z осей корабля — вперёд по dir
			foot = maxf(foot, Seabed.mesh_height(q.x, q.y))
			wall = wall or not Helm.Ship.east_ok(q.x, q.y)
			lx += HULL_HALF_W * 0.5
		lz += 2.0
	var low_y := gc + Helm.Ship.CLEARANCE           # точка хода на нижнем пределе
	var need_y := foot - HULL_LOW                   # днище над самым высоким грунтом под корпусом
	var yaw := atan2(-dir.x, -dir.y)
	var ride := maxf(gc + FLOOR, need_y)
	var arch := GateArch.hits(Vector3(at.x, ride, at.y), yaw)
	var side := cross(at, dir, gc)
	return {"s": s, "x": at.x, "z": at.y, "gc": gc, "foot": foot, "need": need_y - gc,
			"dig": 0.0 if wall else maxf(0.0, need_y - low_y), "dig7": 0.0 if wall else maxf(0.0, need_y - gc - FLOOR),
			"lift": need_y, "ice": need_y > Helm.Ship.CEILING, "wall": wall, "arch": arch,
			"rise_l": side.x, "rise_r": side.y}


## Насколько грунт в пределах ±WIDTH/2 поперёк оси поднимается над грунтом оси (слева, справа).
static func cross(at: Vector2, dir: Vector2, gc: float) -> Vector2:
	var right := Vector2(-dir.y, dir.x)
	var hi := Vector2(-INF, -INF)
	var w := -Plan.WIDTH * 0.5
	while w <= Plan.WIDTH * 0.5 + 0.01:
		var q := at + right * w
		var g := Seabed.mesh_height(q.x, q.y) - gc
		if w < 0.0:
			hi.x = maxf(hi.x, g)
		else:
			hi.y = maxf(hi.y, g)
		w += 2.0
	return hi


## Участки подряд идущих станций, где pred истинно: [[s0, s1, худшее значение], …].
static func spans(stations: Array, pred: Callable, value: Callable) -> Array:
	var out: Array = []
	var cur: Array = []
	for st in stations:
		if pred.call(st):
			if cur.is_empty():
				cur = [st["s"], st["s"], value.call(st)]
			else:
				cur[1] = st["s"]
				cur[2] = maxf(cur[2], value.call(st))
		elif not cur.is_empty():
			out.append(cur)
			cur = []
	if not cur.is_empty():
		out.append(cur)
	return out


static func print_leg(leg: Dictionary) -> void:
	var st: Array = leg["stations"]
	var gmin := INF
	var gmax := -INF
	for x in st:
		gmin = minf(gmin, x["gc"])
		gmax = maxf(gmax, x["gc"])
	print("\n%s → %s%s: %.0f м, дно по оси %.0f…%.0f м." % [leg["from"], leg["to"], " (транзит)" if leg.get("transit") else "",
			leg["length"], -gmax, -gmin])
	var fmt := func(sp: Array, unit: String) -> String:
		var parts: Array[String] = []
		for p in sp:
			parts.append("%d–%d м" % [int(p[0]), int(p[1])] + (" (%s)" % (unit % p[2]) if unit != "" else ""))
		return ", ".join(parts) if not parts.is_empty() else "нет"
	var need := 0.0
	for x in st:
		if not x["wall"]:
			need = maxf(need, x["need"])
	print("  за краем отмели вне прохода (стена): %s" % fmt.call(spans(st, func(x): return x["wall"], func(x): return 0.0), ""))
	print("  чтобы корпус не входил в грунт, ход над дном по оси — до %.1f м (нижний предел — %.0f м, план — %.0f м)" % [
			need, Helm.Ship.CLEARANCE, FLOOR])
	print("  корпус в грунте на нижнем пределе: %s" % fmt.call(spans(st, func(x): return x["dig"] > 0.5, func(x): return x["dig"]), "до %.1f м"))
	print("  корпус в грунте и на %.0f м над дном: %s" % [FLOOR, fmt.call(spans(st, func(x): return x["dig7"] > 0.5, func(x): return x["dig7"]), "до %.1f м")])
	print("  корпус над грунтом не помещается подо льдом: %s" % fmt.call(spans(st, func(x): return x["ice"], func(x): return x["lift"] - Helm.Ship.CEILING), "на %.1f м"))
	print("  опоры арки 07: %s" % fmt.call(spans(st, func(x): return x["arch"], func(x): return 0.0), ""))
	print("  грунт сбоку выше низа объёма: слева %s; справа %s" % [
			fmt.call(spans(st, func(x): return x["rise_l"] > Plan.LOW, func(x): return x["rise_l"]), "+%.0f м"),
			fmt.call(spans(st, func(x): return x["rise_r"] > Plan.LOW, func(x): return x["rise_r"]), "+%.0f м")])
	var fl: Array = leg["flora"]
	var by := {}
	for it in fl:
		var k := "%s%s%s" % [it["kind"], " (в полосе корпуса)" if it["hull"] else "", " у самого места" if it["end"] else ""]
		by[k] = by.get(k, 0) + 1
	var parts: Array[String] = []
	for k in by:
		parts.append("%s ×%d" % [k, by[k]])
	print("  высокая флора в объёме: %s" % (", ".join(parts) if not parts.is_empty() else "нет"))


## Сетка дна для плана слоя: [x0, z0, шаг, nx, nz, высоты построчно по z].
static func grid() -> Array:
	var x0 := LayerMap.BOUNDS.x
	var x1 := Helm.Ship.EAST_END
	var z0 := LayerMap.BOUNDS.x
	var z1 := LayerMap.BOUNDS.y
	var nx := int((x1 - x0) / GRID) + 1
	var nz := int((z1 - z0) / GRID) + 1
	var h: Array = []
	for j in nz:
		for i in nx:
			var x := x0 + i * GRID
			var z := z0 + j * GRID
			h.append(snappedf(Seabed.mesh_height(x, z), 0.1) if Helm.Ship.east_ok(x, z) else null)
	return [x0, z0, GRID, nx, nz, h]
