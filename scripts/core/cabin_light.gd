class_name CabinLight
extends RefCounted
## Свет внутри корабля по ART-064 (`docs/concept-art/svet-vnutri.md`, таблица `svet-vnutri.json`): семь рабочих огней
## (слой корабля, без теней) — две лампы мостика, по одной в коридоре, лаборатории, машинном и трюме и свет реактора.
## Авария — пока открыта пробоина: одна фаза у всех, период 1,2 с; опора (B1, L1) холодная и ровная, остальные — янтарь,
## в отсеке пробоины пульсирует глубже. R1 ведёт реактор (SCRAM гасит, перегрев — к #FF8A3C). `Vitals.lamp_k`
## умножает итог после аварийной огибающей. Огни создаются один раз (BridgeView, RoomsView), здесь — только числа.

enum Kind { SAFE, ALARM, REACTOR }

const PERIOD := 1.2                   ## с — ритм аварии
const SAFE_ALARM := Color("A9DDE7")   ## опора в аварии
const SAFE_K := 0.48
const AMBER := Color("FFB259")        ## янтарь тревоги (без красного, #129)
const HOT := Color("FF8A3C")          ## перегрев реактора


class Lamp:
	var id := ""
	var pos := Vector3.ZERO   ## в осях корабля
	var color := Color.WHITE
	var energy := 1.0
	var range := 1.0
	var attenuation := 1.0
	var room := 0             ## ShipLayout.Room
	var kind := 0             ## Kind

	func _init(i: String, p: Vector3, c: String, e: float, r: float, a: float, rm: int, k: int) -> void:
		id = i
		pos = p
		color = Color(c)
		energy = e
		range = r
		attenuation = a
		room = rm
		kind = k


static func lamps() -> Array[Lamp]:
	var R := ShipLayout.Room
	return [
		Lamp.new("B1", Vector3(-1.65, 2.8, -3.6), "FFE3B5", 1.8, 5.0, 1.7, R.BRIDGE, Kind.SAFE),
		Lamp.new("B2", Vector3(1.8, 2.8, -2.6), "B8D9E8", 1.65, 5.0, 1.6, R.BRIDGE, Kind.ALARM),
		Lamp.new("C1", Vector3(0.0, 2.2, 5.0), "F1DEC2", 1.05, 3.0, 1.6, R.CORRIDOR, Kind.ALARM),
		Lamp.new("L1", Vector3(-0.4, 2.9, 11.0), "B8E7ED", 1.4, 4.5, 1.5, R.LAB, Kind.SAFE),
		Lamp.new("E1", Vector3(-1.1, 2.7, 16.5), "F4D9B0", 1.7, 4.2, 1.6, R.ENGINE, Kind.ALARM),
		Lamp.new("H1", Vector3(0.6, 2.5, 21.7), "C6D6DE", 1.35, 3.6, 1.6, R.CARGO, Kind.ALARM),
		Lamp.new("R1", Vector3(0.0, 1.6, 17.2), "67DDEB", 0.55, 2.8, 2.0, R.ENGINE, Kind.REACTOR),
	]


## Огни отсека: мостик — B1, B2; отсеки — остальные, кроме реактора (его ставит RoomsView у модели).
static func of(bridge: bool) -> Array[Lamp]:
	var out: Array[Lamp] = []
	for l in lamps():
		if l.kind != Kind.REACTOR and (l.room == ShipLayout.Room.BRIDGE) == bridge:
			out.append(l)
	return out


static func reactor() -> Lamp:
	return lamps()[6]


## Фаза ритма аварии 0…1 (`p(t) = 0,5 − 0,5·cos(2πt/1,2)`): в t = 0 — внизу.
static func pulse(t: float) -> float:
	return 0.5 - 0.5 * cos(TAU * t / PERIOD)


## Цвет огня: обычный или аварийный (breach_room — отсек открытой пробоины, −1 — пробоины нет).
static func color(l: Lamp, breach_room: int) -> Color:
	if breach_room < 0 or l.kind == Kind.REACTOR:
		return l.color
	return SAFE_ALARM if l.kind == Kind.SAFE else AMBER


## Энергия огня (light_energy) в момент t; k — мигание Vitals.lamp_k поверх огибающей.
static func energy(l: Lamp, breach_room: int, t: float, k: float = 1.0) -> float:
	var e := l.energy
	if breach_room >= 0 and l.kind != Kind.REACTOR:
		if l.kind == Kind.SAFE:
			e *= SAFE_K
		elif l.room == breach_room:
			e *= 0.35 + 0.65 * pulse(t)
		else:
			e *= 0.40 + 0.20 * pulse(t)
	return e * k


## Свет реактора: SCRAM гасит, перегрев краснит к #FF8A3C по нагреву; от пробоины не пульсирует.
static func reactor_color(r: Reactor) -> Color:
	var c := reactor().color
	if r.scram <= 0.0 and r.hot:
		return c.lerp(HOT, clampf(r.heat / 100.0, 0.0, 1.0))
	return c


static func reactor_energy(r: Reactor, k: float = 1.0) -> float:
	return 0.0 if r.scram > 0.0 else reactor().energy * k

