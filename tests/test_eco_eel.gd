extends TestCase
## Стеклоуст (initEels, eelUpdate, onZap в js/creatures.js; ART-006): одно логово у трещины 02↔01 (#834), бросок на скребунов и светляков,
## присоска на стекле носа — EcoLink.DRAIN 3,2 ед./с, разряд сбрасывает; шесть MultiMesh в сцене (с мутью).

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
## Своё логово для тестов: устье на 1,1 м над дном.
const SPOT := Vector3(0, FLAT, 0)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _notes(w: EcoWorld, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == EcoEel.ID and ev.note == note:
			out.append(ev)
	return out


## Ровное дно, корабль далеко, одно логово в SPOT; prey — скребуны и светляки (могут быть null).
func _world(g: EcoGrazer = null, f: EcoFish = null, w: EcoWorld = null) -> EcoWorld:
	if w == null:
		w = EcoWorld.new()
		w.ground = _flat
		w.ship.pos = FAR
	w.add(EcoEel.new(g, f, [SPOT] as Array[Vector3]))
	return w


func _eels(w: EcoWorld) -> EcoEel:
	for s in w.systems:
		if s is EcoEel:
			return s
	return null


func _drains(events: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["type"] == EcoLink.DRAIN:
			out.append(e)
	return out


## Поставить корабль носом к логову (на юг, корпус уходит прочь от логова): нос в 15 м к северу и на 6 м выше устья.
func _ship_near(w: EcoWorld, e: EcoEel.Eel) -> void:
	w.ship.yaw = PI
	w.ship.pos = e.lair + Vector3(0, 6, -15) - EcoEel.FRONT.rotated(Vector3.UP, PI)


## Прогнать мир, пока стеклоуст не присосётся (не дольше limit с).
func _run_until_latched(w: EcoWorld, limit := 60.0) -> bool:
	var eels := _eels(w)
	var t := 0.0
	while t < limit and eels.latched == null:
		w.step(0.1)
		t += 0.1
	return eels.latched != null


# ---------- Расстановка ----------

func test_lair_on_ground() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var eels := w.add(EcoEel.new()) as EcoEel
	eq(eels.eels.size(), EcoEel.LAIRS.size(), "по стеклоусту на логово")
	eq(w.count(EcoEel.ID), EcoEel.LAIRS.size(), "стеклоусты в мире")
	for i in EcoEel.LAIRS.size():
		var e := eels.eels[i]
		var xz := EcoEel.LAIRS[i]
		near(e.lair.y, Seabed.height(xz.x, xz.y) + EcoEel.MOUTH_UP, 0.01, "устье %d на 1,1 м над дном" % i)
		near(Vector2(e.lair.x - xz.x, e.lair.z - xz.y).length(), EcoEel.MOUTH_OUT, 0.01, "устье на 0,3 м наружу")
		near(e.out.length(), 1.0, 1e-4, "расщелина смотрит вдоль дна")
		eq(e.out.y, 0.0, "горизонтально")
		eq(e.rocks.size(), 5, "пять камней логова")
		eq(e.mode, EcoEel.Mode.HIDE, "сидит в логове")
		eq(e.segs.size(), EcoEel.SEGS, "14 звеньев")
		ok(e.cd >= 10.0 and e.cd <= 25.0, "первый бросок через 10–25 с")
	var again := EcoWorld.new()
	again.ground = Seabed.height
	var e2 := again.add(EcoEel.new()) as EcoEel
	eq(e2.eels[0].out, eels.eels[0].out, "при том же зерне — то же логово")


# ---------- Слой 1 (#834): один читаемый эпизод у трещины 02↔01 ----------

## Ближайшая точка отрезка 02→01 к xz и доля пути по нему.
static func _on_crack_path(xz: Vector2) -> Vector2:
	var a := LayerMap.xz("02")
	var b := LayerMap.xz("01")
	var t := clampf((xz - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return a.lerp(b, t)


func test_single_lair_at_crack_02_01() -> void:
	eq(EcoEel.LAIRS.size(), 1, "одно логово — один читаемый эпизод, не три")
	var xz := EcoEel.LAIRS[0]
	var off := xz.distance_to(_on_crack_path(xz))
	ok(off < 20.0, "логово у трещины на подходе 02↔01: %.1f м от пути" % off)
	ok(xz.distance_to(LayerMap.xz("02")) > 50.0 and xz.distance_to(LayerMap.xz("01")) > 50.0,
		"посреди подхода, а не у самих мест")
	for id: String in ["00", "07", "09", "10", "01"]:
		var d := xz.distance_to(LayerMap.xz(id))
		ok(d >= EcoEel.LAIR_CLEAR, "логово в %.0f м от %s (места сохранения, терминал и серпохвост у цветка)" % [d, id])
	# путь обучения 00→01 мимо логова — дальше броска к стеклу
	var a := LayerMap.xz("00")
	var b := LayerMap.xz("01")
	var t := clampf((xz - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	ok(xz.distance_to(a.lerp(b, t)) > EcoEel.WARN_R, "путь обучения 00→01 не задевает логово")


## Знак раньше угрозы: корабль идёт к логову носом на 4 м/с — строка про красный глаз приходит, пока нос дальше
## SHIP_R, к стеклу стеклоуст плывёт позже и ближе.
func test_eye_sign_before_threat() -> void:
	var w := _world()
	var eels := _eels(w)
	var e := eels.eels[0]
	e.cd = 0.0
	w.ship.yaw = PI   # нос к +z, логово впереди
	var sign_at := -1.0
	var go_at := -1.0
	for i in 400:
		var d := 90.0 - i * 0.4
		w.ship.pos = e.lair + Vector3(0, 6, -d)
		w.step(0.1)
		var nose := EcoEel.front(w.ship).distance_to(e.lair)
		if sign_at < 0.0 and _texts(w).has(EcoEel.WARN_TEXT):
			sign_at = nose
		if go_at < 0.0 and e.mode == EcoEel.Mode.TO_SHIP:
			go_at = nose
			break
	ok(sign_at > 0.0, "знак пришёл")
	ok(go_at > 0.0, "стеклоуст всё же поплыл к стеклу")
	ok(sign_at > EcoEel.SHIP_R + 10.0, "знак пришёл при носе в %.0f м, дальше броска (28 м)" % sign_at)
	ok(sign_at - go_at >= 15.0, "знак на %.0f м раньше угрозы" % (sign_at - go_at))


## Знак — один раз за заход и не в разгар: в круге — тишина; вышел и вернулся — снова, но не раньше WARN_CD; висит на
## стекле — знака нет.
func test_eye_sign_once_per_visit() -> void:
	var w := _world()
	var e := _eels(w).eels[0]
	e.cd = 999.0   # сидит, к стеклу не плывёт
	var inside := e.lair + Vector3(0, 8, EcoEel.WARN_R - 10.0)
	var outside := e.lair + Vector3(0, 8, EcoEel.WARN_R + 20.0)
	var got := 0
	w.ship.pos = inside
	for i in 50:
		w.step(0.1)
		got += _texts(w).count(EcoEel.WARN_TEXT)
	eq(got, 1, "в круге — одна строка")
	w.ship.pos = outside
	w.step(0.1)
	w.ship.pos = inside
	for i in 50:
		w.step(0.1)
		got += _texts(w).count(EcoEel.WARN_TEXT)
	eq(got, 1, "вернулся сразу — тишина до WARN_CD")
	w.ship.pos = outside
	for i in int(EcoEel.WARN_CD * 10.0):
		w.step(0.1)
	w.ship.pos = inside
	w.step(0.1)
	got += _texts(w).count(EcoEel.WARN_TEXT)
	eq(got, 2, "через WARN_CD — снова")


## Обход есть: корабль идёт от 02 к 01 стороной, на 45 м от пути в сторону от логова, на 28 м глубины — дно ниже, нос
## всё время дальше SHIP_R, стеклоуст сидит в расщелине (бросается только на прямом пути).
func test_detour_past_lair() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var eels := w.add(EcoEel.new()) as EcoEel
	var e := eels.eels[0]
	e.cd = 0.0
	var a := LayerMap.xz("02")
	var b := LayerMap.xz("01")
	var lair := Vector2(e.lair.x, e.lair.z)
	var n := (b - a).normalized().orthogonal()
	if (lair - _on_crack_path(lair)).dot(n) > 0.0:
		n = -n   # в сторону от логова
	var dir := (b - a).normalized()
	w.ship.yaw = atan2(-dir.x, -dir.y)
	var closest := INF
	for i in 400:
		var p := a.lerp(b, i / 399.0) + n * 45.0
		var floor_y := Seabed.height(p.x, p.y)
		ok(floor_y < -32.0, "дно на обходе ниже корабля: %.1f м у (%.0f; %.0f)" % [floor_y, p.x, p.y])
		w.ship.pos = Vector3(p.x, -28.0, p.y)
		w.step(0.1)
		closest = minf(closest, EcoEel.front(w.ship).distance_to(e.lair))
		ok(e.mode == EcoEel.Mode.HIDE, "стеклоуст сидит в логове")
	ok(closest > EcoEel.SHIP_R, "нос не ближе %.0f м к логову" % closest)


static func _texts(w: EcoWorld) -> Array[String]:
	var out: Array[String] = []
	for ev in w.take_link():
		if ev.get("type", "") == EcoLink.MESSAGE:
			out.append(str(ev["text"]))
	return out


func test_hidden_body_in_crevice() -> void:
	var w := _world()
	var e := _eels(w).eels[0]
	w.run(2.0)
	eq(e.mode, EcoEel.Mode.HIDE, "корабль далеко, добычи нет — сидит")
	ok(e.agent.p.distance_to(e.lair) < 0.5, "голова у устья")
	for k in range(1, EcoEel.SEGS):
		ok((e.segs[k] - e.agent.p).dot(e.out) < 0.0, "звено %d — в глубине расщелины" % k)
	near(e.face.dot(e.out), 1.0, 1e-4, "смотрит из расщелины")


## Самый большой сдвиг звена и поворот головы за шаг 0,05 с, пока идёт мир (seconds с) или until() не true.
func _max_jump(w: EcoWorld, e: EcoEel.Eel, seconds: float) -> Vector2:
	var most := Vector2.ZERO
	var t := 0.0
	while t < seconds:
		var was := e.segs.duplicate()
		var face := e.face
		w.step(0.05)
		t += 0.05
		for k in EcoEel.SEGS:
			most.x = maxf(most.x, was[k].distance_to(e.segs[k]))
		most.y = maxf(most.y, face.angle_to(e.face))
	return most


func test_returns_into_crevice_smoothly() -> void:
	# Возвращается в логово, тело тянется за головой снаружи устья: в расщелину оно втягивается за SETTLE,
	# а не перескакивает за шаг (раньше хвост прыгал на 11 м, голова — на пол-оборота).
	var w := _world()
	var e := _eels(w).eels[0]
	w.ship.pos = e.lair + Vector3(0, 20, 40)   # корабль смотрит — ближе EcoLod.MID: стеклоуст шагает каждый кадр
	e.mode = EcoEel.Mode.RETURN
	e.cd = 30.0
	e.agent.p = e.lair + e.out * 8.0
	for k in EcoEel.SEGS:
		e.segs[k] = e.agent.p + e.out * (k * EcoEel.SEG_FOLLOW)
	e.face = -e.out
	var most := _max_jump(w, e, 3.0)
	eq(e.mode, EcoEel.Mode.HIDE, "вернулся в логово")
	ok(most.x < 1.6, "звено за шаг сдвинулось не больше 1,6 м (%.2f)" % most.x)
	ok(most.y < EcoEel.FACE_MAX * 0.05 + 1e-3, "голова за шаг повернулась не больше 0,35 рад (%.2f)" % most.y)
	for k in range(1, EcoEel.SEGS):
		ok((e.segs[k] - e.agent.p).dot(e.out) < 0.0, "звено %d — в глубине расщелины" % k)
	near(e.face.dot(e.out), 1.0, 1e-4, "смотрит из расщелины")


func test_latches_smoothly() -> void:
	# На стекло тело ложится за SETTLE, а не прыгает на окно за шаг; по пути — мимо корпуса.
	var w := _world()
	var e := _eels(w).eels[0]
	e.cd = 0.0
	_ship_near(w, e)
	var t := 0.0
	var jump := 0.0   # самый большой сдвиг звена за последний шаг пути к носу и шаг, на котором присосался
	while t < 60.0 and not e.latched():
		var was := e.segs.duplicate()
		w.step(0.05)
		t += 0.05
		jump = 0.0
		for k in EcoEel.SEGS:
			jump = maxf(jump, was[k].distance_to(e.segs[k]))
	ok(e.latched(), "присосался")
	ok(jump < 1.2, "на шаге, где присосался, звенья не прыгнули на стекло (%.2f м)" % jump)
	var most := _max_jump(w, e, EcoEel.SETTLE + 0.2)
	ok(most.x < 1.2, "звено за шаг сдвинулось не больше 1,2 м (%.2f)" % most.x)
	ok(most.y < EcoEel.FACE_MAX * 0.05 + 1e-3, "голова за шаг повернулась не больше 0,35 рад (%.2f)" % most.y)
	for k in EcoEel.SEGS:
		ok(not EcoHull.touches(e.segs[k], w.ship.pos, w.ship.yaw), "звено %d не в корпусе" % k)
		near(e.segs[k].distance_to(EcoEel.latch_point(w.ship, k, w.time)), 0.0, 1e-4, "звено %d на стекле" % k)


func test_turn_face() -> void:
	var f := EcoEel.turn_face(Vector3.FORWARD, Vector3.BACK, 0.05)
	near(Vector3.FORWARD.angle_to(f), EcoEel.FACE_MAX * 0.05, 1e-4, "назад — не быстрее 7 рад/с")
	near(f.y, 0.0, 1e-5, "ровно назад — разворот по горизонтали")
	var g := EcoEel.turn_face(Vector3.FORWARD, Vector3.FORWARD.rotated(Vector3.UP, 0.1), 0.05)
	near(Vector3.FORWARD.angle_to(g), 0.1 * (1.0 - exp(-EcoEel.FACE_FOLLOW * 0.05)), 1e-4, "малый угол — долей")
	eq(EcoEel.turn_face(Vector3.RIGHT, Vector3.RIGHT, 0.05), Vector3.RIGHT, "уже смотрит — так и есть")


# ---------- Охота ----------

func test_strikes_grazer() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var moss := w.add(EcoMoss.new([SPOT + Vector3(4, 0, 0)] as Array[Vector3])) as EcoMoss
	var g := w.add(EcoGrazer.new(moss, 2)) as EcoGrazer
	_world(g, null, w)
	var eels := _eels(w)
	var e := eels.eels[0]
	e.cd = 0.0
	var t := 0.0
	while t < 30.0 and _notes(w, "eelcatch").is_empty():
		w.step(0.1)
		t += 0.1
	var ev := _notes(w, "eelcatch")
	eq(ev.size(), 1, "утащил скребуна")
	if ev.size() == 1:
		ok(ev[0].text().contains("утащил") and ev[0].text().contains("в расщелину"), ev[0].text())
	eq(g.all.filter(func(x): return not x.agent.alive).size(), 1, "одного скребуна нет")
	eq(e.mode, EcoEel.Mode.RETURN, "возвращается в логово")
	near(e.cd, EcoEel.CD_FED, 0.2, "сыт — 25 с")
	w.run(5.0)
	eq(e.mode, EcoEel.Mode.HIDE, "снова в логове")


func test_strikes_fish() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	_world(null, f, w)
	var e := _eels(w).eels[0]
	e.cd = 0.0
	var fish := f.all[0]
	var t := 0.0
	while t < 20.0 and e.mode == EcoEel.Mode.HIDE:
		fish.agent.p = e.lair + Vector3(2, 0, 0)
		w.step(0.05)
		t += 0.05
	eq(e.mode, EcoEel.Mode.STRIKE, "светляк ближе 6 м — бросок")
	w.run(3.0)
	eq(_notes(w, "eelcatch").size(), 1, "схватил светляка")
	ok(not fish.agent.alive, "светляк съеден")


func test_strike_gives_up() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	_world(null, f, w)
	var e := _eels(w).eels[0]
	var fish := f.all[0]
	e.mode = EcoEel.Mode.STRIKE
	e.prey_fish = fish
	e.timer = EcoEel.STRIKE_TIME
	fish.agent.p = e.lair + Vector3(200, 0, 0)
	for i in 70:
		fish.agent.p = e.lair + Vector3(200, 0, 0)
		w.step(0.05)
	eq(e.mode, EcoEel.Mode.RETURN, "за 3 с не догнал — назад")
	near(e.cd, EcoEel.CD_MISS, 0.5, "пауза 8 с")
	ok(fish.agent.alive, "светляк ушёл")


# ---------- Корабль ----------

func test_latches_on_glass_and_drains() -> void:
	var w := _world()
	var eels := _eels(w)
	var e := eels.eels[0]
	e.cd = 0.0
	_ship_near(w, e)
	ok(_run_until_latched(w), "корабль у логова — присосался")
	eq(e.mode, EcoEel.Mode.LATCHED, "на стекле")
	eq(_notes(w, "latch").size(), 1, "наблюдение «latch»")
	ok(_notes(w, "latch")[0].text().ends_with("присосался к корпусу!"), "строка на приборы")
	w.take_link()
	w.step(0.12)   # три подшага — одно событие
	var d := _drains(w.take_link())
	eq(d.size(), 1, "одно DRAIN за шаг, сколько бы ни было подшагов")
	if d.size() == 1:
		eq(d[0]["by"], "Стеклоуст", "кто тянет")
		near(d[0]["units"], EcoEel.DRAIN, 1e-6, "3,2 ед./с")
	w.run(10.0)
	eq(eels.latched, e, "висит, пока нет разряда")


func test_latched_pose_on_glass() -> void:
	var w := _world()
	var e := _eels(w).eels[0]
	e.cd = 0.0
	_ship_near(w, e)
	ok(_run_until_latched(w), "присосался")
	w.run(EcoEel.SETTLE + 0.1, 0.05)   # тело легло на стекло
	for yaw in [0.0, 1.1, -2.3]:
		w.ship.yaw = yaw
		w.step(0.05)
		var head := EcoHull.to_ship(e.segs[0], w.ship.pos, yaw)
		near(head.z, EcoEel.FRONT.z, 1e-3, "голова у стекла")
		near(head.y, EcoEel.FRONT.y, 1e-3, "на середине стекла по высоте")
		near(head.x, EcoEel.LATCH_X0, 1e-3, "у левой стойки")
		near(e.face.dot(Vector3.BACK.rotated(Vector3.UP, yaw)), 1.0, 1e-4, "пастью в стекло")
		for k in EcoEel.SEGS:
			var l := EcoHull.to_ship(e.segs[k], w.ship.pos, yaw)
			ok(absf(l.x) < 4.5 and l.y > 0.75 and l.y < 2.75, "звено %d на стекле 9 × 2 м" % k)
			ok(l.z < HullPlan.NOSE_CUT, "звено %d снаружи стекла" % k)
			ok(not EcoHull.touches(e.segs[k], w.ship.pos, yaw), "звено %d не в корпусе" % k)


func test_zap_shakes_off() -> void:
	var w := _world()
	var eels := _eels(w)
	var e := eels.eels[0]
	e.cd = 0.0
	_ship_near(w, e)
	ok(_run_until_latched(w), "присосался")
	w.take_link()
	w.ship.zap = true
	w.ship.zap_radius = 5.0
	w.step(0.05)
	w.ship.zap = false
	ok(eels.latched == null, "разряд сбросил")
	eq(e.mode, EcoEel.Mode.FLEE, "бежит в логово")
	eq(_notes(w, "zap").size(), 1, "наблюдение «zap»")
	ok(_notes(w, "zap")[0].text().begins_with("Разряд сбросил"), _notes(w, "zap")[0].text())
	eq(_drains(w.take_link()).size(), 0, "заряд больше не тянет")
	w.run(30.0)
	eq(e.mode, EcoEel.Mode.HIDE, "вернулся в логово")
	ok(eels.latched == null, "40 с не выходит, хоть корабль рядом")


func test_zap_without_eel_is_quiet() -> void:
	var w := _world()
	w.ship.zap = true
	w.step(0.05)
	eq(_notes(w, "zap").size(), 0, "сбрасывать некого — молчит")


func test_ship_far_no_latch() -> void:
	var w := _world()
	var e := _eels(w).eels[0]
	e.cd = 0.0
	w.ship.yaw = PI
	w.ship.pos = e.lair + Vector3(0, 0, -40) - EcoEel.FRONT.rotated(Vector3.UP, PI)
	w.run(60.0, 0.1)
	eq(e.mode, EcoEel.Mode.HIDE, "нос дальше 28 м — не выходит")


func test_gives_up_when_ship_leaves() -> void:
	var w := _world()
	var e := _eels(w).eels[0]
	e.mode = EcoEel.Mode.TO_SHIP
	e.timer = EcoEel.TO_SHIP_TIME
	w.ship.pos = FAR
	w.run(6.5, 0.1)
	ok(e.mode == EcoEel.Mode.RETURN or e.mode == EcoEel.Mode.HIDE, "за 6 с не догнал — назад")
	ok(_eels(w).latched == null, "не присосался")


func test_goes_around_hull_from_behind() -> void:
	# Логово за кормой: путь к носу — сбоку корпуса, ни голова, ни звенья не проходят сквозь него.
	var w := _world()
	var e := _eels(w).eels[0]
	w.ship.yaw = 0.0
	w.ship.pos = e.lair - Vector3(0, HullPlan.CENTER_Y, 36)
	e.mode = EcoEel.Mode.TO_SHIP
	e.timer = 30.0
	var inside := 0
	var t := 0.0
	while t < 20.0 and not e.latched():
		w.step(0.05)
		t += 0.05
		for k in EcoEel.SEGS:
			if EcoHull.touches(e.segs[k], w.ship.pos, w.ship.yaw):
				inside += 1
	ok(e.latched(), "добрался до носа за %.1f с" % t)
	eq(inside, 0, "тело не проходило сквозь корпус")


func test_detour_beside_hull() -> void:
	var ship := Vector3(10, -20, 30)
	var behind := ship + Vector3(1, 1.6, 45)
	var nose := ship + EcoEel.FRONT
	var p := EcoHull.detour(behind, nose, ship, 0.0, 0.3)
	eq(p, nose, "дальше 40 м — прямо к цели")
	behind = ship + Vector3(1, 1.6, 32)
	p = EcoHull.detour(behind, nose, ship, 0.0, 0.3)
	ok(p != nose, "путь сквозь корпус — обход")
	near(p.x - ship.x, EcoHull.DETOUR_SIDE + 0.3, 1e-4, "сбоку по правому борту")
	near(p.z - ship.z, 26.0, 1e-4, "на 6 м вперёд")
	var front_side := ship + Vector3(0, 1.75, -20)
	eq(EcoHull.detour(front_side, nose, ship, 0.0, 0.3), nose, "спереди путь чистый")


func test_targets_for_sonar_and_scanner() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.add(EcoEel.new())
	var t := w.scan_targets()
	eq(t.size(), EcoEel.LAIRS.size(), "стеклоуст виден в логове")
	ok(t[0]["sonar"] and not t[0]["hidden"], "видны сонару и сканеру и в логове")
	eq(t[0]["r"], 1.3, "размер цели 1,3 м")


func test_same_seed_same_story() -> void:
	var runs: Array = []
	for n in 2:
		var w := EcoWorld.new()
		w.ground = Seabed.height
		var moss := w.add(EcoMoss.new()) as EcoMoss
		var g := w.add(EcoGrazer.new(moss)) as EcoGrazer
		var f := w.add(EcoFish.new()) as EcoFish
		var eels := w.add(EcoEel.new(g, f)) as EcoEel
		w.ship.yaw = PI
		w.ship.pos = eels.eels[0].lair + Vector3(0, 5, -12) - EcoEel.FRONT.rotated(Vector3.UP, PI)
		w.run(40.0, 0.1)
		var s := []
		for e in eels.eels:
			s.append([e.mode, e.agent.p])
		runs.append(s)
	eq(runs[0], runs[1], "мир повторяется")


# ---------- Сцена ----------

func test_view_four_multimeshes() -> void:
	var w := _world()
	var eels := _eels(w)
	var view := EelView.new(eels)
	tree.root.add_child(view)
	var mm := 0
	for c in view.get_children():
		if c is MultiMeshInstance3D:
			mm += 1
			eq((c as MultiMeshInstance3D).layers, OceanView.LAYER_WORLD, "%s — на слое отмели" % c.name)
	eq(mm, 5, "камни, оболочка, внутренности с глазами, присоска и муть — пять вызовов (#849)")
	eq(view.rocks.multimesh.instance_count, 5, "пять камней логова")
	eq(view.shell.multimesh.instance_count, EcoEel.SEGS, "голова и 13 звеньев")
	var e := eels.eels[0]
	view.sync(w.time)
	near(EelView.transform_at(view.shell_buffer, 0).origin.distance_to(e.segs[0]), 0.0, 1e-4, "голова на месте")
	_check_organs(view, e)
	var ring := EelView.transform_at(view.ring_buffer, 0)
	near(ring.basis.get_scale().x, 1.0, 1e-3, "в логове кольцо круглое")
	e.cd = 0.0
	_ship_near(w, e)
	ok(_run_until_latched(w), "присосался")
	w.run(EcoEel.SETTLE + 0.1, 0.05)   # тело легло на стекло
	view.sync(w.time)
	ring = EelView.transform_at(view.ring_buffer, 0)
	ok(ring.basis.get_scale().x > 1.2, "на стекле кольцо расплющено")
	var l := EcoHull.to_ship(ring.origin, w.ship.pos, w.ship.yaw)
	ok(l.z < HullPlan.NOSE_CUT and l.z > HullPlan.NOSE_CUT - 0.2, "кольцо прижато к стеклу снаружи")
	view.queue_free()
	await frames(1)


func test_eco_view_has_eels() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	ok(view.eels != null and view.eels.eels.size() == 1, "стеклоуст у трещины 02↔01 в живом мире")
	ok(view.eel_view != null and view.eel_view.get_parent() == view, "и в сцене")
	view.queue_free()
	await frames(1)


## Внутренности и глаза — один MultiMesh (#849): звенья без своего света, за ними глаза у головы, светятся сами.
func _check_organs(view: EelView, e: EcoEel.Eel) -> void:
	var mm := view.organs.multimesh
	var n := view.eels.eels.size()
	var organ_n := n * (EcoEel.SEGS - 1)
	eq(mm.instance_count, organ_n + n * EelView.EYES.size(), "звенья и глаза в одном MultiMesh")
	ok(mm.use_colors, "цвет экземпляра")
	ok(view.find_child("Глаза", false, false) == null, "отдельного узла глаз нет")
	var mat := (mm.mesh as SphereMesh).material as ShaderMaterial
	ok(mat != null and mat.shader == EcoShaders.shader(EcoShaders.PLANT), "общий шейдер растений, нового нет")
	var buf := view.organ_buffer
	eq(buf.size(), mm.instance_count * EelView.CSTRIDE, "буфер с цветами")
	near(buf[EelView.STRIDE + 3], 0.0, 1e-6, "звено без своего света")
	var eye := organ_n + e.index * EelView.EYES.size()
	near(buf[eye * EelView.CSTRIDE + EelView.STRIDE + 3], 1.0, 1e-6, "глаз светится сам")
	near(buf[eye * EelView.CSTRIDE + EelView.STRIDE], EelView.EYE.r, 1e-6, "глаз красный")
	near(buf[EelView.STRIDE], EelView.ORGANS.r, 1e-6, "звено — цвета внутренностей")
	var tr := EelView.transform_at(buf, eye, EelView.CSTRIDE)
	near(tr.origin.distance_to(e.segs[0]), EelView.EYES[0].length(), 1e-3, "глаз у головы")
	near(tr.basis.get_scale().x, EelView.EYE_R, 1e-4, "глаз маленький")
