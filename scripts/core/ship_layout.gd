class_name ShipLayout
extends RefCounted
## Отсеки «Ковчега-7» за мостиком (js/ship.js, pogrujenie Core/ShipLayout.cs): коридор z 2…8, лаборатория 8…14,
## машинное 14…19,5, трюм 19,5…24; четыре люка в переборках. Отсеки симметричны по x — числа как в браузере.
## Мостик (z −6…2) — Deck и BridgePlan. Люки 1,4 × 2,1 м, как рама MOD-006 на мостике.

enum Room { BRIDGE, CORRIDOR, LAB, ENGINE, CARGO }

const ROOM_NAMES: Array[String] = ["Мостик", "Коридор", "Лаборатория", "Машинное отделение", "Трюм"]
const DOOR_Z: Array[float] = [2.0, 8.0, 14.0, 19.5]
const DOOR_HALF := BridgePlan.HATCH_HALF   ## полуширина проёма люка
const DOOR_H := BridgePlan.HATCH_H
## Отсек: z от, z до, полуширина, высота потолка.
const ROOMS := {
	Room.CORRIDOR: [2.0, 8.0, 1.1, 2.6],
	Room.LAB: [8.0, 14.0, 4.0, 3.4],
	Room.ENGINE: [14.0, 19.5, 3.0, 3.2],
	Room.CARGO: [19.5, 24.0, 2.5, 3.0],
}
## Реактор в машинном (ART-008, MOD-008): центр основания на полу.
const REACTOR_POS := Vector3(0.0, 0.0, 17.2)
const REACTOR_R := 1.05
## Окна лаборатории в обоих бортах: z 8,6+0,6…13,4−0,6 → 9,2…12,8, y 0,95…2,55.
const LAB_WINDOW := Rect2(9.2, 0.95, 3.6, 1.6)   ## (z, y, длина, высота)


## Люк в переборке: открывается за ~0,55 с, проходим, когда открыт больше чем на 85 %.
class Door:
	const SPEED := 1.8
	const SLIDE := 1.75
	const PASS_AT := 0.85
	var z := 0.0
	var open := false
	var t := 0.0

	func _init(at_z: float) -> void:
		z = at_z

	func passable() -> bool:
		return t > PASS_AT

	## Насколько створка уехала вбок, м.
	func offset() -> float:
		return t * t * (3.0 - 2.0 * t) * SLIDE

	func update(dt: float) -> void:
		t = clampf(t + (1.0 if open else -1.0) * dt * SPEED, 0.0, 1.0)


var doors: Array[Door] = []


func _init() -> void:
	for z in DOOR_Z:
		doors.append(Door.new(z))


func update(dt: float) -> void:
	for d in doors:
		d.update(dt)


static func room_at(z: float) -> int:
	if z < 1.9:
		return Room.BRIDGE
	if z < 8.0:
		return Room.CORRIDOR
	if z < 14.0:
		return Room.LAB
	if z < 19.5:
		return Room.ENGINE
	return Room.CARGO


## Можно ли стоять в точке: мостик (Deck), отсеки, проёмы открытых люков; без реактора.
func can_stand(x: float, z: float, r: float = Deck.Walker.RADIUS) -> bool:
	var ok := Deck.can_stand(x, z, r)
	if not ok:
		for room in ROOMS:
			var a: Array = ROOMS[room]
			if absf(x) < float(a[2]) - r and z > float(a[0]) + r and z < float(a[1]) - r:
				ok = true
				break
	if not ok and absf(x) < DOOR_HALF - r:
		for d in doors:
			if absf(z - d.z) < 0.6 and d.passable():
				ok = true
				break
	if not ok:
		return false
	return Vector2(x, z).distance_to(Vector2(REACTOR_POS.x, REACTOR_POS.z)) >= REACTOR_R + r


## Неподвижная геометрия отсеков за мостиком: полы, потолки, борта (у лаборатории — с окнами), переборки с проёмами
## люков, корма, лампы. Бруски — как BridgePlan.Part, рисует RoomsView.
static func parts() -> Array[BridgePlan.Part]:
	var p: Array[BridgePlan.Part] = []
	var M := BridgePlan.Paint.METAL
	var add := func(n: String, k: int, s: Vector3, c: Vector3) -> void:
		p.append(BridgePlan.Part.new(n, k, s, c))
	for room in ROOMS:
		var a: Array = ROOMS[room]
		var z0: float = a[0]
		var z1: float = a[1]
		var hw: float = a[2]
		var h: float = a[3]
		var len := z1 - z0
		var zc := (z0 + z1) / 2.0
		var name: String = ROOM_NAMES[room]
		add.call("Пол: " + name, BridgePlan.Paint.DECK, Vector3(2 * hw, 0.1, len), Vector3(0, -0.05, zc))
		add.call("Потолок: " + name, BridgePlan.Paint.SEAM, Vector3(2 * hw, 0.1, len), Vector3(0, h + 0.05, zc))
		for s in [-1.0, 1.0]:
			if room == Room.LAB:
				var w := LAB_WINDOW
				add.call("Борт под окном", M, Vector3(0.2, w.position.y, len), Vector3(s * hw, w.position.y / 2.0, zc))
				var top := w.position.y + w.size.y
				add.call("Борт над окном", M, Vector3(0.2, h - top, len), Vector3(s * hw, (h + top) / 2.0, zc))
				add.call("Борт у носа", M, Vector3(0.2, w.size.y, w.position.x - z0), Vector3(s * hw, w.position.y + w.size.y / 2.0, (z0 + w.position.x) / 2.0))
				var we := w.position.x + w.size.x
				add.call("Борт у кормы", M, Vector3(0.2, w.size.y, z1 - we), Vector3(s * hw, w.position.y + w.size.y / 2.0, (we + z1) / 2.0))
			else:
				add.call("Борт: " + name, M, Vector3(0.2, h, len), Vector3(s * hw, h / 2.0, zc))
		add.call("Лампа: " + name, BridgePlan.Paint.PLAFOND, Vector3(0.15, 0.03, len - 0.6), Vector3(0, h - 0.02, zc))
	# переборки между отсеками (у мостика — своя кормовая стена в BridgePlan): шире из двух отсеков и выше из двух
	for i in range(1, DOOR_Z.size()):
		var z: float = DOOR_Z[i]
		var front: Array = ROOMS[room_at(z - 0.1)]
		var back: Array = ROOMS[room_at(z + 0.1)]
		var hw := maxf(front[2], back[2])
		var h := maxf(front[3], back[3])
		_bulkhead(p, z, hw, h)
	var cargo: Array = ROOMS[Room.CARGO]
	add.call("Корма", M, Vector3(2 * float(cargo[2]), cargo[3], 0.2), Vector3(0, float(cargo[3]) / 2.0, 24.0))
	return p


static func _bulkhead(p: Array[BridgePlan.Part], z: float, hw: float, h: float) -> void:
	var side := hw - DOOR_HALF
	var M := BridgePlan.Paint.METAL
	for s in [-1.0, 1.0]:
		p.append(BridgePlan.Part.new("Переборка", M, Vector3(side, h, 0.2), Vector3(s * (DOOR_HALF + side / 2.0), h / 2.0, z)))
	p.append(BridgePlan.Part.new("Над люком", M, Vector3(2 * DOOR_HALF, h - DOOR_H, 0.2), Vector3(0, (h + DOOR_H) / 2.0, z)))


## Цвет стержня реактора по состоянию (MOD-008): норма — голубой, перегрев — к янтарному по нагреву, сброс — тёмный.
static func rod_color(r: Reactor) -> Color:
	if r.scram > 0.0:
		return Color("20343A")
	if r.hot:
		return Color("6FE3FF").lerp(Color("FF8A3C"), clampf(r.heat / 100.0, 0.0, 1.0))
	return Color("6FE3FF")
