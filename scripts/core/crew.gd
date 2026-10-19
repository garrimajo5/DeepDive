class_name Crew
## Экипаж: член экипажа как фигура из частей, которую видят другие и сам игрок (свои руки и ноги — взглядом вниз).
## Пока модели нет (концепт ART-014), фигура — капсулы по суставам; поза считается здесь, без узлов:
## стоит, идёт (шаг ног и рук), сидит в кресле пилота с руками на колесе штурвала (руки идут за поворотом колеса).
## Всё в осях корабля, метры; рост 1,8 м, глаза на высоте Deck.Walker.EYE.
## Для коопа: у каждого игрока свой `Member`, хост шлёт клиентам `snapshot()`, клиенты ставят `apply()`.

enum Role { PILOT, SONAR, ENGINEER, BIOLOGIST }
const ROLE_NAMES := ["Пилот", "Сонарщик", "Инженер", "Биолог"]
## Цвет роли — на груди и плечах костюма (временные, до концепта ART-014).
const ROLE_COLORS := [
	Color(0.89, 0.62, 0.22),  ## пилот — янтарный, как кнопка «Свет»
	Color(0.27, 0.76, 0.80),  ## сонарщик — бирюза голограммы
	Color(0.85, 0.36, 0.22),  ## инженер — оранжево-красный
	Color(0.45, 0.74, 0.36),  ## биолог — зелёный
]
const SUIT := Color(0.24, 0.27, 0.28)
const GLOVES := Color(0.13, 0.14, 0.15)
const HELMET := Color(0.78, 0.80, 0.76)
const VISOR := Color(0.10, 0.22, 0.26)

## Размеры (м). Таз (сустав бедра) — 0,92 над полом стоя; плечи на 0,56 выше таза; глаз — Walker.EYE.
const HEIGHT := 1.8
const HIP := 0.92
const HIP_HALF := 0.11
const TORSO := 0.56
const SHOULDER_HALF := 0.2
const THIGH := 0.46
const SHIN := 0.44
const UPPER_ARM := 0.31
const FOREARM := 0.27
const HAND := 0.1
const EYE_UP := Deck.Walker.EYE - HIP  ## от таза до глаз
## Шаг: полный цикл ног на 1,3 м пути, размах бедра ±0,45 рад, рук ±0,35 рад.
const STRIDE := 1.3
const LEG_SWING := 0.45
const ARM_SWING := 0.35
## Сидя: наклон к штурвалу; таз — seat_hip() (над сиденьем кресла ~0,5 м).
const SEAT_LEAN := 0.44  ## рад (≈25°)
## Хват колеса: точки на ободе ±55° от верха, радиус обода 0,25 м (MOD-002 Ø 0,55). Руки идут за колесом
## до 35°, дальше скользят по ободу (иначе не дотянуться).
const RIM := 0.25
const GRIP_DEG := 55.0
const GRIP_FOLLOW_DEG := 35.0

## Части фигуры в порядке экземпляров MultiMesh (голова и визор — 2 и 3: свой игрок их не рисует).
const ORDER := ["torso", "pelvis", "head", "visor", "arm_l", "arm_r", "fore_l", "fore_r", "hand_l", "hand_r",
	"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]


static func role_color(role: int) -> Color:
	return ROLE_COLORS[clampi(role, 0, ROLE_COLORS.size() - 1)]


static func part_color(part: String, role: int) -> Color:
	match part:
		"torso", "arm_l", "arm_r":
			return role_color(role)
		"head":
			return HELMET
		"visor":
			return VISOR
		"hand_l", "hand_r", "foot_l", "foot_r":
			return GLOVES
	return SUIT


## Высота таза сидя: так, чтобы глаза были на Deck.SEAT_EYE.
static func seat_hip() -> Vector3:
	return Vector3(0.0, Deck.SEAT_EYE - EYE_UP * cos(SEAT_LEAN), Deck.SEAT_Z + EYE_UP * sin(SEAT_LEAN))


## Точки хвата на ободе колеса в осях корабля: [левая, правая]; turn — Helm.Ship.turn (−1…1), как BridgeView.
static func wheel_grips(turn: float) -> Array[Vector3]:
	var b := Basis.from_euler(Vector3(deg_to_rad(BridgeProps.WHEEL_TILT), 0.0, 0.0)) \
		* Basis(Vector3.BACK, deg_to_rad(clampf(-turn * BridgeProps.WHEEL_TURN_DEG, -GRIP_FOLLOW_DEG, GRIP_FOLLOW_DEG)))
	var c := Vector3(0.0, BridgeProps.WHEEL_Y, BridgeProps.WHEEL_Z)
	var a := deg_to_rad(GRIP_DEG)
	return [c + b * Vector3(-RIM * sin(a), RIM * cos(a), 0.0), c + b * Vector3(RIM * sin(a), RIM * cos(a), 0.0)]


## Колено/локоть по двум длинам: от s к цели t, сгиб в сторону hint. Если цель дальше — рука вытянута к ней.
static func two_bone(s: Vector3, t: Vector3, a: float, b: float, hint: Vector3) -> Array[Vector3]:
	var v := t - s
	var d := v.length()
	var dir := v / d if d > 1e-5 else Vector3.DOWN
	d = clampf(d, absf(a - b) + 1e-3, a + b - 1e-3)
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var h := sqrt(maxf(a * a - x * x, 0.0))
	var side := hint - dir * hint.dot(dir)
	side = side.normalized() if side.length() > 1e-5 else Vector3.DOWN
	var mid := s + dir * x + side * h
	return [mid, s + dir * d]


## Преобразование части от сустава a до сустава b: ось y вдоль кости, длина и толщина — масштабом единичной капсулы
## (высота 1, радиус 0,5, центр в нуле). fwd — куда смотрит «перед» части (для ступни, визора).
static func bone(a: Vector3, b: Vector3, w: float, d: float, fwd: Vector3 = Vector3.FORWARD) -> Transform3D:
	var y := b - a
	var len := y.length()
	y = y / len if len > 1e-5 else Vector3.UP
	var z := -fwd
	var x := y.cross(z)
	if x.length() < 1e-4:
		x = y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT)
	x = x.normalized()
	z = x.cross(y).normalized()
	return Transform3D(Basis(x * w, y * len, z * d), (a + b) * 0.5)


## Член экипажа: место (ступни, оси корабля), курс, поза и фаза шага.
class Member:
	extends RefCounted
	var role := Role.PILOT
	var name := ""
	var x := 0.0
	var z := 0.0
	var yaw := 0.0
	var seated := false
	var wheel_turn := 0.0
	var phase := 0.0  ## фаза шага, рад
	var swing := 0.0  ## 0 — стоит, 1 — идёт полным ходом
	var _last := Vector2.INF

	func _init(r: int = Role.PILOT, n: String = "") -> void:
		role = r
		name = n if n != "" else ROLE_NAMES[r]

	## Шаг позы: место и курс игрока; шаг ног — по пройденному пути.
	func follow(px: float, pz: float, pyaw: float, is_seated: bool, turn: float, dt: float) -> void:
		var p := Vector2(px, pz)
		var moved := 0.0 if _last == Vector2.INF or is_seated != seated else p.distance_to(_last)
		_last = p
		x = px
		z = pz
		yaw = pyaw
		seated = is_seated
		wheel_turn = turn
		phase = wrapf(phase + moved / STRIDE * TAU, 0.0, TAU)
		var want := clampf(moved / maxf(dt, 1e-4) / Deck.Walker.SPEED, 0.0, 1.0) if not seated else 0.0
		swing = move_toward(swing, want, dt * 6.0)
		if swing < 0.02 and want == 0.0:
			phase = move_toward(phase, PI if phase > PI * 0.5 and phase < PI * 1.5 else (0.0 if phase < PI else TAU), dt * 4.0)

	## Глаз фигуры в осях корабля (у своего игрока совпадает с камерой).
	func eye() -> Vector3:
		if seated:
			return Vector3(0.0, Deck.SEAT_EYE, Deck.SEAT_Z)
		return Vector3(x, Deck.Walker.EYE, z)

	## Суставы в осях корабля: hip, neck, head, shoulder_l/r, elbow_l/r, wrist_l/r, hand_l/r, knee_l/r, ankle_l/r, toe_l/r.
	func joints() -> Dictionary:
		var j := {}
		var fwd: Vector3
		var right: Vector3
		var hip: Vector3
		var up: Vector3
		if seated:
			fwd = Vector3.FORWARD
			right = Vector3.RIGHT
			hip = Crew.seat_hip()
			up = Vector3(0.0, cos(SEAT_LEAN), -sin(SEAT_LEAN))
		else:
			fwd = Vector3(-sin(yaw), 0.0, -cos(yaw))
			right = Vector3(cos(yaw), 0.0, -sin(yaw))
			hip = Vector3(x, HIP - 0.03 * swing * absf(cos(phase)), z)
			up = Vector3.UP
		j["hip"] = hip
		var neck := hip + up * TORSO
		j["neck"] = neck
		j["head"] = hip + up * EYE_UP - fwd * 0.04
		for side in 2:
			var s := -1.0 if side == 0 else 1.0
			var k := "l" if side == 0 else "r"
			var sh := neck + right * (SHOULDER_HALF * s) - up * 0.04
			j["shoulder_" + k] = sh
			var hp := hip + right * (HIP_HALF * s)
			j["hip_" + k] = hp
			if seated:
				var grip: Vector3 = Crew.wheel_grips(wheel_turn)[side]
				var arm := Crew.two_bone(sh, grip, UPPER_ARM, FOREARM + HAND * 0.5, Vector3.DOWN + right * s * 0.6)
				j["elbow_" + k] = arm[0]
				var wrist: Vector3 = arm[0] + (arm[1] - arm[0]).normalized() * FOREARM
				j["wrist_" + k] = wrist
				j["hand_" + k] = wrist + (arm[1] - arm[0]).normalized() * HAND
				## Сидя: бедро вперёд чуть вниз, голень вниз и вперёд, ступня на подножке.
				var knee := hp + (fwd * cos(0.12) + Vector3.DOWN * sin(0.12)) * THIGH
				var ankle := knee + (Vector3.DOWN * cos(0.35) + fwd * sin(0.35)) * SHIN
				j["knee_" + k] = knee
				j["ankle_" + k] = ankle
				j["toe_" + k] = ankle + fwd * 0.16 + Vector3.DOWN * 0.04
			else:
				## Нога: бедро качается вперёд-назад, колено сгибается, когда нога идёт вперёд.
				var ph := phase + (0.0 if side == 0 else PI)
				var th := sin(ph) * LEG_SWING * swing
				var bend := maxf(0.0, cos(ph)) * 0.9 * swing + 0.04
				var tdir := Vector3.DOWN * cos(th) + fwd * sin(th)
				var knee := hp + tdir * THIGH
				var sa := th - bend
				var ankle := knee + (Vector3.DOWN * cos(sa) + fwd * sin(sa)) * SHIN
				j["knee_" + k] = knee
				j["ankle_" + k] = ankle
				j["toe_" + k] = ankle + fwd * 0.16 + Vector3.DOWN * 0.03
				## Рука качается против ноги своей стороны, локоть чуть согнут.
				var ah := -sin(ph) * ARM_SWING * swing
				var adir := Vector3.DOWN * cos(ah) + fwd * sin(ah) + right * (0.08 * s)
				var elbow := sh + adir.normalized() * UPPER_ARM
				var fa := ah + 0.15 + 0.25 * swing
				var wrist := elbow + (Vector3.DOWN * cos(fa) + fwd * sin(fa)).normalized() * FOREARM
				j["elbow_" + k] = elbow
				j["wrist_" + k] = wrist
				j["hand_" + k] = wrist + (wrist - elbow).normalized() * HAND
		j["fwd"] = fwd
		j["up"] = up
		return j

	## Части фигуры: имя → Transform3D единичной капсулы. own — свой игрок: без головы (камера в ней), а стоя ещё
	## без туловища, таза и плеч, чтобы взгляд вниз видел ноги, а не грудь вплотную; сидя видны руки на штурвале.
	func parts(own: bool = false) -> Dictionary:
		var j := joints()
		var fwd: Vector3 = j["fwd"]
		var up: Vector3 = j["up"]
		var out := {}
		var neck: Vector3 = j["neck"]
		var hip: Vector3 = j["hip"]
		var chest := not own or seated
		if chest:
			out["torso"] = Crew.bone(hip + up * 0.1, neck + up * 0.06, 0.34, 0.22, fwd)
		if chest:
			out["pelvis"] = Crew.bone(hip - up * 0.1, hip + up * 0.12, 0.3, 0.2, fwd)
		if not own:
			var head: Vector3 = j["head"]
			out["head"] = Crew.bone(head - up * 0.15, head + up * 0.15, 0.24, 0.26, fwd)
			out["visor"] = Crew.bone(head - up * 0.05 + fwd * 0.11, head + up * 0.06 + fwd * 0.11, 0.18, 0.06, fwd)
		for k in ["l", "r"]:
			if chest:
				out["arm_" + k] = Crew.bone(j["shoulder_" + k], j["elbow_" + k], 0.1, 0.1, fwd)
			out["fore_" + k] = Crew.bone(j["elbow_" + k], j["wrist_" + k], 0.085, 0.085, fwd)
			out["hand_" + k] = Crew.bone(j["wrist_" + k], j["hand_" + k], 0.08, 0.05, fwd)
			out["thigh_" + k] = Crew.bone(j["hip_" + k], j["knee_" + k], 0.14, 0.14, fwd)
			out["shin_" + k] = Crew.bone(j["knee_" + k], j["ankle_" + k], 0.11, 0.11, fwd)
			var ank: Vector3 = j["ankle_" + k]
			var toe: Vector3 = j["toe_" + k]
			out["foot_" + k] = Crew.bone(ank + Vector3.DOWN * 0.02 - (toe - ank) * 0.25, toe, 0.1, 0.08, Vector3.UP)
		return out

	## Снимок для сети: всё, что нужно клиенту, чтобы поставить фигуру.
	func snapshot() -> Dictionary:
		return {"role": role, "name": name, "x": x, "z": z, "yaw": yaw, "seated": seated,
			"turn": wheel_turn, "phase": phase, "swing": swing}

	func apply(s: Dictionary) -> void:
		role = int(s.get("role", role))
		name = str(s.get("name", name))
		x = float(s.get("x", x))
		z = float(s.get("z", z))
		yaw = float(s.get("yaw", yaw))
		seated = bool(s.get("seated", seated))
		wheel_turn = float(s.get("turn", wheel_turn))
		phase = float(s.get("phase", phase))
		swing = float(s.get("swing", swing))
		_last = Vector2(x, z)
