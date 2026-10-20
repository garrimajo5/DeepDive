extends TestCase
## Стеклоуст (initEels, eelUpdate, onZap в js/creatures.js; ART-006): три логова, бросок на скребунов и светляков,
## присоска на стекле носа — EcoLink.DRAIN 3,2 ед./с, разряд сбрасывает; пять MultiMesh в сцене.

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

func test_three_lairs_on_ground() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var eels := w.add(EcoEel.new()) as EcoEel
	eq(eels.eels.size(), 3, "три логова, как W.lairs")
	eq(w.count(EcoEel.ID), 3, "три стеклоуста в мире")
	for i in 3:
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
	eq(e2.eels[1].out, eels.eels[1].out, "при том же зерне — те же логова")


func test_hidden_body_in_crevice() -> void:
	var w := _world()
	var e := _eels(w).eels[0]
	w.run(2.0)
	eq(e.mode, EcoEel.Mode.HIDE, "корабль далеко, добычи нет — сидит")
	ok(e.agent.p.distance_to(e.lair) < 0.5, "голова у устья")
	for k in range(1, EcoEel.SEGS):
		ok((e.segs[k] - e.agent.p).dot(e.out) < 0.0, "звено %d — в глубине расщелины" % k)
	near(e.face.dot(e.out), 1.0, 1e-4, "смотрит из расщелины")


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
	eq(t.size(), 3, "три стеклоуста")
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

func test_view_five_multimeshes() -> void:
	var w := _world()
	var eels := _eels(w)
	var view := EelView.new(eels)
	tree.root.add_child(view)
	var mm := 0
	for c in view.get_children():
		if c is MultiMeshInstance3D:
			mm += 1
			eq((c as MultiMeshInstance3D).layers, OceanView.LAYER_WORLD, "%s — на слое отмели" % c.name)
	eq(mm, 5, "камни, оболочка, внутренности, глаза, присоска — пять вызовов")
	eq(view.rocks.multimesh.instance_count, 5, "пять камней логова")
	eq(view.shell.multimesh.instance_count, EcoEel.SEGS, "голова и 13 звеньев")
	var e := eels.eels[0]
	view.sync(w.time)
	near(EelView.transform_at(view.shell_buffer, 0).origin.distance_to(e.segs[0]), 0.0, 1e-4, "голова на месте")
	var ring := EelView.transform_at(view.ring_buffer, 0)
	near(ring.basis.get_scale().x, 1.0, 1e-3, "в логове кольцо круглое")
	e.cd = 0.0
	_ship_near(w, e)
	ok(_run_until_latched(w), "присосался")
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
	ok(view.eels != null and view.eels.eels.size() == 3, "три стеклоуста в живом мире")
	ok(view.eel_view != null and view.eel_view.get_parent() == view, "и в сцене")
	view.queue_free()
	await frames(1)
