class_name EcoRemora
extends EcoSystem
## Присоски — рыбы-прилипалы (initRemoras/remorasUpdate/remorasZap в js/creatures.js): по три катаются на спине
## каждого ледокрыла. Ледокрыл ближе 16 м к центру корабля — прилипалы по одной (не чаще раза в 1,5 с) плывут 8 м/с
## на свободное место на корпусе (10 мест снаружи обшивки) и держатся там. Каждая на корпусе тормозит корабль:
## EcoLink.DRAG, сопротивление воды +0,025 за прилипалу. Стеклоуст не садится на корпус, где есть прилипалы
## (EcoEel.remoras, E.hullRemoras). Разряд по корпусу сбрасывает всех: плывут к ближайшему ледокрылу и минуту
## не перебираются снова. Сонар их не видит, сканер — видит (r 0,4).
## Наблюдения: «ride» (ледокрыл с прилипалами ближе 40 м, раз в 2 мин), «hop» (первая на корпусе), «drag» (третья),
## «eel» (стеклоуст не сел, раз в 40 с), «zap».

const ID := "prisoska"
## Прилипал на скате; ледокрыл ближе HOP_R к центру корабля — перебираются; одна за другой не чаще HOP_CD с.
const PER_RAY := 3
const HOP_R := 16.0
const HOP_CD := 1.5
## Добавка к сопротивлению воды за каждую прилипалу на корпусе (ship.js: drag 0,45 + 0,025 · n).
const DRAG := 0.025
## Плывут 8 м/с; ближе ARRIVE к месту — на месте.
const SWIM_SPEED := 8.0
const ARRIVE := 0.3
## Вернулась на ската или сброшена разрядом — BACK_CD с не перебирается.
const BACK_CD := 60.0
## Обход корпуса, пока плывёт обратно (S.pushOut(rm.p, 0,2)).
const SWIM_PAD := 0.2
## «ride» — ледокрыл ближе RIDE_R к кораблю, не чаще RIDE_CD с; «eel» — не чаще EEL_CD с.
const RIDE_R := 40.0
const RIDE_CD := 120.0
const EEL_CD := 40.0
## Сколько на корпусе — наблюдение «drag».
const DRAG_NOTE := 3
## Размер цели сканера (r: 0,4).
const TARGET_R := 0.4
## Места на корпусе в осях корабля — как RM_SLOTS браузера (нос у нижней кромки стекла, крыша рубки, борта, корма),
## но на обшивке HullPlan (корпус здесь длиннее, до z = 29): в 0,08 м снаружи, брюхом к обшивке.
const SLOTS: Array[Vector3] = [Vector3(-3.3, 0.85, -7.25), Vector3(3.4, 0.85, -7.25), Vector3(-2.5, 4.66, -3),
	Vector3(2.5, 4.66, -3.6), Vector3(0, 4.69, 2), Vector3(-6.61, 1.6, -0.9), Vector3(6.89, 1.6, -3.2),
	Vector3(0, 4.69, 12), Vector3(-6.03, 0.45, 17.5), Vector3(6.03, 0.45, 16.6)]
## Места на спине ската в осях его меша (+Z — по курсу; RM_ON_RAY): ближе к хребту, чем в браузере (там на x ±0,9–1
## сидели светящиеся пятнышки спины), и на 0,1 м над горбом тела RayView.
const ON_RAY: Array[Vector3] = [Vector3(-0.4, 0.37, 0.6), Vector3(0.45, 0.43, -0.4), Vector3(0.15, 0.48, -1.6)]

enum Mode { RAY, SWIM, HULL }


## Прилипала.
class Remora:
	extends RefCounted
	var index := 0
	var mode := Mode.RAY
	## На чьей спине катается или к кому плывёт обратно.
	var ray: EcoRay.Ray
	## Место на спине (ON_RAY) и на корпусе (SLOTS; −1 — нет места).
	var spot := 0
	var slot := -1
	var p := Vector3.ZERO
	## Куда смотрит (нос рыбы).
	var dir := Vector3.BACK
	## Пауза до следующего перехода на корпус.
	var cd := 0.0
	## Фаза взмахов хвоста.
	var ph := 0.0

	func on_ship() -> bool:
		return mode == Mode.HULL or (mode == Mode.SWIM and slot >= 0)


var remoras: Array[Remora] = []
## Сколько сейчас на корпусе (E.hullRemoras).
var on_hull := 0
## Паузы: следующий переход, наблюдение «eel», «ride».
var hop_cd := 0.0
var eel_cd := 0.0
var ride_cd := 0.0

var _rays: EcoRay


## rays — ледокрылы, на которых катаются прилипалы (без них прилипал нет).
func _init(rays: EcoRay = null) -> void:
	_rays = rays


func reset(world: EcoWorld) -> void:
	remoras.clear()
	on_hull = 0
	hop_cd = 0.0
	eel_cd = 0.0
	ride_cd = 0.0
	if _rays == null:
		return
	for ry in _rays.rays:
		for k in PER_RAY:
			var rm := Remora.new()
			rm.index = remoras.size()
			rm.ray = ry
			rm.spot = k
			rm.ph = k * 1.7 + ry.index
			rm.p = anchor(world.ship, rm)
			rm.dir = ry.dir
			remoras.append(rm)


func step(world: EcoWorld, dt: float) -> void:
	if remoras.is_empty():
		return
	var s := world.ship
	hop_cd -= dt
	eel_cd -= dt
	ride_cd -= dt
	if ride_cd <= 0.0:
		_ride_note(world)
	for rm in remoras:
		rm.cd -= dt
		match rm.mode:
			Mode.RAY:
				rm.p = anchor(s, rm)
				rm.dir = rm.ray.dir
				if rm.cd <= 0.0 and hop_cd <= 0.0 and rm.ray.p.distance_to(s.pos) < HOP_R:
					var free := free_slot()
					if free >= 0:
						rm.mode = Mode.SWIM
						rm.slot = free
						hop_cd = HOP_CD
			Mode.SWIM:
				_swim(world, rm, dt)
			Mode.HULL:
				rm.p = anchor(s, rm)
				rm.dir = s.nose()
	on_hull = 0
	for rm in remoras:
		if rm.mode == Mode.HULL:
			on_hull += 1
	if on_hull > 0:
		world.drag(Species.info(ID).name, on_hull, DRAG * on_hull)


## Плывёт к своему месту: на корпус (slot ≥ 0) или обратно на ската.
func _swim(world: EcoWorld, rm: Remora, dt: float) -> void:
	var s := world.ship
	var to := anchor(s, rm) - rm.p
	var d := to.length()
	if d < ARRIVE:
		if rm.slot >= 0:
			rm.mode = Mode.HULL
			rm.p = anchor(s, rm)
			var n := 1
			for o in remoras:
				if o != rm and o.mode == Mode.HULL:
					n += 1
			world.emit(ID, "hop", rm.p, _text(world, "hop") if n == 1 else Callable())
			if n == DRAG_NOTE:
				world.emit(ID, "drag", rm.p, _text(world, "drag"))
		else:
			rm.mode = Mode.RAY
			rm.cd = BACK_CD
		return
	rm.p += to * minf(1.0, SWIM_SPEED * dt / d)
	rm.dir = to / d
	if rm.slot < 0:
		var res := EcoHull.push_out(rm.p, s.pos, s.yaw, SWIM_PAD)
		if not res.is_empty():
			rm.p = res[0]


## Ледокрыл с прилипалами ближе RIDE_R — «ride» (раз в RIDE_CD с).
func _ride_note(world: EcoWorld) -> void:
	for ry in _rays.rays:
		if ry.p.distance_to(world.ship.pos) >= RIDE_R:
			continue
		for rm in remoras:
			if rm.mode == Mode.RAY and rm.ray == ry:
				ride_cd = RIDE_CD
				world.emit(ID, "ride", ry.p, _text(world, "ride"))
				return


## Где прилипала держится сейчас (rmAnchor): место на корпусе или на спине ската.
static func anchor(s: EcoLink.ShipState, rm: Remora) -> Vector3:
	if rm.slot >= 0:
		return hull_point(s, rm.slot)
	return EcoRay.xform(rm.ray) * ON_RAY[rm.spot % ON_RAY.size()]


## Место slot на корпусе в мире.
static func hull_point(s: EcoLink.ShipState, slot: int) -> Vector3:
	return s.pos + SLOTS[slot].rotated(Vector3.UP, s.yaw)


## Свободное место на корпусе (никто не сидит и не плывёт туда); −1 — всё занято.
func free_slot() -> int:
	for k in SLOTS.size():
		var used := false
		for rm in remoras:
			if rm.slot == k:
				used = true
				break
		if not used:
			return k
	return -1


## Стеклоуст подплыл бы к кораблю, но на корпусе прилипалы: он не садится; «eel» — раз в EEL_CD с (у логова at).
func scare_eel(world: EcoWorld, at: Vector3) -> void:
	if eel_cd > 0.0:
		return
	eel_cd = EEL_CD
	world.emit(ID, "eel", at, _text(world, "eel"))


## Разряд по корпусу (remorasZap): все на корпусе и плывущие к нему — к ближайшему ледокрылу, минуту не вернутся.
func on_zap(world: EcoWorld, _radius: float) -> void:
	var n := 0
	for rm in remoras:
		if not rm.on_ship():
			continue
		var best := _rays.rays[0]
		var bd := INF
		for ry in _rays.rays:
			var d := ry.p.distance_to(rm.p)
			if d < bd:
				bd = d
				best = ry
		rm.ray = best
		rm.slot = -1
		rm.mode = Mode.SWIM
		rm.cd = BACK_CD
		n += 1
	on_hull = 0
	if n > 0:
		world.emit(ID, "zap", world.ship.pos, _text(world, "zap"))


## Сонар не видит прилипал (noSonar), сканер — видит.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for rm in remoras:
		out.append(EcoWorld.target(ID, rm.p, TARGET_R, false))


## Текст наблюдения собирается в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой.
static func _text(world: EcoWorld, note: String) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return line(note, w.nm(ID) if w else Species.called(ID), w.nm(ID, Species.Case.GEN) if w else "",
				w.nm(EcoRay.ID, Species.Case.GEN) if w else "", w.nm(EcoEel.ID) if w else "",
				w.nm(ID, Species.Case.ACC) if w else "", w != null and w.nm(ID) == Species.info(ID).name.to_lower())


## Строка наблюдения (тексты браузера): названия — уже в нужном падеже; scanned — вид просканирован.
static func line(note: String, nom: String, gen: String, ray_gen: String, eel_nom: String, acc: String,
		scanned: bool) -> String:
	match note:
		"ride": return "На спине %s катаются %s" % [ray_gen, "присоски" if scanned else "рыбы-прилипалы"]
		"hop": return "%s перебралась с %s на корпус корабля" % [Species.cap(nom), ray_gen]
		"drag": return "%s на корпусе уже три — корабль идёт тяжелее" % Species.cap(gen)
		"eel": return "%s выглянул из расщелины, но не сел на корпус: там уже прилипалы" % Species.cap(eel_nom)
		"zap": return "Разряд сбросил %s с корпуса" % acc
	return ""
