extends SceneTree
## План и сечение реального прохода 00 → 01 с высокой флорой (#1400, запрос дизайнера уровней: `docs/urovni/sloj-1.md`,
## «Потоку Б в существующей #1400: план фактической траектории и сечение свободного объёма»). Headless, без узлов:
## мир (`EcoView`, дно `Seabed.mesh_height`) после сброса, путь — точки `scena=` (tools/shot_setup.gd), как в
## tools/patrol.gd. Облачный расчёт, не телефонный.
##   godot --headless --path . -s tools/pass_plan.gd [-- seed=<n> json=<файл>]
## Печатает: по каждой высокой детали ближе REPORT к оси — сторону, отступ от оси, высоту над своим грунтом и над
## грунтом под осью; что входит в свободный объём 60×30 м (ширина WIDTH по оси пути, высота HEIGHT от грунта под
## осью + LOW — низкий покров ниже LOW не считается, `docs/urovni/sloj-1.md`: «низкий покров допустим под ним»);
## где грунт сбоку поднимается в этот объём. json= — то же для картинок плана и сечений.

## Путь: выход из 00 → середина → подход к 01 (точки `scena=`), корабль на FLOOR над видимым дном.
const PATH: Array[Vector2] = [Vector2(4.0, 80.0), Vector2(20.0, 22.5), Vector2(33.0, -22.0)]
const FLOOR := 7.0
## Свободный объём: полная ширина и высота (дизайнер уровней, 08.11: 60×30 м — полные, не отступы).
const WIDTH := 60.0
const HEIGHT := 30.0
## Ниже этого над грунтом под осью — низкий покров, в объём не входит.
const LOW := 2.0
## Высокая деталь — верх выше TALL над своим грунтом.
const TALL := 2.0
## Отчёт — детали не дальше REPORT от оси; шаг станций вдоль пути, шаг сечения поперёк.
const REPORT := 45.0
const STEP := 5.0
const CROSS := 1.0


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	ev.world.reset(int(kv.get("seed", "20261018")))
	var items := collect(ev)
	var out := {"path": [], "items": [], "stations": [], "width": WIDTH, "height": HEIGHT, "low": LOW}
	for p in PATH:
		out["path"].append([p.x, p.y, Seabed.mesh_height(p.x, p.y) + FLOOR])
	var total := path_length()
	print("Проход 00 → 01 по точкам scena=, длина %.0f м, корабль на %.0f м над дном. Объём %.0f×%.0f м от грунта под осью + %.0f м." % [
			total, FLOOR, WIDTH, HEIGHT, LOW])
	var near: Array[Dictionary] = []
	var inside := 0
	for it in items:
		var pr := project(Vector2(it["x"], it["z"]))
		if pr["edge"] or absf(pr["side"]) > REPORT:
			continue
		var axis_g := Seabed.mesh_height(pr["axis"].x, pr["axis"].y)
		it["s"] = pr["s"]
		it["side"] = pr["side"]
		it["over_axis"] = it["top"] - axis_g
		it["in"] = absf(pr["side"]) - it["reach"] < WIDTH * 0.5 and it["top"] > axis_g + LOW
		inside += 1 if it["in"] else 0
		near.append(it)
		out["items"].append(it)
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["s"] < b["s"])
	print("\nВысокие детали ближе %.0f м к оси (верх выше %.0f м над своим грунтом), по пути от 00:" % [REPORT, TALL])
	print("  вдоль, м | вид | сторона, отступ, м | верх над своим грунтом / над грунтом оси, м | в объёме")
	var groups := {}
	for it in near:
		var key := "%s|%d|%s" % [it["kind"], int(it["s"] / 10.0), "Л" if it["side"] < 0.0 else "П"]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(it)
	var keys := groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return groups[a][0]["s"] < groups[b][0]["s"])
	for key in keys:
		var g: Array = groups[key]
		var lo := INF
		var hi_own := 0.0
		var hi_axis := -INF
		var any_in := false
		for it in g:
			lo = minf(lo, absf(it["side"]) - it["reach"])
			hi_own = maxf(hi_own, it["top"] - it["ground"])
			hi_axis = maxf(hi_axis, it["over_axis"])
			any_in = any_in or it["in"]
		print("  %3d–%3d | %s ×%d | %s %.0f | %.1f / %.1f | %s" % [
				int(g[0]["s"]), int(g[-1]["s"]), g[0]["kind"], g.size(), "слева" if g[0]["side"] < 0.0 else "справа",
				maxf(lo, 0.0), hi_own, hi_axis, "ДА" if any_in else "нет"])
	print("\nВ объёме: %d из %d высоких деталей рядом." % [inside, near.size()])
	print("\nГрунт поперёк оси (станции через %.0f м): где поднимается выше низа объёма в пределах ±%.0f м." % [STEP, WIDTH * 0.5])
	var s := 0.0
	while s <= total + 0.01:
		var st := station(s)
		out["stations"].append(st)
		if st["ground_in"].size() > 0 or is_equal_approx(s, 0.0):
			print("  %3d м (%d; %d): грунт оси %.1f, корабль %.1f, низ объёма %.1f; грунт выше низа: %s" % [
					int(s), roundi(st["x"]), roundi(st["z"]), st["axis_g"], st["axis_g"] + FLOOR, st["axis_g"] + LOW,
					", ".join(st["ground_in"]) if st["ground_in"].size() > 0 else "нет"])
		s += STEP
	for i in PATH.size():
		var sc := station(arc_at(i))
		sc["scena"] = i + 1
		out["stations"].append(sc)
	if kv.has("json"):
		var f := FileAccess.open(kv["json"], FileAccess.WRITE)
		f.store_string(JSON.stringify(out))
	quit()


## Высокие детали мира: {kind, x, z, ground, top, reach (сколько выступают вбок от точки, м)}.
static func collect(ev: EcoView) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in ev.kelp.groves:
		for st in g.stalks:
			add(out, "ленточник", st.pos, st.pos.y + st.height, 0.0)
	for f in ev.ferns.ferns:
		add(out, "волнолист", f.pos, f.top.y, 0.0)
	for b in ev.coral.bushes:
		add(out, "огнецвет", b.base, b.top.y, 0.0)
	for f in ev.fans.fans:
		add(out, "веерник", f.pos, f.top.y, 0.0)
	for o in ev.organs.organs:
		add(out, "органчик", o.base, o.top.y, 0.0)
	for b in ev.flower.branches:
		var tip: Vector3 = b.p0 if b.p0.y > b.p1.y else b.p1
		add(out, "Каменный цветок", b.p1, tip.y, b.r1)
	if ev.grot.grot != null:
		var w := ev.grot.grot
		add(out, "гротовик (ходит)", w.p, w.p.y + EcoGrot.SHELL.y + EcoGrot.REEF_TOP, EcoGrot.REEF_R.y)
	return out


static func add(out: Array[Dictionary], kind: String, base: Vector3, top: float, reach: float) -> void:
	var gy := Seabed.mesh_height(base.x, base.z)
	if top - gy < TALL:
		return
	out.append({"kind": kind, "x": base.x, "z": base.z, "ground": gy, "top": top, "reach": reach})


static func path_length() -> float:
	var l := 0.0
	for i in PATH.size() - 1:
		l += PATH[i].distance_to(PATH[i + 1])
	return l


static func arc_at(i: int) -> float:
	var l := 0.0
	for k in i:
		l += PATH[k].distance_to(PATH[k + 1])
	return l


## Точка на пути через s м от 00 и направление.
static func along(s: float) -> Dictionary:
	var left := s
	for i in PATH.size() - 1:
		var seg := PATH[i + 1] - PATH[i]
		if left <= seg.length() or i == PATH.size() - 2:
			var d := seg.normalized()
			return {"at": PATH[i] + d * clampf(left, 0.0, seg.length()), "dir": d}
		left -= seg.length()
	return {"at": PATH[-1], "dir": Vector2.UP}


## Ближайшая точка оси: s — вдоль от 00, side — отступ (минус — слева по ходу), edge — за концами пути.
static func project(p: Vector2) -> Dictionary:
	var best := {"d": INF}
	var acc := 0.0
	for i in PATH.size() - 1:
		var a := PATH[i]
		var seg := PATH[i + 1] - a
		var t := (p - a).dot(seg) / seg.length_squared()
		var tc := clampf(t, 0.0, 1.0)
		var q := a + seg * tc
		var d := p.distance_to(q)
		if d < best["d"]:
			var dir := seg.normalized()
			var right := Vector2(-dir.y, dir.x)   # нос в −Z: правый борт при dir = (0, −1) — +X
			var edge := (i == 0 and t < 0.0) or (i == PATH.size() - 2 and t > 1.0)
			best = {"d": d, "s": acc + seg.length() * tc, "side": (p - q).dot(right), "axis": q, "edge": edge}
		acc += seg.length()
	return best


## Сечение поперёк оси на s м: грунт через CROSS м на ±REPORT, где грунт выше низа объёма.
static func station(s: float) -> Dictionary:
	var a := along(s)
	var at: Vector2 = a["at"]
	var dir: Vector2 = a["dir"]
	var right := Vector2(-dir.y, dir.x)
	var axis_g := Seabed.mesh_height(at.x, at.y)
	var prof: Array = []
	var hi_l := -INF
	var hi_r := -INF
	var w := -REPORT
	while w <= REPORT + 0.01:
		var q := at + right * w
		var gy := Seabed.mesh_height(q.x, q.y)
		prof.append([w, gy])
		if absf(w) <= WIDTH * 0.5:
			if w < 0.0:
				hi_l = maxf(hi_l, gy)
			else:
				hi_r = maxf(hi_r, gy)
		w += CROSS
	var ground_in: Array[String] = []
	if hi_l > axis_g + LOW:
		ground_in.append("слева +%.1f м" % (hi_l - axis_g))
	if hi_r > axis_g + LOW:
		ground_in.append("справа +%.1f м" % (hi_r - axis_g))
	return {"s": s, "x": at.x, "z": at.y, "dir": [dir.x, dir.y], "axis_g": axis_g, "profile": prof, "ground_in": ground_in}
