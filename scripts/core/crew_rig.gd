class_name CrewRig
## Модель экипажа MOD-012 (`docs/concept-art/ekipazh.md`) повторяет позу `Crew.Member.joints()`: позу считает `crew.gd`,
## здесь — только перенос на скелет Meshy (24 кости). Без узлов: на входе покой скелета (имена, родители, местные
## преобразования), на выходе — преобразования костей в осях корабля (корень модели стоит в нуле корабля).
## Руки и ноги — по двум костям с длинами модели (у модели руки короче, чем у `Crew`): середина кисти приходит
## в середину кисти фигуры (точку хвата), лодыжка — на ANKLE_LIFT над лодыжкой фигуры (у `Crew` лодыжка у пола, у модели — сустав на 0,13 м).
## Сгиб локтя и колена — в плоскости, куда смотрит сустав у фигуры, плечо и предплечье поворачиваются вместе
## (без перекрута на локте). Туловище, шея, голова и ключицы идут за тазом как в покое.

## Внешность: мужская и женская модели, обе ростом 1,8 м (`Crew.HEIGHT`).
const MODELS := ["res://models/ekipazh-muzhchina.glb", "res://models/ekipazh-zhenshchina.glb"]
const LOOK_NAMES := ["Мужчина", "Женщина"]
const ANKLE_LIFT := 0.11
## Середина кисти модели — в 8 см от запястья (у `Crew` — HAND/2): в неё приходит точка хвата фигуры.
const GRIP := 0.08
## Свой игрок: голова не рисуется (камера в ней).
const HIDE_HEAD := ["neck", "Head", "head_end", "headfront"]
## И верх груди: сидя наклон к штурвалу подносит его к камере.
const HIDE_CHEST := ["Spine"]
## Конечности: кость начала, середины, конца → суставы фигуры; куда сустав смотрит в покое (локоть назад, колено вперёд).
const LIMBS := [
	["LeftArm", "LeftForeArm", "LeftHand", "shoulder_l", "elbow_l", "wrist_l", "arm"],
	["RightArm", "RightForeArm", "RightHand", "shoulder_r", "elbow_r", "wrist_r", "arm"],
	["LeftUpLeg", "LeftLeg", "LeftFoot", "hip_l", "knee_l", "ankle_l", "leg"],
	["RightUpLeg", "RightLeg", "RightFoot", "hip_r", "knee_r", "ankle_r", "leg"],
]
## Ключица тянется к цели, если рука не достаёт (руки модели короче, чем у `Crew`): не больше CLAVICLE_MAX рад.
const CLAVICLE_MAX := 0.7
## Сидя грудь наклонена к штурвалу ещё на столько (рад): иначе короткие руки модели не достают обода.
const SEAT_BEND := 0.2
## Ступня фигуры стоя: от лодыжки к носку (Crew.Member.joints) — от неё считается поворот ступни модели.
const FOOT_REST := Vector3(0.0, -0.03, -0.16)


## Базис с осью y вдоль dir и осью z, как можно ближе к ref.
static func frame(dir: Vector3, ref: Vector3) -> Basis:
	var y := dir.normalized() if dir.length() > 1e-6 else Vector3.UP
	var z := ref - y * ref.dot(y)
	if z.length() < 1e-5:
		z = Vector3.BACK - y * y.z if absf(y.z) < 0.9 else Vector3.RIGHT - y * y.x
	z = z.normalized()
	return Basis(y.cross(z), y, z)


## Поворот, переводящий направление a (с опорой ra) в направление b (с опорой rb).
static func turn(a: Vector3, ra: Vector3, b: Vector3, rb: Vector3) -> Basis:
	return frame(b, rb) * frame(a, ra).transposed()


## Куда смотрит средний сустав m относительно прямой s–e; почти прямая конечность — fallback.
static func pole(s: Vector3, m: Vector3, e: Vector3, fallback: Vector3) -> Vector3:
	var d := (e - s).normalized()
	var p := m - s
	p -= d * p.dot(d)
	return p + fallback * 0.02


## Покой скелета модели.
class Rest:
	extends RefCounted
	var names: PackedStringArray
	var parents: PackedInt32Array
	var local: Array[Transform3D] = []
	var global: Array[Transform3D] = []

	func _init(n: PackedStringArray, p: PackedInt32Array, l: Array[Transform3D]) -> void:
		names = n
		parents = p
		local = l
		for i in n.size():
			global.append(l[i] if p[i] < 0 else global[p[i]] * l[i])

	func idx(n: String) -> int:
		return names.find(n)

	func at(n: String) -> Vector3:
		return global[idx(n)].origin


## Преобразования всех костей в осях корабля для суставов j (Crew.Member.joints()). Родитель идёт раньше ребёнка.
## bend — наклон груди вперёд (рад) сверх наклона фигуры: сидя пилот тянется к штурвалу (SEAT_BEND).
static func pose(rest: Rest, j: Dictionary, bend: float = 0.0) -> Array[Transform3D]:
	var fwd: Vector3 = j["fwd"]
	var up: Vector3 = j["up"]
	var torso := turn(Vector3.UP, Vector3.FORWARD, up, fwd)
	var hc := (rest.at("LeftUpLeg") + rest.at("RightUpLeg")) * 0.5
	## Повороты конечностей: имя кости → базис поворота от покоя.
	var rot := {}
	var g: Array[Transform3D] = []
	g.resize(rest.names.size())
	for i in rest.names.size():
		var n := rest.names[i]
		var p := rest.parents[i]
		var rg := rest.global[i]
		if p < 0:
			g[i] = Transform3D(torso * rg.basis, j["hip"] + torso * (rg.origin - hc))
			continue
		var o: Vector3 = g[p] * rest.local[i].origin
		var b: Basis = g[p].basis * rest.local[i].basis
		if n == "Spine01" and bend != 0.0:
			b = Basis(up.cross(fwd).normalized(), bend) * b
		for limb in LIMBS:
			if n == limb[0]:
				_limb(rest, j, limb, o, fwd, rot)
		if n == "LeftShoulder" or n == "RightShoulder":
			b = _clavicle(rest, j, n, o, b)
		if rot.has(n):
			b = rot[n] * rg.basis
		elif n.ends_with("Foot"):
			var k := "l" if n.begins_with("Left") else "r"
			b = turn(FOOT_REST, Vector3.UP, j["toe_" + k] - j["ankle_" + k], Vector3.UP) * rg.basis
		g[i] = Transform3D(b.orthonormalized(), o)
	return g


## Конечность по двум костям модели от её начала s: середина и конец — к суставам фигуры.
static func _limb(rest: Rest, j: Dictionary, limb: Array, s: Vector3, fwd: Vector3, rot: Dictionary) -> void:
	var r0 := rest.at(limb[0])
	var r1 := rest.at(limb[1])
	var r2 := rest.at(limb[2])
	var arm: bool = limb[6] == "arm"
	var js: Vector3 = j[limb[3]]
	var jm: Vector3 = j[limb[4]]
	var je: Vector3 = j[limb[5]]
	var target := _arm_target(j, str(limb[5]).right(1)) if arm else je + Vector3.UP * ANKLE_LIFT
	var back := -fwd if arm else fwd
	var mid := Crew.two_bone(s, target, r0.distance_to(r1), r1.distance_to(r2), jm - (js + je) * 0.5 + back * 0.02)
	var pr := pole(r0, r1, r2, Vector3.BACK if arm else Vector3.FORWARD)
	var pt := pole(s, mid[0], mid[1], back)
	rot[limb[0]] = turn(r1 - r0, pr, mid[0] - s, pt)
	rot[limb[1]] = turn(r2 - r1, pr, mid[1] - mid[0], pt)
	if arm:
		var hand_k: String = "hand_" + str(limb[5]).right(1)
		rot[limb[2]] = turn(r2 - r1, pr, j[hand_k] - je, pt)


## Куда прийти запястью модели: середина кисти модели — в точку хвата фигуры (штурвал, резак) или в середину
## её кисти.
static func _arm_target(j: Dictionary, k: String) -> Vector3:
	var je: Vector3 = j["wrist_" + k]
	var hd: Vector3 = j["hand_" + k] - je
	return j.get("grip_" + k, je + hd * 0.5) - hd.normalized() * GRIP


## Ключица n с началом o и базисом b: если рука от плеча не достаёт до цели, ключица поворачивается к цели.
static func _clavicle(rest: Rest, j: Dictionary, n: String, o: Vector3, b: Basis) -> Basis:
	var left := n.begins_with("Left")
	var arm := "LeftArm" if left else "RightArm"
	var fore := "LeftForeArm" if left else "RightForeArm"
	var hand := "LeftHand" if left else "RightHand"
	var reach := rest.at(arm).distance_to(rest.at(fore)) + rest.at(fore).distance_to(rest.at(hand))
	var target := _arm_target(j, "l" if left else "r")
	var loc: Vector3 = rest.local[rest.idx(arm)].origin
	var total := 0.0
	for it in 4:  # поворот за поворотом: малый угол недооценивает сдвиг
		var v: Vector3 = b * loc
		var short := (o + v).distance_to(target) - (reach - 0.01)
		var axis := v.cross(target - o)
		if short <= 0.0 or axis.length() < 1e-6 or total >= CLAVICLE_MAX:
			break
		var a := minf(short / v.length(), CLAVICLE_MAX - total)
		total += a
		b = Basis(axis.normalized(), a) * b
	return b
