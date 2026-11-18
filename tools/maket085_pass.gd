extends SceneTree
## Проход врат 07 (48 × 22 м) моделью-макетом ART-085 v3 (28 × 10 × 9 м) — критерий владельца 17.11 (#1788):
## «весь корпус с выступающими частями: проход 07, наклон, след разворота и выход/возврат по маршруту».
## Те же прогоны и тот же рулевой, что у `tools/gate_pass.gd` для нынешнего корпуса, — отчёты сопоставимы.
## Корпус макета — `tools/maket085.gd` (контур по листам v3, выступы внутри контура). Ход — шагом
## `Helm.Ship.update` (разгон, поворот, погружение — как в игре); предел хода — по днищу макета
## (`Maket085.floor_at`, зазор 3 м под полозьями, как на листе 04 v3), твёрдое — блоки арки против точек
## поверхности макета (`Maket085.arch_hits`). Наклон корпуса (тангаж до ±25° по `HullMesh.Motion`) физику
## не меняет (в игре так же), но замеряется: зазор до арки считается и для наклонённого корпуса.
## Headless, без узлов и живого мира. Ничего не переставляет — только отчёт.
##   godot --headless --path . -s tools/maket085_pass.gd [-- png=<файл плана> run=<имя прогона>]

const Maket := preload("res://tools/maket085.gd")

const DT := 0.1
const EVERY := 10.0
const ARRIVE := 3.0          ## м — точка взята
const DEPTH_OK := 0.6        ## м — глубина точки взята (стоянка с погружением)
const THRUST := 0.6          ## тяга рулевого вперёд, назад — полная (как gate_pass)
const AIM := 0.3             ## рад — круче этого рулевой сперва доворачивает на месте
const PASS_DEPTH := 58.0     ## проектное сечение уровней: центр корабля в проходе, м
const RIDGE_DEPTH := 38.0    ## ход над гребнем, м
const KEEL := 1.0            ## м — рулевой держится не ближе этого к нижнему пределу хода (как gate_pass)
const LOOK := 2.5
const PARK := 0.5
const PARK_SPEED := 0.15
const PARK_YAW := 0.02
const PARK_K := 0.4

## Стоянка кадра 37b у гнезда купольника и точка разворота перед ней — как в gate_pass (#1757).
## Стоянка по глубине 62 м макету недоступна: дно у гнезда ≈ −66 м, полозья на −5 м от точки хода,
## зазор 3 м → предел хода ≈ 58 м (замерено 58.3). Поэтому второй прогон — та же точка и курс
## на достижимой глубине 57.5 м: проверяет подход, парковку и след разворота корпуса макета.
const STAND := [23.1, 24.5, 62.0, -63.0]
const STAND_M := [23.1, 24.5, 57.5, -63.0]
## Соседняя точка уровней 18.11 (#1788): ≈ 4,85 м назад по линии «глаз — гнездо 0» от STAND_M,
## корабль мир (−81,2; −213,3), глубина палубы 57,5 м, курс −63°. Дальность до гнезда ≈ 21 м —
## расчётный запас до нижней кромки порта ≈ 3,4° (взгляд на гнездо ≈ 21,2°, предел 24,6°).
const STAND_L := [18.8, 26.7, 57.5, -63.0]
const STAND_TURN := [0.0, 36.3]

## Прогоны — как в gate_pass.gd: [dx, dz, глубина, задний ход (1/0)]; пятым числом — курс стоянки, °.
const RUNS := {
	"низом": [
		[0.0, 140.0, 30.0, 0], [0.0, 100.0, RIDGE_DEPTH, 0], [0.0, 25.0, PASS_DEPTH, 0],
		[0.0, -45.0, PASS_DEPTH, 0], [0.0, 25.0, PASS_DEPTH, 1], [0.0, 100.0, RIDGE_DEPTH, 1]],
	"07 → 08": [
		[0.0, 25.0, PASS_DEPTH, 0], [0.0, 25.0, RIDGE_DEPTH, 0], [-150.0, 30.0, 35.0, 0]],
	"08 → 07": [
		[-150.0, 30.0, 35.0, 0], [0.0, 25.0, RIDGE_DEPTH, 0], [0.0, 25.0, PASS_DEPTH, 0], [0.0, -45.0, PASS_DEPTH, 0]],
	"верхом": [
		[0.0, 140.0, 30.0, 0], [0.0, 100.0, 35.0, 0], [0.0, -45.0, 35.0, 0], [0.0, 60.0, 35.0, 1]],
	"к стоянке 37b": [
		[0.0, 140.0, 30.0, 0], [0.0, 100.0, RIDGE_DEPTH, 0], [STAND_TURN[0], STAND_TURN[1], PASS_DEPTH, 0],
		[STAND[0], STAND[1], STAND[2], 0, STAND[3]],
		[STAND_TURN[0], STAND_TURN[1], PASS_DEPTH, 1], [0.0, 100.0, RIDGE_DEPTH, 1]],
	"к стоянке 37b (глубина макета)": [
		[0.0, 140.0, 30.0, 0], [0.0, 100.0, RIDGE_DEPTH, 0], [STAND_TURN[0], STAND_TURN[1], PASS_DEPTH, 0],
		[STAND_M[0], STAND_M[1], STAND_M[2], 0, STAND_M[3]],
		[STAND_TURN[0], STAND_TURN[1], PASS_DEPTH, 1], [0.0, 100.0, RIDGE_DEPTH, 1]],
	"к точке уровней (57,5 м)": [
		[0.0, 140.0, 30.0, 0], [0.0, 100.0, RIDGE_DEPTH, 0], [STAND_TURN[0], STAND_TURN[1], PASS_DEPTH, 0],
		[STAND_L[0], STAND_L[1], STAND_L[2], 0, STAND_L[3]],
		[STAND_TURN[0], STAND_TURN[1], PASS_DEPTH, 1], [0.0, 100.0, RIDGE_DEPTH, 1]],
}


## Корабль макета: физика Helm.Ship, предел хода — по днищу макета (3 м под полозьями).
class MaketShip extends Helm.Ship:
	func floor_at(p: Vector3, y: float) -> float:
		return Maket.floor_at(p, y, ground)


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	print("Арка 07, середина (%.0f; %.0f), пол %.1f м. Макет ART-085 v3: габарит %.0f × %.0f × %.0f м (нос %.0f, корма +%.0f от точки хода, низ %.0f, верх %+.0f), зазор под полозьями %.0f м." % [
			EcoGate.CENTER.x, EcoGate.CENTER.y, -GateArch.floor_y(),
			Maket.STERN_Z - Maket.NOSE_Z, Maket.HALF_W * 2.0, Maket.TOP_Y - Maket.KEEL_Y,
			Maket.NOSE_Z, Maket.STERN_Z, Maket.KEEL_Y, Maket.TOP_Y, Maket.SKID_GAP])
	print("Ход — шагом Helm.Ship.update (%.1f с), тяга вперёд %.1f, течения нет. Наклон — HullMesh.Motion (до ±%.0f°), зазор до арки замерен и для наклонённого корпуса." % [
			DT, THRUST, HullMesh.Motion.MAX_PITCH])
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


static func make_ship() -> MaketShip:
	var s := MaketShip.new()
	s.ground = Seabed.height
	s.solid = func(p: Vector3, y: float) -> bool: return Maket.arch_hits(p, y)
	return s


static func world(dx: float, dz: float, depth: float) -> Vector3:
	return Vector3(EcoGate.CENTER.x + dx, -depth, EcoGate.CENTER.y + dz)


## Зазор грунта под днищем макета (точки keel), м.
static func ground_gap(ship: Helm.Ship) -> float:
	var c := cos(ship.yaw)
	var sn := sin(ship.yaw)
	var gap := INF
	for q in Maket.keel_points():
		var wx := ship.pos.x + q.x * c + q.z * sn
		var wz := ship.pos.z - q.x * sn + q.z * c
		gap = minf(gap, ship.pos.y + q.y - Seabed.height(wx, wz))
	return gap


## Прогон по точкам — управление как в gate_pass.drive, плюс замер наклона: тангаж по HullMesh.Motion
## (ввод тот же, что у корабля), зазор до арки — для прямого и наклонённого корпуса.
static func drive(points: Array) -> Dictionary:
	var ship := make_ship()
	var motion := HullMesh.Motion.new()
	var p0: Array = points[0]
	var p1: Array = points[1]
	ship.pos = world(p0[0], p0[1], p0[2])
	var first := Vector2(p1[0] - p0[0], p1[1] - p0[1])
	if first.length() < 0.5 and points.size() > 2:
		first = Vector2(points[2][0] - p0[0], points[2][1] - p0[1])
		if int(points[2][3]) == 1:
			first = -first
	elif int(p1[3]) == 1:
		first = -first
	ship.yaw = atan2(-first.x, -first.y)
	var out := {"samples": [], "done": true, "legs": [], "bumps": 0, "stuck": 0.0, "min_ground": INF,
			"min_arch": INF, "min_arch_tilt": INF, "max_pitch": 0.0, "min_floor": INF, "path": 0.0,
			"held": 0, "slid": 0, "stands": []}
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		var from := world(a[0], a[1], a[2])
		var to := world(b[0], b[1], b[2])
		var length := Vector2(to.x - from.x, to.z - from.z).length()
		var back := int(b[3]) == 1
		var park := b.size() > 4
		var park_yaw := deg_to_rad(float(b[4])) if park else 0.0
		var limit := length / 1.0 + 90.0
		var t := 0.0
		var parked := false
		while t < limit:
			var d := Vector2(to.x - ship.pos.x, to.z - ship.pos.z)
			var k := 1.0 if length < 0.5 else clampf(1.0 - d.length() / length, 0.0, 1.0)
			var ahead := ship.pos + ship.nose() * ship.speed * LOOK
			var keep := maxf(ship.floor_at(ship.pos, ship.yaw),
				ship.floor_at(ahead, ship.yaw) if ahead != ship.pos else -INF) + KEEL
			var want_y := maxf(lerpf(from.y, to.y, k), keep)
			var hover := length < 0.5
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
			motion.update(DT, ship.in_thrust, ship.in_vert, 1.0)
			t += DT
			var moved := Vector2(ship.pos.x - was.x, ship.pos.z - was.z).length()
			var straight := was + ship.nose() * ship.speed * DT
			if ship.in_turn != 0.0 and ship.turn == 0.0:
				out["held"] += 1
			elif Vector2(ship.pos.x - straight.x, ship.pos.z - straight.z).length() > 0.03:
				out["slid"] += 1
			var stuck := absf(ship.speed) > 0.5 and moved < absf(ship.speed) * DT * 0.3
			out["path"] += moved
			var fl := ship.floor_at(ship.pos, ship.yaw)
			var pitch := deg_to_rad(motion.pitch)
			var s := {"at": ship.pos, "yaw": ship.yaw, "speed": ship.speed, "floor": fl,
					"ground": ground_gap(ship), "arch": Maket.arch_gap(ship.pos, ship.yaw),
					"arch_tilt": Maket.arch_gap(ship.pos, ship.yaw, pitch), "pitch": motion.pitch,
					"bump": ship.bump, "stuck": stuck, "leg": i, "s": out["path"]}
			out["samples"].append(s)
			if ship.bump > 0.0:
				out["bumps"] += 1
			if stuck:
				out["stuck"] += DT
			out["min_ground"] = minf(out["min_ground"], s["ground"])
			out["min_arch"] = minf(out["min_arch"], s["arch"])
			out["min_arch_tilt"] = minf(out["min_arch_tilt"], s["arch_tilt"])
			out["max_pitch"] = maxf(out["max_pitch"], absf(motion.pitch))
			out["min_floor"] = minf(out["min_floor"], ship.pos.y - fl)
		out["legs"].append(t)
		if parked:
			out["stands"].append({"at": ship.pos, "yaw": ship.yaw, "t": t, "arch": Maket.arch_gap(ship.pos, ship.yaw)})
		if t >= limit:
			out["done"] = false
			break
	out["end"] = ship.pos
	return out


## Разворот на месте из стоянки корпусом макета (как gate_pass.swing): руль до упора, без хода,
## до полного круга или упора (откат курса у твёрдого). Сколько градусов удалось (360 — круг свободен).
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


static func print_run(run_name: String, r: Dictionary) -> void:
	print("\n«%s»: %s, путь %.0f м за %.0f с. Удары о дно: %d; упор под тягой: %.1f с." % [run_name,
			"дошёл" if r["done"] else "НЕ ДОШЁЛ (отрезок %d)" % r["legs"].size(), r["path"],
			r["samples"].size() * DT, r["bumps"], r["stuck"]])
	print("  наименьшие: грунт под днищем %.1f м, до блоков арки %s (с наклоном %s), запас над нижним пределом хода %.1f м." % [
			r["min_ground"], "—" if r["min_arch"] == INF else "%.1f м" % r["min_arch"],
			"—" if r["min_arch_tilt"] == INF else "%.1f м" % r["min_arch_tilt"], r["min_floor"]])
	print("  наибольший тангаж: %.1f°; откаты поворота у твёрдого: %d шаг., сдвиги вдоль твёрдого: %d шаг." % [
			r["max_pitch"], r["held"], r["slid"]])
	var nest := GateDiag.nest_pos(EcoDome.NEST)
	for st: Dictionary in r["stands"]:
		var sq := GateArch.local(st["at"])
		var at: Vector3 = st["at"]
		print("  стоянка: встал за %.0f с в (%+.1f; %+.1f), мир (%.1f; %.1f), глубина %.1f м, курс %+.1f°; до арки %.1f м, от центра до гнезда купольника %.1f м." % [
				st["t"], sq.x, sq.z, at.x, at.z, -at.y, rad_to_deg(st["yaw"]), st["arch"],
				Vector2(nest.x - at.x, nest.z - at.z).length()])
		print("  разворот на месте со стоянки: влево %.0f°, вправо %.0f° (360 — полный круг)." % [
				swing(at, st["yaw"], 1.0), swing(at, st["yaw"], -1.0)])
	print("  путь, м | (dx; dz) | глубина, м | курс, ° | тангаж, ° | предел хода, м | грунт, м | до арки, м | до арки с наклоном, м | ход, м/с")
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
		print("  %4.0f | (%+.0f; %+.0f) | %.1f | %+.0f | %+.1f | %.1f | %.1f | %s | %s | %+.1f%s%s" % [
				s["s"], q.x, q.z, -s["at"].y, rad_to_deg(s["yaw"]), s["pitch"], -s["floor"], s["ground"],
				"—" if s["arch"] == INF else "%.1f" % s["arch"],
				"—" if s["arch_tilt"] == INF else "%.1f" % s["arch_tilt"], s["speed"],
				" — УДАР до %.2f м" % hit if hit > 0.0 else "", " — УПОР" if stuck else ""])
		hit = 0.0
		stuck = false


## Контур макета в плане (x, z мира) через точки поверхности корпуса (проекция).
static func outline(pos: Vector3, yaw: float) -> PackedVector2Array:
	var c := cos(yaw)
	var sn := sin(yaw)
	var out := PackedVector2Array()
	var z := Maket.NOSE_Z
	while z <= Maket.STERN_Z + 0.01:
		var s := Maket.section(z)
		if s.x < 0.05:
			out.append(Vector2(pos.x, pos.z + (z * c)))
		else:
			for sx: float in [-1.0, 1.0]:
				var lx: float = sx * s.x
				out.append(Vector2(pos.x + lx * c + z * sn, pos.z - lx * sn + z * c))
		z += 0.5
	return out


## План: как gate_pass.plan_image — дно оттенком по глубине, блоки арки ниже верха прохода тёмным,
## контур макета каждые 6 с и след центра цветом прогона. 1 пиксель — 0,5 м, север вверху.
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
				col = col.darkened(0.25)
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
		var col: Color = colors[n % colors.size()]
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
