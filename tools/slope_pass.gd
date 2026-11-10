extends SceneTree
## След корпуса на спуске 06 → (250; 200) → 10 и веерники склона (#840, запрос дизайнера уровней 10.11: «след полного
## корпуса на изгибе через (250;200), особенно у первой пары (280;190)/(281;197), и боковые зазоры с колыханием»).
## Headless, без узлов: мир (`EcoView`) после сброса, веера стоят на `Seabed.mesh_height`; ход корабля — нижний предел
## `Helm.Ship.floor_at` над грунтом, как в игре (`Seabed.height` + верх клиньев `EcoDrop.top`). Облачный расчёт, не
## телефонный. Ничего не переставляет — только отчёт.
##   godot --headless --path . -s tools/slope_pass.gd [-- seed=<n> ride=<м над пределом>]
## Путь — ломаная схемы слоя (`docs/urovni/sloj-1.md`, «Поправка маршрутов»): прямые 06 → изгиб и изгиб → 10, в изгибе
## корпус доворачивает на месте (все промежуточные курсы). Корпус — прямоугольник по `HullPlan` (как tools/route_plan.gd).
## По каждому вееру ближе NEAR к оси: сторона, отступ от оси, наименьший боковой зазор до следа корпуса за вычетом
## полуширины веера и края колыхания, где он; если след накрывает веер — зазор по высоте от днища до верха веера.
## Ещё — 06: с каких станций подхода 03 → 06 → изгиб пятна мха группы кормления и начало склона видны вместе
## (оба в поле зрения камеры `Deck.FOV` по курсу и ближе дальности прожектора `Searchlight.BASE_RANGE`).

const Route := preload("res://tools/route_plan.gd")

const BEND := Vector2(250.0, 200.0)
const STEP := 1.0
const TURN_STEPS := 24
## Веера в отчёте — не дальше этого от оси, м.
const NEAR := 40.0
## Край колыхания: доля высоты веера вбок (как tools/pass_box.gd, `EcoFan.SWAY` 0,05 рад с запасом).
const SWAY_K := 0.1


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var seed := int(kv.get("seed", "20261018"))
	var extra := float(kv.get("ride", "0"))
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	ev.world.reset(seed)
	var ship := Helm.Ship.new()
	var drop := ev.drop
	ship.ground = func(x: float, z: float) -> float:
		var g: float = Seabed.height(x, z)
		if drop:
			g = maxf(g, drop.top(x, z))
		return g
	var path: Array[Vector2] = [LayerMap.xz("06"), BEND, LayerMap.xz("10")]
	var poses := track(path)
	print("Спуск %s → (%.0f; %.0f) → 10, зерно %d. Корпус %.1f × %.1f м (нос %.1f, корма +%.1f от точки хода), днище %.1f м." % [
			"06", BEND.x, BEND.y, seed, Route.HULL_BACK - Route.HULL_FRONT, Route.HULL_HALF_W * 2.0, Route.HULL_FRONT,
			Route.HULL_BACK, Route.HULL_LOW])
	print("Ход — нижний предел Helm.Ship.floor_at (зазор %.0f м под всем днищем)%s; в изгибе доворот на месте %.1f°." % [
			Helm.Ship.CLEARANCE, " + %.1f м" % extra if extra != 0.0 else "", rad_to_deg(
			(BEND - path[0]).normalized().angle_to(path[2] - BEND))])
	print("Веер %.1f × %.1f м, край колыхания %.1f м; на склоне веера: %s." % [EcoFan.WIDTH, EcoFan.HEIGHT,
			EcoFan.HEIGHT * SWAY_K, ", ".join(EcoDrop.SLOPE_FANS.map(func(v: Vector2) -> String: return "(%.0f; %.0f)" % [v.x, v.y]))])
	for pz in poses:
		pz["ride"] = ship.floor_at(Vector3(pz["at"].x, 0.0, pz["at"].y), pz["yaw"]) + extra
	print("\nВеерники у оси (сторона по ходу; зазор — от следа корпуса до края веера с колыханием):")
	print("  веер (x; z) | дно, м | вдоль, м | сторона, отступ от оси | мин. боковой зазор, м — где | накрыт следом: днище − верх веера, м")
	for f in ev.fans.fans:
		var xz := Vector2(f.pos.x, f.pos.z)
		var pr := project(path, xz)
		if pr["d"] > NEAR:
			continue
		var r := clearance(poses, f)
		print("  (%.0f; %.0f) | %.0f | %.0f | %s %.1f | %.1f — %s | %s" % [xz.x, xz.y, -f.pos.y, pr["s"],
				"слева" if pr["side"] < 0.0 else "справа", absf(pr["side"]), r["gap"], r["where"],
				"нет" if r["over"] == INF else "%+.1f (%s)%s" % [r["over"], r["over_where"], " — КОРПУС ЗАДЕВАЕТ" if r["over"] < 0.0 else ""]])
	view_06(path)
	quit()


## Положения корпуса вдоль ломаной через STEP м, в каждой внутренней вершине — доворот на месте.
static func track(path: Array[Vector2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s0 := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		if i > 0:
			var prev := (a - path[i - 1]).normalized()
			var ang := prev.angle_to(dir)
			for k in range(1, TURN_STEPS):
				var d := prev.rotated(ang * k / TURN_STEPS)
				out.append({"at": a, "dir": d, "yaw": atan2(-d.x, -d.y), "s": s0, "turn": true})
		var s := 0.0
		while s <= length + 0.01:
			out.append({"at": a + dir * minf(s, length), "dir": dir, "yaw": atan2(-dir.x, -dir.y), "s": s0 + minf(s, length), "turn": false})
			s += STEP
		s0 += length
	return out


## Ближайшая точка ломаной: s — вдоль от начала, side — отступ (минус — слева по ходу), d — расстояние.
static func project(path: Array[Vector2], p: Vector2) -> Dictionary:
	var best := {"d": INF}
	var acc := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var seg := path[i + 1] - a
		var tc := clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var q := a + seg * tc
		var d := p.distance_to(q)
		if d < best["d"]:
			var dir := seg.normalized()
			best = {"d": d, "s": acc + seg.length() * tc, "side": (p - q).dot(Vector2(-dir.y, dir.x))}
		acc += seg.length()
	return best


## Горизонтальное расстояние от точки до прямоугольника корпуса в положении pz.
static func to_hull(pz: Dictionary, p: Vector2) -> float:
	var dir: Vector2 = pz["dir"]
	var q: Vector2 = p - pz["at"]
	var lx := q.dot(Vector2(-dir.y, dir.x))
	var lz := -q.dot(dir)   # нос в −Z осей корабля — впереди по dir
	var dx := maxf(absf(lx) - Route.HULL_HALF_W, 0.0)
	var dz := maxf(maxf(Route.HULL_FRONT - lz, lz - Route.HULL_BACK), 0.0)
	return sqrt(dx * dx + dz * dz)


## Наименьший боковой зазор от следа корпуса до веера (полуширина и колыхание вычтены) и, где след накрывает веер,
## наименьший зазор по высоте днище − верх веера.
static func clearance(poses: Array[Dictionary], f: EcoFan.Fan) -> Dictionary:
	var p := Vector2(f.pos.x, f.pos.z)
	var reach := EcoFan.WIDTH * 0.5 + EcoFan.HEIGHT * SWAY_K
	var top := f.pos.y + EcoFan.HEIGHT
	var out := {"gap": INF, "where": "", "over": INF, "over_where": ""}
	for pz in poses:
		var g := to_hull(pz, p) - reach
		var where := ("доворот в изгибе" if pz["turn"] else "%.0f м пути" % pz["s"])
		if g < out["gap"]:
			out["gap"] = g
			out["where"] = where
		if g < 0.0:
			var v: float = pz["ride"] + Route.HULL_LOW - top
			if v < out["over"]:
				out["over"] = v
				out["over_where"] = where
	return out


## 06: станции подхода, с которых пятна мха кормления и начало склона (вход в проход) в кадре вместе.
static func view_06(path: Array[Vector2]) -> void:
	var approach: Array[Vector2] = [LayerMap.xz("03"), LayerMap.xz("06"), BEND]
	var half := deg_to_rad(Deck.FOV) * 0.5
	var slope := Vector2(Seabed.Slope.X_IN, Seabed.Slope.GAP_Z)
	print("\n06: подход 03 → 06 → изгиб; мох кормления %s, начало склона (%.0f; %.0f). В кадре — угол от курса ≤ %.0f° (FOV %.0f° по горизонтали — оценка), ближе %.0f м." % [
			", ".join(EcoDrop.MOSS.map(func(v: Vector2) -> String: return "(%.0f; %.0f)" % [v.x, v.y])), slope.x, slope.y,
			rad_to_deg(half), Deck.FOV, Searchlight.BASE_RANGE])
	print("  станция (x; z) | курс | до мха, м, угол | до склона, м, угол | вместе")
	var both := 0
	for i in approach.size() - 1:
		var a := approach[i]
		var b := approach[i + 1]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var s := 0.0
		while s <= length + 0.01:
			var at := a + dir * minf(s, length)
			var m := EcoDrop.MOSS[0] if at.distance_to(EcoDrop.MOSS[0]) < at.distance_to(EcoDrop.MOSS[1]) else EcoDrop.MOSS[1]
			var am := rad_to_deg(absf(dir.angle_to(m - at)))
			var asl := rad_to_deg(absf(dir.angle_to(slope - at)))
			var ok := am <= rad_to_deg(half) and asl <= rad_to_deg(half) and at.distance_to(m) <= Searchlight.BASE_RANGE \
					and at.distance_to(slope) <= Searchlight.BASE_RANGE
			both += 1 if ok else 0
			print("  (%.0f; %.0f) | %s | %.0f, %.0f° | %.0f, %.0f° | %s" % [at.x, at.y, "03→06" if i == 0 else "06→изгиб",
					at.distance_to(m), am, at.distance_to(slope), asl, "ДА" if ok else "нет"])
			s += 10.0
	print("  Станций, где мох и склон в кадре вместе по курсу: %d." % both)
