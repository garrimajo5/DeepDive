extends SceneTree
## След полного корпуса у арки врат 07 (#1757, шаг 3в; запрос дизайнера уровней 13.11: «весь спуск с гребня и отход
## проверять полным корпусом с выступами, обратный ход, поворот 07 ↔ 08 — заново, план полного следа»).
## Headless, без узлов и без живого мира: корабль `Helm.Ship` идёт **своим шагом** `update` (разгон, поворот,
## погружение — как в игре, не стоянки по станциям), дно — `Seabed.height`, твёрдое — арка `GateArch.hits`.
## Течения нет, флору рамки не считает (она на гребне за склонами — `test_eco_gate`). Облачный расчёт, не телефонный.
## Ничего не переставляет — только отчёт.
##   godot --headless --path . -s tools/gate_pass.gd [-- png=<файл плана> run=<имя прогона>]
## Прогоны `RUNS` — ломаные в осях места (dx; dz от середины арки, подход с +Z) с глубиной в каждой точке; ведёт
## простой рулевой `drive`: нос на точку (задний ход — корма на точку), глубина — по доле пути отрезка, но не ближе
## `KEEL` м к нижнему пределу хода под корпусом сейчас и через `LOOK` с (как пилот, что смотрит на глубину под килем).
## Точка с пятым числом — **стоянка**: курс стоянки в градусах (`rotation.y`, как `yaw` шага `ship` сценария). К ней
## рулевой подходит, сбавляя ход (скорость ≈ `PARK_K` × остаток пути, тормозит задним ходом), встаёт не дальше `PARK`
## м от точки, доворачивает на курс и берёт глубину. Так проверяется место кадра `37b-okno-gnezdo` — `STAND`.
## Печатает по каждому прогону станции через `EVERY` м пути: место, глубину, курс, нижний предел хода
## (`Helm.Ship.floor_at`), зазор грунта под всем днищем, зазор от контура корпуса с выступами до блоков арки на его
## высоте; итог — дошёл ли, удары о дно (`bump`), упоры (корабль стоит под тягой), откаты поворота у твёрдого
## (#1847) и сдвиги вбок вдоль твёрдого, наименьшие зазоры; у стоянки — где встал и сколько до гнезда купольника.
## png= — план: дно оттенком по глубине, блоки арки на высоте прохода, контуры корпуса и след центра.

const Route := preload("res://tools/route_plan.gd")

## Контур корпуса с выступами в осях корабля (нос в −Z): губки манипулятора z −9,15, кожухи двигателей до +27,6,
## кормовой переход до `HullPlan.STERN_END`; полуширина — носовая оболочка 6,8 м (кожухи — 6,7).
const HULL_FRONT := -9.2
const HULL_BACK := HullPlan.STERN_END
const HULL_HALF_W := HullPlan.NOSE_W * 0.5
const HULL_UP := GateArch.SHIP_UP
const HULL_DOWN := GateArch.SHIP_DOWN
const DT := 0.1
const EVERY := 10.0
const ARRIVE := 3.0          ## м — точка взята
const DEPTH_OK := 0.6        ## м — глубина точки взята (стоянка с погружением)
const THRUST := 0.6          ## тяга рулевого вперёд (≈ 4 м/с), назад — полная (≈ 3,6 м/с)
const AIM := 0.3             ## рад — круче этого рулевой сперва доворачивает на месте
const PASS_DEPTH := 58.0     ## проектное сечение уровней: центр корабля в проходе, м
const RIDGE_DEPTH := 38.0    ## ход над гребнем, м (дно гребня 44…50 м, предел по центру ≈ 39,4…45,6)
const KEEL := 1.0            ## м — рулевой держит центр не ближе этого к нижнему пределу хода: сейчас и через LOOK с
const LOOK := 2.5
const PARK := 0.5            ## м — стоянка взята: центр не дальше этого от точки…
const PARK_SPEED := 0.15     ## …ход не больше этого, м/с…
const PARK_YAW := 0.02       ## …и курс не дальше этого от курса стоянки, рад (≈ 1°)
const PARK_K := 0.4          ## 1/с — ход к стоянке: остаток пути × это, не больше хода рулевого
const SLIDE := 0.03          ## м за шаг — центр ушёл от «нос × ход» дальше этого: корпус скользит вдоль твёрдого

## Стоянка кадра `37b-okno-gnezdo` (#1757) в осях места: [dx, dz, глубина, курс °] — шаг `ship` сценария тестера
## (−76,9; −62; −215,5), yaw −63 (тест сверяет со сценарием). Точка разворота перед ней — на оси жёлоба, на линии курса.
const STAND := [23.1, 24.5, 62.0, -63.0]
const STAND_TURN := [0.0, 36.3]

## Прогоны: имя → точки [dx, dz, глубина, задний ход (1/0)]; первая точка — старт (курс — на вторую).
const RUNS := {
	"низом": [  # с гребня в жёлоб, под аркой до северного конца пола, задним ходом обратно на гребень
		[0.0, 140.0, 30.0, 0], [0.0, 100.0, RIDGE_DEPTH, 0], [0.0, 25.0, PASS_DEPTH, 0],
		[0.0, -45.0, PASS_DEPTH, 0], [0.0, 25.0, PASS_DEPTH, 1], [0.0, 100.0, RIDGE_DEPTH, 1]],
	"07 → 08": [  # из жёлоба у прежней точки поворота (−100; −210): всплыть на месте, на запад к 08
		[0.0, 25.0, PASS_DEPTH, 0], [0.0, 25.0, RIDGE_DEPTH, 0], [-150.0, 30.0, 35.0, 0]],
	"08 → 07": [  # от 08 к оси жёлоба, погрузиться на месте и под арку
		[-150.0, 30.0, 35.0, 0], [0.0, 25.0, RIDGE_DEPTH, 0], [0.0, 25.0, PASS_DEPTH, 0], [0.0, -45.0, PASS_DEPTH, 0]],
	"верхом": [  # проём между плечами модели: строго по оси на глубине гребня, без спуска
		[0.0, 140.0, 30.0, 0], [0.0, 100.0, 35.0, 0], [0.0, -45.0, 35.0, 0], [0.0, 60.0, 35.0, 1]],
	"к стоянке 37b": [  # с гребня в жёлоб, разворот на оси, носом к гнезду купольника — встать; задним ходом обратно
		[0.0, 140.0, 30.0, 0], [0.0, 100.0, RIDGE_DEPTH, 0], [STAND_TURN[0], STAND_TURN[1], PASS_DEPTH, 0],
		[STAND[0], STAND[1], STAND[2], 0, STAND[3]],
		[STAND_TURN[0], STAND_TURN[1], PASS_DEPTH, 1], [0.0, 100.0, RIDGE_DEPTH, 1]],
}


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	print("Арка 07, середина (%.0f; %.0f), пол %.1f м. Корпус с выступами %.1f × %.1f м (нос %.1f, корма +%.1f от точки хода), низ −%.1f, верх +%.1f м." % [
			EcoGate.CENTER.x, EcoGate.CENTER.y, -GateArch.floor_y(), HULL_BACK - HULL_FRONT, HULL_HALF_W * 2.0,
			HULL_FRONT, HULL_BACK, HULL_DOWN, HULL_UP])
	print("Ход — шагом Helm.Ship.update (%.1f с), зазор под днищем %.0f м, тяга вперёд %.1f, течения нет." % [DT, Helm.Ship.CLEARANCE, THRUST])
	var all := {}
	for run_name: String in RUNS:
		if kv.has("run") and kv["run"] != run_name:
			continue
		var r := drive(RUNS[run_name])
		all[run_name] = r
		print_run(run_name, r)
	if kv.has("png"):
		plan_image(all).save_png(kv["png"])
		print("\nПлан: %s" % kv["png"])
	quit()


## Корабль как в игре у арки: дно `Seabed.height`, твёрдое — арка.
static func make_ship() -> Helm.Ship:
	var s := Helm.Ship.new()
	s.ground = Seabed.height
	s.solid = GateArch.hits
	return s


static func world(dx: float, dz: float, depth: float) -> Vector3:
	return Vector3(EcoGate.CENTER.x + dx, -depth, EcoGate.CENTER.y + dz)


## Прогон по точкам: шаги корабля до последней точки. Итог: "samples" — каждый шаг (at, yaw, speed, floor — нижний
## предел, ground — зазор грунта под днищем, arch — зазор до арки, bump, stuck), "done" — точки взяты,
## "legs" — время отрезков, с; сводка — "bumps", "stuck", "min_ground", "min_arch", "min_floor" (запас над пределом),
## "held" — шаги, где поворот откатился у твёрдого, "slid" — шаги со сдвигом вдоль твёрдого; "stands" — стоянки:
## at, yaw, t — время от начала отрезка до остановки, arch — зазор до арки на стоянке.
static func drive(points: Array) -> Dictionary:
	var ship := make_ship()
	var probe := Sounding.new()
	var p0: Array = points[0]
	var p1: Array = points[1]
	ship.pos = world(p0[0], p0[1], p0[2])
	var first := Vector2(p1[0] - p0[0], p1[1] - p0[1])
	if first.length() < 0.5 and points.size() > 2:
		first = Vector2(points[2][0] - p0[0], points[2][1] - p0[1])
		if first.length() < 0.5:
			first = Vector2(0.0, -1.0)
		elif int(points[2][3]) == 1:
			first = -first
	elif int(p1[3]) == 1:
		first = -first
	ship.yaw = atan2(-first.x, -first.y)
	var out := {"samples": [], "done": true, "legs": [], "bumps": 0, "stuck": 0.0, "min_ground": INF, "min_arch": INF,
			"min_floor": INF, "path": 0.0, "held": 0, "slid": 0, "stands": []}
	probe.at(ship.pos, ship.yaw)
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		var from := world(a[0], a[1], a[2])
		var to := world(b[0], b[1], b[2])
		var length := Vector2(to.x - from.x, to.z - from.z).length()
		var back := int(b[3]) == 1
		var park := b.size() > 4
		var park_yaw := deg_to_rad(float(b[4])) if park else 0.0
		var parked := false
		var limit := length / 1.0 + 90.0
		var t := 0.0
		while t < limit:
			var d := Vector2(to.x - ship.pos.x, to.z - ship.pos.z)
			var k := 1.0 if length < 0.5 else clampf(1.0 - d.length() / length, 0.0, 1.0)
			# предел под корпусом сейчас — промер прошлого шага (`probe`); на месте «через LOOK с» — он же
			var ahead := ship.pos + ship.nose() * ship.speed * LOOK
			var keep := maxf(probe.floor_y, probe.floor_y if ahead == ship.pos else probe.ship.floor_at(ahead, ship.yaw)) + KEEL
			var want_y := maxf(lerpf(from.y, to.y, k), keep)
			var hover := length < 0.5   # отрезок-стоянка: только глубина, без руля
			if park:
				var yaw_err := wrapf(park_yaw - ship.yaw, -PI, PI)
				if d.length() < PARK and absf(ship.speed) < PARK_SPEED and absf(yaw_err) < PARK_YAW \
						and absf(ship.pos.y - to.y) < DEPTH_OK:
					parked = true
					break
			elif (hover and absf(ship.pos.y - to.y) < DEPTH_OK) or (not hover and d.length() < ARRIVE):
				break
			var near_xz := hover
			ship.in_vert = clampf((want_y - ship.pos.y) * 0.8, -1.0, 1.0)
			if near_xz:
				ship.in_thrust = 0.0
				ship.in_turn = 0.0
			elif park:
				# далеко — нос на точку; у точки — курс стоянки, ход — по остатку пути вдоль носа (перелёт — задним)
				var along := d.dot(Vector2(ship.nose().x, ship.nose().z))
				var close := d.length() < PARK * 4.0
				var aim := park_yaw if close else atan2(-d.x, -d.y)
				var err := wrapf(aim - ship.yaw, -PI, PI)
				ship.in_turn = clampf(-err * 3.0, -1.0, 1.0)
				var want_v := 0.0 if (absf(err) > AIM and not close) else clampf(along * PARK_K, -1.5, THRUST * Helm.Ship.FORWARD / Helm.Ship.DRAG)
				ship.in_thrust = clampf((want_v - ship.speed) * 1.5, -1.0, 1.0)
			else:
				var aim := atan2(d.x, d.y) if back else atan2(-d.x, -d.y)
				var err := wrapf(aim - ship.yaw, -PI, PI)
				ship.in_turn = clampf(-err * 3.0, -1.0, 1.0)
				ship.in_thrust = 0.0 if absf(err) > AIM else (-1.0 if back else THRUST)
			var was := ship.pos
			ship.update(DT)
			t += DT
			var moved := Vector2(ship.pos.x - was.x, ship.pos.z - was.z).length()
			var straight := was + ship.nose() * ship.speed * DT
			if ship.in_turn != 0.0 and ship.turn == 0.0:
				out["held"] += 1   # поворот завёл бы корпус в твёрдое — курс откатился (#1847)
			elif Vector2(ship.pos.x - straight.x, ship.pos.z - straight.z).length() > SLIDE:
				out["slid"] += 1
			var stuck := absf(ship.speed) > 0.5 and moved < absf(ship.speed) * DT * 0.3
			out["path"] += moved
			probe.at(ship.pos, ship.yaw)
			var fl := probe.floor_y
			var s := {"at": ship.pos, "yaw": ship.yaw, "speed": ship.speed, "floor": fl, "ground": probe.gap,
					"arch": arch_gap(ship.pos, ship.yaw), "bump": ship.bump, "stuck": stuck, "leg": i, "s": out["path"]}
			out["samples"].append(s)
			if ship.bump > 0.0:
				out["bumps"] += 1
			if stuck:
				out["stuck"] += DT
			out["min_ground"] = minf(out["min_ground"], s["ground"])
			out["min_arch"] = minf(out["min_arch"], s["arch"])
			out["min_floor"] = minf(out["min_floor"], ship.pos.y - fl)
		out["legs"].append(t)
		if parked:
			out["stands"].append({"at": ship.pos, "yaw": ship.yaw, "t": t, "arch": arch_gap(ship.pos, ship.yaw)})
		if t >= limit:
			out["done"] = false
			break
	out["end"] = ship.pos
	return out


## Промер под корпусом за один проход по точкам днища: нижний предел хода `floor_y` (`Helm.Ship.floor_at`) и зазор
## грунта под днищем `gap` (как `ground_gap`) — по тем же высотам дна. Высоты записывает `ground` промерного корабля:
## `floor_at` спрашивает дно раз на точку `foot()`, по порядку. Раньше шаг прогона считал дно под корпусом трижды
## (предел до шага, предел после, зазор) — промер после шага служит и следующему шагу.
class Sounding extends RefCounted:
	var ship := Helm.Ship.new()
	var floor_y := 0.0
	var gap := INF
	var _seen := PackedFloat64Array()

	func _init() -> void:
		ship.ground = _ground

	func _ground(x: float, z: float) -> float:
		var h := Seabed.height(x, z)
		_seen.append(h)
		return h

	func at(pos: Vector3, yaw: float) -> void:
		_seen.clear()
		floor_y = ship.floor_at(pos, yaw)
		var feet := Helm.Ship.foot()
		gap = INF
		if _seen.size() == feet.size():
			for i in feet.size():
				gap = minf(gap, pos.y + feet[i].y - _seen[i])
			return
		var c := cos(yaw)   # `floor_at` спросил дно иначе — зазор отдельным проходом, как `ground_gap`
		var sn := sin(yaw)
		for q in feet:
			gap = minf(gap, pos.y + q.y - Seabed.height(pos.x + q.x * c + q.z * sn, pos.z - q.x * sn + q.z * c))


## Разворот на месте из стоянки: руль до упора в сторону `dir` (+1 — влево, `rotation.y` растёт), без хода, до
## полного круга или пока курс не встанет (откат у твёрдого #1847 или стена дна под корпусом). Итог — на сколько
## градусов повернул (360 — круг свободен).
static func swing(pos: Vector3, yaw: float, dir: float) -> float:
	var ship := make_ship()
	ship.pos = pos
	ship.yaw = yaw
	var turned := 0.0
	var still := 0
	while turned < TAU and still < 30:
		var was := ship.yaw
		ship.in_turn = -dir
		ship.in_vert = clampf((pos.y - ship.pos.y) * 0.8, -1.0, 1.0)
		ship.update(DT)
		var step := absf(wrapf(ship.yaw - was, -PI, PI))
		turned += step
		still = still + 1 if step < 1e-5 else 0
	return minf(rad_to_deg(turned), 360.0)


## Наименьший зазор грунта под днищем: низ корпуса в точках `Helm.Ship.foot()` минус дно под ними, м.
static func ground_gap(pos: Vector3, yaw: float) -> float:
	var c := cos(yaw)
	var sn := sin(yaw)
	var gap := INF
	for q in Helm.Ship.foot():
		var wx := pos.x + q.x * c + q.z * sn
		var wz := pos.z - q.x * sn + q.z * c
		gap = minf(gap, pos.y + q.y - Seabed.height(wx, wz))
	return gap


## Точки контура корпуса с выступами в мире (x, z) через ≈ 1 м.
static func outline(pos: Vector3, yaw: float) -> PackedVector2Array:
	var c := cos(yaw)
	var sn := sin(yaw)
	var out := PackedVector2Array()
	var local: Array[Vector2] = []
	var z := HULL_FRONT
	while z <= HULL_BACK + 0.01:
		local.append(Vector2(-HULL_HALF_W, z))
		local.append(Vector2(HULL_HALF_W, z))
		z += 1.0
	var x := -HULL_HALF_W
	while x <= HULL_HALF_W + 0.01:
		local.append(Vector2(x, HULL_FRONT))
		local.append(Vector2(x, HULL_BACK))
		x += 1.0
	for q in local:
		out.append(Vector2(pos.x + q.x * c + q.y * sn, pos.z - q.x * sn + q.y * c))
	return out


## Наименьшее расстояние по горизонтали от контура корпуса до блоков арки, которые корпус достаёт по высоте
## (от −`HULL_DOWN` до +`HULL_UP` от центра), м; блоков на этой высоте нет или арка далеко — INF; минус — внутри блока.
static func arch_gap(pos: Vector3, yaw: float) -> float:
	var q := GateArch.local(pos)
	if absf(q.x) > 120.0 or absf(q.z) > 80.0:
		return INF
	var gap := INF
	var pts := outline(pos, yaw)
	for b: AABB in GateArch.boxes():
		if q.y + HULL_UP <= b.position.y or q.y - HULL_DOWN >= b.end.y:
			continue
		for w in pts:
			var lx := w.x - EcoGate.CENTER.x
			var lz := w.y - EcoGate.CENTER.y
			var ex := maxf(b.position.x - lx, lx - b.end.x)
			var ez := maxf(b.position.z - lz, lz - b.end.z)
			gap = minf(gap, maxf(ex, ez) if ex < 0.0 and ez < 0.0 else Vector2(maxf(ex, 0.0), maxf(ez, 0.0)).length())
	return gap


static func print_run(run_name: String, r: Dictionary) -> void:
	print("\n«%s»: %s, путь %.0f м за %.0f с. Удары о дно: %d; упор под тягой: %.1f с." % [run_name,
			"дошёл" if r["done"] else "НЕ ДОШЁЛ (отрезок %d)" % r["legs"].size(), r["path"],
			r["samples"].size() * DT, r["bumps"], r["stuck"]])
	print("  наименьшие: грунт под днищем %.1f м, до блоков арки %s, запас над нижним пределом хода %.1f м." % [
			r["min_ground"], "—" if r["min_arch"] == INF else "%.1f м" % r["min_arch"], r["min_floor"]])
	print("  откаты поворота у твёрдого: %d шаг., сдвиги вдоль твёрдого: %d шаг." % [r["held"], r["slid"]])
	var nest := GateDiag.nest_pos(EcoDome.NEST)
	for st: Dictionary in r["stands"]:
		var sq := GateArch.local(st["at"])
		var at: Vector3 = st["at"]
		print("  стоянка: встал за %.0f с в (%+.1f; %+.1f), мир (%.1f; %.1f), глубина %.1f м, курс %+.1f°; до арки %.1f м, от центра до гнезда купольника %.1f м." % [
				st["t"], sq.x, sq.z, at.x, at.z, -at.y, rad_to_deg(st["yaw"]), st["arch"],
				Vector2(nest.x - at.x, nest.z - at.z).length()])
		print("  разворот на месте со стоянки: влево %.0f°, вправо %.0f° (360 — полный круг)." % [
				swing(at, st["yaw"], 1.0), swing(at, st["yaw"], -1.0)])
	print("  путь, м | (dx; dz) | глубина, м | курс, ° | предел хода, м | грунт под днищем, м | до арки, м | ход, м/с")
	var next := 0.0
	var last: Dictionary = r["samples"][-1]
	var hit := 0.0
	var stuck := false
	for s: Dictionary in r["samples"]:
		hit = maxf(hit, s["bump"])
		stuck = stuck or s["stuck"]
		if s["s"] < next and s != last:
			continue
		next = s["s"] + EVERY
		var q := GateArch.local(s["at"])
		print("  %4.0f | (%+.0f; %+.0f) | %.1f | %+.0f | %.1f | %.1f | %s | %+.1f%s%s" % [s["s"], q.x, q.z, -s["at"].y,
				rad_to_deg(s["yaw"]), -s["floor"], s["ground"], "—" if s["arch"] == INF else "%.1f" % s["arch"], s["speed"],
				" — УДАР до %.2f м" % hit if hit > 0.0 else "", " — УПОР" if stuck else ""])
		hit = 0.0
		stuck = false


## План: 1 пиксель — 0,5 м, окно dx −175…+85, dz −75…+165 (север вверху). Дно — оттенком по глубине, блоки арки
## ниже верха прохода — тёмным, контур корпуса каждые 6 с и след центра — цветом прогона.
static func plan_image(runs: Dictionary) -> Image:
	var x0 := -175.0
	var z0 := -75.0
	var px := 2.0
	var w := int(260.0 * px)
	var h := int(240.0 * px)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for iy in h:
		for ix in w:
			var dx := x0 + ix / px
			var dz := z0 + iy / px
			var depth := -Seabed.height(EcoGate.CENTER.x + dx, EcoGate.CENTER.y + dz)
			var k := clampf((depth - 30.0) / 40.0, 0.0, 1.0)
			var col := Color(0.86, 0.9, 0.9).lerp(Color(0.2, 0.36, 0.5), k)
			if fmod(depth, 5.0) < 0.25:
				col = col.darkened(0.25)   # горизонтали через 5 м
			img.set_pixel(ix, iy, col)
	for b: AABB in GateArch.boxes():
		if b.position.y >= GateArch.PASS_TOP:
			continue
		for iy in range(int((b.position.z - z0) * px), int((b.end.z - z0) * px)):
			for ix in range(int((b.position.x - x0) * px), int((b.end.x - x0) * px)):
				if ix >= 0 and ix < w and iy >= 0 and iy < h:
					img.set_pixel(ix, iy, Color(0.12, 0.1, 0.1))
	var colors: Array[Color] = [Color(0.9, 0.2, 0.15), Color(0.95, 0.75, 0.1), Color(0.1, 0.7, 0.25), Color(0.75, 0.2, 0.85)]
	var n := 0
	for run_name: String in runs:
		var col := colors[n % colors.size()]
		n += 1
		var i := 0
		for s: Dictionary in runs[run_name]["samples"]:
			var q := GateArch.local(s["at"])
			_dot(img, (q.x - x0) * px, (q.z - z0) * px, col, 1)
			if i % 60 == 0:
				for o in outline(s["at"], s["yaw"]):
					_dot(img, (o.x - EcoGate.CENTER.x - x0) * px, (o.y - EcoGate.CENTER.y - z0) * px, col, 0)
			i += 1
	return img


static func _dot(img: Image, x: float, y: float, col: Color, r: int) -> void:
	for oy in range(-r, r + 1):
		for ox in range(-r, r + 1):
			var ix := int(x) + ox
			var iy := int(y) + oy
			if ix >= 0 and ix < img.get_width() and iy >= 0 and iy < img.get_height():
				img.set_pixel(ix, iy, col)
