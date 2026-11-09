extends SceneTree
## Локальный габарит прохода 00 → 01 (#1400, решение дизайнера уровней 09.11 по #1455, `docs/urovni/sloj-1.md`,
## PR #1482): **20 м полной ширины × 30 м полной высоты**, ±10 м от оси хода. Низ объёма — H + 2 м, где H — максимум
## грунта под следом корпуса (34,2 м вдоль курса по `HullPlan`, 20 м поперёк); верх — H + 32 м; точка хода — H + 7 м
## (днище H + 5,4, верх корпуса H + 11,8). Низкий покров — до 2 м над своим грунтом с краем колыхания.
## Рядом — прежний контур 60×30 (низ — грунт оси + 2 м, как в tools/pass_plan.gd) на той же оси.
## Headless, без узлов: мир (`EcoView`) после сброса, дно `Seabed.mesh_height`, лёд `Seabed.ICE_Y`, потолок хода
## `Helm.Ship.CEILING`. Облачный расчёт, не телефонный. Ничего не переставляет — только отчёт.
##   godot --headless --path . -s tools/pass_box.gd [-- seed=<n> json=<файл>]
## Печатает по станциям через STEP м: H, точку хода, насколько она выше прежних 7 м над грунтом оси, помещается ли
## верх объёма под льдом; плавную траекторию с уклоном не круче SLOPE; флору у коридора — боковой и вертикальный
## зазор с краем колыхания; конфликты обоих контуров; поворот в вершине — след корпуса целиком; отход к 00 носом назад.

const Plan := preload("res://tools/pass_plan.gd")
const Route := preload("res://tools/route_plan.gd")

## Новый контур: полуширина, запас под низом над H, высота объёма, точка хода над H.
const HALF := 10.0
const LOW := 2.0
const HEIGHT := 30.0
const RIDE := 7.0
const STEP := 2.0
const GRID := 1.0
## Край колыхания флоры: доля высоты над своим грунтом вбок (≈ 6°; ленточник `EcoKelp.TILT` 0,08 рад, веерник
## `EcoFan.SWAY` 0,05 рад, волнолист 0,05 рад; наклон от корпуса уводит ленты наружу, не внутрь).
const SWAY_K := 0.1
## Уклон плавной траектории (подъём/спуск на метр хода) — допущение расчёта, не число управления.
const SLOPE := 0.2
## Флора в отчёте — не дальше этого от края коридора.
const NEAR := 15.0


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	ev.world.reset(int(kv.get("seed", "20261018")))
	var total := Plan.path_length()
	var st: Array[Dictionary] = []
	var s := 0.0
	while s <= total + 0.01:
		st.append(station(s))
		s += STEP
	smooth(st)
	print("Проход 00 → 01 (%.0f м) по оси %s. Контур 20×30: ±%.0f м, низ H+%.0f, верх H+%.0f, ход H+%.0f; H — максимум грунта под следом %.1f×%.0f м." % [
			total, Plan.PATH, HALF, LOW, LOW + HEIGHT, RIDE, Route.HULL_BACK - Route.HULL_FRONT, HALF * 2.0])
	print("\nСтанции (через %.0f м; каждая пятая и вершины):" % STEP)
	print("  вдоль | точка | грунт оси | H | ход H+7 | +к 7 м над осью | плавный ход | верх объёма | до льда")
	var worst_ice := INF
	var worst_lift := -INF
	var worst_extra := 0.0
	for i in st.size():
		var t := st[i]
		worst_ice = minf(worst_ice, Seabed.ICE_Y - t["top"])
		worst_lift = maxf(worst_lift, t["ride"] - (t["axis_g"] + Plan.FLOOR))
		worst_extra = maxf(worst_extra, t["smooth"] - t["ride"])
		if i % 5 == 0 or i == st.size() - 1:
			print("  %3d | (%d; %d) | %.1f | %.1f | %.1f | %+.1f | %.1f | %.1f | %.1f" % [
					int(t["s"]), roundi(t["x"]), roundi(t["z"]), t["axis_g"], t["h"], t["ride"],
					t["ride"] - (t["axis_g"] + Plan.FLOOR), t["smooth"], t["top"], Seabed.ICE_Y - t["top"]])
	print("\nХод H+7 выше прежних 7 м над грунтом оси до %.1f м; плавный ход (уклон ≤ %.2f) выше H+7 до %.1f м." % [
			worst_lift, SLOPE, worst_extra])
	print("Верх объёма под льдом (лёд y = %.0f): запас не меньше %.1f м — %s. Потолок хода корабля %.0f м: ход не выше %.1f м." % [
			Seabed.ICE_Y, worst_ice, "помещается" if worst_ice >= 0.0 else "НЕ помещается", Helm.Ship.CEILING,
			max_of(st, "smooth")])
	var back := -INF
	var back_ice := INF
	for t in st:
		back = maxf(back, t["h_back"] - t["h"])
		back_ice = minf(back_ice, Seabed.ICE_Y - (t["h_back"] + LOW + HEIGHT))
	print("Отход к 00 носом к 00 (разворот — вне коридора, в кармане): H выше прямого хода до %+.1f м; верх объёма под льдом с запасом %.1f м." % [
			back, back_ice])
	turn_report()
	var fl := flora(ev, st)
	if kv.has("json"):
		var f := FileAccess.open(kv["json"], FileAccess.WRITE)
		f.store_string(JSON.stringify({"stations": st, "flora": fl, "path": Plan.PATH}))
	quit()


## Станция на s м от 00: грунт оси, H под следом (корпус по курсу, ±HALF поперёк), ход, верх объёма.
static func station(s: float) -> Dictionary:
	var a := Plan.along(s)
	var at: Vector2 = a["at"]
	var dir: Vector2 = a["dir"]
	var h := foot_max(at, dir, HALF)
	return {"s": s, "x": at.x, "z": at.y, "axis_g": Seabed.mesh_height(at.x, at.y), "h": h, "ride": h + RIDE,
			"low": h + LOW, "top": h + LOW + HEIGHT, "hull_g": foot_max(at, dir, Route.HULL_HALF_W),
			"h_back": foot_max(at, -dir, HALF)}


## Максимум видимого грунта под прямоугольником: корпус от носа (HULL_FRONT, впереди) до кормы, ±half поперёк.
static func foot_max(at: Vector2, dir: Vector2, half: float) -> float:
	var right := Vector2(-dir.y, dir.x)
	var hi := -INF
	var z := Route.HULL_FRONT
	while z <= Route.HULL_BACK + 0.01:
		var w := -half
		while w <= half + 0.01:
			var q := at - dir * z + right * w   # нос в −Z: точка z корпуса — на −z вдоль курса
			hi = maxf(hi, Seabed.mesh_height(q.x, q.y))
			w += GRID
		z += GRID
	return hi


## Плавный ход: не ниже H+7 нигде, уклон между станциями не круче SLOPE (верхняя огибающая конусов).
static func smooth(st: Array[Dictionary]) -> void:
	for t in st:
		var y := -INF
		for u in st:
			y = maxf(y, u["ride"] - SLOPE * absf(u["s"] - t["s"]))
		t["smooth"] = y


static func max_of(st: Array[Dictionary], key: String) -> float:
	var m := -INF
	for t in st:
		m = maxf(m, t[key])
	return m


## Поворот в вершине scena=2: корпус поворачивается на месте с курса первого отрезка на второй — след целиком.
static func turn_report() -> void:
	var p := Plan.PATH
	var d1 := (p[1] - p[0]).normalized()
	var d2 := (p[2] - p[1]).normalized()
	var ang := rad_to_deg(d1.angle_to(d2))
	var swing := 0.0
	var h := -INF
	for k in 11:
		var d := d1.rotated(deg_to_rad(ang) * k / 10.0)
		h = maxf(h, foot_max(p[1], d, HALF))
		# Насколько нос и корма уходят вбок от оси входящего и выходящего отрезков.
		for z in [Route.HULL_FRONT, Route.HULL_BACK]:
			for corner in [-Route.HULL_HALF_W, Route.HULL_HALF_W]:
				var q: Vector2 = p[1] - d * z + Vector2(-d.y, d.x) * corner
				var pr := Plan.project(q)
				swing = maxf(swing, absf(pr["side"]))
	print("\nПоворот в (%.0f; %.1f): %.1f°; углы корпуса уходят от оси до %.1f м (коридор ±%.0f); H по всем положениям %.1f м." % [
			p[1].x, p[1].y, ang, swing, HALF, h])


## Флора у коридора: по каждой высокой детали ближе NEAR к краю ±HALF — боковой зазор с колыханием, верх над низом
## объёма. Конфликт 20×30 — внутри ±HALF и выше низа (H+2); конфликт 60×30 — внутри ±30 и выше грунта оси + 2.
static func flora(ev: EcoView, st: Array[Dictionary]) -> Array:
	var items := Plan.collect(ev)
	var near: Array = []
	var new_in := 0
	var old_in := 0
	for it in items:
		var pr := Plan.project(Vector2(it["x"], it["z"]))
		if pr["edge"]:
			continue
		var sway: float = (it["top"] - it["ground"]) * SWAY_K
		var gap: float = absf(pr["side"]) - it["reach"] - sway - HALF
		var t := st[clampi(roundi(pr["s"] / STEP), 0, st.size() - 1)]
		var over: float = it["top"] - t["low"]
		var axis_g := Seabed.mesh_height(pr["axis"].x, pr["axis"].y)
		if absf(pr["side"]) - it["reach"] < Plan.WIDTH * 0.5 and it["top"] > axis_g + Plan.LOW:
			old_in += 1
		var hit := gap < 0.0 and over > 0.0
		new_in += 1 if hit else 0
		if gap > NEAR:
			continue
		near.append({"kind": it["kind"], "s": pr["s"], "side": pr["side"], "gap": gap, "over": over, "hit": hit,
				"sway": sway, "top_own": it["top"] - it["ground"]})
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["s"] < b["s"])
	print("\nВысокая флора не дальше %.0f м от края коридора ±%.0f (зазор — с краем колыхания %.0f %% высоты):" % [NEAR, HALF, SWAY_K * 100.0])
	print("  вдоль, м | вид ×n | сторона | мин. боковой зазор, м | верх − низ объёма, м | конфликт")
	var groups := {}
	for n in near:
		var key := "%s|%d|%s" % [n["kind"], int(n["s"] / 10.0), "Л" if n["side"] < 0.0 else "П"]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(n)
	var keys := groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return groups[a][0]["s"] < groups[b][0]["s"])
	var min_gap := INF
	for key in keys:
		var g: Array = groups[key]
		var gap := INF
		var over := -INF
		var hit := false
		for n in g:
			gap = minf(gap, n["gap"])
			over = maxf(over, n["over"])
			hit = hit or n["hit"]
			if n["over"] > 0.0:
				min_gap = minf(min_gap, n["gap"])
		print("  %3d–%3d | %s ×%d | %s | %.1f | %+.1f | %s" % [int(g[0]["s"]), int(g[-1]["s"]), g[0]["kind"], g.size(),
				"слева" if g[0]["side"] < 0.0 else "справа", gap, over, "ДА" if hit else "нет"])
	print("\nКонфликты: контур 60×30 — %d высоких деталей; контур 20×30 — %d. Мин. боковой зазор до флоры выше низа объёма: %.1f м." % [
			old_in, new_in, min_gap])
	return near
