class_name Crew
## Экипаж: член экипажа как фигура из частей, которую видят другие и сам игрок (свои руки и ноги — взглядом вниз).
## Поза считается здесь, без узлов (модель MOD-012 её повторяет — `CrewRig`; `parts()` — та же поза капсулами):
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
## Резак MOD-013 (`models/rezak.glb`, docs/concept-art/proboina.md): pivot в хвате, сопло — (0; 0,177; −0,143) от него.
## При сварке правая рука держит резак так, чтобы сопло было в 6 см от шва; не дотянуться — рука вытянута к нему.
const TORCH_NOZZLE := Vector3(0.0, 0.1766, -0.1428)
const TORCH_GAP := 0.06
## Руки на посте далеко: фигура наклоняется к нему (от таза), не больше LEAN_MAX рад.
const LEAN_MAX := 0.75
## Шов ниже плеча: при сварке фигура приседает (таз ниже, колени вперёд), чтобы рука доставала. Не больше CROUCH_MAX.
const CROUCH_MAX := 0.3
const CROUCH_ARM_DROP := 0.35  ## на сколько хват может быть ниже плеча без приседа

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


## Точка для снимка: [x, y, z] или [] (INF — нет точки), и обратно.
static func _v3(p: Vector3) -> Array:
	return [p.x, p.y, p.z] if p.is_finite() else []


static func _from3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2]) if a.size() == 3 else Vector3.INF


## Член экипажа: место (ступни, оси корабля), курс, поза и фаза шага.
class Member:
	extends RefCounted
	var role := Role.PILOT
	var name := ""
	var look := 0  ## внешность: 0 — мужская модель, 1 — женская (CrewRig.MODELS); выбирает игрок
	var x := 0.0
	var z := 0.0
	var yaw := 0.0
	var seated := false
	var wheel_turn := 0.0
	var weld_at := Vector3.INF  ## точка сварки (пробоина, оси корабля) — правая рука с резаком к ней; INF — не варит
	var weld_n := Vector3.ZERO  ## нормаль борта в точке сварки (внутрь отсека)
	var hands: Array[Vector3] = [Vector3.INF, Vector3.INF]  ## руки на посте [левая, правая] (CrewHands); INF — свободна
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

	## Варит ли: правая рука с резаком у шва.
	func welding() -> bool:
		return weld_at.is_finite() and not seated

	## Начать или кончить сварку: точка шва p и нормаль n борта (внутрь отсека); p = INF — убрать резак.
	func weld(p: Vector3, n: Vector3 = Vector3.ZERO) -> void:
		weld_at = p
		weld_n = n

	## Руки на посте: точки хвата [левая, правая] в осях корабля (CrewHands), INF — рука свободна.
	func hold(l: Vector3 = Vector3.INF, r: Vector3 = Vector3.INF) -> void:
		hands = [l, r]

	## Держит ли что-то хоть одной рукой (пост или резак).
	func holding() -> bool:
		return welding() or hands[0].is_finite() or hands[1].is_finite()

	## Насколько присесть при сварке (м): шов ниже плеча стоя больше чем на CROUCH_ARM_DROP.
	func crouch() -> float:
		if not welding():
			return 0.0
		var sh_y := HIP + TORSO - 0.04
		return clampf(sh_y - torch_grip().y - CROUCH_ARM_DROP, 0.0, CROUCH_MAX)

	## Куда сопло смотрит при сварке — в борт, по горизонтали.
	func torch_dir() -> Vector3:
		var d := -weld_n
		d.y = 0.0
		return d.normalized() if d.length() > 1e-4 else Vector3.FORWARD

	## Где хват резака, если сопло у шва (без учёта длины руки).
	func torch_grip() -> Vector3:
		var b := Basis.looking_at(torch_dir(), Vector3.UP)
		return weld_at - torch_dir() * TORCH_GAP - b * TORCH_NOZZLE

	## Резак в правой руке: начало — хват (середина кисти), −Z — к борту, Y — вверх. Только когда варит.
	func torch_xform() -> Transform3D:
		var j := joints()
		var grip: Vector3 = (j["wrist_r"] + j["hand_r"]) * 0.5
		return Transform3D(Basis.looking_at(torch_dir(), Vector3.UP), grip)

	## Глаз фигуры в осях корабля (у своего игрока совпадает с камерой).
	func eye() -> Vector3:
		if seated:
			return Vector3(0.0, Deck.SEAT_EYE, Deck.SEAT_Z)
		return Vector3(x, Deck.Walker.EYE, z)

	## Суставы в осях корабля: hip, neck, head, shoulder_l/r, elbow_l/r, wrist_l/r, hand_l/r, knee_l/r, ankle_l/r, toe_l/r;
	## grip_l/r — точка хвата, если рука тянется к ней (штурвал, резак).
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
			hip = Vector3(x, HIP - 0.03 * swing * absf(cos(phase)) - crouch(), z)
			up = Vector3.UP
			if not welding() and holding():   # руки на посте: наклон к нему, пока не достанет
				up = Basis(Vector3.UP.cross(fwd).normalized(), _lean(hip, fwd, right)) * Vector3.UP
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
				_reach(j, k, sh, Crew.wheel_grips(wheel_turn)[side], right * s)
				## Сидя: бедро вперёд чуть вниз, голень вниз и вперёд, ступня на подножке.
				var knee := hp + (fwd * cos(0.12) + Vector3.DOWN * sin(0.12)) * THIGH
				var ankle := knee + (Vector3.DOWN * cos(0.35) + fwd * sin(0.35)) * SHIN
				j["knee_" + k] = knee
				j["ankle_" + k] = ankle
				j["toe_" + k] = ankle + fwd * 0.16 + Vector3.DOWN * 0.04
			else:
				var ph := phase + (0.0 if side == 0 else PI)
				if welding() and crouch() > 0.0:   # присед у шва: ступня на полу под бедром, колено вперёд
					var leg := Crew.two_bone(hp, Vector3(hp.x, 0.08, hp.z) + fwd * 0.08, THIGH, SHIN, fwd)
					j["knee_" + k] = leg[0]
					j["ankle_" + k] = leg[1]
					j["toe_" + k] = leg[1] + fwd * 0.16 + Vector3.DOWN * 0.05
				else:
					## Нога: бедро качается вперёд-назад, колено сгибается, когда нога идёт вперёд.
					var th := sin(ph) * LEG_SWING * swing
					var bend := maxf(0.0, cos(ph)) * 0.9 * swing + 0.04
					var tdir := Vector3.DOWN * cos(th) + fwd * sin(th)
					var knee := hp + tdir * THIGH
					var sa := th - bend
					var ankle := knee + (Vector3.DOWN * cos(sa) + fwd * sin(sa)) * SHIN
					j["knee_" + k] = knee
					j["ankle_" + k] = ankle
					j["toe_" + k] = ankle + fwd * 0.16 + Vector3.DOWN * 0.03
				if side == 1 and welding():
					_reach(j, k, sh, torch_grip(), right * s)
					continue
				if hands[side].is_finite():
					_reach(j, k, sh, hands[side], right * s)
					continue
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

	## Наклон к посту (рад): самый малый, при котором обе руки достают до точек хвата, не больше LEAN_MAX.
	func _lean(hip: Vector3, fwd: Vector3, right: Vector3) -> float:
		var axis := Vector3.UP.cross(fwd).normalized()
		var reach := UPPER_ARM + FOREARM + HAND * 0.5 - 0.02
		var a := 0.0
		while a < LEAN_MAX:
			var up := Basis(axis, a) * Vector3.UP
			var neck := hip + up * TORSO - up * 0.04
			var fits := true
			for side in 2:
				if hands[side].is_finite():
					var sh := neck + right * (SHOULDER_HALF * (-1.0 if side == 0 else 1.0))
					fits = fits and sh.distance_to(hands[side]) <= reach
			if fits:
				return a
			a += 0.05
		return LEAN_MAX

	## Рука k от плеча sh к точке хвата grip (середина кисти); локоть — вниз и наружу (out).
	func _reach(j: Dictionary, k: String, sh: Vector3, grip: Vector3, out: Vector3) -> void:
		var arm := Crew.two_bone(sh, grip, UPPER_ARM, FOREARM + HAND * 0.5, Vector3.DOWN + out * 0.6)
		j["elbow_" + k] = arm[0]
		var wrist: Vector3 = arm[0] + (arm[1] - arm[0]).normalized() * FOREARM
		j["wrist_" + k] = wrist
		j["hand_" + k] = wrist + (arm[1] - arm[0]).normalized() * HAND
		j["grip_" + k] = grip  ## куда тянется кисть (модель с другими длинами рук приходит сюда, CrewRig)

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
		return {"role": role, "name": name, "look": look, "x": x, "z": z, "yaw": yaw, "seated": seated,
			"turn": wheel_turn, "phase": phase, "swing": swing,
			"weld": [weld_at.x, weld_at.y, weld_at.z, weld_n.x, weld_n.y, weld_n.z] if weld_at.is_finite() else [],
			"hand_l": Crew._v3(hands[0]), "hand_r": Crew._v3(hands[1])}

	func apply(s: Dictionary) -> void:
		role = int(s.get("role", role))
		name = str(s.get("name", name))
		look = int(s.get("look", look))
		x = float(s.get("x", x))
		z = float(s.get("z", z))
		yaw = float(s.get("yaw", yaw))
		seated = bool(s.get("seated", seated))
		wheel_turn = float(s.get("turn", wheel_turn))
		phase = float(s.get("phase", phase))
		swing = float(s.get("swing", swing))
		var w: Array = s.get("weld", [])
		if w.size() == 6:
			weld(Vector3(w[0], w[1], w[2]), Vector3(w[3], w[4], w[5]))
		else:
			weld(Vector3.INF)
		hold(Crew._from3(s.get("hand_l", [])), Crew._from3(s.get("hand_r", [])))
		_last = Vector2(x, z)
